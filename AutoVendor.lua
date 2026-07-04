-- AUTOVENDOR FOR WOTLK 3.3.5a
-- This version uses the classic API functions.

local frame = CreateFrame("Frame", "AutoVendorFrame", UIParent)
frame:SetSize(1, 1)
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, -10)
frame:Show()

-- 1. Startup Message (If you see this, the addon is loaded!)
print("|cff00ff00AutoVendor (WotLK) Loaded Successfully.|r")

-- 1.1 Local Variables & Forward Declarations
local summonState = 0
local summonTimer = 0
local fullBagTimer = 0
local wasFull = false
local summonRetryCount = 0
local currentMerchantName = "Goblin Merchant"
local lastCheckTimer = 0
local targetBtn

local UpdateTargetMacro -- Forward declaration

-- 2. Settings Initialization
local VERSION = GetAddOnMetadata("AutoVendor", "Version") or "1.2"
local GITHUB_URL = "https://github.com/User/AutoVendor"

local defaults = {
    sellGreys = true,
    sellWhites = false,
    sellGreens = true,
    sellBlues = true,
    sellEpics = false,
    useItemLevelFilter = false,
    maxItemLevel = 0,
    showBagWarning = false,
    bagWarningThreshold = 15,
    ignoreSoulbound = true,
    sellRate = 3,
    sellBatchSize = 10,
    autoSummon = false,
    scavengerDelay = 5,
    debugMode = false,
    targetKey = "G",
    interactKey = "F",
    exceptions = {},
    stats = {
        totalGold = 0,
        count0 = 0, -- Poor
        count1 = 0, -- Common
        count2 = 0, -- Uncommon
        count3 = 0, -- Rare
        count4 = 0  -- Epic
    }
}

function UpdateTargetMacro(name)
    if InCombatLockdown() or not targetBtn then
        if InCombatLockdown() then frame.pendingMacroUpdate = true end
        return
    end

    local petName = name or currentMerchantName or "Goblin Merchant"
    -- Robust macro using targetexact
    local macro = "/cleartarget"
    macro = macro .. "\n/targetexact Goblin Merchant"
    macro = macro .. "\n/targetexact Greedy Scavenger"
    if petName ~= "Goblin Merchant" and petName ~= "Greedy Scavenger" then
        macro = macro .. "\n/targetexact " .. petName
    end

    targetBtn:SetAttribute("macrotext", macro)
    frame.pendingMacroUpdate = false

    if AutoVendorSettings.debugMode then
        print("|cff00ff00AutoVendor Debug:|r Targeting macro updated for: " .. petName)
    end
end

local function UpdateTargetBind()
    if InCombatLockdown() then
        frame.pendingBindUpdate = true
        return
    end

    ClearOverrideBindings(frame)
    local tKey = AutoVendorSettings.targetKey
    local iKey = AutoVendorSettings.interactKey

    if tKey and tKey ~= "" then
        SetOverrideBindingClick(frame, true, tKey, "AV_TargetBtn")
    end

    if iKey and iKey ~= "" then
        SetOverrideBinding(frame, true, iKey, "INTERACTTARGET")
    end

    UpdateTargetMacro()
    frame.pendingBindUpdate = false
end

local function InitializeSettings()
    if type(AutoVendorSettings) ~= "table" then
        AutoVendorSettings = {}
    end

    for k, v in pairs(defaults) do
        if AutoVendorSettings[k] == nil or (type(v) == "string" and AutoVendorSettings[k] == "") then
            if type(v) == "table" then
                AutoVendorSettings[k] = {}
                for k2, v2 in pairs(v) do AutoVendorSettings[k][k2] = v2 end
            else
                AutoVendorSettings[k] = v
            end
        end
    end

    if not AutoVendorSettings.stats then AutoVendorSettings.stats = {} end
    for k, v in pairs(defaults.stats) do
        if AutoVendorSettings.stats[k] == nil then AutoVendorSettings.stats[k] = v end
    end

    UpdateTargetBind()
end

-- 3. Alert Frame for Big Red Text
local alertFrame = CreateFrame("Frame", nil, UIParent)
alertFrame:SetSize(600, 100)
alertFrame:SetPoint("CENTER", 0, 150)
alertFrame.text = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alertFrame.text:SetAllPoints()
alertFrame.text:SetTextColor(1, 0, 0) -- Red
alertFrame:Hide()

-- 3.1 Target Alert Frame (Secure)
targetBtn = CreateFrame("Button", "AV_TargetBtn", frame, "SecureActionButtonTemplate, UIPanelButtonTemplate")
targetBtn:SetSize(200, 50)
targetBtn:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
targetBtn:SetText("Target Merchant/Pet")
targetBtn:SetAttribute("type", "macro")
targetBtn:SetAttribute("macrotext", "/cleartarget\n/targetexact Goblin Merchant\n/targetexact Greedy Scavenger")
targetBtn:Hide()

targetBtn:SetScript("PostClick", function(self)
    if not InCombatLockdown() then self:Hide() end
end)

local function ShowAlert(text, isFull, force)
    if not AutoVendorSettings.showBagWarning and not force then 
        alertFrame:Hide()
        return 
    end
    
    alertFrame.text:SetText(text)
    if isFull then
        alertFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 42, "OUTLINE, MONOCHROME")
    elseif force then
        alertFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE, MONOCHROME")
    else
        alertFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE, MONOCHROME")
    end
    alertFrame:SetAlpha(1)
    alertFrame:Show()
end

local function CheckBagSpace()
    local totalFree = 0
    local totalSlots = 0
    for bag = 0, 4 do
        local freeSlots = GetContainerNumFreeSlots(bag)
        local slots = GetContainerNumSlots(bag)
        if freeSlots then totalFree = totalFree + freeSlots end
        if slots then totalSlots = totalSlots + slots end
    end

    if summonState == 0 then
        if AutoVendorSettings.showBagWarning then
            local thresholdPercent = AutoVendorSettings.bagWarningThreshold or 15
            local threshold = math.floor((thresholdPercent / 100) * totalSlots)
            if totalFree == 0 then
                ShowAlert("BAGS ARE FULL!", true)
            elseif totalFree <= threshold then
                ShowAlert(string.format("You have %d bag space remaining", totalFree), false)
            else
                alertFrame:Hide()
            end
        else
            alertFrame:Hide()
        end
    end

    if AutoVendorSettings.autoSummon and totalFree == 0 then
        wasFull = true
    else
        wasFull = false
        fullBagTimer = 0
    end
end

-- 4. Helpers
local function GetIDFromLink(link)
    if not link then return nil end
    local idString = link:match("|Hitem:(%d+):")
    if not idString then idString = link:match("^(%d+)$") end
    return idString and tonumber(idString)
end

local scanner = CreateFrame("GameTooltip", "AVScanner", UIParent, "GameTooltipTemplate")

local function IsSoulbound(bag, slot)
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetBagItem(bag, slot)
    for i = 1, scanner:NumLines() do
        local line = _G["AVScannerTextLeft" .. i]
        if line and line:GetText() then
            local text = line:GetText()
            if text:find(ITEM_SOULBOUND, 1, true) or text:find(ITEM_BIND_ON_PICKUP, 1, true) or
               (ITEM_BIND_TO_ACCOUNT and text:find(ITEM_BIND_TO_ACCOUNT, 1, true)) or
               (ITEM_BIND_TO_BNETACCOUNT and text:find(ITEM_BIND_TO_BNETACCOUNT, 1, true)) then
                return true
            end
        end
    end
    return false
end

local function FormatMoney(amount)
    if not amount or amount == 0 then return "0g 0s 0c" end
    if GetCoinTextureString then return GetCoinTextureString(amount) end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    return string.format("%dg %ds %dc", gold, silver, copper)
end

-- 5. Slash Commands & GPH Logic
AutoVendorGPH = { active = false, paused = false, elapsed = 0, goldGained = 0, startGold = 0 }
function AutoVendorGPH:Start()
    if self.active and not self.paused then return end
    if self.paused then self.paused = false; self.startGold = GetMoney() - self.goldGained
    else self.active = true; self.paused = false; self.elapsed = 0; self.goldGained = 0; self.startGold = GetMoney() end
    print("|cff00ff00AutoVendor:|r GPH Tracking Started.")
end
function AutoVendorGPH:Pause()
    if not self.active or self.paused then return end
    self.paused = true; print("|cff00ff00AutoVendor:|r GPH Tracking Paused.")
end
function AutoVendorGPH:Stop()
    if not self.active then return end
    local totalGained = self.goldGained; local totalElapsed = self.elapsed
    local gph = totalElapsed > 0 and (totalGained / totalElapsed) * 3600 or 0
    print(string.format("|cff00ff00AutoVendor:|r You made %s in %d minutes with total %s per hour.", FormatMoney(totalGained), math.floor(totalElapsed / 60), FormatMoney(gph)))
    self.active = false; self.paused = false; self.elapsed = 0; self.goldGained = 0; print("|cff00ff00AutoVendor:|r GPH Tracking Stopped.")
end

SLASH_AUTOVENDOR1 = "/autovendor"
SLASH_AUTOVENDOR2 = "/av"
SlashCmdList["AUTOVENDOR"] = function(msg)
    if not msg or msg == "" then
        if AutoVendorUI and AutoVendorUI.Toggle then AutoVendorUI:Toggle() else print("|cffff0000Error:|r UI not loaded.") end
        return
    end
    local cmd, arg1 = msg:match("^(%S*)%s*(.-)$")
    if cmd == "stats" then
        local stats = AutoVendorSettings.stats or {}
        print("|cff00ff00AutoVendor Lifetime Statistics:|r Total Gold Earned: " .. FormatMoney(stats.totalGold or 0))
    elseif cmd == "gph" then
        if arg1 == "start" then AutoVendorGPH:Start() elseif arg1 == "pause" then AutoVendorGPH:Pause() elseif arg1 == "stop" then AutoVendorGPH:Stop()
        else if AutoVendorUI and AutoVendorUI.ToggleGPH then AutoVendorUI:ToggleGPH() end end
    elseif cmd == "add" then
        local itemID = GetIDFromLink(arg1)
        if itemID then AutoVendorSettings.exceptions[itemID] = true; print("|cff00ff00AutoVendor:|r Added " .. arg1 .. " to exception list.") end
    elseif cmd == "remove" then
        local itemID = GetIDFromLink(arg1)
        if itemID and AutoVendorSettings.exceptions[itemID] then AutoVendorSettings.exceptions[itemID] = nil; print("|cff00ff00AutoVendor:|r Removed " .. arg1 .. " from exception list.") end
    elseif cmd == "test" then
        summonState = 1; summonTimer = 0; summonRetryCount = 0; frame:SetScript("OnUpdate", frame.AutoVendor_OnUpdate); print("|cff00ff00AutoVendor:|r Starting test summon sequence...")
    elseif cmd == "debug" then
        AutoVendorSettings.debugMode = not AutoVendorSettings.debugMode; print("|cff00ff00AutoVendor:|r Debug mode " .. (AutoVendorSettings.debugMode and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
    elseif cmd == "version" then print("|cff00ff00AutoVendor Version:|r " .. VERSION)
    else print("|cffffff00AutoVendor usage:|r /av, /av add [item], /av remove [item], /av stats, /av gph, /av test, /av debug, /av version") end
end

-- 6. Vendor Logic
local sellQueue = {}
local itemsSoldCount = 0
local totalProfit = 0
local sellTimer = 0

local function IsPetActive(name)
    local num = GetNumCompanions("CRITTER")
    local lowerTarget = name:lower()
    for i = 1, num do
        local _, cName, spellID, _, active = GetCompanionInfo("CRITTER", i)
        if cName and (cName:lower():find(lowerTarget, 1, true) or (name:find("Goblin", 1, true) and spellID == 67504) or (name:find("Scavenger", 1, true) and spellID == 67505)) then
            return active
        end
    end
    return false
end

local function SummonPet(name)
    local num = GetNumCompanions("CRITTER")
    local found = false; local onCooldown = false; local lowerTarget = name:lower(); local exactName = nil
    local targetSpellID = (name:find("Goblin", 1, true) and 67504) or (name:find("Scavenger", 1, true) and 67505)

    for i = 1, num do
        local _, cName, spellID, _, active = GetCompanionInfo("CRITTER", i)
        if (cName and cName:lower():find(lowerTarget, 1, true)) or (targetSpellID and spellID == targetSpellID) then
            exactName = cName; UpdateTargetMacro(exactName)
            if not active then
                local startTime, duration = GetCompanionCooldown("CRITTER", i)
                if duration and duration > 0 and (GetTime() < startTime + duration) then onCooldown = true
                else CallCompanion("CRITTER", i) end
            end
            found = true; break
        end
    end
    return found, exactName, onCooldown
end

function frame:AutoVendor_OnUpdate(elapsed)
    if wasFull and summonState == 0 then
        fullBagTimer = fullBagTimer + elapsed
        if fullBagTimer >= 5 then summonState = 1; summonTimer = 0; summonRetryCount = 0; fullBagTimer = 0 end
    end

    if #sellQueue > 0 then
        local rate = AutoVendorSettings.sellRate or 3; local batchSize = AutoVendorSettings.sellBatchSize or 10; local interval = 1 / rate
        sellTimer = sellTimer + elapsed
        while sellTimer >= interval and #sellQueue > 0 do
            sellTimer = sellTimer - interval; local stopBatch = false
            for i = 1, batchSize do
                local item = sellQueue[1]; if not item then break end
                local _, count, locked = GetContainerItemInfo(item.bag, item.slot); if locked then stopBatch = true; break end
                table.remove(sellQueue, 1); local link = GetContainerItemLink(item.bag, item.slot)
                if link then
                    local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link); local itemID = GetIDFromLink(link); if not count or count == 0 then count = 1 end
                    local shouldSell = false
                    if not (itemID and AutoVendorSettings.exceptions[itemID]) then
                        if quality == 0 and AutoVendorSettings.sellGreys then shouldSell = true
                        elseif quality == 1 and AutoVendorSettings.sellWhites then shouldSell = true
                        elseif quality == 2 and AutoVendorSettings.sellGreens then shouldSell = true
                        elseif quality == 3 and AutoVendorSettings.sellBlues then shouldSell = true
                        elseif quality == 4 and AutoVendorSettings.sellEpics then shouldSell = true end
                    end
                    if shouldSell and AutoVendorSettings.useItemLevelFilter and AutoVendorSettings.maxItemLevel > 0 then
                        local _, _, _, iLevel, _, itemType = GetItemInfo(link)
                        if (itemType == "Armor" or itemType == "Weapon") and iLevel > AutoVendorSettings.maxItemLevel then shouldSell = false end
                    end
                    if shouldSell and AutoVendorSettings.ignoreSoulbound and IsSoulbound(item.bag, item.slot) then shouldSell = false end
                    if shouldSell and price and price > 0 then
                        UseContainerItem(item.bag, item.slot); local profit = price * count
                        itemsSoldCount = itemsSoldCount + count; totalProfit = totalProfit + profit
                        AutoVendorSettings.stats.totalGold = AutoVendorSettings.stats.totalGold + profit
                        if quality >= 0 and quality <= 4 then local k = "count" .. quality; AutoVendorSettings.stats[k] = AutoVendorSettings.stats[k] + count end
                    end
                end
            end
            if stopBatch then break end
        end
    end

    if summonState > 0 then
        local oldState = summonState; summonTimer = summonTimer + elapsed
        if summonState > 0 and summonState < 4 then
            local matchName = currentMerchantName or "Goblin Merchant"
            if MerchantFrame and MerchantFrame:IsShown() and GetUnitName("target") and GetUnitName("target"):lower():find(matchName:lower(), 1, true) then
                summonState = 4; summonTimer = 0; summonRetryCount = 0; lastCheckTimer = 0
            end
        end

        if summonState == 1 then
            ShowAlert("Summoning Goblin Merchant...", true, true)
            if summonTimer >= 1 then
                local success, exactName, onCooldown = SummonPet("Goblin Merchant")
                if success then currentMerchantName = exactName or "Goblin Merchant"; summonState = 1.1; summonTimer = 0
                elseif onCooldown then print("|cffff0000AutoVendor:|r Merchant is on cooldown."); summonState = 0; summonRetryCount = 0; CheckBagSpace()
                else
                    summonRetryCount = summonRetryCount + 1
                    if summonRetryCount <= 3 then ShowAlert("Failed to find Merchant. Retrying...", true, true); summonTimer = 0
                    else print("|cffff0000AutoVendor:|r Failed to find Merchant."); summonState = 0; summonRetryCount = 0; CheckBagSpace() end
                end
            end
        elseif summonState == 1.1 then
            ShowAlert("Verifying Goblin Merchant...", true, true)
            if not lastCheckTimer or lastCheckTimer >= 0.5 then
                if IsPetActive(currentMerchantName) then summonState = 2; summonTimer = 0; summonRetryCount = 0; lastCheckTimer = nil
                elseif summonTimer >= 3 then
                    summonRetryCount = summonRetryCount + 1
                    if summonRetryCount <= 3 then summonState = 1; summonTimer = 0; lastCheckTimer = nil
                    else print("|cffff0000AutoVendor:|r Merchant did not become active."); summonState = 0; summonRetryCount = 0; CheckBagSpace() end
                end
                lastCheckTimer = 0
            else lastCheckTimer = lastCheckTimer + elapsed end
        elseif summonState == 2 then
            ShowAlert("Goblin Merchant summoned! Preparing...", true, true)
            if not InCombatLockdown() then targetBtn:Show() end
            if summonTimer >= 2 then summonState = 3; summonTimer = 0 end
        elseif summonState == 3 then
            local tKey = AutoVendorSettings.targetKey or ""; local iKey = AutoVendorSettings.interactKey or ""
            ShowAlert(string.format("Goblin Merchant summoned. Target and interact! (Target: '%s', Interact: '%s')", tKey, iKey), false, true)
        elseif summonState == 4 then
            local delay = AutoVendorSettings.scavengerDelay or 5
            if (#sellQueue == 0 and summonTimer >= 1) or summonTimer >= delay then summonState = 5; summonTimer = 0; summonRetryCount = 0; lastCheckTimer = 0
            else ShowAlert(string.format("Merchant interaction detected. Waiting %ds for Scavenger...", delay - math.floor(summonTimer)), false, true) end
        elseif summonState == 5 then
            ShowAlert("Summoning Greedy Scavenger...", true, true)
            if summonTimer >= 1 then
                local success, exactName, onCooldown = SummonPet("Greedy Scavenger")
                if success then currentMerchantName = exactName or "Greedy Scavenger"; summonState = 5.1; summonTimer = 0
                elseif onCooldown then print("|cffff0000AutoVendor:|r Scavenger is on cooldown."); summonState = 0; summonRetryCount = 0; CheckBagSpace()
                else
                    summonRetryCount = summonRetryCount + 1
                    if summonRetryCount <= 3 then ShowAlert("Failed to find Scavenger. Retrying...", true, true); summonTimer = 0
                    else print("|cffff0000AutoVendor:|r Failed to find Scavenger."); summonState = 0; summonRetryCount = 0; CheckBagSpace() end
                end
            end
        elseif summonState == 5.1 then
            ShowAlert("Verifying Greedy Scavenger...", true, true)
            if not lastCheckTimer or lastCheckTimer >= 0.5 then
                if IsPetActive(currentMerchantName) then summonState = 0; summonTimer = 0; summonRetryCount = 0; lastCheckTimer = nil; if not InCombatLockdown() then targetBtn:Hide() end; CheckBagSpace()
                elseif summonTimer >= 3 then
                    summonRetryCount = summonRetryCount + 1
                    if summonRetryCount <= 3 then summonState = 5; summonTimer = 0; lastCheckTimer = nil
                    else print("|cffff0000AutoVendor:|r Scavenger did not become active."); summonState = 0; summonRetryCount = 0; if not InCombatLockdown() then targetBtn:Hide() end; CheckBagSpace() end
                end
                lastCheckTimer = 0
            else lastCheckTimer = lastCheckTimer + elapsed end
        end
    end

    if #sellQueue == 0 and summonState == 0 and not wasFull then
        if not InCombatLockdown() then targetBtn:Hide() end
        self:SetScript("OnUpdate", nil)
        if itemsSoldCount > 0 then
            print(string.format("|cff00ff00AutoVendor:|r Sold %d items for %s", itemsSoldCount, FormatMoney(totalProfit)))
            itemsSoldCount = 0; totalProfit = 0
        end
    end
end

frame:RegisterEvent("ADDON_LOADED"); frame:RegisterEvent("PLAYER_LOGIN"); frame:RegisterEvent("PARTY_MEMBERS_CHANGED"); frame:RegisterEvent("RAID_ROSTER_UPDATE"); frame:RegisterEvent("CHAT_MSG_ADDON"); frame:RegisterEvent("MERCHANT_SHOW"); frame:RegisterEvent("MERCHANT_CLOSED"); frame:RegisterEvent("BAG_UPDATE"); frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == "AutoVendor" then InitializeSettings(); _G.AutoVendor_UpdateTargetBind = UpdateTargetBind
    elseif event == "PLAYER_LOGIN" then RegisterAddonMessagePrefix("AutoVendorVer"); BroadcastVersion(); InitializeSettings()
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then BroadcastVersion()
    elseif event == "CHAT_MSG_ADDON" and arg1 == "AutoVendorVer" and arg4 ~= GetUnitName("player") then CheckVersion(arg2)
    elseif event == "PLAYER_REGEN_ENABLED" then
        UpdateTargetBind()
        if self.pendingMacroUpdate then UpdateTargetMacro() end
    elseif event == "BAG_UPDATE" then
        CheckBagSpace()
        if wasFull and not frame:GetScript("OnUpdate") then frame:SetScript("OnUpdate", frame.AutoVendor_OnUpdate) end
    elseif event == "MERCHANT_SHOW" then
        if summonState > 0 and summonState < 4 then
            local name = GetUnitName("target"); local matchName = currentMerchantName or "Goblin Merchant"
            if name and name:lower():find(matchName:lower(), 1, true) then summonState = 4; summonTimer = 0 end
        end
        if #sellQueue > 0 then return end
        sellQueue = {}; itemsSoldCount = 0; totalProfit = 0; sellTimer = 1 / AutoVendorSettings.sellRate
        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag)
            for slot = 1, slots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link); local itemID = GetIDFromLink(link); local _, _, locked = GetContainerItemInfo(bag, slot)
                    local shouldSell = false
                    if not (itemID and AutoVendorSettings.exceptions[itemID]) then
                        if quality == 0 and AutoVendorSettings.sellGreys then shouldSell = true
                        elseif quality == 1 and AutoVendorSettings.sellWhites then shouldSell = true
                        elseif quality == 2 and AutoVendorSettings.sellGreens then shouldSell = true
                        elseif quality == 3 and AutoVendorSettings.sellBlues then shouldSell = true
                        elseif quality == 4 and AutoVendorSettings.sellEpics then shouldSell = true end
                    end
                    if shouldSell and AutoVendorSettings.useItemLevelFilter and AutoVendorSettings.maxItemLevel > 0 then
                        local _, _, _, iLevel, _, itemType = GetItemInfo(link)
                        if (itemType == "Armor" or itemType == "Weapon") and iLevel > AutoVendorSettings.maxItemLevel then shouldSell = false end
                    end
                    if shouldSell and AutoVendorSettings.ignoreSoulbound and IsSoulbound(bag, slot) then shouldSell = false end
                    if not locked and shouldSell and price and price > 0 then table.insert(sellQueue, {bag = bag, slot = slot}) end
                end
            end
        end
        if #sellQueue > 0 then self:SetScript("OnUpdate", self.AutoVendor_OnUpdate) end
    elseif event == "MERCHANT_CLOSED" then sellQueue = {}; if summonState == 0 then self:SetScript("OnUpdate", nil) end end
end)

-- AUTOVENDOR FOR WOTLK 3.3.5a
-- This version uses the classic API functions.

local frame = CreateFrame("Frame")

-- 1. Startup Message (If you see this, the addon is loaded!)
print("|cff00ff00AutoVendor (WotLK) Loaded Successfully.|r")

-- 2. Settings Initialization
local VERSION = "1.2"
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
    interactKey = "H",
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

local function UpdateTargetBind()
    if InCombatLockdown() then return end
    ClearOverrideBindings(frame)
    if AutoVendorSettings.targetKey and AutoVendorSettings.targetKey ~= "" then
        SetBindingClick(AutoVendorSettings.targetKey, "AV_TargetBtn")
    end
    if AutoVendorSettings.interactKey and AutoVendorSettings.interactKey ~= "" then
        SetOverrideBinding(frame, true, AutoVendorSettings.interactKey, "INTERACTTARGET")
    end
end

local function InitializeSettings()
    if type(AutoVendorSettings) ~= "table" then
        AutoVendorSettings = {}
    end

    -- Load defaults if missing
    for k, v in pairs(defaults) do
        if AutoVendorSettings[k] == nil then
            if type(v) == "table" then
                AutoVendorSettings[k] = {}
                for k2, v2 in pairs(v) do
                    AutoVendorSettings[k][k2] = v2
                end
            else
                AutoVendorSettings[k] = v
            end
        end
    end

    -- Ensure nested stats are initialized
    if not AutoVendorSettings.stats then AutoVendorSettings.stats = {} end
    for k, v in pairs(defaults.stats) do
        if AutoVendorSettings.stats[k] == nil then
            AutoVendorSettings.stats[k] = v
        end
    end

    UpdateTargetBind()
end

-- Initial call in case variables are already loaded (e.g. on /reload)
InitializeSettings()

-- 3. Alert Frame for Big Red Text
local alertFrame = CreateFrame("Frame", nil, UIParent)
alertFrame:SetSize(600, 100)
alertFrame:SetPoint("CENTER", 0, 150)
alertFrame.text = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alertFrame.text:SetAllPoints()
alertFrame.text:SetTextColor(1, 0, 0) -- Red
alertFrame:Hide()

-- 3.1 Target Alert Frame (Secure)
local targetBtn = CreateFrame("Button", "AV_TargetBtn", UIParent, "SecureActionButtonTemplate, UIPanelButtonTemplate")
targetBtn:SetSize(200, 50)
targetBtn:SetPoint("CENTER", 0, 50)
targetBtn:SetText("Target Goblin Merchant")
targetBtn:SetAttribute("type", "macro")
targetBtn:SetAttribute("macrotext", "/cleartarget\n/targetexact Goblin Merchant")
targetBtn:Hide()

-- PostClick doesn't interfere with the secure action
targetBtn:SetScript("PostClick", function(self)
    if AutoVendorSettings.debugMode then
        print("|cff00ff00AutoVendor Debug:|r Targeting button clicked.")
    end
    if not InCombatLockdown() then
        self:Hide()
    end
end)

local function ShowAlert(text, isFull)
    if not AutoVendorSettings.showBagWarning then
        alertFrame:Hide()
        return
    end

    alertFrame.text:SetText(text)
    if isFull then
        alertFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 42, "OUTLINE, MONOCHROME")
    else
        alertFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE, MONOCHROME")
    end
    alertFrame:SetAlpha(1)
    alertFrame:Show()
end

local summonState = 0
local summonTimer = 0
local wasFull = false
local pendingTargetShow = false

local function CheckBagSpace()
    local totalFree = 0
    local totalSlots = 0
    for bag = 0, 4 do
        local freeSlots = GetContainerNumFreeSlots(bag)
        local slots = GetContainerNumSlots(bag)
        if freeSlots then
            totalFree = totalFree + freeSlots
        end
        if slots then
            totalSlots = totalSlots + slots
        end
    end

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

    -- Summon Logic Trigger
    if AutoVendorSettings.autoSummon and totalFree == 0 then
        if not wasFull and summonState == 0 then
            summonState = 1
            summonTimer = 0
            frame:SetScript("OnUpdate", frame.AutoVendor_OnUpdate)
            if AutoVendorSettings.debugMode then
                print("|cff00ff00AutoVendor Debug:|r Bags are full! Starting summon sequence...")
            end
        end
        wasFull = true
    else
        wasFull = false
    end
end

-- 4. Helpers
local function GetIDFromLink(link)
    if not link then return nil end
    local idString = link:match("|Hitem:(%d+):")
    if not idString then
        idString = link:match("^(%d+)$")
    end
    return idString and tonumber(idString)
end

local scanner = CreateFrame("GameTooltip", "AVScanner", UIParent, "GameTooltipTemplate")

local function IsSoulbound(bag, slot)
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetBagItem(bag, slot)

    for i = 1, scanner:NumLines() do
        local line = _G["AVScannerTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Standard soulbound and account bound strings
                if text:find(ITEM_SOULBOUND, 1, true) or
                   text:find(ITEM_BIND_ON_PICKUP, 1, true) or
                   (ITEM_BIND_TO_ACCOUNT and text:find(ITEM_BIND_TO_ACCOUNT, 1, true)) or
                   (ITEM_BIND_TO_BNETACCOUNT and text:find(ITEM_BIND_TO_BNETACCOUNT, 1, true)) then
                    return true
                end
            end
        end
    end
    return false
end

local function FormatMoney(amount)
    if not amount or amount == 0 then return "0g 0s 0c" end
    -- GetCoinTextureString is the standard Blizzard way to format money with icons
    if GetCoinTextureString then
        return GetCoinTextureString(amount)
    elseif GetCoinText then
        return GetCoinText(amount)
    end

    -- Fallback manual formatting
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    return string.format("%dg %ds %dc", gold, silver, copper)
end

-- 4. Slash Commands & GPH Logic
AutoVendorGPH = {
    active = false,
    paused = false,
    elapsed = 0,
    goldGained = 0,
    startGold = 0,
}

function AutoVendorGPH:Start()
    if self.active and not self.paused then return end
    if self.paused then
        self.paused = false
        self.startGold = GetMoney() - self.goldGained
    else
        self.active = true
        self.paused = false
        self.elapsed = 0
        self.goldGained = 0
        self.startGold = GetMoney()
    end
    print("|cff00ff00AutoVendor:|r GPH Tracking Started.")
end

function AutoVendorGPH:Pause()
    if not self.active or self.paused then return end
    self.paused = true
    print("|cff00ff00AutoVendor:|r GPH Tracking Paused.")
end

function AutoVendorGPH:Stop()
    if not self.active then return end
    local totalGained = self.goldGained
    local totalElapsed = self.elapsed
    local gph = 0
    if totalElapsed > 0 then
        gph = (totalGained / totalElapsed) * 3600
    end

    print(string.format("|cff00ff00AutoVendor:|r You made %s in %d minutes with total %s per hour.",
        FormatMoney(totalGained), math.floor(totalElapsed / 60), FormatMoney(gph)))

    self.active = false
    self.paused = false
    self.elapsed = 0
    self.goldGained = 0
    print("|cff00ff00AutoVendor:|r GPH Tracking Stopped.")
end

SLASH_AUTOVENDOR1 = "/autovendor"
SLASH_AUTOVENDOR2 = "/av"
SlashCmdList["AUTOVENDOR"] = function(msg)
    if not msg or msg == "" then
        if AutoVendorUI and AutoVendorUI.Toggle then
            AutoVendorUI:Toggle()
        else
            print("|cffff0000Error:|r UI not loaded.")
        end
        return
    end

    local cmd, arg1 = msg:match("^(%S*)%s*(.-)$")

    if cmd == "stats" then
        local stats = AutoVendorSettings.stats or {}
        print("|cff00ff00AutoVendor Lifetime Statistics:|r")
        print("  Total Gold Earned: " .. FormatMoney(stats.totalGold or 0))
        print("  Items Sold by Rarity:")
        print("    |cff9d9d9dPoor (Grey):|r " .. (stats.count0 or 0))
        print("    |cffffffffCommon (White):|r " .. (stats.count1 or 0))
        print("    |cff1eff00Uncommon (Green):|r " .. (stats.count2 or 0))
        print("    |cff0070ddRare (Blue):|r " .. (stats.count3 or 0))
        print("    |cffa335eeEpic (Purple):|r " .. (stats.count4 or 0))

    elseif cmd == "gph" then
        if arg1 == "start" then
            AutoVendorGPH:Start()
        elseif arg1 == "pause" then
            AutoVendorGPH:Pause()
        elseif arg1 == "stop" then
            AutoVendorGPH:Stop()
        else
            if AutoVendorUI and AutoVendorUI.ToggleGPH then
                AutoVendorUI:ToggleGPH()
            end
        end

    elseif cmd == "add" then
        local itemID = GetIDFromLink(arg1)
        if itemID then
            if not AutoVendorSettings.exceptions then AutoVendorSettings.exceptions = {} end
            AutoVendorSettings.exceptions[itemID] = true
            print("|cff00ff00AutoVendor:|r Added " .. arg1 .. " to exception list.")
            if AutoVendorUI and AutoVendorUI.frame:IsShown() and AutoVendorUI.pages[2] and AutoVendorUI.pages[2]:IsShown() then
                AutoVendorUI:SetTab(2)
            end
        else
            print("|cffff0000Error:|r Please link an item or provide an Item ID. Example: /av add [Item Link]")
        end

    elseif cmd == "remove" then
        local itemID = GetIDFromLink(arg1)
        if itemID then
            if AutoVendorSettings.exceptions and AutoVendorSettings.exceptions[itemID] then
                AutoVendorSettings.exceptions[itemID] = nil
                print("|cff00ff00AutoVendor:|r Removed " .. arg1 .. " from exception list.")
                if AutoVendorUI and AutoVendorUI.frame:IsShown() and AutoVendorUI.pages[2] and AutoVendorUI.pages[2]:IsShown() then
                    AutoVendorUI:SetTab(2)
                end
            else
                print("|cffff0000Error:|r Item not in exception list.")
            end
        else
            print("|cffff0000Error:|r Please link an item or provide an Item ID. Example: /av remove [Item Link]")
        end

    elseif cmd == "test" then
        summonState = 1
        summonTimer = 0
        frame:SetScript("OnUpdate", frame.AutoVendor_OnUpdate)
        print("|cff00ff00AutoVendor:|r Starting test summon sequence...")

    elseif cmd == "debug" then
        AutoVendorSettings.debugMode = not AutoVendorSettings.debugMode
        print("|cff00ff00AutoVendor:|r Debug mode " .. (AutoVendorSettings.debugMode and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
        if AutoVendorUI and AutoVendorUI.frame:IsShown() and AutoVendorUI.pages[1] and AutoVendorUI.pages[1]:IsShown() then
            AutoVendorUI:SetTab(1)
        end

    elseif cmd == "version" then
        print("|cff00ff00AutoVendor Version:|r " .. VERSION)
        print("|cff00ff00GitHub:|r " .. GITHUB_URL)

    else
        print("|cffffff00AutoVendor usage:|r")
        print("  /av - Toggle UI")
        print("  /av add [item] - Add item to exceptions")
        print("  /av remove [item] - Remove item from exceptions")
        print("  /av stats - Show lifetime statistics")
        print("  /av gph [start|pause|stop] - Track Gold Per Hour")
        print("  /av test - Test pet summon sequence")
        print("  /av debug - Toggle debug mode")
        print("  /av version - Check version and GitHub")
    end
end

-- 6. Vendor Logic (WotLK Compatible)
local sellQueue = {}
local itemsSoldCount = 0
local totalProfit = 0
local sellTimer = 0

local function SummonPet(name)
    local num = GetNumCompanions("CRITTER")
    local found = false
    local lowerTarget = name:lower()
    local exactName = nil

    for i = 1, num do
        local _, cName = GetCompanionInfo("CRITTER", i)
        if cName and cName:lower():find(lowerTarget, 1, true) then
            exactName = cName
            local _, _, _, _, active = GetCompanionInfo("CRITTER", i)
            if not active then
                CallCompanion("CRITTER", i)
            end
            found = true
            break
        end
    end

    if not found and AutoVendorSettings.debugMode then
        print("|cffff0000AutoVendor Debug:|r Could not find pet '" .. name .. "'. Available pets:")
        for i = 1, num do
            local _, cName = GetCompanionInfo("CRITTER", i)
            if cName then
                print("  - " .. cName)
            end
        end
    end
    return found, exactName
end

function frame:AutoVendor_OnUpdate(elapsed)
    -- 1. Selling Logic
    if #sellQueue > 0 then
        local rate = AutoVendorSettings.sellRate or 3
        local batchSize = AutoVendorSettings.sellBatchSize or 10
        local interval = 1 / rate
        sellTimer = sellTimer + elapsed

        while sellTimer >= interval and #sellQueue > 0 do
            sellTimer = sellTimer - interval

            local stopBatch = false
            for i = 1, batchSize do
                local item = sellQueue[1]
                if not item then break end

                local _, count, locked = GetContainerItemInfo(item.bag, item.slot)
                if locked then
                    stopBatch = true
                    break
                end

                -- Safe to process, so remove from queue
                table.remove(sellQueue, 1)

                local link = GetContainerItemLink(item.bag, item.slot)
                if link then
                    local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
                    local itemID = GetIDFromLink(link)

                    if not count or count == 0 then count = 1 end

                    local isException = false
                    if itemID and AutoVendorSettings.exceptions and AutoVendorSettings.exceptions[itemID] then
                        isException = true
                    end

                    local shouldSell = false
                    if not isException then
                        if quality == 0 and AutoVendorSettings.sellGreys then shouldSell = true
                        elseif quality == 1 and AutoVendorSettings.sellWhites then shouldSell = true
                        elseif quality == 2 and AutoVendorSettings.sellGreens then shouldSell = true
                        elseif quality == 3 and AutoVendorSettings.sellBlues then shouldSell = true
                        elseif quality == 4 and AutoVendorSettings.sellEpics then shouldSell = true
                        end
                    end

                    -- Item Level check
                    if shouldSell and AutoVendorSettings.useItemLevelFilter and AutoVendorSettings.maxItemLevel and AutoVendorSettings.maxItemLevel > 0 then
                        local _, _, _, iLevel, _, itemType, _, _, _, _, _ = GetItemInfo(link)
                        -- Armor and Weapon classes
                        if itemType == "Armor" or itemType == "Weapon" or (itemType == (GetItemClassInfo and GetItemClassInfo(2))) or (itemType == (GetItemClassInfo and GetItemClassInfo(4))) then
                            if iLevel and iLevel > AutoVendorSettings.maxItemLevel then
                                shouldSell = false
                            end
                        end
                    end

                    if shouldSell and AutoVendorSettings.ignoreSoulbound and IsSoulbound(item.bag, item.slot) then
                        shouldSell = false
                    end

                    if shouldSell and price and price > 0 then
                        UseContainerItem(item.bag, item.slot)

                        local itemProfit = (price * count)
                        itemsSoldCount = itemsSoldCount + count
                        totalProfit = totalProfit + itemProfit

                        -- Update lifetime stats
                        if not AutoVendorSettings.stats then AutoVendorSettings.stats = {} end
                        local s = AutoVendorSettings.stats
                        s.totalGold = (s.totalGold or 0) + itemProfit
                        if quality and quality >= 0 and quality <= 4 then
                            local countKey = "count" .. quality
                            s[countKey] = (s[countKey] or 0) + count
                        end
                    end
                end
            end
            if stopBatch then break end
        end
    end

    -- 2. Summoning Logic
    if summonState > 0 then
        summonTimer = summonTimer + elapsed

        if summonState == 1 then -- Initial delay before summon
            if summonTimer >= 1 then
                local success, exactName = SummonPet("Goblin Merchant")
                if success then
                    if AutoVendorSettings.debugMode then
                        print("|cff00ff00AutoVendor Debug:|r Summoning " .. (exactName or "Goblin Merchant") .. "...")
                    end
                    summonState = 2
                    summonTimer = 0
                else
                    summonState = 0
                end
            end
        elseif summonState == 2 then -- Delay before targeting
            if summonTimer >= 2 then
                local tKey = AutoVendorSettings.targetKey or ""
                local iKey = AutoVendorSettings.interactKey or ""
                local bindStr = string.format(" (Target: '%s', Interact: '%s')", tKey, iKey)
                print("|cff00ff00AutoVendor:|r Goblin Merchant summoned. Please target and interact now!" .. bindStr)
                -- We no longer show the on-screen button, but the keybind is still active
                summonState = 3
                summonTimer = 0
            end
        elseif summonState == 4 then -- Wait X seconds after interaction
            local delay = AutoVendorSettings.scavengerDelay or 5
            if summonTimer >= delay then
                local success, exactName = SummonPet("Greedy Scavenger")
                if success then
                    if AutoVendorSettings.debugMode then
                        print("|cff00ff00AutoVendor Debug:|r Summoning " .. (exactName or "Greedy Scavenger") .. "...")
                    end
                end
                summonState = 0
            end
        end
    end

    -- 3. Cleanup
    if #sellQueue == 0 and summonState == 0 then
        self:SetScript("OnUpdate", nil)
        if itemsSoldCount > 0 then
            local msg = string.format("|cff00ff00AutoVendor:|r Sold %d items for %s", itemsSoldCount, FormatMoney(totalProfit))
            print(msg)
            itemsSoldCount = 0
            totalProfit = 0
        end
    end
end

-- 7. Hook for Ctrl+Right Click to add to exceptions
local old_ContainerFrameItemButton_OnModifiedClick = ContainerFrameItemButton_OnModifiedClick
function ContainerFrameItemButton_OnModifiedClick(self, button)
    if button == "RightButton" and IsControlKeyDown() then
        local bag = self:GetParent():GetID()
        local slot = self:GetID()
        local link = GetContainerItemLink(bag, slot)
        local itemID = GetIDFromLink(link)

        if itemID then
            if not AutoVendorSettings.exceptions then AutoVendorSettings.exceptions = {} end
            if not AutoVendorSettings.exceptions[itemID] then
                AutoVendorSettings.exceptions[itemID] = true
                print("|cff00ff00AutoVendor:|r Added " .. (link or "item") .. " to exception list.")
            else
                AutoVendorSettings.exceptions[itemID] = nil
                print("|cff00ff00AutoVendor:|r Removed " .. (link or "item") .. " from exception list.")
            end
            -- Refresh UI if it's shown and on Items tab
            if AutoVendorUI and AutoVendorUI.frame:IsShown() and AutoVendorUI.pages[2] and AutoVendorUI.pages[2]:IsShown() then
                AutoVendorUI:SetTab(2)
            end
        end
        return
    end
    old_ContainerFrameItemButton_OnModifiedClick(self, button)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "AutoVendor" then
        InitializeSettings()
        _G.AutoVendor_UpdateTargetBind = UpdateTargetBind
    elseif event == "PLAYER_REGEN_ENABLED" then
        UpdateTargetBind()
        pendingTargetShow = false
    elseif event == "BAG_UPDATE" then
        CheckBagSpace()
    elseif event == "MERCHANT_SHOW" then
        -- Handle summoning state transition
        if summonState == 3 then
            local name = GetUnitName("target")
            if name and name:lower():find("goblin merchant", 1, true) then
                summonState = 4
                summonTimer = 0
                local delay = AutoVendorSettings.scavengerDelay or 5
                if AutoVendorSettings.debugMode then
                    print(string.format("|cff00ff00AutoVendor Debug:|r Merchant interaction detected. Waiting %d seconds for Greedy Scavenger...", delay))
                end
                pendingTargetShow = false
            end
        end

        if #sellQueue > 0 then return end

        sellQueue = {}
        itemsSoldCount = 0
        totalProfit = 0
        sellTimer = 1 / AutoVendorSettings.sellRate

        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag)
            if slots > 0 then
                for slot = 1, slots do
                    local link = GetContainerItemLink(bag, slot)
                    if link then
                        local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
                        local itemID = GetIDFromLink(link)
                        local _, _, locked = GetContainerItemInfo(bag, slot)

                        local isException = false
                        if itemID and AutoVendorSettings.exceptions and AutoVendorSettings.exceptions[itemID] then
                            isException = true
                        end

                        local shouldSell = false
                        if not isException then
                            if quality == 0 and AutoVendorSettings.sellGreys then shouldSell = true
                            elseif quality == 1 and AutoVendorSettings.sellWhites then shouldSell = true
                            elseif quality == 2 and AutoVendorSettings.sellGreens then shouldSell = true
                            elseif quality == 3 and AutoVendorSettings.sellBlues then shouldSell = true
                            elseif quality == 4 and AutoVendorSettings.sellEpics then shouldSell = true
                            end
                        end

                        -- Item Level check
                        if shouldSell and AutoVendorSettings.useItemLevelFilter and AutoVendorSettings.maxItemLevel and AutoVendorSettings.maxItemLevel > 0 then
                            local _, _, _, iLevel, _, itemType, _, _, _, _, _ = GetItemInfo(link)
                            -- Armor and Weapon classes
                            if itemType == "Armor" or itemType == "Weapon" or (itemType == (GetItemClassInfo and GetItemClassInfo(2))) or (itemType == (GetItemClassInfo and GetItemClassInfo(4))) then
                                if iLevel and iLevel > AutoVendorSettings.maxItemLevel then
                                    shouldSell = false
                                end
                            end
                        end

                        if shouldSell and AutoVendorSettings.ignoreSoulbound and IsSoulbound(bag, slot) then
                            shouldSell = false
                        end

                        if not locked and shouldSell and price and price > 0 then
                            table.insert(sellQueue, {bag = bag, slot = slot})
                        end
                    end
                end
            end
        end

        if #sellQueue > 0 then
            self:SetScript("OnUpdate", self.AutoVendor_OnUpdate)
        end
    elseif event == "MERCHANT_CLOSED" then
        sellQueue = {}
        if summonState == 0 then
            self:SetScript("OnUpdate", nil)
        end
    end
end)

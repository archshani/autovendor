-- AUTOVENDOR FOR WOTLK 3.3.5a
-- This version uses the classic API functions.

local frame = CreateFrame("Frame")

-- 1. Startup Message (If you see this, the addon is loaded!)
print("|cff00ff00AutoVendor (WotLK) Loaded Successfully.|r")

-- 2. Settings Initialization
local defaults = {
    sellGreys = true,
    sellWhites = false,
    sellGreens = true,
    sellBlues = true,
    sellRate = 33,
    sellBatchSize = 1,
    exceptions = {},
    stats = {
        totalGold = 0,
        count0 = 0, -- Poor
        count1 = 0, -- Common
        count2 = 0, -- Uncommon
        count3 = 0  -- Rare
    }
}

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
end

-- Initial call in case variables are already loaded (e.g. on /reload)
InitializeSettings()

-- 3. Helpers
local function GetIDFromLink(link)
    if not link then return nil end
    local idString = link:match("|Hitem:(%d+):")
    if not idString then
        idString = link:match("^(%d+)$")
    end
    return idString and tonumber(idString)
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

    else
        print("|cffffff00AutoVendor usage:|r")
        print("  /av - Toggle UI")
        print("  /av add [item] - Add item to exceptions")
        print("  /av remove [item] - Remove item from exceptions")
        print("  /av stats - Show lifetime statistics")
        print("  /av gph [start|pause|stop] - Track Gold Per Hour")
    end
end

-- 5. Vendor Logic (WotLK Compatible)
local sellQueue = {}
local itemsSoldCount = 0
local totalProfit = 0
local sellTimer = 0

local function OnUpdate(self, elapsed)
    if #sellQueue == 0 then
        self:SetScript("OnUpdate", nil)
        if itemsSoldCount > 0 then
            print(string.format("|cff00ff00AutoVendor:|r Sold %d items for %s", itemsSoldCount, FormatMoney(totalProfit)))
        end
        return
    end

    local rate = AutoVendorSettings.sellRate or 33
    local batchSize = AutoVendorSettings.sellBatchSize or 1
    local interval = 1 / rate
    sellTimer = sellTimer + elapsed

    while sellTimer >= interval and #sellQueue > 0 do
        sellTimer = sellTimer - interval

        for i = 1, batchSize do
            local item = sellQueue[1]
            if not item then break end

            local _, count, locked = GetContainerItemInfo(item.bag, item.slot)
            if locked then
                -- If item is locked, we stop this batch and wait for next frame
                return
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
                    end
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
                    if quality and quality >= 0 and quality <= 3 then
                        local countKey = "count" .. quality
                        s[countKey] = (s[countKey] or 0) + count
                    end
                end
            end
        end
    end
end

-- 6. Hook for Ctrl+Right Click to add to exceptions
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
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "AutoVendor" then
        InitializeSettings()
    elseif event == "MERCHANT_SHOW" then
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
                            end
                        end

                        if not locked and shouldSell and price and price > 0 then
                            table.insert(sellQueue, {bag = bag, slot = slot})
                        end
                    end
                end
            end
        end

        if #sellQueue > 0 then
            self:SetScript("OnUpdate", OnUpdate)
        end
    elseif event == "MERCHANT_CLOSED" then
        sellQueue = {}
        self:SetScript("OnUpdate", nil)
    end
end)

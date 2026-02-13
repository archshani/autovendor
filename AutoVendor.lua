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

-- 3. Helper: Get Item ID from Link
-- 3. Helpers
local function GetIDFromLink(link)
    if not link then return nil end
    local idString = link:match("|Hitem:(%d+):")
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

-- 4. Slash Commands
SLASH_AUTOVENDOR1 = "/autovendor"
SlashCmdList["AUTOVENDOR"] = function(msg)
    if not msg then msg = "" end
    local cmd, arg1 = msg:match("^(%S*)%s*(.-)$")
    
    if cmd == "greys" then
        AutoVendorSettings.sellGreys = not AutoVendorSettings.sellGreys
        print("|cff00ff00AutoVendor:|r Selling Greys " .. (AutoVendorSettings.sellGreys and "enabled" or "disabled"))
    
    elseif cmd == "whites" then
        AutoVendorSettings.sellWhites = not AutoVendorSettings.sellWhites
        print("|cff00ff00AutoVendor:|r Selling Whites " .. (AutoVendorSettings.sellWhites and "enabled" or "disabled"))

    elseif cmd == "greens" then
        AutoVendorSettings.sellGreens = not AutoVendorSettings.sellGreens
        print("|cff00ff00AutoVendor:|r Selling Greens " .. (AutoVendorSettings.sellGreens and "enabled" or "disabled"))

    elseif cmd == "blues" then
        AutoVendorSettings.sellBlues = not AutoVendorSettings.sellBlues
        print("|cff00ff00AutoVendor:|r Selling Blues " .. (AutoVendorSettings.sellBlues and "enabled" or "disabled"))

    elseif cmd == "add" then
        local itemID = GetIDFromLink(arg1)
        if itemID then
            if not AutoVendorSettings.exceptions then AutoVendorSettings.exceptions = {} end
            AutoVendorSettings.exceptions[itemID] = true
            print("|cff00ff00AutoVendor:|r Added Item ID " .. itemID .. " to exception list.")
        else
            print("|cffff0000Error:|r Usage: /autovendor add [itemlink]")
        end

    elseif cmd == "remove" then
        local itemID = GetIDFromLink(arg1)
        if itemID and AutoVendorSettings.exceptions and AutoVendorSettings.exceptions[itemID] then
            AutoVendorSettings.exceptions[itemID] = nil
            print("|cff00ff00AutoVendor:|r Removed Item ID " .. itemID .. " from exception list.")
        else
            print("|cffff0000Error:|r Item not found or invalid link.")
        end

    elseif cmd == "list" then
        if not AutoVendorSettings.exceptions then AutoVendorSettings.exceptions = {} end
        local count = 0
        print("|cff00ff00AutoVendor:|r --- Exception List ---")
        for id, _ in pairs(AutoVendorSettings.exceptions) do
            count = count + 1
            local name = GetItemInfo(id)
            print(count .. ". " .. (name or "Unknown") .. " (ID: " .. id .. ")")
        end
        if count == 0 then print("List is empty.") end

    elseif cmd == "sellrate" then
        local rate = tonumber(arg1)
        if rate and rate >= 1 and rate <= 100 then
            AutoVendorSettings.sellRate = rate
            print("|cff00ff00AutoVendor:|r Selling rate set to " .. rate .. " items per second.")
        else
            print("|cffff0000Error:|r Rate must be a number between 1 and 100.")
        end

    elseif cmd == "stats" then
        local stats = AutoVendorSettings.stats or {}
        print("|cff00ff00AutoVendor Lifetime Statistics:|r")
        print("  Total Gold Earned: " .. FormatMoney(stats.totalGold or 0))
        print("  Items Sold by Rarity:")
        print("    |cff9d9d9dPoor (Grey):|r " .. (stats.count0 or 0))
        print("    |cffffffffCommon (White):|r " .. (stats.count1 or 0))
        print("    |cff1eff00Uncommon (Green):|r " .. (stats.count2 or 0))
        print("    |cff0070ddRare (Blue):|r " .. (stats.count3 or 0))

    else
        print("|cffffff00AutoVendor usage:|r")
        print("  /autovendor [greys|whites|greens|blues] - Toggle selling")
        print("  /autovendor add [itemlink] - Ignore item")
        print("  /autovendor remove [itemlink] - Unignore item")
        print("  /autovendor list - Show ignored items")
        print("  /autovendor sellrate [1-100] - Items sold per second (Default: 33)")
        print("  /autovendor stats - Show lifetime statistics")
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
    local interval = 1 / rate
    sellTimer = sellTimer + elapsed

    if sellTimer >= interval then
        local item = sellQueue[1] -- Peek at the first item
        if not item then
            table.remove(sellQueue, 1)
            return
        end

        local _, count, locked = GetContainerItemInfo(item.bag, item.slot)
        if locked then
            -- Item is locked, wait for next OnUpdate tick to try again
            -- We don't reset sellTimer to 0, so we check again next frame
            return
        end

        -- Safe to process, so remove from queue and reset timer
        table.remove(sellQueue, 1)
        sellTimer = 0

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

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "AutoVendor" then
        InitializeSettings()
    elseif event == "MERCHANT_SHOW" then
        -- Don't start a new scan if we are already processing a queue
        if #sellQueue > 0 then return end

        sellQueue = {}
        itemsSoldCount = 0
        totalProfit = 0
        sellTimer = 1 / AutoVendorSettings.sellRate -- start first sell immediately

        -- Only iterate through character bags (0 = backpack, 1-4 = equipped bags)
        -- This excludes bank bags (-1 and 5-11)
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

                        -- Only queue if it's not locked and should be sold
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
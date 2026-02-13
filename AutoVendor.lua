-- AUTOVENDOR FOR WOTLK 3.3.5a
-- This version uses the classic API functions.

local frame = CreateFrame("Frame")

-- 1. Startup Message (If you see this, the addon is loaded!)
print("|cff00ff00AutoVendor (WotLK) Loaded Successfully.|r")

-- 2. Settings Initialization
if type(AutoVendorSettings) ~= "table" then
    AutoVendorSettings = {}
end

local defaults = {
    sellGreys = true,
    sellWhites = false,
    sellGreens = true,
    sellBlues = true,
    exceptions = {}
}

-- Load defaults if missing
for k, v in pairs(defaults) do
    if AutoVendorSettings[k] == nil then
        AutoVendorSettings[k] = v
    end
end

-- 3. Helper: Get Item ID from Link
local function GetIDFromLink(link)
    if not link then return nil end
    local idString = link:match("|Hitem:(%d+):")
    return idString and tonumber(idString)
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

    else
        print("|cffffff00AutoVendor usage:|r")
        print("  /autovendor [greys|whites|greens|blues] - Toggle selling")
        print("  /autovendor add [itemlink] - Ignore item")
        print("  /autovendor remove [itemlink] - Unignore item")
        print("  /autovendor list - Show ignored items")
    end
end

-- 5. Vendor Logic (WotLK Compatible)
local sellQueue = {}
local itemsSoldCount = 0
local totalProfit = 0
local sellTimer = 0
local SELL_INTERVAL = 0.03 -- Max ~33 items per second (1/33 ≈ 0.0303)

local function OnUpdate(self, elapsed)
    if #sellQueue == 0 then
        self:SetScript("OnUpdate", nil)
        if itemsSoldCount > 0 then
            print(string.format("|cff00ff00AutoVendor:|r Sold %d items for %s", itemsSoldCount, GetCoinText(totalProfit)))
        end
        return
    end

    sellTimer = sellTimer + elapsed
    if sellTimer >= SELL_INTERVAL then
        sellTimer = 0
        local item = table.remove(sellQueue, 1)
        if item then
            -- Verify it's still the same item or should still be sold
            local link = GetContainerItemLink(item.bag, item.slot)
            if link then
                local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
                local itemID = GetIDFromLink(link)
                local _, count = GetContainerItemInfo(item.bag, item.slot)
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
                    itemsSoldCount = itemsSoldCount + 1
                    totalProfit = totalProfit + (price * count)
                end
            end
        end
    end
end

frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:SetScript("OnEvent", function(self, event)
    if event == "MERCHANT_SHOW" then
        sellQueue = {}
        itemsSoldCount = 0
        totalProfit = 0
        sellTimer = SELL_INTERVAL -- start first sell immediately

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
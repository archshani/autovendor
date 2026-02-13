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
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function()
    local total = 0
    local itemsSold = 0

    -- Iterate through all bags (Backpack is 0, Bank bags are usually -1 but we stop at 4)
    for bag = 0, 4 do
        -- Get number of slots in this bag
        local slots = GetContainerNumSlots(bag)
        if slots > 0 then
            for slot = 1, slots do
                local link = GetContainerItemLink(bag, slot)
                
                if link then
                    -- Get Item Info
                    local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
                    local itemID = GetIDFromLink(link)
                    
                    -- Get Stack Count (WotLK returns: icon, count, locked, quality...)
                    -- We select the 2nd return value
                    local _, count = GetContainerItemInfo(bag, slot)
                    if not count or count == 0 then count = 1 end

                    -- Check Exceptions
                    local isException = false
                    if itemID and AutoVendorSettings.exceptions and AutoVendorSettings.exceptions[itemID] then
                        isException = true
                    end

                    -- Logic Check
                    local shouldSell = false
                    if not isException then
                        if quality == 0 and AutoVendorSettings.sellGreys then shouldSell = true
                        elseif quality == 1 and AutoVendorSettings.sellWhites then shouldSell = true
                        elseif quality == 2 and AutoVendorSettings.sellGreens then shouldSell = true
                        elseif quality == 3 and AutoVendorSettings.sellBlues then shouldSell = true
                        end
                    end

                    -- Sell
                    if shouldSell and price and price > 0 then
                        UseContainerItem(bag, slot)
                        total = total + (price * count)
                        itemsSold = itemsSold + 1
                    end
                end
            end
        end
    end

    if total > 0 then
        print(string.format("|cff00ff00AutoVendor:|r Sold %d items for %s", itemsSold, GetCoinText(total)))
    end
end)
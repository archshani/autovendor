-- AUTOVENDOR & AUTOTRASH FOR WOTLK 3.3.5a
-- Integrated version with rate-limiting and unified logic.

local frame = CreateFrame("Frame")
local isMerchantOpen = false

AutoVendor = {}

-- 1. Settings Initialization
local defaults = {
    sellGreys = true,
    sellWhites = false,
    sellGreens = false,
    sellBlues = false,
    sellRate = 33,
    exceptions = {},
    stats = {
        totalGold = 0,
        count0 = 0, -- Poor
        count1 = 0, -- Common
        count2 = 0, -- Uncommon
        count3 = 0  -- Rare
    },
    trash = {
        enabled = false,
        items = {},
        bags = {[0]=true, [1]=true, [2]=true, [3]=true, [4]=true},
        stats = {
            total = 0,
            itemCounts = {}
        }
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

    if not AutoVendorSettings.trash then AutoVendorSettings.trash = {} end
    for k, v in pairs(defaults.trash) do
        if AutoVendorSettings.trash[k] == nil then
            if type(v) == "table" then
                AutoVendorSettings.trash[k] = {}
                for k2, v2 in pairs(v) do
                    AutoVendorSettings.trash[k][k2] = v2
                end
            else
                AutoVendorSettings.trash[k] = v
            end
        end
    end
    -- Specifically ensure trash.bags has keys 0-4
    if not AutoVendorSettings.trash.bags then AutoVendorSettings.trash.bags = {} end
    for i=0, 4 do
        if AutoVendorSettings.trash.bags[i] == nil then
            AutoVendorSettings.trash.bags[i] = true
        end
    end
end

InitializeSettings()

-- 2. Helpers
function AutoVendor.GetIDFromLink(link)
    if not link then return nil end
    local idString = link:match("|Hitem:(%d+):")
    return idString and tonumber(idString)
end

function AutoVendor.FormatMoney(amount)
    if not amount or amount == 0 then return "0g 0s 0c" end
    if GetCoinTextureString then
        return GetCoinTextureString(amount)
    elseif GetCoinText then
        return GetCoinText(amount)
    end

    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    return string.format("%dg %ds %dc", gold, silver, copper)
end

local GetIDFromLink = AutoVendor.GetIDFromLink
local FormatMoney = AutoVendor.FormatMoney

-- 3. Unified Process Queue
local processQueue = {}
local inQueue = {} -- to prevent double queuing
local itemsSoldCount = 0
local totalProfit = 0
local itemsTrashedCount = 0
local processTimer = 0

local function ClearInQueue()
    for b=0, 4 do
        inQueue[b] = {}
    end
end
ClearInQueue()

local function OnUpdate(self, elapsed)
    if #processQueue == 0 then
        self:SetScript("OnUpdate", nil)
        if itemsSoldCount > 0 then
            print(string.format("|cff00ff00AutoVendor:|r Sold %d items for %s", itemsSoldCount, FormatMoney(totalProfit)))
            itemsSoldCount = 0
            totalProfit = 0
        end
        if itemsTrashedCount > 0 then
            print(string.format("|cff00ff00AutoTrash:|r Deleted %d items.", itemsTrashedCount))
            itemsTrashedCount = 0
        end
        return
    end

    local rate = AutoVendorSettings.sellRate or 33
    local interval = 1 / rate
    processTimer = processTimer + elapsed

    while processTimer >= interval and #processQueue > 0 do
        local item = processQueue[1]
        local _, count, locked = GetContainerItemInfo(item.bag, item.slot)

        if locked then
            -- If the top item is locked, we can't process it yet.
            -- We stop the loop but don't reset processTimer so we try again next frame.
            break
        end

        table.remove(processQueue, 1)
        if inQueue[item.bag] then inQueue[item.bag][item.slot] = nil end
        processTimer = processTimer - interval

        local link = GetContainerItemLink(item.bag, item.slot)
        if link then
            local itemID = GetIDFromLink(link)
            if not count or count == 0 then count = 1 end

            if item.action == "sell" then
                if not isMerchantOpen then return end
                local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
                local isException = (itemID and AutoVendorSettings.exceptions and AutoVendorSettings.exceptions[itemID])

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

                    local s = AutoVendorSettings.stats
                    s.totalGold = (s.totalGold or 0) + itemProfit
                    if quality and quality >= 0 and quality <= 3 then
                        local countKey = "count" .. quality
                        s[countKey] = (s[countKey] or 0) + count
                    end
                end

            elseif item.action == "trash" then
                if itemID and AutoVendorSettings.trash.items[itemID] then
                    ClearCursor()
                    PickupContainerItem(item.bag, item.slot)
                    DeleteCursorItem()

                    itemsTrashedCount = itemsTrashedCount + 1
                    local ts = AutoVendorSettings.trash.stats
                    ts.total = (ts.total or 0) + 1
                    ts.itemCounts[itemID] = (ts.itemCounts[itemID] or 0) + 1
                end
            end
        end
    end
end

local function ScanBags(action)
    local queued = false
    for bag = 0, 4 do
        if action == "sell" or (action == "trash" and AutoVendorSettings.trash.bags[bag]) then
            local slots = GetContainerNumSlots(bag)
            for slot = 1, slots do
                if not inQueue[bag][slot] then
                    local link = GetContainerItemLink(bag, slot)
                    if link then
                        local itemID = GetIDFromLink(link)
                        local _, _, locked = GetContainerItemInfo(bag, slot)

                        local shouldAdd = false
                        if action == "sell" and isMerchantOpen then
                            local _, _, quality, _, _, _, _, _, _, _, price = GetItemInfo(link)
                            local isException = (itemID and AutoVendorSettings.exceptions and AutoVendorSettings.exceptions[itemID])
                            if not isException and price and price > 0 then
                                if (quality == 0 and AutoVendorSettings.sellGreys) or
                                   (quality == 1 and AutoVendorSettings.sellWhites) or
                                   (quality == 2 and AutoVendorSettings.sellGreens) or
                                   (quality == 3 and AutoVendorSettings.sellBlues) then
                                    shouldAdd = true
                                end
                            end
                        elseif action == "trash" and AutoVendorSettings.trash.enabled then
                            if itemID and AutoVendorSettings.trash.items[itemID] then
                                shouldAdd = true
                            end
                        end

                        if shouldAdd and not locked then
                            table.insert(processQueue, {bag = bag, slot = slot, action = action})
                            inQueue[bag][slot] = true
                            queued = true
                        end
                    end
                end
            end
        end
    end
    if queued then
        frame:SetScript("OnUpdate", OnUpdate)
    end
end

-- 4. Slash Commands & Import
local function ImportMondDelete()
    if not MondDeleteDB then
        print("|cffff0000AutoVendor:|r MondDeleteDB not found.")
        return
    end

    local count = 0
    if MondDeleteDB.profiles then
        for pName, profile in pairs(MondDeleteDB.profiles) do
            if profile.items then
                for itemID, _ in pairs(profile.items) do
                    local id = tonumber(itemID) or itemID
                    if not AutoVendorSettings.trash.items[id] then
                        AutoVendorSettings.trash.items[id] = true
                        count = count + 1
                    end
                end
            end
        end
    end
    if MondDeleteDB.items then
        for itemID, _ in pairs(MondDeleteDB.items) do
             local id = tonumber(itemID) or itemID
             if not AutoVendorSettings.trash.items[id] then
                 AutoVendorSettings.trash.items[id] = true
                 count = count + 1
             end
        end
    end
    print("|cff00ff00AutoVendor:|r Imported " .. count .. " items from MondDelete.")
end

SLASH_AUTOVENDOR1 = "/autovendor"
SLASH_AUTOVENDOR2 = "/av"
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
            AutoVendorSettings.exceptions[itemID] = true
            print("|cff00ff00AutoVendor:|r Added Item ID " .. itemID .. " to exception list.")
        else
            print("|cffff0000Error:|r Usage: /autovendor add [itemlink]")
        end
    elseif cmd == "remove" then
        local itemID = GetIDFromLink(arg1)
        if itemID and AutoVendorSettings.exceptions[itemID] then
            AutoVendorSettings.exceptions[itemID] = nil
            print("|cff00ff00AutoVendor:|r Removed Item ID " .. itemID .. " from exception list.")
        else
            print("|cffff0000Error:|r Item not found or invalid link.")
        end
    elseif cmd == "list" then
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
        if rate and rate >= 1 and rate <= 1000 then
            AutoVendorSettings.sellRate = rate
            print("|cff00ff00AutoVendor:|r Selling/Trash rate set to " .. rate .. " items per second.")
        else
            print("|cffff0000Error:|r Rate must be a number between 1 and 1000.")
        end
    elseif cmd == "import" then
        ImportMondDelete()
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
        print("  /autovendor - Open Integrated UI")
        print("  /autotrash - Open Integrated UI (AutoTrash section)")
        print("  /autovendor [greys|whites|greens|blues] - Toggle selling")
        print("  /autovendor add [itemlink] - Ignore item from selling")
        print("  /autovendor list - Show ignored items")
        print("  /autovendor sellrate [1-1000] - Items per second")
        print("  /autovendor stats - Show statistics")
        print("  /autovendor import - Import MondDelete list")
    end
end

SLASH_AUTOTRASH1 = "/autotrash"
SLASH_AUTOTRASH2 = "/at"
SlashCmdList["AUTOTRASH"] = function(msg)
    -- Will point to UI later
    print("|cff00ff00AutoTrash:|r Use /autovendor import to import MondDelete list.")
end

-- 5. Events & Hooks
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("BAG_UPDATE")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "AutoVendor" then
        InitializeSettings()
    elseif event == "MERCHANT_SHOW" then
        isMerchantOpen = true
        ScanBags("sell")
    elseif event == "MERCHANT_CLOSED" then
        isMerchantOpen = false
        -- Stop selling but allow trashing to continue
        for i = #processQueue, 1, -1 do
            if processQueue[i].action == "sell" then
                local item = table.remove(processQueue, i)
                if inQueue[item.bag] then inQueue[item.bag][item.slot] = nil end
            end
        end
    elseif event == "BAG_UPDATE" then
        if AutoVendorSettings.trash.enabled then
            ScanBags("trash")
        end
    end
end)

-- Alt + Right Click Hook
local function AddToTrash(itemID, link)
    if not itemID then return end
    if not AutoVendorSettings.trash.items[itemID] then
        AutoVendorSettings.trash.items[itemID] = true
        print("|cff00ff00AutoTrash:|r Added to delete list: " .. (link or itemID))
    end
end

local old_OnClick = ContainerFrameItemButton_OnModifiedClick
function ContainerFrameItemButton_OnModifiedClick(self, button)
    if button == "RightButton" and IsAltKeyDown() then
        local bag = self:GetParent():GetID()
        local slot = self:GetID()
        local link = GetContainerItemLink(bag, slot)
        local itemID = GetIDFromLink(link)
        if itemID then
            AddToTrash(itemID, link)
        end
        return
    end
    old_OnClick(self, button)
end

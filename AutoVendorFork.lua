-- AUTOVENDOR FORK FOR WOTLK 3.3.5a
-- This version sells only whitelisted items.

local frame = CreateFrame("Frame")

-- 1. Startup Message
print("|cff00ff00AutoVendor Fork Loaded Successfully.|r")

-- 2. Settings Initialization
local defaults = {
    sellRate = 3,
    sellBatchSize = 10,
    exceptions = {} -- This is our whitelist
}

local function InitializeSettings()
    if type(AutoVendorSettingsFork) ~= "table" then
        AutoVendorSettingsFork = {}
    end

    -- Load defaults if missing
    for k, v in pairs(defaults) do
        if AutoVendorSettingsFork[k] == nil then
            if type(v) == "table" then
                AutoVendorSettingsFork[k] = {}
                for k2, v2 in pairs(v) do
                    AutoVendorSettingsFork[k][k2] = v2
                end
            else
                AutoVendorSettingsFork[k] = v
            end
        end
    end
end

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

-- 4. Slash Commands
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

    if cmd == "add" then
        local itemID = GetIDFromLink(arg1)
        if itemID then
            if not AutoVendorSettingsFork.exceptions then AutoVendorSettingsFork.exceptions = {} end
            AutoVendorSettingsFork.exceptions[itemID] = true
            print("|cff00ff00AutoVendor Fork:|r Added " .. arg1 .. " to whitelist.")
            if AutoVendorUI and AutoVendorUI.frame:IsShown() and AutoVendorUI.pages[2] and AutoVendorUI.pages[2]:IsShown() then
                AutoVendorUI:SetTab(2)
            end
        else
            print("|cffff0000Error:|r Please link an item or provide an Item ID. Example: /av add [Item Link]")
        end

    elseif cmd == "remove" then
        local itemID = GetIDFromLink(arg1)
        if itemID then
            if AutoVendorSettingsFork.exceptions and AutoVendorSettingsFork.exceptions[itemID] then
                AutoVendorSettingsFork.exceptions[itemID] = nil
                print("|cff00ff00AutoVendor Fork:|r Removed " .. arg1 .. " from whitelist.")
                if AutoVendorUI and AutoVendorUI.frame:IsShown() and AutoVendorUI.pages[2] and AutoVendorUI.pages[2]:IsShown() then
                    AutoVendorUI:SetTab(2)
                end
            else
                print("|cffff0000Error:|r Item not in whitelist.")
            end
        else
            print("|cffff0000Error:|r Please link an item or provide an Item ID. Example: /av remove [Item Link]")
        end

    else
        print("|cffffff00AutoVendor Fork usage:|r")
        print("  /av - Toggle UI")
        print("  /av add [item] - Add item to whitelist")
        print("  /av remove [item] - Remove item from whitelist")
    end
end

-- 5. Vendor Logic (WotLK Compatible)
local sellQueue = {}
local itemsSoldCount = 0
local totalProfit = 0
local sellTimer = 0

function frame:AutoVendor_OnUpdate(elapsed)
    -- Selling Logic
    if #sellQueue > 0 then
        local rate = AutoVendorSettingsFork.sellRate or 3
        local batchSize = AutoVendorSettingsFork.sellBatchSize or 10
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

                -- Safe to process, remove from queue
                table.remove(sellQueue, 1)

                local link = GetContainerItemLink(item.bag, item.slot)
                if link then
                    local _, _, _, _, _, _, _, _, _, _, price = GetItemInfo(link)
                    local itemID = GetIDFromLink(link)

                    if not count or count == 0 then count = 1 end

                    local isWhitelisted = false
                    if itemID and AutoVendorSettingsFork.exceptions and AutoVendorSettingsFork.exceptions[itemID] then
                        isWhitelisted = true
                    end

                    if isWhitelisted and price and price > 0 then
                        UseContainerItem(item.bag, item.slot)

                        local itemProfit = (price * count)
                        itemsSoldCount = itemsSoldCount + count
                        totalProfit = totalProfit + itemProfit
                    end
                end
            end
            if stopBatch then break end
        end
    end

    -- Cleanup
    if #sellQueue == 0 then
        self:SetScript("OnUpdate", nil)
        if itemsSoldCount > 0 then
            local msg = string.format("|cff00ff00AutoVendor Fork:|r Sold %d whitelisted items for %s", itemsSoldCount, FormatMoney(totalProfit))
            print(msg)
            itemsSoldCount = 0
            totalProfit = 0
        end
    end
end

-- 6. Hook for Ctrl+Right Click to add/remove to/from whitelist
local old_ContainerFrameItemButton_OnModifiedClick = ContainerFrameItemButton_OnModifiedClick
function ContainerFrameItemButton_OnModifiedClick(self, button)
    if button == "RightButton" and IsControlKeyDown() then
        local bag = self:GetParent():GetID()
        local slot = self:GetID()
        local link = GetContainerItemLink(bag, slot)
        local itemID = GetIDFromLink(link)

        if itemID then
            if not AutoVendorSettingsFork.exceptions then AutoVendorSettingsFork.exceptions = {} end
            if not AutoVendorSettingsFork.exceptions[itemID] then
                AutoVendorSettingsFork.exceptions[itemID] = true
                print("|cff00ff00AutoVendor Fork:|r Added " .. (link or "item") .. " to whitelist.")
            else
                AutoVendorSettingsFork.exceptions[itemID] = nil
                print("|cff00ff00AutoVendor Fork:|r Removed " .. (link or "item") .. " from whitelist.")
            end
            -- Refresh UI if shown
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
    if event == "ADDON_LOADED" and arg1 and (arg1 == "AutoVendor" or arg1 == "AutoVendorFork" or arg1:find("AutoVendor")) then
        InitializeSettings()
    elseif event == "MERCHANT_SHOW" then
        if #sellQueue > 0 then return end

        sellQueue = {}
        itemsSoldCount = 0
        totalProfit = 0
        sellTimer = 1 / (AutoVendorSettingsFork.sellRate or 3)

        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag)
            if slots > 0 then
                for slot = 1, slots do
                    local link = GetContainerItemLink(bag, slot)
                    if link then
                        local _, _, _, _, _, _, _, _, _, _, price = GetItemInfo(link)
                        local itemID = GetIDFromLink(link)
                        local _, _, locked = GetContainerItemInfo(bag, slot)

                        local isWhitelisted = false
                        if itemID and AutoVendorSettingsFork.exceptions and AutoVendorSettingsFork.exceptions[itemID] then
                            isWhitelisted = true
                        end

                        if not locked and isWhitelisted and price and price > 0 then
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
        self:SetScript("OnUpdate", nil)
    end
end)

-- 7. Tooltip Hook to show Whitelisted status
local function OnTooltipSetItem(self)
    local _, link = self:GetItem()
    if link then
        local itemID = GetIDFromLink(link)
        if itemID and AutoVendorSettingsFork and AutoVendorSettingsFork.exceptions and AutoVendorSettingsFork.exceptions[itemID] then
            self:AddLine("WILL AUTO SELL THIS ITEM", 1, 0, 0)
        end
    end
end

if GameTooltip then
    GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
end
if ItemRefTooltip then
    ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
end

-- Fallback initialization on reload
InitializeSettings()

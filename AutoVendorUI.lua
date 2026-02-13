-- AUTOVENDOR UI FOR WOTLK 3.3.5a
-- Inspired by MondDelete

AutoVendorUI = {}
local UI = AutoVendorUI
UI.tabs = {}
UI.pages = {}

local function GetIDFromLink(link)
    if not link then return nil end
    local idString = link:match("|Hitem:(%d+):")
    return idString and tonumber(idString)
end

-------------------------------------------------
-- MAIN FRAME
-------------------------------------------------
local f = CreateFrame("Frame", "AutoVendorMainFrame", UIParent)
f:SetSize(400, 430)
f:SetPoint("CENTER")
f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left=11, right=12, top=12, bottom=11 }
})
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

UI.frame = f

local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)

-- Title
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -15)
title:SetText("|cff00ff00Auto|rVendor")

-------------------------------------------------
-- TAB SYSTEM
-------------------------------------------------
function UI:RegisterTab(id, name, build, refresh)
    self.tabs[id] = {
        name = name,
        build = build,
        refresh = refresh
    }
end

function UI:SetTab(id)
    for _, p in pairs(self.pages) do
        p:Hide()
    end

    local t = self.tabs[id]
    if not t then return end

    if not self.pages[id] then
        local p = CreateFrame("Frame", nil, f)
        p:SetSize(360, 300)
        p:SetPoint("TOP", 0, -80)
        self.pages[id] = p
        t.build(p)
    end

    self.pages[id]:Show()
    if t.refresh then
        t.refresh(self.pages[id])
    end

end

UI.tabButtons = {}
local function BuildTabButtons()
    local ids = {1, 2, 3} -- Settings, Items, Stats
    local names = {"Settings", "Items", "Stats"}

    for i, id in ipairs(ids) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(80, 24)
        b:SetPoint("TOPLEFT", 20 + (i-1)*85, -50)
        b:SetText(names[i])
        b:SetScript("OnClick", function()
            UI:SetTab(id)
        end)
        UI.tabButtons[id] = b
    end
end

-------------------------------------------------
-- SETTINGS TAB
-------------------------------------------------
UI:RegisterTab(1, "Settings",
function(p)
    -- Build
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, 0)
    title:SetText("Selling Settings")

    local function CreateCheckButton(name, label, relativeTo, x, y, settingKey)
        local cb = CreateFrame("CheckButton", name, p, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", x, y)
        _G[cb:GetName() .. "Text"]:SetText(label)
        cb:SetScript("OnClick", function(self)
            AutoVendorSettings[settingKey] = self:GetChecked() and true or false
        end)
        return cb
    end

    p.sellGreys = CreateCheckButton("AV_SellGreys", "Sell Poor (Grey) items", title, 0, -10, "sellGreys")
    p.sellWhites = CreateCheckButton("AV_SellWhites", "Sell Common (White) items", p.sellGreys, 0, -5, "sellWhites")
    p.sellGreens = CreateCheckButton("AV_SellGreens", "Sell Uncommon (Green) items", p.sellWhites, 0, -5, "sellGreens")
    p.sellBlues = CreateCheckButton("AV_SellBlues", "Sell Rare (Blue) items", p.sellGreens, 0, -5, "sellBlues")

    -- Sell Rate
    local rateLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rateLabel:SetPoint("TOPLEFT", p.sellBlues, "BOTTOMLEFT", 0, -20)
    rateLabel:SetText("Sell Rate (items per second):")

    local rateEB = CreateFrame("EditBox", "AV_SellRateEB", p, "InputBoxTemplate")
    rateEB:SetSize(50, 20)
    rateEB:SetPoint("LEFT", rateLabel, "RIGHT", 10, 0)
    rateEB:SetAutoFocus(false)
    rateEB:SetNumeric(true)
    rateEB:SetMaxLetters(3)
    rateEB:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 100 then
            AutoVendorSettings.sellRate = val
            print("|cff00ff00AutoVendor:|r Selling rate set to " .. val)
        else
            print("|cffff0000Error:|r Rate must be 1-100")
            self:SetText(AutoVendorSettings.sellRate or 33)
        end
        self:ClearFocus()
    end)
    p.rateEB = rateEB
end,
function(p)
    -- Refresh
    p.sellGreys:SetChecked(AutoVendorSettings.sellGreys)
    p.sellWhites:SetChecked(AutoVendorSettings.sellWhites)
    p.sellGreens:SetChecked(AutoVendorSettings.sellGreens)
    p.sellBlues:SetChecked(AutoVendorSettings.sellBlues)
    p.rateEB:SetText(AutoVendorSettings.sellRate or 33)
end)

-------------------------------------------------
-- ITEMS (EXCEPTIONS) TAB
-------------------------------------------------
local function Items_Refresh(p)
    local list = {}
    for id, _ in pairs(AutoVendorSettings.exceptions or {}) do
        table.insert(list, id)
    end
    table.sort(list)

    local rowHeight = 30
    for i = 1, #p.rows do p.rows[i]:Hide() end

    for i, id in ipairs(list) do
        local r = p.rows[i]
        if not r then
            r = CreateFrame("Frame", nil, p.content)
            r:SetSize(320, rowHeight)
            r:SetPoint("TOPLEFT", 0, -(i-1)*rowHeight)

            r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.text:SetPoint("LEFT", 5, 0)

            r.remove = CreateFrame("Button", nil, r, "UIPanelCloseButton")
            r.remove:SetPoint("RIGHT", -5, 0)
            r.remove:SetScale(0.7)

            p.rows[i] = r
        end
        r:SetPoint("TOPLEFT", 0, -(i-1)*rowHeight)

        local name, link = GetItemInfo(id)
        r.text:SetText(link or name or ("Item ID: " .. id))

        r.remove:SetScript("OnClick", function()
            AutoVendorSettings.exceptions[id] = nil
            Items_Refresh(p)
        end)

        r:Show()
    end
    p.content:SetHeight(math.max(#list * rowHeight, 1))
end

UI:RegisterTab(2, "Items",
function(p)
    -- Build
    local help = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    help:SetPoint("TOPLEFT", 10, 0)
    help:SetText("Ignored items (will not be sold).\n|cff00ff00Alt + Right Click|r items in bags to add.")

    local sf = CreateFrame("ScrollFrame", "AV_ItemsScrollFrame", p, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 10, -35)
    sf:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(310, 1)
    sf:SetScrollChild(content)

    p.scroll = sf
    p.content = content
    p.rows = {}
end,
function(p)
    -- Refresh
    Items_Refresh(p)
end)

-------------------------------------------------
-- STATS TAB
-------------------------------------------------
local function FormatMoney(amount)
    if not amount or amount == 0 then return "0g 0s 0c" end
    if GetCoinTextureString then
        return GetCoinTextureString(amount)
    end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    return string.format("%dg %ds %dc", gold, silver, copper)
end

UI:RegisterTab(3, "Stats",
function(p)
    -- Build
    p.totalGold = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    p.totalGold:SetPoint("TOPLEFT", 10, 0)

    p.count0 = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.count0:SetPoint("TOPLEFT", 10, -40)

    p.count1 = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.count1:SetPoint("TOPLEFT", 10, -60)

    p.count2 = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.count2:SetPoint("TOPLEFT", 10, -80)

    p.count3 = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.count3:SetPoint("TOPLEFT", 10, -100)

    local resetBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    resetBtn:SetSize(100, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 10, 10)
    resetBtn:SetText("Reset Stats")
    resetBtn:SetScript("OnClick", function()
        AutoVendorSettings.stats = {
            totalGold = 0,
            count0 = 0,
            count1 = 0,
            count2 = 0,
            count3 = 0
        }
        UI:SetTab(3)
    end)
end,
function(p)
    -- Refresh
    local s = AutoVendorSettings.stats or {}
    p.totalGold:SetText("Total Earned: " .. FormatMoney(s.totalGold or 0))
    p.count0:SetText("|cff9d9d9dPoor (Grey):|r " .. (s.count0 or 0))
    p.count1:SetText("|cffffffffCommon (White):|r " .. (s.count1 or 0))
    p.count2:SetText("|cff1eff00Uncommon (Green):|r " .. (s.count2 or 0))
    p.count3:SetText("|cff0070ddRare (Blue):|r " .. (s.count3 or 0))
end)

-------------------------------------------------
-- UI CONTROL
-------------------------------------------------
function UI:Toggle()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        self:SetTab(1)
    end
end

BuildTabButtons()

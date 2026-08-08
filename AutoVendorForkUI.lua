-- AUTOVENDOR FORK UI FOR WOTLK 3.3.5a

AutoVendorUI = {}
local UI = AutoVendorUI
UI.tabs = {}
UI.pages = {}

-------------------------------------------------
-- MAIN FRAME
-------------------------------------------------
local f = CreateFrame("Frame", "AutoVendorMainFrame", UIParent)
f:SetSize(400, 380)
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
title:SetText("|cff00ff00Auto|rVendor Fork")

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
        p:SetSize(360, 250)
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
    local ids = {1, 2} -- Settings, Items
    local names = {"Settings", "Items"}

    for i, id in ipairs(ids) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(100, 24)
        -- Centering the two buttons: total width = 200 + space = 210. Frame width = 400. Offset = (400 - 210)/2 = 95
        b:SetPoint("TOPLEFT", 95 + (i-1)*110, -50)
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
    local sf = CreateFrame("ScrollFrame", "AV_SettingsScrollFrame", p, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 10, 0)
    sf:SetPoint("BOTTOMRIGHT", -30, 0)

    local c = CreateFrame("Frame", nil, sf)
    c:SetSize(310, 240)
    sf:SetScrollChild(c)
    p.content = c

    -- Performance (Rate & Batch)
    local advTitle = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    advTitle:SetPoint("TOPLEFT", 0, -10)
    advTitle:SetText("Performance Settings")

    local rateLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rateLabel:SetPoint("TOPLEFT", advTitle, "BOTTOMLEFT", 0, -20)
    rateLabel:SetText("Sell Rate (batches/sec):")

    local rateEB = CreateFrame("EditBox", "AV_SellRateEB", c, "InputBoxTemplate")
    rateEB:SetSize(50, 20)
    rateEB:SetPoint("LEFT", rateLabel, "RIGHT", 15, 0)
    rateEB:SetAutoFocus(false)
    rateEB:SetNumeric(true)
    rateEB:SetMaxLetters(4)
    rateEB:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 1000 then
            AutoVendorSettingsFork.sellRate = val
        end
    end)
    rateEB:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    c.rateEB = rateEB

    local batchLabel = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    batchLabel:SetPoint("TOPLEFT", rateLabel, "BOTTOMLEFT", 0, -20)
    batchLabel:SetText("Batch Size (items/tick):")

    local batchEB = CreateFrame("EditBox", "AV_BatchSizeEB", c, "InputBoxTemplate")
    batchEB:SetSize(50, 20)
    batchEB:SetPoint("LEFT", batchLabel, "RIGHT", 15, 0)
    batchEB:SetAutoFocus(false)
    batchEB:SetNumeric(true)
    batchEB:SetMaxLetters(2)
    batchEB:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 33 then
            AutoVendorSettingsFork.sellBatchSize = val
        end
    end)
    batchEB:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    c.batchEB = batchEB
end,
function(p)
    -- Refresh
    local c = p.content
    if not c then return end
    c.rateEB:SetText(AutoVendorSettingsFork.sellRate or 3)
    c.batchEB:SetText(AutoVendorSettingsFork.sellBatchSize or 10)
end)

-------------------------------------------------
-- ITEMS (WHITELIST) TAB
-------------------------------------------------
local function Items_Refresh(p)
    local list = {}
    if AutoVendorSettingsFork.exceptions then
        for id, _ in pairs(AutoVendorSettingsFork.exceptions) do
            table.insert(list, id)
        end
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
            AutoVendorSettingsFork.exceptions[id] = nil
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
    help:SetText("Whitelisted items (will be auto-sold).\n|cff00ff00Ctrl + Right Click|r items in bags to add.")

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

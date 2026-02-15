-- AUTOVENDOR UI FOR WOTLK 3.3.5a
-- Inspired by MondDelete

AutoVendorUI = {}
local UI = AutoVendorUI
UI.tabs = {}
UI.pages = {}

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

local function FormatMoneyGPH(amount)
    if not amount or amount == 0 then return "0g 00s 00c" end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    return string.format("%dg %02ds %02dc", gold, silver, copper)
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

-------------------------------------------------
-- INFO TAB
-------------------------------------------------
UI:RegisterTab(4, "Info",
function(p)
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, 0)
    title:SetText("AutoVendor Help")

    local helpText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    helpText:SetPoint("TOPLEFT", 10, -40)
    helpText:SetWidth(340)
    helpText:SetJustifyH("LEFT")
    helpText:SetText([[
|cff00ff00Slash Commands:|r
/av - Toggle this UI
/av add [link] - Add item to exceptions
/av remove [link] - Remove item from exceptions
/av stats - Show lifetime statistics
/av gph [start|pause|stop] - Track Gold Per Hour

|cff00ff00Shortcuts:|r
|cff00ff00Alt + Right Click|r on an item in your bags to toggle it in the exception list.

|cff00ff00Settings:|r
- |cff00ff00Sell Rate:|r How many items to sell per second.
- |cff00ff00Batch Size:|r Maximum items to sell in a single frame.
]])
end,
function(p)
end)

UI.tabButtons = {}
local function BuildTabButtons()
    local ids = {1, 2, 3, 4} -- Settings, Items, Stats, Info
    local names = {"Settings", "Items", "Stats", "Info"}

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
    rateEB:SetMaxLetters(4)
    rateEB:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 1000 then
            AutoVendorSettings.sellRate = val
            print("|cff00ff00AutoVendor:|r Selling rate set to " .. val)
        else
            print("|cffff0000Error:|r Rate must be 1-1000")
            self:SetText(AutoVendorSettings.sellRate or 33)
        end
        self:ClearFocus()
    end)
    p.rateEB = rateEB

    -- Batch Size
    local batchLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    batchLabel:SetPoint("TOPLEFT", rateLabel, "BOTTOMLEFT", 0, -20)
    batchLabel:SetText("Batch Size (items per tick):")

    local batchEB = CreateFrame("EditBox", "AV_BatchSizeEB", p, "InputBoxTemplate")
    batchEB:SetSize(50, 20)
    batchEB:SetPoint("LEFT", batchLabel, "RIGHT", 10, 0)
    batchEB:SetAutoFocus(false)
    batchEB:SetNumeric(true)
    batchEB:SetMaxLetters(2)
    batchEB:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 33 then
            AutoVendorSettings.sellBatchSize = val
            print("|cff00ff00AutoVendor:|r Batch size set to " .. val)
        else
            print("|cffff0000Error:|r Batch size must be 1-33")
            self:SetText(AutoVendorSettings.sellBatchSize or 1)
        end
        self:ClearFocus()
    end)
    p.batchEB = batchEB
end,
function(p)
    -- Refresh
    p.sellGreys:SetChecked(AutoVendorSettings.sellGreys)
    p.sellWhites:SetChecked(AutoVendorSettings.sellWhites)
    p.sellGreens:SetChecked(AutoVendorSettings.sellGreens)
    p.sellBlues:SetChecked(AutoVendorSettings.sellBlues)
    p.rateEB:SetText(AutoVendorSettings.sellRate or 33)
    p.batchEB:SetText(AutoVendorSettings.sellBatchSize or 1)
end)

-------------------------------------------------
-- ITEMS (EXCEPTIONS) TAB
-------------------------------------------------
local function Items_Refresh(p)
    local list = {}
    if AutoVendorSettings.exceptions then
        for id, _ in pairs(AutoVendorSettings.exceptions) do
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
-- GPH OVERLAY
-------------------------------------------------
local gph = CreateFrame("Frame", "AutoVendorGPHFrame", UIParent)
gph:SetSize(260, 130)
gph:SetPoint("CENTER")
gph:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left=4, right=4, top=4, bottom=4 }
})
gph:SetMovable(true)
gph:EnableMouse(true)
gph:RegisterForDrag("LeftButton")
gph:SetScript("OnDragStart", gph.StartMoving)
gph:SetScript("OnDragStop", gph.StopMovingOrSizing)
gph:Hide()

UI.gphFrame = gph

local gphTitle = gph:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gphTitle:SetPoint("TOP", 0, -10)
gphTitle:SetText("GPH Tracker")

-- Time
local timeLabel = gph:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
timeLabel:SetPoint("TOPLEFT", 15, -35)
timeLabel:SetText("Time Elapsed:")

local timeValue = gph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
timeValue:SetPoint("TOPRIGHT", -15, -35)
timeValue:SetJustifyH("RIGHT")

-- Gold
local goldLabel = gph:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
goldLabel:SetPoint("TOPLEFT", 15, -55)
goldLabel:SetText("Gold Earned:")

local goldValue = gph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
goldValue:SetPoint("TOPRIGHT", -15, -55)
goldValue:SetJustifyH("RIGHT")

-- GPH
local gphLabel = gph:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
gphLabel:SetPoint("TOPLEFT", 15, -75)
gphLabel:SetText("Gold Per Hour:")

local gphValue = gph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
gphValue:SetPoint("TOPRIGHT", -15, -75)
gphValue:SetJustifyH("RIGHT")

local function UpdateGPHDisplay()
    local data = AutoVendorGPH
    local elapsed = data.elapsed
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    local s = elapsed % 60
    timeValue:SetText(string.format("%02d:%02d:%02d", h, m, s))
    goldValue:SetText(FormatMoneyGPH(data.goldGained))

    local gphVal = 0
    if elapsed > 0 then
        gphVal = (data.goldGained / elapsed) * 3600
    end
    gphValue:SetText(FormatMoneyGPH(gphVal))
end

local btnStart = CreateFrame("Button", nil, gph, "UIPanelButtonTemplate")
btnStart:SetSize(65, 20)
-- Centering buttons: total width = 65*3 + 5*2 = 195 + 10 = 205.
-- Offset = (260 - 205) / 2 = 27.5
btnStart:SetPoint("BOTTOMLEFT", 28, 15)
btnStart:SetText("Start")

local btnPause = CreateFrame("Button", nil, gph, "UIPanelButtonTemplate")
btnPause:SetSize(65, 20)
btnPause:SetPoint("LEFT", btnStart, "RIGHT", 5, 0)
btnPause:SetText("Pause")

local btnStop = CreateFrame("Button", nil, gph, "UIPanelButtonTemplate")
btnStop:SetSize(65, 20)
btnStop:SetPoint("LEFT", btnPause, "RIGHT", 5, 0)
btnStop:SetText("Stop")

local function UpdateGPHButtons()
    local data = AutoVendorGPH
    if not data.active then
        btnStart:Enable()
        btnStart:SetText("Start")
        btnPause:Disable()
        btnStop:Disable()
    elseif data.paused then
        btnStart:Enable()
        btnStart:SetText("Resume")
        btnPause:Disable()
        btnStop:Enable()
    else
        btnStart:Disable()
        btnPause:Enable()
        btnStop:Enable()
    end
end

btnStart:SetScript("OnClick", function()
    AutoVendorGPH:Start()
    UpdateGPHButtons()
end)

btnPause:SetScript("OnClick", function()
    AutoVendorGPH:Pause()
    UpdateGPHButtons()
end)

btnStop:SetScript("OnClick", function()
    AutoVendorGPH:Stop()
    UpdateGPHButtons()
    UpdateGPHDisplay()
end)

local lastTick = 0
gph:SetScript("OnUpdate", function(self, elapsed)
    lastTick = lastTick + elapsed
    if lastTick >= 1 then
        lastTick = 0
        if AutoVendorGPH.active and not AutoVendorGPH.paused then
            AutoVendorGPH.elapsed = AutoVendorGPH.elapsed + 1
            AutoVendorGPH.goldGained = GetMoney() - AutoVendorGPH.startGold
        end
        UpdateGPHDisplay()
        UpdateGPHButtons()
    end
end)

function UI:ToggleGPH()
    if gph:IsShown() then
        gph:Hide()
    else
        gph:Show()
        UpdateGPHDisplay()
        UpdateGPHButtons()
    end
end

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

-- AUTOVENDOR & AUTOTRASH UI
-- Ported and adapted from MondDelete Pro

AutoVendorUI = {
    tabs = { vendor = {}, trash = {} },
    pages = { vendor = {}, trash = {} },
    currentSection = "vendor",
    frame = nil
}

local function L(key, fallback)
    -- Simplified localization for now
    return fallback
end

-- 1. Main Frame
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

AutoVendorUI.frame = f

CreateFrame("Button", nil, f, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -5, -5)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -15)
title:SetText("|cff00ff00Auto|rVendor & |cff00ff00Auto|rTrash")

-- 2. Section Switcher (Top Buttons)
local vendorSectionBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
vendorSectionBtn:SetSize(120, 30)
vendorSectionBtn:SetPoint("TOPLEFT", 15, -45)
vendorSectionBtn:SetText("AutoVendor")

local trashSectionBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
trashSectionBtn:SetSize(120, 30)
trashSectionBtn:SetPoint("TOPLEFT", 140, -45)
trashSectionBtn:SetText("AutoTrash")

-- 3. Tab System
function AutoVendorUI:RegisterTab(section, id, name, build, refresh)
    self.tabs[section][id] = {
        name = name,
        build = build,
        refresh = refresh
    }
end

local tabButtons = { vendor = {}, trash = {} }

function AutoVendorUI:SetTab(section, id)
    -- Hide all pages
    for s, pMap in pairs(self.pages) do
        for _, p in pairs(pMap) do
            p:Hide()
        end
    end

    local t = self.tabs[section][id]
    if not t then return end

    if not self.pages[section][id] then
        local p = CreateFrame("Frame", nil, self.frame)
        p:SetSize(360, 260)
        p:SetPoint("TOP", 0, -120)
        self.pages[section][id] = p
        t.build(p)
    end

    self.pages[section][id]:Show()
    if t.refresh then
        t.refresh(self.pages[section][id])
    end

    -- Highlight active tab
    for s, bMap in pairs(tabButtons) do
        for tid, btn in pairs(bMap) do
            if s == section and tid == id then
                btn:LockHighlight()
            else
                btn:UnlockHighlight()
            end
        end
    end
end

function AutoVendorUI:UpdateSection(section)
    self.currentSection = section
    if section == "vendor" then
        vendorSectionBtn:LockHighlight()
        trashSectionBtn:UnlockHighlight()
        for _, b in pairs(tabButtons.trash) do b:Hide() end
        for _, b in pairs(tabButtons.vendor) do b:Show() end
        self:SetTab("vendor", 1)
    else
        vendorSectionBtn:UnlockHighlight()
        trashSectionBtn:LockHighlight()
        for _, b in pairs(tabButtons.vendor) do b:Hide() end
        for _, b in pairs(tabButtons.trash) do b:Show() end
        self:SetTab("trash", 1)
    end
end

vendorSectionBtn:SetScript("OnClick", function() AutoVendorUI:UpdateSection("vendor") end)
trashSectionBtn:SetScript("OnClick", function() AutoVendorUI:UpdateSection("trash") end)

local function CreateTabButtons()
    -- Vendor Tabs
    local i = 1
    local vTabs = {1, 2, 3} -- Order
    local vNames = {[1]="Settings", [2]="Exceptions", [3]="Stats"}
    for _, id in ipairs(vTabs) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(80, 24)
        b:SetPoint("TOPLEFT", 15 + (i-1)*85, -85)
        b:SetText(vNames[id])
        b:SetScript("OnClick", function() AutoVendorUI:SetTab("vendor", id) end)
        tabButtons.vendor[id] = b
        i = i + 1
    end

    -- Trash Tabs
    i = 1
    local tTabs = {1, 2, 3, 4}
    local tNames = {[1]="Bags", [2]="Items", [3]="Stats", [4]="Settings"}
    for _, id in ipairs(tTabs) do
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(70, 24)
        b:SetPoint("TOPLEFT", 15 + (i-1)*75, -85)
        b:SetText(tNames[id])
        b:SetScript("OnClick", function() AutoVendorUI:SetTab("trash", id) end)
        tabButtons.trash[id] = b
        b:Hide()
        i = i + 1
    end
end

CreateTabButtons()

-------------------------------------------------
-- PORTED TRASH TABS
-------------------------------------------------

-- BAGS (Trash)
AutoVendorUI:RegisterTab("trash", 1, "Bags",
function(p)
    p.rows = {}
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -5)
    title:SetText("|cff00ff00Select bags to scan for trashing:|r")

    for bag = 0, 4 do
        local r = CreateFrame("Frame", nil, p)
        r:SetSize(300, 36)
        r:SetPoint("TOPLEFT", 10, -25 - bag * 38)
        r.icon = r:CreateTexture(nil, "OVERLAY")
        r.icon:SetSize(32, 32)
        r.icon:SetPoint("LEFT", 0, 0)
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        r.cb:SetPoint("RIGHT", 0, 0)
        r.cb:SetScript("OnClick", function(self)
            AutoVendorSettings.trash.bags[bag] = self:GetChecked()
        end)
        p.rows[bag] = r
    end
end,
function(p)
    for bag = 0, 4 do
        local r = p.rows[bag]
        local icon, text
        if bag == 0 then
            icon = "Interface\\Icons\\INV_Misc_Bag_08"
            text = "Backpack"
        else
            local invID = ContainerIDToInventoryID(bag)
            local itemID = GetInventoryItemID("player", invID)
            if itemID then
                icon = GetItemIcon(itemID)
                text = GetItemInfo(itemID) or ("Bag " .. bag)
            else
                icon = "Interface\\Icons\\INV_Misc_Bag_08"
                text = "Empty Slot"
            end
        end
        r.icon:SetTexture(icon)
        r.text:SetText(text)
        r.cb:SetChecked(AutoVendorSettings.trash.bags[bag])
    end
end)


-- ITEMS (Trash Whitelist)
-- Simplified port of Items.lua from MondDelete
local function Items_Refresh(p)
    local list = {}
    for itemID, _ in pairs(AutoVendorSettings.trash.items) do
        local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
        table.insert(list, {id=itemID, name=name, link=link, quality=quality, icon=icon})
    end
    table.sort(list, function(a,b) return (a.name or "") < (b.name or "") end)

    for i=1, #list do
        local d = list[i]
        local r = p.rows[i]
        if not r then
            r = CreateFrame("Frame", nil, p.content)
            r:SetSize(330, 30)
            r:SetPoint("TOPLEFT", 0, -(i-1)*32)
            r.icon = r:CreateTexture(nil, "OVERLAY")
            r.icon:SetSize(28, 28)
            r.icon:SetPoint("LEFT", 2, 0)
            r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
            r.del = CreateFrame("Button", nil, r, "UIPanelCloseButton")
            r.del:SetPoint("RIGHT", 0, 0)
            r.del:SetScale(0.6)
            r.del:SetScript("OnClick", function(self)
                AutoVendorSettings.trash.items[self:GetParent().itemID] = nil
                Items_Refresh(p)
            end)
            p.rows[i] = r
        end
        r.itemID = d.id
        r.icon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        r.text:SetText(d.link or d.name or ("Item "..d.id))
        r:Show()
    end
    for i=#list+1, #p.rows do p.rows[i]:Hide() end
    p.content:SetHeight(#list * 32)
end

AutoVendorUI:RegisterTab("trash", 2, "Items",
function(p)
    p.rows = {}
    local desc = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 10, -5)
    desc:SetText("|cff00ff00Trash Whitelist:|r Only items in this list will be deleted.")

    p.scroll = CreateFrame("ScrollFrame", "AutoTrashItemsScroll", p, "UIPanelScrollFrameTemplate")
    p.scroll:SetPoint("TOPLEFT", 5, -25)
    p.scroll:SetPoint("BOTTOMRIGHT", -25, 5)
    p.content = CreateFrame("Frame", nil, p.scroll)
    p.content:SetSize(330, 1)
    p.scroll:SetScrollChild(p.content)
end,
function(p)
    Items_Refresh(p)
end)

-- STATS (Trash)
AutoVendorUI:RegisterTab("trash", 3, "Stats",
function(p)
    p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.text:SetPoint("TOPLEFT", 10, -10)
    p.text:SetJustifyH("LEFT")
end,
function(p)
    local stats = AutoVendorSettings.trash.stats
    local txt = "Total items trashed: " .. (stats.total or 0) .. "\n\nTop items deleted:\n"
    local tmp = {}
    for id, c in pairs(stats.itemCounts) do table.insert(tmp, {id=id, c=c}) end
    table.sort(tmp, function(a,b) return a.c > b.c end)
    for i=1, math.min(10, #tmp) do
        local name = GetItemInfo(tmp[i].id) or ("Item "..tmp[i].id)
        txt = txt .. tmp[i].c .. "x " .. name .. "\n"
    end
    p.text:SetText(txt)
end)

-- SETTINGS (Trash)
AutoVendorUI:RegisterTab("trash", 4, "Settings",
function(p)
    local cb = CreateFrame("CheckButton", "AutoTrashEnabledCB", p, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 10, -10)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cb.text:SetText("Enable AutoTrash")
    cb:SetScript("OnClick", function(self)
        AutoVendorSettings.trash.enabled = self:GetChecked()
    end)
    p.cb = cb

    local importBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    importBtn:SetSize(160, 25)
    importBtn:SetPoint("TOPLEFT", 10, -50)
    importBtn:SetText("Import MondDelete")
    importBtn:SetScript("OnClick", function()
        if SlashCmdList["AUTOVENDOR"] then SlashCmdList["AUTOVENDOR"]("import") end
        AutoVendorUI:SetTab("trash", 2) -- Switch to items to see imported
    end)
end,
function(p)
    p.cb:SetChecked(AutoVendorSettings.trash.enabled)
end)


-------------------------------------------------
-- AUTOVENDOR TABS
-------------------------------------------------

-- SETTINGS (Vendor)
AutoVendorUI:RegisterTab("vendor", 1, "Settings",
function(p)
    p.cbs = {}
    local rarities = {
        {key="sellGreys", text="Sell Poor (Grey)"},
        {key="sellWhites", text="Sell Common (White)"},
        {key="sellGreens", text="Sell Uncommon (Green)"},
        {key="sellBlues", text="Sell Rare (Blue)"},
    }
    for i, r in ipairs(rarities) do
        local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 10, -10 - (i-1)*30)
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        cb.text:SetText(r.text)
        cb:SetScript("OnClick", function(self)
            AutoVendorSettings[r.key] = self:GetChecked()
        end)
        p.cbs[r.key] = cb
    end

    local rateTitle = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rateTitle:SetPoint("TOPLEFT", 10, -140)
    rateTitle:SetText("Processing Rate (items/sec):")

    local eb = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    eb:SetSize(50, 25)
    eb:SetPoint("TOPLEFT", 200, -135)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 1 and val <= 1000 then
            AutoVendorSettings.sellRate = val
            print("|cff00ff00AutoVendor:|r Rate set to "..val)
        end
        self:ClearFocus()
    end)
    p.rateEB = eb
end,
function(p)
    p.cbs.sellGreys:SetChecked(AutoVendorSettings.sellGreys)
    p.cbs.sellWhites:SetChecked(AutoVendorSettings.sellWhites)
    p.cbs.sellGreens:SetChecked(AutoVendorSettings.sellGreens)
    p.cbs.sellBlues:SetChecked(AutoVendorSettings.sellBlues)
    p.rateEB:SetText(tostring(AutoVendorSettings.sellRate))
end)

-- EXCEPTIONS (Vendor)
local function Exceptions_Refresh(p)
    local list = {}
    for itemID, _ in pairs(AutoVendorSettings.exceptions) do
        local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
        table.insert(list, {id=itemID, name=name, link=link, quality=quality, icon=icon})
    end
    table.sort(list, function(a,b) return (a.name or "") < (b.name or "") end)

    for i=1, #list do
        local d = list[i]
        local r = p.rows[i]
        if not r then
            r = CreateFrame("Frame", nil, p.content)
            r:SetSize(330, 30)
            r:SetPoint("TOPLEFT", 0, -(i-1)*32)
            r.icon = r:CreateTexture(nil, "OVERLAY")
            r.icon:SetSize(28, 28)
            r.icon:SetPoint("LEFT", 2, 0)
            r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
            r.del = CreateFrame("Button", nil, r, "UIPanelCloseButton")
            r.del:SetPoint("RIGHT", 0, 0)
            r.del:SetScale(0.6)
            r.del:SetScript("OnClick", function(self)
                AutoVendorSettings.exceptions[self:GetParent().itemID] = nil
                Exceptions_Refresh(p)
            end)
            p.rows[i] = r
        end
        r.itemID = d.id
        r.icon:SetTexture(d.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        r.text:SetText(d.link or d.name or ("Item "..d.id))
        r:Show()
    end
    for i=#list+1, #p.rows do p.rows[i]:Hide() end
    p.content:SetHeight(#list * 32)
end

AutoVendorUI:RegisterTab("vendor", 2, "Exceptions",
function(p)
    p.rows = {}
    p.scroll = CreateFrame("ScrollFrame", "AutoVendorExceptionsScroll", p, "UIPanelScrollFrameTemplate")
    p.scroll:SetPoint("TOPLEFT", 5, -5)
    p.scroll:SetPoint("BOTTOMRIGHT", -25, 5)
    p.content = CreateFrame("Frame", nil, p.scroll)
    p.content:SetSize(330, 1)
    p.scroll:SetScrollChild(p.content)
end,
function(p)
    Exceptions_Refresh(p)
end)

-- STATS (Vendor)
AutoVendorUI:RegisterTab("vendor", 3, "Stats",
function(p)
    p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.text:SetPoint("TOPLEFT", 10, -10)
    p.text:SetJustifyH("LEFT")
end,
function(p)
    local stats = AutoVendorSettings.stats
    local txt = "Lifetime Gold Earned: " .. (AutoVendor.FormatMoney(stats.totalGold or 0)) .. "\n\n"
    txt = txt .. "Items Sold by Rarity:\n"
    txt = txt .. "|cff9d9d9dPoor:|r " .. (stats.count0 or 0) .. "\n"
    txt = txt .. "|cffffffffCommon:|r " .. (stats.count1 or 0) .. "\n"
    txt = txt .. "|cff1eff00Uncommon:|r " .. (stats.count2 or 0) .. "\n"
    txt = txt .. "|cff0070ddRare:|r " .. (stats.count3 or 0) .. "\n"
    p.text:SetText(txt)
end)

-- Initialize UI state
AutoVendorUI:UpdateSection("vendor")

-- SLASH COMMAND TO SHOW UI
SLASH_AUTOVENDOR_UI1 = "/avui"
SlashCmdList["AUTOVENDOR_UI"] = function()
    if AutoVendorUI.frame:IsShown() then
        AutoVendorUI.frame:Hide()
    else
        AutoVendorUI.frame:Show()
    end
end

-- Hook into main slash commands to show UI if no arguments
local old_SlashAV = SlashCmdList["AUTOVENDOR"]
SlashCmdList["AUTOVENDOR"] = function(msg)
    if not msg or msg == "" then
        SlashCmdList["AUTOVENDOR_UI"]()
    else
        old_SlashAV(msg)
    end
end

local old_SlashAT = SlashCmdList["AUTOTRASH"]
SlashCmdList["AUTOTRASH"] = function(msg)
    if not msg or msg == "" then
        AutoVendorUI:UpdateSection("trash")
        AutoVendorUI.frame:Show()
    else
        old_SlashAT(msg)
    end
end

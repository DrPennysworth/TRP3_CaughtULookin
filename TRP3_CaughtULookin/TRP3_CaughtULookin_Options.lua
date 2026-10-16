local ADDON_NAME, addon = ...

local DEFAULT_THEME_INDEX = 1

local function GetBuiltinThemeInfo()
    local themes = {}

    if TRP3_API and TRP3_API.ui and TRP3_API.ui.frame and TRP3_API.ui.frame.getTiledBackgroundList then
        local backgrounds = TRP3_API.ui.frame.getTiledBackgroundList() or {}
        for _, entry in ipairs(backgrounds) do
            local index, bgFile = entry[1], entry[2]
            if index and bgFile and type(bgFile) == "string" and bgFile ~= "" then
                themes[tonumber(index)] = {
                    label = bgFile:gsub("^Interface\\", ""):gsub("\\", "/"),
                    path = bgFile,
                }
            end
        end
    end

    if not next(themes) then
        themes = {
            [1] = { label = "DialogFrame/UI-DialogBox-Background", path = "Interface\\DialogFrame\\UI-DialogBox-Background" },
            [2] = { label = "BankFrame/Bank-Background", path = "Interface\\BankFrame\\Bank-Background" },
            [3] = { label = "FrameGeneral/UI-Background-Marble", path = "Interface\\FrameGeneral\\UI-Background-Marble" },
            [4] = { label = "FrameGeneral/UI-Background-Rock", path = "Interface\\FrameGeneral\\UI-Background-Rock" },
            [5] = { label = "GuildBankFrame/GuildVaultBG", path = "Interface\\GuildBankFrame\\GuildVaultBG" },
            [6] = { label = "HELPFRAME/DarkSandstone-Tile", path = "Interface\\HELPFRAME\\DarkSandstone-Tile" },
            [7] = { label = "HELPFRAME/Tileable-Parchment", path = "Interface\\HELPFRAME\\Tileable-Parchment" },
            [8] = { label = "QuestionFrame/question-background", path = "Interface\\QuestionFrame\\question-background" },
        }
    end

    return themes
end

local function ApplyWindowBackdrop(frame, windowKey)
    if not frame then
        return
    end

    local themeIndex = tonumber(CULookinDB.settings[windowKey].theme) or DEFAULT_THEME_INDEX
    if frame:GetBackdrop() and TRP3_API and TRP3_API.ui and TRP3_API.ui.frame and TRP3_API.ui.frame.setBackdropToBackground then
        TRP3_API.ui.frame.setBackdropToBackground(frame, themeIndex)
        return
    end

    local backdrop = frame:GetBackdrop() or {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 64,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    }

    local theme = GetBuiltinThemeInfo()[themeIndex]
    backdrop.bgFile = theme and theme.path or "Interface\\DialogFrame\\UI-DialogBox-Background"
    backdrop.tile = true
    backdrop.tileSize = 64
    if backdrop.edgeSize == nil then
        backdrop.edgeSize = 16
    end
    if not backdrop.insets then
        backdrop.insets = { left = 4, right = 4, top = 4, bottom = 4 }
    end
    frame:SetBackdrop(backdrop)
end

function addon:GetThemeChoices()
    local choices = {}
    for index, info in pairs(GetBuiltinThemeInfo()) do
        choices[tonumber(index)] = info.label
    end
    return choices
end

function addon:EnsureSettings()
    CULookinDB = CULookinDB or {}
    CULookinDB.settings = CULookinDB.settings or {}
    CULookinDB.settings.targetWindow = CULookinDB.settings.targetWindow or {}
    CULookinDB.settings.historyWindow = CULookinDB.settings.historyWindow or {}

    local targetWindow = CULookinDB.settings.targetWindow
    targetWindow.transparency = targetWindow.transparency or 1.0
    targetWindow.rowHeight = targetWindow.rowHeight or 24
    targetWindow.theme = targetWindow.theme or DEFAULT_THEME_INDEX

    local historyWindow = CULookinDB.settings.historyWindow
    historyWindow.transparency = historyWindow.transparency or 1.0
    historyWindow.rowHeight = historyWindow.rowHeight or 34
    historyWindow.theme = historyWindow.theme or DEFAULT_THEME_INDEX
end

function addon:ApplyTransparency()
    addon:EnsureSettings()
    if addon.frame then
        addon.frame:SetAlpha(CULookinDB.settings.targetWindow.transparency)
        ApplyWindowBackdrop(addon.frame, "targetWindow")
    end
    if addon.historyFrame then
        addon.historyFrame:SetAlpha(CULookinDB.settings.historyWindow.transparency)
        ApplyWindowBackdrop(addon.historyFrame, "historyWindow")
    end
end

function addon:GetTargetRowHeight()
    addon:EnsureSettings()
    return CULookinDB.settings.targetWindow.rowHeight
end

function addon:GetHistoryRowHeight()
    addon:EnsureSettings()
    return CULookinDB.settings.historyWindow.rowHeight
end

function addon:OpenOptions()
    local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
    if AceConfigDialog then
        AceConfigDialog:Open("CaughtULookin")
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory("Caught U Lookin")
    else
        print(ADDON_NAME .. ": AceConfig-3.0 is required to open the settings panel.")
    end
end

function addon:RegisterAceOptions()
    if not LibStub then
        return
    end

    local AceConfig = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if not AceConfig or not AceConfigDialog then
        return
    end

    local function GetSetting(windowKey, setting)
        addon:EnsureSettings()
        return CULookinDB.settings[windowKey][setting]
    end

    local function SetSetting(windowKey, setting, value, refresh)
        addon:EnsureSettings()
        CULookinDB.settings[windowKey][setting] = value
        if refresh and addon[refresh] then
            addon[refresh]()
        end
    end

    local options = {
        name = "Caught U Lookin...now with settings!",
        type = "group",
        args = {
            header = { order = 1, type = "description", name = "", fontSize = "medium" },
            targetTransparency = {
                order = 2, type = "range", name = "Target Window Transparency",
                desc = "Set the transparency for the main target window.", min = 0.2, max = 1.0, step = 0.05, isPercent = true,
                get = function() return GetSetting("targetWindow", "transparency") end,
                set = function(_, value) SetSetting("targetWindow", "transparency", value, "ApplyTransparency") end,
            },
            historyTransparency = {
                order = 3, type = "range", name = "History Window Transparency",
                desc = "Set the transparency for the history window.", min = 0.2, max = 1.0, step = 0.05, isPercent = true,
                get = function() return GetSetting("historyWindow", "transparency") end,
                set = function(_, value) SetSetting("historyWindow", "transparency", value, "ApplyTransparency") end,
            },
            targetTheme = {
                order = 4, type = "select", name = "Target Window Theme",
                desc = "Choose the backdrop theme for the main target window.", values = function() return addon:GetThemeChoices() end,
                get = function() return tonumber(GetSetting("targetWindow", "theme")) or DEFAULT_THEME_INDEX end,
                set = function(_, value) SetSetting("targetWindow", "theme", tonumber(value) or DEFAULT_THEME_INDEX, "ApplyTransparency") end,
            },
            historyTheme = {
                order = 5, type = "select", name = "History Window Theme",
                desc = "Choose the backdrop theme for the history window.", values = function() return addon:GetThemeChoices() end,
                get = function() return tonumber(GetSetting("historyWindow", "theme")) or DEFAULT_THEME_INDEX end,
                set = function(_, value) SetSetting("historyWindow", "theme", tonumber(value) or DEFAULT_THEME_INDEX, "ApplyTransparency") end,
            },
            targetRowHeight = {
                order = 6, type = "range", name = "Target Row Height",
                desc = "Set the minimum row height for the main target list.", min = 18, max = 60, step = 1,
                get = function() return GetSetting("targetWindow", "rowHeight") end,
                set = function(_, value) SetSetting("targetWindow", "rowHeight", value, "UpdateDisplay") end,
            },
            historyRowHeight = {
                order = 7, type = "range", name = "History Row Height",
                desc = "Set the minimum row height for history list rows.", min = 18, max = 60, step = 1,
                get = function() return GetSetting("historyWindow", "rowHeight") end,
                set = function(_, value) SetSetting("historyWindow", "rowHeight", value, "UpdateHistoryDisplay") end,
            },
        },
    }

    local addonIcon = "|TInterface\\AddOns\\TRP3_CaughtULookin\\resources\\wow_whoslookin_icon_v2.dxt1.blp:16:16|t"
    AceConfig:RegisterOptionsTable("CaughtULookin", options)
    AceConfigDialog:AddToBlizOptions("CaughtULookin", " Caught U Lookin " .. addonIcon)
end

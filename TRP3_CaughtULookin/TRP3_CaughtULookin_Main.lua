local ADDON_NAME, addon = ...

addon.frame = nil
addon.minimapButton = nil
addon.historyFrame = nil
addon.history = nil
addon.TRP3_NamePlatesUtil = TRP3_NamePlatesUtil

CULookinDB = CULookinDB or {
    pos = { x = 300, y = -250 },
    size = { width = 260, height = 250 },
    minimap = { show = true, lock = false, minimapPos = 225 },
}

local function EnsureMinimapDB()
    CULookinDB = CULookinDB or {}
    CULookinDB.minimap = CULookinDB.minimap or { show = true, lock = false, minimapPos = 225 }
end

local function ToggleMainFrame()
    if not addon.frame then
        addon:InitializeUI()
    end
    if addon.frame then
        if addon.frame:IsShown() then
            addon.frame:Hide()
        else
            addon.frame:Show()
        end
    end
end

local function CreateMinimapSettingsProxy()
    EnsureMinimapDB()

    local function Read(_, key)
        if key == "hide" then
            return not CULookinDB.minimap.show
        elseif key == "lock" then
            return CULookinDB.minimap.lock
        elseif key == "minimapPos" then
            return CULookinDB.minimap.minimapPos
        end
    end

    local function Write(_, key, value)
        if key == "lock" then
            CULookinDB.minimap.lock = value
        elseif key == "minimapPos" then
            CULookinDB.minimap.minimapPos = value
        end
    end

    return setmetatable({}, { __index = Read, __newindex = Write })
end


function addon:CreateMinimapButton()
    if addon.minimapButton then
        return
    end

    local ldbAvailable = type(LibStub) == "function"
    if ldbAvailable then
        local LibDataBroker = LibStub:GetLibrary("LibDataBroker-1.1", true)
        local LibDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
        local LibDBCompartment = LibStub:GetLibrary("LibDBCompartment-1.0", true)
        if LibDataBroker and LibDBIcon then
            EnsureMinimapDB()

            local objectName = "Total RP 3: Caught U Lookin"
            local object = LibDataBroker:NewDataObject(objectName, {
                type = "launcher",
                icon = "Interface\\AddOns\\TRP3_CaughtULookin\\resources\\INV_Misc_Eye_01.blp",
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        ToggleMainFrame()
                    elseif button == "RightButton" then
                        addon:ToggleHistoryWindow()
                    end
                end,
                OnTooltipShow = function(tooltip)
                    tooltip:AddLine("Caught U Lookin")
                    tooltip:AddLine("Left-click: toggle |cff00ff00Target Window|r", 1, 1, 1)
                    tooltip:AddLine("Right-click: toggle |cff00ff00History Window|r", 1, 1, 1)
                end,
            })

            addon.minimapButton = object
            LibDBIcon:Register(objectName, object, CreateMinimapSettingsProxy())
            if LibDBCompartment then
                LibDBCompartment:Register(objectName, object)
            end

            if CULookinDB.minimap.show then
                LibDBIcon:Refresh(objectName)
            else
                LibDBIcon:Hide(objectName)
            end
            return
        end
    end
end

function addon:OpenTRP3Profile(unit, realName)
    if not realName or realName == "" then
        return
    end

    if TRP3_API and TRP3_API.utils and TRP3_API.utils.str and TRP3_API.utils.str.getUnitID and TRP3_API.register and TRP3_API.register.getUnitIDCurrentProfileSafe and TRP3_API.register.openPageByProfileID and TRP3_API.navigation and TRP3_API.navigation.openMainFrame then
        local unitID = TRP3_API.utils.str.getUnitID(unit)
        if not unitID and type(unit) == "string" then
            local profile = TRP3_API.register.getUnitIDCurrentProfileSafe(unit)
            if profile and next(profile) or unit:find(":") then
                unitID = unit
            end
        end
        if unitID then
            local profile = TRP3_API.register.getUnitIDCurrentProfileSafe(unitID)
            if profile and profile.profileID then
                TRP3_API.register.openPageByProfileID(profile.profileID)
                TRP3_API.navigation.openMainFrame()
                return
            end
            if TRP3_API.register.openPageByUnitID then
                TRP3_API.register.openPageByUnitID(unitID)
                TRP3_API.navigation.openMainFrame()
                return
            end
            -- TRP3 knows the unit ID, but the profile data is not yet ready. Fall back to the chat opener
            -- so we can still attempt to open the profile by name.
            local fullName = addon:MakeFullName(realName)
            local command = "/trp3 open " .. fullName
            ChatFrame_OpenChat(command)
            C_Timer.After(0.1, function()
                local editBox = ChatEdit_GetActiveWindow()
                if editBox then
                    ChatEdit_SendText(editBox)
                end
            end)
            return
        end
    end

    local fullName = addon:MakeFullName(realName)
    local command = "/trp3 open " .. fullName
    ChatFrame_OpenChat(command)
    C_Timer.After(0.1, function()
        local editBox = ChatEdit_GetActiveWindow()
        if editBox then
            ChatEdit_SendText(editBox)
        end
    end)
end

function addon:InitializeUI()
    if addon.frame then
        return
    end

    addon.history = CULookinDB.history or {}
    CULookinDB.history = addon.history

    addon.frame = _G["CULookinFrame"]
    if not addon.frame then
        return
    end

    addon.frame:SetFrameStrata("MEDIUM")
    addon.frame:SetFrameLevel(5)

    addon.frame.header = _G["CULookinHeader"]
    addon.frame.clearButton = _G["CULookinClearButton"]
    addon.frame.historyButton = _G["CULookinHistoryButton"]

    addon.frame:SetSize(CULookinDB.size.width, CULookinDB.size.height)
    addon.frame:ClearAllPoints()
    addon.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", CULookinDB.pos.x, CULookinDB.pos.y)

    if addon.InitializeListUI then
        addon:InitializeListUI()
    end

    if addon.InitializeCopyDialog then
        addon:InitializeCopyDialog()
    end

    if addon.frame.historyButton then
        addon.frame.historyButton:SetScript("OnClick", function()
            addon:ToggleHistoryWindow()
        end)
    end

    if TRP3_API and TRP3_Addon and TRP3_API.RegisterCallback and TRP3_Addon.Events and TRP3_Addon.Events.REGISTER_DATA_UPDATED then
        TRP3_API.RegisterCallback(TRP3_Addon, TRP3_Addon.Events.REGISTER_DATA_UPDATED, function(_, unitID)
            if addon.RefreshTRP3ForUnitID then
                addon:RefreshTRP3ForUnitID(unitID)
            end
        end)
    end

    addon.frame:SetScript("OnSizeChanged", function(self, width, height)
        local minWidth, minHeight = 180, 100
        if width < minWidth then
            self:SetWidth(minWidth)
        end
        if height < minHeight then
            self:SetHeight(minHeight)
        end
        CULookinDB.size.width = self:GetWidth()
        CULookinDB.size.height = self:GetHeight()
        if addon.UpdateDisplay then
            addon:UpdateDisplay()
        end
    end)

    addon.frame:SetScript("OnShow", function()
        if addon.UpdateDisplay then
            addon:UpdateDisplay()
        end
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        addon:InitializeUI()
        addon:CreateMinimapButton()
        if addon.frame then
            addon.frame:Show()
        end
        if addon.CheckAllNameplates then
            addon:CheckAllNameplates()
        end
        C_Timer.NewTicker(1.5, function()
            if addon.CheckAllNameplates then
                addon:CheckAllNameplates()
            end
            if addon.RefreshPendingTRP3Profiles then
                addon:RefreshPendingTRP3Profiles()
            end
        end)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        self:RegisterEvent("FORBIDDEN_NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("FORBIDDEN_NAME_PLATE_UNIT_REMOVED")
        self:RegisterEvent("UNIT_TARGET")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" or event == "FORBIDDEN_NAME_PLATE_UNIT_ADDED" or event == "FORBIDDEN_NAME_PLATE_UNIT_REMOVED" or event == "UNIT_TARGET" then
        C_Timer.After(0.1, function()
            if addon.CheckAllNameplates then
                addon:CheckAllNameplates()
            end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if addon.UpdateDisplay then
            addon:UpdateDisplay()
        end
    end
end)

SLASH_CULOOKIN1 = "/culookin"
SLASH_CULOOKIN2 = "/culook"
SlashCmdList["CULOOKIN"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "history" then
        addon:OpenHistoryWindow()
    elseif msg == "hide" then
        if addon.frame then
            addon.frame:Hide()
        end
    elseif msg == "show" then
        if addon.frame then
            addon.frame:Show()
        end
    elseif msg == "reset" then
        CULookinDB = nil
        ReloadUI()
    else
        if not addon.frame then
            addon:InitializeUI()
        end
        if addon.frame then
            if addon.frame:IsShown() then
                addon.frame:Hide()
            else
                addon.frame:Show()
            end
        end
    end
end

print(ADDON_NAME .. " loaded. Use /culookin to open the window. Friendly nameplates must be enabled.")

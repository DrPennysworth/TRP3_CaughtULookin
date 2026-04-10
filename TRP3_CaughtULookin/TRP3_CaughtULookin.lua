local ADDON_NAME, addon = ...
local frame
local minimapButton
local targetingPlayers = {}
local namePool = {}
local TRP3_NamePlatesUtil = TRP3_NamePlatesUtil

CULookinDB = CULookinDB or {
    pos = { x = 300, y = -250 },
    size = { width = 260, height = 250 },
    minimap = { show = true, lock = false, minimapPos = 225 },
}

local function CreateMinimapSettingsProxy()
    CULookinDB.minimap = CULookinDB.minimap or { show = true, lock = false, minimapPos = 225 }

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

local function CreateFallbackMinimapButton()
    if minimapButton or not Minimap then
        return
    end

    CULookinDB.minimap = CULookinDB.minimap or { show = true, lock = false, minimapPos = 225 }

    local button = CreateFrame("Button", "CULookinMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\MINIMAP\\MiniMap-TrackingBorder")
    bg:SetAllPoints()

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    icon:SetPoint("CENTER", 0, 0)
    icon:SetSize(18, 18)

    local function ToggleFrame()
        if not frame then
            addon:InitializeUI()
        end
        if frame then
            if frame:IsShown() then
                frame:Hide()
            else
                frame:Show()
            end
        end
    end

    button:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ToggleFrame()
        elseif button == "RightButton" then
            CULookinDB.minimap.show = not CULookinDB.minimap.show
            self:SetShown(CULookinDB.minimap.show)
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Caught U Lookin")
        GameTooltip:AddLine("Left-click: toggle window", 1, 1, 1)
        GameTooltip:AddLine("Right-click: hide button", 1, 1, 1)
        GameTooltip:AddLine("Drag: reposition", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        if not CULookinDB.minimap.lock then
            self:StartMoving()
        end
    end)

    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local mx, my = Minimap:GetCenter()
        if x and y and mx and my then
            local angle = math.deg(math.atan2(y - my, x - mx))
            if angle < 0 then
                angle = angle + 360
            end
            CULookinDB.minimap.minimapPos = angle
            local rad = math.rad(angle)
            local radius = 80
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
        end
    end)

    local function PositionButton()
        local angle = CULookinDB.minimap.minimapPos or 225
        local rad = math.rad(angle)
        local radius = 80
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
    end

    PositionButton()
    button:SetShown(CULookinDB.minimap.show)
    minimapButton = button
end

function addon:CreateMinimapButton()
    if minimapButton then
        return
    end

    local ldbAvailable = type(LibStub) == "function"
    if ldbAvailable then
        local LibDataBroker = LibStub:GetLibrary("LibDataBroker-1.1", true)
        local LibDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
        local LibDBCompartment = LibStub:GetLibrary("LibDBCompartment-1.0", true)
        if LibDataBroker and LibDBIcon then
            CULookinDB.minimap = CULookinDB.minimap or { show = true, lock = false, minimapPos = 225 }

            local objectName = "Total RP 3: Caught U Lookin"
            local object = LibDataBroker:NewDataObject(objectName, {
                type = "launcher",
                icon = "Interface\\Icons\\INV_Misc_Map_01",
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        if not frame then
                            addon:InitializeUI()
                        end
                        if frame then
                            if frame:IsShown() then
                                frame:Hide()
                            else
                                frame:Show()
                            end
                        end
                    elseif button == "RightButton" then
                        CULookinDB.minimap.show = not CULookinDB.minimap.show
                        if CULookinDB.minimap.show then
                            LibDBIcon:Refresh(objectName)
                        else
                            LibDBIcon:Hide(objectName)
                        end
                    end
                end,
                OnTooltipShow = function(tooltip)
                    tooltip:AddLine("Caught U Lookin")
                    tooltip:AddLine("Left-click: toggle window", 1, 1, 1)
                    tooltip:AddLine("Right-click: hide button", 1, 1, 1)
                end,
            })

            minimapButton = object
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

    CreateFallbackMinimapButton()
end

local function GetTRP3IconMarkup(unit)
    if TRP3_API and TRP3_API.utils and TRP3_API.utils.str and TRP3_API.utils.str.getUnitID and TRP3_API.utils.str.icon and TRP3_API.register and TRP3_API.register.getUnitIDCurrentProfileSafe then
        local unitID = TRP3_API.utils.str.getUnitID(unit)
        if unitID then
            local profile = TRP3_API.register.getUnitIDCurrentProfileSafe(unitID)
            if profile and profile.characteristics then
                local icon = profile.characteristics.IC
                if not icon and TRP3_InterfaceIcons and TRP3_InterfaceIcons.ProfileDefault then
                    icon = TRP3_InterfaceIcons.ProfileDefault
                end
                if icon then
                    return TRP3_API.utils.str.icon(icon, 15) .. " "
                end
            end
        end
    end
    return ""
end

local function GetTRP3Name(unit, realName)
    if TRP3_API and TRP3_API.utils and TRP3_API.utils.str and TRP3_API.utils.str.getUnitID then
        local unitID = TRP3_API.utils.str.getUnitID(unit)
        if unitID then
            if TRP3_API.chat and TRP3_API.chat.getFullnameForUnitUsingChatMethod then
                local trpName = TRP3_API.chat.getFullnameForUnitUsingChatMethod(unitID)
                if trpName and trpName ~= "" then
                    return trpName
                end
            end
            if TRP3_API.register and TRP3_API.register.getUnitRPName then
                local name = TRP3_API.register.getUnitRPName(unit)
                if name and name ~= "" then
                    return name
                end
            end
            if TRP3_API.register and TRP3_API.register.getUnitIDCurrentProfileSafe and TRP3_API.register.getCompleteName then
                local profile = TRP3_API.register.getUnitIDCurrentProfileSafe(unitID)
                if profile and profile.characteristics then
                    local completeName = TRP3_API.register.getCompleteName(profile.characteristics, profile.profileName or realName, true)
                    if completeName and completeName ~= "" then
                        if profile.characteristics.CH and TRP3_API.CreateColorFromHexString then
                            local colorFunction = TRP3_API.CreateColorFromHexString(profile.characteristics.CH)
                            if colorFunction then
                                return colorFunction(completeName)
                            end
                        end
                        return completeName
                    end
                end
            end
        end
    end
    return nil
end

local function MakeFullName(name)
    if string.find(name, "-") then
        return name
    end
    local realm = GetRealmName():gsub("%s+", "")
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

local function OpenTRP3Profile(unit, realName)
    if not realName or realName == "" then
        return
    end

    if TRP3_API and TRP3_API.utils and TRP3_API.utils.str and TRP3_API.utils.str.getUnitID and TRP3_API.register and TRP3_API.register.getUnitIDCurrentProfileSafe and TRP3_API.register.openPageByProfileID and TRP3_API.navigation and TRP3_API.navigation.openMainFrame then
        local unitID = TRP3_API.utils.str.getUnitID(unit)
        if unitID then
            local profile = TRP3_API.register.getUnitIDCurrentProfileSafe(unitID)
            if profile and profile.profileID then
                TRP3_API.register.openPageByProfileID(profile.profileID)
                TRP3_API.navigation.openMainFrame()
                return
            end
        end
    end

    local fullName = MakeFullName(realName)
    local command = "/trp3 open " .. fullName
    ChatFrame_OpenChat(command)
    C_Timer.After(0.1, function()
        local editBox = ChatEdit_GetActiveWindow()
        if editBox then
            ChatEdit_SendText(editBox)
        end
    end)
end

local function UpdateDisplay()
    if not frame or not frame:IsShown() then
        return
    end

    local hasRecent = false
    for _, data in pairs(targetingPlayers) do
        if not data.isTargeting then
            hasRecent = true
            break
        end
    end

    if frame.clearButton then
        frame.clearButton:SetShown(hasRecent)
    end

    table.wipe(namePool)
    for _, data in pairs(targetingPlayers) do
        table.insert(namePool, data)
    end

    table.sort(namePool, function(a, b)
        if a.isTargeting ~= b.isTargeting then
            return a.isTargeting
        end
        return a.lastSeen > b.lastSeen
    end)

    for _, line in ipairs(frame.lines or {}) do
        line:Hide()
    end

    local top = 28
    local lineHeight = 18
    local bottom = hasRecent and 30 or 8

    for i, data in ipairs(namePool) do
        local line = frame.lines[i]
        if not line then
            break
        end
        line:SetSize(frame:GetWidth() - 16, 16)
        line.unit = data.unit
        line.realName = data.realName
        line.fontString:SetTextColor(1, 1, 1)

        local visibleName
        if data.trpName and data.trpName ~= "" and data.trpName ~= data.realName then
            visibleName = (data.iconMarkup or "") .. data.trpName .. " (" .. data.realName .. ")"
        else
            visibleName = (data.iconMarkup or "") .. data.realName
        end

        local status = data.isTargeting and "" or " |cff808080(recent)|r"
        line.fontString:SetText(visibleName .. status)

        line.hasTRP3 = data.trpName and data.trpName ~= ""

        line:ClearAllPoints()
        if i == 1 then
            line:SetPoint("TOPLEFT", 8, -top)
        else
            line:SetPoint("TOPLEFT", frame.lines[i - 1], "BOTTOMLEFT", 0, -2)
        end
        line:Show()
    end

    local neededHeight = top + bottom + (#namePool * lineHeight)
    neededHeight = math.max(100, math.min(neededHeight, 400))
    frame:SetHeight(neededHeight)
end

local function AddOrUpdatePlayer(realName, trpName, iconMarkup, unit)
    if not realName or realName == "" then
        return
    end
    local guid = UnitGUID(unit)
    if not guid then
        return
    end
    local _, class = GetPlayerInfoByGUID(guid)
    targetingPlayers[realName] = {
        realName = realName,
        trpName = trpName,
        iconMarkup = iconMarkup,
        unit = unit,
        isTargeting = true,
        lastSeen = GetTime(),
        class = class,
    }
end

local function CheckAllNameplates()
    if targetingPlayers[UnitName("player")] then
        targetingPlayers[UnitName("player")] = nil
    end

    local currentlyTargeting = {}
    for _, npFrame in ipairs(C_NamePlate.GetNamePlates()) do
        if npFrame and npFrame:IsShown() then
            local unit = (TRP3_NamePlatesUtil and TRP3_NamePlatesUtil.GetNameplateUnit and TRP3_NamePlatesUtil.GetNameplateUnit(npFrame)) or npFrame.namePlateUnitToken or npFrame.unitToken
            if unit and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") and UnitIsUnit(unit .. "target", "player") then
                local realName = UnitName(unit)
                local trpName = GetTRP3Name(unit, realName)
                local iconMarkup = GetTRP3IconMarkup(unit)
                currentlyTargeting[realName] = true
                AddOrUpdatePlayer(realName, trpName, iconMarkup, unit)
            end
        end
    end

    for name, data in pairs(targetingPlayers) do
        if data.isTargeting and not currentlyTargeting[name] then
            data.isTargeting = false
            data.lastSeen = GetTime()
        end
    end

    for name, data in pairs(targetingPlayers) do
        if not data.isTargeting and (GetTime() - data.lastSeen) > 300 then
            targetingPlayers[name] = nil
        end
    end

    UpdateDisplay()
end

function addon:InitializeUI()
    if frame then
        return
    end

    frame = _G["CULookinFrame"]
    if not frame then
        return
    end

    frame:SetSize(CULookinDB.size.width, CULookinDB.size.height)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", CULookinDB.pos.x, CULookinDB.pos.y)

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
        frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    frame.lines = frame.lines or {}
    for i = 1, 15 do
        if not frame.lines[i] then
            local line = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
            line:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")
            line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            line:SetAttribute("type1", "none")
            line:SetAttribute("type2", "none")
            line:SetAttribute("unit", nil)
            line:SetAttribute("macrotext1", "")
            line:SetAttribute("macrotext2", "")
            local fs = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            fs:SetAllPoints(true)
            fs:SetJustifyH("LEFT")
            line.fontString = fs
            line:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    if self.hasTRP3 and self.realName then
                        OpenTRP3Profile(self.unit, self.realName)
                    else
                        print("|cff00ff00Caught U Lookin:|r TRP3 profile not available. Only you can see this player.")
                    end
                elseif button == "RightButton" then
                    if self.realName then
                        ChatFrame_OpenChat(self.realName)
                    end
                end
            end)
            line:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Caught U Lookin")
                GameTooltip:AddLine("Left-click: open TRP3 profile", 1, 1, 1)
                GameTooltip:AddLine("Right-click: insert real name in chat", 1, 1, 1)
                GameTooltip:Show()
            end)
            line:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            frame.lines[i] = line
        end
    end

    frame.clearButton = _G["CULookinClearButton"]
    if frame.clearButton then
        frame.clearButton:SetText("Clear Recent")
        frame.clearButton:SetScript("OnClick", function()
            local keep = {}
            for name, data in pairs(targetingPlayers) do
                if data.isTargeting then
                    keep[name] = data
                end
            end
            targetingPlayers = keep
            UpdateDisplay()
        end)
    end

    local header = _G["CULookinHeader"]
    if header and not header.title then
        local title = header:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        title:SetAllPoints(true)
        title:SetJustifyH("CENTER")
        title:SetJustifyV("MIDDLE")
        title:SetText("Caught U Lookin")
        header.title = title
    end

    frame:SetScript("OnSizeChanged", function(self, width, height)
        local minWidth, minHeight = 180, 100
        if width < minWidth then
            self:SetWidth(minWidth)
        end
        if height < minHeight then
            self:SetHeight(minHeight)
        end
        CULookinDB.size.width = self:GetWidth()
        CULookinDB.size.height = self:GetHeight()
        UpdateDisplay()
    end)

    frame:SetScript("OnShow", UpdateDisplay)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        addon:InitializeUI()
        addon:CreateMinimapButton()
        if frame then
            frame:Show()
        end
        CheckAllNameplates()
        C_Timer.NewTicker(1.5, CheckAllNameplates)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        self:RegisterEvent("FORBIDDEN_NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("FORBIDDEN_NAME_PLATE_UNIT_REMOVED")
        self:RegisterEvent("UNIT_TARGET")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" or event == "FORBIDDEN_NAME_PLATE_UNIT_ADDED" or event == "FORBIDDEN_NAME_PLATE_UNIT_REMOVED" or event == "UNIT_TARGET" then
        C_Timer.After(0.1, CheckAllNameplates)
    elseif event == "PLAYER_REGEN_ENABLED" then
        UpdateDisplay()
    end
end)

SLASH_CULOOKIN1 = "/culookin"
SLASH_CULOOKIN2 = "/culook"
SlashCmdList["CULOOKIN"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "hide" then
        if frame then
            frame:Hide()
        end
    elseif msg == "show" then
        if frame then
            frame:Show()
        end
    elseif msg == "reset" then
        CULookinDB = nil
        ReloadUI()
    else
        if not frame then
            addon:InitializeUI()
        end
        if frame then
            if frame:IsShown() then
                frame:Hide()
            else
                frame:Show()
            end
        end
    end
end

print(ADDON_NAME .. " loaded. Use /culookin to open the window. Friendly nameplates must be enabled.")

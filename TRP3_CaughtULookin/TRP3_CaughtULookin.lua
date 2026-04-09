local ADDON_NAME, addon = ...
local frame
local targetingPlayers = {}
local namePool = {}
local TRP3_NamePlatesUtil = TRP3_NamePlatesUtil

CULookinDB = CULookinDB or {
    pos = { x = 300, y = -250 },
    size = { width = 260, height = 250 },
}

local function GetDisplayName(unit, realName)
    if TRP3_API and TRP3_API.chat and TRP3_API.chat.getFullnameForUnitUsingChatMethod and TRP3_API.utils and TRP3_API.utils.str and TRP3_API.utils.str.getUnitID then
        local trpName = TRP3_API.chat.getFullnameForUnitUsingChatMethod(TRP3_API.utils.str.getUnitID(unit))
        if trpName and trpName ~= "" then
            return trpName
        end
    end
    return realName
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

local function OpenTRP3Profile(realName)
    if not realName or realName == "" then
        return
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
        if data.unit and UnitExists(data.unit) and not InCombatLockdown() then
            line:SetAttribute("unit", data.unit)
        end
        line.fontString:SetTextColor(1, 1, 1)

        local status = data.isTargeting and "" or " |cff808080(recent)|r"
        line.fontString:SetText(data.displayName .. status)

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

local function AddOrUpdatePlayer(realName, displayName, unit)
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
        displayName = displayName,
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
                local displayName = GetDisplayName(unit, realName)
                currentlyTargeting[realName] = true
                AddOrUpdatePlayer(realName, displayName, unit)
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
            line:SetAttribute("type1", "target")
            line:SetAttribute("type2", "" )
            line:SetAttribute("unit", nil)
            local fs = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            fs:SetAllPoints(true)
            fs:SetJustifyH("LEFT")
            line.fontString = fs
            line:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                    if self.realName then
                        OpenTRP3Profile(self.realName)
                    end
                end
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

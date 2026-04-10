local ADDON_NAME, addon = ...

addon.targetingPlayers = {}
addon.namePool = {}

local function StripTRP3ColorCodes(text)
    if not text then
        return text
    end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

function addon:MakeFullName(name)
    if string.find(name, "-") then
        return name
    end
    local realm = GetRealmName():gsub("%s+", "")
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

function addon:GetTRP3UnitID(unit)
    if TRP3_API and TRP3_API.utils and TRP3_API.utils.str and TRP3_API.utils.str.getUnitID then
        return TRP3_API.utils.str.getUnitID(unit)
    end
    return nil
end

function addon:GetTRP3Profile(unitOrUnitID)
    if TRP3_API and TRP3_API.register and TRP3_API.register.getUnitIDCurrentProfileSafe then
        local unitID = addon:GetTRP3UnitID(unitOrUnitID)
        if not unitID and type(unitOrUnitID) == "string" then
            local profile = TRP3_API.register.getUnitIDCurrentProfileSafe(unitOrUnitID)
            if profile or unitOrUnitID:find(":") then
                unitID = unitOrUnitID
            end
        end
        if unitID then
            return TRP3_API.register.getUnitIDCurrentProfileSafe(unitID), unitID
        end
    end
    return nil, nil
end

function addon:GetTRP3IconMarkup(unitOrUnitID)
    local profile = addon:GetTRP3Profile(unitOrUnitID)
    if profile and profile.characteristics then
        local icon = profile.characteristics.IC
        if not icon and TRP3_InterfaceIcons and TRP3_InterfaceIcons.ProfileDefault then
            icon = TRP3_InterfaceIcons.ProfileDefault
        end
        if icon and TRP3_API and TRP3_API.utils and TRP3_API.utils.str and TRP3_API.utils.str.icon then
            return TRP3_API.utils.str.icon(icon, 15) .. " "
        end
    end
    return ""
end

local function HexToRGB(hex)
    if not hex then
        return nil
    end
    hex = tostring(hex):gsub("^#", "")
    local r, g, b = hex:match("^(%x%x)(%x%x)(%x%x)$")
    if not r then
        return nil
    end
    return {
        r = tonumber(r, 16) / 255,
        g = tonumber(g, 16) / 255,
        b = tonumber(b, 16) / 255,
    }
end

function addon:GetTRP3Color(unitOrUnitID)
    local profile = addon:GetTRP3Profile(unitOrUnitID)
    if profile and profile.characteristics and profile.characteristics.CH then
        return HexToRGB(profile.characteristics.CH)
    end
    return nil
end

function addon:RefreshTRP3ForUnitID(unitID)
    if not unitID or type(unitID) ~= "string" then
        return
    end

    local updated = false
    local function updateEntry(data)
        if not data or not data.realName then
            return
        end
        local newTRPName, newPending = addon:GetTRP3Name(unitID, data.realName)
        local newIconMarkup = addon:GetTRP3IconMarkup(unitID)
        local newTRPColor = addon:GetTRP3Color(unitID)
        if data.trpName ~= newTRPName or data.iconMarkup ~= newIconMarkup or data.trpColor ~= newTRPColor or data.pendingTRP3 ~= newPending then
            data.trpName = newTRPName
            data.iconMarkup = newIconMarkup
            data.trpColor = newTRPColor
            data.pendingTRP3 = newPending
            updated = true
        end
    end

    for _, data in pairs(addon.targetingPlayers) do
        if data.unitID == unitID then
            updateEntry(data)
        end
    end

    for _, entry in pairs(addon.history or {}) do
        if entry.unitID == unitID then
            updateEntry(entry)
        end
    end

    if updated then
        if addon.frame and addon.frame:IsShown() and addon.UpdateDisplay then
            addon:UpdateDisplay()
        end
        if addon.historyFrame and addon.historyFrame:IsShown() and addon.UpdateHistoryDisplay then
            addon:UpdateHistoryDisplay()
        end
        if addon.pendingTRP3Profiles then
            addon.pendingTRP3Profiles[unitID] = nil
        end
    end
end

function addon:RefreshPendingTRP3Profiles()
    if addon.pendingProfileOpen then
        local pending = addon.pendingProfileOpen
        if pending.unitID and TRP3_API and TRP3_API.register and TRP3_API.register.getUnitIDCurrentProfileSafe and TRP3_API.register.openPageByProfileID and TRP3_API.navigation and TRP3_API.navigation.openMainFrame then
            local profile = TRP3_API.register.getUnitIDCurrentProfileSafe(pending.unitID)
            if profile and profile.profileID then
                TRP3_API.register.openPageByProfileID(profile.profileID)
                TRP3_API.navigation.openMainFrame()
                addon.pendingProfileOpen = nil
            end
        end
    end

    if not addon.pendingTRP3Profiles then
        return
    end
    for unitID in pairs(addon.pendingTRP3Profiles) do
        addon:RefreshTRP3ForUnitID(unitID)
    end
end

function addon:GetTRP3Name(unitOrUnitID, realName)
    if not realName or realName == "" then
        return realName
    end

    local unitID = addon:GetTRP3UnitID(unitOrUnitID)
    if not unitID and type(unitOrUnitID) == "string" then
        unitID = unitOrUnitID
    end
    local profile = addon:GetTRP3Profile(unitOrUnitID)
    local trpName

    if TRP3_API and TRP3_API.chat and TRP3_API.chat.getFullnameForUnitUsingChatMethod and unitID then
        trpName = TRP3_API.chat.getFullnameForUnitUsingChatMethod(unitID)
        if trpName and trpName ~= "" then
            if profile and profile.characteristics and profile.characteristics.CH and TRP3_API.CreateColorFromHexString then
                local colorFunction = TRP3_API.CreateColorFromHexString(profile.characteristics.CH)
                if colorFunction then
                    return colorFunction(trpName), false
                end
            end
            return trpName, false
        end
    end

    if TRP3_API and TRP3_API.register and TRP3_API.register.getUnitRPName then
        local name = TRP3_API.register.getUnitRPName(unitOrUnitID)
        if name and name ~= "" then
            if profile and profile.characteristics and profile.characteristics.CH and TRP3_API.CreateColorFromHexString then
                local colorFunction = TRP3_API.CreateColorFromHexString(profile.characteristics.CH)
                if colorFunction then
                    return colorFunction(name), false
                end
            end
            return name, false
        end
    end

    if TRP3_API and TRP3_API.register and TRP3_API.register.getCompleteName and profile and profile.characteristics then
        local completeName = TRP3_API.register.getCompleteName(profile.characteristics, profile.profileName or realName, true)
        if completeName and completeName ~= "" then
            if profile.characteristics.CH and TRP3_API.CreateColorFromHexString then
                local colorFunction = TRP3_API.CreateColorFromHexString(profile.characteristics.CH)
                if colorFunction then
                    return colorFunction(completeName), false
                end
            end
            return completeName, false
        end
    end

    if unitID then
        addon.pendingTRP3Profiles = addon.pendingTRP3Profiles or {}
        addon.pendingTRP3Profiles[unitID] = true
        return realName, true
    end

    return realName, false
end

function addon:InitializeListUI()
    local frame = addon.frame
    if not frame then
        return
    end

    frame.lines = {}
    frame.scrollFrame = _G["CULookinScrollFrame"]
    frame.scrollChild = _G["CULookinScrollFrameChild"] or _G["CULookinScrollFrameScrollChild"]
    if frame.scrollFrame and frame.scrollChild then
        if frame.scrollFrame.SetScrollChild then
            frame.scrollFrame:SetScrollChild(frame.scrollChild)
        end
        frame.scrollFrame:EnableMouseWheel(true)
        frame.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local current = self:GetVerticalScroll()
            local range = self:GetVerticalScrollRange()
            local step = 20
            self:SetVerticalScroll(math.max(0, math.min(current - delta * step, range)))
        end)
    end
    local scrollChild = frame.scrollChild or frame
    for i = 1, 50 do
        if not frame.lines[i] then
            local line = addon:CreateListRow("CULookinListRow" .. i, scrollChild)
            frame.lines[i] = line
        end
    end

    if frame.clearButton then
        frame.clearButton:SetText("Clear Recent")
        frame.clearButton:SetScript("OnClick", function()
            local keep = {}
            for name, data in pairs(addon.targetingPlayers) do
                if data.isTargeting then
                    keep[name] = data
                end
            end
            addon.targetingPlayers = keep
            addon:UpdateDisplay()
        end)
    end
end

function addon:UpdateDisplay()
    local frame = addon.frame
    if not frame or not frame:IsShown() then
        return
    end

    local hasRecent = false
    for _, data in pairs(addon.targetingPlayers) do
        if not data.isTargeting then
            hasRecent = true
            break
        end
    end

    if frame.clearButton then
        frame.clearButton:SetShown(hasRecent)
    end

    table.wipe(addon.namePool)
    for _, data in pairs(addon.targetingPlayers) do
        table.insert(addon.namePool, data)
    end

    table.sort(addon.namePool, function(a, b)
        if a.isTargeting ~= b.isTargeting then
            return a.isTargeting
        end
        return a.lastSeen > b.lastSeen
    end)

    for _, line in ipairs(frame.lines or {}) do
        line:Hide()
    end

    local content = frame.scrollChild or frame
    local top = 4
    local minRowHeight = 18
    local totalHeight = 8
    local contentWidth = 0
    local scrollHeight = 0

    if frame.scrollFrame then
        contentWidth = frame.scrollFrame:GetWidth()
        scrollHeight = frame.scrollFrame:GetHeight()
    else
        contentWidth = frame:GetWidth() - 16
    end
    contentWidth = math.max(contentWidth, 100)

    if frame.scrollChild and frame.scrollFrame then
        frame.scrollChild:SetWidth(contentWidth)
    end

    local lineWidth = math.max(contentWidth - 16, 100)
    for i, data in ipairs(addon.namePool) do
        local line = frame.lines[i]
        if not line then
            break
        end
        line.unit = data.unit
        line.unitID = data.unitID or (data.unit and addon:GetTRP3UnitID(data.unit))
        line.realName = data.realName

        local visibleName = data.iconMarkup or ""
        if data.trpName and data.trpName ~= "" then
            visibleName = visibleName .. data.trpName
            if not visibleName:find("|r$") then
                visibleName = visibleName .. "|r"
            end
            if StripTRP3ColorCodes(data.trpName) ~= data.realName then
                visibleName = visibleName .. " (" .. data.realName .. ")"
            end
        else
            visibleName = visibleName .. data.realName
        end

        local status
        if data.pendingTRP3 then
            status = " |cff808080(loading)|r"
        elseif not data.isTargeting then
            status = " |cff808080(recent)|r"
        else
            status = ""
        end
        local text = visibleName .. status

        local rowHeight = minRowHeight
        if line.fontString then
            if data.trpColor then
                line.fontString:SetTextColor(data.trpColor.r, data.trpColor.g, data.trpColor.b)
            else
                line.fontString:SetTextColor(1, 1, 1)
            end
            line.fontString:SetWidth(lineWidth)
            line.fontString:SetText(text)
            rowHeight = math.max(minRowHeight, line.fontString:GetStringHeight())
            line.fontString:SetHeight(rowHeight)
        end

        line:SetHeight(rowHeight)

        totalHeight = totalHeight + rowHeight + 2

        line:ClearAllPoints()
        if i == 1 then
            line:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -top)
            line:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -top)
        else
            line:SetPoint("TOPLEFT", frame.lines[i - 1], "BOTTOMLEFT", 0, -2)
            line:SetPoint("TOPRIGHT", frame.lines[i - 1], "BOTTOMRIGHT", 0, -2)
        end
        line:Show()
    end

    if frame.scrollChild then
        frame.scrollChild:SetWidth(lineWidth + 16)
    end
    if frame.scrollChild and frame.scrollFrame then
        frame.scrollChild:SetHeight(math.max(totalHeight, scrollHeight))
    end

end

function addon:AddOrUpdatePlayer(realName, trpName, iconMarkup, unit, pendingTRP3)
    if not realName or realName == "" then
        return
    end
    local guid = UnitGUID(unit)
    if not guid then
        return
    end
    local _, class = GetPlayerInfoByGUID(guid)
    addon.targetingPlayers[realName] = {
        realName = realName,
        trpName = trpName,
        iconMarkup = iconMarkup,
        trpColor = addon:GetTRP3Color(unit),
        unit = unit,
        unitID = addon:GetTRP3UnitID(unit),
        pendingTRP3 = pendingTRP3 and true or false,
        isTargeting = true,
        lastSeen = GetTime(),
        class = class,
    }
end

function addon:CheckAllNameplates()
    if addon.targetingPlayers[UnitName("player")] then
        addon.targetingPlayers[UnitName("player")] = nil
    end

    local currentlyTargeting = {}
    for _, npFrame in ipairs(C_NamePlate.GetNamePlates()) do
        if npFrame and npFrame:IsShown() then
            local unit = (addon.TRP3_NamePlatesUtil and addon.TRP3_NamePlatesUtil.GetNameplateUnit and addon.TRP3_NamePlatesUtil.GetNameplateUnit(npFrame)) or npFrame.namePlateUnitToken or npFrame.unitToken
            if unit and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") and UnitIsUnit(unit .. "target", "player") then
                local realName = UnitName(unit)
                local trpName, pendingTRP3 = addon:GetTRP3Name(unit, realName)
                local iconMarkup = addon:GetTRP3IconMarkup(unit)
                currentlyTargeting[realName] = true
                if addon.RecordHistoryEvent and (not addon.targetingPlayers[realName] or not addon.targetingPlayers[realName].isTargeting) then
                    addon:RecordHistoryEvent(realName, trpName, iconMarkup, true, addon:GetTRP3Color(unit), addon:GetTRP3UnitID(unit), pendingTRP3)
                end
                addon:AddOrUpdatePlayer(realName, trpName, iconMarkup, unit, pendingTRP3)
            end
        end
    end

    for name, data in pairs(addon.targetingPlayers) do
        if data.isTargeting and not currentlyTargeting[name] then
            if addon.RecordHistoryEvent then
                addon:RecordHistoryEvent(name, data.trpName, data.iconMarkup, false, data.trpColor, data.unitID)
            end
            data.isTargeting = false
            data.unit = nil
            data.lastSeen = GetTime()
        end
    end

    for name, data in pairs(addon.targetingPlayers) do
        if not data.isTargeting and (GetTime() - data.lastSeen) > 300 then
            addon.targetingPlayers[name] = nil
        end
    end

    addon:UpdateDisplay()
end

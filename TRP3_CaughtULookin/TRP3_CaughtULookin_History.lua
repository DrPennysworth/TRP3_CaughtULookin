local ADDON_NAME, addon = ...

local HISTORY_REFRESH_INTERVAL = 1.5

function addon:GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or ""
    return name .. "-" .. realm
end

function addon:FormatHistoryTime(timestamp)
    if not timestamp then
        return "--/--/---- --:--"
    end
    return date("%m/%d/%Y %I:%M:%S %p", timestamp)
end

function addon:FormatHistoryDuration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))

    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60

    local parts = {}
    if hours > 0 then
        parts[#parts + 1] = string.format("%d %s", hours, hours == 1 and "hour" or "hours")
    end
    if minutes > 0 then
        parts[#parts + 1] = string.format("%d %s", minutes, minutes == 1 and "minute" or "minutes")
    end
    if seconds > 0 or #parts == 0 then
        parts[#parts + 1] = string.format("%d %s", seconds, seconds == 1 and "second" or "seconds")
    end

    return table.concat(parts, ", ")
end

function addon:GetHistoryLineText(entry, iconSize)
    local visibleName
    local iconMarkup = ""
    if entry.iconID then
        iconMarkup = addon:GetTRP3IconMarkup(entry.iconID, iconSize)
    elseif entry.iconMarkup then
        iconMarkup = addon:NormalizeIconMarkup(entry.iconMarkup, iconSize)
    end
    if entry.trpName and entry.trpName ~= "" and entry.trpName ~= entry.realName then
        visibleName = iconMarkup .. entry.trpName .. " (" .. entry.realName .. ")"
    else
        visibleName = iconMarkup .. entry.realName
    end
    if entry.pendingTRP3 then
        visibleName = visibleName .. " |cff808080(loading)|r"
    end

    local stopText = addon:FormatHistoryTime(entry.stop)
    local durationText = addon:FormatHistoryDuration(entry.stop - (entry.start or entry.stop))
    return string.format("%s - finished %s (%s)", visibleName, stopText, durationText)
end

function addon:InitializeHistoryUI()
    if addon.historyFrame then
        return
    end

    addon.historyFrame = _G["CULookinHistoryFrame"]
    if not addon.historyFrame then
        return
    end

    addon:EnsureSettings()
    addon.historyFrame:SetFrameStrata("MEDIUM")
    addon.historyFrame:SetFrameLevel(15)
    addon:ApplyTransparency()

    addon.historyFrame.scrollFrame = _G["CULookinHistoryScrollFrame"]
    addon.historyFrame.content = _G["CULookinHistoryContent"]
    addon.historyFrame.lines = {}
    if addon.historyFrame.scrollFrame and addon.historyFrame.content then
        if addon.historyFrame.scrollFrame.SetScrollChild then
            addon.historyFrame.scrollFrame:SetScrollChild(addon.historyFrame.content)
        end
        addon.historyFrame.scrollFrame:EnableMouseWheel(true)
        addon.historyFrame.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local current = self:GetVerticalScroll()
            local range = self:GetVerticalScrollRange()
            local step = 20
            self:SetVerticalScroll(math.max(0, math.min(current - delta * step, range)))
        end)
    end

    local clearButton = _G["CULookinHistoryClearButton"]
    if clearButton then
        clearButton:SetScript("OnClick", function()
            addon.history = {}
            CULookinDB.history = addon.history
            addon:UpdateHistoryDisplay()
        end)
    end

    local closeButton = _G["CULookinHistoryCloseButton"]
    if closeButton then
        closeButton:SetScript("OnClick", function()
            if addon.historyFrame then
                addon.historyFrame:Hide()
            end
        end)
    end

    addon:InitializeCopyDialog()

    if addon.historyFrame.content then
        for i = 1, 80 do
            if not addon.historyFrame.lines[i] then
                local line = addon:CreateListRow("CULookinHistoryRow" .. i, addon.historyFrame.content)
                addon.historyFrame.lines[i] = line
            end
        end
    end

    addon.historyFrame:SetScript("OnSizeChanged", function(self, width, height)
        addon:UpdateHistoryDisplay()
    end)

    addon.historyFrame.historyRefreshElapsed = 0
    addon.historyFrame:SetScript("OnUpdate", function(self, elapsed)
        self.historyRefreshElapsed = self.historyRefreshElapsed + elapsed
        if self.historyRefreshElapsed < HISTORY_REFRESH_INTERVAL then
            return
        end
        self.historyRefreshElapsed = 0
        addon:UpdateHistoryDisplay()
    end)
end

function addon:OpenHistoryWindow()
    if not addon.history then
        addon.history = CULookinDB.history or {}
        CULookinDB.history = addon.history
    end
    addon:EnsureHistorySessionEntries()

    if not addon.historyFrame then
        addon:InitializeHistoryUI()
    end
    if addon.historyFrame then
        if addon.frame then
            addon.historyFrame:SetFrameLevel(addon.frame:GetFrameLevel() + 10)
        end
        addon.historyFrame:Show()
        addon.historyFrame:Raise()
        addon:UpdateHistoryDisplay()
    end
end

function addon:ToggleHistoryWindow()
    if addon.historyFrame and addon.historyFrame:IsShown() then
        addon.historyFrame:Hide()
    else
        addon:OpenHistoryWindow()
    end
end

function addon:UpdateHistoryDisplay()
    if not addon.historyFrame or not addon.historyFrame:IsShown() then
        return
    end

    local visibleItems = {}
    local characterGroups = {}
    for charKey, group in pairs(addon.history or {}) do
        table.insert(characterGroups, { charKey = charKey, group = group })
    end
    table.sort(characterGroups, function(a, b)
        return (a.group.lastSeen or 0) > (b.group.lastSeen or 0)
    end)

    for _, groupInfo in ipairs(characterGroups) do
        local entries = {}
        for _, entry in pairs(groupInfo.group.entries or {}) do
            if entry.stop then
                table.insert(entries, entry)
            end
        end

        if #entries > 0 then
            table.insert(visibleItems, { type = "header", charKey = groupInfo.charKey, group = groupInfo.group })
        end
        if #entries > 0 and not groupInfo.group.collapsed then
            table.sort(entries, function(a, b)
                return (a.stop or a.lastSeen or 0) > (b.stop or b.lastSeen or 0)
            end)
            for _, entry in ipairs(entries) do
                table.insert(visibleItems, { type = "entry", entry = entry })
            end
        end
    end

    if addon.historyFrame.content then
        for _, line in ipairs(addon.historyFrame.lines) do
            line:Hide()
            line.isHeader = nil
            line.group = nil
            line.realName = nil
            line.unitID = nil
            line.hasTRP3 = nil
        end

        local contentWidth = addon.historyFrame.scrollFrame and addon.historyFrame.scrollFrame:GetWidth() or math.max(addon.historyFrame.content:GetWidth() - 16, 100)
        local lineWidth = math.max(contentWidth - 16, 100)
        local minRowHeight = addon.GetHistoryRowHeight and addon:GetHistoryRowHeight() or 34
        local totalHeight = 8

        for i, item in ipairs(visibleItems) do
            local line = addon.historyFrame.lines[i]
            if not line then
                line = addon:CreateListRow("CULookinHistoryRow" .. i, addon.historyFrame.content)
                addon.historyFrame.lines[i] = line
            end

            local text
            local iconSize = 18
            if item.type == "header" then
                line.isHeader = true
                line.group = item.group
                if line.fontString then
                    line.fontString:SetFontObject("GameFontNormalLarge")
                end
                local count = 0
                for _, entry in pairs(item.group.entries or {}) do
                    if entry.stop then
                        count = count + 1
                    end
                end
                local marker = item.group.collapsed and "[+]" or "[-]"
                text = string.format("%s %s (%d entries)", marker, item.charKey, count)
                if line.fontString then
                    line.fontString:SetTextColor(1, 0.82, 0.2)
                end
            else
                line.isHeader = false
                line.group = nil
                local entry = item.entry
                line.realName = entry.realName
                line.unit = nil
                line.unitID = entry.unitID
                line.hasTRP3 = entry.trpName and entry.trpName ~= ""
                if line.fontString then
                    line.fontString:SetFontObject("GameFontHighlightSmall")
                    local fontSize = math.max(12, minRowHeight - 8)
                    line.fontString:SetFont(STANDARD_TEXT_FONT, fontSize)
                end
                local iconSize = math.max(18, minRowHeight - 6)
                text = "    " .. addon:GetHistoryLineText(entry, iconSize)
                if line.fontString then
                    line.fontString:SetWidth(lineWidth)
                    if entry.trpColor then
                        line.fontString:SetTextColor(entry.trpColor.r, entry.trpColor.g, entry.trpColor.b)
                    else
                        line.fontString:SetTextColor(1, 1, 1)
                    end
                end
            end

            if line.fontString then
                line.fontString:SetWidth(lineWidth)
                line.fontString:SetText(text)
                local rowHeight = math.max(minRowHeight, line.fontString:GetStringHeight(), iconSize + 6)
                line.fontString:SetHeight(rowHeight)
                line:SetHeight(rowHeight)
            else
                line:SetHeight(minRowHeight)
            end

            if i == 1 then
                line:SetPoint("TOPLEFT", addon.historyFrame.content, "TOPLEFT", 8, -4)
                line:SetPoint("TOPRIGHT", addon.historyFrame.content, "TOPRIGHT", -8, -4)
            else
                line:SetPoint("TOPLEFT", addon.historyFrame.lines[i - 1], "BOTTOMLEFT", 0, -2)
                line:SetPoint("TOPRIGHT", addon.historyFrame.lines[i - 1], "BOTTOMRIGHT", 0, -2)
            end

            line:Show()
            totalHeight = totalHeight + line:GetHeight() + 2
        end

        if addon.historyFrame.scrollFrame and addon.historyFrame.content then
            addon.historyFrame.content:SetHeight(math.max(totalHeight, addon.historyFrame.scrollFrame:GetHeight()))
            addon.historyFrame.content:SetWidth(contentWidth)
        end
    end
end

local function GetNextEntryKey(characterHistory)
    characterHistory.nextEntryID = (characterHistory.nextEntryID or 0) + 1
    return "session-" .. characterHistory.nextEntryID
end

local function CopySessionEntry(entry, start, stop)
    return {
        fullName = entry.fullName,
        realName = entry.realName,
        trpName = entry.trpName,
        iconID = entry.iconID,
        iconMarkup = entry.iconMarkup,
        trpColor = entry.trpColor,
        unitID = entry.unitID,
        pendingTRP3 = entry.pendingTRP3 and true or false,
        start = start,
        stop = stop,
        active = not stop,
        lastSeen = stop or start or entry.lastSeen,
    }
end

function addon:EnsureHistorySessionEntries()
    addon.history = addon.history or CULookinDB.history or {}
    CULookinDB.history = addon.history

    for _, characterHistory in pairs(addon.history) do
        characterHistory.entries = characterHistory.entries or {}

        local requiresMigration = false
        local nextEntryID = characterHistory.nextEntryID or 0
        for entryKey, entry in pairs(characterHistory.entries) do
            if entry.events then
                requiresMigration = true
            end
            local entryID = tonumber(tostring(entryKey):match("^session%-(%d+)$"))
            if entryID and entryID > nextEntryID then
                nextEntryID = entryID
            end
        end

        if requiresMigration then
            local convertedEntries = {}
            characterHistory.nextEntryID = 0
            for _, entry in pairs(characterHistory.entries) do
                for _, event in ipairs(entry.events or {}) do
                    local key = GetNextEntryKey(characterHistory)
                    convertedEntries[key] = CopySessionEntry(entry, event.start, event.stop)
                end
            end
            characterHistory.entries = convertedEntries
        else
            characterHistory.nextEntryID = nextEntryID
        end
    end
end

function addon:GetActiveHistoryEntry(characterHistory, fullName)
    local activeEntries = addon.activeHistoryEntries and addon.activeHistoryEntries[addon:GetCharacterKey()]
    local activeEntryKey = activeEntries and activeEntries[fullName]
    local activeEntry = activeEntryKey and characterHistory.entries[activeEntryKey]
    if activeEntry and not activeEntry.stop then
        return activeEntry, activeEntryKey
    end
    return nil, nil
end

function addon:RecordHistoryEvent(realName, trpName, iconID, started, trpColor, unitID, pendingTRP3)
    if not realName or realName == "" then
        return
    end
    addon:EnsureHistorySessionEntries()

    local characterKey = addon:GetCharacterKey()
    local characterHistory = addon.history[characterKey]
    if not characterHistory then
        characterHistory = {
            entries = {},
            collapsed = false,
            lastSeen = time(),
        }
        addon.history[characterKey] = characterHistory
    end
    characterHistory.lastSeen = time()

    local fullName = addon:MakeFullName(realName)
    addon.activeHistoryEntries = addon.activeHistoryEntries or {}
    addon.activeHistoryEntries[characterKey] = addon.activeHistoryEntries[characterKey] or {}
    local entry, entryKey = addon:GetActiveHistoryEntry(characterHistory, fullName)

    if started and not entry then
        entryKey = GetNextEntryKey(characterHistory)
        entry = {
            fullName = fullName,
            realName = realName,
            trpName = trpName or realName,
            iconID = iconID,
            trpColor = trpColor,
            unitID = unitID,
            pendingTRP3 = pendingTRP3 and true or false,
            start = time(),
            stop = nil,
            active = true,
            lastSeen = time(),
        }
        characterHistory.entries[entryKey] = entry
        addon.activeHistoryEntries[characterKey][fullName] = entryKey
    elseif entry then
        entry.realName = realName
        entry.trpName = trpName or entry.trpName or realName
        entry.iconID = iconID or entry.iconID
        entry.trpColor = trpColor or entry.trpColor
        entry.unitID = entry.unitID or unitID
        entry.pendingTRP3 = pendingTRP3 or entry.pendingTRP3
        entry.lastSeen = time()
    end

    if not started and entry and not entry.stop then
        entry.stop = time()
        entry.active = false
        entry.lastSeen = entry.stop
        characterHistory.lastSeen = entry.stop
        addon.activeHistoryEntries[characterKey][fullName] = nil
    end

    CULookinDB.history = addon.history
end

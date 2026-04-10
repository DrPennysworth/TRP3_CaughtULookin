local ADDON_NAME, addon = ...

local function OnSharedRowClick(self, button)
    if button == "LeftButton" then
        local target = self.unitID or self.unit or self.realName
        if target and self.realName and self.realName ~= "" then
            addon:OpenTRP3Profile(target, self.realName)
        else
            print("|cff00ff00Caught U Lookin:|r TRP3 profile not available. Only you can see this player.")
        end
    elseif button == "RightButton" then
        if self.realName and self.realName ~= "" and addon.ShowCopyDialog then
            addon:ShowCopyDialog(self.realName)
        end
    end
end

local function OnSharedRowEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Left click to open TRP3 profile\nRight click to copy the real name")
    GameTooltip:Show()
end

local function OnSharedRowLeave()
    GameTooltip:Hide()
end

function addon:InitializeCopyDialog()
    if addon.copyDialogInitialized then
        return
    end

    local copyDialog = _G["CULookinCopyDialog"]
    local copyEditBox = _G["CULookinCopyDialogEditBox"]
    local copyClose = _G["CULookinCopyDialogClose"]
    if not copyDialog or not copyEditBox then
        return
    end

    if copyClose then
        copyClose:SetScript("OnClick", function()
            copyDialog:Hide()
        end)
    end

    addon.ShowCopyDialog = function(_, text)
        if not text or text == "" then
            return
        end
        copyEditBox:SetText(text)
        copyEditBox:HighlightText(0, -1)
        copyEditBox:SetFocus()
        copyDialog:Show()
    end

    addon.copyDialogInitialized = true
end

function addon:CreateListRow(lineName, parent)
    local line = CreateFrame("Button", lineName, parent, "TRP3_CaughtULookinListRowTemplate")
    local fontString = line.Text
    if not fontString then
        for regionIndex = 1, select("#", line:GetRegions()) do
            local region = select(regionIndex, line:GetRegions())
            if region and region:IsObjectType("FontString") then
                fontString = region
                break
            end
        end
    end
    if not fontString then
        fontString = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fontString:SetAllPoints(true)
    end
    fontString:SetWordWrap(true)
    fontString:SetNonSpaceWrap(false)
    fontString:SetJustifyH("LEFT")
    fontString:SetJustifyV("TOP")
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
    line.fontString = fontString

    line:EnableMouse(true)
    line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    line:SetScript("OnClick", OnSharedRowClick)
    line:SetScript("OnEnter", OnSharedRowEnter)
    line:SetScript("OnLeave", OnSharedRowLeave)

    return line
end

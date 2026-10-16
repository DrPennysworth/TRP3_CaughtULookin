local _, addon = ...

local function EnsureMinimapDB()
    CULookinDB = CULookinDB or {}
    CULookinDB.minimap = CULookinDB.minimap or { show = true, lock = false, minimapPos = 225 }
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
    if addon.minimapButton or not LibStub then
        return
    end

    local LibDataBroker = LibStub:GetLibrary("LibDataBroker-1.1", true)
    local LibDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    local LibDBCompartment = LibStub:GetLibrary("LibDBCompartment-1.0", true)
    if not LibDataBroker or not LibDBIcon then
        return
    end

    EnsureMinimapDB()

    local objectName = "Total RP 3: Caught U Lookin"
    local object = LibDataBroker:NewDataObject(objectName, {
        type = "launcher",
        icon = "Interface\\AddOns\\TRP3_CaughtULookin\\resources\\wow_whoslookin_icon_v2.dxt1.blp",
        OnClick = function(_, button)
            if button == "LeftButton" then
                addon:ToggleMainWindow()
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
end

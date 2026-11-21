-- WayshrineArrow: a movable HUD arrow that points in a straight line to the nearest wayshrine of the current map.

WayshrineArrow = WayshrineArrow or {}
local WA = WayshrineArrow

local ADDON_NAME = "WayshrineArrow"
WA.name = ADDON_NAME
WA.version = "0.1.0"

local EM = EVENT_MANAGER
local UPDATE_NAME = ADDON_NAME .. "_Update"
local UPDATE_INTERVAL_MS = 50
local MAP_RESET_INTERVAL_MS = 1000   -- at most one SetMapToPlayerLocation() per second
local CALIBRATION_MIN_SPAN = 0.005   -- normalized map distance needed before the map scale is measured
local ARROW_TEXTURE = "EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds"

local TARGET_ALL = 1
local TARGET_UNKNOWN = 2
local TARGET_KNOWN = 3
local TARGET_STRINGS = {
    [TARGET_ALL] = SI_WAYSHRINEARROW_TARGET_ALL,
    [TARGET_UNKNOWN] = SI_WAYSHRINEARROW_TARGET_UNKNOWN,
    [TARGET_KNOWN] = SI_WAYSHRINEARROW_TARGET_KNOWN,
}

local DEFAULTS = {
    enabled = true,
    target = TARGET_ALL,
    locked = true,
    posX = 0,
    posY = -280,
    arrowSize = 56,
    fontSize = 18,
    alpha = 1,
    showName = true,
    showStatus = true,
    showDistance = true,
    knownColor = { 0.45, 0.85, 1, 1 },
    unknownColor = { 1, 0.78, 0.25, 1 },
    hideInCombat = false,
    hideNear = 0,
    mapScale = {},   -- [mapId] = { ratio = world cm per normalized map unit, span = normalized span it was measured over }
}

local sv
local window, content, backdrop, arrow, label

-- state
local nodes = {}            -- wayshrines of the cached map: { known, name, x, y }
local cachedMapId
local nodesDirty = true
local inBlockedArea = false
local inCombat = false
local lastMapReset = 0
local lastText
local calibration = {}      -- anchor sample for measuring the map scale

local sqrt, atan2, floor = math.sqrt, math.atan2, math.floor

local function Print(text)
    d("|c88CCFF[WayshrineArrow]|r " .. text)
end

------------------------------------------------------------------------------------------------
-- Areas without the arrow
------------------------------------------------------------------------------------------------

local function IsInBlockedArea()
    -- delves, public and group dungeons, solo and group arenas
    if IsUnitInDungeon("player") then return true end
    -- trials
    if IsPlayerInRaid() then return true end
    if IsInstanceEndlessDungeon() then return true end
    if IsActiveWorldBattleground() then return true end
    if GetCurrentZoneHouseId() ~= 0 then return true end
    return false
end

------------------------------------------------------------------------------------------------
-- Map and wayshrines
------------------------------------------------------------------------------------------------

-- Makes sure the current map is the player's map. Returns false while the world map is open,
-- because then the player browses maps and the coordinates belong to another map.
local function EnsurePlayerMap()
    if ZO_WorldMap_IsWorldMapShowing() then return false end
    if not DoesCurrentMapMatchMapForPlayerLocation() then
        local now = GetFrameTimeMilliseconds()
        if now - lastMapReset < MAP_RESET_INTERVAL_MS then return false end
        lastMapReset = now
        if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
            CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
        end
    end
    return true
end

local function IsInsideMap(x, y)
    return x > 0 and x < 1 and y > 0 and y < 1
end

local function RebuildNodes()
    nodes = {}
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local known, name, x, y, _, _, poiType, isShownInCurrentMap = GetFastTravelNodeInfo(nodeIndex)
        if poiType == POI_TYPE_WAYSHRINE and isShownInCurrentMap and IsInsideMap(x, y) then
            if name == nil or name == "" then
                name = GetString(SI_WAYSHRINEARROW_UNNAMED)
            else
                name = zo_strformat(SI_WORLD_MAP_LOCATION_NAME, name)
            end
            nodes[#nodes + 1] = { known = known, name = name, x = x, y = y }
        end
    end
    cachedMapId = GetCurrentMapId()
    nodesDirty = false
    lastText = nil
end

local function FindNearest(px, py)
    local target = sv.target
    local best, bestDist2
    for i = 1, #nodes do
        local node = nodes[i]
        if target == TARGET_ALL or (target == TARGET_UNKNOWN) ~= node.known then
            local dx, dy = node.x - px, node.y - py
            local dist2 = dx * dx + dy * dy
            if not bestDist2 or dist2 < bestDist2 then
                best, bestDist2 = node, dist2
            end
        end
    end
    return best, bestDist2 and sqrt(bestDist2)
end

-- The map scale (centimeters per normalized map unit) is measured from the player's own movement:
-- world position and map position of two samples on the same map.
local function Calibrate(mapId, px, py)
    local _, worldX, _, worldZ = GetUnitRawWorldPosition("player")
    if calibration.mapId ~= mapId then
        calibration = { mapId = mapId, x = px, y = py, worldX = worldX, worldZ = worldZ }
        return
    end
    local dx, dy = px - calibration.x, py - calibration.y
    local span = sqrt(dx * dx + dy * dy)
    if span < CALIBRATION_MIN_SPAN then return end
    local entry = sv.mapScale[mapId]
    if entry and entry.span >= span then return end
    local wx, wz = worldX - calibration.worldX, worldZ - calibration.worldZ
    local worldDist = sqrt(wx * wx + wz * wz)
    if worldDist > 0 then
        sv.mapScale[mapId] = { ratio = worldDist / span, span = span }
    end
end

local function GetDistanceMeters(mapId, normalizedDist)
    local entry = sv.mapScale[mapId]
    if entry then
        return normalizedDist * entry.ratio / 100
    end
end

local function FormatDistance(meters)
    if meters < 1000 then
        return zo_strformat(SI_WAYSHRINEARROW_METERS, floor(meters + 0.5))
    end
    return zo_strformat(SI_WAYSHRINEARROW_KILOMETERS, string.format("%.1f", meters / 1000))
end

------------------------------------------------------------------------------------------------
-- Display
------------------------------------------------------------------------------------------------

local function SetText(text)
    if text ~= lastText then
        lastText = text
        label:SetText(text)
    end
end

local function ShowPlaceholder()
    content:SetHidden(false)
    arrow:SetTextureRotation(0)
    arrow:SetColor(1, 1, 1, 1)
    SetText(GetString(SI_WAYSHRINEARROW_DRAG_HINT))
end

local function HideArrow()
    content:SetHidden(true)
end

local function BuildText(node, meters)
    local lines = {}
    if sv.showName then
        lines[#lines + 1] = node.name
    end
    local info = {}
    if sv.showStatus then
        local color = node.known and sv.knownColor or sv.unknownColor
        local status = GetString(node.known and SI_WAYSHRINEARROW_KNOWN or SI_WAYSHRINEARROW_UNKNOWN)
        info[#info + 1] = ZO_ColorDef:New(unpack(color)):Colorize(status)
    end
    if sv.showDistance and meters then
        info[#info + 1] = FormatDistance(meters)
    end
    if #info > 0 then
        lines[#lines + 1] = table.concat(info, " · ")
    end
    return table.concat(lines, "\n")
end

local function OnUpdate()
    if not sv.locked then
        ShowPlaceholder()
        return
    end
    if inBlockedArea or (sv.hideInCombat and inCombat) then
        HideArrow()
        return
    end
    if not EnsurePlayerMap() then return end

    local mapId = GetCurrentMapId()
    if nodesDirty or mapId ~= cachedMapId then
        RebuildNodes()
    end

    local px, py, _, isShownInCurrentMap, isSymbolicLocation = GetMapPlayerPosition("player")
    if not isShownInCurrentMap or isSymbolicLocation then
        HideArrow()
        return
    end
    Calibrate(mapId, px, py)

    local node, dist = FindNearest(px, py)
    if not node then
        HideArrow()
        return
    end
    local meters = GetDistanceMeters(mapId, dist)
    if sv.hideNear > 0 and meters and meters < sv.hideNear then
        HideArrow()
        return
    end

    -- Map x grows to the east, y to the south. Heading and texture rotation count counter-clockwise from north.
    local bearing = atan2(px - node.x, py - node.y)
    arrow:SetTextureRotation(bearing - GetPlayerCameraHeading())
    local color = node.known and sv.knownColor or sv.unknownColor
    arrow:SetColor(unpack(color))
    SetText(BuildText(node, meters))
    content:SetHidden(false)
end

local function ApplyLayout()
    local size = sv.arrowSize
    window:SetDimensions(size, size)
    window:ClearAnchors()
    window:SetAnchor(CENTER, GuiRoot, CENTER, sv.posX, sv.posY)
    window:SetAlpha(sv.alpha)
    label:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", sv.fontSize))
    window:SetMovable(not sv.locked)
    window:SetMouseEnabled(not sv.locked)
    backdrop:SetHidden(sv.locked)
    lastText = nil
end

local function SavePosition()
    local cx, cy = window:GetCenter()
    local gx, gy = GuiRoot:GetCenter()
    sv.posX = floor(cx - gx + 0.5)
    sv.posY = floor(cy - gy + 0.5)
end

local function CreateControls()
    window = WINDOW_MANAGER:CreateTopLevelWindow("WayshrineArrow_Window")
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_LOW)
    window:SetHandler("OnMoveStop", SavePosition)

    backdrop = WINDOW_MANAGER:CreateControl("WayshrineArrow_WindowBackdrop", window, CT_BACKDROP)
    backdrop:SetAnchor(TOPLEFT, window, TOPLEFT, -4, -4)
    backdrop:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, 4, 4)
    backdrop:SetCenterColor(0, 0, 0, 0.5)
    backdrop:SetEdgeColor(1, 1, 1, 0.6)
    backdrop:SetEdgeTexture("", 1, 1, 1)

    content = WINDOW_MANAGER:CreateControl("WayshrineArrow_WindowContent", window, CT_CONTROL)
    content:SetAnchorFill(window)
    content:SetHidden(true)

    arrow = WINDOW_MANAGER:CreateControl("WayshrineArrow_WindowArrow", content, CT_TEXTURE)
    arrow:SetAnchorFill(content)
    arrow:SetTexture(ARROW_TEXTURE)

    label = WINDOW_MANAGER:CreateControl("WayshrineArrow_WindowLabel", content, CT_LABEL)
    label:SetAnchor(TOP, content, BOTTOM, 0, 2)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 1, 1, 1)

    -- visible only in the normal game view (and the HUD with mouse cursor, needed for moving)
    local fragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

------------------------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------------------------

local function RefreshArea()
    inBlockedArea = IsInBlockedArea()
    nodesDirty = true
end

local function OnPlayerActivated()
    RefreshArea()
end

local function OnZoneChanged()
    RefreshArea()
end

local function OnFastTravelNetworkUpdated()
    nodesDirty = true
end

local function OnCombatState(_, isInCombat)
    inCombat = isInCombat
end

function WA.CheckEvents()
    EM:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ZONE_CHANGED)
    EM:UnregisterForEvent(ADDON_NAME, EVENT_FAST_TRAVEL_NETWORK_UPDATED)
    EM:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE)
    EM:UnregisterForUpdate(UPDATE_NAME)

    if not sv.enabled then
        HideArrow()
        return
    end

    EM:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EM:RegisterForEvent(ADDON_NAME, EVENT_ZONE_CHANGED, OnZoneChanged)
    EM:RegisterForEvent(ADDON_NAME, EVENT_FAST_TRAVEL_NETWORK_UPDATED, OnFastTravelNetworkUpdated)
    if sv.hideInCombat then
        EM:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
        inCombat = IsUnitInCombat("player")
    end
    EM:RegisterForUpdate(UPDATE_NAME, UPDATE_INTERVAL_MS, OnUpdate)
    RefreshArea()
end

------------------------------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------------------------------

local function SetEnabled(enabled)
    sv.enabled = enabled
    WA.CheckEvents()
end

local function SetLocked(locked)
    sv.locked = locked
    ApplyLayout()
    -- the update loop also shows the placeholder while unlocked, so it must run
    if not locked and not sv.enabled then
        SetEnabled(true)
    end
end

function WA.ToggleEnabled()
    SetEnabled(not sv.enabled)
    Print(GetString(sv.enabled and SI_WAYSHRINEARROW_MSG_ON or SI_WAYSHRINEARROW_MSG_OFF))
end

function WA.CycleTarget()
    sv.target = sv.target % 3 + 1
    lastText = nil
    Print(zo_strformat(SI_WAYSHRINEARROW_MSG_TARGET, GetString(TARGET_STRINGS[sv.target])))
end

local function PrintDebug()
    local onMap, known, outside = 0, 0, 0
    for nodeIndex = 1, GetNumFastTravelNodes() do
        local isKnown, _, x, y, _, _, poiType, isShownInCurrentMap = GetFastTravelNodeInfo(nodeIndex)
        if poiType == POI_TYPE_WAYSHRINE and isShownInCurrentMap then
            if IsInsideMap(x, y) then
                onMap = onMap + 1
                if isKnown then known = known + 1 end
            else
                outside = outside + 1
            end
        end
    end
    local px, py, heading = GetMapPlayerPosition("player")
    local scale = sv.mapScale[GetCurrentMapId()]
    Print(string.format("map %s (id %d), wayshrines %d (known %d, unknown %d, outside %d), blocked %s",
        GetMapName(), GetCurrentMapId(), onMap, known, onMap - known, outside, tostring(inBlockedArea)))
    Print(string.format("player %.4f / %.4f, heading %.2f, camera %.2f, scale %s",
        px, py, heading, GetPlayerCameraHeading(), scale and string.format("%.0f (span %.3f)", scale.ratio, scale.span) or "-"))
end

local settingsPanel

local function OnSlashCommand(args)
    local cmd = zo_strlower(zo_strtrim(args or ""))
    if cmd == "" then
        WA.ToggleEnabled()
    elseif cmd == "on" then
        SetEnabled(true)
        Print(GetString(SI_WAYSHRINEARROW_MSG_ON))
    elseif cmd == "off" then
        SetEnabled(false)
        Print(GetString(SI_WAYSHRINEARROW_MSG_OFF))
    elseif cmd == "lock" then
        SetLocked(true)
        Print(GetString(SI_WAYSHRINEARROW_MSG_LOCKED))
    elseif cmd == "unlock" then
        SetLocked(false)
        Print(GetString(SI_WAYSHRINEARROW_MSG_UNLOCKED))
    elseif cmd == "target" then
        WA.CycleTarget()
    elseif cmd == "reset" then
        sv.posX, sv.posY = DEFAULTS.posX, DEFAULTS.posY
        ApplyLayout()
        Print(GetString(SI_WAYSHRINEARROW_MSG_RESET))
    elseif cmd == "debug" then
        PrintDebug()
    elseif cmd == "settings" and settingsPanel then
        LibAddonMenu2:OpenToPanel(settingsPanel)
    else
        Print(GetString(SI_WAYSHRINEARROW_MSG_HELP))
    end
end

------------------------------------------------------------------------------------------------
-- Settings (LibAddonMenu-2.0 is optional)
------------------------------------------------------------------------------------------------

local function CreateSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    settingsPanel = LAM:RegisterAddonPanel("WayshrineArrow_Settings", {
        type = "panel",
        name = "WayshrineArrow",
        displayName = "Wayshrine Arrow",
        author = "cudddel",
        version = WA.version,
        slashCommand = "/wsarrowsettings",
        registerForRefresh = true,
    })

    local function refreshText()
        lastText = nil
    end

    local function colorOption(nameId, key)
        return {
            type = "colorpicker",
            name = GetString(nameId),
            getFunc = function() return unpack(sv[key]) end,
            setFunc = function(r, g, b, a)
                sv[key] = { r, g, b, a }
                refreshText()
            end,
            default = ZO_ColorDef:New(unpack(DEFAULTS[key])),
        }
    end

    local function checkbox(nameId, key, tooltipId)
        return {
            type = "checkbox",
            name = GetString(nameId),
            tooltip = tooltipId and GetString(tooltipId) or nil,
            getFunc = function() return sv[key] end,
            setFunc = function(value)
                sv[key] = value
                refreshText()
            end,
            default = DEFAULTS[key],
        }
    end

    LAM:RegisterOptionControls("WayshrineArrow_Settings", {
        { type = "description", text = GetString(SI_WAYSHRINEARROW_OPT_INFO) },
        {
            type = "checkbox",
            name = GetString(SI_WAYSHRINEARROW_OPT_ENABLED),
            getFunc = function() return sv.enabled end,
            setFunc = SetEnabled,
            default = DEFAULTS.enabled,
        },
        {
            type = "dropdown",
            name = GetString(SI_WAYSHRINEARROW_OPT_TARGET),
            tooltip = GetString(SI_WAYSHRINEARROW_OPT_TARGET_TT),
            choices = {
                GetString(SI_WAYSHRINEARROW_TARGET_ALL),
                GetString(SI_WAYSHRINEARROW_TARGET_UNKNOWN),
                GetString(SI_WAYSHRINEARROW_TARGET_KNOWN),
            },
            choicesValues = { TARGET_ALL, TARGET_UNKNOWN, TARGET_KNOWN },
            getFunc = function() return sv.target end,
            setFunc = function(value)
                sv.target = value
                refreshText()
            end,
            width = "full",
            default = DEFAULTS.target,
        },
        {
            type = "checkbox",
            name = GetString(SI_WAYSHRINEARROW_OPT_HIDE_COMBAT),
            getFunc = function() return sv.hideInCombat end,
            setFunc = function(value)
                sv.hideInCombat = value
                WA.CheckEvents()
            end,
            default = DEFAULTS.hideInCombat,
        },
        {
            type = "slider",
            name = GetString(SI_WAYSHRINEARROW_OPT_HIDE_NEAR),
            tooltip = GetString(SI_WAYSHRINEARROW_OPT_HIDE_NEAR_TT),
            min = 0, max = 100, step = 5,
            getFunc = function() return sv.hideNear end,
            setFunc = function(value) sv.hideNear = value end,
            default = DEFAULTS.hideNear,
        },
        {
            type = "checkbox",
            name = GetString(SI_WAYSHRINEARROW_OPT_LOCKED),
            tooltip = GetString(SI_WAYSHRINEARROW_OPT_LOCKED_TT),
            getFunc = function() return sv.locked end,
            setFunc = SetLocked,
            default = DEFAULTS.locked,
        },
        {
            type = "button",
            name = GetString(SI_WAYSHRINEARROW_OPT_RESET),
            func = function()
                sv.posX, sv.posY = DEFAULTS.posX, DEFAULTS.posY
                ApplyLayout()
            end,
        },
        { type = "header", name = GetString(SI_WAYSHRINEARROW_OPT_HEADER_DISPLAY) },
        checkbox(SI_WAYSHRINEARROW_OPT_SHOW_NAME, "showName"),
        checkbox(SI_WAYSHRINEARROW_OPT_SHOW_STATUS, "showStatus"),
        checkbox(SI_WAYSHRINEARROW_OPT_SHOW_DISTANCE, "showDistance", SI_WAYSHRINEARROW_OPT_SHOW_DISTANCE_TT),
        colorOption(SI_WAYSHRINEARROW_OPT_KNOWN_COLOR, "knownColor"),
        colorOption(SI_WAYSHRINEARROW_OPT_UNKNOWN_COLOR, "unknownColor"),
        {
            type = "slider",
            name = GetString(SI_WAYSHRINEARROW_OPT_SIZE),
            min = 24, max = 160, step = 4,
            getFunc = function() return sv.arrowSize end,
            setFunc = function(value)
                sv.arrowSize = value
                ApplyLayout()
            end,
            default = DEFAULTS.arrowSize,
        },
        {
            type = "slider",
            name = GetString(SI_WAYSHRINEARROW_OPT_FONT_SIZE),
            min = 12, max = 36, step = 1,
            getFunc = function() return sv.fontSize end,
            setFunc = function(value)
                sv.fontSize = value
                ApplyLayout()
            end,
            default = DEFAULTS.fontSize,
        },
        {
            type = "slider",
            name = GetString(SI_WAYSHRINEARROW_OPT_ALPHA),
            min = 20, max = 100, step = 5,
            getFunc = function() return floor(sv.alpha * 100 + 0.5) end,
            setFunc = function(value)
                sv.alpha = value / 100
                ApplyLayout()
            end,
            default = DEFAULTS.alpha * 100,
        },
    })
end

------------------------------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------------------------------

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- account-wide, one profile per server (the map scale cache is the same everywhere, the position is a UI choice)
    sv = ZO_SavedVars:NewAccountWide("WayshrineArrow_Saved", 1, nil, DEFAULTS, GetWorldName())

    CreateControls()
    ApplyLayout()
    CreateSettings()
    SLASH_COMMANDS["/wsarrow"] = OnSlashCommand
    WA.CheckEvents()
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

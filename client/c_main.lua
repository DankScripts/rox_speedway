-- client/c_main.lua

local Config = require("config.config")
local localeTable = require("locales." .. Config.Locale)
local function loc(key, ...)
    local str = localeTable[key] or key
    local args = { ... }
    return (str:gsub("{(%d+)}", function(n)
        return tostring(args[tonumber(n)] or "")
    end))
end

--------------------------------------------------------------------------------
-- 2) PULL IN QBCORE
--------------------------------------------------------------------------------
local QBCore = exports['qb-core']:GetCoreObject()

--------------------------------------------------------------------------------
-- 3) FUEL MODULE (moved to client/c_fuel.lua)
--------------------------------------------------------------------------------
-- SetFullFuel(veh) is defined in client/c_fuel.lua

--------------------------------------------------------------------------------
-- 4) RACE STATE
--------------------------------------------------------------------------------
local hasLobby             = false
--------------------------------------------------------------------------------
-- NATIVE LOBBY WAITING LIST DISPLAY
local lobbyDisplayActive = false
local lobbyDisplayMembers = {}
local lobbyDisplayName = ""
local nuiReady = false
local lobbyNuiVisible = false   -- track if the NUI lobby panel is currently shown
local lobbyHintShown = false    -- avoid spamming the hint toast

function ShowLobbyDisplay(name, members)
    -- Prefer NUI lobby overlay
    local hostName = name:match("^([%w_]+)_%d+$") or name
    if Config.DebugPrints then
        print("[DEBUG] ShowLobbyDisplay called: hostName=" .. tostring(hostName) .. ", members=" .. table.concat(members, ", "))
    end
    -- Send to NUI (timeout.html handles showLobby)
    local meIsHost = (lobbyOwner == GetPlayerServerId(PlayerId()))
    if not nuiReady then
        -- Defer until UI reports ready to avoid 'no UI frame' warning
        CreateThread(function()
            local tries = 0
            while not nuiReady and tries < 200 do -- up to ~10s
                tries = tries + 1
                Wait(50)
            end
            if nuiReady then
                SendNUIMessage({ action = 'showLobby', lobbyName = hostName, hostName = hostName, members = members, meIsHost = meIsHost, keyLabel = (Config.InteractKeyLabel or 'Left Alt') })
            end
        end)
    else
        SendNUIMessage({ action = 'showLobby', lobbyName = hostName, hostName = hostName, members = members, meIsHost = meIsHost, keyLabel = (Config.InteractKeyLabel or 'Left Alt') })
    end
    -- Disable native draw to avoid double UI
    lobbyDisplayActive = false
    lobbyDisplayName = hostName
    lobbyDisplayMembers = members
    lobbyNuiVisible = true
    if not lobbyHintShown then
        lobbyHintShown = true
        if SpeedwayNotify then
            SpeedwayNotify("Speedway", ("Press %s to interact with the lobby. You can remap it in Settings > Key Bindings > FiveM under 'Speedway: Interact with Lobby Panel'. Or use /lobby."):format(Config.InteractKeyLabel or 'F2'), "inform", 7000)
        else
            print(("[Speedway] Hint: Press %s to interact with the lobby (or use /lobby). You can remap in Settings > Key Bindings."):format(Config.InteractKeyLabel or 'F2'))
        end
    end
end

function HideLobbyDisplay()
    lobbyDisplayActive = false
    if nuiReady then
        SendNUIMessage({ action = 'hideLobby' })
    end
    lobbyNuiVisible = false
    lobbyHintShown = false
end

-- Try to close qb-input dialog if it is open
local function CloseVehicleSelectionUI()
    -- best-effort: try known exports and events, then drop NUI focus
    local ok = false
    if exports['qb-input'] then
        -- Try common method names unconditionally; pcall will swallow if they don't exist
        pcall(function() exports['qb-input']:CloseInput(); ok = true end)
        pcall(function() exports['qb-input']:HideInput();  ok = true end)
        pcall(function() exports['qb-input']:closeMenu();  ok = true end)
        pcall(function() exports['qb-input']:Close();      ok = true end)
        -- Some forks expose a generic close function name
        pcall(function() exports['qb-input']:close();      ok = true end)
    end
    -- common events some forks listen for
    TriggerEvent('qb-input:client:close')
    TriggerEvent('qb-input:close')
    TriggerEvent('qb-input:client:closeMenu')
    TriggerEvent('qb-input:closeMenu')
    -- also try qb-menu close in case the input UI wraps it
    TriggerEvent('qb-menu:client:closeMenu')
    -- ensure focus is released as a last resort
    SetNuiFocus(false, false)
    -- reinforce focus off for a few frames in case another script re-asserts it
    CreateThread(function()
        for i=1,10 do
            SetNuiFocus(false, false)
            Wait(0)
        end
    end)
end

CreateThread(function()
    while true do
        Wait(0)
        if lobbyDisplayActive then
            -- Draw background (scaled down, moved further left)
            DrawRect(0.10, 0.5, 0.16, 0.09, 20, 20, 20, 200) -- x=0.10 (further left), y=0.5 (middle), width=0.16, height=0.09
            -- Draw title
            SetTextFont(4); SetTextScale(0.35,0.35); SetTextCentre(true)
            SetTextColour(255,255,255,255); SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString("Lobby: " .. lobbyDisplayName)
            DrawText(0.10, 0.44)
            -- Draw member list
            for i, member in ipairs(lobbyDisplayMembers) do
                SetTextFont(0); SetTextScale(0.25,0.25); SetTextCentre(false)
                SetTextColour(255,255,255,255); SetTextOutline()
                SetTextEntry("STRING")
                local label = member .. (i == 1 and " (Host)" or "")
                AddTextComponentString(label)
                DrawText(0.02, 0.47 + (i * 0.015))
            end
        end
    end
end)
-- NUI readiness handshake
RegisterNUICallback('nuiReady', function(_, cb)
    nuiReady = true
    if cb then cb({ ok = true }) end
end)

-- Toggle interact mode for the lobby tablet without permanently stealing input
local lobbyFocus = false
local function ToggleLobbyInteract()
    if not nuiReady then return end
    -- Only allow when the lobby overlay is visible
    -- Interact mode: capture NUI focus but DO NOT keep game input (prevents camera movement)
    lobbyFocus = not lobbyFocus
    if lobbyFocus then
        SetNuiFocusKeepInput(false)   -- do not pass mouse/keys to game while interacting
        SetNuiFocus(true, true)
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
    SendNUIMessage({ action = 'lobbyFocus', on = lobbyFocus })
end

RegisterCommand('speedway_lobby_interact', function()
    -- Only allow interact toggle when lobby overlay is visible and we're not in race or a blocking modal
    if lobbyNuiVisible and not inRace and not timeoutModalActive then
        ToggleLobbyInteract()
    end
end, false)

-- Backup chat command if keybind isn't working; same gating rules
RegisterCommand('lobby', function()
    if lobbyNuiVisible and not inRace and not timeoutModalActive then
        ToggleLobbyInteract()
    else
        SpeedwayNotify("Speedway", "Lobby controls are only available while a lobby is visible.", "error", 3500)
    end
end, false)
-- Default keybind: Left Alt (LMENU). Players can remap via FiveM key bindings.
RegisterKeyMapping('speedway_lobby_interact', 'Speedway: Interact with Lobby Panel', 'keyboard', Config.InteractKey or 'F2')

-- Removed qb-target lobbyInteract event: interaction now uses F6 toggle only

-- NUI callbacks from the tablet buttons
RegisterNUICallback('lobbyStart', function(data, cb)
    if lobbyOwner ~= GetPlayerServerId(PlayerId()) then cb('not_host'); return end
    if currentLobby then TriggerServerEvent('speedway:startRace', currentLobby) end
    -- Release focus after click
    lobbyFocus = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'lobbyFocus', on = false })
    HideLobbyDisplay()
    -- suppress auto-interact until Alt is released to avoid re-triggering instantly
    speedwaySuppressAutoUntilAltUp = true
    cb('ok')
end)

RegisterNUICallback('lobbyLeave', function(_, cb)
    if currentLobby then TriggerServerEvent('speedway:leaveLobby', currentLobby) end
    lobbyFocus = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'lobbyFocus', on = false })
    -- suppress auto-interact until Alt is released to avoid re-triggering instantly
    speedwaySuppressAutoUntilAltUp = true
    cb('ok')
end)

-- ESC from lobby tablet: return to passive preview without taking any action
RegisterNUICallback('lobbyCancel', function(_, cb)
    lobbyFocus = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'lobbyFocus', on = false })
    -- suppress auto-interact until Alt is released to avoid re-triggering instantly
    speedwaySuppressAutoUntilAltUp = true
    cb('ok')
end)
local currentProps         = {}
local racerCheckpointIndex = 0
local inRace               = false
local myPosition           = 0
local totalRacers          = 0

--------------------------------------------------------------------------------
-- 5) COMPUTE DISTANCE ALONG TRACK
--------------------------------------------------------------------------------
local function ComputeDistanceAlongTrack(pos)
    -- Monotonic distance since lap start using last passed checkpoint index (0..n)
    -- Includes virtual segment from Start/Finish -> CP1 (segIdx=0) and from last CP -> Start/Finish (segIdx=n)
    if not currentTrack then return 0 end
    local track = Config.Checkpoints[currentTrack]
    if not track or #track < 1 then return 0 end

    local function v3(v) return vector3(v.x, v.y, v.z) end
    local startNode = v3(Config.FinishLine.coords or Config.StartLinePoints[1])
    local n = #track

    -- helper to access the node list with virtual endpoints
    local function getNode(i)
        if i == 0 then return startNode end
        if i >= 1 and i <= n then return v3(track[i]) end
        if i == n + 1 then return startNode end
        -- clamp fallback
        if i < 0 then return startNode end
        return startNode
    end

    -- segment index equals last passed checkpoint; clamp to [0, n]
    local segIdx = racerCheckpointIndex or 0
    if segIdx < 0 then segIdx = 0 end
    if segIdx > n then segIdx = n end

    -- helper: build a polyline for a given big segment using optional hints
    local function buildSegmentNodes(seg)
        local nodes = {}
        local a = getNode(seg)
        local b = getNode(seg + 1)
        table.insert(nodes, a)
        local hintsByTrack = Config.SegmentHints and Config.SegmentHints[currentTrack]
        local hints = hintsByTrack and hintsByTrack[seg]
        -- Support configs that index the final segment (CPn->Finish) as (n-1)
        if (not hints) and seg == n and hintsByTrack then
            hints = hintsByTrack[n - 1]
        end
        if hints then
            for _, h in ipairs(hints) do
                table.insert(nodes, v3(h))
            end
        end
        table.insert(nodes, b)
        return nodes
    end

    -- sum of completed big segments since the Start/Finish line
    local total = 0.0
    for i = 0, segIdx - 1 do
        local nodes = buildSegmentNodes(i)
        for k = 1, #nodes - 1 do
            total = total + #(nodes[k+1] - nodes[k])
        end
    end

    -- progress along current big segment using closest point on polyline
    local nodes = buildSegmentNodes(segIdx)
    local segLen = 0.0
    local cumLen = 0.0
    local bestDist = 0.0
    local bestD2 = math.huge
    -- precompute sub-lengths
    local subLens = {}
    for k = 1, #nodes - 1 do
        subLens[k] = #(nodes[k+1] - nodes[k])
        segLen = segLen + subLens[k]
    end
    for k = 1, #nodes - 1 do
        local a = nodes[k]
        local b = nodes[k+1]
        local ab = b - a
        local abLen = subLens[k]
        if abLen > 0.001 then
            local ap = pos - a
            local t = (ap.x*ab.x + ap.y*ab.y + ap.z*ab.z) / (abLen * abLen)
            if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end
            local proj = a + (ab * t)
            local dp = pos - proj
            local d2 = (dp.x*dp.x + dp.y*dp.y + dp.z*dp.z)
            if d2 < bestD2 then
                bestD2 = d2
                bestDist = cumLen + (t * abLen)
            end
        end
        cumLen = cumLen + abLen
    end
    total = total + bestDist

    -- Anti-plateau smoothing near segment end: softly blend a small look-ahead portion
    -- onto the next segment so distance continues to increase approaching any boundary.
    -- Start smoothing earlier on tight approaches so distance doesn't appear to stall
    local NEAR_END_T = 0.90        -- last 10% of segment
    local LOOKAHEAD_MAX = 35.0     -- cap look-ahead to 35m
    if segLen > 0.001 then
    local tAlong = segLen > 0 and (bestDist / segLen) or 0.0
        if tAlong > NEAR_END_T then
            -- look ahead onto the next big segment's first subsegment
            local nextNodes = buildSegmentNodes(math.min(segIdx + 1, n))
            if #nextNodes >= 2 then
                local nb = nextNodes[2] - nextNodes[1]
                local nbLen = #(nb)
                if nbLen > 0.001 then
                    local pFromEnd = pos - nextNodes[1]
                    local t2 = (pFromEnd.x*nb.x + pFromEnd.y*nb.y + pFromEnd.z*nb.z) / (nbLen * nbLen)
                    if t2 > 0.0 then
                        local extra = t2 * nbLen
                        if extra < 0.0 then extra = 0.0 end
                        if extra > LOOKAHEAD_MAX then extra = LOOKAHEAD_MAX end
                        local blend = (tAlong - NEAR_END_T) / (1.0 - NEAR_END_T)
                        if blend < 0.0 then blend = 0.0 elseif blend > 1.0 then blend = 1.0 end
                        total = total + (blend * extra)
                    end
                end
            end
        end
    end

    return total
end

-- Helper: world position of the vehicle's front bumper, for better pass-by accuracy
local function GetVehicleFrontWorldPos(veh)
    if not veh or veh == 0 then return nil end
    local model = GetEntityModel(veh)
    if not model or model == 0 then return GetEntityCoords(veh) end
    local minDim, maxDim = GetModelDimensions(model)
    -- length along Y axis; add a small fudge to reach beyond the center
    local halfLen = ((maxDim.y or 0.0) - (minDim.y or 0.0)) * 0.5
    if halfLen <= 0.01 then
        -- fallback: assume ~1.8m half length for small cars
        halfLen = 1.8
    end
    -- safer: use native to transform local offset to world coords
    local front = GetOffsetFromEntityInWorldCoords(veh, 0.0, halfLen, 0.0)
    return front or GetEntityCoords(veh)
end

-- Optional: compute both front-left and front-right nose points for better edge detection
local function GetVehicleNoseWorldPoints(veh)
    local pts = {}
    if not veh or veh == 0 then return pts end
    local model = GetEntityModel(veh)
    if not model or model == 0 then
        pts[1] = GetEntityCoords(veh)
        return pts
    end
    local minDim, maxDim = GetModelDimensions(model)
    local halfLen = ((maxDim.y or 0.0) - (minDim.y or 0.0)) * 0.5
    local halfWid = ((maxDim.x or 0.0) - (minDim.x or 0.0)) * 0.5
    if halfLen <= 0.01 then halfLen = 1.8 end
    if halfWid <= 0.01 then halfWid = 0.9 end
    -- front center
    pts[#pts+1] = GetOffsetFromEntityInWorldCoords(veh, 0.0, halfLen, 0.0)
    -- front corners
    pts[#pts+1] = GetOffsetFromEntityInWorldCoords(veh, halfWid, halfLen, 0.0)
    pts[#pts+1] = GetOffsetFromEntityInWorldCoords(veh, -halfWid, halfLen, 0.0)
    return pts
end

-- Attempt to grant keys for a vehicle across common key resources
-- GiveVehicleKeys(veh) is defined in client/c_keys.lua

--------------------------------------------------------------------------------
-- 6) UNIVERSAL NOTIFY & ALERT
--------------------------------------------------------------------------------
function SpeedwayNotify(title, description, ntype, duration)
    local provider = Config.NotificationProvider or "ox_lib"
    if provider == "okokNotify" then
        exports['okokNotify']:Alert(title or "", description or "", duration or 5000, ntype or "info")
    elseif provider == "ox_lib" then
        lib.notify({ title = title or "", description = description or "", type = ntype or "inform", position = "topLeft", duration = duration or 5000 })
    elseif provider == "rtx_notify" then
        exports['rtx_notify']:SendNotification({ title = title or "", text = description or "", icon = ntype or "info", length = duration or 5000, position = "topLeft" })
    else
        print(("[Speedway][%s] %s: %s"):format(provider, title or "Notice", description or ""))
    end
end

function SpeedwayAlert(header, content, duration)
    local provider = Config.NotificationProvider or "ox_lib"
    if provider == "okokNotify" or provider == "ox_lib" then
        lib.alertDialog({ header = header or "", content = content or "", centered = true, duration = duration or 10000 })
    elseif provider == "rtx_notify" then
        exports['rtx_notify']:SendNotification({ title = header or "", text = content or "", icon = "info", length = duration or 10000 })
    else
        lib.notify({ title = header or "", description = content or "", type = "error", position = "topLeft", duration = duration or 5000 })
    end
end

--------------------------------------------------------------------------------
-- 7) COUNTDOWN UI
--------------------------------------------------------------------------------
function ShowCountdownText(text, duration)
    local endTime = GetGameTimer() + duration
    while GetGameTimer() < endTime do
        SetTextFont(4); SetTextScale(1.5,1.5); SetTextCentre(true)
        SetTextDropshadow(0,0,0,0,255)
        BeginTextCommandDisplayText("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandDisplayText(0.5,0.4)
        Wait(0)
    end
end

--------------------------------------------------------------------------------
-- 8) LOBBY PED & TARGET SETUP
--------------------------------------------------------------------------------
CreateThread(function()
    local cfg = Config.LobbyPed
    RequestModel(cfg.model)
    while not HasModelLoaded(cfg.model) do Wait(0) end

    local ped = CreatePed(0, cfg.model, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.coords.w, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            { event = 'speedway:client:createLobby', icon = 'fa-solid fa-flag-checkered', label = loc("create_lobby"), canInteract = function() return not hasLobby end },
            { event = 'speedway:client:joinLobby',   icon = 'fa-solid fa-user-plus',         label = loc("join_lobby"),   canInteract = function() return hasLobby and not currentLobby end },
        },
        distance = 2.5
    })

    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, 315); SetBlipDisplay(blip, 4); SetBlipScale(blip, 0.8); SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING"); AddTextComponentString("Roxwood Speedway"); EndTextCommandSetBlipName(blip)
end)

--------------------------------------------------------------------------------
-- 9) LOBBY STATE HANDLERS
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:setLobbyState', function(state)
    hasLobby = state
    if not state then currentLobby, lobbyOwner = nil, nil end
end)
RegisterNetEvent('speedway:updateLobbyInfo', function(info)
    if inRace then
        -- Don't show lobby window during a race
        return
    end
    if info and info.name then
        hasLobby     = true
        currentLobby = info.name
        lobbyOwner   = info.owner
        -- Show persistent lobby window with current players
        local names = {}
        if info.players then
            for _, sid in ipairs(info.players) do
                local pid   = GetPlayerFromServerId(sid)
                local pname = pid and GetPlayerName(pid) or ("ID"..sid)
                table.insert(names, pname)
            end
        end
    local displayName = info and info.hostName or "UnknownHost"
    if Config.DebugPrints then
        print("[DEBUG] ShowLobbyDisplay called: hostName=" .. tostring(displayName) .. ", members=" .. table.concat(names, ", "))
    end
    ShowLobbyDisplay(displayName, names)
    else
        hasLobby, currentLobby, lobbyOwner = false, nil, nil
        HideLobbyDisplay()
    end
end)

--------------------------------------------------------------------------------
-- 10) CREATE / JOIN / START / LEAVE
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:client:createLobby', function()
    if Config.DebugPrints then
        print("[DEBUG] speedway:client:createLobby event triggered")
    end
    local dialog = exports['qb-input']:ShowInput({
        header     = loc("create_lobby"),
        submitText = loc("submit"),
        inputs     = {
            { text = loc("number_of_laps"), name = "lapCount", type = "number", isRequired = true, min = 1, max = 10, default = 3 },
            { text = loc("select_track"),   name = "trackType", type = "select", isRequired = true, default = "Short_Track",
              options = {
                  { value = "Short_Track", text = loc("Short_Track") },
                  { value = "Drift_Track",  text = loc("Drift_Track")  },
                  { value = "Speed_Track",  text = loc("Speed_Track")  },
                  { value = "Long_Track",   text = loc("Long_Track")   },
              },
            },
        },
    })
    if not dialog then if Config.DebugPrints then print("[DEBUG] qb-input dialog not returned") end return end

    local lapCount  = tonumber(dialog.lapCount) or 1
    local trackType = dialog.trackType
    local lobbyName = GetPlayerName(PlayerId()) .. "_" .. math.random(1000,9999)
    if Config.DebugPrints then
        print(string.format("[DEBUG] TriggerServerEvent speedway:createLobby: lobbyName=%s, trackType=%s, lapCount=%s", lobbyName, trackType, lapCount))
    end
    TriggerServerEvent("speedway:createLobby", lobbyName, trackType, lapCount)
end)

RegisterNetEvent('speedway:client:joinLobby', function()
    local lobbies = lib.callback.await("speedway:getLobbies", true)
    if not lobbies or #lobbies == 0 then
        SpeedwayNotify(loc("no_lobbies"), "", "error")
        return
    end
    local opts = {}
    for _, e in ipairs(lobbies) do table.insert(opts, { value = e.value, text = e.label }) end
    local dialog = exports['qb-input']:ShowInput({
        header     = loc("join_lobby"),
        submitText = loc("submit"),
        inputs     = {{ text = loc("select_lobby"), name = "selectedLobby", type = "select", isRequired = true, options = opts }},
    })
    if dialog and dialog.selectedLobby then
        TriggerServerEvent("speedway:joinLobby", dialog.selectedLobby)
    end
end)

RegisterNetEvent('speedway:client:startRace', function()
    if lobbyOwner ~= GetPlayerServerId(PlayerId()) then
        SpeedwayNotify("", loc("not_authorized_to_start_race"), "error")
        return
    end
    -- Hide lobby preview for the host immediately
    HideLobbyDisplay()
    CloseVehicleSelectionUI()
    local players = lib.callback.await("speedway:getLobbyPlayers", false, currentLobby)
    local names   = {}
    for _, sid in ipairs(players) do
        local pid   = GetPlayerFromServerId(sid)
        local pname = pid and GetPlayerName(pid) or ("ID"..sid)
        table.insert(names, pname)
    end
    SpeedwayNotify(loc("lobby_preview"), table.concat(names, "\n"), "inform", 10000)
    -- No ox_lib context menu to close; lobby window is native
    TriggerServerEvent("speedway:startRace", currentLobby)
end)

-- Hide lobby preview for all players on server signal
RegisterNetEvent('speedway:hideLobbyWindow', function()
    HideLobbyDisplay()
    CloseVehicleSelectionUI()
    -- Ensure interact mode is off
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'lobbyFocus', on = false })
end)

-- Vehicle selection countdown overlay
local selectCountdownActive = false
local selectCountdownRemain = 0
local timeoutModalActive = false

RegisterNetEvent("speedway:vehicleSelectCountdown", function(remaining)
    selectCountdownActive = remaining and remaining > 0
    selectCountdownRemain = remaining or 0
    if selectCountdownActive == false then
        CloseVehicleSelectionUI()
    end
end)

-- If race proceeds, ensure countdown hides
AddEventHandler("speedway:prepareStart", function()
    selectCountdownActive = false
    CloseVehicleSelectionUI()
end)

CreateThread(function()
    while true do
        Wait(0)
        if selectCountdownActive then
            local sec = math.max(0, tonumber(selectCountdownRemain) or 0)
            SetTextFont(4); SetTextScale(0.5,0.5); SetTextCentre(true)
            SetTextColour(255,200,50,255); SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString(("Select your vehicle (%02d)"):format(sec))
            DrawText(0.5, 0.12)
        end
    end
end)

-- Notify if kicked due to timeout
RegisterNetEvent("speedway:kickedFromLobby", function(lobbyName, reason)
    hasLobby, currentLobby, lobbyOwner = false, nil, nil
    HideLobbyDisplay()
    CloseVehicleSelectionUI()
    local message = reason == "timeout" and loc("vehicle_select_timeout") or loc("removed_from_lobby")
    -- Show blocking modal requiring player to acknowledge
    timeoutModalActive = true
    SetNuiFocusKeepInput(false)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showTimeoutModal', message = message })
    -- Keep focus on our modal until dismissed
    CreateThread(function()
        while timeoutModalActive do
            SetNuiFocus(true, true)
            Wait(0)
        end
    end)
end)

-- NUI callback when player clicks Dismiss on the blocking modal
RegisterNUICallback('timeoutDismiss', function(_, cb)
    SendNUIMessage({ action = 'hideTimeoutModal' })
    timeoutModalActive = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    cb('ok')
end)

--------------------------------------------------------------------------------
-- Auto-interact with lobby panel while holding target (Left Alt) near the lobby ped
--------------------------------------------------------------------------------
local autoFocusActive = false
speedwaySuppressAutoUntilAltUp = false

-- Removed Alt long-press simulated targeting loop; use F6 toggle for reliable interaction

RegisterNetEvent('speedway:client:leaveLobby', function()
    if not hasLobby then
        SpeedwayNotify(loc("no_lobby_joined"), loc("no_lobby_joined_desc"), "error")
        return
    end
    TriggerServerEvent("speedway:leaveLobby", currentLobby)
end)

--------------------------------------------------------------------------------
-- 11) VEHICLE SELECTION
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:chooseVehicle", function(lobbyName)
    local opts = {}
    for _, v in ipairs(Config.RaceVehicles) do
        table.insert(opts, { value = v.model, text = v.label })
    end
    local dialog = exports['qb-input']:ShowInput({
        header     = loc("choose_vehicle_title"),
        submitText = loc("submit"),
        inputs     = {{
            text       = loc("choose_vehicle_label"),
            name       = "selectedModel",
            type       = "select",
            isRequired = true,
            options    = opts,
            default    = opts[1].value
        }},
    })
    local sel = dialog and dialog.selectedModel or nil
    TriggerServerEvent("speedway:selectedVehicle", lobbyName, sel)
end)

--------------------------------------------------------------------------------
-- 12) PREPARE & START THE RACE (SPAWN + COUNTDOWN)
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:prepareStart", function(data)
    -- Hide lobby preview window for everyone once the race is about to start
    HideLobbyDisplay()
    -- Stop vehicle selection countdown if showing
    selectCountdownActive = false
    inRace       = true
    currentTrack = data.track
    -- Initialize HUD lap counters using payload laps so HUD shows 1/x from start
    currentLap   = 1
    totalLaps    = tonumber(data.laps) or totalLaps or 1

    -- clear old props
    TriggerEvent("speedway:client:destroyprops")

    -- spawn new props...
    for _, pd in ipairs(Config.TrackProps[data.track] or {}) do
        RequestModel(pd.prop); while not HasModelLoaded(pd.prop) do Wait(0) end
        for _, c in ipairs(pd.cords) do
            local obj = CreateObject(pd.prop, c.x, c.y, c.z - 1.0, false, false, false)
            PlaceObjectOnGroundProperly(obj); SetEntityHeading(obj, c.w); FreezeEntityPosition(obj, true)
            table.insert(currentProps, obj)
        end
    end

    -- checkpoint spheres
    racerCheckpointIndex = 0
    for idx, coord in ipairs(Config.Checkpoints[data.track] or {}) do
        lib.zones.sphere({
            coords = coord, radius = 15.0, debug = Config.ZoneDebug,
            onEnter = function()
                if idx == racerCheckpointIndex + 1 then
                    racerCheckpointIndex = idx
                    TriggerServerEvent("speedway:checkpointPassed", currentLobby, idx)
                end
            end
        })
    end

    -- finish line sphere
    lib.zones.sphere({
        name   = "finish_line",
        coords = Config.FinishLine.coords,
        radius = Config.FinishLine.radius,
        debug  = Config.ZoneDebug,
        onEnter = function()
            if racerCheckpointIndex == #Config.Checkpoints[data.track] then
                racerCheckpointIndex = 0
                TriggerServerEvent("speedway:lapPassed", currentLobby, GetPlayerServerId(PlayerId()))
            end
        end
    })

    -- now spawn & race
    CreateThread(function()
        -- wait for the vehicle entity to exist
        while not NetworkDoesNetworkIdExist(data.netId) do Wait(0) end
        local veh = NetworkGetEntityFromNetworkId(data.netId)
        while not DoesEntityExist(veh) do Wait(0); veh = NetworkGetEntityFromNetworkId(data.netId) end

    -- prep vehicle
    SetEntityAsMissionEntity(veh, true, true)
    FreezeEntityPosition(veh, true)
    -- Give keys as early as possible (before any engine state changes)
    GiveVehicleKeys(veh)

    -- Apply fuel and full cosmetics BEFORE putting the player in to avoid visible pop
    SetFullFuel(veh)
    if Speedway_ApplyAll then Speedway_ApplyAll(veh) end
    -- Engine ON before countdown so drivers can launch instantly at GO
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleUndriveable(veh, true)

    -- Put player in the vehicle after customization
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    repeat Wait(0) until IsPedInAnyVehicle(PlayerPedId(), false)

    -- (keys were already granted before customization)

    -- Force-unlock on client as well (some key scripts toggle later)
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleDoorsLockedForAllPlayers(veh, false)
    SetVehicleDoorsLockedForPlayer(veh, PlayerId(), false)

        -- Apply the desired name-based plate AFTER cosmetics to avoid any overwrite
        local desiredPlate = (data and data.plate) or (GetVehicleNumberPlateText(veh) or "")
        if desiredPlate and desiredPlate ~= "" then
            SetVehicleNumberPlateText(veh, desiredPlate)
            if Config.DebugPrints then
                print(("[DEBUG] Applied name plate after cosmetics -> '%s'"):format(tostring(desiredPlate)))
            end
            -- Reassert a couple times to fight streaming/ownership races
            CreateThread(function()
                local untilTs = GetGameTimer() + 800
                while GetGameTimer() < untilTs and DoesEntityExist(veh) do
                    SetVehicleNumberPlateText(veh, desiredPlate)
                    Wait(120)
                end
            end)
        end

        -- Reassert FULL FUEL for a short window in case other scripts set it later
        CreateThread(function()
            local untilTs = GetGameTimer() + 2500
            while GetGameTimer() < untilTs and DoesEntityExist(veh) do
                if SetFullFuel then SetFullFuel(veh) end
                Wait(200)
            end
        end)

        -- Keep doors unlocked during initialization for a short window to override scripts
        CreateThread(function()
            local tEnd = GetGameTimer() + 3000
            while GetGameTimer() < tEnd and DoesEntityExist(veh) do
                SetVehicleDoorsLocked(veh, 1)
                SetVehicleDoorsLockedForAllPlayers(veh, false)
                SetVehicleDoorsLockedForPlayer(veh, PlayerId(), false)
                Wait(150)
            end
        end)

        -- countdown
            -- Use configurable race start delay
            local delay = Config.RaceStartDelay or 3
            for i = delay, 1, -1 do
                FreezeEntityPosition(veh, true)
                -- Keep engine running during countdown
                SetVehicleEngineOn(veh, true, true, false)
                ShowCountdownText(tostring(i), 1000)
            end
            ShowCountdownText("GO", 1000)
            FreezeEntityPosition(veh, false)
            SetVehicleUndriveable(veh, false)
            SetVehicleHandbrake(veh, false)

        -- Post-GO safety: briefly assert drivability and unlock state without touching engine
        CreateThread(function()
            local untilTs = GetGameTimer() + 3000
            while GetGameTimer() < untilTs and DoesEntityExist(veh) do
                FreezeEntityPosition(veh, false)
                SetVehicleUndriveable(veh, false)
                SetVehicleHandbrake(veh, false)
                SetVehicleDoorsLocked(veh, 1)
                SetVehicleDoorsLockedForAllPlayers(veh, false)
                SetVehicleDoorsLockedForPlayer(veh, PlayerId(), false)
                Wait(100)
            end
        end)

    -- No key or cosmetic changes after GO to avoid any side-effects

    -- (fuel/cosmetics were already applied before entering the vehicle)

        -- start progress reporter
        CreateThread(function()
            while inRace do
                local v = GetVehiclePedIsIn(PlayerPedId(), false)
                if v and v ~= 0 then
                    -- Use nose points to decide the most advanced extreme
                    local dist
                    if Config.DistanceUseNoseCorners then
                        local pts = GetVehicleNoseWorldPoints(v)
                        local best = 0.0
                        for _, p in ipairs(pts) do
                            local d = ComputeDistanceAlongTrack(p)
                            if d > best then best = d end
                        end
                        dist = best
                    else
                        local frontPos = GetVehicleFrontWorldPos(v) or GetEntityCoords(v)
                        dist = ComputeDistanceAlongTrack(frontPos)
                    end
                    if Config.DebugPrints then
                        print(("[DEBUG] updateProgress dist=%.2f lobby=%s"):format(dist, tostring(currentLobby)))
                    end
                    TriggerServerEvent("speedway:updateProgress", currentLobby, dist)
                end
                Wait(Config.ProgressTickMs or 200)
            end
        end)
    end)
end)

RegisterNetEvent("speedway:youFinished", function()
    SpeedwayNotify("🏁 Speedway", loc("you_finished"), "success", 5000)
end)

--------------------------------------------------------------------------------
-- 14) FINAL RANKING
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:finalRanking", function(data)
    local results = data.allResults or {}
    if not data.position then
        local lines = { loc("podium_header") }
        for i,e in ipairs(results) do
            local name = GetPlayerName(GetPlayerFromServerId(e.id)) or ("ID"..e.id)
            lines[#lines+1] = ("%d. %s — %ds"):format(i, name, math.floor(e.time/1000))
        end
        SpeedwayNotify("", table.concat(lines, "\n"), "inform", 10000)
        return
    end

    local totalTime = math.floor((data.totalTime or 0)/1000)
    if data.position == 1 then
        SpeedwayNotify("🏆 Speedway", loc("you_won", totalTime), "success", 5000)
    else
        SpeedwayNotify("🏁 Speedway", loc("you_placed", data.position, #results, totalTime), "inform", 5000)
    end
    if data.lapTimes then
        local lapLines = { loc("lap_summary") }
        for i,t in ipairs(data.lapTimes) do
            lapLines[#lapLines+1] = loc("lap_time", i, math.floor(t/1000))
        end
        lapLines[#lapLines+1] = loc("best_lap", math.floor((data.bestLap or 0)/1000))
        SpeedwayNotify(loc("lap_summary"), table.concat(lapLines, "\n"), "info", 10000)
    end
end)

--------------------------------------------------------------------------------
-- 15) FINISH TELEPORT
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:client:finishTeleport", function(coords)
    inRace = false
    CreateThread(function()
        DoScreenFadeOut(1000); while not IsScreenFadedOut() do Wait(0) end

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local v = GetVehiclePedIsIn(ped, false)
            TaskLeaveVehicle(ped, v, 0); Wait(500)
            if DoesEntityExist(v) then DeleteVehicle(v) end
        end

        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
        SetEntityHeading(ped, coords.w)
        Wait(500); DoScreenFadeIn(1000)
    end)
end)

--------------------------------------------------------------------------------
-- 16) FUEL AUTO-FILL EVENT
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:client:fillFuel", function(netId)
    local v = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(v) then SetFullFuel(v) end
end)

-- Use globals so values set during prepareStart are reflected here too
currentLap, totalLaps = currentLap or 1, totalLaps or 1

RegisterNetEvent("speedway:updateLap", function(cur, tot)
    currentLap, totalLaps = cur, tot
    SpeedwayNotify("🏁 Speedway", ("Lap %s/%s"):format(cur, tot), "inform", 3000)
end)

RegisterNetEvent("speedway:updatePosition", function(position, total)
    myPosition = position
    totalRacers = total
    if Config.DebugPrints then
        print(("[DEBUG] updatePosition myPosition=%s total=%s"):format(tostring(myPosition), tostring(totalRacers)))
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if inRace then
            -- Draw position/rank
            SetTextFont(4); SetTextScale(0.5,0.5); SetTextCentre(true)
            SetTextColour(255,255,255,255); SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString( ("Position: %d/%d"):format(myPosition, totalRacers) )
            DrawText(0.5, 0.93)

            -- Draw lap info
            SetTextFont(4); SetTextScale(0.45,0.45); SetTextCentre(true)
            SetTextColour(255,255,255,255); SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString( ("Lap: %d/%d"):format(currentLap, totalLaps) )
            DrawText(0.5, 0.96)
        end
    end
end)

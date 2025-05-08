local QBCore = exports['qb-core']:GetCoreObject()
lib.locale()
local config = require "config.config"

local notifyProvider = config.NotificationProvider or "ox_lib"

--- Universal notify(title,desc,type,duration)
local function SpeedwayNotify(title, description, ntype, duration)
    if notifyProvider == "okokNotify" then
        exports['okokNotify']:Alert(
            title or "",
            description or "",
            duration or 5000,
            ntype   or "info",
            "bottomRight"
        )
    else
        lib.notify({
            title       = title or "",
            description = description or "",
            type        = ntype   or "inform"
        })
    end
end

--- Universal alertPopup(header,content,duration)
local function SpeedwayAlert(header, content, duration)
    if notifyProvider == "okokNotify" then
        exports['okokNotify']:Alert(
            header    or "",
            content   or "",
            duration  or 10000,
            "info",
            "bottomRight"
        )
    else
        lib.alertDialog({
            header   = header    or "",
            content  = content   or "",
            centered = true
        })
    end
end

-- helper to show big centered text for a given duration (in ms)
function ShowCountdownText(text, duration)
    local endTime = GetGameTimer() + duration
    while GetGameTimer() < endTime do
        SetTextFont(4)
        SetTextScale(1.5, 1.5)
        SetTextCentre(true)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(0.5, 0.4)
        Wait(0)
    end
end

-- track whether we’re in a lobby, what its name is, and who the host is
local hasLobby     = false
local currentLobby = nil
local lobbyOwner   = nil
local currentProps = {}
local racerCheckpointIndex = 0

-- in‑race HUD
local inRace      = false
local myPosition  = 0
local totalRacers = 0

-- receive live position updates from server
RegisterNetEvent("speedway:updatePosition", function(pos, total)
    --print(("[speedway HUD] updatePosition → %d/%d"):format(pos, total))
    myPosition  = pos
    totalRacers = total
end)

-- clean up spawned props on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerEvent("speedway:client:destroyprops")
    end
end)

RegisterNetEvent('speedway:client:destroyprops', function()
    for _, obj in ipairs(currentProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    currentProps = {}
end)

--------------------------------------------------------------------------------
-- LOBBY STATE HANDLERS
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:setLobbyState', function(state)
    hasLobby = state
    if not state then currentLobby, lobbyOwner = nil, nil end
end)

RegisterNetEvent('speedway:updateLobbyInfo', function(info)
    if info and info.name then
        hasLobby     = true
        currentLobby = info.name
        lobbyOwner   = info.owner
    else
        hasLobby, currentLobby, lobbyOwner = false, nil, nil
    end
end)

--------------------------------------------------------------------------------
-- LOBBY PED & TARGET SETUP
--------------------------------------------------------------------------------
CreateThread(function()
    local cfg = config.LobbyPed
    RequestModel(cfg.model)
    while not HasModelLoaded(cfg.model) do Wait(0) end

    local ped = CreatePed(0, cfg.model,
        cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0,
        cfg.coords.w, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            { event = 'speedway:client:createLobby', icon = 'fa-solid fa-flag-checkered', label = locale('create_lobby') },
            { event = 'speedway:client:joinLobby',   icon = 'fa-solid fa-user-plus',      label = locale('join_lobby') },
            { event = 'speedway:client:startRace',   icon = 'fa-solid fa-flag-checkered', label = locale('start_race') },
            { event = 'speedway:client:leaveLobby',  icon = 'fa-solid fa-sign-out-alt',   label = locale('leave_lobby') },
        },
        distance = 2.5
    })

    local blip = AddBlipForCoord(cfg.coords.x, cfg.coords.y, cfg.coords.z)
    SetBlipSprite(blip, 315)             -- 315 = land race flag icon
    SetBlipDisplay(blip, 4)             -- show on main map & minimap
    SetBlipScale(blip, 0.8)             -- a bit smaller
    SetBlipAsShortRange(blip, false)     -- always show on minimap
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Roxwood Speedway")
    EndTextCommandSetBlipName(blip)
end)

--------------------------------------------------------------------------------
-- CREATE LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:client:createLobby', function()
    local dialog = exports['qb-input']:ShowInput({
        header     = locale("create_lobby"),
        submitText = locale("submit"),
        inputs     = {
            { text = locale("number_of_laps"), name = "lapCount", type = "number", isRequired = true, min = 1, max = 10, default = 3 },
            { text = locale("select_track"),   name = "trackType", type = "select", isRequired = true, default = "Short_Track",
              options = {
                  { value = "Short_Track", text = locale("Short_Track") },
                  { value = "Drift_Track",  text = locale("Drift_Track")  },
                  { value = "Speed_Track",  text = locale("Speed_Track")  },
                  { value = "Long_Track",   text = locale("Long_Track")   },
              },
            },
        },
    })
    if not dialog then return end

    local lapCount  = tonumber(dialog.lapCount) or 1
    local trackType = dialog.trackType
    local lobbyName = GetPlayerName(PlayerId()) .. "_" .. math.random(1000,9999)

    TriggerServerEvent("speedway:createLobby", lobbyName, trackType, lapCount)
end)

--------------------------------------------------------------------------------
-- JOIN LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:client:joinLobby', function()
    local lobbies = lib.callback.await("speedway:getLobbies", true)
    if not lobbies or #lobbies == 0 then
        SpeedwayNotify(locale("no_lobbies"), "", "error")
        return
    end

    local opts = {}
    for _, e in ipairs(lobbies) do
        table.insert(opts, { value = e.value, text = e.label })
    end

    local dialog = exports['qb-input']:ShowInput({
        header     = locale("join_lobby"),
        submitText = locale("submit"),
        inputs     = {
            { text = locale("select_lobby"), name = "selectedLobby", type = "select", isRequired = true, options = opts }
        },
    })
    if dialog and dialog.selectedLobby then
        TriggerServerEvent("speedway:joinLobby", dialog.selectedLobby)
    end
end)

--------------------------------------------------------------------------------
-- START/LEAVE RACE
--------------------------------------------------------------------------------
RegisterNetEvent('speedway:client:startRace', function()
    if lobbyOwner ~= GetPlayerServerId(PlayerId()) then
        SpeedwayNotify("", locale("not_authorized_to_start_race"), "error")
        return
    end
    TriggerServerEvent("speedway:startRace", currentLobby)
end)

RegisterNetEvent('speedway:client:leaveLobby', function()
    if not hasLobby then
        SpeedwayNotify(locale("no_lobby_joined"), locale("no_lobby_joined_desc"), "error")
        return
    end
    TriggerServerEvent("speedway:leaveLobby", currentLobby)
end)

--------------------------------------------------------------------------------
-- VEHICLE CHOICE CALLBACK
--------------------------------------------------------------------------------
lib.callback.register("speedway:getVehicleChoice", function(_, cb)
    local opts = {}
    for _, v in ipairs(config.RaceVehicles) do
        table.insert(opts, { value = v.model, text = v.label })
    end

    local dialog = exports['qb-input']:ShowInput({
        header     = locale("choose_vehicle_title"),
        submitText = locale("submit"),
        inputs     = {
            { text = locale("choose_vehicle_label"), name = "selectedModel", type = "select", isRequired = true,
              options = opts, default = opts[1].value }
        },
    })
    return dialog and dialog.selectedModel or nil
end)

--------------------------------------------------------------------------------
-- RACE PREP & CHECKPOINTS
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:prepareStart", function(data)
    -- turn on the HUD
    inRace = true

    -- 1) spawn track props
    local props = config.TrackProps[data.track] or {}
    for _, pd in ipairs(props) do
        RequestModel(pd.prop)
        while not HasModelLoaded(pd.prop) do Wait(0) end
    end
    for _, pd in ipairs(props) do
        for _, c in ipairs(pd.cords) do
            local obj = CreateObject(pd.prop, c.x, c.y, c.z - 1.0, false, false, false)
            PlaceObjectOnGroundProperly(obj)
            SetEntityHeading(obj, c.w)
            FreezeEntityPosition(obj, true)
            table.insert(currentProps, obj)
        end
    end

    -- 2) checkpoint spheres in order
    racerCheckpointIndex = 0
    for idx, coord in ipairs(config.Checkpoints[data.track] or {}) do
        lib.zones.sphere({
            coords = coord,
            radius = 5.0,
            debug  = config.debug,
            onEnter = function()
                if idx == racerCheckpointIndex + 1 then
                    racerCheckpointIndex = idx
                    TriggerServerEvent("speedway:checkpointPassed", data.track, idx)
                end
            end
        })
    end

    -- 3) finish‐line polygon (only after all checkpoints)
    lib.zones.poly({
        name      = "start_line",
        points    = config.StartLinePoints,
        thickness = 3.0,
        debug     = config.debug,
        onEnter = function()
            if racerCheckpointIndex == #config.Checkpoints[data.track] then
                racerCheckpointIndex = 0
                TriggerServerEvent("speedway:lapPassed", currentLobby, GetPlayerServerId(PlayerId()))
            end
        end
    })

    -- 4) warp you into your vehicle & do the 3‑2‑1‑GO
    local veh = NetworkGetEntityFromNetworkId(data.netId)
    while not DoesEntityExist(veh) do Wait(0) end
    SetEntityAsMissionEntity(veh, true, true)
    FreezeEntityPosition(veh, true)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)

    for i = 3, 1, -1 do
        PlaySoundFrontend(-1, "3_2_1", "HUD_MINI_GAME_SOUNDSET", true)
        ShowCountdownText(tostring(i), 1000)
    end
    PlaySoundFrontend(-1, "GO", "HUD_MINI_GAME_SOUNDSET", true)
    ShowCountdownText("GO", 1000)

    FreezeEntityPosition(veh, false)
end)

--------------------------------------------------------------------------------
-- LAP & FINISH NOTIFICATIONS
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:updateLap", function(current, total)
    SpeedwayNotify("🏁 Speedway", ("Lap %s/%s"):format(current, total), "inform", 3000)
end)

RegisterNetEvent("speedway:youFinished", function()
    SpeedwayNotify("🏁 Speedway", locale("you_finished"), "success", 5000)
end)

--------------------------------------------------------------------------------
-- FINAL RANKING (auto‑close)
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:finalRanking", function(data)
    local results = data.allResults or {}
    if data.position == nil then
        local lines = { "🏆 Speedway Podium:" }
        for i,e in ipairs(results) do
            local name = GetPlayerName(GetPlayerFromServerId(e.id)) or ("ID "..e.id)
            lines[#lines+1] = ("%d. %s — %ds"):format(i, name, math.floor((e.time or 0)/1000))
        end
        SpeedwayNotify("", table.concat(lines, "\n"), "inform", 10000)
        return
    end
    local totalS = math.floor((data.totalTime or 0)/1000)
    if data.position == 1 then
        SpeedwayNotify("🏆 Speedway", ("You won! Time: %ds"):format(totalS), "success", 5000)
    else
        SpeedwayNotify("🏁 Speedway", ("You placed %d/%d – %ds"):format(data.position, #results, totalS), "inform", 5000)
    end
    if data.lapTimes then
        local lapLines = { "🏁 Your Lap Times:" }
        for i,t in ipairs(data.lapTimes) do
            lapLines[#lapLines+1] = ("Lap %d: %ds"):format(i, math.floor(t/1000))
        end
        lapLines[#lapLines+1] = ("Best Lap: %ds"):format(math.floor((data.bestLap or 0)/1000))
        SpeedwayNotify("🏁 Lap Summary", table.concat(lapLines, "\n"), "info", 10000)
    end
end)

--------------------------------------------------------------------------------
-- FINISH TELEPORT (with fade)
--------------------------------------------------------------------------------

RegisterNetEvent("speedway:client:finishTeleport", function(coords)
    inRace = false

    -- fade out first
    DoScreenFadeOut(1000)
    while not IsScreenFadedOut() do Wait(0) end

    local ped = PlayerPedId()

    -- if in vehicle, delete it during fade out
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, veh, 0)
        Wait(500)
        DeleteVehicle(veh)
    end

    -- teleport player while screen is black
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.w)

    -- wait a bit, then fade back in
    Wait(500)
    DoScreenFadeIn(1000)
end)


-- FUEL SYSTEM AUTO DETECTION
RegisterNetEvent("speedway:client:fillFuel", function(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return end

    -- native FiveM fuel
    SetVehicleFuelLevel(veh, 100.0)

    -- LegacyFuel
    if GetResourceState("LegacyFuel") == "started" then exports["LegacyFuel"]:SetFuel(veh, 100) end

    -- cdn‑fuel
    if GetResourceState("cdn-fuel") == "started" then exports["cdn-fuel"]:SetFuel(veh, 100) end

    -- okokGasStation
    if GetResourceState("okokGasStation") == "started" then exports["okokGasStation"]:SetFuel(veh, 100) end

    -- ox_fuel
    if GetResourceState("ox_fuel") == "started" then Entity(veh).state.fuel = 100.0 end
end)

-- DRAW THE “Pos X/Y” HUD
CreateThread(function()
    while true do
        Wait(0)
        if inRace then
            SetTextFont(4)
            SetTextScale(0.5, 0.5)
            SetTextCentre(true)           -- center the text
            SetTextColour(255, 255, 255, 255)
            SetTextOutline()
            SetTextEntry("STRING")
            AddTextComponentString( ("Pos %d/%d"):format(myPosition, totalRacers) )
            DrawText(0.5, 0.95)            -- bottom‑center of screen
        end
    end
end)

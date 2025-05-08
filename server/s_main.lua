local QBCore = exports['qb-core']:GetCoreObject()
lib.locale()
local config = require "config.config"

local lobbies = {}
local selectedVehicles = {}
RaceVehicles = {} -- [playerId] = vehicleEntity

--#region events

RegisterNetEvent("speedway:createLobby", function(lobbyName, trackType, lapCount)
    local src = source
    if lobbies[lobbyName] then
        TriggerClientEvent('ox_lib:notify', src, {
            description = locale("lobby_exists"),
            type        = "error"
        })
        return
    end

    lobbies[lobbyName] = {
        owner       = src,
        track       = trackType,
        laps        = lapCount or 1,
        players     = { src },
        isStarted   = false,
        lapProgress = {},
        finished    = {},
        lapTimes    = {},
        startTime   = {},
    }

    for _, id in ipairs(lobbies[lobbyName].players) do
        TriggerClientEvent("speedway:updateLobbyInfo", id, {
            name    = lobbyName,
            track   = lobbies[lobbyName].track,
            players = lobbies[lobbyName].players,
            owner   = lobbies[lobbyName].owner,
            laps    = lobbies[lobbyName].laps
        })
    end

    TriggerClientEvent('ox_lib:notify', src, {
        description = locale("lobby_created", lobbyName),
        type        = "success"
    })
    TriggerClientEvent('speedway:setLobbyState', -1, next(lobbies) ~= nil)
end)

RegisterNetEvent("speedway:joinLobby", function(lobbyName)
    local src = source
    local lobby = lobbies[lobbyName]
    if not lobby then
        TriggerClientEvent('ox_lib:notify', src, {
            title       = "Speedway",
            description = locale("lobby_not_found"),
            type        = "error"
        })
        return
    end

    if not table.contains(lobby.players, src) then
        table.insert(lobby.players, src)
    end

    for _, id in ipairs(lobby.players) do
        TriggerClientEvent("speedway:updateLobbyInfo", id, {
            name    = lobbyName,
            track   = lobby.track,
            players = lobby.players,
            owner   = lobby.owner
        })
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title       = "Speedway",
        description = locale("joined_lobby", lobbyName),
        type        = "success"
    })
end)

RegisterNetEvent("speedway:leaveLobby", function()
    local src = source
    for name, lobby in pairs(lobbies) do
        for i, id in ipairs(lobby.players) do
            if id == src then
                table.remove(lobby.players, i)
                if lobby.owner == src then
                    for _, player in ipairs(lobby.players) do
                        TriggerClientEvent('ox_lib:notify', player, {
                            title       = "Speedway",
                            description = locale("lobby_closed_by_owner", name),
                            type        = "warning"
                        })
                        TriggerClientEvent("speedway:updateLobbyInfo", player, nil)
                    end
                    lobbies[name] = nil
                else
                    for _, player in ipairs(lobby.players) do
                        TriggerClientEvent("speedway:updateLobbyInfo", player, {
                            name    = name,
                            track   = lobby.track,
                            players = lobby.players,
                            owner   = lobby.owner
                        })
                    end
                end
                TriggerClientEvent("speedway:setLobbyState", -1, next(lobbies) ~= nil)
                return
            end
        end
    end
end)

RegisterNetEvent("speedway:startRace", function(lobbyName)
    local src   = source
    local lobby = lobbies[lobbyName]
    if not lobby then
        TriggerClientEvent('ox_lib:notify', src, {
            description = locale("lobby_not_found"),
            type        = "error"
        })
        return
    end
    if lobby.owner ~= src then
        TriggerClientEvent('ox_lib:notify', src, {
            description = locale("not_authorized_to_start_race"),
            type        = "error"
        })
        return
    end

    lobby.isStarted = true

    -- initialize timers
    local now = GetGameTimer()
    for _, pid in ipairs(lobby.players) do
        lobby.startTime[pid]   = now
        lobby.lapProgress[pid] = 0
        lobby.lapTimes[pid]    = {}
    end

    -- live‐update leaderboard every second, toggling names/times
    CreateThread(function()
        local toggle = true
        while lobbies[lobbyName] and lobbies[lobbyName].isStarted do
            Wait(1000)
            if config.Leaderboard.enabled then
                local board = {}
                local now   = GetGameTimer()
                for _, pid in ipairs(lobby.players) do
                    local laps    = lobby.lapProgress[pid] or 0
                    local elapsed = 0
                    for _, t in ipairs(lobby.lapTimes[pid] or {}) do elapsed = elapsed + t end
                    if lobby.startTime[pid] then
                        elapsed = elapsed + (now - lobby.startTime[pid])
                    end
                    table.insert(board, { id = pid, score = laps * 1e9 - elapsed })
                end
                table.sort(board, function(a,b) return a.score > b.score end)

                -- build "X/Y" header
                local anyPlayer    = lobby.players[1]
                local currentLap   = lobby.lapProgress[anyPlayer] or 0
                local totalLaps    = lobby.laps
                local displayTitle = ("%d/%d"):format(currentLap, totalLaps)

                -- alternate between times and names
                local names, times = {}, {}
                for _, e in ipairs(board) do
                    local ply = QBCore.Functions.GetPlayer(e.id)
                    local nm  = ply and ply.PlayerData.charinfo.firstname or ("ID"..e.id)
                    table.insert(names, nm)
                    local elapsed = (lobby.lapProgress[e.id] or 0) * 1e9 - e.score
                    table.insert(times, math.floor(elapsed))
                end

                if toggle then
                    TriggerEvent("amir-leaderboard:setPlayerTimes", displayTitle, times)
                else
                    TriggerEvent("amir-leaderboard:setPlayerNames", displayTitle, names)
                end

                -- build laps in the same order
                local laps = {}
                for i, e2 in ipairs(board) do
                    laps[i] = lobby.lapProgress[e2.id] or 0
                end
                -- send laps to the leaderboard
                TriggerEvent("amir-leaderboard:setPlayerLaps", displayTitle, laps)

                -- tell each racer their personal position in the board
                for pos, entry in ipairs(board) do
                    TriggerClientEvent("speedway:updatePosition", entry.id, pos, #board)
                end

                toggle = not toggle
            end
        end
    end)

    -- vehicle spawn (fuel fill moved client‑side)
    local selected = {}
    for i, pid in ipairs(lobby.players) do
        lib.callback("speedway:getVehicleChoice", pid, function(model)
            if model then selected[pid] = model end
            if #lobby.players == (function() local c=0 for _ in pairs(selected) do c=c+1 end return c end)() then
                for idx, p in ipairs(lobby.players) do
                    local spawn = config.GridSpawnPoints[idx]
                    local veh   = CreateVehicle(joaat(selected[p]), spawn.x, spawn.y, spawn.z, spawn.w, true, false)
                    while not DoesEntityExist(veh) do Wait(0) end

                    local netId = NetworkGetNetworkIdFromEntity(veh)
                    TriggerClientEvent("speedway:client:fillFuel", p, netId)
                    TriggerClientEvent('vehiclekeys:client:SetOwner', p, plate)
                    RaceVehicles[p] = veh
                    TriggerClientEvent("speedway:prepareStart", p, { track = lobby.track, netId = netId })
                end
            end
        end)
    end
end)

-------------------------------------------------------------------
-- LAP PASSING & RACE END (server)
-------------------------------------------------------------------
RegisterNetEvent("speedway:lapPassed", function(lobbyName, forcedSrc)
    local src   = forcedSrc or source
    local lobby = lobbies[lobbyName]
    if not lobby then return end

    -- advance this player’s lap count
    lobby.lapProgress[src] = (lobby.lapProgress[src] or 0) + 1
    local currentLap = lobby.lapProgress[src]
    local totalLaps  = lobby.laps

    -- record lap time
    local now = GetGameTimer()
    lobby.startTime     = lobby.startTime     or {}
    lobby.lapTimes      = lobby.lapTimes      or {}
    lobby.lapTimes[src] = lobby.lapTimes[src] or {}
    if lobby.startTime[src] then
        table.insert(lobby.lapTimes[src], now - lobby.startTime[src])
    end
    lobby.startTime[src] = now

    -- If this player just completed the race
    if currentLap >= totalLaps then

        -- mark finished
        if not lobby.finished[src] then
            lobby.finished[src] = true

            -- 1) teleport this player out immediately
            TriggerClientEvent("speedway:client:finishTeleport", src, config.outCoords)

            -- 2) send personal result
            local yourTime = 0
            for _, t in ipairs(lobby.lapTimes[src] or {}) do yourTime = yourTime + t end

            -- determine your position among those finished so far
            local position = 0
            for _, pid in ipairs(lobby.players) do
                if lobby.finished[pid] then position = position + 1 end
            end

            -- compute best lap
            local best = math.huge
            for _, t in ipairs(lobby.lapTimes[src] or {}) do
                if t < best then best = t end
            end
            if best == math.huge then best = 0 end

            TriggerClientEvent("speedway:finalRanking", src, {
                position   = position,
                totalTime  = yourTime,
                allResults = nil,
                lapTimes   = lobby.lapTimes[src],
                bestLap    = best
            })
        end

        -- check if all players have finished
        local allFinished = true
        for _, pid in ipairs(lobby.players) do
            if not lobby.finished[pid] then allFinished = false break end
        end

        if allFinished then
            -- build shared podium
            local results = {}
            for _, pid in ipairs(lobby.players) do
                local sum = 0
                for _, t in ipairs(lobby.lapTimes[pid] or {}) do sum = sum + t end
                table.insert(results, { id = pid, time = sum })
            end
            table.sort(results, function(a,b) return a.time < b.time end)

            -- broadcast podium to participants
            for _, pid in ipairs(lobby.players) do
                TriggerClientEvent("speedway:finalRanking", pid, {
                    position   = nil,
                    totalTime  = nil,
                    allResults = results
                })
                -- cleanup props for each
                TriggerClientEvent("speedway:client:destroyprops", pid)
            end

            -- remove lobby and update global state
            lobbies[lobbyName] = nil
            TriggerClientEvent("speedway:setLobbyState", -1, next(lobbies) ~= nil)
        end

        return
    end

    -- otherwise just send lap update
    TriggerClientEvent("speedway:updateLap", src, currentLap, totalLaps)
end)

--#endregion events

--#region callback
lib.callback.register("speedway:getLobbies", function()
    local result = {}
    for name, data in pairs(lobbies) do
        result[#result+1] = { label = name .. " | " .. data.track, value = name }
    end
    return result
end)
--#endregion callback

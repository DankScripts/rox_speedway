-- s_main.lua

local Config    = require("config.config")
local QBCore    = exports['qb-core']:GetCoreObject()
local localeTable = require("locales." .. Config.Locale)
local function locale(key, ...)
  local str = localeTable[key] or key
  local args = { ... }
  return (str:gsub("{(%d+)}", function(n)
    return tostring(args[tonumber(n)] or "")
  end))
end

--------------------------------------------------------------------------------
-- re-add table helpers from s_function.lua
--------------------------------------------------------------------------------
local function table_contains(tbl, val)
  for _, v in ipairs(tbl) do
    if v == val then return true end
  end
  return false
end

local function table_count(tbl)
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

--------------------------------------------------------------------------------
-- lobby storage
--------------------------------------------------------------------------------
local lobbies        = {}    -- [lobbyName] = { owner, track, laps, players, ... }
local pendingChoices = {}    -- for vehicle selection
local amirState      = {}    -- per-lobby AMIR throttle and last state

-- Helper: build a license plate string from a player's character name (fallback to Rockstar name)
-- - Uppercase alphanumerics only
-- - Max 8 characters (GTA V plate limit)
-- - Optionally uniquified with digits if a collision occurs within the same spawn batch
local function makePlateFromPlayer(pid, used)
  local Player = QBCore and QBCore.Functions and QBCore.Functions.GetPlayer and QBCore.Functions.GetPlayer(pid)
  local first, last = nil, nil
  if Player and Player.PlayerData and Player.PlayerData.charinfo then
    first = Player.PlayerData.charinfo.firstname
    last  = Player.PlayerData.charinfo.lastname
  end

  local function san(s)
    if not s then return "" end
    s = tostring(s)
    s = s:gsub("%s+", ""):upper():gsub("[^A-Z0-9]", "")
    return s
  end

  local candidates = {}
  -- Prefer full name smashed if it fits/exists
  if first or last then
    table.insert(candidates, san((first or "") .. (last or "")))
    -- Also try first initial + last (keeps surname readable in 8 chars)
    local fi = first and first:sub(1,1) or ""
    table.insert(candidates, san(fi .. (last or "")))
  end
  -- Fallback to Rockstar name
  table.insert(candidates, san(GetPlayerName(pid) or ""))
  -- Final fallback
  table.insert(candidates, "SPD")

  local str = "SPD"
  for _, c in ipairs(candidates) do
    if c and #c > 0 then str = c break end
  end
  if #str > 8 then str = str:sub(1, 8) end

  -- Ensure uniqueness within the provided 'used' set by appending digits, trimming if needed
  if used then
    local base = str
    local suffix = 0
    while used[str] do
      suffix = suffix + 1
      local suf = tostring(suffix)
      local take = math.max(0, 8 - #suf)
      str = base:sub(1, take) .. suf
    end
    used[str] = true
  end

  if Config.DebugPrints then
    print(('[DEBUG] Plate for %s -> %s'):format(tostring(pid), str))
  end
  return str
end

-- Helper: find lobby by player id
local function findLobbyByPlayer(pid)
  for name, lob in pairs(lobbies) do
    for _, p in ipairs(lob.players or {}) do
      if p == pid then return name, lob end
    end
  end
  return nil, nil
end

-- Admin/host command to change AMIR view mode at runtime
-- Usage:
--   /lb names
--   /lb toggle
--   From server console, pass lobby name as 2nd arg: lb names <LobbyName>
RegisterCommand('lb', function(src, args)
  local mode = args and args[1] and args[1]:lower() or nil
  if mode ~= 'names' and mode ~= 'toggle' then
    if src == 0 then
      print('[Speedway] Usage: lb <names|toggle> [LobbyName]')
    else
      TriggerClientEvent('ox_lib:notify', src, { title = 'Speedway', description = 'Usage: /lb names | toggle', type = 'inform' })
    end
    return
  end

  local lobbyName, lob
  if src == 0 then
    lobbyName = args[2]
    if not lobbyName then lobbyName = next(lobbies) end
    lob = lobbyName and lobbies[lobbyName] or nil
  else
    lobbyName, lob = findLobbyByPlayer(src)
  end

  if not lob then
    if src == 0 then
      print('[Speedway] No active lobby found for command')
    else
      TriggerClientEvent('ox_lib:notify', src, { title = 'Speedway', description = 'No active lobby found', type = 'error' })
    end
    return
  end

  amirState[lobbyName] = amirState[lobbyName] or { last = 0, key = nil, title = nil, lastSwitch = 0, showNames = true }
  amirState[lobbyName].vm = mode
  amirState[lobbyName].last = 0       -- force next push
  amirState[lobbyName].lastSwitch = 0 -- reset toggle timer
  amirState[lobbyName].showNames = true -- always start on names view

  local msg = ('AMIR view mode set to %s for lobby %s'):format(mode, tostring(lobbyName))
  if src == 0 then print('[Speedway] ' .. msg) else TriggerClientEvent('ox_lib:notify', src, { title = 'Speedway', description = msg, type = 'success' }) end
end, false)

math.randomseed(GetGameTimer())

--------------------------------------------------------------------------------
-- callbacks for client queries
--------------------------------------------------------------------------------
lib.callback.register("speedway:getLobbies", function(source)
  local result = {}
  for name, lobby in pairs(lobbies) do
    table.insert(result, {
      label = name .. " | " .. lobby.track .. " (" .. #lobby.players .. " players)",
      value = name
    })
  end
  return result
end)

lib.callback.register("speedway:getLobbyPlayers", function(source, lobbyName)
  local lobby = lobbies[lobbyName]
  return lobby and lobby.players or {}
end)

--------------------------------------------------------------------------------
-- CREATE LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:createLobby", function(lobbyName, trackType, lapCount)
  print(string.format("[DEBUG] speedway:createLobby received: lobbyName=%s, trackType=%s, lapCount=%s, src=%s", lobbyName, trackType, lapCount, source))
  local src = source
  if lobbies[lobbyName] then
    print("[DEBUG] Lobby already exists: " .. lobbyName)
    TriggerClientEvent('ox_lib:notify', src, {
      description = locale("lobby_exists"),
      type        = "error"
    })
    return
  end

  lobbies[lobbyName] = {
    owner              = src,
    track              = trackType,
    laps               = lapCount or 1,
    players            = { src },
    checkpointProgress = {},
    isStarted          = false,
    lapProgress        = {},
    finished           = {},
    lapTimes           = {},
    startTime          = {},
    progress           = {},
  }
  print("[DEBUG] Lobby created: " .. lobbyName)

  -- tell the creator
  TriggerClientEvent('ox_lib:notify', src, {
    description = locale("lobby_created", lobbyName),
    type        = "success"
  })
  local hostName = GetPlayerName(src)
  TriggerClientEvent('speedway:updateLobbyInfo', src, {
    name      = lobbyName,
    hostName  = hostName,
    track     = trackType,
    players   = lobbies[lobbyName].players,
    owner     = src,
    laps      = lobbies[lobbyName].laps
  })
  TriggerClientEvent('speedway:setLobbyState', -1, next(lobbies) ~= nil)
  print("[DEBUG] Lobby info sent to client and lobby state updated.")
end)

--------------------------------------------------------------------------------
-- JOIN LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:joinLobby", function(lobbyName)
  local src   = source
  local lobby = lobbies[lobbyName]
  if not lobby then
    TriggerClientEvent('ox_lib:notify', src, {
      title       = "Speedway",
      description = locale("lobby_not_found"),
      type        = "error"
    })
    return
  end

  if not table_contains(lobby.players, src) then
    table.insert(lobby.players, src)
    -- BROADCAST who joined
    local playerName = GetPlayerName(src)
    for _, id in ipairs(lobby.players) do
      TriggerClientEvent("speedway:client:playerJoined", id, playerName)
    end
  end

  -- update everyone’s lobby info
  for _, id in ipairs(lobby.players) do
    TriggerClientEvent("speedway:updateLobbyInfo", id, {
  name     = lobbyName,
  hostName = GetPlayerName(lobby.owner),
  track    = lobby.track,
  players  = lobby.players,
  owner    = lobby.owner,
  laps     = lobby.laps
    })
  end
end)

--------------------------------------------------------------------------------
-- CHECKPOINT PASSED (improves ranking during a lap)
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:checkpointPassed", function(lobbyName, idx)
  local src = source
  local lob = lobbies[lobbyName]
  if not lob or not lob.isStarted then return end
  local cur = lob.checkpointProgress[src] or 0
  if type(idx) == 'number' and idx > cur then
    lob.checkpointProgress[src] = idx
  end
end)

--------------------------------------------------------------------------------
-- LEAVE LOBBY
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:leaveLobby", function()
  local src = source
  for name, lobby in pairs(lobbies) do
    for i, id in ipairs(lobby.players) do
      if id == src then
        table.remove(lobby.players, i)
        if lobby.owner == src then
          -- owner left → close lobby
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
          -- member left → update remaining
          for _, player in ipairs(lobby.players) do
            TriggerClientEvent("speedway:updateLobbyInfo", player, {
              name     = name,
              hostName = GetPlayerName(lobby.owner),
              track    = lobby.track,
              players  = lobby.players,
              owner    = lobby.owner,
              laps     = lobby.laps
            })
          end
        end

        -- clear leaver’s UI
        TriggerClientEvent("speedway:updateLobbyInfo", src, nil)
        TriggerClientEvent("speedway:setLobbyState", -1, next(lobbies) ~= nil)
        return
      end
    end
  end
end)

--------------------------------------------------------------------------------
-- START RACE & VEHICLE SELECTION
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:startRace", function(lobbyName)
  local src = source
  local lob = lobbies[lobbyName]
  if not lob then
    TriggerClientEvent('ox_lib:notify', src, {
      title       = "Speedway",
      description = locale("lobby_not_found"),
      type        = "error"
    })
    return
  end
  if lob.owner ~= src then
    TriggerClientEvent('ox_lib:notify', src, {
      title       = "Speedway",
      description = locale("not_authorized_to_start_race"),
      type        = "error"
    })
    return
  end

  lob.isStarted          = true
  lob.progress           = {}
  lob.checkpointProgress = {}
  lob.lapProgress        = {}
  lob.startTime          = {}
  lob.lapTimes           = {}
  lob.finished           = {}

  local now = GetGameTimer()
  for _, pid in ipairs(lob.players) do
    lob.startTime[pid]   = now
    lob.lapProgress[pid] = 0
    lob.lapTimes[pid]    = {}
  end

  if Config.Leaderboard and Config.Leaderboard.enabled then
    -- reset per-lobby AMIR state
    local vm = (amirState[lobbyName] and amirState[lobbyName].vm) or (Config.Leaderboard.viewMode or "toggle")
    if vm == 'times' then vm = 'toggle' end -- coerce unsupported mode
    local startShowNames = true -- always start with names
    amirState[lobbyName] = { last = 0, key = nil, title = nil, lastSwitch = 0, showNames = startShowNames }
    -- ─ Initialize AMIR leaderboard at race start ───────────────────
    do
  local names, times = {}, {}
      for i, pid in ipairs(lob.players) do
        names[i] = GetPlayerName(pid) or ""
        times[i] = 0
      end
      -- pad to exactly 9 entries
      for i = #names + 1, 9 do names[i], times[i] = "", 0 end
      -- show “1/totalLaps” instead of “0/totalLaps”
      local title = ("1/%d"):format(lob.laps)
      -- Initialize board according to viewMode
      local vm = (amirState[lobbyName] and amirState[lobbyName].vm) or (Config.Leaderboard.viewMode or "toggle")
      if vm == 'times' then vm = 'toggle' end -- coerce unsupported mode
      -- We always initialize with names to avoid flashing
      TriggerEvent("amir-leaderboard:setPlayerNames", title, names)
    end
    -- ───────────────────────────────────────────────────────────────
  end

  pendingChoices[lobbyName] = { total = #lob.players, received = 0, selected = {} }
  -- Immediately hide lobby UI for all members
  for _, pid in ipairs(lob.players) do
    TriggerClientEvent("speedway:hideLobbyWindow", pid)
  end
  -- Start a 30s vehicle selection countdown visible to players
  local deadline = GetGameTimer() + 30000
  CreateThread(function()
    while pendingChoices[lobbyName] do
      local now = GetGameTimer()
      local remaining = math.max(0, math.floor((deadline - now) / 1000))
      for _, pid in ipairs(lob.players) do
        TriggerClientEvent("speedway:vehicleSelectCountdown", pid, remaining)
      end
      if pendingChoices[lobbyName].received >= pendingChoices[lobbyName].total then
        -- everyone selected; stop countdown
        break
      end
      if remaining <= 0 then
        break
      end
      Wait(1000)
    end

    -- Timeout or all selected; if still pending, finalize selections
    local data = pendingChoices[lobbyName]
    if not data then return end
    if data.received < data.total then
      -- kick players who didn't pick and proceed with those who did
      local keep = {}
      for i = #lob.players, 1, -1 do
        local pid = lob.players[i]
        if not data.selected[pid] then
          TriggerClientEvent('ox_lib:notify', pid, {
            title = "Speedway",
            description = locale("vehicle_select_timeout"),
            type = "warning"
          })
          TriggerClientEvent("speedway:kickedFromLobby", pid, lobbyName, "timeout")
          table.remove(lob.players, i)
        else
          table.insert(keep, pid)
        end
      end
      data.total = #keep
      data.received = #keep
    end

    -- If we still have players, spawn vehicles for those who selected
    if #lob.players > 0 and data.received > 0 then
      pendingChoices[lobbyName] = nil
      local usedPlates = {}
      for idx, pid in ipairs(lob.players) do
        local m = data.selected[pid]
        if m then
          local sp  = Config.GridSpawnPoints[idx]
          local veh = CreateVehicle(joaat(m), sp.x, sp.y, sp.z, sp.w, true, false)
          while not DoesEntityExist(veh) do Wait(0) end
          local plate = makePlateFromPlayer(pid, usedPlates)
          SetVehicleNumberPlateText(veh, plate)
          -- Ensure doors are unlocked server-side (client will also reinforce)
          SetVehicleDoorsLocked(veh, 1)
          TriggerClientEvent("speedway:client:fillFuel", pid, NetworkGetNetworkIdFromEntity(veh))
          TriggerClientEvent("vehiclekeys:client:SetOwner", pid, plate)
          TriggerClientEvent("speedway:prepareStart", pid, {
            track = lob.track,
            laps  = lob.laps,
            netId = NetworkGetNetworkIdFromEntity(veh),
            plate = plate,
          })
        end
      end
    else
      -- nobody left or nobody selected: cancel race
      pendingChoices[lobbyName] = nil
      lob.isStarted = false
      for _, pid in ipairs(lob.players) do
        TriggerClientEvent('ox_lib:notify', pid, {
          title = "Speedway",
          description = locale("race_cancelled"),
          type = "error"
        })
      end
    end
  end)
  for _, pid in ipairs(lob.players) do
    TriggerClientEvent("speedway:chooseVehicle", pid, lobbyName)
  end
end)

--------------------------------------------------------------------------------
-- VEHICLE SELECTION RESPONSE
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:selectedVehicle", function(lobbyName, model)
  local src  = source
  local data = pendingChoices[lobbyName]
  local lob  = lobbies[lobbyName]
  if not data or not lob then return end
  -- Ignore submissions from players no longer in the lobby (kicked/left)
  local inLobby = false
  for _, pid in ipairs(lob.players) do if pid == src then inLobby = true break end end
  if not inLobby then return end

  if model and not data.selected[src] then
    data.selected[src] = model
    data.received = data.received + 1
  end

  if data.received == data.total then
    pendingChoices[lobbyName] = nil
  local usedPlates = {}
  for idx, pid in ipairs(lob.players) do
      local m   = data.selected[pid]
      local sp  = Config.GridSpawnPoints[idx]
      local veh = CreateVehicle(joaat(m), sp.x, sp.y, sp.z, sp.w, true, false)
      while not DoesEntityExist(veh) do Wait(0) end
  -- Generate a plate from the player's name for easy identification (unique within this batch)
  local plate = makePlateFromPlayer(pid, usedPlates)
      SetVehicleNumberPlateText(veh, plate)
  -- Ensure doors are unlocked server-side (client will also reinforce)
  SetVehicleDoorsLocked(veh, 1)
      TriggerClientEvent("speedway:client:fillFuel", pid, NetworkGetNetworkIdFromEntity(veh))
      TriggerClientEvent("vehiclekeys:client:SetOwner", pid, plate)
      TriggerClientEvent("speedway:prepareStart", pid, {
        track = lob.track,
        laps  = lob.laps,
        netId = NetworkGetNetworkIdFromEntity(veh),
        plate = plate,
      })
    end
  end
end)

--------------------------------------------------------------------------------
-- LIVE PROGRESS UPDATES
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:updateProgress", function(lobbyName, dist)
  local src = source
  local lob = lobbies[lobbyName]
  if not lob or not lob.isStarted then return end

  lob.progress[src] = dist

  local board = {}
  for _, pid in ipairs(lob.players) do
    table.insert(board, {
      id   = pid,
      lap  = lob.lapProgress[pid] or 0,
      dist = lob.progress[pid]    or 0
    })
  end

  table.sort(board, function(a, b)
    if a.lap ~= b.lap then
      return a.lap > b.lap
    end
    local acp = lob.checkpointProgress[a.id] or 0
    local bcp = lob.checkpointProgress[b.id] or 0
    if acp ~= bcp then
      return acp > bcp
    end
    return a.dist > b.dist
  end)

  if Config.DebugPrints then
    local dbg = {}
    for i, e in ipairs(board) do
      local cp = lob.checkpointProgress[e.id] or 0
      dbg[#dbg+1] = ("%d:%s lap=%d cp=%d dist=%.1f"):format(i, tostring(e.id), e.lap or 0, cp, e.dist or 0)
    end
    print("[DEBUG] leaderboard " .. table.concat(dbg, " | "))
    -- Also log which rank is sent to which player id
    for rank, e in ipairs(board) do
      local cp = lob.checkpointProgress[e.id] or 0
      local displayRank = (Config.RankingInvert and ((#board - rank) + 1)) or rank
      print(("[DEBUG] sendPosition -> id=%s rank=%d display=%d total=%d lap=%d cp=%d dist=%.1f"):format(tostring(e.id), rank, displayRank, #board, e.lap or 0, cp, e.dist or 0))
    end
  end

  for rank, e in ipairs(board) do
    local displayRank = (Config.RankingInvert and ((#board - rank) + 1)) or rank
    TriggerClientEvent("speedway:updatePosition", e.id, displayRank, #board)
  end

  -- Update AMIR leaderboard to reflect live positions and current lap/total
  if Config.Leaderboard and Config.Leaderboard.enabled then
    local lName = lobbyName
    -- derive a deterministic key for ordering (IDs joined by '-')
    local keyParts = {}
    for i, e in ipairs(board) do keyParts[i] = tostring(e.id) end
    local orderKey = table.concat(keyParts, "-")
    -- Displayed lap should be current lap number (completed+1), clamped to total
    local leaderLapDisplay = 1
    for _, e in ipairs(board) do
      local lp = (lob.lapProgress[e.id] or 0) + 1
      if lp > lob.laps then lp = lob.laps end
      if lp > leaderLapDisplay then leaderLapDisplay = lp end
    end
    local title = ("%d/%d"):format(leaderLapDisplay, lob.laps)

    -- Throttle and only push when content actually changes to prevent flashing
  local st = amirState[lName] or { last = 0, key = nil, title = nil, lastSwitch = 0, showNames = true }
  local now = GetGameTimer()
  local interval   = (Config.Leaderboard.updateIntervalMs or 1000)
  local toggleInt  = (Config.Leaderboard.toggleIntervalMs or 2000)
  local vm         = (st and st.vm) or (Config.Leaderboard.viewMode or "toggle")
  if vm == 'times' then vm = 'toggle' end -- coerce unsupported mode

    -- Decide which view should be active now and whether we just switched this tick
    local showNames = st.showNames ~= false -- default true
    local switched  = false
    if vm == "toggle" then
      if (now - (st.lastSwitch or 0)) >= toggleInt then
        showNames      = not showNames
        st.lastSwitch  = now
        switched       = true
      end
    elseif vm == "names" then
      showNames = true
    else -- vm == "times"
      showNames = false
    end

  -- Only push when:
  --  - order or title changed (rank/lap changes)
  --  - toggle just switched modes
    local contentChanged = (st.key ~= orderKey) or (st.title ~= title)
    local timeForInterval = (now - (st.last or 0)) >= interval
  local shouldPush = contentChanged or switched

    if shouldPush then
      local names, times = {}, {}
      local maxEntries = 9
      local count = math.min(#board, maxEntries)
      for i = 1, count do
        local pid = board[i].id
        names[i] = GetPlayerName(pid) or ""
        -- Always provide times for the AMIR toggle view.
        -- Times are milliseconds, AMIR displays them as MM:SS.
        local tmode = (Config.Leaderboard and Config.Leaderboard.timeMode) or "total" -- "total" or "lap"
        local finished = lob.finished[pid] == true
        if tmode == "lap" then
          if finished then
            -- show the final lap time for finished racers
            local arr = lob.lapTimes[pid] or {}
            local last = arr[#arr] or 0
            times[i] = last
          else
            local lapStart = lob.startTime[pid] or now
            local lapMs    = now - lapStart
            if lapMs < 0 then lapMs = 0 end
            times[i] = lapMs
          end
        else
          -- total time: freeze at final total for finished racers; otherwise keep running
          local sum = 0
          local arr = lob.lapTimes[pid] or {}
          for _, t in ipairs(arr) do sum = sum + t end
          if finished then
            times[i] = sum
          else
            local lapStart = lob.startTime[pid] or now
            local currLap  = now - lapStart
            if currLap < 0 then currLap = 0 end
            times[i] = sum + currLap
          end
        end
      end
      for i = count + 1, maxEntries do names[i], times[i] = "", 0 end

      if showNames then
        TriggerEvent("amir-leaderboard:setPlayerNames", title, names)
      else
        TriggerEvent("amir-leaderboard:setPlayerTimes", title, times)
      end

      -- Persist state; note we intentionally do not include vm here, it's read from config/override
      amirState[lName] = { last = now, key = orderKey, title = title, lastSwitch = st.lastSwitch, showNames = showNames, vm = vm }
    end
  end
end)

--------------------------------------------------------------------------------
-- LAP PASSED, LEADERBOARD UPDATE & RACE END
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:lapPassed", function(lobbyName, forcedSrc)
  local src = forcedSrc or source
  local lob = lobbies[lobbyName]
  if not lob then return end

  -- advance lap count
  lob.lapProgress[src] = (lob.lapProgress[src] or 0) + 1
  local curLap = lob.lapProgress[src]

  -- record lap time
  local now = GetGameTimer()
  table.insert(lob.lapTimes[src], now - (lob.startTime[src] or now))
  lob.startTime[src] = now

  -- notify client of the current lap to display: completed+1, clamped to total
  local displayLap = curLap + 1
  if displayLap > lob.laps then displayLap = lob.laps end
  TriggerClientEvent("speedway:updateLap", src, displayLap, lob.laps)

  -- reset per-lap progress counters so sorting is fair at the new lap start
  lob.checkpointProgress[src] = 0
  lob.progress[src] = 0

  -- Leaderboard updates are handled continuously in updateProgress to reflect live positions

  -- if they’ve now completed the total number of laps…
  if curLap >= lob.laps then
    if not lob.finished[src] then
      lob.finished[src] = true

      -- warp them back, fade in/out
      TriggerClientEvent("speedway:client:finishTeleport", src, Config.outCoords)
      -- important “You finished!” toast
      TriggerClientEvent("speedway:youFinished", src)

      -- push their personal result
      local totalT, best = 0, math.huge
      for _, t in ipairs(lob.lapTimes[src]) do
        totalT, best = totalT + t, math.min(best, t)
      end
      if best == math.huge then best = 0 end

      TriggerClientEvent("speedway:finalRanking", src, {
        position  = table_count(lob.finished),
        totalTime = totalT,
        lapTimes  = lob.lapTimes[src],
        bestLap   = best
      })
    end

    -- once everyone’s finished, broadcast the podium and tear down
    local allFin = true
    for _, pid in ipairs(lob.players) do
      if not lob.finished[pid] then allFin = false break end
    end
    if allFin then
      local results = {}
      for _, pid in ipairs(lob.players) do
        local sum = 0
        for _, t in ipairs(lob.lapTimes[pid]) do sum = sum + t end
        table.insert(results, { id = pid, time = sum })
      end
      table.sort(results, function(a,b) return a.time < b.time end)

      for _, pid in ipairs(lob.players) do
        TriggerClientEvent("speedway:finalRanking", pid, { allResults = results })
        TriggerClientEvent("speedway:client:destroyprops", pid)
      end

      lobbies[lobbyName] = nil
      TriggerClientEvent("speedway:setLobbyState", -1, next(lobbies) ~= nil)
    end
  end
end)

--------------------------------------------------------------------------------
-- FINISH TELEPORT, FUEL, ETC.
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:finishTeleport", function(coords)
  TriggerClientEvent("speedway:client:finishTeleport", source, coords)
end)

RegisterNetEvent("speedway:client:fillFuel", function(netId)
  local v = NetworkGetEntityFromNetworkId(netId)
  if not DoesEntityExist(v) then return end
  SetVehicleFuelLevel(v, 100.0)
  if GetResourceState("LegacyFuel")    == "started" then exports["LegacyFuel"]:SetFuel(v,100) end
  if GetResourceState("cdn-fuel")      == "started" then exports["cdn-fuel"]:SetFuel(v,100) end
  if GetResourceState("okokGasStation")== "started" then exports["okokGasStation"]:SetFuel(v,100) end
  if GetResourceState("ox_fuel")       == "started" then
    local st = Entity(v).state
    if st and st.set then st:set("fuel", 100.0, true) end
  end
end)

--------------------------------------------------------------------------------
-- SERVER-AUTHORITATIVE FUEL SYNC (called from client after pit stop)
--------------------------------------------------------------------------------
RegisterNetEvent("speedway:server:setFuel", function(netId, level)
  local src = source -- reserved if we later want to restrict
  if type(netId) ~= 'number' or type(level) ~= 'number' then return end
  if level < 0 then level = 0 end; if level > 100 then level = 100 end
  local v = NetworkGetEntityFromNetworkId(netId)
  if not v or v == 0 or not DoesEntityExist(v) then return end

  -- Native baseline
  SetVehicleFuelLevel(v, level + 0.0)

  -- Common fuel scripts (server-side exports if available)
  if GetResourceState("LegacyFuel")     == "started" and exports["LegacyFuel"] and exports["LegacyFuel"].SetFuel then exports["LegacyFuel"]:SetFuel(v, level) end
  if GetResourceState("cdn-fuel")       == "started" and exports["cdn-fuel"]   and exports["cdn-fuel"].SetFuel   then exports["cdn-fuel"]:SetFuel(v, level) end
  if GetResourceState("okokGasStation") == "started" and exports["okokGasStation"] and exports["okokGasStation"].SetFuel then exports["okokGasStation"]:SetFuel(v, level) end

  -- ox_fuel uses statebags
  if GetResourceState("ox_fuel") == "started" then
    local st = Entity(v).state
    if st and st.set then st:set("fuel", level + 0.0, true) end
  end

  if Config.DebugPrints then
    print(("[Speedway] Server fuel sync: netId=%s -> %.1f"):format(tostring(netId), level))
  end

  -- Reassert a couple more times to win any late ticks from fuel scripts that reapply old cached values
  CreateThread(function()
    local tries = { 400, 1000 }
    for _, waitMs in ipairs(tries) do
      Wait(waitMs)
      if DoesEntityExist(v) then
        SetVehicleFuelLevel(v, level + 0.0)
        if GetResourceState("LegacyFuel") == "started" and exports["LegacyFuel"] and exports["LegacyFuel"].SetFuel then
          exports["LegacyFuel"]:SetFuel(v, level)
        end
        if GetResourceState("ox_fuel") == "started" then
          local st = Entity(v).state
          if st and st.set then st:set("fuel", level + 0.0, true) end
        end
      end
    end
  end)
end)

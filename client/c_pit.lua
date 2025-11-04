-- client/c_pit.lua

print("👷 [ROX-Speedway] c_pit.lua loaded")

local Config = require("config.config")
local QBCore = exports['qb-core']:GetCoreObject()

-- will hold all our ped references
local pitZones = {}

--------------------------------------------------------------------------------
-- 1) SPAWN ALL PIT CREW & ADD MAP BLIPS
--------------------------------------------------------------------------------
CreateThread(function()
    Wait(100)

    print(("👷 [ROX-Speedway] Config.PitCrewZones has %d entries"):format(#Config.PitCrewZones))

    local modelHash = GetHashKey(Config.PitCrewModel)
    RequestModel(modelHash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(modelHash) then
        print("👷 [ROX-Speedway] ❌ Failed to load ped model")
        return
    end

    for idx, zone in ipairs(Config.PitCrewZones) do
        print(("👷 [ROX-Speedway] Spawning pit crew for zone %d at %s"):format(idx, tostring(zone.coords)))
        pitZones[idx] = { idle = {}, crew = {}, crewIdle = {} }
        local data = pitZones[idx]

        local r = zone.radius
        local idleBase = { vector3(-2.5, r, 0.0), vector3(2.5, r, 0.0) }
        local crewBase = { vector3(-1.5, r, 0.0), vector3(0.0, r, 0.0), vector3(1.5, r, 0.0) }
        local angle = math.rad(-10)
        local cosA, sinA = math.cos(angle), math.sin(angle)
        local moveOffset = vector3(-0.68, -3.17, 0.0)

        -- idle peds
        for i, base in ipairs(idleBase) do
            local x = base.x * cosA - base.y * sinA
            local y = base.x * sinA + base.y * cosA
            local offs = vector3(x, y, base.z)
            local pos = zone.coords + offs + moveOffset

            local spawnZ = pos.z
            local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 5.0, false)
            if found then spawnZ = gz end

            local ped = CreatePed(4, modelHash, pos.x, pos.y, spawnZ, zone.heading or 0.0, false, false)
            FreezeEntityPosition(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
            data.idle[i] = ped
        end

        -- service peds
        for i, base in ipairs(crewBase) do
            local x = base.x * cosA - base.y * sinA
            local y = base.x * sinA + base.y * cosA
            local offs = vector3(x, y, base.z)
            local pos = zone.coords + offs + moveOffset

            local spawnZ = pos.z
            local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 5.0, false)
            if found then spawnZ = gz end

            local ped = CreatePed(4, modelHash, pos.x, pos.y, spawnZ, zone.heading or 0.0, false, false)
            FreezeEntityPosition(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
            data.crew[i]     = ped
            data.crewIdle[i] = offs + moveOffset
        end

        -- map blip
        local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
        SetBlipSprite(blip, 225); SetBlipColour(blip, 5); SetBlipScale(blip, 0.8)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Pit Crew Zone")
        EndTextCommandSetBlipName(blip)
    end
end)

--------------------------------------------------------------------------------
-- 2) HELPER: FIND NEAREST ZONE INDEX
--------------------------------------------------------------------------------
local function getNearestZoneIdx(veh)
    local vcoords, bestIdx, bestDist = GetEntityCoords(veh), nil, math.huge
    for idx, zone in ipairs(Config.PitCrewZones) do
        local d = #(vcoords - zone.coords)
        if d < bestDist then bestDist, bestIdx = d, idx end
    end
    return bestIdx
end

--------------------------------------------------------------------------------
-- 3) AUTOMATIC PIT DETECTION & SERVICE SEQUENCE
--------------------------------------------------------------------------------
local inPit = false
CreateThread(function()
    while #pitZones < #Config.PitCrewZones do Wait(0) end
    print("👷 [ROX-Speedway] Pit detection thread starting")

    local fuelBones = { "door_fuel", "petrolcap", "petroltank" }
    local canModel = GetHashKey("prop_jerrycan_01a")
    RequestModel(canModel)
    while not HasModelLoaded(canModel) do Wait(0) end

    while true do
        Wait(500)
        local playerPed = PlayerPedId()
        local veh = GetVehiclePedIsIn(playerPed, false)
        if not veh or veh == 0 then goto continue end

        local speed = GetEntitySpeed(veh)
        local idx = getNearestZoneIdx(veh)
        local dist = #(GetEntityCoords(veh) - Config.PitCrewZones[idx].coords)

        if not inPit then
            if dist < Config.PitCrewZones[idx].radius and speed < 0.5 then
                print(("👷 [ROX-Speedway] Vehicle entered pit zone %d at speed %.2f"):format(idx, speed))
                inPit = true

                local zoneData   = pitZones[idx]
                local baseCoords = Config.PitCrewZones[idx].coords

                -- snap & freeze vehicle
                FreezeEntityPosition(veh, true)
                SetEntityCoords(veh, baseCoords.x, baseCoords.y, baseCoords.z, false, false, false, true)

                -- unfreeze crew
                for _, cp in ipairs(zoneData.crew) do FreezeEntityPosition(cp, false) end

                -- compute service positions
                local fuelPos
                for _, bn in ipairs(fuelBones) do
                    local bi = GetEntityBoneIndexByName(veh, bn)
                    if bi ~= -1 then
                        local fx, fy, fz = GetWorldPositionOfEntityBone(veh, bi)
                        fuelPos = vector3(fx, fy, fz + 1.0)   -- bump Z for pathfinding
                        break
                    end
                end
                if not fuelPos then
                    local ox, oy, oz = table.unpack(GetOffsetFromEntityInWorldCoords(veh, 0, -2.0, 0))
                    fuelPos = vector3(ox, oy, oz + 1.0)
                end

                local frontPos = GetOffsetFromEntityInWorldCoords(veh, 0, 2.0, 0)
                local sidePos  = GetOffsetFromEntityInWorldCoords(veh, 1.5, 0.0, 0)
                local refuelPed, hoodPed, jackPed = table.unpack(zoneData.crew)

                -- DEBUG: where they’re going
                print("👷 [ROX-Speedway] REFUELER moving to →", fuelPos)

                -- refueler walks straight there
                ClearPedTasks(refuelPed)
                FreezeEntityPosition(refuelPed, false)
                TaskGoStraightToCoord(refuelPed,
                    fuelPos.x, fuelPos.y, fuelPos.z,
                    1.0,  -- speed
                    -1,   -- timeout
                    zone.heading or 0.0,
                    0.0
                )

                -- hood & jack
                TaskGoToCoordAnyMeans(hoodPed, frontPos.x, frontPos.y, frontPos.z, 2.0, 0, 0, 786603, 0.0)
                TaskGoToCoordAnyMeans(jackPed, sidePos.x, sidePos.y, sidePos.z,   2.0, 0, 0, 786603, 0.0)

                Wait(1000)

                -- REFUEL: attach & anim
                local canObj = CreateObject(canModel, fuelPos.x, fuelPos.y, fuelPos.z, true, true, false)
                AttachEntityToEntity(canObj, refuelPed, GetPedBoneIndex(refuelPed, 57005),
                    0.10, 0.0, -0.02,
                   -90.0, 0.0,  0.0,
                    true, true, false, true, 1, true
                )
                TaskTurnPedToFaceEntity(refuelPed, veh, 1000)
                Wait(1000)
                RequestAnimDict("timetable@gardener@filling_can")
                while not HasAnimDictLoaded("timetable@gardener@filling_can") do Wait(0) end
                TaskPlayAnim(refuelPed,
                    "timetable@gardener@filling_can", "gar_ig_5_filling_can",
                    2.0, 8.0, -1, 50, 0, false, false, false
                )

                -- hood & jack scenarios
                TaskStartScenarioInPlace(hoodPed, "PROP_HUMAN_BUM_BIN",    0, true)
                TaskStartScenarioInPlace(jackPed, "WORLD_HUMAN_PUSH_CAR",  0, true)

                -- fill + repair
                local startFuel = GetVehicleFuelLevel(veh)
                for i = 1, 10 do
                    SetVehicleFuelLevel(veh, startFuel + (100 - startFuel) * (i / 10))
                    Wait(300)
                end
                SetVehicleDeformationFixed(veh)
                SetVehicleFixed(veh)

                -- cleanup
                ClearPedTasks(refuelPed)
                DeleteEntity(canObj)
                RemoveAnimDict("timetable@gardener@filling_can")

                -- return crew
                for i, cp in ipairs(zoneData.crew) do
                    ClearPedTasks(cp)
                    local off = zoneData.crewIdle[i]
                    TaskGoToCoordAnyMeans(cp,
                        baseCoords.x + off.x,
                        baseCoords.y + off.y,
                        baseCoords.z + off.z,
                        2.0, 0, 0, 786603, 0.0
                    )
                end
                repeat Wait(100)
                    local allBack = true
                    for i, cp in ipairs(zoneData.crew) do
                        local off = zoneData.crewIdle[i]
                        if #(GetEntityCoords(cp) - (baseCoords + off)) > 0.5 then allBack = false; break end
                    end
                until allBack
                for _, cp in ipairs(zoneData.crew) do FreezeEntityPosition(cp, true) end

                -- unfreeze & toast
                FreezeEntityPosition(veh, false)
                AddTextEntry("PIT_RETURN", "Return to Race")
                BeginTextCommandPrint("PIT_RETURN")
                EndTextCommandPrint(3000, true)
            end

        else
            -- EXIT PIT
            local dist2 = #(GetEntityCoords(veh) - Config.PitCrewZones[idx].coords)
            if dist2 > Config.PitCrewZones[idx].radius then
                print("👷 [ROX-Speedway] Exiting pit zone")
                FreezeEntityPosition(veh, false)
                inPit = false
            end
        end

        ::continue::
    end
end)

--------------------------------------------------------------------------------
-- 4) GROUND MARKERS (half-scale)
--------------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(0)
        for _, zone in ipairs(Config.PitCrewZones) do
            local size = (zone.radius * 2.0) / 6.0
            DrawMarker(
                36,
                zone.coords.x, zone.coords.y, zone.coords.z + 1.0,
                0, 0, 0, 0, 0, 0,
                size, size, size,
                255, 255, 255, 200,
                false, true, 2, false, nil, nil, false
            )
        end
    end
end)

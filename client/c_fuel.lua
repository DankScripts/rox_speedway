-- client/fuel.lua
local QBCore = exports['qb-core']:GetCoreObject()

local FuelAPIs = {
  { name = "LegacyFuel" },
  { name = "cdn-fuel" },
  { name = "okokGasStation" },
  { name = "lc_fuel" },
}

local activeSetters = {}

CreateThread(function()
  -- Helper to push a setter if the export function exists under various common names
  local function tryRegister(apiName)
    local ex = exports[apiName]
    if not ex then return false end
    local candidates = { "SetFuel", "setFuel", "SetVehicleFuel", "SetVehFuel" }
    for _, fname in ipairs(candidates) do
      if ex[fname] then
        table.insert(activeSetters, function(veh, lvl)
          -- Try direct call pattern common in exports tables
          local ok = pcall(function()
            exports[apiName][fname](veh, lvl)
          end)
          if not ok then
            -- Fallback: method-style (colon) semantics
            pcall(function()
              exports[apiName][fname](exports[apiName], veh, lvl)
            end)
          end
        end)
        print(("[ROX-Speedway] Fuel integration: %s (%s) detected"):format(apiName, fname))
        return true
      end
    end
    return false
  end

  for _, api in ipairs(FuelAPIs) do
    if GetResourceState(api.name) == "started" then
      local ok = false
      -- Prefer explicit, known-good path for LegacyFuel
      if api.name == 'LegacyFuel' then
        ok = true
        table.insert(activeSetters, function(veh, lvl)
          -- LegacyFuel canonical export
          pcall(function() exports['LegacyFuel']:SetFuel(veh, lvl) end)
        end)
        print("[ROX-Speedway] Fuel integration: LegacyFuel (SetFuel) detected [explicit]")
      end
      if not ok then
        ok = tryRegister(api.name)
      end
      if not ok and api.name == "lc_fuel" then
        print("[ROX-Speedway] lc_fuel detected but no known SetFuel export; will use natives + server sync")
      end
    end
  end
end)

-- Set fuel to a specific percentage across supported fuel scripts and natives
function SetFuelLevel(veh, level)
  SetVehicleFuelLevel(veh, level)
  for _, setter in ipairs(activeSetters) do
    setter(veh, level)
  end
  if GetResourceState("ox_fuel") == "started" then
    local ent = Entity(veh)
    if ent and ent.state and ent.state.set then ent.state:set("fuel", level, true) end
  end
end

function SetFullFuel(veh)
  SetVehicleFuelLevel(veh, 100.0)
  for _, setter in ipairs(activeSetters) do
    setter(veh, 100.0)
  end
  -- ox_fuel commonly uses statebags instead of an export
  if GetResourceState("ox_fuel") == "started" then
    local ent = Entity(veh)
    if ent and ent.state and ent.state.set then ent.state:set("fuel", 100.0, true) end
  end
  -- Server-authoritative sync (prevents external fuel scripts from reverting the value)
  local netId = NetworkGetNetworkIdFromEntity(veh)
  if netId and netId ~= 0 then
    TriggerServerEvent('speedway:server:setFuel', netId, 100.0)
  end
end

-- client/fuel.lua
local QBCore = exports['qb-core']:GetCoreObject()

local FuelAPIs = {
  { name = "LegacyFuel",     fns = { "SetFuel" } },
  { name = "cdn-fuel",       fns = { "SetFuel" } },
  { name = "okokGasStation", fns = { "SetFuel" } },
  -- lc_fuel by LeonardoSoares98: try common variants just in case
  { name = "lc_fuel",        fns = { "SetFuel", "setFuel", "SetVehicleFuel", "set_vehicle_fuel" } },
}

local activeSetters = {}

CreateThread(function()
  for _, api in ipairs(FuelAPIs) do
    if GetResourceState(api.name) == "started" and exports[api.name] then
      local hooked = false
      for _, fnName in ipairs(api.fns) do
        if exports[api.name][fnName] then
          -- Wrap to ensure stable calling even if export references change
          table.insert(activeSetters, function(veh, lvl)
            exports[api.name][fnName](veh, lvl)
          end)
          hooked = true
          print(("[ROX-Speedway] Fuel integration: %s (%s) detected"):format(api.name, fnName))
          break
        end
      end
      if not hooked and api.name == "lc_fuel" then
        print("[ROX-Speedway] lc_fuel detected but no compatible export found; fuel will fall back to natives only")
      end
    end
  end
end)

function SetFullFuel(veh)
  SetVehicleFuelLevel(veh, 100.0)
  for _, setter in ipairs(activeSetters) do
    setter(veh, 100.0)
  end
  -- ox_fuel commonly uses statebags instead of an export
  if GetResourceState("ox_fuel") == "started" then
    local ent = Entity(veh)
    if ent and ent.state then ent.state.fuel = 100.0 end
  end
end

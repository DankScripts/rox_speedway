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
  for _, api in ipairs(FuelAPIs) do
    if GetResourceState(api.name) == "started" and exports[api.name] then
      if exports[api.name]["SetFuel"] then
        -- Use colon-call consistently for all supported fuel scripts
        table.insert(activeSetters, function(veh, lvl)
          exports[api.name]:SetFuel(veh, lvl)
        end)
        print(("[ROX-Speedway] Fuel integration: %s (SetFuel) detected"):format(api.name))
      elseif api.name == "lc_fuel" then
        print("[ROX-Speedway] lc_fuel detected but SetFuel export not found; fuel will fall back to natives only")
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

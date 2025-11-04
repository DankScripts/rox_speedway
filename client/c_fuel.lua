-- client/fuel.lua
local QBCore = exports['qb-core']:GetCoreObject()

local FuelAPIs = {
  { name = "LegacyFuel",     fn = "SetFuel" },
  { name = "cdn-fuel",       fn = "SetFuel" },
  { name = "okokGasStation", fn = "SetFuel" },
}

local activeSetters = {}

CreateThread(function()
  for _, api in ipairs(FuelAPIs) do
    if GetResourceState(api.name) == "started"
    and exports[api.name]
    and exports[api.name][api.fn] then
      table.insert(activeSetters, exports[api.name][api.fn])
      print(("[ROX-Speedway] Fuel integration: %s detected"):format(api.name))
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

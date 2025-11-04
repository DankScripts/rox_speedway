-- client/c_keys.lua
-- Centralized vehicle-keys handoff so different key resources can be supported easily.
-- Exposes:
--   GiveVehicleKeys(veh)               -- attempts to grant keys for the passed vehicle
--   Speedway_RegisterKeyProvider(fn)   -- add a custom provider; fn(veh, plate) -> true if handled

local Providers = {}

-- Public: allow other scripts to register a provider at runtime
function Speedway_RegisterKeyProvider(name, fn)
    if type(fn) == 'function' then
        Providers[#Providers+1] = { name = name or ('prov_'..#Providers+1), fn = fn }
    end
end

local function safeHasResource(name)
    if not GetResourceState then return false end
    local st = GetResourceState(name)
    return st == 'started' or st == 'starting'
end

-- Built-in providers (common key scripts)
-- 1) qb-vehiclekeys (and forks under 'vehiclekeys') using plate
Speedway_RegisterKeyProvider('qb-vehiclekeys', function(veh, plate)
    local handled = false
    if safeHasResource('qb-vehiclekeys') or safeHasResource('vehiclekeys') then
        -- Events
        handled = pcall(function() TriggerEvent('vehiclekeys:client:SetOwner', plate) end) or handled
        handled = pcall(function() TriggerEvent('qb-vehiclekeys:client:SetOwner', plate) end) or handled
        -- Exports (some forks)
        if exports['qb-vehiclekeys'] then
            handled = pcall(function() exports['qb-vehiclekeys']:SetOwner(plate) end) or handled
            handled = pcall(function() exports['qb-vehiclekeys']:GiveKeys(plate) end) or handled
        end
    end
    return handled
end)

-- 2) qs-vehiclekeys using entity
Speedway_RegisterKeyProvider('qs-vehiclekeys', function(veh, plate)
    if safeHasResource('qs-vehiclekeys') and exports['qs-vehiclekeys'] then
        return pcall(function() exports['qs-vehiclekeys']:GiveKeys(veh) end)
    end
    return false
end)

-- 3) wasabi_carlock (optional) – uses entity
Speedway_RegisterKeyProvider('wasabi_carlock', function(veh, plate)
    if safeHasResource('wasabi_carlock') and exports['wasabi_carlock'] then
        return pcall(function() exports['wasabi_carlock']:GiveKey(veh) end)
    end
    return false
end)

-- 4) renewed-vehiclekeys: similar to qb-vehiclekeys (plate)
Speedway_RegisterKeyProvider('renewed-vehiclekeys', function(veh, plate)
    if safeHasResource('renewed-vehiclekeys') then
        return pcall(function() TriggerEvent('vehiclekeys:client:SetOwner', plate) end)
    end
    return false
end)

-- Public: Attempt all providers in order
function GiveVehicleKeys(veh)
    if not veh or veh == 0 then return false end
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
    local ok = false
    for _, prov in ipairs(Providers) do
        local handled = false
        local okcall, res = pcall(prov.fn, veh, plate)
        handled = okcall and (res == true)
        ok = ok or handled
        -- Do not break; some servers prefer multiple scripts to receive keys
    end
    return ok
end

return {}

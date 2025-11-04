-- Vehicle customization helpers: apply max performance, random cosmetics, and random paint instantly.

local Styles = {}

local function ensureControl(ent, tries)
    tries = tries or 30
    if not DoesEntityExist(ent) then return false end
    if NetworkHasControlOfEntity(ent) then return true end
    NetworkRequestControlOfEntity(ent)
    local i=0
    while i < tries and not NetworkHasControlOfEntity(ent) do
        Wait(0)
        NetworkRequestControlOfEntity(ent)
        i=i+1
    end
    return NetworkHasControlOfEntity(ent)
end

local function rand(min, max)
    return math.random(min or 0, max or 255)
end

local function applyPerformanceMax(veh)
    if not veh or veh == 0 then return end
    SetVehicleModKit(veh, 0)
    local perfSlots = {11,12,13,15,16}
    for _, slot in ipairs(perfSlots) do
        local count = GetNumVehicleMods(veh, slot)
        if count and count > 0 then
            local maxIndex = count - 1
            if maxIndex >= 0 then SetVehicleMod(veh, slot, maxIndex, false) end
        end
    end
    -- Turbo, tire smoke, xenon
    ToggleVehicleMod(veh, 17, true)
    ToggleVehicleMod(veh, 18, true)
    ToggleVehicleMod(veh, 19, true)
    -- Some servers prefer max armor via native instead of mod (slot 16 covers it)
end

local function buildStyle(veh)
    local style = { mods = {}, extras = {}, neon = {r=rand(), g=rand(), b=rand()}, tint = math.random(0,5), plateIndex = math.random(0,5) }
    -- Paints
    style.primary = { r=rand(), g=rand(), b=rand() }
    style.secondary = { r=rand(), g=rand(), b=rand() }
    style.pearl = math.random(0,159)
    style.wheelCol = math.random(0,159)
    style.smoke = { r=rand(), g=rand(), b=rand() }

    -- Mods (cosmetics only)
    for modType = 0, 49 do
        if modType ~= 11 and modType ~= 12 and modType ~= 13 and modType ~= 15 and modType ~= 16 and modType ~= 17 and modType ~= 18 and modType ~= 19 and modType ~= 22 then
            local count = GetNumVehicleMods(veh, modType)
            if count and count > 0 then
                style.mods[modType] = math.random(0, count - 1)
            end
        end
    end
    -- Livery
    local lcount = GetVehicleLiveryCount(veh)
    if lcount and lcount > 0 then style.livery = math.random(0, lcount - 1) end
    -- Extras
    for extraId = 1, 12 do
        if DoesExtraExist(veh, extraId) then
            style.extras[extraId] = (math.random() < 0.5)
        end
    end
    return style
end

local function applyStyle(veh, style)
    if not veh or veh == 0 or not style then return end
    SetVehicleModKit(veh, 0)
    -- Mods
    for modType, index in pairs(style.mods or {}) do
        SetVehicleMod(veh, modType, index, false)
    end
    -- Livery
    if style.livery then SetVehicleLivery(veh, style.livery) end
    -- Extras (true disables extra)
    for id, enabled in pairs(style.extras or {}) do
        SetVehicleExtra(veh, id, not enabled)
    end
    -- Neon
    for i=0,3 do SetVehicleNeonLightEnabled(veh, i, true) end
    if style.neon then SetVehicleNeonLightsColour(veh, style.neon.r, style.neon.g, style.neon.b) end
    -- Tint and plate index
    if style.tint then SetVehicleWindowTint(veh, style.tint) end
    if style.plateIndex then SetVehicleNumberPlateTextIndex(veh, style.plateIndex) end
    -- Colors
    if style.primary then SetVehicleCustomPrimaryColour(veh, style.primary.r, style.primary.g, style.primary.b) end
    if style.secondary then SetVehicleCustomSecondaryColour(veh, style.secondary.r, style.secondary.g, style.secondary.b) end
    if style.pearl or style.wheelCol then SetVehicleExtraColours(veh, style.pearl or 0, style.wheelCol or 0) end
    if style.smoke then SetVehicleTyreSmokeColor(veh, style.smoke.r, style.smoke.g, style.smoke.b) end
end

-- Public API: apply everything, with a quick reapply to ensure visibility
function Speedway_ApplyAll(veh)
    if not veh or veh == 0 then return end
    ensureControl(veh)
    applyPerformanceMax(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local style = Styles[netId]
    if not style then
        style = buildStyle(veh)
        Styles[netId] = style
    end
    applyStyle(veh, style)
    -- Clean & finalize
    WashDecalsFromVehicle(veh, 1.0)
    SetVehicleDirtLevel(veh, 0.0)
    -- Re-apply the SAME style a few times to fight streaming/ownership race conditions
    CreateThread(function()
        for i=1,3 do
            Wait(120)
            if not DoesEntityExist(veh) then break end
            SetVehicleModKit(veh, 0)
            applyStyle(veh, Styles[netId] or style)
        end
    end)
end

return {}

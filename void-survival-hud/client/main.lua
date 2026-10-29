local ESX
local loaded, nuiReady, editing = false, false, false
local identifier
local hunger, thirst = false, false
local trip = { vehicle = 0, distance = 0.0, coords = nil, at = nil }

local baseSettings = {
    version = 1, accent = '#a78bfa', secondary = '#67e8f9', opacity = 85,
    scale = 100, layout = 'cards', showLabels = true, unit = 'kmh',
    widgets = { vitals = true, vehicle = true, voice = true },
    positions = {
        vitals = { x = 20, y = 86 }, vehicle = { x = 78, y = 72 },
        voice = { x = 20, y = 80 }
    }
}

local function finite(value)
    return type(value) == 'number' and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function clamp(value, low, high, fallback)
    if not finite(value) then return fallback or low end
    return math.max(low, math.min(high, value))
end

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

local function sanitize(input, fallback)
    local result = copy(fallback)
    if type(input) ~= 'table' then return result end
    result.version = 1
    for _, key in ipairs({ 'accent', 'secondary' }) do
        if type(input[key]) == 'string' and input[key]:match('^#%x%x%x%x%x%x$') then
            result[key] = input[key]:lower()
        end
    end
    result.opacity = clamp(input.opacity, 35, 100, result.opacity)
    result.scale = clamp(input.scale, 70, 130, result.scale)
    if input.layout == 'cards' or input.layout == 'compact' then result.layout = input.layout end
    if input.unit == 'kmh' or input.unit == 'mph' then result.unit = input.unit end
    if type(input.showLabels) == 'boolean' then result.showLabels = input.showLabels end
    for _, widget in ipairs({ 'vitals', 'vehicle', 'voice' }) do
        if type(input.widgets) == 'table' and type(input.widgets[widget]) == 'boolean' then
            result.widgets[widget] = input.widgets[widget]
        end
        local position = type(input.positions) == 'table' and input.positions[widget]
        if type(position) == 'table' then
            result.positions[widget].x = clamp(position.x, 0, 100, result.positions[widget].x)
            result.positions[widget].y = clamp(position.y, 0, 100, result.positions[widget].y)
        end
    end
    return result
end

local defaults = sanitize(Config.DefaultSettings, baseSettings)
local settings = copy(defaults)

local function sendInit()
    if nuiReady then SendNUIMessage({ action = 'init', defaults = defaults, settings = settings }) end
end

local function closeEditor()
    editing = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'editor', open = false })
end

local function loadPreferences(data)
    data = type(data) == 'table' and data or {}
    local nextIdentifier = data.identifier
    if type(nextIdentifier) ~= 'string' or nextIdentifier == '' then return end
    if identifier == nextIdentifier then return end
    identifier = nextIdentifier
    settings = copy(defaults)
    local saved = GetResourceKvpString('settings:v1:' .. identifier)
    if saved then
        local ok, value = pcall(json.decode, saved)
        if ok and type(value) == 'table' then settings = sanitize(value, defaults) end
    end
    sendInit()
end

local function resourceStarted(name)
    return type(name) == 'string' and name ~= '' and GetResourceState(name) == 'started'
end

local function readStress()
    if not resourceStarted(Config.StressResource) then return 0, false end
    local ok, value = pcall(function() return exports[Config.StressResource]:getStress() end)
    if ok and finite(value) then return clamp(value, 0, 100), true end
    -- Lo stesso statebag utilizzato dall'addon allegato. Non scrive e non genera stress.
    value = LocalPlayer.state.stress
    if finite(value) then return clamp(value, 0, 100), true end
    return 0, false
end

local function readFuel(vehicle)
    local fuelConfig = Config.Fuel or {}
    if resourceStarted(fuelConfig.Resource) and type(fuelConfig.Export) == 'string' then
        local ok, value = pcall(function()
            local resource = exports[fuelConfig.Resource]
            return resource[fuelConfig.Export](resource, vehicle)
        end)
        if ok and finite(value) then return clamp(value, 0, 100) end
    end
    return clamp(GetVehicleFuelLevel(vehicle), 0, 100)
end

local function resetTrip(vehicle)
    trip = { vehicle = vehicle or 0, distance = 0.0, coords = nil, at = nil }
end

local function updateTrip(vehicle)
    if trip.vehicle ~= vehicle then resetTrip(vehicle) end
    local coords, now = GetEntityCoords(vehicle), GetGameTimer()
    if trip.coords and trip.at then
        local elapsed = math.max(0, (now - trip.at) / 1000.0)
        local dx, dy, dz = coords.x - trip.coords.x, coords.y - trip.coords.y, coords.z - trip.coords.z
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        local plausible = GetEntitySpeed(vehicle) * elapsed * 2.0 + 8.0
        if elapsed <= 2.0 and distance <= (Config.TripTeleportDistance or 100.0)
            and distance <= plausible then
            trip.distance = trip.distance + distance / 1000.0
        end
    end
    trip.coords, trip.at = coords, now
end

local function readVehicle(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        if trip.vehicle ~= 0 then resetTrip(0) end
        return { active = false }
    end
    updateTrip(vehicle)
    local speedMeters = GetEntitySpeed(vehicle)
    local gear = GetVehicleCurrentGear(vehicle)
    local relativeSpeed = GetEntitySpeedVector(vehicle, true)
    if relativeSpeed.y < -0.5 then gear = 'R'
    elseif speedMeters < 0.5 and gear == 0 then gear = 'N'
    else gear = tostring(gear) end
    local _, lowBeam, highBeam = GetVehicleLightsState(vehicle)
    local miles = settings.unit == 'mph'
    return {
        active = true,
        speed = math.floor(speedMeters * (miles and 2.236936 or 3.6) + 0.5),
        gear = gear,
        fuel = readFuel(vehicle),
        engine = clamp(GetVehicleEngineHealth(vehicle) / 10.0, 0, 100),
        rpm = clamp(GetVehicleCurrentRpm(vehicle), 0, 1),
        trip = trip.distance * (miles and 0.621371 or 1.0),
        tripUnit = miles and 'mi' or 'km',
        lights = lowBeam == 1 or highBeam == 1 or lowBeam == true or highBeam == true
    }
end

local function readVoice()
    local proximity = LocalPlayer.state.proximity
    if type(proximity) == 'table' and finite(proximity.distance) then
        return ('%g m'):format(clamp(proximity.distance, 0, 1000))
    end
    return 'VOCE'
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendInit()
    cb({ ok = true })
end)

RegisterNUICallback('save', function(data, cb)
    if not editing or not loaded or not identifier then
        cb({ ok = false, error = 'Personaggio non disponibile. Riprova dopo il caricamento ESX.' })
        return
    end
    if type(data) ~= 'table' or type(data.settings) ~= 'table' then
        cb({ ok = false, error = 'Impostazioni non valide.' })
        return
    end
    local candidate = sanitize(data.settings, defaults)
    local ok = pcall(function()
        SetResourceKvp('settings:v1:' .. identifier, json.encode(candidate))
    end)
    if not ok then
        cb({ ok = false, error = 'Salvataggio locale non riuscito.' })
        return
    end
    settings = candidate
    cb({ ok = true, settings = settings })
end)

RegisterNUICallback('close', function(_, cb)
    closeEditor()
    cb({ ok = true })
end)

RegisterNUICallback('resetTrip', function(_, cb)
    resetTrip(GetVehiclePedIsIn(PlayerPedId(), false))
    cb({ ok = true })
end)

RegisterCommand(Config.Command or 'hud', function()
    if editing then closeEditor() return end
    if not loaded then return end
    editing = true
    sendInit()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'editor', open = true })
end, false)

RegisterKeyMapping(Config.Command or 'hud', 'Apri editor HUD Void', 'keyboard', Config.DefaultKey or 'F7')

RegisterNetEvent('esx:playerLoaded', function(playerData)
    loaded = true
    loadPreferences(playerData)
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    loaded, identifier = false, nil
    hunger, thirst = false, false
    settings = copy(defaults)
    resetTrip(0)
    closeEditor()
    sendInit()
    SendNUIMessage({ action = 'update', data = { visible = false, vehicle = { active = false } } })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)

CreateThread(function()
    while not ESX do
        local ok, object = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and object then ESX = object end
        if not ESX then Wait(500) end
    end
    loaded = ESX.IsPlayerLoaded()
    if loaded then loadPreferences(ESX.GetPlayerData()) end
    while true do
        if loaded then
            if not identifier then loadPreferences(ESX.GetPlayerData()) end
            if resourceStarted(Config.StatusResource) then
                -- Uno status non ancora registrato può non invocare il callback.
                hunger, thirst = false, false
                -- I valori di esx_status standard sono 0–1.000.000.
                for _, statusName in ipairs({ 'hunger', 'thirst' }) do
                    local name = statusName
                    TriggerEvent('esx_status:getStatus', name, function(status)
                        local value = false
                        if status then
                            if type(status.getPercent) == 'function' then
                                local ok, percent = pcall(status.getPercent)
                                if ok and finite(percent) then value = clamp(percent, 0, 100) end
                            end
                            if value == false and finite(status.val) then
                                value = clamp(status.val / 10000.0, 0, 100)
                            end
                        end
                        if name == 'hunger' then hunger = value else thirst = value end
                    end)
                end
            else
                hunger, thirst = false, false
            end
        end
        Wait(math.max(250, Config.StatusInterval or 1000))
    end
end)

CreateThread(function()
    while true do
        local interval = math.max(100, Config.UpdateInterval or 250)
        if loaded and nuiReady then
            local ped, player = PlayerPedId(), PlayerId()
            local dead = IsEntityDead(ped)
            local visible = not (Config.HideOnPause and IsPauseMenuActive())
                and not (Config.HideWhileDead and dead)
            local maximum, health = GetEntityMaxHealth(ped), GetEntityHealth(ped)
            local healthPercent = maximum > 100 and ((health - 100.0) / (maximum - 100.0)) * 100.0
                or (health / math.max(1, maximum)) * 100.0
            local stress, stressConnected = readStress()
            local underwater = IsPedSwimmingUnderWater(ped)
            local vehicle = readVehicle(ped)
            if vehicle.active then interval = math.max(50, Config.VehicleUpdateInterval or 100) end
            SendNUIMessage({ action = 'update', data = {
                visible = visible,
                health = dead and 0 or clamp(healthPercent, 0, 100),
                armor = clamp(GetPedArmour(ped), 0, 100),
                hunger = hunger,
                thirst = thirst,
                stamina = clamp(GetPlayerSprintStaminaRemaining(player), 0, 100),
                oxygen = underwater and clamp(GetPlayerUnderwaterTimeRemaining(player)
                    / math.max(0.1, Config.OxygenSeconds or 10.0) * 100.0, 0, 100) or 100,
                underwater = underwater,
                stress = stress,
                stressConnected = stressConnected,
                voice = readVoice(),
                talking = NetworkIsPlayerTalking(player),
                vehicle = vehicle
            } })
        elseif nuiReady then
            SendNUIMessage({ action = 'update', data = { visible = false, vehicle = { active = false } } })
            interval = 500
        end
        Wait(interval)
    end
end)

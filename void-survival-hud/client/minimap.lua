local options = Config.Minimap or {}
if options.Enabled ~= true then return end

local ESX
local loaded, bootstrapped, allowed = false, false, false
local dirty, nextCheck = true, 0
local previousRadarVisible = not IsRadarHidden()
local itemName = type(options.Item) == 'string' and options.Item or ''
local interval = math.max(100, math.min(5000, tonumber(options.CheckInterval) or 500))

local function positiveCount(value)
    local count = tonumber(value)
    return count and count == count and count < math.huge and count > 0 or false
end

local function invalidate()
    dirty = true
end

local function readESXInventory()
    local ok, data = pcall(ESX.GetPlayerData)
    if not ok or type(data) ~= 'table' or type(data.inventory) ~= 'table' then return false end
    local inventory = data.inventory
    -- Alcuni inventari ESX espongono una tabella per nome anziché un array.
    local direct = inventory[itemName]
    if type(direct) == 'table' then
        if positiveCount(direct.count) then return true end
    elseif positiveCount(direct) then
        return true
    end
    for _, item in pairs(inventory) do
        if type(item) == 'table' and item.name == itemName and positiveCount(item.count) then
            return true
        end
    end
    return false
end

local function refresh()
    if GetResourceState('es_extended') ~= 'started' then
        ESX, loaded, bootstrapped = nil, false, false
        return false
    end
    if not ESX then
        local ok, object = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and object then ESX = object end
    end
    if not ESX then return false end
    if not bootstrapped then
        if type(ESX.IsPlayerLoaded) ~= 'function' then return false end
        local ok, state = pcall(ESX.IsPlayerLoaded)
        if not ok then return false end
        loaded, bootstrapped = state == true, true
    end
    if not loaded or itemName == '' then return false end

    local backend = options.Inventory or 'auto'
    local oxState = GetResourceState('ox_inventory')
    if backend == 'ox_inventory' or (backend == 'auto' and oxState ~= 'missing') then
        -- Non usare una copia ESX eventualmente vecchia mentre ox si riavvia.
        if oxState ~= 'started' then return false end
        local ok, count = pcall(function()
            return exports['ox_inventory']:Search('count', itemName)
        end)
        return ok and positiveCount(count) or false
    end
    if backend == 'esx' or backend == 'auto' then return readESXInventory() end
    return false
end

RegisterNetEvent('esx:playerLoaded', function()
    loaded, bootstrapped, allowed = true, true, false
    invalidate()
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    -- Non rileggere IsPlayerLoaded: può essere ancora true durante il logout.
    loaded, bootstrapped, allowed = false, true, false
    invalidate()
    DisplayRadar(false)
end)

-- Gli argomenti non sono delta affidabili: si rilegge l'inventario completo.
AddEventHandler('esx:addInventoryItem', invalidate)
AddEventHandler('esx:removeInventoryItem', invalidate)
AddEventHandler('esx:setPlayerData', function(key)
    if key == 'inventory' then invalidate() end
end)
AddEventHandler('ox_inventory:updateInventory', invalidate)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'es_extended' then
        ESX, loaded, bootstrapped, allowed = nil, false, false, false
        invalidate()
    elseif resource == 'ox_inventory' then
        allowed = false
        invalidate()
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == 'es_extended' then
        ESX, loaded, bootstrapped, allowed = nil, false, false, false
        invalidate()
    elseif resource == 'ox_inventory' then
        allowed = false
        invalidate()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        local restore = loaded and GetResourceState('es_extended') == 'started' and previousRadarVisible
        DisplayRadar(restore)
    end
end)

CreateThread(function()
    while true do
        local now = GetGameTimer()
        if dirty or now >= nextCheck then
            allowed = refresh()
            nextCheck = now + interval
            dirty = false
        end
        -- Ogni frame impedisce che il gioco riattivi da solo il radar in auto.
        -- Non cambia la mappa estesa del menu pausa né altri componenti HUD.
        DisplayRadar(allowed and not (Config.HideOnPause and IsPauseMenuActive()))
        Wait(0)
    end
end)

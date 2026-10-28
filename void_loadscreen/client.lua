VoidLoadscreen.validate()
local finished, pending = false, false

local function selectorOwnsTransition()
    local state = GetResourceState('void_characters')
    return Config.Shutdown.Mode == 'auto' and (state == 'started' or state == 'starting')
end

local function finish()
    if finished then return false end
    finished = true
    SendLoadingScreenMessage(json.encode({eventName = 'void:shutdown', durationMs = Config.Shutdown.FadeMs}))
    ShutdownLoadingScreen()
    SetTimeout(Config.Shutdown.FadeMs, function()
        ShutdownLoadingScreenNui()
    end)
    return true
end

exports('Finish', finish)

local function automaticFinish()
    if finished or pending or Config.Shutdown.Mode == 'external' then return end
    if selectorOwnsTransition() then return end
    pending = true
    SetTimeout(Config.Shutdown.DelayMs, function()
        pending = false
        -- Re-evaluate ownership: a selector may have started during the delay.
        if selectorOwnsTransition() then return end
        finish()
    end)
end

AddEventHandler('playerSpawned', automaticFinish)
RegisterNetEvent('esx:playerLoaded', automaticFinish)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', automaticFinish)

CreateThread(function()
    -- Handover already supplies config before the page is painted. This also
    -- hydrates the page if another resource replaced the handover namespace.
    SendLoadingScreenMessage(json.encode({
        eventName = 'void:config',
        config = VoidLoadscreen.publicConfig(GetPlayerName(PlayerId()))
    }))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- Timers do not survive stopping this resource.
    finished = true
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end)

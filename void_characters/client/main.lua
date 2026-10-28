local phase, characters, framework = 'boot', {}, nil
local camera, nuiReady = nil, false
local pendingPreview, previewBusy, operationBusy = nil, false, false
local invBusyBefore, invBusyCaptured
local esxLoaded = false

RegisterNetEvent('esx:playerLoaded', function() esxLoaded = true end)

local function closeLoadingScreen()
    if GetResourceState('void_loadscreen') == 'started' then
        local ok, err = pcall(function() exports.void_loadscreen:Finish() end)
        if ok then return end
        print('[void_characters] Transizione loadscreen: ' .. tostring(err))
    end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end

local function send(action, payload)
    SendNUIMessage({action = action, payload = payload})
end

local function errorMessage(message)
    SendNUIMessage({action = 'error', message = message})
    VoidIntegrations.notify(message, 'error')
end

local function server(action, data)
    local ok, result = pcall(lib.callback.await, 'void_characters:' .. action, false, data or {})
    if not ok or type(result) ~= 'table' then
        print(('[void_characters] Callback %s fallita: %s'):format(action, tostring(result)))
        return {ok = false, error = 'Il server non risponde. Controlla la console o riprova.'}
    end
    return result
end

local function setInventoryBusy(value)
    if not invBusyCaptured then
        invBusyBefore, invBusyCaptured = LocalPlayer.state.invBusy, true
    end
    LocalPlayer.state:set('invBusy', value, true)
end

local function hook(name, context)
    local ok, err = pcall(Config.Hooks[name], context)
    if not ok then print(('[void_characters] Hook %s: %s'):format(name, tostring(err))) end
end

local function destroyCamera()
    if camera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(camera, false)
        camera = nil
    end
end

local function cleanup(loaded)
    SetNuiFocus(false, false)
    send('close')
    destroyCamera()
    VoidIntegrations.hideText()
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    NetworkClearClockTimeOverride()
    SetEntityVisible(PlayerPedId(), true, false)
    FreezeEntityPosition(PlayerPedId(), false)
    SetPlayerInvincible(PlayerId(), false)
    SetPlayerControl(PlayerId(), true, 0)
    DisplayRadar(true)
    if invBusyCaptured then
        -- ox_inventory starts busy before login; restoring that value would lock
        -- the inventory permanently after a successful first spawn.
        LocalPlayer.state:set('invBusy', not loaded and invBusyBefore or false, true)
    end
    invBusyCaptured = false
end

local function putInScene()
    local pos, ped = Config.Scene.Ped, PlayerPedId()
    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(ped, pos.w)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    SetPlayerInvincible(PlayerId(), true)
    SetPlayerControl(PlayerId(), false, 0)
end

local function createScene()
    setInventoryBusy(true)
    if GetResourceState('spawnmanager') == 'started' then exports.spawnmanager:setAutoSpawn(false) end
    VoidIntegrations.setModel()
    local pos = Config.Scene.Ped
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, pos.w, true, false)
    putInScene()
    camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camera, Config.Scene.Camera.x, Config.Scene.Camera.y, Config.Scene.Camera.z)
    PointCamAtCoord(camera, Config.Scene.LookAt.x, Config.Scene.LookAt.y, Config.Scene.LookAt.z)
    SetCamFov(camera, Config.Scene.Fov)
    RenderScriptCams(true, false, 0, true, true)
    SetWeatherTypeNowPersist(Config.Scene.Weather)
    DisplayRadar(false)
    hook('SelectionStarted')
end

local function publicPayload(result)
    local i = Config.Identity
    return {
        characters = result.characters or {}, slots = result.slots or Config.Slots.Default,
        allowDelete = result.allowDelete == true, framework = result.framework,
        brand = {name = Config.Brand.Name, tagline = Config.Brand.Tagline},
        deleteConfirmation = Config.DeleteConfirmation,
        identity = {
            minNameLength = i.MinNameLength, maxNameLength = i.MaxNameLength,
            minAge = i.MinAge, maxAge = i.MaxAge, minHeight = i.MinHeight, maxHeight = i.MaxHeight,
            nationalities = i.Nationalities
        }
    }
end

local function refresh()
    local result = server('list')
    if result.ok then
        characters, framework = result.characters, result.framework
        return publicPayload(result)
    end
    return result
end

local function findCharacter(id)
    for _, character in ipairs(characters) do
        if character.id == id then return character end
    end
end

local function validPosition(position)
    if type(position) ~= 'table' then return false end
    for _, key in ipairs({'x', 'y', 'z'}) do
        local value = position[key]
        if type(value) ~= 'number' or value ~= value or math.abs(value) > 20000 then return false end
    end
    return true
end

local function spawnCharacter(context)
    local character, isNew = context.character, context.isNew
    local pos = Config.Spawn.Default
    if not isNew and Config.Spawn.UseLastPosition and validPosition(character.position) then
        pos = character.position
    end
    context.position = pos
    if Config.Spawn.Provider == 'custom' then
        assert(Config.Spawn.Custom(context) == true, 'Lo spawn custom deve attendere il completamento e restituire true.')
    else
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        SetEntityCoordsNoOffset(PlayerPedId(), pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(PlayerPedId(), pos.w or pos.heading or 0.0)
        local deadline = GetGameTimer() + 8000
        while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < deadline do Wait(50) end
    end
end

local function finishLogin(result)
    phase = 'loading'
    local context = {character = result.character, isNew = result.new == true, framework = result.framework}
    context.needsAppearance = Config.Appearance.Provider ~= 'none'
        and (context.isNew or type(context.character.appearance) ~= 'table' or next(context.character.appearance) == nil)
    -- esx:onPlayerJoined sends its own loaded event. Never synthesize it here.
    if result.framework == 'esx' then
        local deadline = GetGameTimer() + Config.Server.LoginTimeout * 1000
        while not esxLoaded and GetGameTimer() < deadline do Wait(50) end
        assert(esxLoaded, 'Evento esx:playerLoaded non ricevuto. Riconnettiti e controlla ESX.')
    end
    -- Finish any in-flight ped preview before applying the chosen appearance.
    pendingPreview = nil
    while previewBusy do Wait(0) end
    DoScreenFadeOut(250)
    Wait(300)
    SetNuiFocus(false, false)
    send('close')
    destroyCamera()
    VoidIntegrations.hideText()
    VoidIntegrations.applyAppearance(context.character)
    FreezeEntityPosition(PlayerPedId(), true)
    SetPlayerControl(PlayerId(), true, 0)
    spawnCharacter(context)
    VoidIntegrations.frameworkLoaded(result.framework)
    -- Resume an interrupted first creation after reconnect, too.
    if context.needsAppearance then
        phase = 'customizing'
        DoScreenFadeIn(400)
        local complete = false
        repeat
            local ok, saved = pcall(VoidIntegrations.createAppearance, context)
            complete = ok and saved == true
            if not complete then
                if not ok then print('[void_characters] Editor aspetto: ' .. tostring(saved)) end
                lib.alertDialog({
                    header = 'Completa il tuo personaggio',
                    content = 'L’aspetto non è stato salvato. Verifica che il provider sia attivo e riapri l’editor.',
                    centered = true, labels = {confirm = 'Riprova'}
                })
            end
        until complete
    end
    -- Acknowledge server-side login before releasing controls and the private bucket.
    local finished
    for attempt = 1, 3 do
        finished = server('finished')
        if finished.ok then break end
        Wait(1100)
    end
    assert(finished and finished.ok, finished and finished.error or 'Impossibile uscire dalla selezione personaggio.')
    phase = 'ready'
    cleanup(true)
    hook('CharacterReady', context)
    DoScreenFadeIn(500)
end

local function choose(action, data, cb)
    if phase ~= 'selecting' or operationBusy then cb({ok = false, error = 'Operazione già in corso.'}) return end
    local ok, err = VoidIntegrations.preflight(framework)
    if not ok then cb({ok = false, error = err}) return end
    operationBusy = true
    local result = server(action, data)
    cb(result)
    if result.ok then
        local loaded, loadError = pcall(finishLogin, result)
        if not loaded then
            phase = 'failed'
            cleanup()
            DoScreenFadeIn(500)
            errorMessage('Caricamento interrotto: riconnettiti e controlla la console del server.')
            print('[void_characters] ' .. tostring(loadError))
        end
    end
    operationBusy = false
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    cb({ok = true})
end)

RegisterNUICallback('list', function(_, cb)
    if phase ~= 'selecting' or operationBusy then cb({ok = false, error = 'Lista non disponibile durante il caricamento.'}) return end
    operationBusy = true
    local result = refresh()
    result.ok = result.ok ~= false
    cb(result)
    operationBusy = false
end)

RegisterNUICallback('preview', function(data, cb)
    if phase ~= 'selecting' or operationBusy then cb({ok = false}) return end
    local character = findCharacter(data.id)
    if not character then cb({ok = false}) return end
    pendingPreview = character
    cb({ok = true})
end)

RegisterNUICallback('select', function(data, cb) choose('select', data, cb) end)
RegisterNUICallback('create', function(data, cb) choose('create', data, cb) end)

RegisterNUICallback('delete', function(data, cb)
    if phase ~= 'selecting' or operationBusy then cb({ok = false, error = 'Operazione già in corso.'}) return end
    operationBusy = true
    local result = server('delete', data)
    if result.ok then
        result = refresh()
        result.ok = result.ok ~= false
        VoidIntegrations.notify('Personaggio eliminato.', 'success')
    end
    cb(result)
    operationBusy = false
end)

CreateThread(function()
    while true do
        if pendingPreview and phase == 'selecting' then
            local character = pendingPreview
            pendingPreview, previewBusy = nil, true
            local ok, err = pcall(VoidIntegrations.applyAppearance, character)
            if not ok then print('[void_characters] Anteprima: ' .. tostring(err)) end
            if phase == 'selecting' then putInScene() end
            previewBusy = false
        end
        Wait(50)
    end
end)

CreateThread(function()
    while true do
        if phase == 'selecting' or phase == 'loading' then
            DisableAllControlActions(0)
            HideHudAndRadarThisFrame()
            NetworkOverrideClockTime(Config.Scene.Time.Hour, Config.Scene.Time.Minute, 0)
            Wait(0)
        else Wait(250) end
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    -- A resource restart must not teleport an already loaded character into selection.
    if VoidIntegrations.isLoaded() then phase = 'ready' return end
    local nuiDeadline = GetGameTimer() + 30000
    while not nuiReady and GetGameTimer() < nuiDeadline do Wait(100) end
    if not nuiReady then
        phase = 'failed'
        closeLoadingScreen()
        DoScreenFadeIn(0)
        VoidIntegrations.notify('Interfaccia VOID non disponibile. Controlla i file NUI e riconnettiti.', 'error')
        return
    end
    DoScreenFadeOut(0)
    phase = 'selecting'
    local ok, err = pcall(createScene)
    if not ok then
        phase = 'failed'
        cleanup()
        closeLoadingScreen()
        DoScreenFadeIn(500)
        errorMessage('Impossibile preparare la scena. Controlla Config.Scene e la console F8.')
        print('[void_characters] ' .. tostring(err))
        return
    end
    local result = refresh()
    -- Keep a retry path visible even if SQL or a required resource is not ready.
    local payload = result.ok == false and publicPayload({}) or result
    if result.ok == false then payload.error = result.error end
    send('open', payload)
    SetNuiFocus(true, true)
    closeLoadingScreen()
    DoScreenFadeIn(650)
    VoidIntegrations.showText('VOID · Seleziona un’identità per continuare')
    if result.ok == false then VoidIntegrations.notify(result.error, 'error') end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or phase == 'ready' then return end
    phase = 'stopped'
    cleanup()
    DoScreenFadeIn(0)
end)

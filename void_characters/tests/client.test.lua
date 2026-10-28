-- Run from the resource directory: texlua tests/client.test.lua
-- Provider contract tests; this does not emulate GTA or replace an in-game test.
local passed = 0
local resources, events, notices, applied, editorOptions, editorResult = {}, {}, {}, {}, nil, nil
local registeredExports = {}
local currentModel = 100
local function eq(actual, expected, context)
    assert(actual == expected, (context or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function test(name, fn)
    events, notices, applied = {}, {}, {}
    fn()
    passed = passed + 1
    print('PASS ' .. name)
end

function vector3(x, y, z) return { x = x, y = y, z = z } end
function vector4(x, y, z, w) return { x = x, y = y, z = z, w = w } end
function GetResourceState(name) return resources[name] or 'missing' end
function PlayerId() return 1 end
function PlayerPedId() return 2 end
function GetEntityModel() return currentModel end
function joaat(model)
    if model == 'mp_f_freemode_01' then return 101 end
    if model == 'mp_m_freemode_01' then return 100 end
    return 999
end
function IsModelInCdimage(model) return model == 100 or model == 101 end
function IsModelAPed(model) return IsModelInCdimage(model) end
function SetPlayerModel(_, model) currentModel = model; applied[#applied + 1] = model end
function SetModelAsNoLongerNeeded() end
function SetPedDefaultComponentVariation() end
function TriggerServerEvent(name, payload) events[#events + 1] = { name = name, payload = payload, server = true } end
function TriggerEvent(name, payload) events[#events + 1] = { name = name, payload = payload, server = false } end

LocalPlayer = { state = {} }
lib = {
    requestModel = function(model) assert(model == 100 or model == 101) end,
    notify = function(data) notices[#notices + 1] = data end,
    showTextUI = function(text, options) applied.text = text; applied.position = options.position end,
    hideTextUI = function() applied.hidden = true end
}
promise = { new = function()
    return { resolve = function(self, value) self.value = value; self.resolved = true end }
end }
Citizen = { Await = function(value) assert(value.resolved, 'Provider did not resolve completion'); return value.value end }
local esx = { SetPlayerData = function(key, value) applied[key] = value end, IsPlayerLoaded = function() return false end }
exports = setmetatable({
    ['illenium-appearance'] = {
        startPlayerCustomization = function(_, callback, options)
            editorOptions = options
            callback(editorResult)
        end,
        setPlayerAppearance = function(_, appearance) applied.appearance = appearance end,
        setPedAppearance = function(_, ped, appearance) eq(ped, 2); applied.appearance = appearance end
    },
    es_extended = { getSharedObject = function() return esx end }
}, { __call = function(_, name, callback) registeredExports[name] = callback end })

dofile('config.lua')
dofile('client/integrations.lua')

test('Missing illenium blocks login before character creation', function()
    Config.Appearance.Provider = 'illenium-appearance'
    local ok, message = VoidIntegrations.preflight('esx')
    eq(ok, false)
    assert(message:find('illenium%-appearance'))
    resources['illenium-appearance'] = 'started'
    eq(VoidIntegrations.preflight('esx'), true)
end)

test('Appearance with the same model does not recreate or reset the player ped', function()
    Config.Appearance.Provider = 'illenium-appearance'
    currentModel = 100
    local appearance = { model = 'mp_m_freemode_01', components = {} }
    VoidIntegrations.applyAppearance({ sex = 'm', appearance = appearance })
    eq(#applied, 0, 'SetPlayerModel calls')
    eq(applied.appearance, appearance)
end)

test('Appearance changes model once and then applies to the resulting ped', function()
    currentModel = 100
    local appearance = { model = 'mp_f_freemode_01', components = {} }
    VoidIntegrations.applyAppearance({ sex = 'f', appearance = appearance })
    eq(#applied, 1, 'SetPlayerModel calls')
    eq(applied[1], 101)
    eq(applied.appearance, appearance)
end)

test('Other VOID scripts can reuse registered notification and text UI adapters', function()
    eq(registeredExports.Notify, VoidIntegrations.notify)
    eq(registeredExports.ShowTextUI, VoidIntegrations.showText)
    eq(registeredExports.HideTextUI, VoidIntegrations.hideText)
end)

test('ESX skin cannot be configured against QB or Qbox', function()
    Config.Appearance.Provider = 'esx_skin'
    resources.esx_skin, resources.skinchanger = 'started', 'started'
    eq(VoidIntegrations.preflight('qb'), false)
    eq(VoidIntegrations.preflight('qbox'), false)
    eq(VoidIntegrations.preflight('esx'), true)
    resources.skinchanger = 'missing'
    eq(VoidIntegrations.preflight('esx'), false)
end)

test('Appearance success uses the official persistence event and cannot exit unsaved', function()
    Config.Appearance.Provider = 'illenium-appearance'
    Config.Appearance.Creator.enableExit = true
    editorResult = { model = 'mp_m_freemode_01', components = {} }
    eq(VoidIntegrations.createAppearance({}), true)
    eq(editorOptions.enableExit, false)
    eq(Config.Appearance.Creator.enableExit, true, 'Do not mutate shared config')
    eq(#events, 1)
    eq(events[1].name, 'illenium-appearance:server:saveAppearance')
    eq(events[1].payload, editorResult)
    eq(events[1].server, true)
end)

test('Cancelled appearance never signals a successful save', function()
    editorResult = nil
    eq(VoidIntegrations.createAppearance({}), false)
    eq(#events, 0)
end)

test('Custom creator must explicitly acknowledge persistence', function()
    Config.Appearance.Provider = 'custom'
    Config.Appearance.Custom = function(context, done) eq(context.id, 17); done(false) end
    eq(VoidIntegrations.createAppearance({ id = 17 }), false)
    Config.Appearance.Custom = function(_, done) done(true) end
    eq(VoidIntegrations.createAppearance({}), true)
end)

test('No appearance provider skips creation without triggering external events', function()
    Config.Appearance.Provider = 'none'
    eq(VoidIntegrations.createAppearance({}), true)
    eq(#events, 0)
end)

test('QB lifecycle emits client and server loaded once each', function()
    VoidIntegrations.frameworkLoaded('qb')
    eq(#events, 2)
    eq(events[1].name, 'QBCore:Server:OnPlayerLoaded')
    eq(events[2].name, 'QBCore:Client:OnPlayerLoaded')
end)

test('ESX lifecycle never synthesizes playerLoaded or grants inventory items', function()
    VoidIntegrations.frameworkLoaded('esx')
    eq(applied.ped, 2)
    for _, event in ipairs(events) do
        assert(event.name ~= 'esx:playerLoaded')
        assert(not event.name:lower():find('item'))
    end
    eq(events[1].name, 'esx:onPlayerSpawn')
    eq(events[2].name, 'esx:onPlayerSpawn')
end)

test('Ox text UI and notification contracts remain configurable', function()
    Config.TextUI.Provider = 'ox_lib'
    VoidIntegrations.showText('Seleziona identità')
    eq(applied.text, 'Seleziona identità')
    eq(applied.position, Config.TextUI.Position)
    VoidIntegrations.hideText()
    eq(applied.hidden, true)
    Config.Notifications.Provider = 'ox_lib'
    VoidIntegrations.notify('Errore', 'error')
    eq(notices[1].title, 'VOID')
    eq(notices[1].description, 'Errore')
    eq(notices[1].type, 'error')
end)

-- Exercise the real client orchestration with immediate simulated FiveM replies.
-- Tick/preview threads are registered but not run: GTA graphics are not mocked.
local function simulateLogin(appearance, options)
    options = options or {}
    local callbacks, netEvents, threads, log, notifications, handlers = {}, {}, {}, {}, {}, {}
    local clock, creatorCalls, readyContext = 0, 0, nil
    local controlsEnabled, frozen, nuiFocused, invincible
    local character = {
        id = 'char1:license-test', slot = 1, firstname = 'Andrea', lastname = 'Moretti',
        sex = 'm', appearance = appearance, position = { x = 200, y = 300, z = 30, w = 90 }
    }
    local state = { invBusy = true }
    function state:set(key, value) self[key] = value end
    local env = setmetatable({
        Config = {
            Brand = Config.Brand, Identity = Config.Identity, Slots = Config.Slots,
            Scene = Config.Scene, Server = Config.Server, DeleteConfirmation = Config.DeleteConfirmation,
            Spawn = { Provider = 'direct', UseLastPosition = true, Default = Config.Spawn.Default },
            Appearance = { Provider = 'illenium-appearance' },
            Hooks = { SelectionStarted = function() end, CharacterReady = function(context) readyContext = context end }
        },
        LocalPlayer = { state = state },
        VoidIntegrations = {
            isLoaded = function() return options.alreadyLoaded == true end,
            preflight = function() return true end,
            setModel = function() end,
            applyAppearance = function() end,
            showText = function() end, hideText = function() end,
            notify = function(message) notifications[#notifications + 1] = message end,
            frameworkLoaded = function() log[#log + 1] = 'frameworkLoaded' end,
            createAppearance = function() creatorCalls = creatorCalls + 1; return true end
        },
        RegisterNetEvent = function(name, callback) netEvents[name] = callback end,
        RegisterNUICallback = function(name, callback) callbacks[name] = callback end,
        CreateThread = function(callback) threads[#threads + 1] = callback end,
        AddEventHandler = function(name, callback) handlers[name] = callback end,
        GetCurrentResourceName = function() return 'void_characters' end,
        NetworkIsPlayerActive = function() return true end,
        GetResourceState = function() return 'missing' end,
        GetGameTimer = function() return clock end,
        Wait = function(ms) clock = clock + math.max(ms, 1) end,
        SendNUIMessage = function(message) log[#log + 1] = message.action end,
        CreateCam = function() return 12 end,
        HasCollisionLoadedAroundEntity = function() return true end,
        lib = {
            callback = { await = function(name)
                local action = name:match(':(.+)$')
                log[#log + 1] = action
                if action == 'list' then return { ok = true, characters = {character}, slots = 3, framework = 'esx' } end
                if action == 'select' then
                    netEvents['esx:playerLoaded']()
                    return { ok = true, character = character, framework = 'esx', new = false }
                end
                if action == 'finished' then return { ok = true } end
                error('Unexpected action ' .. tostring(action))
            end },
            alertDialog = function() error('Unexpected retry dialog') end
        }
    }, { __index = _G })
    local noops = {
        'SetNuiFocus', 'RenderScriptCams', 'DestroyCam', 'ClearOverrideWeather', 'ClearWeatherTypePersist',
        'NetworkClearClockTimeOverride', 'SetEntityVisible', 'FreezeEntityPosition', 'SetPlayerInvincible',
        'SetPlayerControl', 'DisplayRadar', 'SetEntityCoordsNoOffset', 'SetEntityHeading',
        'NetworkResurrectLocalPlayer', 'SetCamCoord', 'PointCamAtCoord', 'SetCamFov', 'SetWeatherTypeNowPersist',
        'RequestCollisionAtCoord', 'DoScreenFadeOut', 'DoScreenFadeIn', 'ShutdownLoadingScreen', 'ShutdownLoadingScreenNui'
    }
    for _, name in ipairs(noops) do env[name] = function() end end
    env.SetNuiFocus = function(focus) nuiFocused = focus end
    env.SetPlayerControl = function(_, enabled) controlsEnabled = enabled end
    env.FreezeEntityPosition = function(_, enabled) frozen = enabled end
    env.SetPlayerInvincible = function(_, enabled) invincible = enabled end
    assert(loadfile('client/main.lua', 't', env))()
    callbacks.ready({}, function(result) eq(result.ok, true) end)
    threads[#threads]()
    if options.stopDuringSelection then
        handlers.onResourceStop('void_characters')
    elseif not options.alreadyLoaded then
        callbacks.select({ id = character.id }, function(result) eq(result.ok, true) end)
    end
    return {
        state = state, log = log, creatorCalls = creatorCalls, context = readyContext, notifications = notifications,
        controlsEnabled = controlsEnabled, frozen = frozen, nuiFocused = nuiFocused, invincible = invincible
    }
end

test('Reconnect resumes incomplete appearance before the character is marked ready', function()
    local result = simulateLogin(nil)
    eq(result.creatorCalls, 1)
    assert(result.context, 'CharacterReady hook was not reached')
    eq(result.context.isNew, false)
    eq(result.context.needsAppearance, true)
    eq(result.context.position.x, 200, 'Existing characters retain last position')
end)

test('Existing saved appearance skips editor and releases the initial ox inventory lock', function()
    local result = simulateLogin({ model = 'mp_m_freemode_01' })
    eq(result.creatorCalls, 0)
    assert(result.context, 'CharacterReady hook was not reached')
    eq(result.state.invBusy, false, 'Pre-login ox invBusy=true must not be restored after successful login')
end)

test('Restart on a loaded player never reopens selection or moves the player', function()
    local result = simulateLogin(nil, { alreadyLoaded = true })
    eq(result.creatorCalls, 0)
    eq(#result.log, 0)
    eq(result.context, nil)
end)

test('Resource stop during selection restores controls and the pre-login inventory state', function()
    local result = simulateLogin(nil, { stopDuringSelection = true })
    eq(result.state.invBusy, true, 'Unloaded player keeps the inventory initialization lock')
    eq(result.controlsEnabled, true)
    eq(result.frozen, false)
    eq(result.nuiFocused, false)
    eq(result.invincible, false)
    eq(result.creatorCalls, 0)
    eq(result.context, nil)
end)

print(('Client provider tests: %d passed'):format(passed))

-- Run from inventory_patch: lua tests/native_bridge.test.lua (or texlua).
-- Native calls are mocked; this does not prove camera alignment inside GTA.
local passed = 0
local function eq(actual, expected, message)
    assert(actual == expected, (message or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function test(name, fn)
    fn()
    passed = passed + 1
    print('PASS ' .. name)
end

local function simulation(options)
    options = options or {}
    local root = (arg[0]:match('^(.*)/tests/[^/]+$') or '.')
    local s = {
        open = false, clock = 0, heading = 90, model = 100, realPed = 10,
        coords = {x = 2, y = 4, z = 6}, health = 187, maxHealth = 200, armor = 35,
        exists = {[10] = true}, cams = {}, render = nil, log = {}, messages = {},
        vehicle = false, dead = false, pause = false, focus = false, cuffed = false,
        callbacks = {}, events = {}, handlers = {}, commands = {}, keys = {}, uses = {},
        state = {invOpen = false, invBusy = false, invHotkeys = true}, progress = false,
        weapon = {slot = 3}
    }
    local function log(name, ...) s.log[#s.log + 1] = {name, ...} end
    local env = setmetatable({
        PlayerData = {loaded = true, weight = 6240, maxWeight = 30000},
        client = {screenblur = true},
        LocalPlayer = {state = s.state},
        lib = {progressActive = function() return s.progress end},
        PlayerPedId = function() return s.realPed end,
        GetCurrentResourceName = function() return 'ox_inventory' end,
        GetGameTimer = function() return s.clock end,
        GetEntityHeading = function() return s.heading end,
        GetEntityModel = function() return s.model end,
        GetEntityCoords = function() return s.coords end,
        GetEntityHealth = function() return s.health end,
        GetEntityMaxHealth = function() return s.maxHealth end,
        GetPedArmour = function() return s.armor end,
        DoesEntityExist = function(id) return s.exists[id] == true end,
        IsEntityDead = function() return s.dead end,
        IsPedFatallyInjured = function() return s.dead end,
        IsPedInAnyVehicle = function() return s.vehicle end,
        IsPauseMenuActive = function() return s.pause end,
        IsPedCuffed = function() return s.cuffed end,
        IsNuiFocused = function() return s.focus end,
        IsGameplayCamRendering = function() return s.render == nil end,
        GetRenderingCam = function() return s.render end,
        DoesCamExist = function(cam) return s.cams[cam] == true end,
        ClonePed = function(ped, heading, networked, host)
            eq(ped, s.realPed); eq(networked, false); eq(host, false)
            if options.cloneFails then return 0 end
            s.nextClone = (s.nextClone or 29) + 1
            s.exists[s.nextClone] = true
            log('clone', s.nextClone)
            return s.nextClone
        end,
        CreateCam = function()
            if options.cameraFails then return 0 end
            s.nextCam = (s.nextCam or 19) + 1
            s.cams[s.nextCam] = true
            return s.nextCam
        end,
        SetCamCoord = function(cam, x, y, z) log('camCoord', cam, x, y, z) end,
        PointCamAtCoord = function(cam, x, y, z) log('camTarget', cam, x, y, z) end,
        SetCamFov = function(cam, fov) log('fov', cam, fov) end,
        SetCamActive = function(cam) s.activeCam = cam end,
        RenderScriptCams = function(enabled)
            log('render', enabled)
            s.render = enabled and s.activeCam or nil
        end,
        DestroyCam = function(cam) s.cams[cam] = nil; log('destroy', cam) end,
        DeleteEntity = function(entity) s.exists[entity] = nil; log('delete', entity) end,
        SetEntityHeading = function(entity, heading)
            assert(entity ~= s.realPed, 'Actual player heading changed')
            log('heading', entity, heading)
        end,
        SetEntityLocallyInvisible = function(entity) eq(entity, s.realPed); log('localHide', entity) end,
        SendNUIMessage = function(data) s.messages[#s.messages + 1] = data end,
        RegisterNUICallback = function(name, callback) s.callbacks[name] = callback end,
        RegisterNetEvent = function(name, callback) s.events[name] = callback end,
        AddEventHandler = function(name, callback) s.handlers[name] = callback end,
        RegisterCommand = function(name, callback) s.commands[name] = callback end,
        RegisterKeyMapping = function(name, _, _, key) s.keys[name] = key end,
        CreateThread = function(fn) s.thread = coroutine.create(fn) end,
        Wait = function() coroutine.yield() end,
        print = function() end
    }, {__index = _G})
    for _, name in ipairs({'SetEntityAsMissionEntity', 'SetEntityCollision', 'SetEntityInvincible', 'FreezeEntityPosition', 'SetBlockingOfNonTemporaryEvents', 'ClearPedTasksImmediately', 'RemoveAllPedWeapons'}) do
        env[name] = function(entity, ...)
            assert(entity ~= s.realPed, 'Gameplay player was modified by ' .. name)
            log(name, entity, ...)
        end
    end
    env.exports = {ox_inventory = {
        getCurrentWeapon = function() return s.weapon end,
        GetPlayerWeight = function() return s.exportWeight or 6240 end,
        GetPlayerMaxWeight = function() return s.exportMaxWeight or 30000 end,
        useSlot = function(_, slot) s.uses[#s.uses + 1] = slot end
    }}
    assert(loadfile(root .. '/ox_inventory/void/config.lua', 't', env))()
    if options.previewDisabled then env.VoidInventoryConfig.Preview.Enabled = false end
    if options.extraKeys then env.VoidInventoryConfig.Hotkeys.ExtraEnabled = true end
    assert(loadfile(root .. '/ox_inventory/void/client.lua', 't', env))()
    s.env = env
    function s.tick(ms)
        s.clock = s.clock + (ms or 250)
        local ok, err = coroutine.resume(s.thread)
        assert(ok, err)
    end
    function s.callback(name, data)
        local result
        s.callbacks[name](data, function(value) result = value end)
        return result
    end
    function s.count(name)
        local n = 0
        for _, entry in ipairs(s.log) do if entry[1] == name then n = n + 1 end end
        return n
    end
    function s.latest() return s.messages[#s.messages] and s.messages[#s.messages].data end
    return s
end

test('Closed inventory creates no clone, camera or UI message', function()
    local s = simulation(); s.tick()
    eq(s.count('clone'), 0); eq(s.count('render'), 0); eq(#s.messages, 0)
    eq(s.callback('voidStatus', {}).ok, false)
end)

test('Open creates a local clone and camera without modifying the gameplay ped', function()
    local s = simulation(); s.state.invOpen = true; s.tick()
    eq(s.count('clone'), 1); eq(s.render, 20)
    eq(s.count('SetEntityCollision'), 1)
    for _, item in ipairs(s.log) do if item[1] == 'SetEntityCollision' then eq(item[3], false) end end
    eq(s.count('localHide'), 1); eq(s.heading, 90)
    eq(s.coords.x, 2); eq(s.coords.y, 4); eq(s.coords.z, 6)
    eq(s.latest().previewActive, true)
end)

test('Health, armor, weight and weapon slot are obtained from real state', function()
    local s = simulation(); s.state.invOpen = true; s.tick()
    local data = s.callback('voidStatus', {}).status
    eq(data.health, 87); eq(data.armor, 35); eq(data.weight, 6240); eq(data.maxWeight, 30000); eq(data.weaponSlot, 3)
    s.health, s.armor, s.maxHealth = 100, 999, 200
    eq(s.callback('voidStatus', {}).status.health, 0)
    eq(s.callback('voidStatus', {}).status.armor, 100)
    s.maxHealth, s.health = 100, 75
    eq(s.callback('voidStatus', {}).status.health, 75)
end)

test('Close destroys owned entities and local hiding stops immediately', function()
    local s = simulation(); s.state.invOpen = true; s.tick()
    s.state.invOpen = false; s.tick()
    eq(s.count('delete'), 1); eq(s.count('destroy'), 1); eq(s.render, nil); eq(s.count('localHide'), 1)
    s.tick(); eq(s.count('delete'), 1)
end)

test('Another script camera is never disabled by preview cleanup', function()
    local s = simulation(); s.state.invOpen = true; s.tick()
    s.render, s.cams[99] = 99, true
    s.tick()
    eq(s.render, 99); eq(s.cams[99], true); eq(s.count('destroy'), 1); eq(s.count('delete'), 1)
    eq(s.count('render'), 1, 'Foreign camera was switched off')
    eq(s.latest().previewActive, false)
end)

test('An existing script camera, a vehicle or death prevents preview capture', function()
    for _, kind in ipairs({'camera', 'vehicle', 'dead'}) do
        local s = simulation()
        if kind == 'camera' then s.render = 99 elseif kind == 'vehicle' then s.vehicle = true else s.dead = true end
        s.state.invOpen = true; s.tick()
        eq(s.count('clone'), 0, kind)
        eq(s.latest().previewActive, false)
    end
end)

test('Clone or camera creation failures leave no entity or render leak', function()
    local s = simulation({cloneFails = true}); s.state.invOpen = true; s.tick()
    eq(s.count('clone'), 0); eq(s.render, nil); eq(s.latest().previewActive, false)
    s = simulation({cameraFails = true}); s.state.invOpen = true; s.tick()
    eq(s.count('delete'), 1); eq(s.render, nil); eq(s.count('localHide'), 0)
end)

test('Player movement and model changes clean up or refresh the owned preview', function()
    local s = simulation(); s.state.invOpen = true; s.tick()
    s.model = 101; s.tick()
    eq(s.count('clone'), 2); eq(s.count('delete'), 1)
    s.coords = {x = 20, y = 4, z = 6}; s.tick()
    eq(s.count('delete'), 2); eq(s.latest().previewActive, false)
end)

test('Rotation is validated and changes only clone heading', function()
    local s = simulation(); s.state.invOpen = true; s.tick()
    eq(s.callback('voidPreviewRotate', {direction = '1'}).ok, false)
    eq(s.callback('voidPreviewRotate', {direction = 99}).ok, false)
    eq(s.callback('voidPreviewRotate', {direction = 1}).ok, true)
    eq(s.log[#s.log][3], 105); eq(s.heading, 90)
    s.state.invOpen = false
    eq(s.callback('voidPreviewRotate', {direction = -1}).ok, false)
end)

test('Native blur setting is restored on stop and untouched if preview is disabled', function()
    local s = simulation(); eq(s.env.client.screenblur, false)
    s.state.invOpen = true; s.tick()
    s.handlers.onResourceStop('another_resource'); eq(s.count('delete'), 0)
    s.handlers.onResourceStop('ox_inventory')
    eq(s.count('delete'), 1); eq(s.count('destroy'), 1); eq(s.env.client.screenblur, true)
    s = simulation({previewDisabled = true}); eq(s.env.client.screenblur, true)
    s.state.invOpen = true; s.tick(); eq(s.count('clone'), 0)
end)

test('Framework unload releases preview and never reopens while inventory remains stale', function()
    local s = simulation(); s.state.invOpen = true; s.tick()
    s.events['esx:onPlayerLogout'](); eq(s.count('delete'), 1)
    s.tick(); eq(s.count('clone'), 1); eq(s.latest().previewActive, false)
end)

test('Extra keys are opt-in and use only their actual native inventory slots', function()
    local s = simulation(); eq(next(s.commands), nil)
    s = simulation({extraKeys = true})
    for slot = 6, 10 do
        local name = 'void_inventory_slot_' .. slot
        assert(s.commands[name]); eq(s.keys[name], slot == 10 and '0' or tostring(slot))
        s.commands[name]()
        eq(s.uses[#s.uses], slot)
    end
end)

test('Extra keys respect open inventory, busy state, hotkeys, focus and ped restrictions', function()
    local s = simulation({extraKeys = true})
    local command = s.commands.void_inventory_slot_6
    for _, key in ipairs({'invOpen', 'invBusy'}) do s.state[key] = true; command(); s.state[key] = false end
    s.state.invHotkeys = false; command(); s.state.invHotkeys = true
    for _, key in ipairs({'focus', 'vehicle', 'dead', 'pause', 'cuffed', 'progress'}) do s[key] = true; command(); s[key] = false end
    s.env.PlayerData.loaded = false; command(); s.env.PlayerData.loaded = true
    eq(#s.uses, 0)
    command(); eq(s.uses[1], 6)
end)

print(('Native bridge: %d tests passed (FiveM natives simulated)'):format(passed))

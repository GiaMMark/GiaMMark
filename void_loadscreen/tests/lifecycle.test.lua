-- Run from void_loadscreen: lua tests/lifecycle.test.lua (Lua 5.3+ / texlua).
-- Deterministic tests of real resource lifecycle and handover code. GTA/CEF are
-- boundaries, not emulated engines: complete the documented in-game smoke test.
local passed = 0
local function eq(actual, expected, message)
    assert(actual == expected, (message or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function test(name, action)
    action()
    passed = passed + 1
    print('PASS ' .. name)
end

local function runtime(mode, owner)
    local events, timers, threads, registered, messages = {}, {}, {}, {}, {}
    local calls = {engine = 0, nui = 0}
    local resources = {void_characters = owner and 'started' or 'missing'}
    local env = setmetatable({
        GetResourceState = function(name) return resources[name] or 'missing' end,
        GetCurrentResourceName = function() return 'void_loadscreen' end,
        GetPlayerName = function() return 'Test Player' end,
        PlayerId = function() return 1 end,
        AddEventHandler = function(name, callback) events[name] = callback end,
        RegisterNetEvent = function(name, callback) events[name] = callback end,
        CreateThread = function(callback) threads[#threads + 1] = callback end,
        SetTimeout = function(delay, callback) timers[#timers + 1] = {delay = delay, callback = callback} end,
        SendLoadingScreenMessage = function(message) messages[#messages + 1] = message end,
        ShutdownLoadingScreen = function() calls.engine = calls.engine + 1 end,
        ShutdownLoadingScreenNui = function() calls.nui = calls.nui + 1 end,
        exports = function(name, callback) registered[name] = callback end,
        json = {encode = function(value) return value end}
    }, {__index = _G})
    assert(loadfile('config.lua', 't', env))()
    env.Config.Shutdown.Mode = mode or 'auto'
    env.Config.Shutdown.DelayMs = 50
    assert(loadfile('shared.lua', 't', env))()
    assert(loadfile('client.lua', 't', env))()
    local result = {env = env, events = events, timers = timers, threads = threads,
        exports = registered, messages = messages, calls = calls, resources = resources}
    function result.tick()
        assert(#timers > 0, 'No queued timer')
        local timer = table.remove(timers, 1)
        timer.callback()
        return timer.delay
    end
    return result
end

test('Finish closes native loading immediately and NUI only after configured fade', function()
    local r = runtime()
    eq(r.exports.Finish(), true)
    eq(r.calls.engine, 1)
    eq(r.calls.nui, 0)
    eq(r.messages[1].eventName, 'void:shutdown')
    eq(r.messages[1].durationMs, 500)
    eq(r.tick(), 500)
    eq(r.calls.nui, 1)
end)

test('Repeated Finish is idempotent even before the fade timeout', function()
    local r = runtime()
    eq(r.exports.Finish(), true)
    eq(r.exports.Finish(), false)
    eq(#r.timers, 1)
    eq(#r.messages, 1)
    r.tick()
    eq(r.exports.Finish(), false)
    eq(r.calls.engine, 1)
    eq(r.calls.nui, 1)
end)

test('Auto mode delegates to VOID Characters and never closes on premature loaded events', function()
    local r = runtime('auto', true)
    for _, event in ipairs({'playerSpawned', 'esx:playerLoaded', 'QBCore:Client:OnPlayerLoaded'}) do r.events[event]() end
    eq(#r.timers, 0)
    eq(r.calls.engine, 0)
    eq(r.exports.Finish(), true, 'The owner can still finish explicitly')
end)

test('External mode waits for explicit integration on every framework', function()
    local r = runtime('external', false)
    for _, event in ipairs({'playerSpawned', 'esx:playerLoaded', 'QBCore:Client:OnPlayerLoaded'}) do r.events[event]() end
    eq(#r.timers, 0)
    eq(r.calls.engine, 0)
    eq(r.exports.Finish(), true)
end)

test('Standalone automatic spawn uses delay and coalesces duplicate framework events', function()
    local r = runtime('auto', false)
    r.events.playerSpawned()
    r.events['esx:playerLoaded']()
    r.events['QBCore:Client:OnPlayerLoaded']()
    eq(#r.timers, 1)
    eq(r.calls.engine, 0)
    eq(r.tick(), 50)
    eq(r.calls.engine, 1)
    eq(r.calls.nui, 0)
    r.tick()
    eq(r.calls.nui, 1)
end)

test('Automatic delayed close rechecks a selector that started after the spawn event', function()
    local r = runtime('auto', false)
    r.events.playerSpawned()
    r.resources.void_characters = 'started'
    r.tick()
    eq(r.calls.engine, 0)
    eq(#r.timers, 0)
    eq(r.exports.Finish(), true)
end)

test('Spawn mode explicitly overrides selector ownership', function()
    local r = runtime('spawn', true)
    r.events['QBCore:Client:OnPlayerLoaded']()
    r.tick()
    eq(r.calls.engine, 1)
    r.tick()
    eq(r.calls.nui, 1)
end)

test('Resource stop closes both layers immediately without waiting for discarded timers', function()
    local r = runtime('external', true)
    r.events.onResourceStop('another_resource')
    eq(r.calls.engine, 0)
    r.events.onResourceStop('void_loadscreen')
    eq(r.calls.engine, 1)
    eq(r.calls.nui, 1)
    eq(r.exports.Finish(), false)
end)

test('Client hydration sends the same public UI namespace without shutdown settings', function()
    local r = runtime()
    r.threads[1]()
    eq(r.messages[1].eventName, 'void:config')
    eq(r.messages[1].config.brand.name, 'VOID')
    eq(r.messages[1].config.playerName, 'Test Player')
    eq(r.messages[1].config.Shutdown, nil)
end)

test('Connecting handover preserves deferral ownership and scopes payload to VOID', function()
    local r = runtime()
    assert(loadfile('server.lua', 't', r.env))()
    local payload
    local deferrals = {
        handover = function(value) payload = value end,
        defer = function() error('This resource must not own connection deferrals') end,
        done = function() error('This resource must not finish another resource deferral') end
    }
    r.events.playerConnecting('Player Name', nil, deferrals)
    eq(payload.void_loadscreen.playerName, 'Player Name')
    eq(payload.void_loadscreen.brand.name, 'VOID')
    eq(payload.void_loadscreen.Shutdown, nil)
    local keys = 0
    for _ in pairs(payload) do keys = keys + 1 end
    eq(keys, 1, 'Do not overwrite unrelated handover keys')
end)

test('Public config is copied and cannot leak unrelated config fields', function()
    local r = runtime()
    r.env.Config.PrivateForTest = 'must not leak'
    r.env.Config.UI.UnrelatedForTest = 'must not leak'
    local result = r.env.VoidLoadscreen.publicConfig('Player')
    result.music.tracks[1].title = 'Changed externally'
    eq(r.env.Config.UI.music.tracks[1].title, 'VOID / SIGNAL 01')
    eq(result.PrivateForTest, nil)
    eq(result.UnrelatedForTest, nil)
end)

test('Player names honor privacy and UTF-8 length limits', function()
    local r = runtime()
    local result = r.env.VoidLoadscreen.publicConfig(string.rep('é', 100))
    eq(utf8.len(result.playerName), 64)
    eq(r.env.VoidLoadscreen.publicConfig(string.char(255)).playerName, nil)
    r.env.Config.ShowPlayerName = false
    eq(r.env.VoidLoadscreen.publicConfig('Hidden').playerName, nil)
end)

test('Invalid shutdown mode and nonfinite delay are rejected', function()
    local r = runtime()
    r.env.Config.Shutdown.Mode = 'invalid'
    eq(pcall(r.env.VoidLoadscreen.validate), false)
    r.env.Config.Shutdown.Mode = 'auto'
    r.env.Config.Shutdown.FadeMs = 0/0
    eq(pcall(r.env.VoidLoadscreen.validate), false)
    r.env.Config.Shutdown.FadeMs = 500
    r.env.Config.Shutdown.DelayMs = 10001
    eq(pcall(r.env.VoidLoadscreen.validate), false)
end)

print(('Lifecycle and handover: %d tests passed'):format(passed))

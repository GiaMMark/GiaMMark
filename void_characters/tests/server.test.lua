-- Run from void_characters: lua tests/server.test.lua (or texlua).
-- Exercises real callback/session code with deterministic framework/DB boundaries.
local root = (arg[0]:match('^(.*)/tests/[^/]+$') or '.')
local callbacks, events, players, buckets, characters, loaded = {}, {}, {}, {}, {}, {}
local now, passed = 10000, 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end

function vector3(x, y, z) return {x = x, y = y, z = z} end
function vector4(x, y, z, w) return {x = x, y = y, z = z, w = w} end
dofile(root .. '/config.lua')
dofile(root .. '/shared/identity.lua')
function GetPlayerName(id) return players[id] and 'Test player' end
function GetPlayers()
    local result = {}
    for id in pairs(players) do result[#result + 1] = tostring(id) end
    return result
end
function GetGameTimer() return now end
function Wait(ms) now = now + ms end
function GetPlayerRoutingBucket(id) return buckets[id] or 0 end
function SetPlayerRoutingBucket(id, bucket) buckets[id] = bucket end
function SetRoutingBucketPopulationEnabled() end
function SetRoutingBucketEntityLockdownMode() end
function GetCurrentResourceName() return 'void_characters' end
function AddEventHandler(name, handler) events[name] = handler end
local busyProbe, failureNextLogin, cleaned = nil, false, {}
local appearanceStored = true
VoidBridge = {
    name = 'esx', init = function() end,
    licenses = function(id) return players[id], nil end,
    owner = function(id) return players[id] end,
    baseIdentifier = function(id) return players[id]:gsub('license:', '') end,
    player = function(id) return loaded[id] end,
    playerId = function(id) return loaded[id] end,
    list = function(id)
        if busyProbe then local probe = busyProbe; busyProbe = nil; probe() end
        return characters[players[id]] or {}
    end,
    isOnline = function(characterId)
        for _, id in pairs(loaded) do if id == characterId then return true end end
        return false
    end,
    login = function(id, character, identity, slot)
        if failureNextLogin then failureNextLogin = false; return nil, 'Framework failure' end
        if character then loaded[id] = character.id; return character.id end
        local created = {
            id = 'char' .. slot .. ':' .. players[id], slot = slot,
            firstname = identity.firstname, lastname = identity.lastname, dateofbirth = identity.dateofbirth,
            sex = identity.sex, height = identity.height, nationality = identity.nationality
        }
        characters[players[id]] = characters[players[id]] or {}
        table.insert(characters[players[id]], created)
        loaded[id] = created.id
        return created.id
    end,
    remember = function() end,
    appearanceSaved = function() return appearanceStored end,
    cleanup = function(base, id) cleaned[id] = base end,
    delete = function(id, character)
        for index, row in ipairs(characters[players[id]]) do
            if row.id == character.id then table.remove(characters[players[id]], index); return true end
        end
        return false, 'not found'
    end
}
MySQL = { ready = function(fn) fn() end }
lib = { callback = { register = function(name, fn) callbacks[name] = fn end } }
dofile(root .. '/server/main.lua')
local function call(name, id, data, advance)
    now = now + (advance or 0)
    return callbacks['void_characters:' .. name](id, data)
end
local function connect(id, owner, previousBucket)
    players[id], buckets[id] = owner, previousBucket or 0
end
local function disconnect(id)
    source = id
    events.playerDropped()
    players[id], loaded[id] = nil, nil
end
local alice = {id = 'char1:alice', slot = 1, firstname = 'Alice', lastname = 'Rossi'}
connect(1, 'license:alice', 12)
characters['license:alice'] = {alice}
local result = call('list', 1)
check(result.ok and result.slots == 3 and result.characters[1].id == alice.id, 'list did not return owner characters/default slots')
check(buckets[1] == Config.Server.SelectionBucketBase + 1, 'selection not isolated')
check(not call('list', 1).ok, 'same-action cooldown bypassed')
check(not call('select', 1, {id = 'char1:someone_else'}).ok, 'forged character ownership accepted')
alice.disabled = true
check(not call('select', 1, {id = alice.id}, 1001).ok, 'admin-disabled character login accepted')
Config.AllowDelete = true
check(not call('delete', 1, {id = alice.id, confirmation = Config.DeleteConfirmation}).ok, 'admin-disabled character deletion accepted')
Config.AllowDelete = false
alice.disabled = false
check(not call('delete', 1, {id = alice.id, confirmation = Config.DeleteConfirmation}, 1001).ok, 'disabled deletion accepted')
check(not call('create', 1, {slot = 999}).ok, 'invalid slot accepted')
local invalid = {slot = 2, firstname = '<script>', lastname = 'Rossi', dateofbirth = '2000-01-01', sex = 'm', height = 175, nationality = 'Italiana'}
check(not call('create', 1, invalid, 1001).ok, 'invalid identity accepted')
local valid = {slot = 1, firstname = 'Marco', lastname = 'Rossi', dateofbirth = '2000-01-01', sex = 'm', height = 175, nationality = 'Italiana'}
check(not call('create', 1, valid, 1001).ok, 'occupied slot overwritten')
busyProbe = function()
    local nested = call('select', 1, {id = alice.id})
    check(not nested.ok and nested.error:find('corso'), 'concurrent callback was not locked')
end
check(call('list', 1, nil, 1001).ok, 'list failed during busy probe')
result = call('select', 1, {id = alice.id}, 1001)
check(result.ok and result.character.id == alice.id and not result.new, 'owner character login failed')
check(buckets[1] ~= 12, 'bucket released before appearance/spawn completion')
check(call('finished', 1).ok and buckets[1] == 12, 'immediate finished was throttled or bucket not restored')
check(call('finished', 1).ok and buckets[1] == 12, 'finished must be idempotent')
check(not call('select', 1, {id = alice.id}, 1001).ok, 'second login accepted after finished')
disconnect(1)
check(cleaned[1] == 'alice', 'drop did not clean framework selection alias')

-- A disconnected source releases the license lock for a later connection.
connect(2, 'license:alice', 14)
check(call('list', 2).ok, 'drop left owner lock behind')
check(not call('finished', 2).ok and buckets[2] ~= 14, 'unloaded session released isolation bucket')
connect(3, 'license:alice')
check(not call('list', 3).ok, 'parallel same-license session accepted')
disconnect(3)
failureNextLogin = true
check(not call('select', 2, {id = alice.id}).ok, 'framework login failure claimed success')
check(not call('select', 2, {id = alice.id}, 1001).ok, 'failed login could be resubmitted')
events.onResourceStop('void_characters')
check(buckets[2] == 14, 'resource stop did not restore selection bucket')
disconnect(2)

-- Slot overrides are server-derived and capped; valid new identities survive login.
connect(4, 'license:bob')
Config.Slots.IdentifierOverrides['license:bob'] = 999
check(call('list', 4).slots == Config.Slots.Max, 'slot override not capped')
valid.slot = 2
result = call('create', 4, valid)
check(result.ok and result.new and result.character.slot == 2 and result.character.firstname == 'Marco', 'valid character creation failed')
appearanceStored = false
check(not call('finished', 4).ok and buckets[4] ~= 0, 'unsaved appearance released isolation')
appearanceStored = true
check(call('finished', 4).ok, 'created character could not finish')
disconnect(4)

-- Mutations and their subsequent list refresh have independent throttles.
connect(5, 'license:alice')
Config.AllowDelete = true
check(not call('delete', 5, {id = alice.id, confirmation = 'wrong'}).ok, 'wrong delete confirmation accepted')
check(not call('delete', 5, {id = 'char1:other', confirmation = Config.DeleteConfirmation}, 1001).ok, 'delete ownership forgery accepted')
check(call('delete', 5, {id = alice.id, confirmation = Config.DeleteConfirmation}, 1001).ok, 'valid delete failed')
result = call('list', 5)
check(result.ok and #result.characters == 0, 'delete to list refresh throttled or stale')
disconnect(5)
print(('server: %s assertions passed'):format(passed))

-- Run from void_characters: lua tests/bridge.test.lua (or texlua).
-- Verifies exact adapter calls and database ownership boundaries without FXServer.
local root = (arg[0]:match('^(.*)/tests/[^/]+$') or '.')
local passed = 0
local function check(value, message) assert(value, message); passed = passed + 1 end
function vector3(x, y, z) return {x = x, y = y, z = z} end
function vector4(x, y, z, w) return {x = x, y = y, z = z, w = w} end
dofile(root .. '/config.lua')
local resources, calls, loaded, schemaRows, rows, metadata, appearance = {}, {}, {}, {}, {}, {}, nil
local now, deleted = 100, false
function GetResourceState(name) return resources[name] and 'started' or 'missing' end
function GetPlayerIdentifierByType(_, kind)
    return kind == 'license' and 'license:alice' or (kind == 'license2' and 'license2:alice' or nil)
end
function GetPlayerName(id) return id == 1 and 'Alice' or nil end
function GetPlayers() return {'1'} end
function GetGameTimer() return now end
function Wait(ms) now = now + ms end
json = {decode = function(value) if type(value) == 'table' then return value end; error('invalid JSON fixture') end}
local esx = {
    Players = {}, GetConfig = function() return {Multichar = true, Identity = true} end,
    GetIdentifier = function() return 'alice' end,
    GetPlayerFromId = function(id) return loaded[id] end
}
local function frameworkLogin(source, id, data)
    calls.login = {source = source, id = id, data = data}
    loaded[source] = {PlayerData = {citizenid = id or 'NEWCID'}}
    return true
end
local qb = {
    Functions = {GetPlayer = function(id) return loaded[id] end},
    Commands = {Refresh = function(id) calls.refreshed = id end},
    Player = {
        Login = frameworkLogin,
        DeleteCharacter = function(source, id) calls.deleted = {source, id}; deleted = true end
    }
}
exports = {
    es_extended = {getSharedObject = function() return esx end},
    ['qb-core'] = {GetCoreObject = function() return qb end},
    qbx_core = {
        GetPlayer = function(_, id) return loaded[id] end,
        Login = function(_, source, id, data) return frameworkLogin(source, id, data) end,
        DeleteCharacter = function(_, id) calls.deleted = {id}; deleted = true end
    }
}
function TriggerEvent(name, source, prefix, identity)
    calls.event = {name, source, prefix, identity}
    loaded[source] = {identifier = prefix .. ':alice'}
end
MySQL = {
    query = {await = function(query, params)
        calls.query, calls.params = query, params
        if query:find('INFORMATION_SCHEMA') then return schemaRows end
        if query:find('FROM void_characters_identity') then return metadata end
        return rows
    end},
    single = {await = function() return appearance end},
    scalar = {await = function(query)
        if query:find('SELECT skin') then return appearance and appearance.skin end
        if deleted then return nil end
        return 'EXISTING'
    end},
    update = {await = function(query, params) calls.update = {query = query, params = params}; return 1 end},
    transaction = {await = function(statements) calls.transaction = statements; return true end}
}
local tables = {
    users = {'identifier', 'firstname', 'lastname', 'dateofbirth', 'sex', 'height', 'skin'},
    players = {'citizenid', 'license', 'charinfo', 'money', 'job', 'position'},
    playerskins = {'citizenid', 'model', 'skin', 'active'},
    void_characters_identity = {'framework', 'character_id', 'owner', 'nationality', 'height'},
    owned_vehicles = {'owner'}
}
for tableName, columns in pairs(tables) do
    for _, column in ipairs(columns) do schemaRows[#schemaRows + 1] = {TABLE_NAME = tableName, COLUMN_NAME = column} end
end
local function init(framework)
    Config.Framework = framework
    resources = { [({esx = 'es_extended', qb = 'qb-core', qbox = 'qbx_core'})[framework]] = true }
    calls, loaded, rows, metadata, deleted, appearance = {}, {}, {}, {}, false, nil
    dofile(root .. '/server/bridge.lua')
    VoidBridge.init()
end
local identity = {firstname = 'Alice', lastname = 'Rossi', dateofbirth = '2000-02-29', sex = 'f', height = 172, nationality = 'Italiana'}
init('esx')
check(VoidBridge.name == 'esx' and VoidBridge.owner(1) == 'license:alice', 'ESX init/license mismatch')
rows = {
    {identifier = 'char1:alice', firstname = 'Alice', lastname = 'Rossi', dateofbirth = '29/02/2000', accounts = {bank = 100, money = 20}, disabled = 1},
    {identifier = 'char2:other_alice', firstname = 'Evil'},
    {identifier = 'char9:someone', firstname = 'Other'},
    {identifier = 'random:alice', firstname = 'No slot'}
}
metadata = {{character_id = 'char1:alice', nationality = 'Italiana', height = 172}}
local list = VoidBridge.list(1)
check(#list == 1 and list[1].id == 'char1:alice', 'ESX suffix/prefix ownership filter failed')
check(list[1].dateofbirth == '2000-02-29' and list[1].height == 172 and list[1].bank == 100, 'ESX identity/accounts metadata mapping failed')
check(list[1].disabled, 'ESX disabled status not preserved')
local id = VoidBridge.login(1, nil, identity, 2)
check(id == 'char2:alice' and calls.event[1] == 'esx:onPlayerJoined' and calls.event[3] == 'char2', 'ESX joined event/prefix mismatch')
check(calls.event[4].dateofbirth == '29/02/2000' and calls.event[4].sex == 'f', 'ESX identity payload format mismatch')
check(esx.Players.alice == 'char2', 'ESX duplicate-license registry not established')
VoidBridge.remember(1, id, identity)
check(calls.update.params[1] == 'esx' and calls.update.params[2] == id and calls.update.params[3] == 'license:alice', 'metadata owner/id bindings not server-derived')
check(not VoidBridge.appearanceSaved(1, id), 'missing appearance accepted')
appearance = {skin = {model = 'mp_f_freemode_01'}}
check(VoidBridge.appearanceSaved(1, id), 'persisted appearance not recognized')
loaded = {}
rows = {
    {identifier = 'char01:alice', firstname = 'Leading zero'},
    {identifier = 'char1:alice', firstname = 'Canonical'}
}
list = VoidBridge.list(1)
check(list[2].id == 'char1:alice' and list[2].slot == 2, 'legacy ESX duplicate display slot not normalized')
id = VoidBridge.login(1, list[2])
check(id == 'char1:alice' and calls.event[3] == 'char1', 'ESX remapped display slot loaded the wrong persisted identifier')
loaded = {}
Config.Server.ESXDeleteTables = {users = 'identifier', owned_vehicles = 'owner'}
check(VoidBridge.delete(1, {id = 'char2:alice'}), 'ESX delete transaction failed')
local statements = calls.transaction
check(#statements == 3 and statements[1].query:find('owned_vehicles') and statements[3].query == 'DELETE FROM users WHERE identifier = ?', 'ESX cleanup did not delete users last')
check(statements[1].values[1] == 'char2:alice' and statements[2].values[3] == 'license:alice', 'ESX delete bindings mismatch')
Config.Server.ESXDeleteTables = {users = 'identifier', ['users; DROP TABLE users'] = 'owner'}
check(not pcall(VoidBridge.delete, 1, {id = 'char2:alice'}), 'invalid SQL config identifier accepted')
Config.Server.ESXDeleteTables = {users = 'identifier'}
VoidBridge.cleanup('alice', 1)
check(esx.Players.alice == nil, 'ESX registry cleanup failed')

for _, framework in ipairs({'qb', 'qbox'}) do
    init(framework)
    id = VoidBridge.login(1, nil, identity, 3)
    check(id == 'NEWCID' and calls.login.source == 1 and not calls.login.id, framework .. ' new-character Login signature mismatch')
    check(calls.login.data.cid == 3 and calls.login.data.charinfo.cid == 3 and calls.login.data.charinfo.gender == 1, framework .. ' cid/gender data mismatch')
    check(calls.login.data.charinfo.birthdate == '2000-02-29' and calls.login.data.charinfo.nationality == 'Italiana', framework .. ' identity format mismatch')
    if framework == 'qb' then check(calls.refreshed == 1, 'QB command permissions were not refreshed') end
    loaded = {}
    id = VoidBridge.login(1, {id = 'OLDID', slot = 1})
    check(id == 'OLDID' and calls.login.id == 'OLDID' and calls.login.data == nil, framework .. ' existing-character Login signature mismatch')
    loaded = {}
    rows = {
        {citizenid = 'A', charinfo = {cid = 1, firstname = 'Alice'}, money = {cash = 20}, job = {label = 'Police'}},
        {citizenid = 'B', charinfo = {cid = 1, firstname = 'Bob'}},
        {citizenid = 'C', charinfo = {firstname = 'Carol'}}
    }
    appearance = {model = 'mp_f_freemode_01', skin = {components = {}}}
    list = VoidBridge.list(1)
    check(#list == 3 and list[1].slot == 1 and list[2].slot == 2 and list[3].slot == 3, framework .. ' missing/duplicate cid hides characters')
    check(list[1].appearance.model == 'mp_f_freemode_01' and list[1].cash == 20 and list[1].job == 'Police', framework .. ' skin/money/job mapping failed')
    check(VoidBridge.delete(1, {id = 'A'}), framework .. ' async official delete not confirmed')
    check(framework == 'qb' and calls.deleted[1] == 1 and calls.deleted[2] == 'A' or framework == 'qbox' and calls.deleted[1] == 'A', framework .. ' delete export signature mismatch')
end

init('esx')
Config.Framework = 'auto'
resources['qb-core'] = true
check(not pcall(VoidBridge.init), 'ambiguous auto framework accepted')
resources['qb-core'] = nil
Config.Server.ESXIdentifierPrefix = 'char.*'
check(not pcall(VoidBridge.init), 'unsafe prefix regex accepted')
Config.Server.ESXIdentifierPrefix = 'char'
local fullSchema = schemaRows
schemaRows = {}
for _, row in ipairs(fullSchema) do
    if not (row.TABLE_NAME == 'users' and row.COLUMN_NAME == 'skin') then schemaRows[#schemaRows + 1] = row end
end
check(not pcall(VoidBridge.init), 'ESX appearance provider without users.skin accepted')
schemaRows = fullSchema
init('qb')
schemaRows = {}
for _, row in ipairs(fullSchema) do
    if row.TABLE_NAME ~= 'playerskins' then schemaRows[#schemaRows + 1] = row end
end
check(not pcall(VoidBridge.init), 'QB illenium provider without playerskins accepted')
Config.Appearance.Provider = 'none'
check(pcall(VoidBridge.init), 'appearance none incorrectly requires playerskins')
schemaRows = fullSchema
Config.Appearance.Provider = 'illenium-appearance'
Config.Slots.Default = 0
check(not pcall(VoidBridge.init), 'invalid slot default accepted')
Config.Slots.Default = 3
schemaRows = {}
check(not pcall(VoidBridge.init), 'missing SQL installation accepted')
print(('bridge: %s assertions passed'):format(passed))

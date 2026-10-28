-- Framework-specific persistence stays here; clients never choose SQL identifiers.
VoidBridge = { name = nil }
local Bridge = VoidBridge
local ESX, QB, schema

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and type(result) == 'table' and result or fallback
end

local function isoDate(value)
    if type(value) ~= 'string' then return '' end
    local d, m, y = value:match('^(%d%d)/(%d%d)/(%d%d%d%d)$')
    return y and ('%s-%s-%s'):format(y, m, d) or value
end

local function esxDate(value)
    local y, m, d = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    return y and ('%s/%s/%s'):format(d, m, y) or value
end

function Bridge.licenses(source)
    local license = GetPlayerIdentifierByType(source, 'license')
    local license2 = GetPlayerIdentifierByType(source, 'license2')
    return license, license2
end

function Bridge.owner(source)
    local license, license2 = Bridge.licenses(source)
    return license or license2
end

function Bridge.player(source)
    if Bridge.name == 'esx' then return ESX.GetPlayerFromId(source) end
    if Bridge.name == 'qb' then return QB.Functions.GetPlayer(source) end
    if Bridge.name == 'qbox' then return exports.qbx_core:GetPlayer(source) end
end

function Bridge.playerId(source)
    local player = Bridge.player(source)
    if not player then return end
    return Bridge.name == 'esx' and player.identifier or player.PlayerData.citizenid
end

function Bridge.isOnline(id)
    for _, value in ipairs(GetPlayers()) do
        if Bridge.playerId(tonumber(value)) == id then return true end
    end
    return false
end

function Bridge.init()
    local requested = Config.Framework or 'auto'
    if requested == 'auto' then
        local hasESX = GetResourceState('es_extended') == 'started'
        local hasQB = GetResourceState('qb-core') == 'started'
        local hasQbox = GetResourceState('qbx_core') == 'started'
        assert(not (hasESX and (hasQB or hasQbox)), 'Più framework attivi: imposta Config.Framework esplicitamente e disattiva quello inutilizzato.')
        if GetResourceState('qbx_core') == 'started' then requested = 'qbox'
        elseif GetResourceState('es_extended') == 'started' then requested = 'esx'
        elseif GetResourceState('qb-core') == 'started' then requested = 'qb' end
    end
    local prefix = Config.Server.ESXIdentifierPrefix or 'char'
    assert(type(prefix) == 'string' and #prefix <= 12 and prefix:match('^[%a_][%w_]*$'), 'ESXIdentifierPrefix deve contenere solo lettere, numeri e underscore.')
    assert(type(Config.Slots.Max) == 'number' and Config.Slots.Max >= 1 and Config.Slots.Max % 1 == 0, 'Slots.Max deve essere un intero positivo.')
    assert(type(Config.Slots.Default) == 'number' and Config.Slots.Default >= 1 and Config.Slots.Default % 1 == 0 and Config.Slots.Default <= Config.Slots.Max, 'Slots.Default deve essere un intero compreso tra 1 e Slots.Max.')
    local resource = ({esx = 'es_extended', qb = 'qb-core', qbox = 'qbx_core'})[requested]
    assert(resource and GetResourceState(resource) == 'started', 'Avvia ESX, QBCore o Qbox prima di void_characters.')
    Bridge.name = requested
    if requested == 'esx' then
        ESX = exports.es_extended:getSharedObject()
        local config = ESX.GetConfig()
        assert(config.Multichar and config.Identity, 'ESX richiede Config.Multichar=true e Config.Identity=true in es_extended.')
    elseif requested == 'qb' then
        QB = exports['qb-core']:GetCoreObject()
    end
    schema = {}
    local columns = MySQL.query.await('SELECT TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE()')
    for _, row in ipairs(columns) do
        schema[row.TABLE_NAME] = schema[row.TABLE_NAME] or {}
        schema[row.TABLE_NAME][row.COLUMN_NAME] = true
    end
    for _, column in ipairs({'framework', 'character_id', 'owner', 'nationality', 'height'}) do
        assert(schema.void_characters_identity and schema.void_characters_identity[column], 'Importa void_characters/sql/schema.sql: manca void_characters_identity.' .. column)
    end
    if requested == 'esx' then
        for _, column in ipairs({'identifier', 'firstname', 'lastname', 'dateofbirth', 'sex', 'height'}) do
            assert(schema.users and schema.users[column], 'Manca users.' .. column .. ': importa lo schema ufficiale esx_identity.')
        end
        if Config.Appearance.Provider == 'illenium-appearance' or Config.Appearance.Provider == 'esx_skin' then
            assert(schema.users.skin, 'Manca users.skin: importa lo schema ufficiale di illenium-appearance/esx_skin prima di creare personaggi.')
        end
    else
        for _, column in ipairs({'citizenid', 'license', 'charinfo', 'money', 'job', 'position'}) do
            assert(schema.players and schema.players[column], 'Manca players.' .. column .. ': importa lo schema ufficiale del framework.')
        end
        assert(Config.Appearance.Provider ~= 'esx_skin', 'esx_skin è supportato solo con ESX.')
        if Config.Appearance.Provider == 'illenium-appearance' then
            for _, column in ipairs({'citizenid', 'model', 'skin', 'active'}) do
                assert(schema.playerskins and schema.playerskins[column], 'Importa lo schema ufficiale illenium-appearance: manca playerskins.' .. column)
            end
        elseif schema.playerskins then
            for _, column in ipairs({'citizenid', 'model', 'skin', 'active'}) do
                if not schema.playerskins[column] then schema.playerskins = nil; break end
            end
        end
    end
end

function Bridge.baseIdentifier(source)
    if Bridge.name == 'esx' then return ESX.GetIdentifier(source) end
    return Bridge.owner(source)
end

function Bridge.list(source)
    local rows
    if Bridge.name == 'esx' then
        -- Exact suffix checks below prevent LIKE wildcard characters matching another owner.
        local suffix = ':' .. Bridge.baseIdentifier(source)
        rows = MySQL.query.await('SELECT * FROM users WHERE identifier LIKE ?', {'%' .. suffix})
        local filtered, prefix = {}, Config.Server.ESXIdentifierPrefix or 'char'
        for _, row in ipairs(rows) do
            local slot = row.identifier:sub(1, -#suffix - 1):match('^' .. prefix .. '(%d+)$')
            if slot and row.identifier:sub(-#suffix) == suffix then
                row._slot = tonumber(slot)
                filtered[#filtered + 1] = row
            end
        end
        rows = filtered
    else
        local license, license2 = Bridge.licenses(source)
        rows = MySQL.query.await('SELECT * FROM players WHERE license IN (?, ?)', {license or '', license2 or license or ''})
    end

    local metadata = MySQL.query.await('SELECT character_id, nationality, height FROM void_characters_identity WHERE framework = ? AND owner = ?', {Bridge.name, Bridge.owner(source)})
    local byId = {}
    for _, row in ipairs(metadata) do byId[row.character_id] = row end
    local result = {}
    for _, row in ipairs(rows) do
        local character, id
        if Bridge.name == 'esx' then
            id = row.identifier
            local accounts = decode(row.accounts, {})
            character = {
                id = id, slot = row._slot, firstname = row.firstname or '', lastname = row.lastname or '',
                dateofbirth = isoDate(row.dateofbirth), sex = row.sex == 'f' and 'f' or 'm', height = row.height,
                disabled = row.disabled == true or row.disabled == 1 or row.disabled == '1',
                job = row.job or 'unemployed', bank = accounts.bank or 0, cash = accounts.money or 0,
                position = decode(row.position), appearance = decode(row.skin)
            }
        else
            id = row.citizenid
            local info, money, job = decode(row.charinfo, {}), decode(row.money, {}), decode(row.job, {})
            character = {
                id = id, slot = tonumber(info.cid or row.cid), firstname = info.firstname or '', lastname = info.lastname or '',
                dateofbirth = isoDate(info.birthdate), sex = tonumber(info.gender) == 1 and 'f' or 'm', height = info.height,
                nationality = info.nationality, job = job.label or job.name or 'unemployed',
                bank = money.bank or 0, cash = money.cash or 0, position = decode(row.position)
            }
            if schema.playerskins then
                local skin = MySQL.single.await('SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', {id})
                if skin then
                    character.appearance = decode(skin.skin)
                    if character.appearance and not character.appearance.model then character.appearance.model = skin.model end
                end
            end
        end
        local extra = byId[id]
        character.nationality = extra and extra.nationality or character.nationality or Config.Identity.Nationalities[1]
        character.height = extra and extra.height or character.height or 175
        result[#result + 1] = character
    end
    -- Older QB saves may omit cid or contain duplicate cids. Give these entries a
    -- stable display slot without rewriting framework data or hiding a character.
    table.sort(result, function(a, b)
        if (a.slot or math.huge) == (b.slot or math.huge) then return a.id < b.id end
        return (a.slot or math.huge) < (b.slot or math.huge)
    end)
    local occupied, unmapped = {}, {}
    for _, character in ipairs(result) do
        local slot = character.slot
        if slot and slot >= 1 and slot % 1 == 0 and not occupied[slot] then occupied[slot] = true
        else unmapped[#unmapped + 1] = character end
    end
    local nextSlot = 1
    for _, character in ipairs(unmapped) do
        while occupied[nextSlot] do nextSlot = nextSlot + 1 end
        character.slot, occupied[nextSlot] = nextSlot, true
    end
    table.sort(result, function(a, b) return a.slot < b.slot end)
    return result
end

local function awaitPlayer(source)
    local expires = GetGameTimer() + (Config.Server.LoginTimeout or 20) * 1000
    while GetGameTimer() < expires and GetPlayerName(source) do
        local player = Bridge.player(source)
        if player then return player end
        Wait(50)
    end
end

function Bridge.login(source, character, identity, slot)
    if Bridge.player(source) then return nil, 'Un personaggio è già caricato.' end
    if Bridge.name == 'esx' then
        local base, prefix = Bridge.baseIdentifier(source), Config.Server.ESXIdentifierPrefix or 'char'
        local charIdentifier
        if identity then
            charIdentifier = prefix .. tostring(slot)
        else
            -- Display slots can be normalized for legacy duplicate cids. ESX must
            -- always load the exact stored prefix (e.g. char01), never that label.
            local suffix = ':' .. base
            if not character or type(character.id) ~= 'string' or character.id:sub(-#suffix) ~= suffix then
                return nil, 'Identificativo del personaggio non valido.'
            end
            charIdentifier = character.id:sub(1, -#suffix - 1)
            if not charIdentifier:match('^' .. prefix .. '%d+$') then return nil, 'Prefisso del personaggio non valido.' end
        end
        ESX.Players[base] = charIdentifier
        local data
        if identity then
            data = {
                firstname = identity.firstname, lastname = identity.lastname,
                dateofbirth = esxDate(identity.dateofbirth), sex = identity.sex, height = identity.height
            }
        end
        TriggerEvent('esx:onPlayerJoined', source, charIdentifier, data)
    else
        local data
        if identity then
            data = {
                cid = slot,
                charinfo = {
                    cid = slot, firstname = identity.firstname, lastname = identity.lastname,
                    birthdate = identity.dateofbirth, gender = identity.sex == 'f' and 1 or 0,
                    height = identity.height, nationality = identity.nationality
                }
            }
        end
        local ok
        if Bridge.name == 'qb' then
            ok = QB.Player.Login(source, character and character.id or false, data)
            if ok then QB.Commands.Refresh(source) end
        else
            ok = exports.qbx_core:Login(source, character and character.id or nil, data)
        end
        if not ok then return nil, 'Il framework ha rifiutato il caricamento del personaggio.' end
    end
    local player = awaitPlayer(source)
    if not player then return nil, 'Tempo di caricamento scaduto. Controlla i log del framework e riconnettiti.' end
    return Bridge.playerId(source)
end

function Bridge.remember(source, id, identity)
    MySQL.update.await([[
        INSERT INTO void_characters_identity (framework, character_id, owner, nationality, height)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE owner = VALUES(owner), nationality = VALUES(nationality), height = VALUES(height)
    ]], {Bridge.name, id, Bridge.owner(source), identity.nationality, identity.height})
end

function Bridge.appearanceSaved(source, id)
    if Bridge.playerId(source) ~= id then return false end
    local value
    if Bridge.name == 'esx' then
        if not schema.users.skin then return false end
        value = MySQL.scalar.await('SELECT skin FROM users WHERE identifier = ?', {id})
    else
        if not schema.playerskins then return false end
        value = MySQL.scalar.await('SELECT skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', {id})
    end
    local appearance = decode(value)
    return appearance ~= nil and next(appearance) ~= nil
end

function Bridge.cleanup(base, source)
    if Bridge.name == 'esx' and base and ESX.Players[base] then
        local value = ESX.Players[base]
        if value == source or type(value) == 'string' then ESX.Players[base] = nil end
    end
end

function Bridge.delete(source, character)
    if Bridge.isOnline(character.id) then return false, 'Questo personaggio è attualmente connesso.' end
    if Bridge.name == 'esx' then
        local statements = {}
        local configured = Config.Server.ESXDeleteTables or {users = 'identifier'}
        assert(configured.users == 'identifier', 'ESXDeleteTables deve includere users = identifier.')
        for tableName, column in pairs(configured) do
            assert(type(tableName) == 'string' and tableName:match('^[%w_]+$') and type(column) == 'string' and column:match('^[%w_]+$'), 'Nome tabella/colonna ESXDeleteTables non valido.')
            assert(schema[tableName] and schema[tableName][column], 'ESXDeleteTables contiene una tabella/colonna inesistente: ' .. tableName)
            if tableName ~= 'users' then
                statements[#statements + 1] = {query = ('DELETE FROM `%s` WHERE `%s` = ?'):format(tableName, column), values = {character.id}}
            end
        end
        statements[#statements + 1] = {query = 'DELETE FROM void_characters_identity WHERE framework = ? AND character_id = ? AND owner = ?', values = {Bridge.name, character.id, Bridge.owner(source)}}
        statements[#statements + 1] = {query = 'DELETE FROM users WHERE identifier = ?', values = {character.id}}
        if not MySQL.transaction.await(statements) then return false, 'Eliminazione non riuscita: transazione annullata.' end
    else
        if Bridge.name == 'qb' then QB.Player.DeleteCharacter(source, character.id)
        else exports.qbx_core:DeleteCharacter(character.id) end
        local expires = GetGameTimer() + 10000
        repeat
            if not MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ?', {character.id}) then
                MySQL.update.await('DELETE FROM void_characters_identity WHERE framework = ? AND character_id = ? AND owner = ?', {Bridge.name, character.id, Bridge.owner(source)})
                return true
            end
            Wait(100)
        until GetGameTimer() >= expires
        return false, 'Eliminazione non confermata dal framework. Controlla i log e ricarica la lista.'
    end
    return true
end

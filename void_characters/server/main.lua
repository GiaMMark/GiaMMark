local sessions, owners, cooldowns = {}, {}, {}
local ready, startupError = false, 'Ambiente non ancora inizializzato.'

MySQL.ready(function()
    local ok, err = pcall(VoidBridge.init)
    ready = ok
    if not ok then
        startupError = 'Configurazione incompleta: controlla la console del server.'
        print(('[void_characters] AVVIO BLOCCATO: %s'):format(err))
    else
        print(('[void_characters] Framework %s pronto. Eliminazione: %s.'):format(VoidBridge.name, Config.AllowDelete and 'abilitata' or 'disabilitata'))
    end
end)

local function failure(message) return {ok = false, error = message} end

local function allowedSlots(source)
    local license, license2 = VoidBridge.licenses(source)
    local overrides = Config.Slots.IdentifierOverrides or {}
    local count = tonumber(overrides[license] or overrides[license2] or Config.Slots.Default) or 1
    return math.max(1, math.min(math.floor(count), Config.Slots.Max or 5))
end

local function current(source, session)
    return sessions[source] == session and GetPlayerName(source) and VoidBridge.owner(source) == session.owner
end

local function ensureSession(source)
    local session = sessions[source]
    if session then
        if session.phase ~= 'selecting' then return nil, 'Selezione già completata.' end
        return session
    end
    if VoidBridge.player(source) then return nil, 'Un personaggio è già caricato. Riconnettiti per cambiare personaggio.' end
    local owner = VoidBridge.owner(source)
    if not owner then return nil, 'Licenza Rockstar non disponibile. Riconnettiti.' end
    if owners[owner] and owners[owner] ~= source then return nil, 'Questa licenza ha già una sessione attiva.' end
    local license, license2 = VoidBridge.licenses(source)
    for _, other in ipairs(GetPlayers()) do
        other = tonumber(other)
        if other ~= source then
            local first, second = VoidBridge.licenses(other)
            if (first and (first == license or first == license2)) or (second and (second == license or second == license2)) then
                return nil, 'Questa licenza è già connessa al server.'
            end
        end
    end
    session = {owner = owner, base = VoidBridge.baseIdentifier(source), phase = 'selecting', previousBucket = GetPlayerRoutingBucket(source)}
    sessions[source], owners[owner] = session, source
    local bucket = (Config.Server.SelectionBucketBase or 6000) + source
    SetRoutingBucketPopulationEnabled(bucket, false)
    SetRoutingBucketEntityLockdownMode(bucket, 'strict')
    SetPlayerRoutingBucket(source, bucket)
    return session
end

local function ownedCharacter(source, id)
    if type(id) ~= 'string' or #id > 100 then return end
    for _, character in ipairs(VoidBridge.list(source)) do
        if character.id == id then return character end
    end
end

local function register(name, action)
    lib.callback.register('void_characters:' .. name, function(source, data)
        if not ready then return failure(startupError) end
        local session = sessions[source]
        if session and session.busy then return failure('Operazione già in corso.') end
        if name ~= 'finished' then
            local now = GetGameTimer()
            cooldowns[source] = cooldowns[source] or {}
            local previous = cooldowns[source][name]
            if previous and now - previous < (Config.Server.RateLimitMs or 750) then
                return failure('Attendi un istante prima di riprovare.')
            end
            cooldowns[source][name] = now
        end
        local err
        if name ~= 'finished' then session, err = ensureSession(source) end
        if not session then return failure(err or 'Sessione non valida.') end
        session.busy = true
        local ok, result = pcall(action, source, type(data) == 'table' and data or {}, session)
        session.busy = false
        if not ok then
            print(('[void_characters] %s non riuscito: %s'):format(name, result))
            return failure('Operazione non riuscita. Controlla la console del server.')
        end
        if not current(source, session) then return failure('Sessione scaduta.') end
        return result
    end)
end

register('list', function(source)
    return {ok = true, characters = VoidBridge.list(source), slots = allowedSlots(source), allowDelete = Config.AllowDelete == true, framework = VoidBridge.name}
end)

local function login(source, session, character, identity, slot)
    session.phase = 'loading'
    local id, err = VoidBridge.login(source, character, identity, slot)
    if not current(source, session) then return failure('Sessione scaduta.') end
    if not id then
        -- A timed-out framework login must never be submitted a second time.
        session.phase = 'failed'
        return failure(err)
    end
    session.phase, session.character = 'loaded', id
    if identity then
        local ok, metadataError = pcall(VoidBridge.remember, source, id, identity)
        if not ok then print(('[void_characters] Personaggio creato ma metadati non salvati: %s'):format(metadataError)) end
    end
    local selected = ownedCharacter(source, id) or character
    if not selected then
        -- QBCore may persist the first save asynchronously; use server-generated ID/validated identity.
        selected = {id = id, slot = slot, firstname = identity.firstname, lastname = identity.lastname, dateofbirth = identity.dateofbirth, sex = identity.sex, height = identity.height, nationality = identity.nationality}
    end
    session.needsAppearance = identity ~= nil or type(selected.appearance) ~= 'table' or next(selected.appearance) == nil
    return {ok = true, new = identity ~= nil, character = selected, framework = VoidBridge.name}
end

register('select', function(source, data, session)
    local character = ownedCharacter(source, data.id)
    if not character then return failure('Personaggio non disponibile per questa licenza.') end
    if character.disabled then return failure('Questo personaggio è stato disabilitato dall’amministrazione.') end
    if VoidBridge.isOnline(character.id) then return failure('Questo personaggio è già connesso.') end
    return login(source, session, character)
end)

register('create', function(source, data, session)
    local slot = tonumber(data.slot)
    if not slot or slot % 1 ~= 0 or slot < 1 or slot > allowedSlots(source) then return failure('Slot non disponibile.') end
    local characters = VoidBridge.list(source)
    if #characters >= allowedSlots(source) then return failure('Hai raggiunto il limite dei personaggi.') end
    for _, character in ipairs(characters) do
        if character.slot == slot then return failure('Questo slot è già occupato.') end
    end
    local identity, err = VoidIdentity.validate(data)
    if not identity then return failure(err) end
    return login(source, session, nil, identity, slot)
end)

register('delete', function(source, data)
    if Config.AllowDelete ~= true then return failure('Eliminazione dei personaggi disabilitata.') end
    if type(data.confirmation) ~= 'string' or data.confirmation ~= Config.DeleteConfirmation then return failure('Conferma di eliminazione non valida.') end
    local character = ownedCharacter(source, data.id)
    if not character then return failure('Personaggio non disponibile per questa licenza.') end
    if character.disabled then return failure('Un personaggio disabilitato può essere eliminato solo dall’amministrazione.') end
    local ok, err = VoidBridge.delete(source, character)
    return ok and {ok = true} or failure(err)
end)

register('finished', function(source, _, session)
    if session.phase == 'playing' then return {ok = true} end
    if session.phase ~= 'loaded' or VoidBridge.playerId(source) ~= session.character then return failure('Il framework non ha completato il caricamento.') end
    local provider = Config.Appearance.Provider
    if session.needsAppearance and (provider == 'illenium-appearance' or provider == 'esx_skin') then
        local expires = GetGameTimer() + (Config.Server.LoginTimeout or 20) * 1000
        while not VoidBridge.appearanceSaved(source, session.character) do
            if GetGameTimer() >= expires or not current(source, session) then
                return failure('Aspetto non ancora salvato. Riprova dopo il salvataggio e controlla la configurazione del tuo appearance.')
            end
            Wait(100)
        end
    end
    if not current(source, session) then return failure('Sessione scaduta.') end
    SetPlayerRoutingBucket(source, session.previousBucket)
    session.phase = 'playing'
    return {ok = true}
end)

AddEventHandler('playerDropped', function()
    local player, session = source, sessions[source]
    if session then
        VoidBridge.cleanup(session.base, player)
        if owners[session.owner] == player then owners[session.owner] = nil end
    end
    sessions[player], cooldowns[player] = nil, nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for player, session in pairs(sessions) do
        if GetPlayerName(player) and session.phase ~= 'playing' then
            SetPlayerRoutingBucket(player, session.previousBucket)
            VoidBridge.cleanup(session.base, player)
        end
    end
end)

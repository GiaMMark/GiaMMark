-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function decodeJsonObject(value, fallback)
    if type(value) == 'table' then
        return value
    end

    if type(value) ~= 'string' or value == '' then
        return fallback
    end

    local ok, decoded = pcall(json.decode, value)

    if not ok or type(decoded) ~= 'table' then
        return fallback
    end

    return decoded
end

local function failVoidCurrencyLoad(playerId, errorCode)
    print(('[^1ERROR^7] Void currency load blocked for player ID ^5%s^7: ^5%s^7'):format(playerId, errorCode))
    local explanation
    if errorCode == 'ox-void-adapter-missing' then
        explanation = 'Manca l\'adattatore Void richiesto in ox_inventory.'
    elseif errorCode == 'ox-void-adapter-not-ready' then
        explanation = 'L\'adattatore Void di ox_inventory non e ancora pronto. Nessun saldo e stato modificato.'
    elseif errorCode == 'custom-inventory-conversion-required' then
        explanation = 'La conversione dei vecchi black_money richiede un adattatore per il tuo inventario personalizzato.'
    else
        explanation = 'I saldi o l\'inventario del personaggio non sono validi. Nessun dato e stato modificato.'
    end
    return DropPlayer(playerId, ('Impossibile caricare la valuta Void.\nCodice: %s\n%s\nContatta lo staff del server.'):format(errorCode, explanation))
end

local function loadPlayer(identifier, playerId, isNew, loading)
    if not Core.PlayerSession.IsPlayerLoadActive(playerId, loading) then
        return
    end

    if Config.CustomInventory == 'ox' then
        local markerOk, marker = pcall(function()
            return GetResourceMetadata('ox_inventory', 'void_currency', 0)
        end)
        if not markerOk or marker ~= '1.0.0' then
            return failVoidCurrencyLoad(playerId, 'ox-void-adapter-missing')
        end
        local readyOk, ready = pcall(function()
            return exports.ox_inventory:IsVoidCurrencyReady()
        end)
        if not readyOk or ready ~= true then
            return failVoidCurrencyLoad(playerId, 'ox-void-adapter-not-ready')
        end
    end

    local userData = {
        accounts = {},
        inventory = {},
        loadout = {},
        weight = 0,
        name = GetPlayerName(playerId),
        identifier = identifier,
        firstName = 'John',
        lastName = 'Doe',
        dateofbirth = '01/01/2000',
        height = 120,
        dead = false,
    }

    local result = MySQL.prepare.await(Core.PlayerSession.loadPlayerQuery, { identifier })

    if not Core.PlayerSession.IsPlayerLoadActive(playerId, loading) then
        return
    end

    if not result then
        print(('[^1ERROR^7] esx_core could not load data for identifier ^5%s^7'):format(identifier))
        return DropPlayer(
            playerId --[[@as string]],
            'There was an error loading your character!\nError code: data-load-failed\n\nYour character data could not be retrieved. Please reconnect, and contact the server administration team if this keeps happening.'
        )
    end

    -- Never continue with partial or corrupt balances: the next autosave would
    -- otherwise overwrite the original account data in the database.
    local savedAccounts = result.accounts
    local accounts, accountError
    if savedAccounts == nil or savedAccounts == '' then
        accounts = {}
    elseif type(savedAccounts) == 'table' then
        accounts = savedAccounts
    elseif type(savedAccounts) == 'string' and savedAccounts:match('^%s*{') then
        local ok, decoded = pcall(json.decode, savedAccounts)
        if ok and type(decoded) == 'table' then
            accounts = decoded
        else
            accountError = 'invalid-accounts-json'
        end
    else
        accountError = 'invalid-accounts-json'
    end

    local convertedOxInventory
    if not accountError and Config.CustomInventory == 'ox' then
        local savedInventory, inventory = result.inventory
        if savedInventory == nil or savedInventory == '' then
            inventory = {}
        elseif type(savedInventory) == 'table' then
            inventory = savedInventory
        elseif type(savedInventory) == 'string' then
            local firstCharacter = savedInventory:match('^%s*(.)')
            if firstCharacter == '[' or firstCharacter == '{' then
                local ok, decoded = pcall(json.decode, savedInventory)
                if ok and type(decoded) == 'table' then inventory = decoded end
            end
        end
        if inventory then
            accounts, convertedOxInventory, accountError = Core.NormalizeVoidOxAccounts(accounts, inventory)
        else
            accountError = 'invalid-ox-inventory-json'
        end
    elseif not accountError then
        accounts, accountError = Core.NormalizeVoidAccounts(accounts)
    end

    if accountError then
        return failVoidCurrencyLoad(playerId, accountError)
    end

    for account, data in pairs(Config.Accounts) do
        data.round = data.round or data.round == nil

        local index = #userData.accounts + 1

        userData.accounts[index] = {
            name = account,
            money = accounts[account] or Config.StartingAccountMoney[account] or 0,
            label = data.label,
            round = data.round,
            index = index,
        }
    end

    userData.ssn = result.ssn

    local job, grade = result.job, tostring(result.job_grade)

    if not ESX.DoesJobExist(job, grade) then
        print(('[^3WARNING^7] Ignoring invalid job for ^5%s^7 [job: ^5%s^7, grade: ^5%s^7]'):format(identifier, job, grade))
        job, grade = 'unemployed', '0'
    end

    local jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]

    userData.job = {
        id = jobObject.id,
        name = jobObject.name,
        label = jobObject.label,
        type = jobObject.type,

        grade = tonumber(grade),
        grade_name = gradeObject.name,
        grade_label = gradeObject.label,
        grade_salary = gradeObject.salary,

        skin_male = decodeJsonObject(gradeObject.skin_male, {}),
        skin_female = decodeJsonObject(gradeObject.skin_female, {}),
    }

    if not Config.CustomInventory then
        local inventory = decodeJsonObject(result.inventory, {})

        userData.inventory, userData.weight = Core.PlayerClass.BuildInventory(inventory)
    elseif Config.CustomInventory == 'ox' then
        userData.inventory = convertedOxInventory
    elseif result.inventory and result.inventory ~= '' then
        userData.inventory = json.decode(result.inventory)
    end

    if result.group then
        if result.group == 'superadmin' then
            userData.group = 'admin'
            print('[^3WARNING^7] ^5Superadmin^7 detected, setting group to ^5admin^7')
        else
            userData.group = result.group
        end
    else
        userData.group = 'user'
    end

    if not Config.CustomInventory and result.loadout and result.loadout ~= '' then
        local loadout = json.decode(result.loadout)

        for name, weapon in pairs(loadout) do
            local found, label = pcall(ESX.GetWeaponLabel, name)

            if found and label then
                userData.loadout[#userData.loadout + 1] = {
                    name = name,
                    ammo = weapon.ammo,
                    label = label,
                    components = weapon.components or {},
                    tintIndex = weapon.tintIndex or 0,
                }
            end
        end
    end

    local coordinates = decodeJsonObject(result.position)

    if not Core.PlayerClass.IsValidCoordinates(coordinates) then
        coordinates = Core.PlayerClass.GetDefaultCoordinates()

        if not coordinates then
            print(('[^1ERROR^7] No valid Config.DefaultSpawns for player ^5%s^7'):format(identifier))
            return DropPlayer(playerId, 'There was an error loading your character!\nError code: invalid-spawn-config\n\nContact the server administration team.')
        end

        if result.position and result.position ~= '' then
            print(('[^3WARNING^7] Invalid saved position for ^5%s^7; using a configured spawn.'):format(identifier))
        end
    end

    userData.coords = {
        x = coordinates.x,
        y = coordinates.y,
        z = coordinates.z,
        heading = coordinates.w or coordinates.heading or 0.0,
    }
    userData.skin = decodeJsonObject(result.skin, { sex = result.sex == 'f' and 1 or 0 })
    userData.metadata = (result.metadata and result.metadata ~= '') and json.decode(result.metadata) or {}

    local xPlayer = CreateExtendedPlayer(
        playerId,
        identifier,
        userData.ssn,
        userData.group,
        userData.accounts,
        userData.inventory,
        userData.weight,
        userData.job,
        userData.loadout,
        GetPlayerName(playerId),
        userData.coords,
        userData.metadata
    )

    GlobalState['playerCount'] = (GlobalState['playerCount'] or 0) + 1
    ESX.Players[playerId] = xPlayer
    Core.playersByIdentifier[identifier] = xPlayer

    if result.firstname and result.firstname ~= '' then
        userData.firstName = result.firstname
        userData.lastName = result.lastname

        local name = ('%s %s'):format(result.firstname, result.lastname)

        userData.name = name

        xPlayer.set('firstName', result.firstname)
        xPlayer.set('lastName', result.lastname)
        xPlayer.setName(name)

        if result.dateofbirth then
            userData.dateofbirth = result.dateofbirth
            xPlayer.set('dateofbirth', result.dateofbirth)
        end

        if result.sex then
            userData.sex = result.sex
            xPlayer.set('sex', result.sex)
        end

        if result.height then
            userData.height = result.height
            xPlayer.set('height', result.height)
        end
    end

    TriggerEvent('esx:playerLoaded', playerId, xPlayer, isNew)
    userData.money = xPlayer.getMoney()
    userData.maxWeight = xPlayer.getMaxWeight()
    userData.variables = xPlayer.variables or {}

    if not Config.CustomInventory then
        userData.inventory = xPlayer.getInventory()
        userData.weight = xPlayer.getWeight()
    end

    xPlayer.triggerEvent('esx:playerLoaded', userData, isNew, userData.skin)

    if Config.CustomInventory and setPlayerInventory then
        setPlayerInventory(playerId, xPlayer, userData.inventory, isNew)
    end

    xPlayer.triggerEvent('esx:registerSuggestions', Core.RegisteredCommands)
    print(('[^2INFO^0] Player ^5"%s"^0 has connected to the server. ID: ^5%s^7'):format(xPlayer.getName(), playerId))
end

function loadESXPlayer(identifier, playerId, isNew, loading)
    return Core.WithPlayerPersistence(identifier, function(existing)
        if existing then
            return DropPlayer(playerId, 'There is already an active session for this character.')
        end

        return loadPlayer(identifier, playerId, isNew, loading)
    end)
end

Core.PlayerSession.LoadESXPlayer = loadESXPlayer

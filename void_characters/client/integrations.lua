VoidIntegrations = {}
local I = VoidIntegrations

function I.notify(message, kind)
    local provider = Config.Notifications.Provider
    if provider == 'esx' and GetResourceState('es_extended') == 'started' then
        exports.es_extended:getSharedObject().ShowNotification(message, kind or 'info')
    elseif provider == 'qb' and GetResourceState('qb-core') == 'started' then
        exports['qb-core']:GetCoreObject().Functions.Notify(message, kind or 'primary')
    elseif provider == 'custom' then
        Config.Notifications.Custom(message, kind or 'inform')
    else
        lib.notify({title = Config.Brand.Name, description = message, type = kind or 'inform'})
    end
end

function I.showText(text)
    if Config.TextUI.Provider == 'ox_lib' then
        lib.showTextUI(text, {position = Config.TextUI.Position})
    elseif Config.TextUI.Provider == 'custom' then
        Config.TextUI.CustomShow(text)
    end
end

function I.hideText()
    if Config.TextUI.Provider == 'ox_lib' then lib.hideTextUI()
    elseif Config.TextUI.Provider == 'custom' then Config.TextUI.CustomHide() end
end

function I.preflight(framework)
    local provider = Config.Appearance.Provider
    if provider == 'illenium-appearance' and GetResourceState(provider) ~= 'started' then
        return false, 'Avvia illenium-appearance prima di entrare, oppure cambia Config.Appearance.Provider.'
    elseif provider == 'esx_skin' then
        if framework ~= 'esx' then return false, 'esx_skin richiede ESX. Scegli un altro provider aspetto.' end
        if GetResourceState('esx_skin') ~= 'started' or GetResourceState('skinchanger') ~= 'started' then
            return false, 'Avvia esx_skin e skinchanger, oppure cambia il provider aspetto.'
        end
    elseif provider ~= 'illenium-appearance' and provider ~= 'custom' and provider ~= 'none' then
        return false, 'Config.Appearance.Provider non riconosciuto.'
    end
    if Config.Spawn.Provider ~= 'direct' and Config.Spawn.Provider ~= 'custom' then
        return false, 'Config.Spawn.Provider non riconosciuto.'
    end
    return true
end

function I.setModel(character)
    local appearance = character and character.appearance
    local model = appearance and appearance.model
        or (character and character.sex == 'f' and Config.Scene.FemaleModel or Config.Scene.MaleModel)
    model = tonumber(model) or joaat(model)
    if not IsModelInCdimage(model) or not IsModelAPed(model) then
        model = joaat(Config.Scene.MaleModel)
    end
    lib.requestModel(model, 10000)
    local changed = GetEntityModel(PlayerPedId()) ~= model
    if changed then SetPlayerModel(PlayerId(), model) end
    SetModelAsNoLongerNeeded(model)
    if changed or not appearance then SetPedDefaultComponentVariation(PlayerPedId()) end
end

function I.applyAppearance(character)
    I.setModel(character)
    local appearance = character and character.appearance
    if not appearance then return end
    if Config.Appearance.Provider == 'illenium-appearance' then
        -- The model is already loaded. Avoid resetting the player ped twice.
        exports['illenium-appearance']:setPedAppearance(PlayerPedId(), appearance)
    elseif Config.Appearance.Provider == 'esx_skin' then
        local done = promise.new()
        TriggerEvent('skinchanger:loadSkin', appearance, function() done:resolve(true) end)
        Citizen.Await(done)
    end
end

-- Reuse the same notification/textUI adapters from the rest of the VOID pack.
exports('Notify', I.notify)
exports('ShowTextUI', I.showText)
exports('HideTextUI', I.hideText)

function I.createAppearance(context)
    local done, resolved = promise.new(), false
    local function finish(ok)
        if resolved then return end
        resolved = true
        done:resolve(ok == true)
    end
    local provider = Config.Appearance.Provider
    if provider == 'none' then return true end
    if provider == 'illenium-appearance' then
        local options = {}
        for key, value in pairs(Config.Appearance.Creator) do options[key] = value end
        options.enableExit = false
        exports['illenium-appearance']:startPlayerCustomization(function(appearance)
            if appearance then
                TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
                finish(true)
            else finish(false) end
        end, options)
    elseif provider == 'esx_skin' then
        -- skinchanger maintains its own sex/model state independently of the ped.
        local skinLoaded = promise.new()
        TriggerEvent('skinchanger:loadSkin', {sex = context.character.sex == 'f' and 1 or 0}, function()
            skinLoaded:resolve(true)
        end)
        Citizen.Await(skinLoaded)
        TriggerEvent('esx_skin:openSaveableMenu', function() finish(true) end, function() finish(false) end)
    elseif provider == 'custom' then
        Config.Appearance.Custom(context, finish)
    else
        return false
    end
    return Citizen.Await(done)
end

function I.frameworkLoaded(framework)
    if framework == 'esx' then
        local esx = exports.es_extended:getSharedObject()
        esx.SetPlayerData('ped', PlayerPedId())
        TriggerEvent('esx:onPlayerSpawn')
        TriggerServerEvent('esx:onPlayerSpawn')
        TriggerEvent('esx:restoreLoadout')
        TriggerEvent('esx:loadingScreenOff')
    else
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerEvent('QBCore:Client:OnPlayerLoaded')
    end
    -- Inventories use their own framework hooks. Do not re-grant starter items.
end

function I.isLoaded()
    if LocalPlayer.state.isLoggedIn then return true end
    if GetResourceState('es_extended') == 'started' then
        return exports.es_extended:getSharedObject().IsPlayerLoaded()
    end
    if GetResourceState('qb-core') == 'started' then
        local data = exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
        return data and data.citizenid ~= nil
    end
    return false
end

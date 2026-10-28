-- Additive same-resource bridge: no server/storage or inventory authority here.
local config = VoidInventoryConfig
local preview = config.Preview
local clone, camera, sourcePed, sourceModel, origin, cloneHeading
local wasOpen, attempted, nextStatus = false, false, 0
local savedBlur, blurOwner

if preview.Enabled and preview.DisableNativeBlur and type(client) == 'table' then
    blurOwner, savedBlur = client, client.screenblur
    client.screenblur = false
end

local function number(value, fallback)
    value = tonumber(value)
    return value and value == value and math.abs(value) < math.huge and value or fallback
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function inventoryOpen()
    return LocalPlayer.state.invOpen == true
end

local function ownCamera()
    return camera and DoesCamExist(camera) and GetRenderingCam() == camera
end

local function cleanup()
    if camera then
        -- Another script may have taken ownership in the meantime. Never switch
        -- off that script's camera or destroy any camera except our own.
        if ownCamera() then RenderScriptCams(false, false, 0, true, true) end
        if DoesCamExist(camera) then DestroyCam(camera, false) end
    end
    if clone and DoesEntityExist(clone) then DeleteEntity(clone) end
    clone, camera, sourcePed, sourceModel, origin, cloneHeading = nil, nil, nil, nil, nil, nil
end

local function safePed(ped)
    return ped and ped ~= 0 and DoesEntityExist(ped)
        and PlayerData and PlayerData.loaded == true
        and not IsEntityDead(ped) and not IsPedFatallyInjured(ped)
        and not IsPedInAnyVehicle(ped, false) and not IsPauseMenuActive()
        and not (PlayerData and (PlayerData.dead or PlayerData.cuffed))
end

local function startPreview(ped)
    if not preview.Enabled or not safePed(ped) or not IsGameplayCamRendering() then return end
    local heading = GetEntityHeading(ped)
    local angle = math.rad(heading)
    local forwardX, forwardY = -math.sin(angle), math.cos(angle)
    local rightX, rightY = math.cos(angle), math.sin(angle)
    local coords = GetEntityCoords(ped)
    local distance = clamp(number(preview.Distance, 4.5), 1.5, 8.0)
    local side = clamp(number(preview.SideOffset, 1.7), -4.0, 4.0)
    local height = clamp(number(preview.Height, 0.9), -1.0, 3.0)
    local targetHeight = clamp(number(preview.TargetHeight, 0.85), -1.0, 3.0)
    local newClone = ClonePed(ped, heading, false, false)
    if not newClone or newClone == 0 or not DoesEntityExist(newClone) then return end
    clone = newClone
    SetEntityAsMissionEntity(clone, true, true)
    SetEntityCollision(clone, false, false)
    SetEntityInvincible(clone, true)
    FreezeEntityPosition(clone, true)
    SetBlockingOfNonTemporaryEvents(clone, true)
    ClearPedTasksImmediately(clone)
    RemoveAllPedWeapons(clone, true)
    SetEntityHeading(clone, heading)

    camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not camera or camera == 0 or not DoesCamExist(camera) then cleanup() return end
    SetCamCoord(camera, coords.x + forwardX * distance, coords.y + forwardY * distance, coords.z + height)
    PointCamAtCoord(camera, coords.x - rightX * side, coords.y - rightY * side, coords.z + targetHeight)
    SetCamFov(camera, clamp(number(preview.Fov, 40.0), 25.0, 75.0))
    SetCamActive(camera, true)
    RenderScriptCams(true, false, 0, true, true)
    sourcePed, sourceModel = ped, GetEntityModel(ped)
    origin = { x = coords.x, y = coords.y, z = coords.z }
    cloneHeading = heading
end

local function getter(name, fallback)
    local ok, value = pcall(function() return exports.ox_inventory[name](exports.ox_inventory) end)
    return ok and value or fallback
end

local function status()
    local ped = PlayerPedId()
    local exists = ped ~= 0 and DoesEntityExist(ped)
    local maxHealth = exists and number(GetEntityMaxHealth(ped), 200) or 200
    local base = maxHealth > 100 and 100 or 0
    local health = exists and number(GetEntityHealth(ped), 0) or 0
    local weapon = getter('getCurrentWeapon')
    return {
        health = math.floor(clamp((health - base) / math.max(1, maxHealth - base) * 100, 0, 100) + 0.5),
        armor = exists and math.floor(clamp(number(GetPedArmour(ped), 0), 0, 100)) or 0,
        weight = math.max(0, number(getter('GetPlayerWeight', PlayerData and PlayerData.weight), 0)),
        maxWeight = math.max(0, number(getter('GetPlayerMaxWeight', PlayerData and PlayerData.maxWeight), 0)),
        weaponSlot = type(weapon) == 'table' and number(weapon.slot) or nil,
        previewActive = clone ~= nil and DoesEntityExist(clone) and ownCamera() == true
    }
end

local function sendStatus()
    SendNUIMessage({ action = 'void:status', data = status() })
end

RegisterNUICallback('voidStatus', function(_, cb)
    if not inventoryOpen() then cb({ok = false, error = 'inventory_closed'}) return end
    cb({ok = true, status = status()})
end)

RegisterNUICallback('voidPreviewRotate', function(data, cb)
    local direction = type(data) == 'table' and data.direction
    if not inventoryOpen() or not clone or not ownCamera() or (direction ~= -1 and direction ~= 1) then
        cb({ok = false}) return
    end
    cloneHeading = (cloneHeading + direction * clamp(number(preview.RotateStep, 15), 1, 90)) % 360
    SetEntityHeading(clone, cloneHeading)
    cb({ok = true})
end)

CreateThread(function()
    while true do
        local open = inventoryOpen()
        local ped = PlayerPedId()
        if open and not wasOpen then
            wasOpen, attempted, nextStatus = true, false, 0
        elseif not open and wasOpen then
            cleanup()
            wasOpen, attempted = false, false
        end

        if open then
            if clone then
                local coords = GetEntityCoords(ped)
                local limit = clamp(number(preview.MaxMovement, 2.0), 0.5, 10.0)
                local moved = origin and ((coords.x - origin.x)^2 + (coords.y - origin.y)^2 + (coords.z - origin.z)^2 > limit^2)
                if not safePed(ped) or not ownCamera() or moved or not DoesEntityExist(clone) then
                    cleanup()
                elseif sourcePed ~= ped or sourceModel ~= GetEntityModel(ped) then
                    cleanup()
                    attempted = false
                end
            end
            if not attempted then
                attempted = true
                local ok, err = pcall(startPreview, ped)
                if not ok then cleanup(); print('[VOID inventory] Preview unavailable: ' .. tostring(err)) end
            end
            if clone and ownCamera() then
                -- Per-frame local invisibility never replicates to other clients
                -- and expires automatically when this loop stops hiding the ped.
                SetEntityLocallyInvisible(ped)
            end
            local now = GetGameTimer()
            if now >= nextStatus then
                sendStatus()
                nextStatus = now + clamp(number(config.StatusIntervalMs, 250), 100, 2000)
            end
        end
        Wait(clone and 0 or 200)
    end
end)

if config.Hotkeys.ExtraEnabled then
    for slot = 6, 10 do
        local targetSlot = slot
        local command = ('void_inventory_slot_%d'):format(targetSlot)
        RegisterCommand(command, function()
            local state, ped = LocalPlayer.state, PlayerPedId()
            if inventoryOpen() or state.invBusy or state.invHotkeys ~= true or IsNuiFocused()
                or EnableWeaponWheel or not safePed(ped) or IsPedCuffed(ped) then return end
            if lib and type(lib.progressActive) == 'function' and lib.progressActive() then return end
            -- useSlot owns all original item checks and the server callback.
            exports.ox_inventory:useSlot(targetSlot)
        end, false)
        local key = config.Hotkeys.Keys[targetSlot]
        if type(key) == 'string' and #key <= 10 then
            RegisterKeyMapping(command, ('VOID: usa slot %d'):format(targetSlot), 'keyboard', key)
        end
    end
end

local function unload()
    cleanup()
    attempted = true
    if inventoryOpen() then sendStatus() end
end

RegisterNetEvent('esx:onPlayerLogout', unload)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', unload)
RegisterNetEvent('ox:playerLogout', unload)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanup()
    if blurOwner and client == blurOwner and client.screenblur == false then client.screenblur = savedBlur end
end)

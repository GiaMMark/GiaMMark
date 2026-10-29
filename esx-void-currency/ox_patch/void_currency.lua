-- VOID_CURRENCY_ADDON 1.0.0
-- Install as both a client_script and server_script at the end of ox_inventory's manifest.
-- This changes shared item labels and account definitions, never player balances.

local ready = false
local items, inventory, configuredLabel, loadWrapper
local isServer = IsDuplicityVersion()

local function readCurrency()
    local ok, esx = pcall(function()
        return exports.es_extended:getSharedObject()
    end)
    if not ok or type(esx) ~= 'table' or type(esx.GetConfig) ~= 'function' then
        error('[void_currency] ESX GetConfig unavailable. Start es_extended before ox_inventory.', 0)
    end

    local configOk, config = pcall(esx.GetConfig)
    if not configOk or type(config) ~= 'table' then
        error('[void_currency] Cannot read es_extended configuration through GetConfig.', 0)
    end

    if type(config.VoidCurrency) ~= 'table' then return nil end
    local label = config.VoidCurrency.Label
    if type(label) ~= 'string' or label == '' then
        error('[void_currency] Config.VoidCurrency.Label must be a nonempty string.', 0)
    end
    return label
end

local function validAccounts(accounts)
    return type(accounts) == 'table' and accounts.money == 0 and accounts.black_money == nil
end

exports('IsVoidCurrencyReady', function()
    if not ready then return false end
    local ok, label = pcall(readCurrency)
    if not ok or label ~= configuredLabel then return false end
    if type(items.money) ~= 'table' or items.money.label ~= configuredLabel then return false end

    if isServer then
        return type(server) == 'table' and validAccounts(server.accounts)
            and validAccounts(inventory.accounts)
            and inventory.Load == loadWrapper and type(inventory.SlotWeight) == 'function'
            and type(items.black_money) == 'table'
    end
    return true
end)

configuredLabel = readCurrency()
if not configuredLabel then return end

local function requireTable(moduleName)
    local ok, module = pcall(require, moduleName)
    if not ok or type(module) ~= 'table' then
        error(('[void_currency] Unsupported ox_inventory module %s. Expected a shared table; install on the supported ESX/ox_inventory layout.'):format(moduleName), 0)
    end
    return module
end

items = requireTable('modules.items.shared')
if type(items.money) ~= 'table' then
    error('[void_currency] ox_inventory has no money item definition. Restore the standard money item first.', 0)
end
if type(items.cash) == 'table' and items.cash == items.black_money then
    error('[void_currency] Unsupported ox_inventory cash alias: it points to the retired black_money item.', 0)
end

if isServer then
    if type(items.black_money) ~= 'table' then
        error('[void_currency] The legacy black_money item definition is required to convert old container slots safely.', 0)
    end
    if type(server) ~= 'table' or type(server.accounts) ~= 'table' then
        error('[void_currency] ox_inventory server.accounts unavailable. The add-on must run after the ESX inventory bridge.', 0)
    end
    inventory = requireTable('modules.inventory.server')
    if inventory.accounts ~= nil and type(inventory.accounts) ~= 'table' then
        error('[void_currency] Unsupported ox_inventory Inventory.accounts value; expected a table.', 0)
    end
    if type(inventory.Load) ~= 'function' or type(inventory.SlotWeight) ~= 'function' then
        error('[void_currency] Unsupported ox_inventory container loader. Inventory.Load and Inventory.SlotWeight are required.', 0)
    end
end

local function finiteNonnegative(value)
    return type(value) == 'number' and value == value and value >= 0 and value < math.huge
end

local function copyTable(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[key] = copyTable(child, seen) end
    return result
end

local function convertContainer(data, weight)
    -- Stock Inventory.Load returns nothing when called without an inventory type.
    if data == nil and weight == nil then return nil, nil end
    if type(data) ~= 'table' or not finiteNonnegative(weight) then
        error('[void_currency] Invalid container data or total weight returned by Inventory.Load.', 0)
    end

    local converted, oldWeight, newWeight = {}, 0, 0
    for key, entry in pairs(data) do
        if type(entry) ~= 'table' then
            error('[void_currency] Invalid container slot returned by Inventory.Load.', 0)
        end
        if entry.name == 'black_money' then
            if not finiteNonnegative(entry.count) or entry.count == 0 or entry.count % 1 ~= 0
                or entry.count > 9007199254740991 or not finiteNonnegative(entry.weight)
                or not finiteNonnegative(entry.slot) or entry.slot < 1 or entry.slot % 1 ~= 0
                or key ~= entry.slot or (entry.metadata ~= nil and type(entry.metadata) ~= 'table') then
                error('[void_currency] Invalid legacy black_money container slot; conversion stopped without changing stored items.', 0)
            end

            local item = items.money
            if type(item) ~= 'table' or item.label ~= configuredLabel then
                error('[void_currency] Void money definition changed; container conversion cannot continue.', 0)
            end
            local replacement = {}
            for field, value in pairs(entry) do replacement[field] = value end
            replacement.name, replacement.label = 'money', item.label
            replacement.description, replacement.stack, replacement.close = item.description, item.stack, item.close
            replacement.metadata = copyTable(entry.metadata or {})

            local ok, slotWeight = pcall(inventory.SlotWeight, item, replacement)
            if not ok or not finiteNonnegative(slotWeight) then
                error('[void_currency] Failed to calculate the Void container slot weight; conversion stopped.', 0)
            end
            replacement.weight = slotWeight
            converted[key] = replacement
            oldWeight, newWeight = oldWeight + entry.weight, newWeight + slotWeight
        end
    end

    if next(converted) == nil then return data, weight end
    local total = weight - oldWeight + newWeight
    if not finiteNonnegative(oldWeight) or oldWeight > weight
        or not finiteNonnegative(newWeight) or not finiteNonnegative(total) then
        error('[void_currency] Invalid converted container total weight; conversion stopped.', 0)
    end
    local result = {}
    for key, entry in pairs(data) do result[key] = converted[key] or entry end
    return result, total
end

-- Cash is an alias in stock ox_inventory. Keep either table pointing at the same label.
items.money.label = configuredLabel
if type(items.cash) == 'table' then items.cash.label = configuredLabel end

if isServer then
    -- These zeroes describe the account item counters; they are not player balances.
    server.accounts.money = 0
    server.accounts.black_money = nil
    if inventory.accounts == nil then inventory.accounts = server.accounts end
    inventory.accounts.money = 0
    inventory.accounts.black_money = nil

    local originalLoad = inventory.Load
    loadWrapper = function(...)
        if type(items.black_money) ~= 'table' then
            error('[void_currency] The legacy black_money item definition was removed; container conversion stopped.', 0)
        end
        local data, weight = originalLoad(...)
        return convertContainer(data, weight)
    end
    inventory.Load = loadWrapper
end

-- Keep the old item definition so stock loading can recognize and convert legacy container slots.
ready = true

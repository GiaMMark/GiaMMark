-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local MAX_BALANCE = 9007199254740991

local function validNumber(value)
    return type(value) == 'number'
        and value == value
        and math.abs(value) <= MAX_BALANCE
end

local function validBalance(value)
    return validNumber(value) and value >= 0
end

local function cloneAccountMap(accounts)
    if type(accounts) ~= 'table' then
        return nil, 'invalid-accounts-object'
    end

    local normalized = {}
    for name, balance in pairs(accounts) do
        if type(name) ~= 'string' or name == '' then
            return nil, 'invalid-account-name'
        end
        local currencyAccount = name == 'money' or name == 'black_money'
        -- Existing bank/custom accounts may represent debt. Preserve their
        -- signed balances; only the two currency sources must be nonnegative.
        if not validNumber(balance) or (currencyAccount and balance < 0) then
            return nil, 'invalid-account-balance'
        end
        normalized[name] = balance
    end
    return normalized
end

---Converts standard ESX cash and black-money balances into one Void balance.
---Returns a fresh account map; invalid data is never replaced by zero.
---The caller must abort the load on error so no incomplete balance is saved.
---@param accounts table<string, number>
---@return table<string, number>? normalized
---@return string? errorCode
function Core.NormalizeVoidAccounts(accounts)
    local normalized, accountError = cloneAccountMap(accounts)
    if not normalized then return nil, accountError end

    local money = normalized.money or 0
    local blackMoney = normalized.black_money or 0

    -- Custom inventories can store the same balances as physical items. Their
    -- migration must be handled by an inventory adapter, not by adding mirrors.
    if Config.CustomInventory and blackMoney > 0 then
        return nil, 'custom-inventory-conversion-required'
    end

    local total = Config.CustomInventory and money or money + blackMoney
    if not validBalance(total) or total < money or total < blackMoney then
        return nil, 'void-balance-overflow'
    end

    normalized.money = total
    normalized.black_money = nil
    return normalized
end

local function positiveInteger(value)
    return validBalance(value) and value >= 1 and value == math.floor(value)
end

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

---Normalizes ox_inventory's persisted slot array before inventory creation.
---Item counts are authoritative; account JSON entries are only stale mirrors.
---Every item keeps its slot, order, metadata and other saved properties.
---@param accounts table<string, number>
---@param inventory table[]
---@return table<string, number>? normalizedAccounts
---@return table[]? normalizedInventory
---@return string? errorCode
function Core.NormalizeVoidOxAccounts(accounts, inventory)
    local normalized, accountError = cloneAccountMap(accounts)
    if not normalized then return nil, nil, accountError end
    if type(inventory) ~= 'table' then
        return nil, nil, 'invalid-ox-inventory-object'
    end

    local entryCount = 0
    for index in pairs(inventory) do
        if not positiveInteger(index) then
            return nil, nil, 'unsupported-ox-inventory-format'
        end
        entryCount = entryCount + 1
    end

    local converted, usedSlots, total = {}, {}, 0
    for index = 1, entryCount do
        local item = inventory[index]
        if type(item) ~= 'table' then
            return nil, nil, 'unsupported-ox-inventory-format'
        end
        if type(item.name) ~= 'string' or item.name == '' or #item.name > 100
            or item.name:find('%c') or not item.name:find('%S') then
            return nil, nil, 'invalid-ox-item-name'
        end
        if not positiveInteger(item.count) then
            return nil, nil, 'invalid-ox-item-count'
        end
        if not positiveInteger(item.slot) then
            return nil, nil, 'invalid-ox-item-slot'
        end
        if usedSlots[item.slot] then
            return nil, nil, 'duplicate-ox-inventory-slot'
        end
        usedSlots[item.slot] = true

        local nextItem = copy(item)
        if item.name == 'money' or item.name == 'black_money' then
            local nextTotal = total + item.count
            if not validBalance(nextTotal) or nextTotal < total then
                return nil, nil, 'void-balance-overflow'
            end
            total = nextTotal
            nextItem.name = 'money'
        end
        converted[index] = nextItem
    end

    normalized.money = total
    normalized.black_money = nil
    return normalized, converted
end

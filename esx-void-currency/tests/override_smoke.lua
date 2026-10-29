local resource = 'es_extended/'
local passed = 0
local function check(name, action)
    action(); passed = passed + 1; print('PASS '..name)
end

local function fixture(mode)
    Config = { CustomInventory = 'ox', VoidCurrency = { Label = 'Void' } }
    Core = { PlayerClass = {}, PlayerFunctionOverrides = {} }
    ESX = { Math = { Round = function(n) return math.floor(n + 0.5) end } }
    json = { decode = function(_) return {'money','black_money'} end }
    local events, calls = {}, {}
    function GetConvar(_, fallback) return fallback end
    function GetResourceState(_) return 'started' end
    function AddEventHandler(name, fn) events[name] = fn end
    function TriggerEvent(...) end
    local player = {
        source = 7, playerId = 7,
        inventory = {},
        accounts = {
            { name='money', label='Void', money=100, round=true, index=1 },
            { name='bank', label='Banca', money=250, round=true, index=2 },
        },
        triggerEvent = function(...) end,
    }
    dofile(resource..'server/classes/player/accounts.lua')
    Core.PlayerClass.AttachAccounts(player)
    local module = { accounts = {money=0} }
    local function run(method, source, item, amount)
        assert(source == 7)
        calls[#calls+1] = {method=method,item=item,amount=amount}
        assert(item == 'money', 'only canonical physical money item allowed')
        if method == 'AddItem' then player.accounts[1].money = player.accounts[1].money + amount
        elseif method == 'RemoveItem' then
            if amount > player.accounts[1].money then return false end
            player.accounts[1].money = player.accounts[1].money - amount
        elseif method == 'SetItem' then player.accounts[1].money = amount end
        return true
    end
    local exportTable = {}
    for _,name in ipairs({'GetItem','AddItem','RemoveItem','SetItem','CanCarryItem','CanSwapItem','SetMaxWeight'}) do
        module[name] = function(...) return run(name, ...) end
        exportTable[name] = function(_, ...) return run(name, ...) end
    end
    exportTable.Inventory = function(_) return mode == 'module' and module or nil end
    exports = { ox_inventory = exportTable }
    dofile(resource..'server/classes/overrides/oxinventory.lua')
    local overrides = Core.PlayerFunctionOverrides.OxInventory
    for _,name in ipairs({'getInventory','setAccountMoney','addAccountMoney','removeAccountMoney','syncInventory'}) do
        player[name] = overrides[name](player)
    end
    return player, calls, events
end

for _,mode in ipairs({'module','proxy'}) do
    check(mode..': money canonical add/set/remove and bank isolated', function()
        local player, calls = fixture(mode)
        assert(player.getMoney() == 100 and player.getAccount('money').label == 'Void')
        assert(player.addMoney(25) == true and player.getMoney() == 125)
        assert(player.removeMoney(30) == true and player.getMoney() == 95)
        assert(player.setMoney(51) == true and player.getMoney() == 51)
        assert(#calls == 3)
        assert(calls[1].item == 'money' and calls[2].item == 'money' and calls[3].item == 'money')
        assert(player.setAccountMoney('bank',180) == true)
        assert(player.getAccount('bank').money == 180 and player.getMoney() == 51)
        assert(#calls == 3, 'bank must not write a physical item')
        assert(player.removeMoney(52) == false and player.getMoney() == 51)
        assert(#calls == 3, 'insufficient balance must not call remove export')
    end)
    check(mode..': retired black_money rejects operations without touching Void', function()
        local player, calls = fixture(mode)
        assert(player.getAccount('black_money') == nil)
        assert(player.addAccountMoney('black_money',30) == false)
        assert(player.removeAccountMoney('black_money',30) == false)
        assert(player.setAccountMoney('black_money',30) == false)
        assert(#calls == 0 and player.getMoney() == 100)
        local minimal = player.getAccounts(true)
        assert(minimal.money == 100 and minimal.bank == 250 and minimal.black_money == nil)
    end)
end

check('ox mirrors are not summed and persisted converted slots reload idempotently', function()
    Config = { CustomInventory = 'ox' }; Core = {}
    dofile(resource..'server/modules/core/void_currency.lua')
    local inputAccounts = {money=9000,black_money=4000,bank=550}
    local inputSlots = {
        {name='money',count=100,slot=2,metadata={tag='cash'}},
        {name='black_money',count=40,slot=6,metadata={tag='legacy'}},
        {name='bread',count=3,slot=12,metadata={fresh=true}},
    }
    local accounts, slots, err = Core.NormalizeVoidOxAccounts(inputAccounts,inputSlots)
    assert(accounts and slots and not err)
    assert(accounts.money == 140 and accounts.bank == 550 and accounts.black_money == nil)
    assert(slots[1].name == 'money' and slots[2].name == 'money' and slots[2].slot == 6)
    assert(slots[3].name == 'bread' and slots[3].count == 3)
    assert(inputAccounts.black_money == 4000 and inputSlots[2].name == 'black_money')
    slots[2].metadata.tag = 'changed copy'; assert(inputSlots[2].metadata.tag == 'legacy')
    local savedAccounts,savedSlots = Core.NormalizeVoidOxAccounts(accounts,slots)
    assert(savedAccounts.money == 140 and savedAccounts.bank == 550 and savedAccounts.black_money == nil)
    assert(savedSlots[2].count == 40 and savedSlots[2].name == 'money')
end)
print('Integration QA scenarios passed: '..passed)

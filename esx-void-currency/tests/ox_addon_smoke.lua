local addon = 'ox_patch/void_currency.lua'
local function fixture(options)
    options = options or {}
    local config = options.config
    if config == nil and not options.noFeature then config = { VoidCurrency = { Label = 'Void' } } end
    config = config or {}
    local money = { name = 'money', label = 'Money', weight=2, description='Survival currency', stack=true, close=true }
    local black = { name = 'black_money', label = 'Dirty Money', image = 'black_money.png' }
    local items = { money = money, cash = money, black_money = black, water = {label='Water'} }
    if options.separateCash then items.cash = { name='cash', label='Cash' } end
    if options.noMoney then items.money = nil end
    if options.noBlackDefinition then items.black_money = nil end
    if options.cashAliasesBlack then items.cash = black end
    local accountDefinitions = { money = 0, black_money = 0, custom = 17 }
    local player = { accounts = { money = 120, black_money = 45, bank = 200 }, items = { { name = 'black_money', count = 45, label = 'Dirty Money' } } }
    local inventory = { accounts = accountDefinitions, players = { player } }
    inventory.Load = function(...)
        inventory.loadArgs = { ... }
        inventory.loadCalls = (inventory.loadCalls or 0) + 1
        if options.nilLoad then return nil, nil end
        return options.loadData or {}, options.loadWeight or 0
    end
    inventory.SlotWeight = function(item, entry)
        if options.mutateThenFail then entry.metadata.nested.value='changed'; error('weight failed') end
        if options.invalidWeight then return math.huge end
        return item.weight * entry.count + (entry.metadata.weight or 0) * entry.count
    end
    if options.noLoader then inventory.Load = nil end
    if options.noSlotWeight then inventory.SlotWeight = nil end
    if options.cloneAccounts then inventory.accounts = { money = 9, black_money = 4, other = 22 } end
    if options.noInventoryAccounts then inventory.accounts = nil end
    if options.badInventoryAccounts then inventory.accounts = 5 end
    local modules = { ['modules.items.shared'] = items, ['modules.inventory.server'] = inventory }
    if options.noItemModule then modules['modules.items.shared'] = nil end
    if options.noInventoryModule then modules['modules.inventory.server'] = nil end
    local calls, exposed = {}, {}
    local resourceExports = { es_extended = { getSharedObject = function()
        if options.failESX then error('ESX unavailable') end
        return { GetConfig = function() return config end }
    end } }
    setmetatable(resourceExports, { __call = function(_, name, fn) exposed[name] = fn end })
    local env = {
        IsDuplicityVersion = function() return options.isServer ~= false end,
        exports = resourceExports,
        server = { accounts = accountDefinitions },
        require = function(name)
            calls[#calls+1] = name
            assert(modules[name], 'module unavailable')
            return modules[name]
        end,
    }
    if options.noServer then env.server = nil end
    if options.badServerAccounts then env.server.accounts = 'bad' end
    setmetatable(env, { __index = _G })
    local chunk = assert(loadfile(addon, 't', env))
    local ok, err = pcall(chunk)
    return { env=env, ok=ok, err=err, exposed=exposed, items=items, black=black,
        definitions=accountDefinitions, inventory=inventory, player=player, calls=calls, config=config }
end
local function ready(f) return f.exposed.IsVoidCurrencyReady() end
local function noPlayerMutation(f)
    assert(f.player.accounts.money == 120 and f.player.accounts.black_money == 45 and f.player.accounts.bank == 200)
    assert(f.player.items[1].name == 'black_money' and f.player.items[1].count == 45 and f.player.items[1].label == 'Dirty Money')
    assert(f.items.black_money == f.black and f.black.label == 'Dirty Money' and f.black.image == 'black_money.png')
    assert(f.items.water.label == 'Water')
end
local server = fixture()
assert(server.ok, server.err)
assert(ready(server) and server.items.money.label == 'Void' and server.items.cash == server.items.money)
assert(server.definitions.money == 0 and server.definitions.black_money == nil and server.definitions.custom == 17)
assert(server.inventory.accounts == server.definitions)
noPlayerMutation(server)
print('PASS server: labels and account definitions changed, player balances/items untouched')
local client = fixture({ isServer=false, noServer=true, noInventoryModule=true })
assert(client.ok, client.err)
assert(ready(client) and client.items.money.label == 'Void' and #client.calls == 1)
assert(client.definitions.black_money == 0)
noPlayerMutation(client)
print('PASS client: money/cash label only, no server modules or account mutation')
local clone = fixture({ cloneAccounts=true, separateCash=true })
assert(clone.ok, clone.err)
assert(ready(clone) and clone.items.cash.label == 'Void')
assert(clone.inventory.accounts ~= clone.definitions and clone.inventory.accounts.money == 0)
assert(clone.inventory.accounts.black_money == nil and clone.inventory.accounts.other == 22)
noPlayerMutation(clone)
print('PASS account definition clones and independent cash alias')
local deferred = fixture({ noInventoryAccounts=true })
assert(deferred.ok, deferred.err)
assert(ready(deferred) and deferred.inventory.accounts == deferred.definitions)
print('PASS stock deferred Inventory.accounts initialization receives shared definitions')
for _, isServer in ipairs({ true, false }) do
    local off = fixture({ noFeature=true, isServer=isServer })
    assert(off.ok, off.err)
    assert(not ready(off) and #off.calls == 0 and off.items.money.label == 'Money' and off.definitions.black_money == 0)
    noPlayerMutation(off)
end
print('PASS absent Config.VoidCurrency leaves both VMs unchanged and readiness false')
for _, options in ipairs({ {noItemModule=true}, {noMoney=true}, {noServer=true},
    {badServerAccounts=true}, {noInventoryModule=true}, {badInventoryAccounts=true}, {noLoader=true}, {noSlotWeight=true} }) do
    local unsupported = fixture(options)
    assert(not unsupported.ok and tostring(unsupported.err):find('[void_currency]', 1, true))
    assert(not ready(unsupported))
    if unsupported.items.money then assert(unsupported.items.money.label == 'Money') end
    assert(unsupported.definitions.black_money == 0)
    noPlayerMutation(unsupported)
end
print('PASS unsupported forks fail clearly before mutations; readiness never falsely passes')
for _, options in ipairs({ {failESX=true}, {config={VoidCurrency={}}}, {config={VoidCurrency={Label=''}}} }) do
    local invalid = fixture(options)
    assert(not invalid.ok and tostring(invalid.err):find('[void_currency]', 1, true))
    assert(not ready(invalid) and #invalid.calls == 0)
end
print('PASS missing ESX and invalid labels fail with a clear diagnostic')
server.items.money.label = 'Wrong'
assert(not ready(server)); server.items.money.label='Void'; assert(ready(server))
server.definitions.black_money=0
assert(not ready(server)); server.definitions.black_money=nil; assert(ready(server))
server.inventory.accounts.money=1
assert(not ready(server)); server.inventory.accounts.money=0; assert(ready(server))
server.config.VoidCurrency=nil
assert(not ready(server)); server.config.VoidCurrency={Label='Changed'};assert(not ready(server))
server.config.VoidCurrency.Label='Void';assert(ready(server))
print('PASS readiness rechecks actual labels, definitions and active ESX configuration')
local custom = fixture({ config={VoidCurrency={Label='Void Survival %'}} })
assert(custom.ok and ready(custom) and custom.items.money.label == 'Void Survival %')
noPlayerMutation(custom)
print('PASS label is read from ESX config and preserves literal text')
assert(pcall(assert(loadfile(addon, 't', server.env))))
assert(server.exposed.IsVoidCurrencyReady())
noPlayerMutation(server)
print('PASS repeat execution is idempotent')

local function legacyData()
    return {
        [1] = { name='water', label='Water', slot=1, count=2, weight=10, metadata={} },
        [3] = { name='black_money', label='Dirty Money', slot=3, count=5, weight=5, description='Retired', stack=false, close=false,
            metadata={weight=0.5,nested={value='original'}}, custom='keep' },
        [4] = { name='money', label='Money', slot=4, count=7, weight=14, metadata={} },
    }
end
for _, invType in ipairs({'stash','trunk','glovebox','dumpster'}) do
    local options = {loadData=legacyData(),loadWeight=29}
    local f = fixture(options)
    assert(f.ok, f.err)
    local source=options.loadData
    local result, weight=f.inventory.Load('container',invType,'owner')
    assert(f.inventory.loadArgs[1]=='container' and f.inventory.loadArgs[2]==invType and f.inventory.loadArgs[3]=='owner')
    assert(result~=source and result[3]~=source[3] and result[1]==source[1] and result[4]==source[4])
    assert(result[3].name=='money' and result[3].label=='Void' and result[3].count==5 and result[3].slot==3)
    assert(result[3].weight==12.5 and weight==36.5)
    assert(result[3].description=='Survival currency' and result[3].stack and result[3].close and result[3].custom=='keep')
    assert(result[3].metadata~=source[3].metadata and result[3].metadata.nested.value=='original')
    assert(source[3].name=='black_money' and source[3].label=='Dirty Money' and source[3].weight==5)
    assert(result[3].count+result[4].count==12)
    options.loadData,options.loadWeight=result,weight
    local again,againWeight=f.inventory.Load('container',invType,'owner')
    assert(again==result and againWeight==weight and again[3].count+again[4].count==12)
    noPlayerMutation(f)
end
print('PASS stash/trunk/glovebox/random loot conversion preserves counts/slots/metadata and recalculates total weight idempotently')
local nilResult=fixture({nilLoad=true})
assert(nilResult.ok, nilResult.err)
local a,b=nilResult.inventory.Load(nil,nil,nil)
assert(a==nil and b==nil)
print('PASS stock nil/nil loader return remains unchanged')
for _, badCount in ipairs({0,-1,1.5,math.huge,0/0,9007199254740992}) do
    local data=legacyData();data[3].count=badCount
    local f=fixture({loadData=data,loadWeight=29})
    assert(f.ok,f.err)
    local ok,err=pcall(f.inventory.Load,'container','stash')
    assert(not ok and tostring(err):find('[void_currency]',1,true))
    assert(data[3].name=='black_money' and data[3].label=='Dirty Money' and data[3].metadata.nested.value=='original')
end
print('PASS invalid/nonfinite/fractional/unsafe counts reject conversion without modifying original slots')
for _, mode in ipairs({'slot','metadata','entryWeight','totalWeight','data','slotEntry','tooSmallTotal','invalidCalculatedWeight','calculationFailure'}) do
    local data=legacyData()
    local options={loadData=data,loadWeight=29}
    if mode=='slot' then data[3].slot=4 end
    if mode=='metadata' then data[3].metadata='bad' end
    if mode=='entryWeight' then data[3].weight=math.huge end
    if mode=='totalWeight' then options.loadWeight=math.huge end
    if mode=='data' then options.loadData='bad' end
    if mode=='slotEntry' then data[2]='bad' end
    if mode=='tooSmallTotal' then options.loadWeight=1 end
    if mode=='invalidCalculatedWeight' then options.invalidWeight=true end
    if mode=='calculationFailure' then options.mutateThenFail=true end
    local f=fixture(options)
    assert(f.ok,f.err)
    local ok,err=pcall(f.inventory.Load,'container','stash')
    assert(not ok and tostring(err):find('[void_currency]',1,true),mode)
    assert(data[3].name=='black_money' and data[3].label=='Dirty Money')
    if type(data[3].metadata)=='table' then assert(data[3].metadata.nested.value=='original') end
    noPlayerMutation(f)
end
print('PASS malformed container data, weight failures and metadata mutations fail atomically')
local wrapped=fixture()
assert(ready(wrapped))
wrapped.inventory.Load=function()return{},0 end
assert(not ready(wrapped))
print('PASS readiness fails if the installed container migration wrapper is replaced')

local absentLegacy=fixture({noBlackDefinition=true})
assert(not absentLegacy.ok and tostring(absentLegacy.err):find('legacy black_money item definition',1,true))
assert(not ready(absentLegacy) and absentLegacy.items.money.label=='Money')
local wrongAlias=fixture({cashAliasesBlack=true})
assert(not wrongAlias.ok and tostring(wrongAlias.err):find('cash alias',1,true))
assert(not ready(wrongAlias) and wrongAlias.black.label=='Dirty Money' and wrongAlias.items.money.label=='Money')
print('PASS forks cannot silently discard legacy slots or relabel black_money through a cash alias')
local removed=fixture({loadData=legacyData(),loadWeight=29})
assert(removed.ok and ready(removed))
removed.items.black_money=nil
assert(not ready(removed))
local ok,err=pcall(removed.inventory.Load,'container','stash')
assert(not ok and tostring(err):find('legacy black_money item definition was removed',1,true))
assert(removed.inventory.loadCalls==nil)
print('PASS removing legacy definition after startup blocks the original loader before data can be dropped')

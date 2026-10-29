local root='es_extended/'
local groups=0
local function pass(name) groups=groups+1;print('PASS '..name) end
local function copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o end
local function same(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not same(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
function GetConvar(_,fallback) return fallback end
function GetResourceState() return 'missing' end
function TranslateCap(k) return k end
function vector3(x,y,z) return {x=x,y=y,z=z} end
Core={PlayerClass={}}
dofile(root..'shared/config/main.lua')
dofile(root..'server/modules/core/void_currency.lua')
local sourceAccounts={money=999,black_money=777,bank=1234,token=9}
local sourceInventory={
 {name='water',count=2,slot=8,metadata={quality=80,tags={'a','b'}}},
 {name='black_money',count=75,slot=4,metadata={label='saved label',custom={serial='test'}}},
 {name='money',count=125,slot=20,metadata={}},
}
local accounts,inventory,err=Core.NormalizeVoidOxAccounts(sourceAccounts,sourceInventory)
assert(not err and accounts.money==200 and accounts.black_money==nil and accounts.bank==1234 and accounts.token==9)
assert(inventory[1].name=='water' and inventory[2].name=='money' and inventory[3].name=='money')
assert(inventory[1].slot==8 and inventory[2].slot==4 and inventory[3].slot==20)
assert(inventory[2].count==75 and inventory[3].count==125)
assert(same(inventory[1].metadata,sourceInventory[1].metadata) and same(inventory[2].metadata,sourceInventory[2].metadata))
assert(sourceInventory[2].name=='black_money' and sourceAccounts.money==999 and sourceAccounts.black_money==777)
pass('ox conta solo slot autoritativi, conserva ordine/slot/oggetti e non somma specchi accounts')
local againAccounts,againInventory=Core.NormalizeVoidOxAccounts(accounts,inventory)
assert(same(againAccounts,accounts) and same(againInventory,inventory))
inventory[1].metadata.tags[1]='changed';inventory[2].metadata.custom.serial='changed'
assert(sourceInventory[1].metadata.tags[1]=='a' and sourceInventory[2].metadata.custom.serial=='test')
pass('conversione idempotente e clone profondo dei metadata senza mutare gli originali')
local emptyAccounts,emptyInventory=Core.NormalizeVoidOxAccounts({money=1000,black_money=200,bank=70},{})
assert(emptyAccounts.money==0 and emptyAccounts.black_money==nil and emptyAccounts.bank==70 and next(emptyInventory)==nil)
pass('inventario ox vuoto autorevole, nessun compenso o doppio conteggio dei mirror')
local function invalid(inv,expected,a)
 local x,y,e=Core.NormalizeVoidOxAccounts(a or {},inv)
 assert(x==nil and y==nil and e==expected,tostring(e)..' != '..expected)
end
invalid('bad','invalid-ox-inventory-object')
invalid({money=10},'unsupported-ox-inventory-format')
invalid({[1]={name='money',count=2,slot=1},[3]={name='water',count=1,slot=3}},'unsupported-ox-inventory-format')
invalid({[1]={name='money',count=2,slot=1},extra=true},'unsupported-ox-inventory-format')
invalid({false},'unsupported-ox-inventory-format')
for _,name in ipairs({'','  ','money\0','money\n'}) do invalid({{name=name,count=1,slot=1}},'invalid-ox-item-name') end
pass('formati legacy/misti/sparsi, oggetti scalari e nomi invalidi rifiutati')
for _,count in ipairs({0,-1,0.5,'3',false,math.huge,0/0,9007199254740992}) do
 invalid({{name='money',count=count,slot=1}},'invalid-ox-item-count')
end
for _,slot in ipairs({0,-1,1.5,'2',false,math.huge,0/0,9007199254740992}) do
 invalid({{name='money',count=1,slot=slot}},'invalid-ox-item-slot')
end
invalid({{name='money',count=1,slot=7},{name='water',count=1,slot=7}},'duplicate-ox-inventory-slot')
invalid({{name='money',count=9007199254740991,slot=1},{name='black_money',count=1,slot=2}},'void-balance-overflow')
invalid({},'invalid-account-balance',{bank=math.huge})
invalid({},'invalid-account-balance',{bank=-9007199254740992})
invalid({},'invalid-account-balance',{money=-1})
invalid({},'invalid-account-balance',{black_money=-1})
pass('count e slot interi positivi, slot unici, saldi e somma safeinteger verificati')
Config.CustomInventory=false
local stock=assert(Core.NormalizeVoidAccounts({money=125,black_money=75,bank=1234}))
assert(stock.money==200 and stock.bank==1234 and stock.black_money==nil)
assert(same(Core.NormalizeVoidAccounts(stock),stock))
Config.CustomInventory='custom-other'
local blocked,e=Core.NormalizeVoidAccounts({money=10,black_money=1})
assert(blocked==nil and e=='custom-inventory-conversion-required')
pass('normalizzazione stock e guard per altri inventari restano invariati')

Config.CustomInventory=false
local stockDebt=assert(Core.NormalizeVoidAccounts({money=12,black_money=3,bank=-50,credit=-25}))
assert(stockDebt.money==15 and stockDebt.bank==-50 and stockDebt.credit==-25)
local oxDebt,oxDebtInventory=Core.NormalizeVoidOxAccounts({money=900,black_money=800,bank=-50,credit=-25},{{name='money',count=15,slot=3}})
assert(oxDebt and oxDebt.money==15 and oxDebt.bank==-50 and oxDebt.credit==-25 and oxDebtInventory[1].count==15)
for _,bad in ipairs({{money=-1,bank=-50},{black_money=-1,bank=-50}}) do
 local stockBad,stockError=Core.NormalizeVoidAccounts(bad)
 assert(stockBad==nil and stockError=='invalid-account-balance')
 local oxBad,oxItems,oxError=Core.NormalizeVoidOxAccounts(bad,{})
 assert(oxBad==nil and oxItems==nil and oxError=='invalid-account-balance')
end
pass('debiti banca e conti noncurrency preservati, contanti e sporchi negativi rifiutati')


local fixture,decodedAccounts,decodedInventory,captured,inventoryCall,dropped,queries,writes
local marker,ready,readyError,metadataError='1.0.0',true,false,false
function GetResourceMetadata()
 if metadataError then error('metadata unavailable') end
 return marker
end
exports={ox_inventory={IsVoidCurrencyReady=function()
 if readyError then error('adapter unavailable') end
 return ready
end}}
json={decode=function(v)
 if v=='{"fixture":"accounts"}' then return copy(decodedAccounts) end
 if v=='[{"fixture":"inventory"}]' or v=='{"fixture":"inventory"}' then return copy(decodedInventory) end
 if v=='{"x":1,"y":2,"z":3}' then return {x=1,y=2,z=3} end
 error('bad JSON fixture')
end}
MySQL={prepare={await=function() queries=queries+1;return fixture end},update={await=function() writes=writes+1;error('unexpected DB write') end}}
ESX={Players={},Jobs={unemployed={id=1,name='unemployed',label='None',type='none',grades={['0']={grade=0,name='unemployed',label='None',salary=0}}}},Math={Round=function(v)return math.floor(v+0.5)end}}
function ESX.DoesJobExist()return true end
function GetPlayerName()return 'Test character' end
function DropPlayer(_,reason)dropped=reason;return 'DROPPED'end
function TriggerEvent()end
GlobalState={}
Core.playersByIdentifier={};Core.RegisteredCommands={}
Core.PlayerSession={IsPlayerLoadActive=function()return true end,loadPlayerQuery='fake query'}
Core.WithPlayerPersistence=function(_,fn)return fn(nil)end
Core.PlayerClass.BuildInventory=function()return {},0 end
Core.PlayerClass.IsValidCoordinates=function(v)return type(v)=='table'and v.x~=nil end
Core.PlayerClass.GetDefaultCoordinates=function()return{x=1,y=2,z=3}end
dofile(root..'server/classes/player/accounts.lua')
function CreateExtendedPlayer(source,identifier,ssn,group,values,items)
 captured={source=source,identifier=identifier,accounts=values,inventory=items,playerId=source,variables={}}
 captured.triggerEvent=function()end
 captured.getMaxWeight=function()return 24 end
 captured.getName=function()return 'Test character'end
 captured.getInventory=function()return items end
 captured.getWeight=function()return 0 end
 Core.PlayerClass.AttachAccounts(captured)
 return captured
end
function setPlayerInventory(source,player,items,isNew)inventoryCall={source=source,player=player,items=items,isNew=isNew}end
dofile(root..'server/modules/player/session/runtime/load.lua')
local function load(a,inv,custom,accountRaw,inventoryRaw)
 fixture={accounts=accountRaw or '{"fixture":"accounts"}',inventory=inventoryRaw or '[{"fixture":"inventory"}]',job='unemployed',job_grade=0,position='{"x":1,"y":2,"z":3}'}
 decodedAccounts=a;decodedInventory=inv;captured=nil;inventoryCall=nil;dropped=nil;queries=0;writes=0
 Config.CustomInventory=custom==nil and 'ox' or custom
 ESX.Players={};Core.playersByIdentifier={}
 local ok,msg=pcall(loadESXPlayer,'test-character',42,false,{})
 assert(ok,msg)
 assert(writes==0)
 return msg
end
local realPrint=print
print=function()end
marker=nil
assert(load(sourceAccounts,sourceInventory)=='DROPPED' and dropped:find('ox%-void%-adapter%-missing') and queries==0 and not captured and not inventoryCall)
marker='0.9.0'
assert(load(sourceAccounts,sourceInventory)=='DROPPED' and queries==0 and not captured)
marker='1.0.0';metadataError=true
assert(load(sourceAccounts,sourceInventory)=='DROPPED' and queries==0)
metadataError=false
print=realPrint
pass('loader senza marker corretto blocca prima di query, player, inventory e scritture')
print=function()end
for _,state in ipairs({false,'true'}) do
 ready=state;assert(load(sourceAccounts,sourceInventory)=='DROPPED' and dropped:find('ox%-void%-adapter%-not%-ready') and queries==0 and not captured)
end
ready=true;readyError=true
assert(load(sourceAccounts,sourceInventory)=='DROPPED' and queries==0 and not captured)
readyError=false
print=realPrint
pass('marker non basta: export readiness true obbligatorio, errori e stringhe non accettati')
print=function()end
load(sourceAccounts,sourceInventory)
print=realPrint
assert(queries==1 and captured and not dropped and inventoryCall)
assert(captured.getMoney()==200 and captured.getAccount('money').label=='Void' and captured.getAccount('black_money')==nil)
assert(captured.getAccount('bank').money==1234)
assert(captured.inventory[2].name=='money' and inventoryCall.items==captured.inventory)
assert(sourceInventory[2].name=='black_money' and sourceInventory[2].metadata.custom.serial=='test')
assert(same(captured.inventory[2].metadata,sourceInventory[2].metadata))
pass('loader reale passa saldi e slot convertiti a CreateExtendedPlayer e setPlayerInventory')
local savedAccounts=copy(captured.getAccounts(true));local savedInventory=copy(captured.inventory)
print=function()end
load(savedAccounts,savedInventory)
print=realPrint
assert(captured and captured.getMoney()==200 and same(captured.inventory,savedInventory))
pass('reload di JSON gia convertito conserva stessa quantita di Void e metadata')
print=function()end
load({money=999,black_money=888,bank=10},{})
print=realPrint
assert(captured and captured.getMoney()==0 and captured.getAccount('bank').money==10 and #captured.inventory==0)
pass('loader vuoto ox non accredita mirror money/black_money del database')
print=function()end
for _,raw in ipairs({'null','false','10','[{broken'}) do
 assert(load(sourceAccounts,sourceInventory,nil,nil,raw)=='DROPPED' and dropped:find('invalid%-ox%-inventory%-json') and not captured and not inventoryCall)
end
for _,bad in ipairs({{money=10},{{name='money',count=0,slot=1}},{{name='money',count=1,slot=1},{name='water',count=1,slot=1}}}) do
 assert(load(sourceAccounts,bad)=='DROPPED' and not captured and not inventoryCall)
end
assert(load(sourceAccounts,sourceInventory,nil,'{broken')=='DROPPED' and dropped:find('invalid%-accounts%-json') and not captured)
print=realPrint
pass('JSON corrotto o inventario invalido non crea player, non cambia inventario e non salva')
marker=nil;ready=false
print=function()end
load({money=125,black_money=75,bank=1234},nil,false)
print=realPrint
assert(captured and captured.getMoney()==200 and captured.getAccount('bank').money==1234 and not inventoryCall)
assert(captured.addMoney(20,'test')==true and captured.getMoney()==220)
assert(captured.removeMoney(30,'test')==true and captured.getMoney()==190)
assert(captured.removeMoney(191,'test')==false and captured.getMoney()==190)
pass('stock reale non richiede adapter ox e API money continuano ad aggiungere/togliere Void')

print=function()end
load({money=12,black_money=3,bank=-50},nil,false)
print=realPrint
assert(captured and captured.getMoney()==15 and captured.getAccount('bank').money==-50)
marker='1.0.0';ready=true
print=function()end
load({money=900,black_money=800,bank=-50},{{name='black_money',count=15,slot=7}},'ox')
print=realPrint
assert(captured and captured.getMoney()==15 and captured.getAccount('bank').money==-50 and captured.inventory[1].name=='money')
pass('loader stock e ox mantengono banca negativa dopo conversione della valuta')

print('SCENARI OX/STOCK PASSATI: '..groups)

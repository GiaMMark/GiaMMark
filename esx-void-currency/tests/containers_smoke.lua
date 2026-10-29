local config={VoidCurrency={Label='Void'}}
local labels={money={label='Money',weight=2,stack=true,close=true},black_money={label='Dirty Money',weight=1}}
labels.cash=labels.money
local originalSlots={
 [1]={name='money',label='Money',count=3,slot=1,weight=6,metadata={}},
 [5]={name='black_money',label='Dirty Money',count=40,slot=5,weight=40,metadata={tag={saved=true}}},
 [8]={name='bread',label='Bread',count=1,slot=8,weight=5,metadata={}},
}
local currentSlots,currentWeight=originalSlots,51
local inv={accounts={money=0,black_money=0},Load=function() return currentSlots,currentWeight end,SlotWeight=function(item,slot)return item.weight*slot.count end}
server={accounts={money=0,black_money=0}}
function IsDuplicityVersion()return true end
local exported={}
exports=setmetatable({es_extended={getSharedObject=function()return {GetConfig=function()return config end}end}}, {__call=function(_,key,fn)exported[key]=fn end})
require=function(path)
 if path=='modules.items.shared'then return labels end
 if path=='modules.inventory.server'then return inv end
 error('unexpected module '..path)
end
dofile('ox_patch/void_currency.lua')
assert(exported.IsVoidCurrencyReady()==true)
assert(server.accounts.black_money==nil and inv.accounts.black_money==nil)
assert(labels.money.label=='Void' and labels.cash.label=='Void' and labels.black_money.label=='Dirty Money')
local converted,weight=inv.Load('stash','stash')
assert(converted[5].name=='money'and converted[5].label=='Void'and converted[5].count==40 and converted[5].slot==5)
assert(converted[5].weight==80 and weight==91)
assert(converted[1]==originalSlots[1] and converted[8]==originalSlots[8])
assert(originalSlots[5].name=='black_money'and originalSlots[5].weight==40 and originalSlots[5].label=='Dirty Money')
converted[5].metadata.tag.saved=false
assert(originalSlots[5].metadata.tag.saved==true)
currentSlots,currentWeight=converted,weight
local again,sameWeight=inv.Load('stash','stash')
assert(again==converted and sameWeight==weight and again[5].count==40)
print('PASS actual addon converts loaded container currency, preserves originals and idempotent reload')
currentSlots,currentWeight={[4]={name='black_money',count=1,slot=3,weight=1}},1
local ok=pcall(inv.Load,'stash','stash')
assert(not ok and currentSlots[4].name=='black_money')
print('PASS invalid container slot fails without mutating input')
server.accounts.black_money=0
assert(exported.IsVoidCurrencyReady()==false)
print('PASS addon readiness detects a competing dirty-account registry')

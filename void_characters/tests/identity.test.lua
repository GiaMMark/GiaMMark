-- Run from void_characters: lua tests/identity.test.lua (Lua 5.3+ / texlua).
function vector3(x,y,z) return {x=x,y=y,z=z} end
function vector4(x,y,z,w) return {x=x,y=y,z=z,w=w} end
dofile('config.lua')
dofile('shared/identity.lua')
local passed = 0
local today = {year=2026, month=10, day=28}
local function payload(overrides)
    local value = {firstname='André', lastname="D'Amico", dateofbirth='2000-02-29', sex='m', height=180, nationality='Italiana'}
    for k,v in pairs(overrides or {}) do value[k]=v end
    return value
end
local function test(name, values, expected)
    local result, err = VoidIdentity.validate(payload(values), today)
    assert((result ~= nil) == expected, name .. ': ' .. tostring(err))
    if not expected then assert(type(err)=='string' and #err>0, 'Missing validation error') end
    passed = passed + 1
end
test('accented names / leap date', {}, true)
test('trim leading and trailing whitespace', {firstname='  André  '}, true)
test('typographic apostrophe normalized', {lastname='D’Angelo'}, true)
test('script injection', {firstname='<script>'}, false)
test('control characters', {lastname='Ros\nsi'}, false)
test('invalid UTF-8', {firstname=string.char(255,254)}, false)
test('only separators', {lastname="--''"}, false)
test('name too long', {lastname=string.rep('x',17)}, false)
test('accented name byte length vs character length', {lastname=string.rep('é',16)}, true)
test('birthdate invalid leap', {dateofbirth='2001-02-29'}, false)
test('birthdate invalid month', {dateofbirth='2000-13-01'}, false)
test('birthdate invalid day', {dateofbirth='2000-04-31'}, false)
test('birthdate not ISO', {dateofbirth='29/02/2000'}, false)
test('birthday exactly min age', {dateofbirth='2008-10-28'}, true)
test('birthday tomorrow below min age', {dateofbirth='2008-10-29'}, false)
test('age exactly max', {dateofbirth='1926-10-28'}, true)
test('age above max', {dateofbirth='1925-10-28'}, false)
test('future date', {dateofbirth='2030-01-01'}, false)
test('height NaN', {height=0/0}, false)
test('height fractional', {height=180.5}, false)
test('height out of range', {height=999}, false)
test('height integer string', {height='175'}, true)
test('nationality outside allowlist', {nationality='Inventata'}, false)
test('invalid sex', {sex='admin'}, false)
local valid = VoidIdentity.validate(payload({firstname='  André  '}), today)
assert(valid.firstname=='André' and valid.lastname=="D'Amico", 'Sanitization corrupted name')
assert(not VoidIdentity.validate(false, today), 'Non-table payload accepted')
print(('identity: %d cases passed'):format(passed + 2))

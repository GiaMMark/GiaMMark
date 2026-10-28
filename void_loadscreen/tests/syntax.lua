-- Run from void_loadscreen: lua tests/syntax.lua (Lua 5.3+ / texlua).
local files = {'fxmanifest.lua', 'config.lua', 'shared.lua', 'server.lua', 'client.lua', 'tests/lifecycle.test.lua'}
for _, file in ipairs(files) do assert(loadfile(file)) end
print(('Syntax: %d Lua files compiled'):format(#files))

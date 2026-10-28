-- Compile every resource Lua file without executing FiveM natives.
local files = {
    'fxmanifest.lua', 'config.lua', 'shared/identity.lua',
    'server/bridge.lua', 'server/main.lua', 'client/integrations.lua', 'client/main.lua',
    'tests/identity.test.lua', 'tests/server.test.lua', 'tests/bridge.test.lua', 'tests/client.test.lua'
}
for _, file in ipairs(files) do assert(loadfile(file)) end
print(('syntax: %d Lua files compiled'):format(#files))

VoidLoadscreen = {}

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end

function VoidLoadscreen.publicConfig(playerName)
    local ui = Config.UI
    local result = {}
    for _, key in ipairs({'brand', 'appearance', 'tips', 'music', 'links', 'rules', 'labels', 'diagnostics'}) do
        result[key] = copy(ui[key])
    end
    if Config.ShowPlayerName and type(playerName) == 'string' and utf8.len(playerName) then
        local boundary = utf8.offset(playerName, 65)
        result.playerName = boundary and playerName:sub(1, boundary - 1) or playerName
    end
    return result
end

function VoidLoadscreen.validate()
    assert(type(Config.UI) == 'table', 'Config.UI deve essere una tabella.')
    assert(Config.Shutdown.Mode == 'auto' or Config.Shutdown.Mode == 'external' or Config.Shutdown.Mode == 'spawn', 'Config.Shutdown.Mode non valido.')
    for _, key in ipairs({'DelayMs', 'FadeMs'}) do
        local value = Config.Shutdown[key]
        assert(type(value) == 'number' and value == value and value >= 0 and value <= 10000, 'Config.Shutdown.' .. key .. ' deve essere tra 0 e 10000 ms.')
    end
end

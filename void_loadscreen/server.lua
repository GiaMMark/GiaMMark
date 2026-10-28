VoidLoadscreen.validate()

AddEventHandler('playerConnecting', function(playerName, _, deferrals)
    -- FiveM merges handover keys. Do not defer/done or alter other resources' data.
    deferrals.handover({void_loadscreen = VoidLoadscreen.publicConfig(playerName)})
end)

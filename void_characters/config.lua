Config = {}

-- auto detects qbx_core before qb-core, then es_extended. Never run two cores.
Config.Framework = 'auto' -- auto | esx | qb | qbox
Config.Debug = false
Config.Brand = { Name = 'VOID', Tagline = 'La tua storia inizia nel vuoto.' }

Config.Slots = {
    Default = 3,
    Max = 5,
    -- Server-side only. Full license identifier, never a player-supplied value.
    IdentifierOverrides = {} -- ['license:0123456789abcdef...'] = 5
}

Config.Identity = {
    MinNameLength = 2,
    MaxNameLength = 16, -- ESX stock columns are VARCHAR(16).
    MinAge = 18,
    MaxAge = 100,
    MinHeight = 140,
    MaxHeight = 210,
    Nationalities = { 'Italiana', 'Francese', 'Spagnola', 'Tedesca', 'Britannica', 'Americana', 'Altra' }
}

Config.AllowDelete = false -- Enable only after configuring cleanup for your resources.
Config.DeleteConfirmation = 'ELIMINA'

Config.Scene = {
    -- Isolated in a server-controlled routing bucket. No map/IPLs required.
    Ped = vector4(-75.16, -818.96, 326.18, 145.0),
    Camera = vector3(-78.32, -822.80, 327.10),
    LookAt = vector3(-75.16, -818.96, 327.00),
    Fov = 38.0,
    Time = { Hour = 0, Minute = 0 },
    Weather = 'CLEAR',
    MaleModel = 'mp_m_freemode_01',
    FemaleModel = 'mp_f_freemode_01'
}

Config.Spawn = {
    UseLastPosition = true,
    Default = vector4(-1037.72, -2737.87, 20.17, 328.0),
    -- direct | custom. A custom hook must return true only after spawning.
    Provider = 'direct',
    Custom = function(context) -- { character, isNew, position }
        -- Integrate housing/apartments/spawn selectors here, awaiting completion.
        return false
    end
}

Config.Appearance = {
    Provider = 'illenium-appearance', -- illenium-appearance | esx_skin (ESX only) | custom | none
    Creator = {
        ped = true, headBlend = true, faceFeatures = true, headOverlays = true,
        components = true, props = true, tattoos = true, enableExit = false
    },
    -- Only for custom. done(true) must mean appearance is saved by your script.
    Custom = function(context, done)
        done(false)
    end
}

Config.Notifications = {
    Provider = 'ox_lib', -- ox_lib | esx | qb | custom
    Custom = function(message, kind) end
}
Config.TextUI = {
    Provider = 'ox_lib', -- ox_lib | custom | none
    Position = 'right-center',
    CustomShow = function(text) end,
    CustomHide = function() end
}

Config.Server = {
    LoginTimeout = 20,
    SelectionBucketBase = 6000,
    RateLimitMs = 1000,
    ESXIdentifierPrefix = 'char',
    -- ESX has no portable delete-character API. Only these tables are touched.
    -- Add other tables used by your server before enabling deletion in production.
    -- All listed columns must contain the full ESX character identifier.
    ESXDeleteTables = { users = 'identifier' }
}

Config.Hooks = {
    -- Client-side: pause/resume your own time, weather, HUD or voice resource here.
    SelectionStarted = function() end,
    CharacterReady = function(context) end -- { character, isNew, framework }
}

-- A relog command is deliberately disabled: reconnect to change characters.
-- This avoids bypassing jail, combat, inventory and housing logout restrictions.

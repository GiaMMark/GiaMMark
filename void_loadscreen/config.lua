-- All these settings are PUBLIC and sent to the player's loading screen.
-- Do not put credentials, webhook URLs or private settings here.
Config = {}

Config.ShowPlayerName = true
Config.UI = {
    brand = {
        name = 'VOID',
        eyebrow = 'ROLEPLAY EXPERIENCE',
        tagline = 'Ogni storia\ninizia dal vuoto.',
        description = 'Una città. Infinite possibilità.\nLa prossima storia porta il tuo nome.'
    },
    appearance = {
        accent = '#ededed',
        background = '#090909',
        animation = true
    },
    tips = {
        enabled = true,
        intervalMs = 9000,
        items = {
            'Dai un’identità al tuo personaggio. Il resto arriva vivendo.',
            'Rispetta la storia degli altri: il roleplay si costruisce insieme.',
            'Durante il caricamento puoi regolare o disattivare la musica.'
        }
    },
    music = {
        enabled = true,
        autoplay = true, -- If the browser blocks autoplay, the player can press play.
        volume = 0.22,
        tracks = {
            { src = 'media/void-ambient.ogg', title = 'VOID / SIGNAL 01', artist = 'VOID' }
        }
    },
    -- Only HTTPS links. Empty by default: add your real server links.
    links = {}, -- { { label = 'DISCORD', url = 'https://discord.gg/your-invite' } }
    rules = {
        { title = 'Vivi il personaggio', text = 'Dai valore alla sua storia, alle sue scelte e alle conseguenze.' },
        { title = 'Rispetta gli altri', text = 'Costruisci scene credibili insieme agli altri giocatori.' },
        { title = 'Leggi il regolamento', text = 'Questi sono consigli introduttivi: consulta il regolamento completo del server prima di giocare.' }
    },
    labels = {
        connecting = 'Connessione al server',
        downloading = 'Download risorse',
        initializing = 'Inizializzazione',
        loadingMap = 'Caricamento mappa',
        ready = 'Pronto a entrare',
        waiting = 'Preparazione del personaggio'
    },
    diagnostics = false
}

Config.Shutdown = {
    -- auto: VOID Characters owns the transition when running; otherwise waits for
    -- playerSpawned / ESX / QB loaded. Stock selectors can close with their natives.
    -- external: your selector calls exports.void_loadscreen:Finish() when ready.
    -- spawn: always close on a supported spawn/loaded event.
    Mode = 'auto', -- auto | external | spawn
    DelayMs = 0,
    FadeMs = 500
}

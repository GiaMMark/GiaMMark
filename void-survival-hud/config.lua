Config = {}

-- Ogni giocatore può aprire l'editor. Nessun permesso ACE/staff richiesto.
Config.Command = 'hud'
Config.DefaultKey = 'F7'

Config.StressResource = 'jg-stress-addon'
Config.StatusResource = 'esx_status'
Config.HideOnPause = true
Config.HideWhileDead = false

Config.UpdateInterval = 250
Config.VehicleUpdateInterval = 100
Config.StatusInterval = 1000
Config.OxygenSeconds = 10.0 -- Adegua se un'altra risorsa cambia la capacità polmonare.
Config.TripTeleportDistance = 100.0 -- Metri massimi per campione, oltre: ignora lo spostamento.

-- Lascia Resource vuoto per il livello carburante nativo GTA.
-- Esempio: Resource = 'LegacyFuel', Export = 'GetFuel'. L'export deve restituire 0–100.
Config.Fuel = { Resource = '', Export = 'GetFuel' }

-- Valori iniziali per i player senza preferenze. Le scelte personali sono salvate
-- localmente dal client FiveM, separatamente per identificatore ESX/personaggio.
-- x/y sono percentuali dello schermo riferite all'angolo superiore sinistro.
Config.DefaultSettings = {
    version = 2,
    accent = '#a78bfa',
    secondary = '#67e8f9',
    opacity = 65,
    scale = 100,
    layout = 'row',
    showLabels = false,
    unit = 'kmh',
    widgets = { vitals = true, vehicle = true, voice = true },
    positions = {
        vitals = { x = 20, y = 90 },
        vehicle = { x = 78, y = 90 },
        voice = { x = 62, y = 90 }
    }
}

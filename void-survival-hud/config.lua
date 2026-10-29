Config = {}

-- Ogni giocatore può aprire l'editor. Nessun permesso ACE/staff richiesto.
Config.Command = 'hud'
Config.DefaultKey = 'F7'

Config.StressResource = 'jg-stress-addon'
Config.StatusResource = 'esx_status'
Config.HideOnPause = true
Config.HideWhileDead = false

-- La minimappa è disponibile soltanto se il personaggio possiede questo item.
-- auto: usa ox_inventory se installato; altrimenti legge l'inventario ESX.
-- Con ox_inventory fermo/in avvio resta nascosta per evitare dati ESX obsoleti.
-- Imposta Inventory = 'esx' per forzare l'inventario ESX standard.
Config.Minimap = {
    Enabled = true,
    Item = 'mappa',
    Inventory = 'auto', -- auto, esx, ox_inventory
    CheckInterval = 500 -- ms; gli eventi inventario anticipano il controllo.
}

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
    version = 3,
    accent = '#ff2028',
    secondary = '#f2f2f2',
    opacity = 90,
    scale = 100,
    layout = 'row',
    showLabels = false,
    showBackground = true,
    unit = 'kmh',
    widgets = { vitals = true, vehicle = true, voice = true },
    positions = {
        vitals = { x = 20, y = 90 },
        vehicle = { x = 78, y = 90 },
        voice = { x = 62, y = 90 }
    }
}

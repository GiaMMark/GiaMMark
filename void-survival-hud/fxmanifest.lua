fx_version 'cerulean'
game 'gta5'

author 'Void Survival HUD'
description 'HUD survival ESX con editor personale, stress JG e strumenti veicolo'
version '1.3.0'

ui_page 'html/index.html'

shared_script 'config.lua'
client_scripts {
    'client/main.lua',
    'client/minimap.lua'
}

files {
    'html/index.html',
    'html/styles.css',
    'html/app.js',
    'html/settings.js',
    'html/assets/void-logo.png'
}

dependency 'es_extended'

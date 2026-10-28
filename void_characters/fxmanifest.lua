fx_version 'cerulean'
game 'gta5'

name 'void_characters'
author 'VOID'
description 'VOID identity & multicharacter — ESX, QBCore, Qbox'
version '0.1.1'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/identity.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/main.lua'
}

client_scripts {
    'client/integrations.lua',
    'client/main.lua'
}

ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js' }

dependencies { 'ox_lib', 'oxmysql', '/onesync' }

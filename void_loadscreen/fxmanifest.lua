fx_version 'cerulean'
game 'gta5'

name 'void_loadscreen'
author 'VOID'
description 'VOID loading screen — standalone, minimal monochrome'
version '0.1.0'

loadscreen 'web/index.html'
loadscreen_cursor 'yes'
loadscreen_manual_shutdown 'yes'

shared_scripts { 'config.lua', 'shared.lua' }
server_script 'server.lua'
client_script 'client.lua'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/media/*.ogg',
    'web/media/*.mp3',
    'web/media/*.wav'
}

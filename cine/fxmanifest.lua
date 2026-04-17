fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'OpenCode'
description 'Cinematic stage runtime with setup loading, spawning, and synced playback'

files {
    'data/setups/*.json'
}

shared_script 'shared/util.lua'

dependency 'ox_lib'
dependency 'illenium-appearance'

server_scripts {
    'server/acl.lua',
    'server/repository.lua',
    'server/stages.lua',
    'server/spawn.lua',
    'server/playback.lua',
    'server/main.lua'
}

client_scripts {
    'client/context.lua',
    'client/world_lock.lua',
    'client/preloader.lua',
    'client/camera.lua',
    'client/timeline.lua',
    'client/main.lua'
}

fx_version 'cerulean'
game 'gta5'

author 'DrCannabis'
description '(Original Author Koala) Alternate version of max_rox_speedway edited by DrCannabis'

shared_scripts {
  '@ox_lib/init.lua',
  'config/config.lua',
  'locales/*.lua',           -- load your Lua locale modules
}

client_scripts {
  'client/c_fuel.lua',       -- <-- matches your filename
  'client/c_keys.lua',       -- centralized vehicle-keys support
  'client/c_customs.lua',    -- vehicle cosmetics & paints
  'client/c_function.lua',
  'client/c_main.lua',
  --'client/c_pit.lua',      -- pit stop system (WIP NOT READY)
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/s_main.lua',
}

ui_page 'client/nui/timeout.html'

files {
  'locales/*.lua',
  'client/nui/timeout.html',
}

dependencies {
    'ox_lib',
    'qb-core',
    'qb-target',
    'oxmysql',
}

lua54 'yes'

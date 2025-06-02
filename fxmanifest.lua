fx_version 'cerulean'

game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

author 'TiagoBranquinho'
description 'TB Water Wagon - Sistema otimizado de carroças de água'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'shared/*.lua', 'bridge/*.lua' }
client_scripts { 'client/*.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/*.lua' }

files { 'locales/*.json' }

dependencies { 'ox_lib', 'oxmysql', 'kd_stable' }
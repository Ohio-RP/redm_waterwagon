fx_version 'cerulean'

game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'

author 'Mr Terabyte'
description 'Simple script for redm servers for use a wagon as a water wagon..'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'shared/*.lua' }
client_scripts { 'bridge/cl_inventory.lua', 'client/*.lua'}
server_scripts { 'bridge/sv_inventory.lua', 'server/*.lua' }

files { 'locales/*.json' }

dependencies { 'ox_lib', 'vorp_inventory' }
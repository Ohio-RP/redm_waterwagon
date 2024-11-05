fx_version 'adamant'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

game 'rdr3'
lua54 'yes'
author 'Mr Terabyte'
description 'Simple scripts for redm servers for use a wagon as a water wagon..'
version '1.0.0'

shared_scripts {
	'config.lua',
	'language.lua'
}

client_scripts {
	'client.lua'
}

server_scripts {
	'server.lua'
}

dependencies {
    'vorp_inventory'
}
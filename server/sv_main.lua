lib.locale()

local Config = require 'shared.config'
local Functions = require 'shared.functions'
local Inventory = require 'bridge.sv_inventory'

local lastFillTime = {}

GlobalState.waterwagons = {}

-- Functions
local function getMaxCapacity(wagonType)
    return Config.waterWagons[wagonType] or 0
end

local function canFillWagon(source, wagonType, networkId)
    local playerPed = GetPlayerPed(source)
    local wagonEntity = NetworkGetEntityFromNetworkId(networkId)

    if not DoesEntityExist(wagonEntity) then return false, "Player ID: ".. source.." | Wagon does not exist" end
    if lastFillTime[source] and (os.time() - lastFillTime[source] < 5) then return false, "Player ID: ".. source .." | Cooldown active" end
    lastFillTime[source] = os.time()

    local playerCoords = GetEntityCoords(playerPed)
    local wagonCoords = GetEntityCoords(wagonEntity)
    if #(playerCoords - wagonCoords) > Config.interactionDistance + 1.0 then return false, "Player ID: ".. source .." | Too far from wagon" end

    local maxCapacity = getMaxCapacity(wagonType)
    if maxCapacity == 0 then return false, "Invalid wagon type" end
    if (GlobalState.waterwagons[networkId] or 0) >= maxCapacity then return false, "Player ID: ".. source .." | Wagon at max capacity" end

    return true
end

-- Events
RegisterServerEvent("tb_waterwagon:server:fillWagon", function(wagonType, networkId)
    local source = source
    local success, reason = canFillWagon(source, wagonType, networkId)

    if success then
        local updatedWaterwagons = GlobalState.waterwagons
        updatedWaterwagons[networkId] = (updatedWaterwagons[networkId] or 0) + 1
        GlobalState.waterwagons = updatedWaterwagons
    else
        Functions.DebugPrint('error', 'Filling failed: ' .. reason) 
    end
end)

RegisterServerEvent("tb_waterwagon:server:pourbacktoBucket", function(networkId)
    local source = source
    if not Config.standalone then
        if Inventory.hasItem(source, Config.emptyCan) then
            if GlobalState.waterwagons[networkId] and GlobalState.waterwagons[networkId] > 0 then
                local updatedWaterwagons = GlobalState.waterwagons
                updatedWaterwagons[networkId] = updatedWaterwagons[networkId] - 1
                GlobalState.waterwagons = updatedWaterwagons
                
                if Inventory.removeItem(source, Config.emptyCan, 1) then
                    Inventory.addItem(source, Config.filledCan, 1)
                end
                Functions.Notify(source, locale('waterbucketfilled'), 5000, 'success')
            else
                Functions.Notify(source, locale('wagonempty'), 5000, 'error')
            end
        else
            Functions.Notify(source, locale('needempty'), 5000, 'error')
        end
    else
        if GlobalState.waterwagons[networkId] and GlobalState.waterwagons[networkId] > 0 then
            local updatedWaterwagons = GlobalState.waterwagons
            updatedWaterwagons[networkId] = updatedWaterwagons[networkId] - 1
            GlobalState.waterwagons = updatedWaterwagons
            Functions.Notify(source, locale('waterbucketfilled'), 5000, 'success')
        else
            Functions.Notify(source, locale('wagonempty'), 5000, 'error')
        end
    end
end)

-- Callbacks
lib.callback.register('tb_waterwagons:server:checkWaterLevel', function(source, networkId)
    return GlobalState.waterwagons[networkId] or 0
end)
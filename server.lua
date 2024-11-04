local waterwagons = {}  -- Stores water levels of each wagon

-- Fill the water wagon from rivers
RegisterServerEvent("tb_waterwagon:sendwagonfillrequest")
AddEventHandler("tb_waterwagon:sendwagonfillrequest", function(wagonType, networkId)
    local source = source
    if not waterwagons[networkId] then
        waterwagons[networkId] = 0
    end
    if Config.waterwagons[wagonType] > waterwagons[networkId] then
        waterwagons[networkId] = waterwagons[networkId] + 1
        TriggerClientEvent("tb_waterwagon:recinfowagons", -1, waterwagons)
    end
end)

-- Handle request to pour water into the player's bucket
RegisterServerEvent("tb_waterwagon:requestPourWater")   
AddEventHandler("tb_waterwagon:requestPourWater", function(networkId)
    local source = source
    local hasBucket = exports.vorp_inventory:getItem(source, Config.emptycan)
    if hasBucket and hasBucket.count > 0 then
        if waterwagons[networkId] and waterwagons[networkId] > 0 then
            waterwagons[networkId] = waterwagons[networkId] - 1
            exports.vorp_inventory:subItem(source, Config.emptycan, 1)  -- Remove one empty bucket
            exports.vorp_inventory:addItem(source, Config.filledCan, 1)  -- Add filled can item
            TriggerClientEvent("tb_waterwagon:recinfowagons", -1, waterwagons)
            TriggerClientEvent("tb_waterwagon:pourWaterAnimation", source) -- Trigger animation on client after successful check
            TriggerClientEvent("vorp:TipRight", source, language.waterbucketfilled, 5000)
        end
    else
        TriggerClientEvent("vorp:TipRight", source, language.needempty, 5000)
    end
end)

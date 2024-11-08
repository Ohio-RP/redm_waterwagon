local Inventory = {}

local Config = require 'shared.config' 

function Inventory.hasItem(source, itemName, metadata)

    if Config.standalone then return true end -- If standalone mode is enabled, skip inventory check

    if GetResourceState("vorp_inventory") == "started" then
        local item = exports.vorp_inventory:getItem(source, itemName, metadata)
        return item and item.count > 0
    else
        -- Add compatibility for other inventory systems here if needed
        return false
    end
end

function Inventory.addItem(source, itemName, amount, metadata)

    if Config.standalone then return true end -- If standalone mode is enabled, skip inventory check

    if GetResourceState("vorp_inventory") == "started" then
        return exports.vorp_inventory:addItem(source, itemName, amount, metadata)
    else
        -- Add compatibility for other inventory systems here if needed
        return false
    end
end

function Inventory.removeItem(source, itemName, amount, metadata)

    if Config.standalone then return true end -- If standalone mode is enabled, skip inventory check

    if GetResourceState("vorp_inventory") == "started" then
        return exports.vorp_inventory:subItem(source, itemName, amount, metadata)
    else
        return false
    end
end

return Inventory

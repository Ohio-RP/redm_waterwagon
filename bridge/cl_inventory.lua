local Inventory = {}

function Inventory.hasItem(itemName)
    if GetResourceState("vorp_inventory") == "started" then
        return exports.vorp_inventory:GetItem(itemName)
    else
        -- Add compatibility for other inventory systems here if needed
        return false
    end
    return false
end

return Inventory
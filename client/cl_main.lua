local closewagon = nil

lib.locale()

local function isInWater(entity)
    return IsEntityInWater(entity)
end

local function getWagonWaterLevel(networkId)
    return GlobalState.waterwagons[networkId] or 0
end

if Config.oxTarget then
    for modelHash, maxCapacity in pairs(Config.waterWagons) do
        local options = {
            {
                name = 'water_level',
                icon = 'fas fa-info-circle',
                label = locale('checkLevel'),
                distance = Config.interactionDistance,
                onSelect = function(data)
                    local networkId = NetworkGetNetworkIdFromEntity(data.entity)
                    local waterLevel = getWagonWaterLevel(networkId)
                    Functions.Notify(nil, locale('waterLevel', waterLevel, maxCapacity), 5000, 'inform')
                end
            },
            {
                name = 'fill_wagon',
                icon = 'fas fa-tint',
                label = locale('fillwagon'),
                distance = Config.interactionDistance,
                canInteract = function(entity, distance, coords)
                    local networkId = NetworkGetNetworkIdFromEntity(entity)
                    local currentWaterLevel = getWagonWaterLevel(networkId)
                    return currentWaterLevel < maxCapacity and isInWater(cache.ped)
                end,
                onSelect = function(data)

                    if not Config.standalone then 
                        if not Inventory.hasItem(Config.emptyCan) then
                            Functions.Notify(nil, locale('noBucket'), 5000, 'error')
                            return
                        end
                    end

                    if Functions.playAnimation('fill') then
                        local networkId = NetworkGetNetworkIdFromEntity(data.entity)
                        TriggerServerEvent("tb_waterwagon:server:fillWagon", modelHash, networkId)
                    end
                end
            },
            {
                name = 'pour_water',
                icon = 'fas fa-water',
                label = locale('wagonwater'),
                distance = Config.interactionDistance,
                canInteract = function(entity, distance, coords)
                    local networkId = NetworkGetNetworkIdFromEntity(entity)
                    local currentWaterLevel = getWagonWaterLevel(networkId)
                    return currentWaterLevel > 0
                end,
                onSelect = function(data)

                    if not Config.standalone then 
                        if not Inventory.hasItem(Config.emptyCan) then
                            Functions.Notify(nil, locale('noBucket'), 5000, 'error')
                            return
                        end
                    end

                    if Functions.playAnimation('pour') then
                        local networkId = NetworkGetNetworkIdFromEntity(data.entity)
                        TriggerServerEvent("tb_waterwagon:server:pourbacktoBucket", networkId)
                    end
                end
            }
        }
        exports.ox_target:addModel(modelHash, options)
    end
else
    -- Use the old prompt system
    local prompts3 = UiPromptRegisterBegin() -- Unique group for water wagon prompts
    local fillwagon, wagonwater

    local function createPrompts()
        local str = CreateVarString(10, 'LITERAL_STRING', locale('fillwagon'))
        fillwagon = PromptRegisterBegin()
        PromptSetControlAction(fillwagon, Config.keys["G"])
        PromptSetText(fillwagon, str)
        PromptSetEnabled(fillwagon, 1)
        PromptSetStandardMode(fillwagon, 1)
        PromptSetGroup(fillwagon, prompts3)
        PromptRegisterEnd(fillwagon)

        str = CreateVarString(10, 'LITERAL_STRING', locale('wagonwater'))
        wagonwater = PromptRegisterBegin()
        PromptSetControlAction(wagonwater, Config.keys["ENTER"])
        PromptSetText(wagonwater, str)
        PromptSetEnabled(wagonwater, 1)
        PromptSetStandardMode(wagonwater, 1)
        PromptSetGroup(wagonwater, prompts3)
        PromptRegisterEnd(wagonwater)
    end

    createPrompts()

    CreateThread(function()
        while true do
            Wait(500)
            local ped = cache.ped
            local playerCoords = GetEntityCoords(ped)
            closewagon = GetClosestVehicle(playerCoords, 10.0, 0, 70)
        end
    end)

    CreateThread(function()
        while true do
            Wait(0)
            if closewagon then
                local ped = cache.ped
                local playerCoords = GetEntityCoords(ped)
                local model = GetEntityModel(closewagon)
                local wagonCoords = GetEntityCoords(closewagon)
                local distanceToWagon = #(playerCoords - wagonCoords)

                if distanceToWagon <= Config.interactionDistance then
                    for wagonType, maxCapacity in pairs(Config.waterWagons) do
                        if GetHashKey(wagonType) == model then
                            local networkId = NetworkGetNetworkIdFromEntity(closewagon)
                            local waterLevel = getWagonWaterLevel(networkId)

                            if waterLevel == 0 then
                                Functions.DrawText3D(wagonCoords.x, wagonCoords.y, wagonCoords.z + 1.0, "Carroça Vazia", waterLevel, maxCapacity)
                            elseif waterLevel == maxCapacity then
                                Functions.DrawText3D(wagonCoords.x, wagonCoords.y, wagonCoords.z + 1.0, "Carroça Cheia", waterLevel, maxCapacity)
                            else
                                Functions.DrawText3D(wagonCoords.x, wagonCoords.y, wagonCoords.z + 1.0, "Carroça de Água", waterLevel, maxCapacity)
                            end
                            PromptSetActiveGroupThisFrame(prompts3, CreateVarString(10, 'LITERAL_STRING', locale('waterwagon')))

                            -- LÓGICA CORRIGIDA: Prompt de ENCHER aparece quando carroça NÃO está cheia E jogador está na água
                            if waterLevel < maxCapacity and isInWater(ped) then
                                PromptSetVisible(fillwagon, true)
                                if UiPromptHasStandardModeCompleted(fillwagon) then

                                    if not Config.standalone then 
                                        if not Inventory.hasItem(Config.emptyCan) then
                                            Functions.Notify(nil, locale('noBucket'), 5000, 'error')
                                            return
                                        end
                                    end
                
                                    if Functions.playAnimation('fill') then
                                        TriggerServerEvent("tb_waterwagon:server:fillWagon", wagonType, networkId)
                                    end
                                end
                            else
                                PromptSetVisible(fillwagon, false)
                            end

                            -- LÓGICA CORRIGIDA: Prompt de RETIRAR ÁGUA aparece quando carroça TEM água
                            if waterLevel > 0 then
                                PromptSetVisible(wagonwater, true)
                                if UiPromptHasStandardModeCompleted(wagonwater) then
                                    
                                    if not Config.standalone then 
                                        if not Inventory.hasItem(Config.emptyCan) then
                                            Functions.Notify(nil, locale('noBucket'), 5000, 'error')
                                            return
                                        end
                                    end
                
                                    if Functions.playAnimation('pour') then
                                        TriggerServerEvent("tb_waterwagon:server:pourbacktoBucket", networkId)
                                    end
                                end
                            else
                                PromptSetVisible(wagonwater, false)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- TRSUT ME YOU DONT NEED TO TOUCH THIS LOL --
AddStateBagChangeHandler('waterwagons', 'global', function(_, _, value)
    for networkId, waterLevel in pairs(value) do
        Functions.DebugPrint('info', string.format("Wagon Water Level Data | Wagon ID: %d, Water Level: %d", networkId, waterLevel))
    end
end)

-- Event Handler for cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName) 
    if resourceName ~= cache.resource then return end
    ClearPedTasksImmediately(cache.ped)
    for modelHash, _ in pairs(Config.waterWagons) do
        exports.ox_target:removeModel(modelHash)
    end
end)

-- Função para verificar wagon mais próxima
local function getNearestWaterWagon(maxDistance)
    maxDistance = maxDistance or Config.interactionDistance
    local ped = cache.ped
    local playerCoords = GetEntityCoords(ped)
    local nearestWagon = nil
    local minDistance = maxDistance
    local wagonInfo = nil

    -- Procurar por todas as wagons próximas
    local wagon = GetClosestVehicle(playerCoords, maxDistance, 0, 70)
    if wagon and DoesEntityExist(wagon) then
        local wagonCoords = GetEntityCoords(wagon)
        local distance = #(playerCoords - wagonCoords)
        
        if distance <= minDistance then
            local model = GetEntityModel(wagon)
            local networkId = NetworkGetNetworkIdFromEntity(wagon)
            
            -- Verificar se é uma wagon de água
            for wagonType, maxCapacity in pairs(Config.waterWagons) do
                if GetHashKey(wagonType) == model then
                    local waterLevel = getWagonWaterLevel(networkId)
                    wagonInfo = {
                        entity = wagon,
                        networkId = networkId,
                        model = wagonType,
                        maxCapacity = maxCapacity,
                        waterLevel = waterLevel,
                        distance = distance,
                        coords = wagonCoords
                    }
                    break
                end
            end
        end
    end

    return wagonInfo
end

-- Export: Verificar wagon de água mais próxima
exports('getNearestWaterWagon', function(maxDistance)
    return getNearestWaterWagon(maxDistance)
end)

-- Export: Verificar se está perto de uma wagon de água
exports('isNearWaterWagon', function(maxDistance)
    local wagonInfo = getNearestWaterWagon(maxDistance)
    return wagonInfo ~= nil, wagonInfo
end)

-- Evento para verificar wagon mais próxima quando solicitado pelo servidor
RegisterNetEvent('tb_waterwagon:checkNearestWagon', function()
    local wagonInfo = getNearestWaterWagon()
    if wagonInfo then
        TriggerServerEvent('tb_waterwagon:setNearestWagon', wagonInfo)
    end
end)
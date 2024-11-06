local clientwaterwagons = {}
local closewagon = nil

-- Animation for filling water using WORLD_HUMAN_BUCKET_FILL
local function playFillAnimation()
    local playerPed = PlayerPedId()
    HidePedWeapons(playerPed, 2, true)  -- Hide any currently held items

    TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_BUCKET_FILL", 0, true)
    Citizen.Wait(5000)  -- Wait for animation to complete

    ClearPedTasks(playerPed)  -- Clear tasks after animation
    Wait(3000)  -- Smooth transition
    HidePedWeapons(playerPed, 2, true)  -- Ensure bucket is hidden
end

-- Animation for pouring water into a bucket
local function playPourAnimation()
    local playerPed = PlayerPedId()
    HidePedWeapons(playerPed, 2, true)  -- Hide any currently held items

    TaskStartScenarioInPlace(playerPed, joaat('WORLD_PLAYER_CHORES_BUCKET_PUT_DOWN_FULL'), 5000, true, false, false, false)

    ClearPedTasks(playerPed)  -- Clear tasks after animation
    Wait(3000)  -- Smooth transition
    HidePedWeapons(playerPed, 2, true)  -- Ensure bucket is hidden
end

-- Check if player is in water using IsEntityInWater
local function isInWater()
    return IsEntityInWater(PlayerPedId())
end

if Config.oxtarget then
    local registeredWagons = {}

    -- Register interaction points for ox_target
    local function setupWagonTarget(wagon)
        if registeredWagons[wagon] then return end  -- Skip if already registered
        registeredWagons[wagon] = true

        local model = GetEntityModel(wagon)
        local wagonCoords = GetEntityCoords(wagon)

        for wagonType, maxCapacity in pairs(Config.waterwagons) do
            if GetHashKey(wagonType) == model then

                local options = {}

                table.insert(options, {
                    name = 'water_level',
                    icon = 'fas fa-info-circle',
                    label = 'Check Water Level',
                    distance = Config.interactionDistance,
                    onSelect = function(data)
                        local networkId = NetworkGetNetworkIdFromEntity(data.entity)
                        local currentWaterLevel = clientwaterwagons[networkId] or 0
                        TriggerEvent("vorp:TipRight", language.waterLevel .. tostring(currentWaterLevel), 5000)
                    end
                        
                })
                
                table.insert(options, {
                    name = 'fill_wagon',
                    icon = 'fas fa-tint',
                    label = language.fillwagon,
                    distance = Config.interactionDistance,
                    canInteract = function(entity, distance, coords)
                        local networkId = NetworkGetNetworkIdFromEntity(entity)
                        local currentWaterLevel = clientwaterwagons[networkId] or 0
                        return currentWaterLevel < maxCapacity and isInWater()
                    end,
                    onSelect = function(data)
                        playFillAnimation()
                        local networkId = NetworkGetNetworkIdFromEntity(data.entity)
                        TriggerServerEvent("tb_waterwagon:sendwagonfillrequest", wagonType, networkId)
                    end
                })
                
                table.insert(options, {
                    name = 'pour_water',
                    icon = 'fas fa-water',
                    label = language.wagonwater,
                    distance = Config.interactionDistance,
                    canInteract = function(entity, distance, coords)
                        local networkId = NetworkGetNetworkIdFromEntity(entity)
                        local currentWaterLevel = clientwaterwagons[networkId] or 0
                        return currentWaterLevel > 0
                    end,
                    onSelect = function(data)
                        local networkId = NetworkGetNetworkIdFromEntity(data.entity)
                        TriggerServerEvent("tb_waterwagon:requestPourWater", networkId)
                    end
                })

                exports.ox_target:addLocalEntity(wagon, options)
            end
        end
    end

    -- Check for nearby wagons and set up target interactions
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(1000)  -- Check every second to avoid overloading
            local playerCoords = GetEntityCoords(PlayerPedId())
            local nearbyWagons = GetGamePool('CVehicle')

            for _, wagon in ipairs(nearbyWagons) do
                if DoesEntityExist(wagon) and GetEntityType(wagon) == 2 then
                    local model = GetEntityModel(wagon)
                    for wagonType, _ in pairs(Config.waterwagons) do
                        if GetHashKey(wagonType) == model then
                            setupWagonTarget(wagon)
                        end
                    end
                end
            end
        end
    end)
else
    -- Use the old prompt system
    local prompts3 = Citizen.InvokeNative(0x04F97DE45A519419) -- Unique group for water wagon prompts
    local fillwagon, wagonwater

    local function createPrompts()
        local str = CreateVarString(10, 'LITERAL_STRING', language.fillwagon)
        fillwagon = PromptRegisterBegin()
        PromptSetControlAction(fillwagon, Config.keys["G"])
        PromptSetText(fillwagon, str)
        PromptSetEnabled(fillwagon, 1)
        PromptSetStandardMode(fillwagon, 1)
        PromptSetGroup(fillwagon, prompts3)
        PromptRegisterEnd(fillwagon)

        str = CreateVarString(10, 'LITERAL_STRING', language.wagonwater)
        wagonwater = PromptRegisterBegin()
        PromptSetControlAction(wagonwater, Config.keys["ENTER"])
        PromptSetText(wagonwater, str)
        PromptSetEnabled(wagonwater, 1)
        PromptSetStandardMode(wagonwater, 1)
        PromptSetGroup(wagonwater, prompts3)
        PromptRegisterEnd(wagonwater)
    end

    createPrompts()

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(500)
            local playerCoords = GetEntityCoords(PlayerPedId())
            closewagon = GetClosestVehicle(playerCoords, 10.0, 0, 70)
        end
    end)

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(1)
            if closewagon ~= nil then
                local playerCoords = GetEntityCoords(PlayerPedId())
                local model = GetEntityModel(closewagon)
                local wagonCoords = GetEntityCoords(closewagon)
                local distanceToWagon = #(playerCoords - wagonCoords)

                if distanceToWagon <= Config.interactionDistance then
                    for wagonType, maxCapacity in pairs(Config.waterwagons) do
                        if GetHashKey(wagonType) == model then
                            local networkId = NetworkGetNetworkIdFromEntity(closewagon)
                            local waterLevel = clientwaterwagons[networkId] or 0

                            if waterLevel == 0 then
                                DrawText3D(wagonCoords.x, wagonCoords.y, wagonCoords.z + 1.0, language.wagonempty)
                            elseif waterLevel == maxCapacity then
                                DrawText3D(wagonCoords.x, wagonCoords.y, wagonCoords.z + 1.0, language.wagonfull)
                            else
                                DrawText3D(wagonCoords.x, wagonCoords.y, wagonCoords.z + 1.0, language.waterLevel .. tostring(waterLevel))
                            end
                            PromptSetActiveGroupThisFrame(prompts3, CreateVarString(10, 'LITERAL_STRING', language.waterwagon))

                            if waterLevel < maxCapacity and isInWater() then
                                PromptSetVisible(fillwagon, true)
                                if Citizen.InvokeNative(0xC92AC953F0A982AE, fillwagon) then
                                    playFillAnimation()
                                    TriggerServerEvent("tb_waterwagon:sendwagonfillrequest", wagonType, networkId)
                                end
                            else
                                PromptSetVisible(fillwagon, false)
                            end

                            if waterLevel > 0 then
                                PromptSetVisible(wagonwater, true)
                                if Citizen.InvokeNative(0xC92AC953F0A982AE, wagonwater) then
                                    TriggerServerEvent("tb_waterwagon:requestPourWater", networkId)
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

RegisterNetEvent("tb_waterwagon:pourWaterAnimation")
AddEventHandler("tb_waterwagon:pourWaterAnimation", function()
    playPourAnimation()
end)

-- Function to draw 3D text (not used with ox_target, kept for reference if needed)
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFontForCurrentCommand(1)
        DisplayText(CreateVarString(10, "LITERAL_STRING", text), _x, _y)
    end
end

-- Event to receive water wagon info from server
RegisterNetEvent("tb_waterwagon:recinfowagons")
AddEventHandler("tb_waterwagon:recinfowagons", function(wagonData)
    clientwaterwagons = wagonData
end)
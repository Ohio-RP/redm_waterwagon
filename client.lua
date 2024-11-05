local clientwaterwagons = {}
local closewagon = nil

-- Define prompts for interacting with water wagons
local fillwagon, wagonwater
local prompts3 = Citizen.InvokeNative(0x04F97DE45A519419) -- Unique group for water wagon prompts

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

-- Event to receive water wagon info from server
RegisterNetEvent("tb_waterwagon:recinfowagons")
AddEventHandler("tb_waterwagon:recinfowagons", function(wagonData)
    clientwaterwagons = wagonData
end)

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

    -- TaskStartScenarioInPlace(playerPed, "WORLD_PLAYER_CHORES_BUCKET_PUT_DOWN_FULL", 0, true)
    TaskStartScenarioInPlace(playerPed, joaat('WORLD_PLAYER_CHORES_BUCKET_PUT_DOWN_FULL'), 5000, true, false, false, false)

    ClearPedTasks(playerPed)  -- Clear tasks after animation
    Wait(3000)  -- Smooth transition
    HidePedWeapons(playerPed, 2, true)  -- Ensure bucket is hidden
end

-- Check if player is in water using IsEntityInWater
local function isInWater()
    return IsEntityInWater(PlayerPedId())
end

-- Check if player is close to any water wagon
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local playerCoords = GetEntityCoords(PlayerPedId())
        closewagon = GetClosestVehicle(playerCoords, 10.0, 0, 70)
    end
end)

-- Handle proximity-based interaction with water wagons
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1)
        if closewagon ~= nil then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local model = GetEntityModel(closewagon)
            local wagonCoords = GetEntityCoords(closewagon)
            local distanceToWagon = #(playerCoords - wagonCoords)

            -- Check if within interaction distance before showing prompts and text
            if distanceToWagon <= Config.interactionDistance then
                for wagonType, maxCapacity in pairs(Config.waterwagons) do
                    if GetHashKey(wagonType) == model then
                        local networkId = NetworkGetNetworkIdFromEntity(closewagon)
                        local waterLevel = clientwaterwagons[networkId] or 0

                        -- Show prompts and text if within range
                        if waterLevel == 0 then
                            DrawText3D(wagonCoords.x, wagonCoords.y, wagonCoords.z + 1.0, language.wagonempty)
                        elseif waterLevel == maxCapacity then
                            DrawText3D(wagonCoords.x, wagonCoords.y, wagonCoords.z + 1.0, language.wagonfull)
                        else
                            DrawText3D(wagonCoords.x, wagonCoords.y, wagonCoords.z + 1.0, language.waterLevel .. tostring(waterLevel))
                        end
                        PromptSetActiveGroupThisFrame(prompts3, CreateVarString(10, 'LITERAL_STRING', language.waterwagon))

                        -- Option to fill the water wagon (only if in or near water)
                        if waterLevel < maxCapacity and isInWater() then
                            PromptSetVisible(fillwagon, true)
                            if Citizen.InvokeNative(0xC92AC953F0A982AE, fillwagon) then
                                playFillAnimation()
                                TriggerServerEvent("tb_waterwagon:sendwagonfillrequest", wagonType, networkId)
                            end
                        else
                            PromptSetVisible(fillwagon, false)
                        end

                        -- Option to pour water into the player’s bucket
                        if waterLevel > 0 then
                            PromptSetVisible(wagonwater, true)
                            if Citizen.InvokeNative(0xC92AC953F0A982AE, wagonwater) then
                                -- Request server to check inventory before playing animation
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

RegisterNetEvent("tb_waterwagon:pourWaterAnimation")
AddEventHandler("tb_waterwagon:pourWaterAnimation", function()
    playPourAnimation()
end)

-- Function to draw 3D text
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFontForCurrentCommand(1)
        DisplayText(CreateVarString(10, "LITERAL_STRING", text), _x, _y)
    end
end

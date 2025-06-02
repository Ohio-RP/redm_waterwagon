lib.locale()

local lastFillTime = {}
local wagonIdToNetworkId = {} -- Mapear wagon ID para network ID
local networkIdToWagonId = {} -- Mapear network ID para wagon ID
local wagonWaterCache = {} -- Cache dos níveis de água

GlobalState.waterwagons = {}

-- Função para verificar se o modelo está no config
local function isWaterWagon(wagonModel)
    return Config.waterWagons[wagonModel] ~= nil
end

-- Função para obter dados da wagon do kd_stable
local function getWagonData(wagonID)
    return exports.kd_stable:getWagons(wagonID)
end

-- Função para salvar nível de água no banco
local function saveWaterLevel(wagonId, waterLevel)
    exports.oxmysql:execute([[
        INSERT INTO tb_waterwagon_levels (wagon_id, water_level) 
        VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE water_level = ?, last_updated = NOW()
    ]], {wagonId, waterLevel, waterLevel}, function(result)
        if result then
            Functions.DebugPrint('info', string.format("Nível de água salvo: Wagon ID %d = %d", wagonId, waterLevel))
        end
    end)
end

-- Função para carregar nível de água do banco
local function loadWaterLevel(wagonId, callback)
    -- Verificar cache primeiro
    if wagonWaterCache[wagonId] then
        Functions.DebugPrint('info', string.format("Carregado do cache: Wagon ID %d = %d", wagonId, wagonWaterCache[wagonId]))
        callback(wagonWaterCache[wagonId])
        return
    end
    
    exports.oxmysql:execute('SELECT water_level FROM tb_waterwagon_levels WHERE wagon_id = ?', 
        {wagonId}, function(result)
            local waterLevel = 0
            if result and result[1] then
                waterLevel = result[1].water_level
            end
            
            -- Salvar no cache
            wagonWaterCache[wagonId] = waterLevel
            Functions.DebugPrint('info', string.format("Carregado do banco: Wagon ID %d = %d", wagonId, waterLevel))
            callback(waterLevel)
        end)
end

-- Função para atualizar nível de água
local function updateWaterLevel(networkId, newLevel)
    local wagonId = networkIdToWagonId[networkId]
    
    -- Atualizar GlobalState
    local updatedWaterwagons = GlobalState.waterwagons
    updatedWaterwagons[networkId] = newLevel
    GlobalState.waterwagons = updatedWaterwagons
    
    -- Atualizar cache e banco se tivermos wagon ID
    if wagonId then
        wagonWaterCache[wagonId] = newLevel
        saveWaterLevel(wagonId, newLevel)
        Functions.DebugPrint('info', string.format("Água atualizada: Wagon ID %d, Network ID %d = %d", wagonId, networkId, newLevel))
    else
        Functions.DebugPrint('warning', string.format("Network ID %d não mapeado para wagon ID", networkId))
    end
end

-- Evento: Quando wagon é tirada do estábulo
exports.kd_stable:registerAction('spawnWagon', function(source, wagon, wagonID)
    -- Obter dados da wagon
    local wagonData = getWagonData(wagonID)
    if not wagonData then
        Functions.DebugPrint('error', string.format("Dados da wagon ID %d não encontrados", wagonID))
        return
    end
    
    -- Verificar se é uma wagon de água
    if not isWaterWagon(wagonData.model) then
        Functions.DebugPrint('info', string.format("Wagon '%s' (ID: %d) não é uma wagon de água. Ignorando...", wagonData.model, wagonID))
        return
    end
    
    local networkId = NetworkGetNetworkIdFromEntity(wagon)
    
    -- Registrar mapeamento
    wagonIdToNetworkId[wagonID] = networkId
    networkIdToWagonId[networkId] = wagonID
    
    -- Carregar nível de água do banco
    loadWaterLevel(wagonID, function(waterLevel)
        local updatedWaterwagons = GlobalState.waterwagons
        updatedWaterwagons[networkId] = waterLevel
        GlobalState.waterwagons = updatedWaterwagons
        
        Functions.DebugPrint('info', string.format("Wagon de água '%s' (ID: %d) spawnada com nível %d/%d", 
            wagonData.name or wagonData.model, wagonID, waterLevel, Config.waterWagons[wagonData.model]))
    end)
end)

-- Evento: Quando wagon é guardada no estábulo
exports.kd_stable:registerAction('stableWagon', function(source, wagonID, stableID)
    -- Obter dados da wagon
    local wagonData = getWagonData(wagonID)
    if not wagonData then
        Functions.DebugPrint('error', string.format("Dados da wagon ID %d não encontrados", wagonID))
        return
    end
    
    -- Verificar se é uma wagon de água
    if not isWaterWagon(wagonData.model) then
        Functions.DebugPrint('info', string.format("Wagon '%s' (ID: %d) não é uma wagon de água. Ignorando...", wagonData.model, wagonID))
        return
    end
    
    local networkId = wagonIdToNetworkId[wagonID]
    if networkId then
        -- Salvar último estado da água antes de guardar
        local currentLevel = GlobalState.waterwagons[networkId] or 0
        saveWaterLevel(wagonID, currentLevel)
        
        -- Limpar do GlobalState
        local updatedWaterwagons = GlobalState.waterwagons
        updatedWaterwagons[networkId] = nil
        GlobalState.waterwagons = updatedWaterwagons
        
        Functions.DebugPrint('info', string.format("Wagon de água '%s' (ID: %d) guardada no estábulo '%s' com nível %d", 
            wagonData.name or wagonData.model, wagonID, stableID, currentLevel))
    end
    
    -- Limpar mapeamentos
    if networkId then
        wagonIdToNetworkId[wagonID] = nil
        networkIdToWagonId[networkId] = nil
    end
end)

-- Cleanup quando resource para
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Salvar todos os níveis atuais antes de parar
    for networkId, waterLevel in pairs(GlobalState.waterwagons) do
        local wagonId = networkIdToWagonId[networkId]
        if wagonId then
            saveWaterLevel(wagonId, waterLevel)
            Functions.DebugPrint('info', string.format("Salvando estado final: Wagon ID %d = %d", wagonId, waterLevel))
        end
    end
    
    Functions.DebugPrint('info', "Resource parado. Estados salvos.")
end)

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
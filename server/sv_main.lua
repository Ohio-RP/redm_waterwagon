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
    if not wagonId then return end
    
    exports.oxmysql:execute([[
        INSERT INTO tb_waterwagon_levels (wagon_id, water_level) 
        VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE water_level = ?, last_updated = NOW()
    ]], {wagonId, waterLevel, waterLevel}, function(result)
        if result and result.affectedRows > 0 then
            Functions.DebugPrint('info', string.format("Nível de água salvo no banco: Wagon ID %d = %d", wagonId, waterLevel))
        else
            Functions.DebugPrint('error', string.format("Erro ao salvar nível de água: Wagon ID %d = %d", wagonId, waterLevel))
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
        Functions.DebugPrint('warning', string.format("Network ID %d não mapeado para wagon ID - Nível não será salvo no banco", networkId))
    end
end

-- Função para deletar dados da wagon do banco
local function deleteWagonData(wagonId)
    if not wagonId then return end
    
    exports.oxmysql:execute('DELETE FROM tb_waterwagon_levels WHERE wagon_id = ?', {wagonId}, function(result)
        if result and result.affectedRows > 0 then
            -- Limpar do cache também
            wagonWaterCache[wagonId] = nil
            Functions.DebugPrint('info', string.format("Dados da wagon ID %d deletados do banco e cache", wagonId))
        else
            Functions.DebugPrint('info', string.format("Nenhum dado encontrado para deletar da wagon ID %d", wagonId))
        end
    end)
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
    if not networkId then
        Functions.DebugPrint('error', string.format("Não foi possível obter Network ID para Wagon ID %d", wagonID))
        return
    end
    
    -- Registrar mapeamento
    wagonIdToNetworkId[wagonID] = networkId
    networkIdToWagonId[networkId] = wagonID
    
    Functions.DebugPrint('info', string.format("Mapeamento criado: Wagon ID %d -> Network ID %d", wagonID, networkId))
    
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
            
        -- Limpar mapeamentos
        wagonIdToNetworkId[wagonID] = nil
        networkIdToWagonId[networkId] = nil
        Functions.DebugPrint('info', string.format("Mapeamento removido: Wagon ID %d -> Network ID %d", wagonID, networkId))
    else
        Functions.DebugPrint('warning', string.format("Wagon ID %d não tinha mapeamento ao guardar", wagonID))
    end
end)

-- Evento: Quando wagon é deletada do estábulo
exports.kd_stable:registerAction('deleteWagon', function(source, wagonID)
    -- Obter dados da wagon
    local wagonData = getWagonData(wagonID)
    if not wagonData then
        Functions.DebugPrint('error', string.format("Dados da wagon ID %d não encontrados ao tentar deletar", wagonID))
        return
    end
    
    -- Verificar se é uma wagon de água
    if not isWaterWagon(wagonData.model) then
        Functions.DebugPrint('info', string.format("Wagon '%s' (ID: %d) não é uma wagon de água. Ignorando deleção...", wagonData.model, wagonID))
        return
    end
    
    -- Deletar dados da wagon
    deleteWagonData(wagonID)
    
    -- Limpar mapeamentos se existirem
    local networkId = wagonIdToNetworkId[wagonID]
    if networkId then
        -- Limpar do GlobalState se estiver ativa
        local updatedWaterwagons = GlobalState.waterwagons
        updatedWaterwagons[networkId] = nil
        GlobalState.waterwagons = updatedWaterwagons
        
        -- Limpar mapeamentos
        wagonIdToNetworkId[wagonID] = nil
        networkIdToWagonId[networkId] = nil
        
        Functions.DebugPrint('info', string.format("Mapeamentos removidos para wagon deletada: Wagon ID %d -> Network ID %d", wagonID, networkId))
    end
    
    Functions.DebugPrint('info', string.format("Wagon de água '%s' (ID: %d) deletada com sucesso", wagonData.name or wagonData.model, wagonID))
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
        local currentLevel = GlobalState.waterwagons[networkId] or 0
        local newLevel = currentLevel + 1
        
        -- Atualizar o nível usando a função updateWaterLevel
        updateWaterLevel(networkId, newLevel)
        
        Functions.DebugPrint('info', string.format("Wagon enchida: Network ID %d, Novo nível: %d", networkId, newLevel))
    else
        Functions.DebugPrint('error', 'Enchimento falhou: ' .. reason) 
    end
end)

RegisterServerEvent("tb_waterwagon:server:pourbacktoBucket", function(networkId)
    local source = source
    if not Config.standalone then
        if not Inventory.hasItem(source, Config.emptyCan) then
            Functions.Notify(source, locale('needempty'), 5000, 'error')
            return
        end
    end

    local currentLevel = GlobalState.waterwagons[networkId] or 0
    if currentLevel > 0 then
        -- Atualizar o nível usando a função updateWaterLevel
        local newLevel = currentLevel - 1
        updateWaterLevel(networkId, newLevel)
        
        if not Config.standalone then
            if Inventory.removeItem(source, Config.emptyCan, 1) then
                Inventory.addItem(source, Config.filledCan, 1)
            end
        end
        Functions.Notify(source, locale('waterbucketfilled'), 5000, 'success')
        
        Functions.DebugPrint('info', string.format("Água retirada: Network ID %d, Novo nível: %d", networkId, newLevel))
    else
        Functions.Notify(source, locale('wagonempty'), 5000, 'error')
    end
end)

-- Callbacks
lib.callback.register('tb_waterwagons:server:checkWaterLevel', function(source, networkId)
    return GlobalState.waterwagons[networkId] or 0
end)

-- Função para verificar se pode adicionar água
local function canAddWater(networkId, amount)
    if not networkId then return false, "Network ID inválido" end
    
    local wagonId = networkIdToWagonId[networkId]
    if not wagonId then return false, "Wagon não encontrada" end
    
    local wagonData = getWagonData(wagonId)
    if not wagonData then return false, "Dados da wagon não encontrados" end
    
    if not isWaterWagon(wagonData.model) then return false, "Não é uma wagon de água" end
    
    local currentLevel = GlobalState.waterwagons[networkId] or 0
    local maxCapacity = Config.waterWagons[wagonData.model]
    
    if currentLevel + amount > maxCapacity then
        return false, string.format("Capacidade excedida (Atual: %d, Máximo: %d)", currentLevel, maxCapacity)
    end
    
    return true
end

-- Export: Adicionar água à wagon
exports('addWagonWater', function(networkId, amount)
    amount = tonumber(amount) or 1
    if amount <= 0 then return false, "Quantidade inválida" end
    
    local success, reason = canAddWater(networkId, amount)
    if not success then
        Functions.DebugPrint('error', string.format("Falha ao adicionar água: %s", reason))
        return false, reason
    end
    
    local currentLevel = GlobalState.waterwagons[networkId] or 0
    local newLevel = currentLevel + amount
    updateWaterLevel(networkId, newLevel)
    
    Functions.DebugPrint('info', string.format("Água adicionada via export: Network ID %d, Quantidade: %d, Novo nível: %d", networkId, amount, newLevel))
    return true, newLevel
end)

-- Export: Remover água da wagon
exports('removeWagonWater', function(networkId, amount)
    amount = tonumber(amount) or 1
    if amount <= 0 then return false, "Quantidade inválida" end
    
    local currentLevel = GlobalState.waterwagons[networkId] or 0
    if currentLevel < amount then
        return false, string.format("Água insuficiente (Atual: %d, Solicitado: %d)", currentLevel, amount)
    end
    
    local newLevel = currentLevel - amount
    updateWaterLevel(networkId, newLevel)
    
    Functions.DebugPrint('info', string.format("Água removida via export: Network ID %d, Quantidade: %d, Novo nível: %d", networkId, amount, newLevel))
    return true, newLevel
end)

-- Export: Verificar nível de água
exports('getWagonWaterLevel', function(networkId)
    if not networkId then return false, "Network ID inválido" end
    
    local wagonId = networkIdToWagonId[networkId]
    if not wagonId then return false, "Wagon não encontrada" end
    
    local wagonData = getWagonData(wagonId)
    if not wagonData then return false, "Dados da wagon não encontrados" end
    
    if not isWaterWagon(wagonData.model) then return false, "Não é uma wagon de água" end
    
    local currentLevel = GlobalState.waterwagons[networkId] or 0
    local maxCapacity = Config.waterWagons[wagonData.model]
    
    Functions.DebugPrint('info', string.format("Nível verificado via export: Network ID %d, Nível: %d/%d", networkId, currentLevel, maxCapacity))
    return true, currentLevel, maxCapacity
end)

-- Export: Definir nível de água específico
exports('setWagonWaterLevel', function(networkId, level)
    level = tonumber(level)
    if not level or level < 0 then return false, "Nível inválido" end
    
    local wagonId = networkIdToWagonId[networkId]
    if not wagonId then return false, "Wagon não encontrada" end
    
    local wagonData = getWagonData(wagonId)
    if not wagonData then return false, "Dados da wagon não encontrados" end
    
    if not isWaterWagon(wagonData.model) then return false, "Não é uma wagon de água" end
    
    local maxCapacity = Config.waterWagons[wagonData.model]
    if level > maxCapacity then
        return false, string.format("Nível excede capacidade máxima (%d)", maxCapacity)
    end
    
    updateWaterLevel(networkId, level)
    
    Functions.DebugPrint('info', string.format("Nível definido via export: Network ID %d, Novo nível: %d", networkId, level))
    return true, level
end)

-- Export: Manipular wagon mais próxima do jogador
exports('handleNearestWaterWagon', function(source, action, amount)
    -- Trigger para o cliente verificar a wagon mais próxima
    local success, wagonInfo = lib.callback.await('tb_waterwagon:getNearestWagon', source)
    
    if not success or not wagonInfo then
        return false, "Nenhuma wagon de água próxima encontrada"
    end
    
    -- Verificar a ação solicitada
    if action == 'add' then
        return exports['redm_waterwagon']:addWagonWater(wagonInfo.networkId, amount)
    elseif action == 'remove' then
        return exports['redm_waterwagon']:removeWagonWater(wagonInfo.networkId, amount)
    elseif action == 'get' then
        return exports['redm_waterwagon']:getWagonWaterLevel(wagonInfo.networkId)
    elseif action == 'set' then
        return exports['redm_waterwagon']:setWagonWaterLevel(wagonInfo.networkId, amount)
    else
        return false, "Ação inválida"
    end
end)

-- Callback para obter informações da wagon mais próxima
lib.callback.register('tb_waterwagon:getNearestWagon', function(source)
    local success = pcall(function()
        TriggerClientEvent('tb_waterwagon:checkNearestWagon', source)
    end)
    if not success then
        return false, nil
    end
    return true, cache.nearestWagon
end)

-- Evento para receber informações da wagon do cliente
RegisterNetEvent('tb_waterwagon:setNearestWagon', function(wagonInfo)
    local source = source
    cache.nearestWagon = wagonInfo
end)
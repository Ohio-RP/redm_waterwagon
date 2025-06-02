# Implementação Otimizada - Water Wagon + kd_stable

## 🗄️ Estrutura da Tabela Separada

```sql
CREATE TABLE `tb_waterwagon_levels` (
  `wagon_id` int(11) NOT NULL,
  `water_level` int(11) NOT NULL DEFAULT 0,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`wagon_id`),
  FOREIGN KEY (`wagon_id`) REFERENCES `kd_wagons`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;
```

## 🔧 Arquivo Modificado: server/sv_main.lua

```lua
lib.locale()

local Config = require 'shared.config'
local Functions = require 'shared.functions'
local Inventory = require 'bridge.sv_inventory'

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
    
    -- Manter no cache para próximo spawn
    -- wagonWaterCache[wagonID] permanece para carregamento rápido
end)

-- Função para verificar se pode encher wagon
local function canFillWagon(source, wagonType, networkId)
    local playerPed = GetPlayerPed(source)
    local wagonEntity = NetworkGetEntityFromNetworkId(networkId)

    if not DoesEntityExist(wagonEntity) then return false, "Wagon não existe" end
    if lastFillTime[source] and (os.time() - lastFillTime[source] < 5) then return false, "Cooldown ativo" end
    lastFillTime[source] = os.time()

    local playerCoords = GetEntityCoords(playerPed)
    local wagonCoords = GetEntityCoords(wagonEntity)
    if #(playerCoords - wagonCoords) > Config.interactionDistance + 1.0 then return false, "Muito longe da wagon" end

    local maxCapacity = Config.waterWagons[wagonType] or 0
    if maxCapacity == 0 then return false, "Tipo de wagon inválido" end
    if (GlobalState.waterwagons[networkId] or 0) >= maxCapacity then return false, "Wagon na capacidade máxima" end

    return true
end

-- Evento: Encher wagon
RegisterServerEvent("tb_waterwagon:server:fillWagon", function(wagonType, networkId)
    local source = source
    local success, reason = canFillWagon(source, wagonType, networkId)

    if success then
        local currentLevel = GlobalState.waterwagons[networkId] or 0
        local newLevel = currentLevel + 1
        updateWaterLevel(networkId, newLevel)
        
        local wagonId = networkIdToWagonId[networkId]
        if wagonId then
            local wagonData = getWagonData(wagonId)
            local maxCapacity = Config.waterWagons[wagonType]
            Functions.DebugPrint('info', string.format("Wagon '%s' enchida: %d/%d", 
                wagonData and wagonData.name or "Desconhecida", newLevel, maxCapacity))
        end
    else
        Functions.DebugPrint('error', 'Enchimento falhou: ' .. reason) 
    end
end)

-- Evento: Despejar água da wagon
RegisterServerEvent("tb_waterwagon:server:pourbacktoBucket", function(networkId)
    local source = source
    
    if not Config.standalone then
        if not Inventory.hasItem(source, Config.emptyCan) then
            Functions.Notify(source, locale('needempty'), 5000, 'error')
            return
        end
    end
    
    local currentLevel = GlobalState.waterwagons[networkId] or 0
    if currentLevel <= 0 then
        Functions.Notify(source, locale('wagonempty'), 5000, 'error')
        return
    end
    
    -- Atualizar nível
    local newLevel = currentLevel - 1
    updateWaterLevel(networkId, newLevel)
    
    -- Processar inventário
    if not Config.standalone then
        if Inventory.removeItem(source, Config.emptyCan, 1) then
            Inventory.addItem(source, Config.filledCan, 1)
        end
    end
    
    Functions.Notify(source, locale('waterbucketfilled'), 5000, 'success')
    
    local wagonId = networkIdToWagonId[networkId]
    if wagonId then
        local wagonData = getWagonData(wagonId)
        Functions.DebugPrint('info', string.format("Água despejada da wagon '%s': %d restante", 
            wagonData and wagonData.name or "Desconhecida", newLevel))
    end
end)

-- Callback: Verificar nível de água
lib.callback.register('tb_waterwagons:server:checkWaterLevel', function(source, networkId)
    return GlobalState.waterwagons[networkId] or 0
end)

-- Callback: Obter informações das wagons de água do jogador
lib.callback.register('tb_waterwagons:server:getPlayerWaterWagons', function(source)
    local playerWagons = exports.kd_stable:getMyWagons(source)
    local waterWagons = {}
    
    if playerWagons then
        for _, wagon in pairs(playerWagons) do
            if isWaterWagon(wagon.model) then
                local waterLevel = 0
                if wagon.isOut then
                    -- Se está fora, pegar do GlobalState
                    local networkId = wagonIdToNetworkId[wagon.id]
                    if networkId then
                        waterLevel = GlobalState.waterwagons[networkId] or 0
                    end
                else
                    -- Se está no estábulo, pegar do cache/banco
                    waterLevel = wagonWaterCache[wagon.id] or 0
                end
                
                waterWagons[wagon.id] = {
                    name = wagon.name,
                    model = wagon.model,
                    maxCapacity = Config.waterWagons[wagon.model],
                    waterLevel = waterLevel,
                    isOut = wagon.isOut,
                    stable = wagon.stable
                }
            end
        end
    end
    
    return waterWagons
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
```

## 🎮 Comandos Administrativos

### server/sv_commands.lua
```lua
-- Comando para verificar nível de água de uma wagon específica
RegisterCommand('checkwagon', function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, 'waterwagon.admin') then return end
    
    local wagonId = tonumber(args[1])
    if not wagonId then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"WaterWagon", "Use: /checkwagon [wagon_id]"}
        })
        return
    end
    
    local wagonData = exports.kd_stable:getWagons(wagonId)
    if not wagonData then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"WaterWagon", "Wagon não encontrada!"}
        })
        return
    end
    
    if not Config.waterWagons[wagonData.model] then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 165, 0},
            multiline = true,
            args = {"WaterWagon", string.format("Wagon '%s' (ID: %d) não é uma wagon de água", wagonData.name, wagonId)}
        })
        return
    end
    
    exports.oxmysql:execute('SELECT water_level FROM tb_waterwagon_levels WHERE wagon_id = ?', 
        {wagonId}, function(result)
            local waterLevel = result and result[1] and result[1].water_level or 0
            local maxCapacity = Config.waterWagons[wagonData.model]
            
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = true,
                args = {"WaterWagon", string.format("Wagon '%s' (ID: %d) - Água: %d/%d | Status: %s", 
                    wagonData.name, wagonId, waterLevel, maxCapacity, wagonData.isOut and "Fora do estábulo" or "No estábulo")}
            })
        end)
end, false)

-- Comando para definir nível de água
RegisterCommand('setwagon', function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, 'waterwagon.admin') then return end
    
    local wagonId = tonumber(args[1])
    local waterLevel = tonumber(args[2])
    
    if not wagonId or not waterLevel then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"WaterWagon", "Use: /setwagon [wagon_id] [water_level]"}
        })
        return
    end
    
    local wagonData = exports.kd_stable:getWagons(wagonId)
    if not wagonData or not Config.waterWagons[wagonData.model] then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"WaterWagon", "Wagon não encontrada ou não é uma wagon de água!"}
        })
        return
    end
    
    local maxCapacity = Config.waterWagons[wagonData.model]
    if waterLevel < 0 or waterLevel > maxCapacity then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"WaterWagon", string.format("Nível deve ser entre 0 e %d", maxCapacity)}
        })
        return
    end
    
    -- Salvar no banco
    exports.oxmysql:execute([[
        INSERT INTO tb_waterwagon_levels (wagon_id, water_level) 
        VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE water_level = ?
    ]], {wagonId, waterLevel, waterLevel}, function(result)
        if result then
            -- Atualizar GlobalState se a wagon estiver ativa
            if wagonData.isOut then
                local networkId = wagonIdToNetworkId[wagonId]
                if networkId then
                    local updatedWaterwagons = GlobalState.waterwagons
                    updatedWaterwagons[networkId] = waterLevel
                    GlobalState.waterwagons = updatedWaterwagons
                end
            end
            
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = true,
                args = {"WaterWagon", string.format("Nível da wagon '%s' (ID: %d) definido para %d/%d", 
                    wagonData.name, wagonId, waterLevel, maxCapacity)}
            })
        end
    end)
end, false)

-- Comando para listar todas as wagons de água
RegisterCommand('listwagons', function(source, args, rawCommand)
    if not IsPlayerAceAllowed(source, 'waterwagon.admin') then return end
    
    exports.oxmysql:execute([[
        SELECT w.id, w.name, w.model, w.isOut, w.stable, wl.water_level, w.identifier
        FROM kd_wagons w
        LEFT JOIN tb_waterwagon_levels wl ON w.id = wl.wagon_id
        WHERE w.model IN (?) 
        ORDER BY w.id
    ]], {table.concat(table.keys(Config.waterWagons), ',')}, function(result)
        if result and #result > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 255},
                multiline = true,
                args = {"WaterWagon", "=== Wagons de Água Registradas ==="}
            })
            
            for _, wagon in ipairs(result) do
                local waterLevel = wagon.water_level or 0
                local maxCapacity = Config.waterWagons[wagon.model] or 0
                local status = wagon.isOut == 1 and "Ativa" or "Estabulada"
                
                TriggerClientEvent('chat:addMessage', source, {
                    color = {255, 255, 255},
                    multiline = true,
                    args = {"", string.format("ID: %d | '%s' | %s | Água: %d/%d | %s", 
                        wagon.id, wagon.name, wagon.model, waterLevel, maxCapacity, status)}
                })
            end
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 165, 0},
                multiline = true,
                args = {"WaterWagon", "Nenhuma wagon de água encontrada."}
            })
        end
    end)
end, false)
```

## 🔄 Fluxo Otimizado

### 1. Spawn da Wagon:
```
kd_stable dispara 'spawnWagon' → 
Verificar se modelo está no Config.waterWagons → 
Se SIM: Carregar nível do banco → Mapear IDs → Atualizar GlobalState
Se NÃO: Ignorar completamente
```

### 2. Interações (Encher/Despejar):
```
Player interage → 
Atualizar GlobalState → 
Salvar no banco usando mapeamento → 
Atualizar cache
```

### 3. Stable da Wagon:
```
kd_stable dispara 'stableWagon' → 
Verificar se modelo está no Config.waterWagons → 
Se SIM: Salvar estado final → Limpar GlobalState → Manter cache
Se NÃO: Ignorar completamente
```

## ✅ Vantagens da Implementação

- **Performance:** Só processa wagons que estão no config
- **Persistência:** Dados salvos automaticamente no banco
- **Cache:** Carregamento rápido com sistema de cache
- **Integração:** Funciona nativamente com kd_stable
- **Administração:** Comandos completos para gerenciamento
- **Debug:** Logs detalhados para troubleshooting


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
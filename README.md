# TB Water Wagon - Sistema Otimizado

## 📋 Descrição
Sistema otimizado de carroças de água para RedM, com integração nativa ao kd_stable, sistema de cache para melhor performance e exports para integração com outros scripts.

## ✨ Características
- Sistema de cache para melhor performance
- Integração nativa com kd_stable
- Persistência de dados em banco MySQL
- Sistema de debug detalhado
- Comandos administrativos
- Suporte a múltiplos sistemas de notificação (ox/vorp)
- Exports para integração com outros scripts
- Sistema de verificação de wagon próxima
- Interface visual com informações de nível de água

## 📦 Dependências
- ox_lib
- oxmysql
- kd_stable

## 🚀 Instalação

1. Copie a pasta para sua pasta de resources
2. Execute o arquivo `install.sql` no seu banco de dados
3. Adicione ao seu `server.cfg`:
```cfg
ensure ox_lib
ensure oxmysql
ensure kd_stable
ensure redm_waterwagon
```

4. Configure as permissões de admin no seu `server.cfg`:
```cfg
add_ace group.admin waterwagon.admin allow
```

## ⚙️ Configuração
Edite o arquivo `shared/config.lua` para configurar:

```lua
Config = {
    debug = true, -- Habilita ou desabilita o modo debug
    standalone = true, -- Define como true para modo standalone sem verificações de inventário
    oxTarget = false, -- Define como true para usar ox_target. False para usar prompts
    
    interactionDistance = 2.0, -- Distância para interagir com a wagon
    
    notify = 'vorp', -- Sistema de notificação ('ox', 'vorp' ou personalizado)
    
    filledCan = 'wateringcan', -- Item de regador cheio
    emptyCan = 'wateringcan_empty', -- Item de regador vazio
    
    waterWagons = { -- Modelos de wagon e capacidade máxima
        ["cart05"] = 3,
        ["oilWagon01x"] = 20,
    },
    
    keys = { -- Teclas de prompt
        ["G"] = 0x760A9C6F,
        ["ENTER"] = 0xC7B5340A,
    }
}
```

## 🛠️ Comandos Administrativos
- `/checkwagon [id]` - Verifica nível de água de uma wagon
- `/setwagon [id] [nivel]` - Define nível de água de uma wagon
- `/listwagons` - Lista todas as wagons de água registradas

## 📡 Exports

### Exports do Cliente

1. **Verificar Wagon Próxima**
```lua
-- Retorna se há uma wagon próxima e suas informações
-- @param maxDistance: distância máxima para procurar (opcional, padrão: Config.interactionDistance)
-- @return success: boolean, wagonInfo: table ou nil
local isNear, wagonInfo = exports['redm_waterwagon']:isNearWaterWagon(2.0)

-- Estrutura do wagonInfo:
{
    entity = entityId,      -- ID da entidade da wagon
    networkId = netId,      -- ID de rede da wagon
    model = "cart05",       -- Modelo da wagon
    maxCapacity = 3,        -- Capacidade máxima
    waterLevel = 2,         -- Nível atual de água
    distance = 1.5,         -- Distância do jogador
    coords = vector3(x,y,z) -- Coordenadas da wagon
}
```

2. **Obter Wagon Mais Próxima**
```lua
-- Retorna informações detalhadas da wagon mais próxima
-- @param maxDistance: distância máxima para procurar
-- @return wagonInfo: table ou nil
local wagonInfo = exports['redm_waterwagon']:getNearestWaterWagon(2.0)
```

### Exports do Servidor

1. **Manipular Água**
```lua
-- Adicionar água à wagon
-- @param networkId: ID de rede da wagon
-- @param amount: quantidade de água (opcional, padrão: 1)
-- @return success: boolean, result: número ou mensagem de erro
exports['redm_waterwagon']:addWagonWater(networkId, amount)

-- Remover água da wagon
-- @param networkId: ID de rede da wagon
-- @param amount: quantidade de água (opcional, padrão: 1)
-- @return success: boolean, result: número ou mensagem de erro
exports['redm_waterwagon']:removeWagonWater(networkId, amount)

-- Verificar nível de água
-- @param networkId: ID de rede da wagon
-- @return success: boolean, currentLevel: número, maxCapacity: número
exports['redm_waterwagon']:getWagonWaterLevel(networkId)

-- Definir nível de água
-- @param networkId: ID de rede da wagon
-- @param level: nível desejado
-- @return success: boolean, result: número ou mensagem de erro
exports['redm_waterwagon']:setWagonWaterLevel(networkId, level)
```

2. **Manipular Wagon Próxima**
```lua
-- Manipular a wagon mais próxima do jogador
-- @param source: ID do jogador
-- @param action: 'add', 'remove', 'get' ou 'set'
-- @param amount: quantidade (para add/remove/set)
-- @return success: boolean, result: número ou mensagem de erro
exports['redm_waterwagon']:handleNearestWaterWagon(source, action, amount)
```

## 🔍 Debug
O sistema inclui logs detalhados para:
- Spawn/despawn de wagons
- Alterações nos níveis de água
- Carregamento de cache
- Operações de banco de dados
- Erros e avisos
- Uso de exports
- Mapeamento de IDs

Para ativar o debug, defina `debug = true` no arquivo de configuração.

## 📝 Exemplos de Uso

### Exemplo 1: Encher Wagon Próxima
```lua
RegisterCommand('encherwagon', function(source, args)
    local amount = tonumber(args[1]) or 1
    local success, result = exports['redm_waterwagon']:handleNearestWaterWagon(source, 'add', amount)
    
    if success then
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            args = {"WaterWagon", "Água adicionada! Novo nível: " .. result}
        })
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            args = {"WaterWagon", "Erro: " .. result}
        })
    end
end)
```

### Exemplo 2: Verificar Wagon Próxima (Cliente)
```lua
CreateThread(function()
    while true do
        Wait(1000)
        local isNear, wagonInfo = exports['redm_waterwagon']:isNearWaterWagon(3.0)
        if isNear then
            print(string.format("Wagon próxima: %s | Água: %d/%d", 
                wagonInfo.model, 
                wagonInfo.waterLevel, 
                wagonInfo.maxCapacity
            ))
        end
    end
end)
```

## 🔒 Segurança
O sistema inclui várias verificações de segurança:
- Validação de permissões para comandos admin
- Verificação de propriedade das wagons
- Proteção contra exploits de distância
- Validação de dados do banco
- Sanitização de inputs
- Verificações de limites de água

## 🤝 Suporte e Contribuição
- Discord: TiagoBranquinho
- GitHub Issues: [Reportar Problemas]
- Pull Requests: [Contribuir]

## 📄 Licença
Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🔄 Changelog
### v1.0.0
- Lançamento inicial
- Sistema de cache
- Integração com kd_stable
- Comandos administrativos
- Sistema de exports
- Verificação de wagon próxima
# TB Water Wagon - Sistema Otimizado

## 📋 Descrição
Sistema otimizado de carroças de água para RedM, com integração nativa ao kd_stable e sistema de cache para melhor performance.

## ✨ Características
- Sistema de cache para melhor performance
- Integração nativa com kd_stable
- Persistência de dados em banco MySQL
- Sistema de debug detalhado
- Comandos administrativos
- Suporte a múltiplos sistemas de notificação (ox/vorp)

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
- Modelos de wagon e capacidade máxima
- Sistema de notificação (ox/vorp)
- Modo debug
- Distância de interação
- Items necessários

## 🛠️ Comandos Administrativos
- `/checkwagon [id]` - Verifica nível de água de uma wagon
- `/setwagon [id] [nivel]` - Define nível de água de uma wagon
- `/listwagons` - Lista todas as wagons de água registradas

## 🔍 Debug
O sistema inclui logs detalhados para:
- Spawn/despawn de wagons
- Alterações nos níveis de água
- Carregamento de cache
- Operações de banco de dados
- Erros e avisos

Para ativar o debug, defina `debug = true` no arquivo de configuração.

## 📄 Licença
Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 🤝 Suporte
Para suporte, entre em contato através do Discord: TiagoBranquinho
Config = {
    debug = true, -- Habilita ou desabilita o modo debug
    standalone = true,  -- Define como true para modo standalone sem verificações de inventário
    oxTarget = false, -- Define como true para usar ox_target. False para usar prompts
    
    interactionDistance = 2, -- Distância para ver drawtext e prompt para wagon

    notify = 'vorp', -- Sistema de notificação | 'ox' , 'vorp' ou personalizado

    filledCan = 'wateringcan', -- Item de regador cheio
    emptyCan = 'wateringcan_empty', -- Item de regador vazio

    waterWagons = { -- Modelos de wagon de água e seus níveis máximos de água
        ["cart05"] = 3,
        ["oilWagon01x"] = 20,
    },

    keys = {  -- Teclas de prompt
        ["G"] = 0x760A9C6F,
        ["ENTER"] = 0xC7B5340A,
    }
}

Functions = {}


-----------------------------------
------ Debug Print Function -------
-----------------------------------
function Functions.DebugPrint(level, text, ...)
    if not Config.debug then return end
    local args = {...}
    local formattedText = string.format(text, table.unpack(args))
    local levelPrefix = '^3[INFO]^7 |'
    if level == 'error' then levelPrefix = '^1[ERROR]^7 |'
    elseif level == 'warning' then levelPrefix = '^3[WARN]^7 |' end
    print('^3[TB WATERWAGON]^7 | ^3[DEBUG]^7 | ' .. levelPrefix .. ' ' .. formattedText)
end

-----------------------------------
------ Draw Text 3D Function ------
-----------------------------------
function Functions.DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFontForCurrentCommand(1)
        DisplayText(CreateVarString(10, "LITERAL_STRING", text), _x, _y)
    end
end

-----------------------------------
----- Play Animation Function -----
-----------------------------------
local isPlayingDefinedScenario = false
function Functions.playAnimation(animationType)
    local playerPed = cache.ped
    if isPlayingDefinedScenario then 
        Functions.DebugPrint('info', 'Player já está em um cenário. Retornando...') 
        return 
    end
    isPlayingDefinedScenario = true
    ClearPedTasksImmediately(playerPed) 
    HidePedWeapons(playerPed, 2, true)

    local scenarios = {
        fill = {scenario = `WORLD_HUMAN_BUCKET_FILL`, delay = 3500, postWait = 4000, secpostWait = 3500},
        pour = {scenario = `WORLD_PLAYER_CHORES_BUCKET_PUT_DOWN_FULL`, delay = 0, postWait = 4000, secpostWait = 0}
    }
    
    local anim = scenarios[animationType]
    if anim then
        TaskStartScenarioInPlaceHash(playerPed, anim.scenario, anim.delay, true)
        Wait(anim.postWait)
        ClearPedTasks(playerPed)
        Wait(anim.secpostWait)
        HidePedWeapons(playerPed, 2, true)
        
        isPlayingDefinedScenario = false
        return true
    end
    Functions.DebugPrint('error', 'Cenário inválido ou não listado.')
    isPlayingDefinedScenario = false
    return false
end

-----------------------------------
--------- Notify Function ---------
-----------------------------------
function Functions.Notify(source, message, duration, msgType)
    if source == nil then
        if Config.notify == 'ox' then
            lib.notify({description = message, duration = duration, type = msgType, position = 'center-right'})
        elseif Config.notify == 'vorp' then
            TriggerEvent("vorp:TipRight", message, duration)
        else
            Functions.DebugPrint('error', 'Você precisa configurar isso para seu sistema de notificação.')
        end
    else
        if Config.notify == 'ox' then
            TriggerClientEvent('ox_lib:notify', source, {description = message, duration = duration, type = msgType, position = 'center-right'})
        elseif Config.notify == 'vorp' then
            TriggerClientEvent("vorp:TipRight", source, message, duration)
        else
            Functions.DebugPrint('error', 'Você precisa configurar isso para seu sistema de notificação.')
        end
    end
end

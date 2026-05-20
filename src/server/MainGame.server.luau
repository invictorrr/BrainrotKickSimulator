--[[
    MainGame - Script principal del servidor
    Conecta PlayerData, GameConfig, RemoteEvents y maneja toda la lógica del juego
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)
local PlayerData = require(game.ServerScriptService.PlayerData)
local BrainrotSystem = require(game.ServerScriptService.BrainrotSystem)
local RemoteEvents = ReplicatedStorage.RemoteEvents

-- ═══════════════════════════════════════════
-- REFERENCIAS AL MAPA
-- ═══════════════════════════════════════════
local brainrotsModels = workspace:FindFirstChild("brainrotsmodels")
local zonesFolder = workspace:FindFirstChild("Zones") or Instance.new("Folder")
if not zonesFolder.Parent then
    zonesFolder.Name = "Zones"
    zonesFolder.Parent = workspace
end

-- ═══════════════════════════════════════════
-- POSICIONES DE LAS ZONAS (porterías)
-- ═══════════════════════════════════════════
local zonePositions = {
    [1] = CFrame.new(0, 0, 0),
    [2] = CFrame.new(200, 0, 0),
    [3] = CFrame.new(400, 0, 0),
}

-- ═══════════════════════════════════════════
-- SETUP INICIAL DE ZONAS (solo si no existen ya)
-- ═══════════════════════════════════════════
local function setupZone(zoneId)
    local zoneData = GameConfig.Zones[zoneId]
    if not zoneData then return end

    local zoneModel = zonesFolder:FindFirstChild("Zone" .. tostring(zoneId))
    if zoneModel then
        -- Zona ya existe (creada manualmente), solo verificar portería
        local goal = zoneModel:FindFirstChild("Goal_Zone" .. tostring(zoneId))
        if not goal then
            -- Crear portería si falta
            local goalPos = zonePositions[zoneId] or CFrame.new(0, 0, 0)
            goal = BrainrotSystem.CreateGoal(zoneId, goalPos)
            if goal then goal.Parent = zoneModel end
        end
        return
    end

    -- Crear zona si no existe
    zoneModel = Instance.new("Model")
    zoneModel.Name = "Zone" .. tostring(zoneId)
    zoneModel.Parent = zonesFolder

    local goalPos = zonePositions[zoneId] or CFrame.new(0, 0, 0)

    local goal = BrainrotSystem.CreateGoal(zoneId, goalPos)
    if goal then goal.Parent = zoneModel end

    local markers = BrainrotSystem.CreateDistanceMarkers(zoneId, goalPos)
    for _, marker in ipairs(markers) do
        marker.Parent = zoneModel
    end

    local floor = Instance.new("Part")
    floor.Name = "Floor"
    floor.Size = Vector3.new(60, 1, zoneData.maxDistance + 20)
    floor.CFrame = goalPos * CFrame.new(0, -0.5, -(zoneData.maxDistance + 20) / 2)
    floor.Color = Color3.fromRGB(50, 120, 50)
    floor.Material = Enum.Material.Grass
    floor.Anchored = true
    floor.Parent = zoneModel

    zoneModel:PivotTo(goalPos)
end

for zoneId, _ in pairs(GameConfig.Zones) do
    setupZone(zoneId)
end

-- ═══════════════════════════════════════════
-- ESTADO POR JUGADOR (runtime)
-- ═══════════════════════════════════════════
local playerRuntimeState = {} -- datos que NO se guardan (posición de patada, portero actual, etc.)

local function getRuntime(player)
    if not playerRuntimeState[player.UserId] then
        playerRuntimeState[player.UserId] = {
            kickDistance = nil,       -- distancia seleccionada para patear
            currentGoalkeeper = nil,  -- brainrot que está de portero actualmente
            isKicking = false,        -- está en proceso de patada
            baseIncomeAccumulated = 0, -- income acumulado sin reclamar
        }
    end
    return playerRuntimeState[player.UserId]
end

-- ═══════════════════════════════════════════
-- ENVIAR STATS AL CLIENTE
-- ═══════════════════════════════════════════
local function sendStats(player)
    local data = PlayerData.GetData(player)
    if not data then return end

    local ballData = GameConfig.BallShop[data.ballLevel]
    local ballMultiplier = ballData and ballData.multiplier or 1
    local baseIncome = PlayerData.CalculateBaseIncome(player)

    RemoteEvents.UpdateStats:FireClient(player, {
        coins = data.coins,
        power = data.power,
        ballLevel = data.ballLevel,
        ballName = ballData and ballData.name or "Balón Básico",
        ballMultiplier = ballMultiplier,
        rebirths = data.rebirths,
        rebirthMultiplier = data.rebirthMultiplier,
        currentZone = data.currentZone,
        totalGoals = data.totalGoals,
        totalKicks = data.totalKicks,
        baseIncomePerSec = baseIncome,
        brainrotCount = #data.brainrots,
    })
end

-- ═══════════════════════════════════════════
-- SISTEMA DE PATADA
-- ═══════════════════════════════════════════

-- Cuando el jugador selecciona su posición de patada
RemoteEvents.SetKickPosition.OnServerEvent:Connect(function(player, distance)
    local data = PlayerData.GetData(player)
    if not data then return end

    local zoneId = data.currentZone
    local zone = GameConfig.Zones[zoneId]
    if not zone then return end

    -- Validar distancia
    distance = math.clamp(distance, zone.minDistance, zone.maxDistance)

    local runtime = getRuntime(player)
    runtime.kickDistance = distance

    -- Seleccionar portero brainrot basado en zona y distancia
    local goalkeeper = GameConfig.SelectRandomBrainrot(zoneId, distance)
    if not goalkeeper then return end

    runtime.currentGoalkeeper = goalkeeper

    -- Enviar al cliente: mostrar siluetas y luego revelar portero
    RemoteEvents.ShowGoalkeepers:FireClient(player, {
        zoneId = zoneId,
        distance = distance,
        goalkeeperId = goalkeeper.id,
        goalkeeperName = goalkeeper.name,
        isBoss = goalkeeper.isBoss or false,
        rarity = goalkeeper.rarity,
    })

    -- Spawn visual de siluetas → revelación en el mundo 3D
    local zoneModel = zonesFolder:FindFirstChild("Zone" .. tostring(zoneId))
    if zoneModel then
        local goal = zoneModel:FindFirstChild("Goal_Zone" .. tostring(zoneId))
        if goal then
            local goalPos = goal:GetPivot()
            -- Limpiar porteros anteriores
            for _, child in zoneModel:GetChildren() do
                if child.Name == "GoalkeeperSilhouette" or child.Name == "RevealedGoalkeeper" then
                    child:Destroy()
                end
            end
            BrainrotSystem.SpawnGoalkeeperSequence(goalPos, goalkeeper, zoneModel)
        end
    end
end)

-- Cuando el jugador patea (suelta el indicador de fuerza)
RemoteEvents.KickBall.OnServerEvent:Connect(function(player, indicatorZone)
    local data = PlayerData.GetData(player)
    if not data then return end

    local runtime = getRuntime(player)
    if not runtime.kickDistance or not runtime.currentGoalkeeper then
        return -- No ha seleccionado posición
    end

    if runtime.isKicking then return end -- Anti-spam
    runtime.isKicking = true

    local zoneId = data.currentZone
    local zone = GameConfig.Zones[zoneId]
    local distance = runtime.kickDistance
    local goalkeeper = runtime.currentGoalkeeper
    local ballData = GameConfig.BallShop[data.ballLevel]
    local ballMultiplier = ballData and ballData.multiplier or 1

    -- Goal streak tracking
    if not runtime.goalStreak then runtime.goalStreak = 0 end

    PlayerData.IncrementKicks(player)

    local result = "miss" -- por defecto
    local coinsEarned = 0
    local capturedBrainrot = nil

    -- Validar que indicatorZone es válido
    if indicatorZone ~= "green" and indicatorZone ~= "yellow" and indicatorZone ~= "red" then
        indicatorZone = "red" -- fallback seguro
    end

    if indicatorZone == "red" then
        -- Zona roja: balón no llega a portería
        result = "miss"
        runtime.goalStreak = 0

    elseif indicatorZone == "green" then
        -- Zona verde: gol seguro SI tienes potencia suficiente para el portero
        if goalkeeper.isBoss and data.power < goalkeeper.minPower then
            -- Boss: no tienes suficiente potencia, te para seguro
            result = "saved"
            runtime.goalStreak = 0
        else
            result = "goal"
            runtime.goalStreak = runtime.goalStreak + 1
            local streakBonus = 1 + (runtime.goalStreak - 1) * 0.1 -- 10% per consecutive goal
            coinsEarned = math.floor(GameConfig.CalculateGoalCoins(distance, zoneId, ballMultiplier, data.rebirthMultiplier) * streakBonus)
            capturedBrainrot = goalkeeper
            PlayerData.AddCoins(player, coinsEarned)
            PlayerData.AddBrainrot(player, goalkeeper.id)
            PlayerData.IncrementGoals(player)
        end

    elseif indicatorZone == "yellow" then
        -- Zona amarilla: probabilidad de gol basada en suerte (distancia)
        if goalkeeper.isBoss and data.power < goalkeeper.minPower then
            -- Boss: sin potencia suficiente, siempre para
            result = "saved"
            runtime.goalStreak = 0
        else
            local goalProb = GameConfig.CalculateYellowGoalProbability(distance, zoneId)
            if math.random() < goalProb then
                result = "goal"
                runtime.goalStreak = runtime.goalStreak + 1
                local streakBonus = 1 + (runtime.goalStreak - 1) * 0.1
                coinsEarned = math.floor(GameConfig.CalculateGoalCoins(distance, zoneId, ballMultiplier, data.rebirthMultiplier) * streakBonus)
                capturedBrainrot = goalkeeper
                PlayerData.AddCoins(player, coinsEarned)
                PlayerData.AddBrainrot(player, goalkeeper.id)
                PlayerData.IncrementGoals(player)
            else
                result = "saved"
                runtime.goalStreak = 0
            end
        end
    end

    -- Efectos visuales en el mundo 3D
    local zoneModel = zonesFolder:FindFirstChild("Zone" .. tostring(zoneId))
    if zoneModel then
        local goal = zoneModel:FindFirstChild("Goal_Zone" .. tostring(zoneId))
        if goal then
            local goalPos = goal:GetPivot()
            if result == "goal" then
                BrainrotSystem.PlayGoalEffect(goalPos)
            elseif result == "saved" then
                local gk = zoneModel:FindFirstChild("RevealedGoalkeeper")
                if gk then
                    BrainrotSystem.PlaySaveAnimation(gk)
                end
            end
        end
    end

    -- Enviar resultado al cliente
    RemoteEvents.GoalResult:FireClient(player, {
        result = result,
        coinsEarned = coinsEarned,
        capturedBrainrot = capturedBrainrot and {
            id = capturedBrainrot.id,
            name = capturedBrainrot.name,
            rarity = capturedBrainrot.rarity,
            coinsPerSec = capturedBrainrot.coinsPerSec,
        } or nil,
        distance = distance,
        goalkeeperName = goalkeeper.name,
        goalStreak = runtime.goalStreak,
    })

    -- Actualizar stats, lista de brainrots y leaderstats
    sendStats(player)
    updateLeaderstats(player)
    if capturedBrainrot then
        sendBrainrotList(player)
    end

    -- Reset estado de patada
    runtime.isKicking = false
    runtime.kickDistance = nil
    runtime.currentGoalkeeper = nil
end)

-- ═══════════════════════════════════════════
-- TIENDA DE POTENCIA
-- ═══════════════════════════════════════════
RemoteEvents.BuyPower.OnServerEvent:Connect(function(player)
    local data = PlayerData.GetData(player)
    if not data then return end

    local cost = GameConfig.GetPowerUpgradeCost(data.power)
    if not cost then
        return -- Ya está al máximo
    end

    if PlayerData.SpendCoins(player, cost) then
        PlayerData.SetPower(player, data.power + 1)

        -- Verificar si desbloquea nueva zona
        local unlockedZone = nil
        for zoneId, zone in pairs(GameConfig.Zones) do
            if data.power + 1 >= zone.requiredPower and zoneId > data.currentZone then
                PlayerData.UnlockZone(player, zoneId)
                unlockedZone = zoneId
            end
        end

        sendStats(player)
        updateLeaderstats(player)
        
        -- Notify client of zone unlock
        if unlockedZone then
            RemoteEvents.CameraEffect:FireClient(player, "flash", {
                color = Color3.fromRGB(0, 100, 255),
                duration = 1.0,
            })
        end
    end
end)

-- ═══════════════════════════════════════════
-- TIENDA DE PELOTAS
-- ═══════════════════════════════════════════
RemoteEvents.BuyBall.OnServerEvent:Connect(function(player)
    local data = PlayerData.GetData(player)
    if not data then return end

    local nextBall = GameConfig.GetNextBallUpgrade(data.ballLevel)
    if not nextBall then
        return -- Ya tiene la mejor pelota
    end

    if PlayerData.SpendCoins(player, nextBall.cost) then
        PlayerData.SetBallLevel(player, nextBall.level)
        sendStats(player)
        updateLeaderstats(player)
    end
end)

-- ═══════════════════════════════════════════
-- REBIRTH
-- ═══════════════════════════════════════════
RemoteEvents.Rebirth.OnServerEvent:Connect(function(player)
    local data = PlayerData.GetData(player)
    if not data then return end

    local nextRebirth = GameConfig.GetNextRebirth(data.rebirths)
    if not nextRebirth then
        return -- Ya está al máximo de rebirths
    end

    -- Verificar requisitos
    if data.power < nextRebirth.requiredPower then
        return -- No tiene suficiente potencia
    end
    if #data.brainrots < nextRebirth.requiredBrainrots then
        return -- No tiene suficientes brainrots
    end

    PlayerData.PerformRebirth(player, nextRebirth.multiplier)
    sendStats(player)
    updateLeaderstats(player)
    
    -- Send rebirth effect to client
    RemoteEvents.CameraEffect:FireClient(player, "rebirth")
    
    -- Refresh base after rebirth (brainrots stay but income resets)
    sendBrainrotList(player)
end)

-- ═══════════════════════════════════════════
-- COLOCAR BRAINROT EN BASE
-- ═══════════════════════════════════════════
RemoteEvents.PlaceBrainrot.OnServerEvent:Connect(function(player, brainrotIndex, slotIndex)
    local data = PlayerData.GetData(player)
    if not data then return end

    brainrotIndex = tonumber(brainrotIndex)
    slotIndex = tonumber(slotIndex)
    if not brainrotIndex or not slotIndex then return end
    if brainrotIndex < 1 or brainrotIndex > #data.brainrots then return end
    if slotIndex < 1 or slotIndex > 20 then return end -- max 20 slots

    PlayerData.PlaceBrainrotInBase(player, brainrotIndex, slotIndex)
    sendStats(player)
    sendBrainrotList(player)
end)

-- ═══════════════════════════════════════════
-- QUITAR BRAINROT DE LA BASE
-- ═══════════════════════════════════════════
RemoteEvents.RemoveBrainrotFromBase.OnServerEvent:Connect(function(player, brainrotIndex, slotIndex)
    local data = PlayerData.GetData(player)
    if not data then return end

    brainrotIndex = tonumber(brainrotIndex)
    slotIndex = tonumber(slotIndex)
    if not brainrotIndex or not slotIndex then return end
    if brainrotIndex < 1 or brainrotIndex > #data.brainrots then return end

    PlayerData.RemoveBrainrotFromBase(player, brainrotIndex, slotIndex)
    sendStats(player)
    sendBrainrotList(player)
end)

-- ═══════════════════════════════════════════
-- INCOME PASIVO DE LA BASE
-- ═══════════════════════════════════════════
task.spawn(function()
    while task.wait(1) do
        for _, player in Players:GetPlayers() do
            local data = PlayerData.GetData(player)
            if data then
                local income = PlayerData.CalculateBaseIncome(player)
                if income > 0 then
                    local runtime = getRuntime(player)
                    runtime.baseIncomeAccumulated = runtime.baseIncomeAccumulated + income
                end
            end
        end
    end
end)

-- Reclamar income acumulado
RemoteEvents.ClaimBaseIncome.OnServerEvent:Connect(function(player)
    local runtime = getRuntime(player)
    if runtime and runtime.baseIncomeAccumulated > 0 then
        PlayerData.AddCoins(player, math.floor(runtime.baseIncomeAccumulated))
        runtime.baseIncomeAccumulated = 0
        sendStats(player)
        updateLeaderstats(player)
    end
end)

-- ═══════════════════════════════════════════
-- ENVIAR LISTA DE BRAINROTS AL CLIENTE
-- ═══════════════════════════════════════════
local function sendBrainrotList(player)
    local data = PlayerData.GetData(player)
    if not data then return end

    local list = {}
    for idx, entry in ipairs(data.brainrots) do
        -- Buscar datos del brainrot en GameConfig
        local brainrotData = nil
        for _, b in ipairs(GameConfig.Brainrots) do
            if b.id == entry.id then
                brainrotData = b
                break
            end
        end

        table.insert(list, {
            id = entry.id,
            name = brainrotData and brainrotData.name or entry.id,
            rarity = brainrotData and brainrotData.rarity or "Common",
            coinsPerSec = brainrotData and brainrotData.coinsPerSec or 1,
            isBoss = brainrotData and brainrotData.isBoss or false,
            placedInBase = entry.placedInBase or false,
            baseSlot = entry.baseSlot,
        })
    end

    RemoteEvents.UpdateBrainrotList:FireClient(player, list)
end

-- ═══════════════════════════════════════════
-- LEADERSTATS
-- ═══════════════════════════════════════════
local function setupLeaderstats(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local coins = Instance.new("IntValue")
    coins.Name = "Coins"
    coins.Value = 0
    coins.Parent = leaderstats

    local goals = Instance.new("IntValue")
    goals.Name = "Goals"
    goals.Value = 0
    goals.Parent = leaderstats

    local brainrots = Instance.new("IntValue")
    brainrots.Name = "Brainrots"
    brainrots.Value = 0
    brainrots.Parent = leaderstats

    return leaderstats
end

local function updateLeaderstats(player)
    local data = PlayerData.GetData(player)
    if not data then return end

    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return end

    local coins = leaderstats:FindFirstChild("Coins")
    if coins then coins.Value = data.coins end

    local goals = leaderstats:FindFirstChild("Goals")
    if goals then goals.Value = data.totalGoals end

    local brainrots = leaderstats:FindFirstChild("Brainrots")
    if brainrots then brainrots.Value = #data.brainrots end
end

-- ═══════════════════════════════════════════
-- ZONE TELEPORTATION
-- ═══════════════════════════════════════════
local zoneTeleportPositions = {
    [1] = CFrame.new(0, 5, -30),
    [2] = CFrame.new(200, 5, -30),
    [3] = CFrame.new(400, 5, -30),
}

local baseTeleportPosition = CFrame.new(-77.7, 5, -37.45)

RemoteEvents.ZoneTeleport.OnServerEvent:Connect(function(player, targetZone)
    local data = PlayerData.GetData(player)
    if not data then return end

    targetZone = tonumber(targetZone)
    if not targetZone then return end

    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if targetZone == 0 then
        -- Teleport to base
        hrp.CFrame = baseTeleportPosition
        return
    end

    -- Validate zone access
    local zoneConfig = GameConfig.Zones[targetZone]
    if not zoneConfig then return end

    if targetZone > data.currentZone then
        -- Zone not unlocked yet
        return
    end

    local teleportPos = zoneTeleportPositions[targetZone]
    if teleportPos then
        hrp.CFrame = teleportPos
    end
end)

-- ═══════════════════════════════════════════
-- GESTIÓN DE JUGADORES
-- ═══════════════════════════════════════════
local function onPlayerAdded(player)
    PlayerData.LoadData(player)
    setupLeaderstats(player)
    updateLeaderstats(player)
    sendStats(player)
    sendBrainrotList(player)
end

local function onPlayerRemoving(player)
    PlayerData.SaveData(player)
    PlayerData.RemovePlayer(player)
    playerRuntimeState[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Manejar jugadores que ya están en el juego
for _, player in Players:GetPlayers() do
    onPlayerAdded(player)
end

-- Guardar todo al cerrar
game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        PlayerData.SaveData(player)
    end
end)

print("[MainGame] Brainrot Goal Kick Simulator - Servidor iniciado")
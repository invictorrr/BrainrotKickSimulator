--[[
    MainGame - Script principal del servidor
    Conecta PlayerData, GameConfig, RemoteEvents y maneja toda la lógica del juego
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig    = require(ReplicatedStorage.GameConfig)
local PlayerData    = require(game.ServerScriptService.PlayerData)
local BrainrotSystem = require(game.ServerScriptService.BrainrotSystem)
local LevelManager  = require(game.ServerScriptService.LevelManager)
local KickMechanic  = require(game.ServerScriptService.KickMechanic)
local BaseSetup     = require(game.ServerScriptService.BaseSetup)
local RemoteEvents  = ReplicatedStorage.RemoteEvents

-- ═══════════════════════════════════════════
-- REFERENCIAS AL MAPA
-- ═══════════════════════════════════════════
local zonesFolder = workspace:FindFirstChild("Zones") or Instance.new("Folder")
if not zonesFolder.Parent then
    zonesFolder.Name = "Zones"
    zonesFolder.Parent = workspace
end

-- LevelManager se encarga del nuevo mapa (18 zonas con Gates).
-- Si el HD Simulator Map no está cargado, devuelve nil para todo y caemos al
-- sistema legacy de zonas (workspace.Zones.Zone1/2/3).
LevelManager.Init(BrainrotSystem)

-- ═══════════════════════════════════════════
-- POSICIONES LEGACY (sólo se usan si no hay HD map)
-- ═══════════════════════════════════════════
local zonePositions = {}
for i = 1, 18 do
    zonePositions[i] = CFrame.new((i - 1) * 200, 0, 0)
end

-- ═══════════════════════════════════════════
-- SETUP INICIAL DE ZONAS (solo si no existen ya)
-- ═══════════════════════════════════════════
local function setupZone(zoneId)
    local zoneData = GameConfig.Zones[zoneId]
    if not zoneData then return end

    local zoneModel = zonesFolder:FindFirstChild("Zone" .. tostring(zoneId))
    if zoneModel then
        -- Zona ya existe. Comprobamos la portería: si es de la versión antigua
        -- (sin el atributo GoalDepth) la reemplazamos por la caja cerrada.
        local goal = zoneModel:FindFirstChild("Goal_Zone" .. tostring(zoneId))
        local goalPos = (goal and goal:IsA("Model")) and goal:GetPivot()
            or zonePositions[zoneId]
            or CFrame.new(0, 0, 0)

        local needsRebuild = false
        if not goal then
            needsRebuild = true
        elseif not goal:GetAttribute("GoalDepth") then
            needsRebuild = true
        end

        if needsRebuild then
            if goal then goal:Destroy() end
            local newGoal = BrainrotSystem.CreateGoal(zoneId, goalPos)
            if newGoal then newGoal.Parent = zoneModel end
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

if not LevelManager.IsHDMapPresent() then
    -- Sólo creamos zonas legacy si el mapa nuevo no está disponible.
    for zoneId, _ in pairs(GameConfig.Zones) do
        setupZone(zoneId)
    end
end

-- Devuelve la portería para la zona del jugador, usando el HD map si está
-- presente, o las zonas legacy en caso contrario.
local function resolveGoalContext(zoneId: number)
    local hdGoal, hdCFrame = LevelManager.GetGoalForZone(zoneId)
    if hdGoal then
        local goalZone = hdGoal:FindFirstChild("GoalZone")
        return hdGoal, (goalZone and goalZone:IsA("BasePart")) and goalZone or nil, hdCFrame
    end
    local zoneModel = zonesFolder:FindFirstChild("Zone" .. tostring(zoneId))
    if not zoneModel then return nil, nil, nil end
    local goal = zoneModel:FindFirstChild("Goal_Zone" .. tostring(zoneId))
    if not (goal and goal:IsA("Model")) then return nil, nil, zoneModel:GetPivot() end
    local goalZone = goal:FindFirstChild("GoalZone")
    return goal, (goalZone and goalZone:IsA("BasePart")) and goalZone or nil, goal:GetPivot()
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
            kickLockToken = nil,      -- token anti-bloqueo de patada
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

-- Pelotas activas por jugador. Solo se mantiene 1 a la vez: al patear de
-- nuevo, se elimina la previa para evitar pelotas huérfanas acumulándose.
-- (La detección de gol / spread / multiplicadores vive en KickMechanic.)
local activeBallsByPlayer: { [number]: BasePart } = {}

local function clearActiveBall(player: Player)
    local ball = activeBallsByPlayer[player.UserId]
    if ball and ball.Parent then
        ball:Destroy()
    end
    activeBallsByPlayer[player.UserId] = nil
end

local function createSoccerBall(startPos: Vector3, ballData): BasePart
    local ball = Instance.new("Part")
    ball.Name = "ServerKickBall"
    ball.Shape = Enum.PartType.Ball
    ball.Size = Vector3.new(1.6, 1.6, 1.6)
    ball.Material = Enum.Material.SmoothPlastic
    ball.TopSurface = Enum.SurfaceType.Smooth
    ball.BottomSurface = Enum.SurfaceType.Smooth
    ball.Color = (ballData and ballData.color) or Color3.fromRGB(245, 245, 245)
    ball.CFrame = CFrame.new(startPos)
    ball.Anchored = false
    -- Sin colisión al inicio: la habilitamos tras unos ms para que el balón
    -- no rebote contra el cuerpo del propio jugador al spawnear.
    ball.CanCollide = false
    ball.CanTouch = false
    ball.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.5, 0.6, 1, 1)

    -- Decoración estilo balón de fútbol (parches negros en las 6 caras)
    for _, face in ipairs({
        Enum.NormalId.Top, Enum.NormalId.Bottom,
        Enum.NormalId.Front, Enum.NormalId.Back,
        Enum.NormalId.Left, Enum.NormalId.Right,
    }) do
        local decal = Instance.new("Decal")
        decal.Face = face
        decal.Color3 = Color3.fromRGB(20, 20, 20)
        decal.Transparency = 0.05
        decal.Parent = ball
    end

    return ball
end

-- Amortigua progresivamente la velocidad para que la pelota se quede
-- dentro de la portería en vez de salir disparada al rebotar.
local function dampBallToRest(ball: BasePart)
    if not ball or not ball.Parent then return end
    task.spawn(function()
        local t = 0
        while ball.Parent and t < 1.8 do
            local dt = task.wait(0.05)
            t += dt
            ball.AssemblyLinearVelocity = ball.AssemblyLinearVelocity * 0.55
        end
    end)
end

-- Inicialización de la mecánica de patada (módulo intercambiable).
-- KickMechanic se ocupa de spawnear la pelota y de la detección de gol/parada;
-- nosotros sólo le proveemos los "ganchos" para crear pelota y manejar su
-- ciclo de vida en el servidor.
KickMechanic.Init({
    createBall      = createSoccerBall,
    onBallSpawned   = function(player, ball)
        activeBallsByPlayer[player.UserId] = ball
    end,
    clearActiveBall = clearActiveBall,
    dampBallToRest  = dampBallToRest,
})

-- ═══════════════════════════════════════════
-- SISTEMA DE PATADA
-- ═══════════════════════════════════════════

-- Cuando el jugador selecciona su posición de patada (distancia = donde está parado)
RemoteEvents.SetKickPosition.OnServerEvent:Connect(function(player, _clientDistance)
    local data = PlayerData.GetData(player)
    if not data then return end

    local zoneId = data.currentZone
    local zone = GameConfig.Zones[zoneId]
    if not zone then return end

    local distance = _clientDistance
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if hrp then
        distance = GameConfig.ComputeKickDistance(hrp.Position, GameConfig.GetGoalCFrame(zoneId), zoneId)
    else
        distance = math.clamp(_clientDistance or zone.minDistance, zone.minDistance, zone.maxDistance)
    end

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

    -- Spawn visual de siluetas -> revelacion en el mundo 3D.
    local goalModel, goalCFrame, _ = resolveGoalContext(zoneId)
    if goalCFrame then
        local gkFolder = LevelManager.GetGoalkeepersFolder() or workspace
        for _, child in ipairs(gkFolder:GetChildren()) do
            if child:GetAttribute("OwnerUserId") == player.UserId then
                child:Destroy()
            end
        end
        if goalModel then
            for _, child in ipairs(goalModel:GetChildren()) do
                if child.Name == "GoalkeeperSilhouette" or child.Name == "RevealedGoalkeeper" then
                    child:Destroy()
                end
            end
        end
        BrainrotSystem.SpawnGoalkeeperSequence(goalCFrame, goalkeeper, gkFolder, player.UserId)
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
    local lockToken = tostring(os.clock()) .. "_" .. tostring(player.UserId)
    runtime.kickLockToken = lockToken

    -- Failsafe de servidor: si algo explota en medio del tiro, desbloquear.
    task.delay(5, function()
        if runtime.isKicking and runtime.kickLockToken == lockToken then
            runtime.isKicking = false
            runtime.kickDistance = nil
            runtime.currentGoalkeeper = nil
        end
    end)

    local zoneId = data.currentZone
    local distance = runtime.kickDistance
    local goalkeeper = runtime.currentGoalkeeper
    local ballData = GameConfig.BallShop[data.ballLevel]
    local ballMultiplier = ballData and ballData.multiplier or 1
    local maxKickDistance = GameConfig.CalculateMaxKickDistance(data.power, zoneId)
    local outOfRange = distance > (maxKickDistance + 1)

    if indicatorZone ~= "green" and indicatorZone ~= "yellow" and indicatorZone ~= "red" then
        indicatorZone = "red"
    end

    if not runtime.goalStreak then runtime.goalStreak = 0 end
    PlayerData.IncrementKicks(player)

    local coinsEarned = 0
    local capturedBrainrot = nil

    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local goalModel, goalZone, goalCFrame = resolveGoalContext(zoneId)
    local gkFolder = LevelManager.GetGoalkeepersFolder()
    local revealedGoalkeeper = nil
    if gkFolder then
        for _, child in ipairs(gkFolder:GetChildren()) do
            if child.Name == "RevealedGoalkeeper"
                and child:GetAttribute("OwnerUserId") == player.UserId then
                revealedGoalkeeper = child
                break
            end
        end
    end
    if not revealedGoalkeeper then
        local zoneModel = zonesFolder:FindFirstChild("Zone" .. tostring(zoneId))
        revealedGoalkeeper = (zoneModel and zoneModel:FindFirstChild("RevealedGoalkeeper"))
            or (goalModel and goalModel:FindFirstChild("RevealedGoalkeeper"))
    end

    -- Toda la mecánica vive en KickMechanic. Le pasamos el contexto y
    -- recibimos el resultado + la pelota spawneada (si la hubo).
    local kickResult = KickMechanic.ResolveKick({
        player                   = player,
        zoneId                   = zoneId,
        distance                 = distance,
        indicatorZone            = indicatorZone,
        power                    = data.power,
        maxKickDistance          = maxKickDistance,
        outOfRange               = outOfRange,
        ballData                 = ballData,
        goalModel                = goalModel,
        goalZone                 = goalZone,
        goalCFrame               = goalCFrame,
        revealedGoalkeeperModel  = revealedGoalkeeper,
        humanoidRootPart         = hrp,
    })

    local result = kickResult.result

    if not hrp then
        runtime.goalStreak = 0
    elseif result == "saved" then
        runtime.goalStreak = 0
    end

    local unlockedZone = nil
    if result == "goal" then
        runtime.goalStreak = runtime.goalStreak + 1
        local streakBonus = 1 + (runtime.goalStreak - 1) * 0.1
        coinsEarned = math.floor(GameConfig.CalculateGoalCoins(distance, zoneId, ballMultiplier, data.rebirthMultiplier) * streakBonus)
        capturedBrainrot = goalkeeper
        PlayerData.AddCoins(player, coinsEarned)
        PlayerData.AddBrainrot(player, goalkeeper.id)
        PlayerData.IncrementGoals(player)

        -- Progresión por gol: si el jugador acaba de marcar en su zona
        -- actual, avanza a la siguiente y se oculta el muro/portería que
        -- acaba de superar.
        local maxZone = 0
        for id, _ in pairs(GameConfig.Zones) do
            if id > maxZone then maxZone = id end
        end
        if zoneId == data.currentZone and zoneId < maxZone then
            local nextZone = zoneId + 1
            PlayerData.UnlockZone(player, nextZone)
            unlockedZone = nextZone
            if LevelManager.IsHDMapPresent() then
                LevelManager.UnlockZone(nextZone)
            end
        end
    elseif result ~= "saved" then
        runtime.goalStreak = 0
    end

    if goalModel then
        local goalPos = goalModel:GetPivot()
        if result == "goal" then
            BrainrotSystem.PlayGoalEffect(goalPos)
        elseif result == "saved" then
            local gk = revealedGoalkeeper
            if not gk and gkFolder then
                for _, child in ipairs(gkFolder:GetChildren()) do
                    if child.Name == "RevealedGoalkeeper"
                        and child:GetAttribute("OwnerUserId") == player.UserId then
                        gk = child
                        break
                    end
                end
            end
            if gk then
                BrainrotSystem.PlaySaveAnimation(gk)
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
        maxKickDistance = maxKickDistance,
        outOfRange = outOfRange,
        useServerPhysics = true,
        goalkeeperName = goalkeeper.name,
        goalStreak = runtime.goalStreak,
        unlockedZone = unlockedZone,
    })

    -- Actualizar stats, lista de brainrots y leaderstats
    sendStats(player)
    updateLeaderstats(player)
    if capturedBrainrot then
        sendBrainrotList(player)
    end

    -- Reset estado de patada
    runtime.isKicking = false
    runtime.kickLockToken = nil
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
        local baseCf = BaseSetup.GetBaseTeleportCFrame(player)
        if baseCf then
            hrp.CFrame = baseCf
        else
            hrp.CFrame = baseTeleportPosition
        end
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

    local data = PlayerData.GetData(player)
    if data and LevelManager.IsHDMapPresent() then
        LevelManager.SyncPlayerGates(data.currentZone)
    end
end

local function onPlayerRemoving(player)
    PlayerData.SaveData(player)
    PlayerData.RemovePlayer(player)
    playerRuntimeState[player.UserId] = nil
    clearActiveBall(player)
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
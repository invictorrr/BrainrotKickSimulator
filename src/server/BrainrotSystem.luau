--[[
    BrainrotSystem - Sistema completo de brainrots
    Maneja: captura, colocacion en base, calculo de income,
    porteros en porteria, siluetas, revelacion, boss, animaciones
]]
local BrainrotSystem = {}

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)

local function normalizeName(name: string): string
	return string.lower(name:gsub("%s+", ""):gsub("[^%w]", ""))
end

local function getBrainrotModelsFolder(): Instance?
	local folder = ServerStorage:FindFirstChild("BrainrotModels")
	if folder and #folder:GetChildren() > 0 then
		return folder
	end

	folder = ServerStorage:WaitForChild("BrainrotModels", 10)
	if folder and #folder:GetChildren() > 0 then
		return folder
	end

	return workspace:FindFirstChild("brainrotsmodels")
end

local brainrotsModels = getBrainrotModelsFolder()

-- Cache de modelos de brainrot
local modelCache = {}

function BrainrotSystem.GetBrainrotModel(brainrotId)
    if modelCache[brainrotId] then
        return modelCache[brainrotId]:Clone()
    end
    if not brainrotsModels then
        warn("[BrainrotSystem] No se encontro la carpeta brainrotsmodels")
        return nil
    end
    local brainrotData = nil
    for _, b in ipairs(GameConfig.Brainrots) do
        if b.id == brainrotId then
            brainrotData = b
            break
        end
    end
    if not brainrotData then
        warn("[BrainrotSystem] No se encontro brainrot con ID: " .. tostring(brainrotId))
        return nil
    end

    local folder = getBrainrotModelsFolder()
    if not folder then
        warn("[BrainrotSystem] No hay carpeta de modelos (ServerStorage.BrainrotModels o Workspace.brainrotsmodels)")
        return nil
    end
    brainrotsModels = folder

    local lookupName = brainrotData.modelName or brainrotData.name
    local targetNorm = normalizeName(lookupName)
    local model = brainrotsModels:FindFirstChild(lookupName)
    if not model then
        for _, child in brainrotsModels:GetChildren() do
            if child:IsA("Model") and normalizeName(child.Name) == targetNorm then
                model = child
                break
            end
        end
    end
    if model then
        modelCache[brainrotId] = model
        return model:Clone()
    end
    warn("[BrainrotSystem] Modelo no encontrado en workspace: " .. brainrotData.name)
    return nil
end

-- Capturar brainrot
function BrainrotSystem.CaptureBrainrot(playerData, brainrotConfig)
    if not playerData or not brainrotConfig then return false end
    local entry = {
        id = brainrotConfig.id,
        name = brainrotConfig.name,
        rarity = brainrotConfig.rarity,
        coinsPerSec = brainrotConfig.coinsPerSec,
        placedInBase = false,
        baseSlot = nil,
    }
    table.insert(playerData.brainrots, entry)
    return true, entry
end

-- Colocar brainrot en base
function BrainrotSystem.PlaceInBase(playerData, brainrotIndex, slotNumber)
    if not playerData then return false end
    if not playerData.brainrots[brainrotIndex] then return false end
    if slotNumber < 1 or slotNumber > 20 then return false end
    for _, br in ipairs(playerData.brainrots) do
        if br.placedInBase and br.baseSlot == slotNumber then
            return false
        end
    end
    playerData.brainrots[brainrotIndex].placedInBase = true
    playerData.brainrots[brainrotIndex].baseSlot = slotNumber
    return true
end

-- Quitar brainrot de la base
function BrainrotSystem.RemoveFromBase(playerData, brainrotIndex)
    if not playerData then return false end
    if not playerData.brainrots[brainrotIndex] then return false end
    playerData.brainrots[brainrotIndex].placedInBase = false
    playerData.brainrots[brainrotIndex].baseSlot = nil
    return true
end

-- Calcular income total
function BrainrotSystem.CalculateTotalIncome(playerData, rebirthMultiplier)
    if not playerData then return 0 end
    local totalIncome = 0
    for _, br in ipairs(playerData.brainrots) do
        if br.placedInBase then
            totalIncome = totalIncome + (br.coinsPerSec or 0) * (rebirthMultiplier or 1)
        end
    end
    return totalIncome
end

-- Contar brainrots
function BrainrotSystem.GetCount(playerData)
    if not playerData then return 0 end
    return #playerData.brainrots
end

-- Obtener lista para enviar al cliente
function BrainrotSystem.GetClientList(playerData)
    if not playerData then return {} end
    local list = {}
    for idx, br in ipairs(playerData.brainrots) do
        table.insert(list, {
            id = br.id,
            name = br.name,
            rarity = br.rarity,
            coinsPerSec = br.coinsPerSec,
            placedInBase = br.placedInBase,
            baseSlot = br.baseSlot,
        })
    end
    return list
end

-- Crear silueta de portero (negra, misteriosa)
local function createSilhouette(position)
    local silhouette = Instance.new("Model")
    silhouette.Name = "GoalkeeperSilhouette"
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(3, 4, 1.5)
    torso.CFrame = position * CFrame.new(0, 2, 0)
    torso.Color = Color3.fromRGB(15, 15, 15)
    torso.Material = Enum.Material.Neon
    torso.Anchored = true
    torso.CanCollide = false
    torso.Parent = silhouette
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(2, 2, 2)
    head.Shape = Enum.PartType.Ball
    head.CFrame = position * CFrame.new(0, 5, 0)
    head.Color = Color3.fromRGB(15, 15, 15)
    head.Material = Enum.Material.Neon
    head.Anchored = true
    head.CanCollide = false
    head.Parent = silhouette
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(Color3.fromRGB(50, 0, 80), Color3.fromRGB(100, 0, 150))
    particles.Size = NumberSequence.new(0.3, 0)
    particles.Lifetime = NumberRange.new(0.5, 1)
    particles.Rate = 15
    particles.Speed = NumberRange.new(1, 3)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Parent = torso
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 50, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head
    local questionMark = Instance.new("TextLabel")
    questionMark.Size = UDim2.new(1, 0, 1, 0)
    questionMark.BackgroundTransparency = 1
    questionMark.Text = "?"
    questionMark.TextColor3 = Color3.fromRGB(200, 0, 255)
    questionMark.Font = Enum.Font.GothamBlack
    questionMark.TextSize = 40
    questionMark.TextStrokeTransparency = 0
    questionMark.TextStrokeColor3 = Color3.fromRGB(100, 0, 150)
    questionMark.Parent = billboard
    return silhouette
end

-- Crear portero revelado (modelo real del brainrot)
local function createRevealedGoalkeeper(brainrotId, position, isBoss)
    local model = BrainrotSystem.GetBrainrotModel(brainrotId)
    if model then
        model.Name = "RevealedGoalkeeper"
        model:PivotTo(position * CFrame.new(0, 0, 0))
        for _, part in model:GetDescendants() do
            if part:IsA("BasePart") then
                part.Anchored = true
                part.CanCollide = false
            end
        end
        if isBoss then
            local aura = Instance.new("Part")
            aura.Name = "BossAura"
            aura.Size = Vector3.new(8, 8, 8)
            aura.Shape = Enum.PartType.Ball
            aura.CFrame = position * CFrame.new(0, 3, 0)
            aura.Color = Color3.fromRGB(255, 0, 0)
            aura.Material = Enum.Material.Neon
            aura.Transparency = 0.7
            aura.Anchored = true
            aura.CanCollide = false
            aura.Parent = model
            local billboard = Instance.new("BillboardGui")
            billboard.Size = UDim2.new(0, 200, 0, 40)
            billboard.StudsOffset = Vector3.new(0, 8, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = aura
            local bossLabel = Instance.new("TextLabel")
            bossLabel.Size = UDim2.new(1, 0, 1, 0)
            bossLabel.BackgroundTransparency = 1
            bossLabel.Text = "BOSS"
            bossLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            bossLabel.Font = Enum.Font.GothamBlack
            bossLabel.TextSize = 28
            bossLabel.TextStrokeTransparency = 0
            bossLabel.TextStrokeColor3 = Color3.fromRGB(100, 0, 0)
            bossLabel.Parent = billboard
        end
        return model
    end
    -- Fallback si no se encuentra el modelo
    local fallback = Instance.new("Model")
    fallback.Name = "RevealedGoalkeeper"
    local body = Instance.new("Part")
    body.Size = Vector3.new(3, 5, 2)
    body.CFrame = position * CFrame.new(0, 2.5, 0)
    body.Color = isBoss and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(100, 100, 200)
    body.Material = Enum.Material.SmoothPlastic
    body.Anchored = true
    body.CanCollide = false
    body.Parent = fallback
    local head = Instance.new("Part")
    head.Size = Vector3.new(2, 2, 2)
    head.Shape = Enum.PartType.Ball
    head.CFrame = position * CFrame.new(0, 6, 0)
    head.Color = isBoss and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(150, 150, 220)
    head.Material = Enum.Material.SmoothPlastic
    head.Anchored = true
    head.CanCollide = false
    head.Parent = fallback
    return fallback
end

-- Crear porteria para una zona
function BrainrotSystem.CreateGoal(zoneId, position)
    local zone = GameConfig.Zones[zoneId]
    if not zone then return nil end
    local goal = Instance.new("Model")
    goal.Name = "Goal_Zone" .. tostring(zoneId)
    local width = zone.goalWidth
    local height = zone.goalHeight
    local leftPost = Instance.new("Part")
    leftPost.Name = "LeftPost"
    leftPost.Size = Vector3.new(0.5, height, 0.5)
    leftPost.CFrame = position * CFrame.new(-width / 2, height / 2, 0)
    leftPost.Color = Color3.fromRGB(255, 255, 255)
    leftPost.Material = Enum.Material.SmoothPlastic
    leftPost.Anchored = true
    leftPost.Parent = goal
    local rightPost = Instance.new("Part")
    rightPost.Name = "RightPost"
    rightPost.Size = Vector3.new(0.5, height, 0.5)
    rightPost.CFrame = position * CFrame.new(width / 2, height / 2, 0)
    rightPost.Color = Color3.fromRGB(255, 255, 255)
    rightPost.Material = Enum.Material.SmoothPlastic
    rightPost.Anchored = true
    rightPost.Parent = goal
    local crossbar = Instance.new("Part")
    crossbar.Name = "Crossbar"
    crossbar.Size = Vector3.new(width + 0.5, 0.5, 0.5)
    crossbar.CFrame = position * CFrame.new(0, height, 0)
    crossbar.Color = Color3.fromRGB(255, 255, 255)
    crossbar.Material = Enum.Material.SmoothPlastic
    crossbar.Anchored = true
    crossbar.Parent = goal
    local net = Instance.new("Part")
    net.Name = "Net"
    net.Size = Vector3.new(width, height, 2)
    net.CFrame = position * CFrame.new(0, height / 2, 1.5)
    net.Color = Color3.fromRGB(255, 255, 255)
    net.Material = Enum.Material.SmoothPlastic
    net.Transparency = 0.7
    net.Anchored = true
    net.CanCollide = false
    net.Parent = goal
    local goalZone = Instance.new("Part")
    goalZone.Name = "GoalZone"
    goalZone.Size = Vector3.new(width - 1, height - 1, 2)
    goalZone.CFrame = position * CFrame.new(0, height / 2, 0)
    goalZone.Transparency = 1
    goalZone.Anchored = true
    goalZone.CanCollide = false
    goalZone.Parent = goal
    goal:SetAttribute("ZoneId", zoneId)
    return goal
end

-- Crear marcadores de distancia en el campo
function BrainrotSystem.CreateDistanceMarkers(zoneId, goalPosition)
    local zone = GameConfig.Zones[zoneId]
    if not zone then return {} end
    local markers = {}
    local distances = {zone.penaltyDistance, (zone.minDistance + zone.maxDistance) / 2, zone.maxDistance}
    local labels = {"PENALTY", "MEDIO CAMPO", "LEJOS"}
    for i, dist in ipairs(distances) do
        local marker = Instance.new("Part")
        marker.Name = "DistanceMarker_" .. tostring(dist)
        marker.Size = Vector3.new(20, 0.2, 0.5)
        marker.CFrame = goalPosition * CFrame.new(0, 0.1, -dist)
        marker.Color = Color3.fromRGB(255, 255, 255)
        marker.Material = Enum.Material.Neon
        marker.Transparency = 0.5
        marker.Anchored = true
        marker.CanCollide = false
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 120, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = marker
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = labels[i] .. "\n" .. tostring(dist) .. " studs"
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.Parent = billboard
        table.insert(markers, marker)
    end
    return markers
end

-- Animacion: siluetas -> revelacion de portero
function BrainrotSystem.SpawnGoalkeeperSequence(goalPosition, brainrotData, parent)
    local silhouettes = {}
    local zone = GameConfig.Zones[brainrotData.zone]
    local width = zone and zone.goalWidth or 10
    local positions = {
        goalPosition * CFrame.new(-width / 3, 0, 0),
        goalPosition * CFrame.new(0, 0, 0),
        goalPosition * CFrame.new(width / 3, 0, 0),
    }
    for i, pos in ipairs(positions) do
        local sil = createSilhouette(pos)
        sil.Parent = parent or workspace
        table.insert(silhouettes, sil)
    end
    task.delay(1.5, function()
        for _, sil in ipairs(silhouettes) do
            if sil and sil.Parent then sil:Destroy() end
        end
        local revealed = createRevealedGoalkeeper(
            brainrotData.id,
            goalPosition * CFrame.new(0, 0, 0),
            brainrotData.isBoss
        )
        revealed.Parent = parent or workspace
        task.delay(8, function()
            if revealed and revealed.Parent then
                revealed:Destroy()
            end
        end)
    end)
end

-- Animacion de parada (portero salva)
function BrainrotSystem.PlaySaveAnimation(goalkeeperModel)
    if not goalkeeperModel or not goalkeeperModel.Parent then return end
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    for _, part in goalkeeperModel:GetDescendants() do
        if part:IsA("BasePart") then
            local tween = game:GetService("TweenService"):Create(part, tweenInfo, {
                CFrame = part.CFrame * CFrame.new(3, -0.5, 0)
            })
            tween:Play()
        end
    end
end

-- Animacion de gol (balon entra)
function BrainrotSystem.PlayGoalEffect(goalPosition)
    local effect = Instance.new("Part")
    effect.Size = Vector3.new(1, 1, 1)
    effect.CFrame = goalPosition * CFrame.new(0, 3, 0)
    effect.Transparency = 1
    effect.Anchored = true
    effect.CanCollide = false
    effect.Parent = workspace
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 0)),
    })
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Lifetime = NumberRange.new(1, 2)
    particles.Rate = 50
    particles.Speed = NumberRange.new(5, 15)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Parent = effect
    task.delay(3, function()
        if effect and effect.Parent then
            particles.Enabled = false
            task.delay(2, function()
                if effect and effect.Parent then effect:Destroy() end
            end)
        end
    end)
end

return BrainrotSystem
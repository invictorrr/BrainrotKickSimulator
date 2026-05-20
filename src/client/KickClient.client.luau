--[[
    KickClient - LocalScript principal del cliente
    Maneja: indicador de fuerza, input, distancia, eventos del servidor, HUD
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local RemoteEvents = ReplicatedStorage.RemoteEvents
local GameConfig = require(ReplicatedStorage.GameConfig)

-- ═══════════════════════════════════════════
-- ESPERAR A QUE LA UI ESTÉ LISTA
-- ═══════════════════════════════════════════
local screenGui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotGoalKickUI", 10)
if not screenGui then
    warn("[KickClient] No se encontró la UI")
    return
end

-- Referencias UI
local hud = screenGui:FindFirstChild("HUD")
local coinsLabel = hud and hud:FindFirstChild("CoinsLabel")
local powerLabel = hud and hud:FindFirstChild("PowerLabel")
local ballLabel = hud and hud:FindFirstChild("BallLabel")
local zoneLabel = hud and hud:FindFirstChild("ZoneLabel")
local incomeLabel = hud and hud:FindFirstChild("IncomeLabel")
local rebirthLabel = hud and hud:FindFirstChild("RebirthLabel")

local indicatorFrame = screenGui:FindFirstChild("IndicatorFrame")
local bar = indicatorFrame and indicatorFrame:FindFirstChild("Bar")
local greenZone = bar and bar:FindFirstChild("GreenZone")
local yellowZone = bar and bar:FindFirstChild("YellowZone")
local redZone = bar and bar:FindFirstChild("RedZone")
local marker = bar and bar:FindFirstChild("Marker")
local resultLabel = indicatorFrame and indicatorFrame:FindFirstChild("ResultLabel")

local distanceFrame = screenGui:FindFirstChild("DistanceFrame")
local distSlider = distanceFrame and distanceFrame:FindFirstChild("DistanceSlider")
local distLabel = distanceFrame and distanceFrame:FindFirstChild("DistanceLabel")
local sliderFill = distSlider and distSlider:FindFirstChild("SliderFill")

local goalkeeperFrame = screenGui:FindFirstChild("GoalkeeperFrame")
local gkName = goalkeeperFrame and goalkeeperFrame:FindFirstChild("GoalkeeperName")
local gkRarity = goalkeeperFrame and goalkeeperFrame:FindFirstChild("GoalkeeperRarity")
local gkBoss = goalkeeperFrame and goalkeeperFrame:FindFirstChild("GoalkeeperBoss")

local claimButton = screenGui:FindFirstChild("ClaimButton")

-- ═══════════════════════════════════════════
-- ESTADO LOCAL
-- ═══════════════════════════════════════════
local playerStats = {
    coins = 0,
    power = 1,
    ballLevel = 1,
    ballMultiplier = 1,
    ballName = "Balón Básico",
    rebirths = 0,
    rebirthMultiplier = 1,
    currentZone = 1,
    baseIncomePerSec = 0,
    brainrotCount = 0,
    totalGoals = 0,
    totalKicks = 0,
}

local isCharging = false
local indicatorActive = false
local markerPosition = 0
local markerDirection = 1
local selectedDistance = 30
local currentGoalkeeper = nil
local accumulatedIncome = 0
local canKick = true
local kickCooldown = 1.5

-- ═══════════════════════════════════════════
-- GOAL STREAK / COMBO SYSTEM
-- ═══════════════════════════════════════════
if screenGui then
    streakLabel = Instance.new("TextLabel")
    streakLabel.Name = "StreakLabel"
    streakLabel.Size = UDim2.new(0, 200, 0, 50)
    streakLabel.Position = UDim2.new(0.5, -100, 0.08, 0)
    streakLabel.BackgroundTransparency = 1
    streakLabel.Text = ""
    streakLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    streakLabel.Font = Enum.Font.GothamBlack
    streakLabel.TextSize = 22
    streakLabel.TextStrokeTransparency = 0
    streakLabel.TextStrokeColor3 = Color3.fromRGB(100, 50, 0)
    streakLabel.ZIndex = 50
    streakLabel.Parent = screenGui
end

local function updateStreakDisplay()
    if not streakLabel then return end
    if goalStreak >= 2 then
        streakLabel.Text = "🔥 STREAK x" .. tostring(goalStreak) .. " (x" .. string.format("%.1f", streakBonusMultiplier) .. " bonus)"
        -- Color based on streak
        if goalStreak >= 5 then
            streakLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        elseif goalStreak >= 3 then
            streakLabel.TextColor3 = Color3.fromRGB(255, 150, 0)
        else
            streakLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
    else
        streakLabel.Text = ""
    end
end

local function animateStreakPopup()
    if not streakLabel or goalStreak < 2 then return end
    -- Pop animation
    streakLabel.TextSize = 30
    local tween = TweenService:Create(streakLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextSize = 22,
    })
    tween:Play()
end

-- ═══════════════════════════════════════════
-- 3D KICK POSITION MARKER ON THE FIELD
-- ═══════════════════════════════════════════
local kickMarker = nil
local goalStreak = 0
local streakBonusMultiplier = 1
local lastKickWasGoal = false
local streakLabel = nil

local function createKickMarker()

-- ═══════════════════════════════════════════
-- STATS DISPLAY (total goals, kicks, accuracy)
-- ═══════════════════════════════════════════
if screenGui then
    local statsDisplay = Instance.new("Frame")
    statsDisplay.Name = "StatsDisplay"
    statsDisplay.Size = UDim2.new(0, 160, 0, 70)
    statsDisplay.Position = UDim2.new(0, 10, 0.15, 0)
    statsDisplay.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    statsDisplay.BackgroundTransparency = 0.3
    statsDisplay.BorderSizePixel = 0
    statsDisplay.Parent = screenGui
    
    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 8)
    statsCorner.Parent = statsDisplay
    
    local statsStroke = Instance.new("UIStroke")
    statsStroke.Color = Color3.fromRGB(80, 80, 120)
    statsStroke.Thickness = 1
    statsStroke.Parent = statsDisplay
    
    local goalsLabel = Instance.new("TextLabel")
    goalsLabel.Name = "GoalsLabel"
    goalsLabel.Size = UDim2.new(1, 0, 0, 20)
    goalsLabel.Position = UDim2.new(0, 0, 0, 5)
    goalsLabel.BackgroundTransparency = 1
    goalsLabel.Text = "⚽ Goles: 0"
    goalsLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    goalsLabel.Font = Enum.Font.GothamBold
    goalsLabel.TextSize = 12
    goalsLabel.Parent = statsDisplay
    
    local kicksLabel = Instance.new("TextLabel")
    kicksLabel.Name = "KicksLabel"
    kicksLabel.Size = UDim2.new(1, 0, 0, 20)
    kicksLabel.Position = UDim2.new(0, 0, 0, 25)
    kicksLabel.BackgroundTransparency = 1
    kicksLabel.Text = "👟 Patadas: 0"
    kicksLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    kicksLabel.Font = Enum.Font.GothamBold
    kicksLabel.TextSize = 12
    kicksLabel.Parent = statsDisplay
    
    local accuracyLabel = Instance.new("TextLabel")
    accuracyLabel.Name = "AccuracyLabel"
    accuracyLabel.Size = UDim2.new(1, 0, 0, 20)
    accuracyLabel.Position = UDim2.new(0, 0, 0, 45)
    accuracyLabel.BackgroundTransparency = 1
    accuracyLabel.Text = "🎯 Precisión: 0%"
    accuracyLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    accuracyLabel.Font = Enum.Font.GothamBold
    accuracyLabel.TextSize = 12
    accuracyLabel.Parent = statsDisplay
end
    if kickMarker then return end
    
    kickMarker = Instance.new("Part")
    kickMarker.Name = "KickPositionMarker"
    kickMarker.Size = Vector3.new(3, 0.3, 3)
    kickMarker.Shape = Enum.PartType.Ball
    kickMarker.Color = Color3.fromRGB(255, 255, 0)
    kickMarker.Material = Enum.Material.Neon
    kickMarker.Transparency = 0.4
    kickMarker.Anchored = true
    kickMarker.CanCollide = false
    kickMarker.Parent = workspace
    
    -- Billboard label
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = kickMarker
    
    local label = Instance.new("TextLabel")
    label.Name = "DistanceLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "📏 " .. tostring(selectedDistance) .. " studs"
    label.TextColor3 = Color3.fromRGB(255, 255, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Parent = billboard
    
    -- Particle effect on marker
    local particles = Instance.new("ParticleEmitter")
    particles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 100, 0))
    particles.Size = NumberSequence.new(0.2, 0)
    particles.Lifetime = NumberRange.new(0.3, 0.8)
    particles.Rate = 10
    particles.Speed = NumberRange.new(0.5, 2)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.LightEmission = 1
    particles.Parent = kickMarker
    
    -- Kick direction arrow (points toward goal)
    local arrow = Instance.new("Part")
    arrow.Name = "KickArrow"
    arrow.Size = Vector3.new(0.4, 0.4, 6)
    arrow.CFrame = CFrame.new(0, 0.5, -3) -- points toward goal (negative Z)
    arrow.Color = Color3.fromRGB(0, 255, 100)
    arrow.Material = Enum.Material.Neon
    arrow.Transparency = 0.3
    arrow.Anchored = true
    arrow.CanCollide = false
    arrow.Parent = kickMarker
    
    -- Arrow head (wedge)
    local arrowHead = Instance.new("Part")
    arrowHead.Name = "ArrowHead"
    arrowHead.Size = Vector3.new(1.5, 0.4, 1.5)
    arrowHead.CFrame = CFrame.new(0, 0.5, -6.5)
    arrowHead.Color = Color3.fromRGB(0, 255, 100)
    arrowHead.Material = Enum.Material.Neon
    arrowHead.Transparency = 0.3
    arrowHead.Anchored = true
    arrowHead.CanCollide = false
    arrowHead.Parent = kickMarker
    
    -- Ball preview at kick position
    local ballPreview = Instance.new("Part")
    ballPreview.Name = "BallPreview"
    ballPreview.Shape = Enum.PartType.Ball
    ballPreview.Size = Vector3.new(1.2, 1.2, 1.2)
    ballPreview.CFrame = CFrame.new(0, 1, 0)
    ballPreview.Color = Color3.fromRGB(255, 255, 255)
    ballPreview.Material = Enum.Material.SmoothPlastic
    ballPreview.Transparency = 0.5
    ballPreview.Anchored = true
    ballPreview.CanCollide = false
    ballPreview.Parent = kickMarker
    
    -- Pulse animation for kick marker
    task.spawn(function()
        while task.wait(0.8) do
            if kickMarker and kickMarker.Parent then
                local pulse = TweenService:Create(kickMarker, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                    Transparency = 0.7,
                    Size = Vector3.new(4, 0.4, 4),
                })
                pulse:Play()
                pulse.Completed:Connect(function()
                    if kickMarker and kickMarker.Parent then
                        local unpulse = TweenService:Create(kickMarker, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                            Transparency = 0.4,
                            Size = Vector3.new(3, 0.3, 3),
                        })
                        unpulse:Play()
                    end
                end)
            end
        end
    end)
end

local function updateKickMarkerPosition()
    if not kickMarker then return end
    
    local zone = GameConfig.Zones[playerStats.currentZone]
    if not zone then return end
    
    -- Calculate position based on zone offset and distance
    local zoneOffsets = {
        [1] = 0,
        [2] = 200,
        [3] = 400,
    }
    local offsetX = zoneOffsets[playerStats.currentZone] or 0
    
    -- Position marker at the selected distance from the goal
    kickMarker.CFrame = CFrame.new(offsetX, 0.5, -selectedDistance)
    
    -- Update label
    local billboard = kickMarker:FindFirstChild("BillboardGui")
    if billboard then
        local label = billboard:FindFirstChild("DistanceLabel")
        if label then
            label.Text = "📏 " .. tostring(selectedDistance) .. " studs"
        end
    end
end

createKickMarker()

-- ═══════════════════════════════════════════
-- ACTUALIZAR HUD
-- ═══════════════════════════════════════════
local function updateHUD()
    if coinsLabel then
        coinsLabel.Text = "🪙 " .. tostring(playerStats.coins)
    end
    if powerLabel then
        powerLabel.Text = "⚡ Potencia: " .. tostring(playerStats.power)
    end
    if ballLabel then
        ballLabel.Text = "⚽ " .. playerStats.ballName .. " (x" .. tostring(playerStats.ballMultiplier) .. ")"
    end
    if zoneLabel then
        local zone = GameConfig.Zones[playerStats.currentZone]
        zoneLabel.Text = "🏟️ " .. (zone and zone.name or "Zona " .. tostring(playerStats.currentZone))
    end
    if incomeLabel then
        incomeLabel.Text = "💰 Income: " .. tostring(playerStats.baseIncomePerSec) .. "/seg"
    end
    if rebirthLabel then
        rebirthLabel.Text = "🔄 Rebirth: " .. tostring(playerStats.rebirths) .. " (x" .. tostring(playerStats.rebirthMultiplier) .. ")"
    end
    
    -- Update stats display
    local statsDisplay = screenGui:FindFirstChild("StatsDisplay")
    if statsDisplay then
        local goalsLabel = statsDisplay:FindFirstChild("GoalsLabel")
        local kicksLabel = statsDisplay:FindFirstChild("KicksLabel")
        local accuracyLabel = statsDisplay:FindFirstChild("AccuracyLabel")
        if goalsLabel then
            goalsLabel.Text = "⚽ Goles: " .. tostring(playerStats.totalGoals)
        end
        if kicksLabel then
            kicksLabel.Text = "👟 Patadas: " .. tostring(playerStats.totalKicks)
        end
        if accuracyLabel then
            local accuracy = playerStats.totalKicks > 0 and math.floor((playerStats.totalGoals / playerStats.totalKicks) * 100) or 0
            accuracyLabel.Text = "🎯 Precisión: " .. tostring(accuracy) .. "%"
        end
    end
end

-- ═══════════════════════════════════════════
-- ACTUALIZAR ZONAS DEL INDICADOR
-- ═══════════════════════════════════════════
local function updateIndicatorZones()
    local greenSize, yellowSize, redSize = GameConfig.CalculateIndicatorZones(
        playerStats.power, selectedDistance, playerStats.currentZone
    )

    if greenZone then
        greenZone.Size = UDim2.new(greenSize, 0, 1, 0)
        greenZone.Position = UDim2.new(0, 0, 0, 0)
    end
    if yellowZone then
        yellowZone.Size = UDim2.new(yellowSize, 0, 1, 0)
        yellowZone.Position = UDim2.new(greenSize, 0, 0, 0)
    end
    if redZone then
        redZone.Size = UDim2.new(redSize, 0, 1, 0)
        redZone.Position = UDim2.new(greenSize + yellowSize, 0, 0, 0)
    end
end

-- ═══════════════════════════════════════════
-- DETERMINAR ZONA DEL INDICADOR SEGÚN POSICIÓN DEL MARCADOR
-- ═══════════════════════════════════════════
local function getIndicatorZone()
    local greenSize, yellowSize, _ = GameConfig.CalculateIndicatorZones(
        playerStats.power, selectedDistance, playerStats.currentZone
    )

    if markerPosition <= greenSize then
        return "green"
    elseif markerPosition <= greenSize + yellowSize then
        return "yellow"
    else
        return "red"
    end
end

-- ═══════════════════════════════════════════
-- OSCILACIÓN DEL INDICADOR
-- ═══════════════════════════════════════════
local runConnection = nil

local function startIndicator()
    if indicatorActive then return end
    indicatorActive = true
    markerPosition = 0
    markerDirection = 1

    if indicatorFrame then
        indicatorFrame.Visible = true
    end
    if resultLabel then
        resultLabel.Text = ""
    end

    updateIndicatorZones()

    local speed = GameConfig.Indicator.oscillationSpeed

    runConnection = RunService.RenderStepped:Connect(function(dt)
        if not indicatorActive then return end

        markerPosition = markerPosition + markerDirection * speed * dt

        if markerPosition >= 1 then
            markerPosition = 1
            markerDirection = -1
        elseif markerPosition <= 0 then
            markerPosition = 0
            markerDirection = 1
        end

        if marker then
            marker.Position = UDim2.new(markerPosition - 0.015, 0, 0, 0)
        end
    end)
end

local function stopIndicator()
    if not indicatorActive then return end
    indicatorActive = false

    if runConnection then
        runConnection:Disconnect()
        runConnection = nil
    end

    local zone = getIndicatorZone()

    -- Enviar patada al servidor
    RemoteEvents.KickBall:FireServer(zone)

    -- Feedback visual inmediato
    if resultLabel then
        if zone == "green" then
            resultLabel.Text = "✅ PERFECTO!"
            resultLabel.TextColor3 = Color3.fromRGB(0, 255, 80)
        elseif zone == "yellow" then
            resultLabel.Text = "⚠️ RIESGO..."
            resultLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        else
            resultLabel.Text = "❌ DEMASIADA FUERZA!"
            resultLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        end
    end

    -- Cooldown: se activa antes del FireServer para evitar race conditions
    -- donde el servidor responde antes de que se setée el cooldown.
    canKick = false
    showCooldownBar(kickCooldown)
    task.delay(kickCooldown, function()
        canKick = true
        if indicatorFrame then
            indicatorFrame.Visible = false
        end
        if kickMarker then
            kickMarker.Transparency = 0.4
        end
    end)
end

-- ═══════════════════════════════════════════
-- KICK COOLDOWN VISUAL INDICATOR
-- ═══════════════════════════════════════════
local cooldownBar = nil
local cooldownFill = nil

if screenGui then
    cooldownBar = Instance.new("Frame")
    cooldownBar.Name = "CooldownBar"
    cooldownBar.Size = UDim2.new(0, 200, 0, 8)
    cooldownBar.Position = UDim2.new(0.5, -100, 0.95, 0)
    cooldownBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    cooldownBar.BorderSizePixel = 0
    cooldownBar.Visible = false
    cooldownBar.Parent = screenGui
    
    local cdCorner = Instance.new("UICorner")
    cdCorner.CornerRadius = UDim.new(0, 4)
    cdCorner.Parent = cooldownBar
    
    cooldownFill = Instance.new("Frame")
    cooldownFill.Name = "Fill"
    cooldownFill.Size = UDim2.new(1, 0, 1, 0)
    cooldownFill.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
    cooldownFill.BorderSizePixel = 0
    cooldownFill.Parent = cooldownBar
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = cooldownFill
    
    local cdLabel = Instance.new("TextLabel")
    cdLabel.Name = "Label"
    cdLabel.Size = UDim2.new(1, 0, 0, 15)
    cdLabel.Position = UDim2.new(0, 0, 1, 2)
    cdLabel.BackgroundTransparency = 1
    cdLabel.Text = "Recargando..."
    cdLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    cdLabel.Font = Enum.Font.GothamBold
    cdLabel.TextSize = 10
    cdLabel.Parent = cooldownBar
end

local function showCooldownBar(duration)
    if not cooldownBar or not cooldownFill then return end
    cooldownBar.Visible = true
    cooldownFill.Size = UDim2.new(0, 0, 1, 0)
    cooldownFill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    
    local TweenService = game:GetService("TweenService")
    local tween = TweenService:Create(cooldownFill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Size = UDim2.new(1, 0, 1, 0),
    })
    tween:Play()
    
    -- Cancel previous tween's Completed callback so it cant hide the bar early
    -- (new call to showCooldownBar while a tween is still running would otherwise
    -- leave the bar visible after the first tween completes)
    tween.Completed:Connect(function()
        cooldownBar.Visible = false
    end)
    
    -- Change color as it fills
    task.spawn(function()
        local elapsed = 0
        while elapsed < duration do
            task.wait(0.1)
            elapsed = elapsed + 0.1
            local progress = elapsed / duration
            if progress > 0.7 then
                cooldownFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
            elseif progress > 0.4 then
                cooldownFill.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- INPUT: CLICK/TAP PARA PATEAR
-- ═══════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not canKick then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        -- Notificar al servidor la posición de patada
        RemoteEvents.SetKickPosition:FireServer(selectedDistance)

        -- Esperar a que el servidor seleccione el portero
        task.wait(0.3)

        -- Iniciar indicador de fuerza
        startIndicator()
        
        -- Hide kick marker during kick
        if kickMarker then
            kickMarker.Transparency = 1
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        if indicatorActive then
            stopIndicator()
        end
    end
end)

-- ═══════════════════════════════════════════
-- SLIDER DE DISTANCIA
-- ═══════════════════════════════════════════
local dragging = false

local function updateDistanceFromInput(inputPos)
    if not distSlider then return end
    local relX = math.clamp(
        (inputPos.X - distSlider.AbsolutePosition.X) / distSlider.AbsoluteSize.X,
        0, 1
    )
    local zone = GameConfig.Zones[playerStats.currentZone]
    if zone then
        selectedDistance = math.floor(zone.minDistance + relX * (zone.maxDistance - zone.minDistance))
        if distLabel then
            distLabel.Text = "📏 Distancia: " .. tostring(selectedDistance) .. " studs"
        end
        if sliderFill then
            sliderFill.Size = UDim2.new(relX, 0, 1, 0)
        end
        updateIndicatorZones()
        -- Update 3D marker position
        updateKickMarkerPosition()
    end
end

if distSlider then
    distSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateDistanceFromInput(input.Position)
        end
    end)

    distSlider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

UserInputService.InputChanged:Connect(function(input)
    if dragging then
        updateDistanceFromInput(input.Position)
    end
end)

-- ═══════════════════════════════════════════
-- BOTÓN CLAIM INCOME
-- ═══════════════════════════════════════════
if claimButton then
    claimButton.MouseButton1Click:Connect(function()
        RemoteEvents.ClaimBaseIncome:FireServer()
        -- Feedback visual
        local originalColor = claimButton.BackgroundColor3
        claimButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
        task.delay(0.2, function()
            claimButton.BackgroundColor3 = originalColor
        end)
    end)
end

-- ═══════════════════════════════════════════
-- RECIBIR EVENTOS DEL SERVIDOR
-- ═══════════════════════════════════════════

-- Actualizar stats
RemoteEvents.UpdateStats.OnClientEvent:Connect(function(stats)
    playerStats = stats
    updateHUD()
    -- Update kick marker when zone changes
    updateKickMarkerPosition()
end)

-- Mostrar portero seleccionado
RemoteEvents.ShowGoalkeepers.OnClientEvent:Connect(function(data)
    currentGoalkeeper = data

    if goalkeeperFrame then
        goalkeeperFrame.Visible = true
    end
    if gkName then
        gkName.Text = "🧠 " .. data.goalkeeperName
    end
    if gkRarity then
        local rarityColors = {
            Common = Color3.fromRGB(180, 180, 180),
            Rare = Color3.fromRGB(85, 170, 255),
            Epic = Color3.fromRGB(170, 85, 255),
            Legendary = Color3.fromRGB(255, 170, 0),
        }
        gkRarity.Text = "[" .. data.rarity .. "]"
        gkRarity.TextColor3 = rarityColors[data.rarity] or Color3.new(1, 1, 1)
    end
    if gkBoss then
        gkBoss.Visible = data.isBoss or false
    end

    -- Ocultar tras 4 segundos
    task.delay(4, function()
        if goalkeeperFrame then
            goalkeeperFrame.Visible = false
        end
    end)
end)

-- Resultado del gol
RemoteEvents.GoalResult.OnClientEvent:Connect(function(data)
    if not resultLabel then return end

    if data.result == "goal" then
        resultLabel.Text = "⚽ GOL! +" .. tostring(data.coinsEarned) .. " coins!"
        resultLabel.TextColor3 = Color3.fromRGB(0, 255, 100)

        -- Update streak
        goalStreak = goalStreak + 1
        streakBonusMultiplier = 1 + (goalStreak - 1) * 0.1 -- 10% bonus per consecutive goal
        updateStreakDisplay()
        animateStreakPopup()

        -- Show streak bonus in result if applicable
        if goalStreak >= 2 then
            task.delay(0.5, function()
                if resultLabel then
                    resultLabel.Text = resultLabel.Text .. " 🔥x" .. tostring(goalStreak)
                end
            end)
        end

        if data.capturedBrainrot then
            task.delay(1.2, function()
                resultLabel.Text = "🧠 Capturaste a " .. data.capturedBrainrot.name .. "!"
                resultLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
            end)
        end

        -- Flash verde en el indicador
        if bar then
            local original = bar.BackgroundColor3
            bar.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
            task.delay(0.5, function()
                bar.BackgroundColor3 = original
            end)
        end

    elseif data.result == "saved" then
        resultLabel.Text = "🧤 " .. data.goalkeeperName .. " la paró!"
        resultLabel.TextColor3 = Color3.fromRGB(255, 100, 0)
        
        -- Reset streak on save
        goalStreak = 0
        streakBonusMultiplier = 1
        updateStreakDisplay()

        -- Flash rojo
        if bar then
            local original = bar.BackgroundColor3
            bar.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            task.delay(0.5, function()
                bar.BackgroundColor3 = original
            end)
        end

    else -- miss
        resultLabel.Text = "💨 El balón se fue lejos!"
        resultLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        
        -- Reset streak on miss
        goalStreak = 0
        streakBonusMultiplier = 1
        updateStreakDisplay()
    end

    -- Resetear estado del indicador para que el jugador pueda patear de nuevo
    -- Esto es necesario porque el servidor responde con GoalResult SIN nueva petición
    -- de kick — el ciclo acaba en el servidor, no en el cliente.
    task.delay(0.5, function()
        indicatorActive = false
        if indicatorFrame then
            indicatorFrame.Visible = false
        end
        if kickMarker then
            kickMarker.Transparency = 0.4
        end
    end)
end)

-- ═══════════════════════════════════════════
-- INCOME COUNTER LOCAL (visual)
-- ═══════════════════════════════════════════
task.spawn(function()
    while task.wait(1) do
        if playerStats.baseIncomePerSec > 0 then
            accumulatedIncome = accumulatedIncome + playerStats.baseIncomePerSec
            if claimButton then
                claimButton.Text = "💰 Claim: " .. tostring(math.floor(accumulatedIncome)) .. " coins"
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- INICIALIZACIÓN
-- ═══════════════════════════════════════════
if indicatorFrame then
    indicatorFrame.Visible = false
end
if goalkeeperFrame then
    goalkeeperFrame.Visible = false
end

-- Inicializar slider con distancia por defecto
local initZone = GameConfig.Zones[playerStats.currentZone]
if initZone then
    selectedDistance = math.floor((initZone.minDistance + initZone.maxDistance) / 2)
    if distLabel then
        distLabel.Text = "📏 Distancia: " .. tostring(selectedDistance) .. " studs"
    end
    if sliderFill then
        local relX = (selectedDistance - initZone.minDistance) / (initZone.maxDistance - initZone.minDistance)
        sliderFill.Size = UDim2.new(relX, 0, 1, 0)
    end
end

updateHUD()
print("[KickClient] Cliente inicializado correctamente")
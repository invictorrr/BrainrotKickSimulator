--[[
    EffectsClient - LocalScript para efectos visuales y sonidos
    Maneja: camera shake, animación de balón, partículas, sonidos, rebirth effect
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local RemoteEvents = ReplicatedStorage.RemoteEvents
local GameConfig = require(ReplicatedStorage.GameConfig)
local SoundConfig = require(ReplicatedStorage.SoundConfig)

-- ═══════════════════════════════════════════
-- SONIDO LOCAL (reproducir en el cliente)
-- ═══════════════════════════════════════════
local soundFolder = Instance.new("Folder")
soundFolder.Name = "ClientSounds"
soundFolder.Parent = player:WaitForChild("PlayerGui")

local function playLocalSound(soundId, volume, playbackSpeed)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. tostring(soundId)
    sound.Volume = volume or 0.5
    sound.PlaybackSpeed = playbackSpeed or 1
    sound.Parent = soundFolder
    sound:Play()
    sound.Ended:Once(function()
        sound:Destroy()
    end)
    return sound
end

-- ═══════════════════════════════════════════
-- CAMERA SHAKE
-- ═══════════════════════════════════════════
local shakeActive = false
local shakeIntensity = 0
local shakeDuration = 0
local shakeElapsed = 0
local originalCFrame = nil

local function startCameraShake(intensity, duration)
    shakeActive = true
    shakeIntensity = intensity
    shakeDuration = duration
    shakeElapsed = 0
    originalCFrame = camera.CFrame
end

local function stopCameraShake()
    shakeActive = false
    shakeIntensity = 0
end

RunService.RenderStepped:Connect(function(dt)
    if not shakeActive then return end

    shakeElapsed = shakeElapsed + dt
    if shakeElapsed >= shakeDuration then
        stopCameraShake()
        return
    end

    local progress = 1 - (shakeElapsed / shakeDuration)
    local currentIntensity = shakeIntensity * progress

    local offsetX = (math.random() - 0.5) * 2 * currentIntensity
    local offsetY = (math.random() - 0.5) * 2 * currentIntensity
    local offsetZ = (math.random() - 0.5) * currentIntensity * 0.5

    camera.CFrame = camera.CFrame * CFrame.new(offsetX, offsetY, offsetZ)
end)

-- ═══════════════════════════════════════════
-- BALÓN VISUAL (vuela hacia la portería)
-- ═══════════════════════════════════════════
local function createBallFlyEffect(startPos, endPos, ballColor, isGoal)
    local ball = Instance.new("Part")
    ball.Name = "KickBall"
    ball.Shape = Enum.PartType.Ball
    ball.Size = Vector3.new(1.2, 1.2, 1.2)
    ball.Color = ballColor or Color3.fromRGB(255, 255, 255)
    ball.Material = Enum.Material.SmoothPlastic
    ball.Anchored = true
    ball.CanCollide = false
    ball.CFrame = CFrame.new(startPos)
    ball.Parent = workspace

    -- Trail effect
    local trail = Instance.new("Trail")
    trail.Attachment0 = Instance.new("Attachment")
    trail.Attachment1 = Instance.new("Attachment")
    trail.Attachment0.Parent = ball
    trail.Attachment1.Parent = ball
    trail.Attachment0.Position = Vector3.new(0, 0, -0.6)
    trail.Attachment1.Position = Vector3.new(0, 0, 0.6)
    trail.Lifetime = 0.4
    trail.MinLength = 0.1
    trail.FaceCamera = true
    trail.LightEmission = 0.5

    local colorSeq = ColorSequence.new(ballColor or Color3.fromRGB(255, 255, 255))
    trail.Color = colorSeq
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0.2),
    })
    trail.Parent = ball

    -- Animate ball flying
    local distance = (endPos - startPos).Magnitude
    local flightTime = math.clamp(distance / 80, 0.3, 1.5)
    local tweenInfo = TweenInfo.new(flightTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local targetCFrame = CFrame.new(endPos)
    if isGoal then
        -- Ball goes into the goal
        targetCFrame = CFrame.new(endPos + Vector3.new(0, 2, 2))
    end

    local tween = TweenService:Create(ball, tweenInfo, {
        CFrame = targetCFrame,
    })
    tween:Play()

    -- Play kick sound
    playLocalSound(SoundConfig.Kick.kickHit, 0.6)

    tween.Completed:Connect(function()
        if isGoal then
            -- Goal explosion effect
            local explosion = Instance.new("Part")
            explosion.Size = Vector3.new(1, 1, 1)
            explosion.CFrame = ball.CFrame
            explosion.Transparency = 1
            explosion.Anchored = true
            explosion.CanCollide = false
            explosion.Parent = workspace

            local particles = Instance.new("ParticleEmitter")
            particles.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50)),
            })
            particles.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 2),
                NumberSequenceKeypoint.new(1, 0),
            })
            particles.Lifetime = NumberRange.new(0.5, 1.5)
            particles.Rate = 80
            particles.Speed = NumberRange.new(3, 10)
            particles.SpreadAngle = Vector2.new(180, 180)
            particles.LightEmission = 1
            particles.Parent = explosion

            -- Goal sound
            playLocalSound(SoundConfig.Result.goal, 0.7)
            playLocalSound(SoundConfig.Result.goalFanfare, 0.4)

            -- Camera shake for goal
            startCameraShake(0.3, 0.5)

            -- Clean up
            task.delay(2, function()
                particles.Enabled = false
                task.delay(1.5, function()
                    if explosion and explosion.Parent then explosion:Destroy() end
                end)
            end)
        else
            -- Miss / saved - smaller effect
            playLocalSound(SoundConfig.Result.saved, 0.5)
            startCameraShake(0.1, 0.2)
        end

        -- Remove ball after a moment
        task.delay(0.5, function()
            if ball and ball.Parent then ball:Destroy() end
        end)
    end)
end

-- ═══════════════════════════════════════════
-- FLASH EFFECT (pantalla completa)
-- ═══════════════════════════════════════════
local function createFlashEffect(color, duration)
    local screenGui = player:FindFirstChild("PlayerGui")
    if not screenGui then return end

    local brainrotUI = screenGui:FindFirstChild("BrainrotGoalKickUI")
    if not brainrotUI then return end

    local flash = Instance.new("Frame")
    flash.Name = "FlashEffect"
    flash.Size = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3 = color
    flash.BackgroundTransparency = 0.3
    flash.BorderSizePixel = 0
    flash.ZIndex = 100
    flash.Parent = brainrotUI

    local tween = TweenService:Create(flash, TweenInfo.new(duration or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1,
    })
    tween:Play()
    tween.Completed:Connect(function()
        flash:Destroy()
    end)
end

-- ═══════════════════════════════════════════
-- REBIRTH VISUAL EFFECT
-- ═══════════════════════════════════════════
local function createRebirthEffect()
    -- Purple flash
    createFlashEffect(Color3.fromRGB(170, 0, 255), 1.5)

    -- Camera shake
    startCameraShake(0.5, 1.0)

    -- Sound
    playLocalSound(SoundConfig.Rebirth.rebirthActivate, 0.8)

    -- Particle ring around player
    local character = player.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local ring = Instance.new("Part")
            ring.Size = Vector3.new(1, 1, 1)
            ring.Shape = Enum.PartType.Ball
            ring.CFrame = hrp.CFrame
            ring.Color = Color3.fromRGB(170, 0, 255)
            ring.Material = Enum.Material.Neon
            ring.Transparency = 0.5
            ring.Anchored = true
            ring.CanCollide = false
            ring.Parent = workspace

            -- Expand ring
            local tween = TweenService:Create(ring, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(30, 30, 30),
                Transparency = 1,
            })
            tween:Play()
            tween.Completed:Connect(function()
                ring:Destroy()
            end)
        end
    end
end

-- ═══════════════════════════════════════════
-- BOSS APPEAR EFFECT
-- ═══════════════════════════════════════════
local function createBossAppearEffect()
    -- Red flash
    createFlashEffect(Color3.fromRGB(255, 0, 0), 0.8)

    -- Dramatic camera shake
    startCameraShake(0.6, 1.0)

    -- Boss sound
    playLocalSound(SoundConfig.Result.bossAppear, 0.8)
end

-- ═══════════════════════════════════════════
-- UI PURCHASE EFFECT
-- ═══════════════════════════════════════════
local function createPurchaseEffect(success)
    if success then
        createFlashEffect(Color3.fromRGB(0, 255, 100), 0.3)
        playLocalSound(SoundConfig.UI.purchase, 0.5)
    else
        playLocalSound(SoundConfig.UI.purchaseFail, 0.3)
    end
end

-- ═══════════════════════════════════════════
-- ESCUCHAR EVENTOS DEL SERVIDOR
-- ═══════════════════════════════════════════

-- ═══════════════════════════════════════════
-- HELPER: Get goal position for current zone
-- ═══════════════════════════════════════════
local function getGoalPosition(zoneId)
    return GameConfig.GetGoalPosition(zoneId or 1)
end

-- ═══════════════════════════════════════════
-- HELPER: Get ball color from current level
-- ═══════════════════════════════════════════
local function getBallColor()
    local GameConfig = require(ReplicatedStorage.GameConfig)
    local data = GameConfig.BallShop[1]
    -- Try to get from player stats (stored locally in KickClient)
    return Color3.fromRGB(255, 255, 255)
end

-- Resultado del gol → efectos visuales
RemoteEvents.GoalResult.OnClientEvent:Connect(function(data)
    local character = player.Character
    if not character then return end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Get the correct goal position based on the player's current zone
    local GameConfig = require(ReplicatedStorage.GameConfig)
    local currentZone = 1
    -- Try to read current zone from HUD
    local screenGui = player:FindFirstChild("PlayerGui")
    if screenGui then
        local brainrotUI = screenGui:FindFirstChild("BrainrotGoalKickUI")
        if brainrotUI then
            local hud = brainrotUI:FindFirstChild("HUD")
            if hud then
                local zoneLabel = hud:FindFirstChild("ZoneLabel")
                if zoneLabel then
                    -- Parse zone from label text
                    local zoneText = zoneLabel.Text
                    for zoneId, zone in pairs(GameConfig.Zones) do
                        if zoneText:find(zone.name) then
                            currentZone = zoneId
                            break
                        end
                    end
                end
            end
        end
    end

    local goalPos = getGoalPosition(currentZone)
    local ballColor = Color3.fromRGB(255, 255, 255)

    if data.result == "goal" then
        if not data.useServerPhysics then
            createBallFlyEffect(hrp.Position, goalPos, ballColor, true)
        end
        createFlashEffect(Color3.fromRGB(0, 255, 100), 0.5)

        -- Si capturó un brainrot, efecto extra
        if data.capturedBrainrot then
            task.delay(1, function()
                createFlashEffect(Color3.fromRGB(255, 170, 0), 0.8)
                if data.capturedBrainrot.rarity == "Legendary" then
                    startCameraShake(0.5, 1.0)
                    playLocalSound(SoundConfig.Result.goalFanfare, 0.8)
                elseif data.capturedBrainrot.rarity == "Epic" then
                    startCameraShake(0.3, 0.5)
                    playLocalSound(SoundConfig.Result.goalFanfare, 0.5)
                end
            end)
        end

    elseif data.result == "saved" then
        if not data.useServerPhysics then
            createBallFlyEffect(hrp.Position, goalPos, ballColor, false)
        end
        createFlashEffect(Color3.fromRGB(255, 100, 0), 0.3)

    else -- miss
        if not data.useServerPhysics then
            createBallFlyEffect(hrp.Position, goalPos + Vector3.new(0, 15, 0), ballColor, false)
        end
        playLocalSound(SoundConfig.Result.miss, 0.4)
        createFlashEffect(Color3.fromRGB(255, 50, 50), 0.3)
    end
end)

-- Portero revelado → boss effect
RemoteEvents.ShowGoalkeepers.OnClientEvent:Connect(function(data)
    if data.isBoss then
        task.delay(1.5, function()
            createBossAppearEffect()
        end)
    end
end)

-- Camera effect event (from server)
RemoteEvents.CameraEffect.OnClientEvent:Connect(function(effectType, params)
    params = params or {}
    if effectType == "shake" then
        startCameraShake(params.intensity or 0.3, params.duration or 0.5)
    elseif effectType == "flash" then
        createFlashEffect(params.color or Color3.new(1, 1, 1), params.duration or 0.5)
    elseif effectType == "rebirth" then
        createRebirthEffect()
    end
end)

-- Play sound event (from server)
RemoteEvents.PlaySound.OnClientEvent:Connect(function(soundId, volume, playbackSpeed)
    playLocalSound(soundId, volume, playbackSpeed)
end)

-- ═══════════════════════════════════════════
-- UI BUTTON SOUNDS
-- ═══════════════════════════════════════════
task.delay(2, function()
    local screenGui = player:FindFirstChild("PlayerGui")
    if screenGui then
        local brainrotUI = screenGui:FindFirstChild("BrainrotGoalKickUI")
        if brainrotUI then
            -- Add click sounds to all buttons
            for _, descendant in brainrotUI:GetDescendants() do
                if descendant:IsA("TextButton") then
                    descendant.MouseButton1Click:Connect(function()
                        playLocalSound(SoundConfig.UI.buttonClick, 0.2)
                    end)
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- AMBIENT SOUND LOOP (changes based on zone)
-- ═══════════════════════════════════════════
local ambientSound = Instance.new("Sound")
ambientSound.SoundId = "rbxassetid://" .. tostring(SoundConfig.Ambient.zone1)
ambientSound.Volume = 0.15
ambientSound.Looped = true
ambientSound.Parent = soundFolder
ambientSound:Play()

-- Track current zone and change ambient sound
local lastAmbientZone = 1
task.spawn(function()
    local GameConfig = require(ReplicatedStorage.GameConfig)
    while task.wait(2) do
        -- Determine current zone from player position
        local character = player.Character
        if character then
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local x = hrp.Position.X
                local currentZone = 1
                if x >= 350 then
                    currentZone = 3
                elseif x >= 150 then
                    currentZone = 2
                else
                    currentZone = 1
                end
                
                if currentZone ~= lastAmbientZone then
                    lastAmbientZone = currentZone
                    local zoneSoundId = SoundConfig.Ambient.zone1
                    if currentZone == 2 and SoundConfig.Ambient.zone2 then
                        zoneSoundId = SoundConfig.Ambient.zone2
                    elseif currentZone == 3 and SoundConfig.Ambient.zone3 then
                        zoneSoundId = SoundConfig.Ambient.zone3
                    end
                    
                    -- Fade out, change, fade in
                    local fadeOut = TweenService:Create(ambientSound, TweenInfo.new(1), {Volume = 0})
                    fadeOut:Play()
                    fadeOut.Completed:Connect(function()
                        ambientSound.SoundId = "rbxassetid://" .. tostring(zoneSoundId)
                        ambientSound:Play()
                        local fadeIn = TweenService:Create(ambientSound, TweenInfo.new(1.5), {Volume = 0.15})
                        fadeIn:Play()
                    end)
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- POWER CHARGE SOUND (cuando se inicia el indicador)
-- ═══════════════════════════════════════════
task.delay(1, function()
    local screenGui = player:FindFirstChild("PlayerGui")
    if screenGui then
        local brainrotUI = screenGui:FindFirstChild("BrainrotGoalKickUI")
        if brainrotUI then
            local indicatorFrame = brainrotUI:FindFirstChild("IndicatorFrame")
            if indicatorFrame then
                -- Watch for indicator becoming visible
                local indicatorVisible = false
                RunService.RenderStepped:Connect(function()
                    if indicatorFrame.Visible and not indicatorVisible then
                        indicatorVisible = true
                        playLocalSound(SoundConfig.Kick.powerCharge, 0.3)
                    elseif not indicatorFrame.Visible then
                        indicatorVisible = false
                    end
                end)
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- CAPTURE CELEBRATION POPUP
-- ═══════════════════════════════════════════
local function createCaptureCelebration(brainrotData)
    if not brainrotData then return end

    local screenGui = player:FindFirstChild("PlayerGui")
    if not screenGui then return end
    local brainrotUI = screenGui:FindFirstChild("BrainrotGoalKickUI")
    if not brainrotUI then return end

    local rarityColors = {
        Common = {bg = Color3.fromRGB(60, 60, 60), text = Color3.fromRGB(180, 180, 180), glow = Color3.fromRGB(150, 150, 150)},
        Rare = {bg = Color3.fromRGB(20, 40, 80), text = Color3.fromRGB(85, 170, 255), glow = Color3.fromRGB(50, 100, 255)},
        Epic = {bg = Color3.fromRGB(40, 10, 60), text = Color3.fromRGB(170, 85, 255), glow = Color3.fromRGB(130, 50, 255)},
        Legendary = {bg = Color3.fromRGB(60, 30, 0), text = Color3.fromRGB(255, 170, 0), glow = Color3.fromRGB(255, 130, 0)},
    }

    local colors = rarityColors[brainrotData.rarity] or rarityColors.Common

    -- Create popup frame
    local popup = Instance.new("Frame")
    popup.Name = "CapturePopup"
    popup.Size = UDim2.new(0, 350, 0, 180)
    popup.Position = UDim2.new(0.5, -175, 0.3, 0)
    popup.BackgroundColor3 = colors.bg
    popup.BorderSizePixel = 2
    popup.BorderColor3 = colors.text
    popup.ZIndex = 200
    popup.Parent = brainrotUI

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = popup

    -- Glow effect behind popup
    local glow = Instance.new("Frame")
    glow.Size = UDim2.new(1.1, 0, 1.1, 0)
    glow.Position = UDim2.new(-0.05, 0, -0.05, 0)
    glow.BackgroundColor3 = colors.glow
    glow.BackgroundTransparency = 0.7
    glow.ZIndex = 199
    glow.Parent = popup
    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0, 16)
    glowCorner.Parent = glow

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.25, 0)
    title.BackgroundTransparency = 1
    title.Text = brainrotData.isBoss and "BOSS CAPTURADO!" or "BRAINROT CAPTURADO!"
    title.TextColor3 = colors.text
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 22
    title.ZIndex = 201
    title.Parent = popup

    -- Brainrot name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.25, 0)
    nameLabel.Position = UDim2.new(0, 0, 0.25, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = brainrotData.name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 20
    nameLabel.ZIndex = 201
    nameLabel.Parent = popup

    -- Rarity
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 0.2, 0)
    rarityLabel.Position = UDim2.new(0, 0, 0.5, 0)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = "[" .. brainrotData.rarity .. "]"
    rarityLabel.TextColor3 = colors.text
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.TextSize = 16
    rarityLabel.ZIndex = 201
    rarityLabel.Parent = popup

    -- Income
    local incomeLabel = Instance.new("TextLabel")
    incomeLabel.Size = UDim2.new(1, 0, 0.2, 0)
    incomeLabel.Position = UDim2.new(0, 0, 0.7, 0)
    incomeLabel.BackgroundTransparency = 1
    incomeLabel.Text = "+" .. tostring(brainrotData.coinsPerSec) .. " coins/seg en la base"
    incomeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    incomeLabel.Font = Enum.Font.GothamBold
    incomeLabel.TextSize = 14
    incomeLabel.ZIndex = 201
    incomeLabel.Parent = popup

    -- Animate in
    popup.Size = UDim2.new(0, 0, 0, 0)
    popup.Position = UDim2.new(0.5, 0, 0.4, 0)
    local tweenIn = TweenService:Create(popup, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 350, 0, 180),
        Position = UDim2.new(0.5, -175, 0.3, 0),
    })
    tweenIn:Play()

    -- Auto dismiss after 4 seconds
    task.delay(4, function()
        if popup and popup.Parent then
            local tweenOut = TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 0, 0, 0),
                Position = UDim2.new(0.5, 0, 0.4, 0),
                BackgroundTransparency = 1,
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                popup:Destroy()
            end)
        end
    end)
end

-- ═══════════════════════════════════════════
-- ZONE UNLOCK CELEBRATION
-- ═══════════════════════════════════════════
local function createZoneUnlockEffect(zoneName)
    local screenGui = player:FindFirstChild("PlayerGui")
    if not screenGui then return end
    local brainrotUI = screenGui:FindFirstChild("BrainrotGoalKickUI")
    if not brainrotUI then return end

    -- Big announcement
    local announcement = Instance.new("TextLabel")
    announcement.Name = "ZoneUnlockAnnouncement"
    announcement.Size = UDim2.new(0.6, 0, 0.15, 0)
    announcement.Position = UDim2.new(0.2, 0, 0.35, 0)
    announcement.BackgroundColor3 = Color3.fromRGB(0, 50, 100)
    announcement.BackgroundTransparency = 0.3
    announcement.Text = "NUEVA ZONA DESBLOQUEADA!\n" .. zoneName
    announcement.TextColor3 = Color3.fromRGB(255, 255, 255)
    announcement.Font = Enum.Font.GothamBlack
    announcement.TextSize = 28
    announcement.TextStrokeTransparency = 0
    announcement.TextStrokeColor3 = Color3.fromRGB(0, 50, 150)
    announcement.ZIndex = 200
    announcement.Parent = brainrotUI

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = announcement

    -- Effects
    startCameraShake(0.4, 1.5)
    createFlashEffect(Color3.fromRGB(0, 100, 255), 1.0)
    playLocalSound(SoundConfig.Result.goalFanfare, 0.7)

    -- Animate in
    announcement.TextTransparency = 1
    announcement.BackgroundTransparency = 1
    local tweenIn = TweenService:Create(announcement, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextTransparency = 0,
        BackgroundTransparency = 0.3,
    })
    tweenIn:Play()

    -- Auto dismiss
    task.delay(5, function()
        if announcement and announcement.Parent then
            local tweenOut = TweenService:Create(announcement, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                TextTransparency = 1,
                BackgroundTransparency = 1,
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                announcement:Destroy()
            end)
        end
    end)
end

-- ═══════════════════════════════════════════
-- LISTEN FOR CAPTURE AND ZONE UNLOCK EVENTS
-- ═══════════════════════════════════════════

-- When a brainrot is captured, show celebration popup
RemoteEvents.GoalResult.OnClientEvent:Connect(function(data)
    if data.result == "goal" and data.capturedBrainrot then
        task.delay(1.5, function()
            createCaptureCelebration(data.capturedBrainrot)
        end)
    end
end)

-- When stats update, check for zone unlock
local lastKnownZone = 1
RemoteEvents.UpdateStats.OnClientEvent:Connect(function(stats)
    if stats.currentZone and stats.currentZone > lastKnownZone then
        local GameConfig = require(ReplicatedStorage.GameConfig)
        local zone = GameConfig.Zones[stats.currentZone]
        if zone then
            createZoneUnlockEffect(zone.name)
        end
        lastKnownZone = stats.currentZone
    end
end)

-- ═══════════════════════════════════════════
-- ZONE AMBIENT VISUAL EFFECTS
-- ═══════════════════════════════════════════
task.delay(5, function()
    local zonesFolder = workspace:FindFirstChild("Zones")
    if not zonesFolder then return end

    local zoneParticleColors = {
        [1] = {Color3.fromRGB(100, 255, 100), Color3.fromRGB(50, 200, 50)},  -- Green particles
        [2] = {Color3.fromRGB(100, 150, 255), Color3.fromRGB(50, 100, 200)}, -- Blue particles
        [3] = {Color3.fromRGB(255, 100, 50), Color3.fromRGB(200, 50, 0)},    -- Red/orange particles
    }

    for zoneId, zoneModel in pairs(zonesFolder:GetChildren()) do
        if zoneModel:IsA("Model") and zoneModel.Name:find("Zone") then
            local zoneNum = tonumber(zoneModel.Name:match("%d+"))
            if zoneNum and zoneParticleColors[zoneNum] then
                local colors = zoneParticleColors[zoneNum]

                -- Create ambient particle emitter at the zone center
                local zoneEmitter = Instance.new("Part")
                zoneEmitter.Name = "AmbientParticles"
                zoneEmitter.Size = Vector3.new(1, 1, 1)
                zoneEmitter.Transparency = 1
                zoneEmitter.Anchored = true
                zoneEmitter.CanCollide = false
                local zoneData = GameConfig.Zones[zoneNum]
                if zoneData then
                    zoneEmitter.CFrame = zoneModel:GetPivot() * CFrame.new(0, 15, -(zoneData.maxDistance or 80) / 2)
                else
                    zoneEmitter.CFrame = zoneModel:GetPivot() * CFrame.new(0, 15, -40)
                end
                zoneEmitter.Parent = zoneModel

                local particles = Instance.new("ParticleEmitter")
                particles.Color = ColorSequence.new(colors[1], colors[2])
                particles.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.3),
                    NumberSequenceKeypoint.new(0.5, 0.5),
                    NumberSequenceKeypoint.new(1, 0),
                })
                particles.Lifetime = NumberRange.new(3, 6)
                particles.Rate = 8
                particles.Speed = NumberRange.new(0.5, 2)
                particles.SpreadAngle = Vector2.new(180, 180)
                particles.LightEmission = 0.8
                particles.RotSpeed = NumberRange.new(-180, 180)
                particles.Parent = zoneEmitter
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- WELCOME HINT (shows on first join)
-- ═══════════════════════════════════════════
task.delay(3, function()
    local screenGui = player:FindFirstChild("PlayerGui")
    if not screenGui then return end
    local brainrotUI = screenGui:FindFirstChild("BrainrotGoalKickUI")
    if not brainrotUI then return end

    local hint = Instance.new("Frame")
    hint.Name = "WelcomeHint"
    hint.Size = UDim2.new(0, 400, 0, 120)
    hint.Position = UDim2.new(0.5, -200, 0.7, 0)
    hint.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    hint.BackgroundTransparency = 0.2
    hint.BorderSizePixel = 0
    hint.ZIndex = 150
    hint.Parent = brainrotUI

    local hintCorner = Instance.new("UICorner")
    hintCorner.CornerRadius = UDim.new(0, 12)
    hintCorner.Parent = hint

    local hintStroke = Instance.new("UIStroke")
    hintStroke.Color = Color3.fromRGB(100, 100, 255)
    hintStroke.Thickness = 2
    hintStroke.Parent = hint

    local hintLabel = Instance.new("TextLabel")
    hintLabel.Size = UDim2.new(1, 0, 0.7, 0)
    hintLabel.BackgroundTransparency = 1
    hintLabel.Text = "Bienvenido al Brainrot Goal Kick Simulator!\n\nClick para patear | Ajusta la distancia\nMete gol para capturar brainrots!"
    hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    hintLabel.Font = Enum.Font.GothamBold
    hintLabel.TextSize = 14
    hintLabel.ZIndex = 151
    hintLabel.Parent = hint

    local dismissBtn = Instance.new("TextButton")
    dismissBtn.Size = UDim2.new(0.5, 0, 0.25, 0)
    dismissBtn.Position = UDim2.new(0.25, 0, 0.75, 0)
    dismissBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    dismissBtn.BorderSizePixel = 0
    dismissBtn.Text = "A JUGAR!"
    dismissBtn.TextColor3 = Color3.new(1, 1, 1)
    dismissBtn.Font = Enum.Font.GothamBold
    dismissBtn.TextSize = 14
    dismissBtn.ZIndex = 151
    dismissBtn.Parent = hint

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = dismissBtn

    dismissBtn.MouseButton1Click:Connect(function()
        local tweenOut = TweenService:Create(hint, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.7, 0),
            BackgroundTransparency = 1,
        })
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            hint:Destroy()
        end)
    end)

    -- Auto-dismiss after 15 seconds
    task.delay(15, function()
        if hint and hint.Parent then
            dismissBtn:MouseButton1Click()
        end
    end)
end)

-- ═══════════════════════════════════════════
-- STREAK BONUS NOTIFICATION (from server)
-- ═══════════════════════════════════════════
local function showStreakBonusNotification(streak, bonus)
    local screenGui = player:FindFirstChild("PlayerGui")
    if not screenGui then return end
    local brainrotUI = screenGui:FindFirstChild("BrainrotGoalKickUI")
    if not brainrotUI then return end

    local notif = Instance.new("TextLabel")
    notif.Name = "StreakBonusNotif"
    notif.Size = UDim2.new(0, 300, 0, 40)
    notif.Position = UDim2.new(0.5, -150, 0.15, 0)
    notif.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    notif.BackgroundTransparency = 0.3
    notif.Text = "STREAK x" .. tostring(streak) .. "! +" .. string.format("%.0f", bonus * 100) .. "% bonus coins!"
    notif.TextColor3 = Color3.fromRGB(255, 255, 255)
    notif.Font = Enum.Font.GothamBlack
    notif.TextSize = 16
    notif.TextStrokeTransparency = 0
    notif.TextStrokeColor3 = Color3.fromRGB(100, 30, 0)
    notif.ZIndex = 100
    notif.Parent = brainrotUI

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notif

    -- Animate in
    notif.TextTransparency = 1
    local tweenIn = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextTransparency = 0,
    })
    tweenIn:Play()

    -- Auto dismiss
    task.delay(2.5, function()
        if notif and notif.Parent then
            local tweenOut = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                TextTransparency = 1,
                BackgroundTransparency = 1,
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                notif:Destroy()
            end)
        end
    end)
end

-- Listen for streak from GoalResult
RemoteEvents.GoalResult.OnClientEvent:Connect(function(data)
    if data.result == "goal" and data.goalStreak and data.goalStreak >= 2 then
        local bonus = (data.goalStreak - 1) * 0.1
        task.delay(0.8, function()
            showStreakBonusNotification(data.goalStreak, bonus)
        end)
    end
end)

print("[EffectsClient] Efectos visuales y sonidos inicializados")
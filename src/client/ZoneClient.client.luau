--[[
    ZoneClient - LocalScript for zone navigation and teleportation
    Handles: zone selection UI, teleport buttons, zone unlock indicators
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local RemoteEvents = ReplicatedStorage.RemoteEvents
local GameConfig = require(ReplicatedStorage.GameConfig)

-- ═══════════════════════════════════════════
-- WAIT FOR UI
-- ═══════════════════════════════════════════
local screenGui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotGoalKickUI", 10)
if not screenGui then return end

-- ═══════════════════════════════════════════
-- CREATE ZONE NAVIGATION PANEL
-- ═══════════════════════════════════════════
local zonePanel = Instance.new("Frame")
zonePanel.Name = "ZonePanel"
zonePanel.Size = UDim2.new(0, 300, 0, 280)
zonePanel.Position = UDim2.new(0.5, -150, 0.5, -140)
zonePanel.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
zonePanel.BorderSizePixel = 0
zonePanel.Visible = false
zonePanel.Parent = screenGui

local zoneCorner = Instance.new("UICorner")
zoneCorner.CornerRadius = UDim.new(0, 12)
zoneCorner.Parent = zonePanel

local zoneStroke = Instance.new("UIStroke")
zoneStroke.Color = Color3.fromRGB(100, 100, 255)
zoneStroke.Thickness = 2
zoneStroke.Parent = zonePanel

-- Title
local zoneTitle = Instance.new("TextLabel")
zoneTitle.Size = UDim2.new(1, 0, 0, 40)
zoneTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
zoneTitle.BorderSizePixel = 0
zoneTitle.Text = "🏟️ SELECCIONAR ZONA"
zoneTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
zoneTitle.Font = Enum.Font.GothamBlack
zoneTitle.TextSize = 18
zoneTitle.Parent = zonePanel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = zoneTitle

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(1, -40, 0, 3)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = zonePanel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    local tween = TweenService:Create(zonePanel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
    })
    tween:Play()
    tween.Completed:Connect(function()
        zonePanel.Visible = false
        zonePanel.Size = UDim2.new(0, 300, 0, 280)
        zonePanel.Position = UDim2.new(0.5, -150, 0.5, -140)
    end)
end)

-- Zone buttons container
local zonesContainer = Instance.new("Frame")
zonesContainer.Name = "ZonesContainer"
zonesContainer.Size = UDim2.new(1, -20, 1, -90)
zonesContainer.Position = UDim2.new(0, 10, 0, 50)
zonesContainer.BackgroundTransparency = 1
zonesContainer.Parent = zonePanel

local zonesLayout = Instance.new("UIListLayout")
zonesLayout.Padding = UDim.new(0, 8)
zonesLayout.SortOrder = Enum.SortOrder.LayoutOrder
zonesLayout.Parent = zonesContainer

-- ═══════════════════════════════════════════
-- CREATE ZONE BUTTONS
-- ═══════════════════════════════════════════
local playerStats = {
    currentZone = 1,
    power = 1,
}

local zoneColors = {
    [1] = Color3.fromRGB(50, 150, 50),   -- Green for Zone 1
    [2] = Color3.fromRGB(50, 100, 200),   -- Blue for Zone 2
    [3] = Color3.fromRGB(200, 50, 50),    -- Red for Zone 3
}

local zoneEmojis = {
    [1] = "🌿",
    [2] = "🏟️",
    [3] = "☢️",
}

local function createZoneButton(zoneId)
    local zone = GameConfig.Zones[zoneId]
    if not zone then return end

    local btn = Instance.new("TextButton")
    btn.Name = "ZoneBtn_" .. tostring(zoneId)
    btn.Size = UDim2.new(1, 0, 0, 50)
    btn.BackgroundColor3 = zoneColors[zoneId] or Color3.fromRGB(80, 80, 80)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.LayoutOrder = zoneId
    btn.AutoButtonColor = true
    btn.Parent = zonesContainer

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    -- Zone info label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(0.7, 0, 1, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = zoneEmojis[zoneId] .. " " .. zone.name
    infoLabel.TextColor3 = Color3.new(1, 1, 1)
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Font = Enum.Font.GothamBold
    infoLabel.TextSize = 14
    infoLabel.Parent = btn

    local infoPad = Instance.new("UIPadding")
    infoPad.PaddingLeft = UDim.new(0, 12)
    infoPad.Parent = infoLabel

    -- Power requirement label
    local reqLabel = Instance.new("TextLabel")
    reqLabel.Size = UDim2.new(0.3, 0, 1, 0)
    reqLabel.Position = UDim2.new(0.7, 0, 0, 0)
    reqLabel.BackgroundTransparency = 1
    reqLabel.Text = "⚡" .. tostring(zone.requiredPower)
    reqLabel.TextColor3 = Color3.fromRGB(255, 255, 200)
    reqLabel.Font = Enum.Font.GothamBold
    reqLabel.TextSize = 12
    reqLabel.Parent = btn

    -- Lock overlay
    local lockLabel = Instance.new("TextLabel")
    lockLabel.Name = "LockLabel"
    lockLabel.Size = UDim2.new(1, 0, 1, 0)
    lockLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    lockLabel.BackgroundTransparency = 0.5
    lockLabel.Text = "🔒 Bloqueado (⚡" .. tostring(zone.requiredPower) .. ")"
    lockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    lockLabel.Font = Enum.Font.GothamBold
    lockLabel.TextSize = 14
    lockLabel.Visible = true
    lockLabel.ZIndex = 5
    lockLabel.Parent = btn

    local lockCorner = Instance.new("UICorner")
    lockCorner.CornerRadius = UDim.new(0, 8)
    lockCorner.Parent = lockLabel

    -- Click handler
    btn.MouseButton1Click:Connect(function()
        if zoneId <= playerStats.currentZone then
            -- Teleport to zone
            RemoteEvents.ZoneTeleport:FireServer(zoneId)
            -- Close panel with animation
            closeBtn:MouseButton1Click()
        end
    end)

    return btn
end

-- Create zone buttons
for zoneId, _ in pairs(GameConfig.Zones) do
    createZoneButton(zoneId)
end

-- Base button
local baseBtn = Instance.new("TextButton")
baseBtn.Name = "BaseBtn"
baseBtn.Size = UDim2.new(1, 0, 0, 50)
baseBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 40)
baseBtn.BorderSizePixel = 0
baseBtn.Text = "🏠 Ir a la Base"
baseBtn.TextColor3 = Color3.new(1, 1, 1)
baseBtn.Font = Enum.Font.GothamBold
baseBtn.TextSize = 14
baseBtn.LayoutOrder = 0
baseBtn.AutoButtonColor = true
baseBtn.Parent = zonesContainer

local baseCorner = Instance.new("UICorner")
baseCorner.CornerRadius = UDim.new(0, 8)
baseCorner.Parent = baseBtn

baseBtn.MouseButton1Click:Connect(function()
    RemoteEvents.ZoneTeleport:FireServer(0) -- 0 = base
    closeBtn:MouseButton1Click()
end)

-- ═══════════════════════════════════════════
-- UPDATE ZONE LOCKS
-- ═══════════════════════════════════════════
local function updateZoneLocks()
    for zoneId, _ in pairs(GameConfig.Zones) do
        local btn = zonesContainer:FindFirstChild("ZoneBtn_" .. tostring(zoneId))
        if btn then
            local lockLabel = btn:FindFirstChild("LockLabel")
            if lockLabel then
                lockLabel.Visible = zoneId > playerStats.currentZone
            end
        end
    end
end

-- ═══════════════════════════════════════════
-- ZONE BUTTON IN HUD
-- ═══════════════════════════════════════════
local hud = screenGui:FindFirstChild("HUD")
if hud then
    local zoneNavBtn = hud:FindFirstChild("ZoneNavBtn")
    if not zoneNavBtn then
        zoneNavBtn = Instance.new("TextButton")
        zoneNavBtn.Name = "ZoneNavBtn"
        zoneNavBtn.Size = UDim2.new(0, 120, 0, 30)
        zoneNavBtn.Position = UDim2.new(1, -130, 0, 0)
        zoneNavBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 150)
        zoneNavBtn.BorderSizePixel = 0
        zoneNavBtn.Text = "🏟️ Zonas"
        zoneNavBtn.TextColor3 = Color3.new(1, 1, 1)
        zoneNavBtn.Font = Enum.Font.GothamBold
        zoneNavBtn.TextSize = 13
        zoneNavBtn.Parent = hud

        local navCorner = Instance.new("UICorner")
        navCorner.CornerRadius = UDim.new(0, 6)
        navCorner.Parent = zoneNavBtn

        zoneNavBtn.MouseButton1Click:Connect(function()
            if zonePanel.Visible then
                closeBtn:MouseButton1Click()
            else
                zonePanel.Visible = true
                zonePanel.Size = UDim2.new(0, 0, 0, 0)
                zonePanel.Position = UDim2.new(0.5, 0, 0.5, 0)
                local tween = TweenService:Create(zonePanel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 300, 0, 280),
                    Position = UDim2.new(0.5, -150, 0.5, -140),
                })
                tween:Play()
            end
        end)
    end
end

-- ═══════════════════════════════════════════
-- LISTEN FOR STATS UPDATES
-- ═══════════════════════════════════════════
RemoteEvents.UpdateStats.OnClientEvent:Connect(function(stats)
    playerStats.currentZone = stats.currentZone or 1
    playerStats.power = stats.power or 1
    updateZoneLocks()
end)

-- ═══════════════════════════════════════════
-- TELEPORT PADS IN 3D WORLD (visual indicators)
-- ═══════════════════════════════════════════
-- Create zone teleport pad indicators near spawn
local function createTeleportPads()
    local zonesFolder = workspace:FindFirstChild("Zones")
    if not zonesFolder then return end

    for zoneId, zoneData in pairs(GameConfig.Zones) do
        local zoneModel = zonesFolder:FindFirstChild("Zone" .. tostring(zoneId))
        if zoneModel then
            -- Check if pad already exists
            if not zoneModel:FindFirstChild("TeleportPad") then
                local pad = Instance.new("Part")
                pad.Name = "TeleportPad"
                pad.Size = Vector3.new(8, 0.5, 8)
                pad.CFrame = zoneModel:GetPivot() * CFrame.new(0, 0.25, -(zoneData.maxDistance or 80) / 2)
                pad.Color = zoneColors[zoneId] or Color3.fromRGB(100, 100, 100)
                pad.Material = Enum.Material.Neon
                pad.Transparency = 0.3
                pad.Anchored = true
                pad.CanCollide = false
                pad.Parent = zoneModel

                -- Pad label
                local billboard = Instance.new("BillboardGui")
                billboard.Size = UDim2.new(0, 150, 0, 50)
                billboard.StudsOffset = Vector3.new(0, 4, 0)
                billboard.AlwaysOnTop = true
                billboard.Parent = pad

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Text = "🏟️ " .. zoneData.name .. "\nClick Zonas para teletransportarte"
                label.TextColor3 = Color3.new(1, 1, 1)
                label.Font = Enum.Font.GothamBold
                label.TextSize = 11
                label.Parent = billboard
            end
        end
    end
end

task.delay(3, createTeleportPads)

-- ═══════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════
updateZoneLocks()
print("[ZoneClient] Zone navigation initialized")
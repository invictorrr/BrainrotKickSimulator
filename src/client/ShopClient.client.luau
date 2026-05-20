--[[
    ShopClient - LocalScript para tiendas y rebirth
    Maneja: abrir/cerrar paneles, comprar potencia/pelotas, hacer rebirth
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local RemoteEvents = ReplicatedStorage.RemoteEvents
local GameConfig = require(ReplicatedStorage.GameConfig)

-- ═══════════════════════════════════════════
-- ESPERAR UI
-- ═══════════════════════════════════════════
local screenGui = player:WaitForChild("PlayerGui"):WaitForChild("BrainrotGoalKickUI", 10)
if not screenGui then return end

local nav = screenGui:FindFirstChild("Navigation")
local powerPanel = screenGui:FindFirstChild("PowerShopPanel")
local ballPanel = screenGui:FindFirstChild("BallShopPanel")
local rebirthPanel = screenGui:FindFirstChild("RebirthPanel")

-- ═══════════════════════════════════════════
-- ESTADO
-- ═══════════════════════════════════════════
local playerStats = {
    coins = 0,
    power = 1,
    ballLevel = 1,
    rebirths = 0,
    brainrotCount = 0,
}

local openPanel = nil

-- ═══════════════════════════════════════════
-- ABRIR/CERRAR PANELES
-- ═══════════════════════════════════════════
local function closeAllPanels()
    if powerPanel then powerPanel.Visible = false end
    if ballPanel then ballPanel.Visible = false end
    if rebirthPanel then rebirthPanel.Visible = false end
    openPanel = nil
end

local function togglePanel(panel)
    if not panel then return end
    if openPanel == panel then
        closeAllPanels()
    else
        closeAllPanels()
        panel.Visible = true
        openPanel = panel
    end
end

-- ═══════════════════════════════════════════
-- BOTONES DE NAVEGACIÓN
-- ═══════════════════════════════════════════
if nav then
    local powerBtn = nav:FindFirstChild("PowerShopBtn")
    local ballBtn = nav:FindFirstChild("BallShopBtn")
    local rebirthBtn = nav:FindFirstChild("RebirthBtn")

    if powerBtn then
        powerBtn.MouseButton1Click:Connect(function()
            togglePanel(powerPanel)
        end)
    end
    if ballBtn then
        ballBtn.MouseButton1Click:Connect(function()
            togglePanel(ballPanel)
        end)
    end
    if rebirthBtn then
        rebirthBtn.MouseButton1Click:Connect(function()
            togglePanel(rebirthPanel)
        end)
    end
end

-- ═══════════════════════════════════════════
-- BOTONES DE CERRAR
-- ═══════════════════════════════════════════
if powerPanel then
    local closeBtn = powerPanel:FindFirstChild("CloseBtn")
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(closeAllPanels)
    end
end
if ballPanel then
    local closeBtn = ballPanel:FindFirstChild("CloseBtn")
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(closeAllPanels)
    end
end
if rebirthPanel then
    local closeBtn = rebirthPanel:FindFirstChild("CloseBtn")
    if closeBtn then
        closeBtn.MouseButton1Click:Connect(closeAllPanels)
    end
end

-- ═══════════════════════════════════════════
-- TIENDA DE POTENCIA - COMPRAR
-- ═══════════════════════════════════════════
if powerPanel then
    local scroll = powerPanel:FindFirstChild("ItemsScroll")
    if scroll then
        for _, item in scroll:GetChildren() do
            if item:IsA("Frame") and item.Name:find("PowerItem") then
                local buyBtn = item:FindFirstChild("BuyBtn")
                if buyBtn then
                    buyBtn.MouseButton1Click:Connect(function()
                        -- Feedback visual
                        buyBtn.Text = "Comprando..."
                        RemoteEvents.BuyPower:FireServer()
                        task.wait(0.3)
                        buyBtn.Text = "✓"
                        buyBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
                        task.wait(0.5)
                        buyBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
                    end)
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════
-- TIENDA DE PELOTAS - COMPRAR
-- ═══════════════════════════════════════════
if ballPanel then
    local scroll = ballPanel:FindFirstChild("ScrollingFrame") or ballPanel:FindFirstChildWhichIsA("ScrollingFrame")
    -- Buscar botones de compra en los items
    for _, child in ballPanel:GetDescendants() do
        if child:IsA("TextButton") and child.Name == "BuyBtn" then
            child.MouseButton1Click:Connect(function()
                child.Text = "Comprando..."
                RemoteEvents.BuyBall:FireServer()
                task.wait(0.3)
                child.Text = "✓"
                child.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
                task.wait(0.5)
                child.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
            end)
        end
    end
end

-- ═══════════════════════════════════════════
-- REBIRTH
-- ═══════════════════════════════════════════
if rebirthPanel then
    local rbButton = rebirthPanel:FindFirstChild("RebirthButton")
    local rbReqs = rebirthPanel:FindFirstChild("RequirementsLabel")

    if rbButton then
        rbButton.MouseButton1Click:Connect(function()
            rbButton.Text = "Rebirth..."
            RemoteEvents.Rebirth:FireServer()
            task.wait(0.5)
            rbButton.Text = "🔄 HACER REBIRTH"
        end)
    end

    -- Actualizar requisitos según el rebirth actual
    local function updateRebirthUI()
        local nextRebirth = GameConfig.GetNextRebirth(playerStats.rebirths)
        if rbReqs then
            if nextRebirth then
                rbReqs.Text = "Requisitos para Rebirth " .. tostring(playerStats.rebirths + 1) .. ":\n"
                    .. "⚡ Potencia: " .. tostring(nextRebirth.requiredPower) .. " (tienes " .. tostring(playerStats.power) .. ")\n"
                    .. "🧠 Brainrots: " .. tostring(nextRebirth.requiredBrainrots) .. " (tienes " .. tostring(playerStats.brainrotCount) .. ")\n"
                    .. "🎁 Recompensa: x" .. tostring(nextRebirth.multiplier) .. " permanente"

                local canRebirth = playerStats.power >= nextRebirth.requiredPower
                    and playerStats.brainrotCount >= nextRebirth.requiredBrainrots

                if rbButton then
                    rbButton.BackgroundColor3 = canRebirth
                        and Color3.fromRGB(180, 0, 255)
                        or Color3.fromRGB(80, 80, 80)
                    rbButton.Text = canRebirth and "🔄 HACER REBIRTH!" or "🔒 Requisitos insuficientes"
                end
            else
                rbReqs.Text = "¡Ya tienes el máximo de Rebirths!\nEres un verdadero Sigma. 🏆"
                if rbButton then
                    rbButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                    rbButton.Text = "🏆 MÁXIMO"
                end
            end
        end
    end

    -- Escuchar actualizaciones de stats
    RemoteEvents.UpdateStats.OnClientEvent:Connect(function(stats)
        playerStats.coins = stats.coins
        playerStats.power = stats.power
        playerStats.ballLevel = stats.ballLevel
        playerStats.rebirths = stats.rebirths
        playerStats.brainrotCount = stats.brainrotCount or 0
        updateRebirthUI()
    end)

    updateRebirthUI()
end

print("[ShopClient] Tiendas y Rebirth inicializados")
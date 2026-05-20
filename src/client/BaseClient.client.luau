--[[
    BaseClient - LocalScript para la base y el inventario de brainrots
    Maneja: mostrar slots, colocar brainrots, actualizar income
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
local basePanel = screenGui:FindFirstChild("BasePanel")
local invPanel = screenGui:FindFirstChild("InventoryPanel")

-- ═══════════════════════════════════════════
-- ESTADO
-- ═══════════════════════════════════════════
local playerStats = {
    coins = 0, power = 1, ballLevel = 1, ballMultiplier = 1,
    rebirths = 0, rebirthMultiplier = 1, currentZone = 1,
    baseIncomePerSec = 0, brainrotCount = 0, totalGoals = 0, totalKicks = 0,
}

local brainrotsList = {} -- lista de brainrots capturados (del servidor)
local openPanel = nil

-- ═══════════════════════════════════════════
-- ABRIR/CERRAR PANELES
-- ═══════════════════════════════════════════
local function closeAllPanels()
    if basePanel then basePanel.Visible = false end
    if invPanel then invPanel.Visible = false end
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
-- NAVEGACIÓN
-- ═══════════════════════════════════════════
if nav then
    local baseBtn = nav:FindFirstChild("BaseBtn")
    local invBtn = nav:FindFirstChild("InventoryBtn")

    if baseBtn then
        baseBtn.MouseButton1Click:Connect(function()
            togglePanel(basePanel)
        end)
    end
    if invBtn then
        invBtn.MouseButton1Click:Connect(function()
            togglePanel(invPanel)
            -- Solicitar inventario actualizado
            updateInventoryUI()
        end)
    end
end

-- ═══════════════════════════════════════════
-- BOTONES DE CERRAR
-- ═══════════════════════════════════════════
if basePanel then
    local closeBtn = basePanel:FindFirstChild("CloseBtn")
    if closeBtn then closeBtn.MouseButton1Click:Connect(closeAllPanels) end
end
if invPanel then
    local closeBtn = invPanel:FindFirstChild("CloseBtn")
    if closeBtn then closeBtn.MouseButton1Click:Connect(closeAllPanels) end
end

-- ═══════════════════════════════════════════
-- ACTUALIZAR SLOTS DE LA BASE
-- ═══════════════════════════════════════════
local function updateBaseSlots()
    if not basePanel then return end

    local slotsFrame = basePanel:FindFirstChild("SlotsFrame")
    if not slotsFrame then return end

    local totalIncome = 0

    for i = 1, 20 do
        local slot = slotsFrame:FindFirstChild("Slot_" .. tostring(i))
        if slot then
            local label = slot:FindFirstChild("BrainrotLabel")
            local incomeLabel = slot:FindFirstChild("IncomeLabel")

            -- Buscar si hay un brainrot en este slot
            local foundBrainrot = nil
            for idx, entry in ipairs(brainrotsList) do
                if entry.placedInBase and entry.baseSlot == i then
                    foundBrainrot = entry
                    break
                end
            end

            if foundBrainrot then
                -- Buscar datos del brainrot en GameConfig
                local brainrotData = nil
                for _, b in ipairs(GameConfig.Brainrots) do
                    if b.id == foundBrainrot.id then
                        brainrotData = b
                        break
                    end
                end

                if brainrotData then
                    local rarityColors = {
                        Common = Color3.fromRGB(180, 180, 180),
                        Rare = Color3.fromRGB(85, 170, 255),
                        Epic = Color3.fromRGB(170, 85, 255),
                        Legendary = Color3.fromRGB(255, 170, 0),
                    }

                    if label then
                        label.Text = brainrotData.name
                        label.TextColor3 = rarityColors[brainrotData.rarity] or Color3.new(1,1,1)
                    end
                    if incomeLabel then
                        local income = brainrotData.coinsPerSec * playerStats.rebirthMultiplier
                        incomeLabel.Text = "+" .. tostring(income) .. "/s"
                        totalIncome = totalIncome + income
                    end
                    slot.BackgroundColor3 = Color3.fromRGB(40, 70, 40)
                end
            else
                if label then
                    label.Text = "Vacío"
                    label.TextColor3 = Color3.fromRGB(100, 100, 100)
                end
                if incomeLabel then
                    incomeLabel.Text = ""
                end
                slot.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
            end
        end
    end

    -- Actualizar display de income
    local incomeDisplay = basePanel:FindFirstChild("IncomeDisplay")
    if incomeDisplay then
        incomeDisplay.Text = "Income total: " .. tostring(totalIncome) .. " coins/seg (x" .. tostring(playerStats.rebirthMultiplier) .. " rebirth)"
    end
end

-- ═══════════════════════════════════════════
-- ACTUALIZAR INVENTARIO
-- ═══════════════════════════════════════════
function updateInventoryUI()
    if not invPanel then return end

    local scroll = invPanel:FindFirstChild("ItemsScroll")
    local countLabel = invPanel:FindFirstChild("CountLabel")
    if not scroll then return end

    -- Limpiar items existentes
    for _, child in scroll:GetChildren() do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    if countLabel then
        countLabel.Text = "Brainrots capturados: " .. tostring(#brainrotsList)
    end

    -- Crear items
    for idx, entry in ipairs(brainrotsList) do
        -- Buscar datos en GameConfig
        local brainrotData = nil
        for _, b in ipairs(GameConfig.Brainrots) do
            if b.id == entry.id then
                brainrotData = b
                break
            end
        end

        if brainrotData then
            local item = Instance.new("Frame")
            item.Name = "InvItem_" .. tostring(idx)
            item.Size = UDim2.new(1, 0, 0, 55)
            item.BackgroundColor3 = Color3.fromRGB(40, 25, 25)
            item.BorderSizePixel = 0
            item.LayoutOrder = idx
            item.Parent = scroll

            local itemCorner = Instance.new("UICorner")
            itemCorner.CornerRadius = UDim.new(0, 8)
            itemCorner.Parent = item

            local rarityColors = {
                Common = Color3.fromRGB(180, 180, 180),
                Rare = Color3.fromRGB(85, 170, 255),
                Epic = Color3.fromRGB(170, 85, 255),
                Legendary = Color3.fromRGB(255, 170, 0),
            }

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = brainrotData.name .. "\n[" .. brainrotData.rarity .. "]" .. (brainrotData.isBoss and " BOSS" or "")
            nameLabel.TextColor3 = rarityColors[brainrotData.rarity] or Color3.new(1,1,1)
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextSize = 12
            nameLabel.Parent = item

            local namePad = Instance.new("UIPadding")
            namePad.PaddingLeft = UDim.new(0, 10)
            namePad.Parent = nameLabel

            local incomeLabel = Instance.new("TextLabel")
            incomeLabel.Size = UDim2.new(0.2, 0, 1, 0)
            incomeLabel.Position = UDim2.new(0.55, 0, 0, 0)
            incomeLabel.BackgroundTransparency = 1
            incomeLabel.Text = "+" .. tostring(brainrotData.coinsPerSec) .. "/s"
            incomeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
            incomeLabel.Font = Enum.Font.GothamBold
            incomeLabel.TextSize = 12
            incomeLabel.Parent = item

            -- Botón colocar/quitar de la base
            local placeBtn = Instance.new("TextButton")
            placeBtn.Name = "PlaceBtn"
            placeBtn.Size = UDim2.new(0, 80, 0, 40)
            placeBtn.Position = UDim2.new(1, -90, 0.5, -20)
            placeBtn.BorderSizePixel = 0
            placeBtn.Font = Enum.Font.GothamBold
            placeBtn.TextSize = 11
            placeBtn.Parent = item

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = placeBtn

            if entry.placedInBase then
                placeBtn.Text = "Quitar"
                placeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
                placeBtn.TextColor3 = Color3.new(1, 1, 1)

                -- Quitar de la base
                placeBtn.MouseButton1Click:Connect(function()
                    if entry.baseSlot then
                        RemoteEvents.RemoveBrainrotFromBase:FireServer(idx, entry.baseSlot)
                        entry.placedInBase = false
                        entry.baseSlot = nil
                        placeBtn.Text = "Colocar"
                        placeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
                        updateBaseSlots()
                    end
                end)
            else
                placeBtn.Text = "Colocar"
                placeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
                placeBtn.TextColor3 = Color3.new(1, 1, 1)

                -- Al hacer click, colocar en el primer slot vacío
                placeBtn.MouseButton1Click:Connect(function()
                    -- Buscar primer slot vacío
                    local slotFound = nil
                    for s = 1, 20 do
                        local occupied = false
                        for _, e in ipairs(brainrotsList) do
                            if e.placedInBase and e.baseSlot == s then
                                occupied = true
                                break
                            end
                        end
                        if not occupied then
                            slotFound = s
                            break
                        end
                    end

                    if slotFound then
                        RemoteEvents.PlaceBrainrot:FireServer(idx, slotFound)
                        entry.placedInBase = true
                        entry.baseSlot = slotFound
                        placeBtn.Text = "Quitar"
                        placeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
                        updateBaseSlots()
                    end
                end)
            end
        end
    end
end

-- ═══════════════════════════════════════════
-- ESCUCHAR STATS DEL SERVIDOR
-- ═══════════════════════════════════════════
RemoteEvents.UpdateStats.OnClientEvent:Connect(function(stats)
    playerStats = stats
    updateBaseSlots()
end)

-- ═══════════════════════════════════════════
-- ESCUCHAR LISTA DE BRAINROTS DEL SERVIDOR
-- ═══════════════════════════════════════════
RemoteEvents.UpdateBrainrotList.OnClientEvent:Connect(function(list)
    brainrotsList = list
    updateBaseSlots()
    if openPanel == invPanel then
        updateInventoryUI()
    end
end)

-- ═══════════════════════════════════════════
-- ESCUCHAR CAPTURA DE BRAINROT
-- ═══════════════════════════════════════════
RemoteEvents.GoalResult.OnClientEvent:Connect(function(data)
    if data.result == "goal" and data.capturedBrainrot then
        table.insert(brainrotsList, {
            id = data.capturedBrainrot.id,
            name = data.capturedBrainrot.name,
            rarity = data.capturedBrainrot.rarity,
            coinsPerSec = data.capturedBrainrot.coinsPerSec,
            placedInBase = false,
            baseSlot = nil,
        })
    end
end)

-- ═══════════════════════════════════════════
-- INICIALIZACIÓN
-- ═══════════════════════════════════════════
updateBaseSlots()
print("[BaseClient] Base e Inventario inicializados")
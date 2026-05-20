--[[
    BaseManager - Server script for 3D Base visualization
    Spawns brainrot models in the physical base when placed
    Updates income display board
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)
local PlayerData = require(game.ServerScriptService.PlayerData)
local BrainrotSystem = require(game.ServerScriptService.BrainrotSystem)
local BaseSetup = require(game.ServerScriptService.BaseSetup)
local RemoteEvents = ReplicatedStorage.RemoteEvents

BaseSetup.Init()

local function getPlayerBase(player: Player): Model?
	local hdBase = BaseSetup.GetPlayerBase(player)
	if hdBase then
		return hdBase
	end
	return workspace:FindFirstChild("PlayerBase")
end

local function getSlotsFolder(player: Player): Instance?
	local base = getPlayerBase(player)
	return base and base:FindFirstChild("Slots")
end

-- ═══════════════════════════════════════════
-- SPAWN BRAINROT MODEL IN SLOT
-- ═══════════════════════════════════════════
local function spawnBrainrotInSlot(player, brainrotId, slotIndex)
	local slotsFolder = getSlotsFolder(player)
	if not slotsFolder then return end
	local slot = slotsFolder:FindFirstChild("Slot_" .. tostring(slotIndex))
	if not slot then return end

	local existing = slot:FindFirstChild("BrainrotModel")
	if existing then existing:Destroy() end

	local model = BrainrotSystem.GetBrainrotModel(brainrotId)
	if not model then
		model = Instance.new("Model")
		model.Name = "BrainrotModel"
		local body = Instance.new("Part")
		body.Size = Vector3.new(2, 3, 2)
		body.CFrame = slot.CFrame * CFrame.new(0, 2, 0)
		body.Color = Color3.fromRGB(100, 100, 200)
		body.Material = Enum.Material.SmoothPlastic
		body.Anchored = true
		body.CanCollide = false
		body.Parent = model

		local head = Instance.new("Part")
		head.Size = Vector3.new(1.5, 1.5, 1.5)
		head.Shape = Enum.PartType.Ball
		head.CFrame = slot.CFrame * CFrame.new(0, 4.5, 0)
		head.Color = Color3.fromRGB(150, 150, 220)
		head.Material = Enum.Material.SmoothPlastic
		head.Anchored = true
		head.CanCollide = false
		head.Parent = model

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(0, 100, 0, 30)
		billboard.StudsOffset = Vector3.new(0, 6, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = head

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = brainrotId
		nameLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 10
		nameLabel.Parent = billboard

		model.Parent = slot
		return
	end

	model.Name = "BrainrotModel"
	model:PivotTo(slot.CFrame * CFrame.new(0, 1, 0))

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	local primaryPart = model:FindFirstChildWhichIsA("BasePart") or model:FindFirstChild("HumanoidRootPart")
	if primaryPart then
		local brainrotData = nil
		for _, b in ipairs(GameConfig.Brainrots) do
			if b.id == brainrotId then
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

			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.new(0, 120, 0, 40)
			billboard.StudsOffset = Vector3.new(0, 5, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = primaryPart

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = brainrotData.name
			nameLabel.TextColor3 = rarityColors[brainrotData.rarity] or Color3.new(1, 1, 1)
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 10
			nameLabel.Parent = billboard

			local incomeLabel = Instance.new("TextLabel")
			incomeLabel.Size = UDim2.new(1, 0, 0.4, 0)
			incomeLabel.Position = UDim2.new(0, 0, 0.6, 0)
			incomeLabel.BackgroundTransparency = 1
			incomeLabel.Text = "+" .. tostring(brainrotData.coinsPerSec) .. "/s"
			incomeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			incomeLabel.Font = Enum.Font.GothamBold
			incomeLabel.TextSize = 9
			incomeLabel.Parent = billboard
		end
	end

	model.Parent = slot
	BrainrotSystem.StartIdleAnimation(model)
end

local function removeBrainrotFromSlot(player, slotIndex)
	local slotsFolder = getSlotsFolder(player)
	if not slotsFolder then return end
	local slot = slotsFolder:FindFirstChild("Slot_" .. tostring(slotIndex))
	if slot then
		local existing = slot:FindFirstChild("BrainrotModel")
		if existing then existing:Destroy() end
	end
end

local function updateIncomeBoard(player)
	local base = getPlayerBase(player)
	if not base then return end
	local board = base:FindFirstChild("IncomeBoard")
	if not board then return end

	local gui = board:FindFirstChildWhichIsA("SurfaceGui")
	if not gui then return end

	local label = gui:FindFirstChild("IncomeText")
	if not label then return end

	local income = PlayerData.CalculateBaseIncome(player)
	local data = PlayerData.GetData(player)
	local mult = data and data.rebirthMultiplier or 1

	label.Text = "Income: " .. tostring(income) .. " coins/seg\nx" .. tostring(mult) .. " rebirth"
end

local function refreshBase(player)
	local data = PlayerData.GetData(player)
	if not data then return end

	local slotsFolder = getSlotsFolder(player)
	if slotsFolder then
		for i = 1, 20 do
			removeBrainrotFromSlot(player, i)
		end
	end

	for _, entry in ipairs(data.brainrots) do
		if entry.placedInBase and entry.baseSlot then
			spawnBrainrotInSlot(player, entry.id, entry.baseSlot)
		end
	end

	updateIncomeBoard(player)
end

RemoteEvents.PlaceBrainrot.OnServerEvent:Connect(function(player, brainrotIndex, slotIndex)
	local data = PlayerData.GetData(player)
	if not data then return end

	brainrotIndex = tonumber(brainrotIndex)
	slotIndex = tonumber(slotIndex)
	if not brainrotIndex or not slotIndex then return end
	if brainrotIndex < 1 or brainrotIndex > #data.brainrots then return end

	local entry = data.brainrots[brainrotIndex]
	if entry then
		spawnBrainrotInSlot(player, entry.id, slotIndex)
		updateIncomeBoard(player)
	end
end)

RemoteEvents.RemoveBrainrotFromBase.OnServerEvent:Connect(function(player, brainrotIndex, slotIndex)
	removeBrainrotFromSlot(player, slotIndex)
	updateIncomeBoard(player)
end)

local function onPlayerAdded(player)
	task.delay(2, function()
		if BaseSetup.IsHDMapPresent() then
			BaseSetup.AssignBase(player)
		end
		refreshBase(player)
	end)
end

local function onPlayerRemoving(player)
	BaseSetup.OnPlayerRemoving(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

task.spawn(function()
	while task.wait(5) do
		for _, player in Players:GetPlayers() do
			updateIncomeBoard(player)
		end
	end
end)

print("[BaseManager] 3D Base manager initialized")

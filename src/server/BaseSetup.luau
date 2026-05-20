--[[
    BaseSetup - Coloca 4 bases de jugador en el lobby del HD map
    (donde estaba LobbyCasa) usando PlayerBaseTemplate del asset pack.
]]

local BaseSetup = {}

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local MAX_BASES = 4
local BASE_SPACING_X = 58
local BASE_SPACING_Z = 42

local state = {
	initialized = false,
	hdMapPresent = false,
	basesFolder = nil,
	bases = {} :: { Model },
	baseOwners = {} :: { [number]: number? },
	playerBases = {} :: { [number]: Model },
}

local function findHDMap(): Instance?
	return Workspace:FindFirstChild("HD Simulator Map")
end

local function getLobbyCasa(): Model?
	local hdMap = findHDMap()
	if not hdMap then
		return nil
	end
	local map = hdMap:FindFirstChild("Map")
	if not map then
		return nil
	end
	local areas = map:FindFirstChild("Areas/Zones")
	if not areas then
		return nil
	end
	local spawn = areas:FindFirstChild("Spawn")
	if not spawn then
		return nil
	end
	local lobby = spawn:FindFirstChild("Lobby")
	if not lobby then
		return nil
	end
	return lobby:FindFirstChild("LobbyCasa")
end

local function getGroundY(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	local hdMap = findHDMap()
	if hdMap then
		table.insert(ignore, hdMap)
	end
	params.FilterDescendantsInstances = ignore

	local origin = Vector3.new(position.X, position.Y + 80, position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -300, 0), params)
	if result then
		return result.Position.Y
	end
	return position.Y
end

local function findTemplate(): Model?
	local template = ServerStorage:FindFirstChild("PlayerBaseTemplate")
	if template and template:IsA("Model") then
		return template
	end
	template = Workspace:FindFirstChild("PlayerBaseTemplate")
	if template and template:IsA("Model") then
		template.Parent = ServerStorage
		return template
	end
	return nil
end

local function buildSlots(baseModel: Model)
	local existing = baseModel:FindFirstChild("Slots")
	if existing then
		existing:Destroy()
	end

	local slotsFolder = Instance.new("Folder")
	slotsFolder.Name = "Slots"
	slotsFolder.Parent = baseModel

	local standEntries = {}
	for _, floorName in ipairs({ "SecondFloor", "ThirdFloor", "Base" }) do
		local floor = baseModel:FindFirstChild(floorName)
		local stands = floor and floor:FindFirstChild("Stands")
		if stands then
			for _, stand in ipairs(stands:GetChildren()) do
				if stand:IsA("Model") then
					local num = tonumber(stand.Name)
					table.insert(standEntries, {
						order = num or 999,
						stand = stand,
					})
				end
			end
		end
	end

	table.sort(standEntries, function(a, b)
		return a.order < b.order
	end)

	local slotIndex = 1
	for _, entry in standEntries do
		if slotIndex > 20 then
			break
		end
		local anchor = entry.stand:FindFirstChild("PromptPart")
			or entry.stand:FindFirstChildWhichIsA("BasePart")
		if anchor then
			local slot = Instance.new("Part")
			slot.Name = "Slot_" .. tostring(slotIndex)
			slot.Size = Vector3.new(2, 0.5, 2)
			slot.Anchored = true
			slot.CanCollide = false
			slot.Transparency = 1
			slot.CFrame = anchor.CFrame * CFrame.new(0, 2, 0)
			slot.Parent = slotsFolder
			slotIndex += 1
		end
	end
end

local function ensureIncomeBoard(baseModel: Model)
	if baseModel:FindFirstChild("IncomeBoard") then
		return
	end

	local root = baseModel:FindFirstChild("Root", true)
		or baseModel:FindFirstChildWhichIsA("BasePart", true)
	local boardPart = Instance.new("Part")
	boardPart.Name = "IncomeBoard"
	boardPart.Size = Vector3.new(6, 4, 0.5)
	boardPart.Anchored = true
	boardPart.CanCollide = false
	if root then
		boardPart.CFrame = root.CFrame * CFrame.new(0, 6, -8)
	else
		boardPart.CFrame = baseModel:GetPivot() * CFrame.new(0, 8, -8)
	end
	boardPart.Parent = baseModel

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = boardPart

	local label = Instance.new("TextLabel")
	label.Name = "IncomeText"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "Income: 0 coins/seg"
	label.Parent = gui
end

local function ensureNameTag(baseModel: Model, baseIndex: number)
	local tagPart = baseModel:FindFirstChild("BaseNameTag")
	if not tagPart then
		tagPart = Instance.new("Part")
		tagPart.Name = "BaseNameTag"
		tagPart.Size = Vector3.new(1, 1, 1)
		tagPart.Anchored = true
		tagPart.CanCollide = false
		tagPart.Transparency = 1
		tagPart.CFrame = baseModel:GetPivot() * CFrame.new(0, 12, 0)
		tagPart.Parent = baseModel

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NameBillboard"
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 0, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = tagPart

		local label = Instance.new("TextLabel")
		label.Name = "DisplayName"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextStrokeTransparency = 0.3
		label.Parent = billboard
	end

	local label = tagPart:FindFirstChild("NameBillboard"):FindFirstChild("DisplayName")
	if label then
		label.Text = "Base " .. tostring(baseIndex) .. " (libre)"
	end
end

local function updateBaseNameTag(baseModel: Model, player: Player?)
	local tagPart = baseModel:FindFirstChild("BaseNameTag")
	if not tagPart then
		return
	end
	local billboard = tagPart:FindFirstChild("NameBillboard")
	local label = billboard and billboard:FindFirstChild("DisplayName")
	if label then
		if player then
			label.Text = player.DisplayName
		else
			local idx = baseModel:GetAttribute("BaseIndex") or "?"
			label.Text = "Base " .. tostring(idx) .. " (libre)"
		end
	end
end

local function hideLegacyBase()
	local legacy = Workspace:FindFirstChild("PlayerBase")
	if legacy then
		legacy.Parent = ServerStorage
		legacy.Name = "PlayerBase_Legacy"
	end
end

function BaseSetup.IsHDMapPresent(): boolean
	return state.hdMapPresent
end

function BaseSetup.GetPlayerBase(player: Player): Model?
	return state.playerBases[player.UserId]
end

function BaseSetup.GetBaseTeleportCFrame(player: Player): CFrame?
	local base = state.playerBases[player.UserId]
	if not base then
		return nil
	end
	local root = base:FindFirstChild("Root", true)
	if root and root:IsA("BasePart") then
		return root.CFrame + Vector3.new(0, 4, 0)
	end
	return base:GetPivot() + Vector3.new(0, 5, 0)
end

function BaseSetup.AssignBase(player: Player): Model?
	if state.playerBases[player.UserId] then
		return state.playerBases[player.UserId]
	end

	for i = 1, MAX_BASES do
		if not state.baseOwners[i] then
			local base = state.bases[i]
			if base then
				state.baseOwners[i] = player.UserId
				state.playerBases[player.UserId] = base
				base:SetAttribute("OwnerUserId", player.UserId)
				base:SetAttribute("BaseIndex", i)
				updateBaseNameTag(base, player)
				return base
			end
		end
	end

	warn("[BaseSetup] Servidor lleno: no hay bases libres para " .. player.Name)
	return nil
end

function BaseSetup.ReleaseBase(player: Player)
	local base = state.playerBases[player.UserId]
	if not base then
		return
	end
	local idx = base:GetAttribute("BaseIndex")
	if idx then
		state.baseOwners[idx] = nil
	end
	base:SetAttribute("OwnerUserId", nil)
	updateBaseNameTag(base, nil)
	state.playerBases[player.UserId] = nil
end

function BaseSetup.Init()
	if state.initialized then
		return
	end
	state.initialized = true

	local hdMap = findHDMap()
	if not hdMap then
		warn("[BaseSetup] HD map no encontrado; se usa PlayerBase legacy.")
		return
	end

	local template = findTemplate()
	if not template then
		warn("[BaseSetup] PlayerBaseTemplate no encontrado en ServerStorage/Workspace.")
		return
	end

	hideLegacyBase()

	local lobbyCasa = getLobbyCasa()
	local centerPos = Vector3.new(-0.5, 246.5, 757)
	if lobbyCasa then
		local cf, _ = lobbyCasa:GetBoundingBox()
		centerPos = Vector3.new(cf.Position.X, getGroundY(cf.Position), cf.Position.Z)
		lobbyCasa:Destroy()
	end

	local basesFolder = Workspace:FindFirstChild("BKS_Bases")
	if not basesFolder then
		basesFolder = Instance.new("Folder")
		basesFolder.Name = "BKS_Bases"
		basesFolder.Parent = Workspace
	end
	state.basesFolder = basesFolder

	local offsets = {
		Vector3.new(-BASE_SPACING_X / 2, 0, -BASE_SPACING_Z / 2),
		Vector3.new(BASE_SPACING_X / 2, 0, -BASE_SPACING_Z / 2),
		Vector3.new(-BASE_SPACING_X / 2, 0, BASE_SPACING_Z / 2),
		Vector3.new(BASE_SPACING_X / 2, 0, BASE_SPACING_Z / 2),
	}

	local templatePivot = template:GetPivot()
	for i, offset in ipairs(offsets) do
		local base = template:Clone()
		base.Name = "PlayerBase_" .. tostring(i)
		base:SetAttribute("BaseIndex", i)

		local targetPos = centerPos + offset
		local rotation = templatePivot - templatePivot.Position
		base:PivotTo(CFrame.new(targetPos) * rotation)

		buildSlots(base)
		ensureIncomeBoard(base)
		ensureNameTag(base, i)
		base.Parent = basesFolder

		state.bases[i] = base
	end

	template.Parent = ServerStorage

	state.hdMapPresent = true
	print(string.format("[BaseSetup] %d bases colocadas en el lobby (LobbyCasa reemplazado).", MAX_BASES))
end

function BaseSetup.OnPlayerAdded(player: Player)
	if not state.hdMapPresent then
		return
	end
	BaseSetup.AssignBase(player)
end

function BaseSetup.OnPlayerRemoving(player: Player)
	BaseSetup.ReleaseBase(player)
end

return BaseSetup

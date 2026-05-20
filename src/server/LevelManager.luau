--[[
    LevelManager - Mapa de 18 zonas (HD Simulator Map).

    Responsable de:
      - Localizar los "Gate" del mapa (muros entre zonas).
      - Crear una portería procedural delante de cada Gate, en el suelo y
        mirando hacia la zona origen (de donde viene el jugador a disparar).
      - Bloquear el paso por gates cerrados (CanCollide = true).
      - Ocultar gate + portería cuando el jugador desbloquea la zona destino.
]]

local LevelManager = {}

local Workspace = game:GetService("Workspace")

local GATE_ORDER = {
	{ themeFolder = "Desert",   wallPartName = "Desert",   zoneName = "Desert"   },
	{ themeFolder = "Lake",     wallPartName = "Lake",     zoneName = "Lake"     },
	{ themeFolder = "Candy",    wallPartName = "Candy",    zoneName = "Candy"    },
	{ themeFolder = "Glacier",  wallPartName = "Glacier",  zoneName = "Glacier"  },
	{ themeFolder = "Volcano",  wallPartName = "Volcano",  zoneName = "Volcano"  },
	{ themeFolder = "Atlantic", wallPartName = "Atlantic", zoneName = "Atlantic" },
	{ themeFolder = "Cemetery", wallPartName = "Cemetery", zoneName = "Cemetery" },
	{ themeFolder = "Ninja",    wallPartName = "Ninja",    zoneName = "Ninja"    },
	{ themeFolder = "Toy",      wallPartName = "Toy",      zoneName = "Toy"      },
	{ themeFolder = "School",   wallPartName = "School",   zoneName = "School"   },
	{ themeFolder = "Mage",     wallPartName = "Mage",     zoneName = "Mage"     },
	{ themeFolder = "Medieval", wallPartName = "Castle",   zoneName = "Castle"   },
	{ themeFolder = "City",     wallPartName = "City",     zoneName = "City"     },
	{ themeFolder = "Forest",   wallPartName = "Forest",   zoneName = "Forest"   },
	{ themeFolder = "Autumn",   wallPartName = "Autumn",   zoneName = "Autumn"   },
	{ themeFolder = "Farm",     wallPartName = "Farm",     zoneName = "Farm"     },
	{ themeFolder = "??",       wallPartName = "a",        zoneName = "VIP"      },
}

local GOAL_FRONT_OFFSET = 6 -- studs delante del muro, lado del jugador (+Z mundo)

local state = {
	initialized = false,
	hdMapPresent = false,
	gates = {},
	gatesByDestination = {},
	goalsFolder = nil,
	goalkeepersFolder = nil,
	brainrotSystem = nil,
}

local function findHDMap(): Instance?
	local map = Workspace:FindFirstChild("HD Simulator Map")
	if map then
		return map
	end
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Model") and string.find(string.lower(child.Name), "simulator map", 1, true) then
			return child
		end
	end
	return nil
end

local function findDoorsFolder(hdMap: Instance): Instance?
	local mapChild = hdMap:FindFirstChild("Map")
	if not mapChild then
		return nil
	end
	local other = mapChild:FindFirstChild("Other")
	if not other then
		return nil
	end
	return other:FindFirstChild("Doors")
end

local function getGroundY(wallPart: BasePart): number
	local bottomY = wallPart.Position.Y - (wallPart.Size.Y * 0.5)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { wallPart.Parent, wallPart }

	local origin = Vector3.new(wallPart.Position.X, wallPart.Position.Y + 10, wallPart.Position.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -200, 0), params)
	if result then
		return result.Position.Y
	end
	return bottomY
end

-- Portería en el suelo, delante del Gate (lado +Z, de donde viene el jugador).
local function gateCFrameToGoalCFrame(wallPart: BasePart): CFrame
	local wallPos = wallPart.Position
	local groundY = getGroundY(wallPart)
	local goalPos = Vector3.new(
		wallPos.X,
		groundY,
		wallPos.Z + GOAL_FRONT_OFFSET
	)
	-- -Z local mira hacia +Z mundo (jugador). +Z local entra hacia el muro/red.
	return CFrame.lookAt(goalPos, goalPos + Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
end

local function setGateLocked(record, locked: boolean)
	if not record or not record.wallPart then
		return
	end

	record.wallPart.CanCollide = locked
	record.wallPart.CanQuery = locked
	if locked then
		record.wallPart.Transparency = 0.5
	else
		record.wallPart.Transparency = 1
	end

	local cadeado = record.gateModel:FindFirstChild("Cadeado")
	if cadeado then
		for _, inst in ipairs(cadeado:GetDescendants()) do
			if inst:IsA("BasePart") then
				inst.CanCollide = locked
				inst.Transparency = locked and 0 or 1
			end
		end
	end

	if record.goalModel then
		for _, inst in ipairs(record.goalModel:GetDescendants()) do
			if inst:IsA("BasePart") then
				if inst.Name == "GoalZone" then
					inst.CanCollide = false
				else
					inst.Transparency = locked and 0 or 1
					inst.CanCollide = locked
				end
			end
		end
		record.goalModel:SetAttribute("GateLocked", locked)
	end
end

local function scanGates(doorsFolder: Instance): { table }
	local found = {}
	for index, spec in ipairs(GATE_ORDER) do
		local folder = doorsFolder:FindFirstChild(spec.themeFolder)
		if folder then
			local gateModel = folder:FindFirstChild("Gate")
			if gateModel then
				local wallPart = gateModel:FindFirstChild(spec.wallPartName)
				if not (wallPart and wallPart:IsA("BasePart")) then
					for _, child in ipairs(gateModel:GetChildren()) do
						if child:IsA("BasePart") then
							wallPart = child
							break
						end
					end
				end
				if wallPart and wallPart:IsA("BasePart") then
					table.insert(found, {
						order = index,
						spec = spec,
						gateModel = gateModel,
						wallPart = wallPart,
					})
				end
			end
		end
	end
	return found
end

local function setupLobbySpawn(hdMap: Instance)
	local areasZones = hdMap.Map:FindFirstChild("Areas/Zones")
	local lobby = areasZones and areasZones:FindFirstChild("Spawn")
	local lobbySpawnPart = lobby and lobby:FindFirstChild("Spawn")
	if not (lobbySpawnPart and lobbySpawnPart:IsA("BasePart")) then
		warn("[LevelManager] No se encontro el Spawn del lobby (Areas/Zones.Spawn.Spawn)")
		return
	end

	local desiredPos = lobbySpawnPart.Position + Vector3.new(0, 3, 0)
	local kept: SpawnLocation? = nil
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("SpawnLocation") then
			if not kept then
				kept = inst
			else
				inst:Destroy()
			end
		end
	end

	if not kept then
		kept = Instance.new("SpawnLocation")
		kept.Name = "LobbySpawn"
		kept.Size = Vector3.new(6, 1, 6)
		kept.Transparency = 1
		kept.Parent = Workspace
	end

	kept.Position = desiredPos
	kept.Anchored = true
	kept.CanCollide = true
	kept.Neutral = true
	kept.AllowTeamChangeOnTouch = false
	kept.Enabled = true
end

function LevelManager.IsHDMapPresent(): boolean
	return state.hdMapPresent
end

function LevelManager.GetGateCount(): number
	local n = 0
	for _ in pairs(state.gates) do
		n += 1
	end
	return n
end

function LevelManager.GetGoalkeepersFolder(): Instance?
	return state.goalkeepersFolder
end

function LevelManager.GetGoalForZone(zoneId: number)
	local g = state.gates[zoneId]
	if not g then
		return nil, nil, nil
	end
	local cf = g.goalCFrame
	if g.goalModel then
		cf = g.goalModel:GetPivot()
	end
	return g.goalModel, cf, g.spec.zoneName
end

function LevelManager.UnlockZone(zoneId: number)
	local g = state.gatesByDestination[zoneId]
	if not g then
		return
	end
	setGateLocked(g, false)
end

function LevelManager.SyncPlayerGates(currentZone: number)
	if not state.hdMapPresent then
		return
	end
	for destZoneId = 2, currentZone do
		LevelManager.UnlockZone(destZoneId)
	end
end

function LevelManager.Init(brainrotSystem)
	if state.initialized then
		return
	end
	state.initialized = true
	state.brainrotSystem = brainrotSystem

	local hdMap = findHDMap()
	if not hdMap then
		warn("[LevelManager] No se encontro 'HD Simulator Map' en Workspace. Se usara el sistema legacy.")
		return
	end

	setupLobbySpawn(hdMap)

	local doors = findDoorsFolder(hdMap)
	if not doors then
		warn("[LevelManager] HD map encontrado pero falta la carpeta Map.Other.Doors")
		return
	end

	local foundGates = scanGates(doors)
	if #foundGates == 0 then
		warn("[LevelManager] No se encontro ningun Gate dentro de Map.Other.Doors")
		return
	end

	local goalsFolder = Workspace:FindFirstChild("BKS_Goals")
	if not goalsFolder then
		goalsFolder = Instance.new("Folder")
		goalsFolder.Name = "BKS_Goals"
		goalsFolder.Parent = Workspace
	end
	state.goalsFolder = goalsFolder

	local gkFolder = Workspace:FindFirstChild("BKS_Goalkeepers")
	if not gkFolder then
		gkFolder = Instance.new("Folder")
		gkFolder.Name = "BKS_Goalkeepers"
		gkFolder.Parent = Workspace
	end
	state.goalkeepersFolder = gkFolder

	for _, entry in ipairs(foundGates) do
		local originZoneId = entry.order
		local destZoneId = entry.order + 1
		local goalCFrame = gateCFrameToGoalCFrame(entry.wallPart)

		local goalModel
		if state.brainrotSystem and state.brainrotSystem.CreateGoal then
			goalModel = state.brainrotSystem.CreateGoal(originZoneId, goalCFrame)
			if goalModel then
				goalModel.Name = "Goal_Gate_" .. tostring(originZoneId) .. "_" .. entry.spec.zoneName
				goalModel.Parent = goalsFolder
				goalCFrame = goalModel:GetPivot()
			end
		end

		local record = {
			order = entry.order,
			spec = entry.spec,
			gateModel = entry.gateModel,
			wallPart = entry.wallPart,
			goalModel = goalModel,
			goalCFrame = goalCFrame,
			originZoneId = originZoneId,
			destinationZoneId = destZoneId,
		}
		state.gates[originZoneId] = record
		state.gatesByDestination[destZoneId] = record

		setGateLocked(record, true)
	end

	state.hdMapPresent = true
	print(string.format("[LevelManager] HD Simulator Map cargado: %d gates con porteria (bloqueados).", LevelManager.GetGateCount()))
end

return LevelManager

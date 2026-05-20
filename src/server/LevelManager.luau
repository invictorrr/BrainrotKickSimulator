--[[
    LevelManager - Mapa de 18 zonas (HD Simulator Map).

    Responsable de:
      • Localizar los "Gate" del mapa (muros entre zonas).
      • Crear una portería procedural delante de cada Gate, mirando hacia
        la zona origen (de dónde viene el jugador a disparar).
      • Exponer el CFrame de la portería para cada zona del jugador.
      • Ocultar el Gate cuando el jugador desbloquea esa zona.

    El mapa esperado en Workspace:
        HD Simulator Map.Map.Other.Doors.<Theme>.Gate.<ThemeWallPart>

    Tablas internas
    ---------------
    Cada entrada `gates[zoneId]` describe el Gate al que apunta el jugador
    cuando está en la zona `zoneId` (su tiro lo desbloquea como currentZone+1).

    Si el mapa nuevo no está presente, todas las consultas devuelven `nil`
    para que el caller use el sistema legacy (workspace.Zones.Zone1/2/3).
]]

local LevelManager = {}

local Workspace = game:GetService("Workspace")

-- Orden canónico de progresión (de spawn lobby hacia el final).
-- Cada entrada tiene:
--   themeFolder   = nombre de la carpeta dentro de Other.Doors
--   wallPartName  = nombre del Part dentro de Gate (suele coincidir con la carpeta)
--   zoneName      = nombre humano de la zona donde llegas al cruzar el Gate
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

-- gates[zoneIdOrigen] = {
--     wallPart, gateModel, goalModel, goalCFrame,
--     destinationZoneId, destinationZoneName,
-- }
local state = {
	initialized = false,
	hdMapPresent = false,
	gates = {},               -- indexado por zoneId origen
	gatesByDestination = {},  -- indexado por zoneId destino
	goalsFolder = nil,
	brainrotSystem = nil,
}

local function findHDMap(): Instance?
	local map = Workspace:FindFirstChild("HD Simulator Map")
	if map then return map end
	-- Algunos imports lo dejan suelto en Workspace con otro nombre
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Model") and string.find(string.lower(child.Name), "simulator map", 1, true) then
			return child
		end
	end
	return nil
end

local function findDoorsFolder(hdMap: Instance): Instance?
	local mapChild = hdMap:FindFirstChild("Map")
	if not mapChild then return nil end
	local other = mapChild:FindFirstChild("Other")
	if not other then return nil end
	return other:FindFirstChild("Doors")
end

-- Devuelve el CFrame de la portería: posición del muro, pero girado para
-- que su +Z apunte "hacia adentro" del arco (hacia la zona DESTINO).
-- El jugador dispara desde la zona ORIGEN (z más alto), así que la red
-- queda detrás del muro (z más bajo).
local function gateCFrameToGoalCFrame(wallPart: BasePart): CFrame
	-- La portería procedural (BrainrotSystem.CreateGoal) construye sus partes
	-- en local +Z (red), -Z (frente). Queremos que esa "frente" mire hacia
	-- el jugador. El jugador está en Z mayor, así que el frente del arco
	-- debe mirar a +Z y la profundidad extenderse hacia -Z.
	--
	-- CFrame.lookAt(pos, pos + LookVector) construye un CFrame cuyo -Z mira
	-- al target. Si pasamos target = pos + (0, 0, +1), el -Z local apunta a
	-- +Z mundo y +Z local apunta a -Z mundo. Eso es justo lo que queremos:
	-- la red (profundidad +Z local) se extiende hacia z mundo decreciente.
	local pos = wallPart.Position
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))
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
					-- fallback: primera BasePart hija
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

-- ── API pública ──────────────────────────────────────────────────────────────

function LevelManager.IsHDMapPresent(): boolean
	return state.hdMapPresent
end

function LevelManager.GetGateCount(): number
	local n = 0
	for _ in pairs(state.gates) do n += 1 end
	return n
end

-- (zoneIdOrigen) -> (goalModel?, goalCFrame?, destinationZoneName?)
function LevelManager.GetGoalForZone(zoneId: number)
	local g = state.gates[zoneId]
	if not g then return nil, nil, nil end
	return g.goalModel, g.goalCFrame, g.spec.zoneName
end

-- Cuando un jugador llega a la zona `zoneId`, hace desaparecer el muro
-- correspondiente (el que estaba entre la zona origen y `zoneId`).
function LevelManager.UnlockZone(zoneId: number)
	local g = state.gatesByDestination[zoneId]
	if not g then return end
	-- Ocultar el muro y el candado
	if g.wallPart then
		g.wallPart.Transparency = 1
		g.wallPart.CanCollide = false
		g.wallPart.CanQuery = false
	end
	local cadeado = g.gateModel:FindFirstChild("Cadeado")
	if cadeado then
		for _, inst in ipairs(cadeado:GetDescendants()) do
			if inst:IsA("BasePart") then
				inst.Transparency = 1
				inst.CanCollide = false
			end
		end
	end
	-- Ocultar también la portería procedural (ya no se dispara aquí)
	if g.goalModel then
		for _, inst in ipairs(g.goalModel:GetDescendants()) do
			if inst:IsA("BasePart") then
				if inst.Name ~= "GoalZone" then
					inst.Transparency = 1
					inst.CanCollide = false
				end
			end
		end
	end
end

function LevelManager.Init(brainrotSystem)
	if state.initialized then return end
	state.initialized = true
	state.brainrotSystem = brainrotSystem

	local hdMap = findHDMap()
	if not hdMap then
		warn("[LevelManager] No se encontró 'HD Simulator Map' en Workspace. Se usará el sistema legacy.")
		return
	end

	local doors = findDoorsFolder(hdMap)
	if not doors then
		warn("[LevelManager] HD map encontrado pero falta la carpeta Map.Other.Doors")
		return
	end

	local foundGates = scanGates(doors)
	if #foundGates == 0 then
		warn("[LevelManager] No se encontró ningún Gate dentro de Map.Other.Doors")
		return
	end

	-- Carpeta donde depositar las porterías procedurales
	local goalsFolder = Workspace:FindFirstChild("BKS_Goals")
	if not goalsFolder then
		goalsFolder = Instance.new("Folder")
		goalsFolder.Name = "BKS_Goals"
		goalsFolder.Parent = Workspace
	end
	state.goalsFolder = goalsFolder

	for _, entry in ipairs(foundGates) do
		local originZoneId = entry.order              -- estás en zona N → disparas a Gate N
		local destZoneId   = entry.order + 1          -- gol → desbloqueas zona N+1
		local goalCFrame   = gateCFrameToGoalCFrame(entry.wallPart)

		local goalModel
		if state.brainrotSystem and state.brainrotSystem.CreateGoal then
			goalModel = state.brainrotSystem.CreateGoal(originZoneId, goalCFrame)
			if goalModel then
				goalModel.Name = "Goal_Gate_" .. tostring(originZoneId) .. "_" .. entry.spec.zoneName
				goalModel.Parent = goalsFolder
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
	end

	state.hdMapPresent = true
	print(string.format("[LevelManager] HD Simulator Map cargado: %d gates con portería.", LevelManager.GetGateCount()))
end

return LevelManager

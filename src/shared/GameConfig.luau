--[[
    GameConfig - Configuración central del Brainrot Goal Kick Simulator
    Todos los datos de balance, zonas, brainrots, tiendas y rebirths
]]
local GameConfig = {}

-- ═══════════════════════════════════════════
-- RAREZAS
-- ═══════════════════════════════════════════
GameConfig.Rarities = {
    Common    = {weight = 70, color = Color3.fromRGB(180, 180, 180), coinsPerSecBase = 1},
    Rare      = {weight = 20, color = Color3.fromRGB(85, 170, 255), coinsPerSecBase = 3},
    Epic      = {weight = 8,  color = Color3.fromRGB(170, 85, 255), coinsPerSecBase = 8},
    Legendary = {weight = 2,  color = Color3.fromRGB(255, 170, 0),  coinsPerSecBase = 20},
}

-- ═══════════════════════════════════════════
-- BRAINROTS (Ultimate Brainrot Pack v1.1 → ServerStorage.BrainrotModels)
-- ═══════════════════════════════════════════
local DEFAULT_BRAINROT_PACK = {
	"67",
	"69",
	"Agarrini La Palini",
	"Alessio",
	"Avocadini Antilopini",
	"AvocadiniGuffo",
	"BalerinaCapucina",
	"Ballerino lololo",
	"Bambini Crostini",
	"Banana Dancana",
	"Bananita Dolphinita",
	"Ben",
	"BlueberrinniOctopusini",
	"Bobrito Bandito",
	"BombardinoCrocodilo",
	"BombombiniGusini",
	"Boneca Ambalabu",
	"Brr Brr Patapim",
	"BrrBicusDicus",
	"BurbalolliLulilolli",
	"Cachorrito Melonito",
	"Cacto Hipopotamo",
	"Cappuccino Assassino",
	"CavalloVirtuoso",
	"ChefCrabracadabra",
	"Chicleteira Bicicleteira",
	"Chicleteirina Bicicleteirina",
	"ChillinChili",
	"ChimpanziniBananini",
	"Cocofanto Elefanto",
	"Dragon Cannelloni",
	"Esok Sekolah",
	"Espresso Signora",
	"Fluri Flura",
	"FrigoCamelo",
	"GanganzelliTrulala",
	"Gangster Footera",
	"Garama",
	"Gattatino Nyanino",
	"GiraffaCelestre",
	"GlorboFruttodrillo",
	"GorilloWatermelondrillo",
	"Graipuss Medussi",
	"Happy Banana Cat",
	"Illuminati",
	"Job Job Job Sahur",
	"Karkerkar Kurkur",
	"Ketchuru and Musturu",
	"Ketupat Kepat",
	"La Grande Combinasion",
	"La Vaca Saturno Saturnita",
	"Lerulerulerule",
	"LioneloCactuseli",
	"Lirili Larila",
	"Los Tralalelitos",
	"Madungdung",
	"Mateo",
	"Meowl",
	"Noo my examine",
	"Noobini Pizzanini",
	"Nuclearo Dinossauro",
	"Odin Din Din Dun",
	"OrangutiniAnanassini",
	"Orcalero Orcala",
	"Orcalita Orcala",
	"Pakrahmatmamat",
	"Pakrahmatmatina",
	"PandacciniBananini",
	"Pepe Frogy",
	"Pipi Kiwi",
	"PipiPotato",
	"Pot Hotspot",
	"Quesadilla Crocodila",
	"RhinoToasterino",
	"Salamino Penguino",
	"Sigma Boy",
	"Skibidi Toilet",
	"Smurf Cat",
	"StrawberrelliFlamingelli",
	"Strawberry Elephant",
	"Svinina Bombardino",
	"Swag Soda",
	"Ta Ta Ta Ta Sahur",
	"Talpa Di Fero",
	"TicTac Sahur",
	"Tigroligre Frutonni",
	"Tim Cheese",
	"TirilikalikaTirilikalako",
	"Torrtuginni Dragonfrutini",
	"Tralaledon",
	"TralaleroTralala",
	"Tric Trac Barabum",
	"Triplito Tralalelitos",
	"Trippi Troppi",
	"Trippi Troppi Troppa Trippa",
	"Trollface",
	"Trulimero Trulicina",
	"Tung Tung Tung Sahur",
	"Yess My Examine",
	"ZibraZubraZibralini",
}

local BrainrotPackManifest = DEFAULT_BRAINROT_PACK
do
	local ok, loaded = pcall(function()
		return require(script.Parent.BrainrotPackManifest)
	end)
	if ok and type(loaded) == "table" and #loaded > 0 then
		BrainrotPackManifest = loaded
	else
		warn("[GameConfig] BrainrotPackManifest inválido; usando fallback embebido.")
	end
end

local BOSS_BY_ZONE = {
	[1]  = "Cappuccino Assassino",
	[2]  = "BombombiniGusini",
	[3]  = "Strawberry Elephant",
	[4]  = "Nuclearo Dinossauro",
	[5]  = "BombardinoCrocodilo",
	[6]  = "Graipuss Medussi",
	[7]  = "Tralaledon",
	[8]  = "Sigma Boy",
	[9]  = "Trippi Troppi Troppa Trippa",
	[10] = "Skibidi Toilet",
	[11] = "Illuminati",
	[12] = "Odin Din Din Dun",
	[13] = "Karkerkar Kurkur",
	[14] = "Espresso Signora",
	[15] = "La Grande Combinasion",
	[16] = "La Vaca Saturno Saturnita",
	[17] = "Lirili Larila",
	[18] = "Smurf Cat",
}

local RARITY_CYCLE = { "Common", "Common", "Rare", "Epic", "Legendary" }

local function normalizeId(name: string): string
	return string.lower(name:gsub("%s+", ""):gsub("[^%w]", ""))
end

local function buildBrainrotsFromPack(packNames: { string })
	local total = #packNames
	local zoneCount = 0
	for _ in pairs(GameConfig.Zones) do zoneCount += 1 end
	zoneCount = math.max(1, zoneCount)
	local perZone = math.max(1, math.ceil(total / zoneCount))
	local brainrots = {}

	for index, displayName in ipairs(packNames) do
		local zone = math.min(zoneCount, math.ceil(index / perZone))
		local zoneData = GameConfig.Zones[zone]
		local requiredPower = zoneData and zoneData.requiredPower or 1
		local bossName = BOSS_BY_ZONE[zone]
		local isBoss = bossName
			and (
				normalizeId(displayName) == normalizeId(bossName)
				or index == zone * perZone
			)

		local rarity = RARITY_CYCLE[((index - 1) % #RARITY_CYCLE) + 1]
		if isBoss then
			rarity = "Legendary"
		end

		local rarityData = GameConfig.Rarities[rarity]
		local coinsBase = rarityData and rarityData.coinsPerSecBase or 1
		local zoneScale = 1 + (zone - 1) * 0.85

		table.insert(brainrots, {
			id = normalizeId(displayName),
			name = displayName,
			modelName = displayName,
			rarity = rarity,
			zone = zone,
			coinsPerSec = math.floor(coinsBase * zoneScale * ((isBoss and 3) or 1)),
			minPower = requiredPower + math.floor((index % 8) * 2),
			isBoss = isBoss or nil,
		})
	end

	return brainrots
end

-- ═══════════════════════════════════════════
-- ZONAS (18 zonas progresivas alineadas con el HD Simulator Map)
-- ═══════════════════════════════════════════
-- Cada zona representa una "porción del mapa" desde la que el jugador dispara
-- a la siguiente puerta. Cuando hace gol, desbloquea la zona N+1.
-- Los nombres se mantienen alineados con las carpetas del mapa (LevelManager).
local ZONE_THEMES = {
    "Campo Tralalero",  -- 1  (lobby / spawn → Gate.Desert)
    "Oasis Desierto",   -- 2  (Desert)
    "Lago Brumoso",     -- 3  (Lake)
    "Bosque Caramelo",  -- 4  (Candy)
    "Glaciar Bombardo", -- 5  (Glacier)
    "Crater Volcánico", -- 6  (Volcano)
    "Profundo Atlántico", -- 7 (Atlantic)
    "Cementerio Sahur", -- 8  (Cemetery)
    "Dojo Ninja",       -- 9  (Ninja)
    "Fábrica de Juguetes", -- 10 (Toy)
    "Escuela Brainrot", -- 11 (School)
    "Torre del Mago",   -- 12 (Mage)
    "Castillo Medieval",-- 13 (Castle / Medieval)
    "Ciudad Sigma",     -- 14 (City)
    "Bosque Encantado", -- 15 (Forest)
    "Pradera Otoñal",   -- 16 (Autumn)
    "Granja Saturno",   -- 17 (Farm)
    "Salón VIP Cocofanto", -- 18 (VIP)
}

local function buildZones()
    local zones = {}
    for i = 1, #ZONE_THEMES do
        local t = (i - 1) / math.max(1, #ZONE_THEMES - 1) -- 0 .. 1
        local requiredPower = math.floor(1 + (i - 1) * 8)            -- 1, 9, 17, ... 137
        local minDistance   = math.floor(15 + t * 65)                 -- 15 → 80
        local maxDistance   = math.floor(80 + t * 220)                -- 80 → 300
        local penaltyDist   = minDistance
        local goalWidth     = math.max(14, math.floor(24 - t * 10))   -- 24 → 14
        local goalHeight    = math.max(10, math.floor(14 - t * 4))    -- 14 → 10
        local baseCoins     = math.floor(5 * (1.30 ^ (i - 1)))         -- 5 → ~430
        local distMult      = 0.5 + t * 1.5                            -- 0.5 → 2.0

        zones[i] = {
            name = ZONE_THEMES[i],
            requiredPower = requiredPower,
            maxDistance = maxDistance,
            minDistance = minDistance,
            penaltyDistance = penaltyDist,
            goalWidth = goalWidth,
            goalHeight = goalHeight,
            baseCoinsPerGoal = baseCoins,
            distanceCoinMultiplier = distMult,
        }
    end
    return zones
end

GameConfig.Zones = buildZones()

-- Porterías por defecto (fallback cuando NO hay HD Simulator Map cargado).
-- Cada zona separada 200 studs en X.
GameConfig.ZoneGoalCFrames = {}
for i = 1, #ZONE_THEMES do
    GameConfig.ZoneGoalCFrames[i] = CFrame.new((i - 1) * 200, 0, 0)
end

-- ═══════════════════════════════════════════
-- TIENDA DE POTENCIA
-- ═══════════════════════════════════════════
local powerLevels = {}
for i = 1, 50 do
    powerLevels[i] = {
        level = i,
        power = i,
        cost = math.floor(10 * (1.5 ^ (i - 1))),
    }
end
GameConfig.PowerShop = powerLevels

-- ═══════════════════════════════════════════
-- TIENDA DE PELOTAS
-- ═══════════════════════════════════════════
GameConfig.BallShop = {
    {level = 1, name = "Balón Básico",       multiplier = 1,   cost = 0,     color = Color3.fromRGB(255, 255, 255)},
    {level = 2, name = "Balón de Fuego",     multiplier = 1.5, cost = 500,   color = Color3.fromRGB(255, 100, 0)},
    {level = 3, name = "Balón Eléctrico",    multiplier = 2,   cost = 2000,  color = Color3.fromRGB(0, 170, 255)},
    {level = 4, name = "Balón Galáctico",     multiplier = 3,   cost = 8000,  color = Color3.fromRGB(170, 0, 255)},
    {level = 5, name = "Balón Brainrot",      multiplier = 5,   cost = 25000, color = Color3.fromRGB(0, 255, 100)},
    {level = 6, name = "Balón Sigma",         multiplier = 8,   cost = 75000, color = Color3.fromRGB(255, 255, 0)},
    {level = 7, name = "Balón Dios Italiano", multiplier = 12,  cost = 200000,color = Color3.fromRGB(255, 0, 0)},
}

-- ═══════════════════════════════════════════
-- REBIRTHS
-- ═══════════════════════════════════════════
GameConfig.Rebirths = {
    {rebirth = 1, requiredPower = 15, requiredBrainrots = 3,  multiplier = 1.5},
    {rebirth = 2, requiredPower = 35, requiredBrainrots = 6,  multiplier = 2},
    {rebirth = 3, requiredPower = 60, requiredBrainrots = 10, multiplier = 3},
    {rebirth = 4, requiredPower = 90, requiredBrainrots = 15, multiplier = 5},
    {rebirth = 5, requiredPower = 130,requiredBrainrots = 20, multiplier = 8},
}

-- ═══════════════════════════════════════════
-- INDICADOR DE FUERZA
-- ═══════════════════════════════════════════
GameConfig.Indicator = {
    oscillationSpeed = 3,      -- velocidad de oscilación del indicador
    baseGreenSize = 0.25,      -- 25% de la barra
    baseYellowSize = 0.30,     -- 30% de la barra
    baseRedSize = 0.45,        -- 45% de la barra
    -- La zona verde crece cuanto más potencia tengas vs la requerida
    -- La zona verde decrece cuanto más lejos estés
    powerFactor = 0.03,        -- cuánto crece la verde por punto de potencia extra
    distanceFactor = 0.005,    -- cuánto decrece la verde por stud de distancia extra
    minGreenSize = 0.05,       -- mínimo 5% de verde
    maxGreenSize = 0.60,       -- máximo 60% de verde
}

-- Alcance de disparo en "metros/studs" según potencia.
-- Potencia 1 => solo llega al área blanca (penaltyDistance).
GameConfig.KickPower = {
    studsPerPower = 5, -- +5 studs de alcance por nivel de potencia extra
}

-- ═══════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════

local function findZoneGoalModel(zoneModel: Instance, zoneId: number): Instance?
	local goal = zoneModel:FindFirstChild("Goal_Zone" .. tostring(zoneId))
	if goal then
		return goal
	end
	for _, child in zoneModel:GetChildren() do
		if child:IsA("Model") and string.find(child.Name, "Goal", 1, true) then
			return child
		end
	end
	return nil
end

local function findHDGoalModel(zoneId: number): Instance?
	local goalsFolder = workspace:FindFirstChild("BKS_Goals")
	if not goalsFolder then return nil end
	local prefix = "Goal_Gate_" .. tostring(zoneId) .. "_"
	for _, child in goalsFolder:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, #prefix) == prefix then
			return child
		end
	end
	return nil
end

function GameConfig.GetGoalCFrame(zoneId: number): CFrame
	local fallback = GameConfig.ZoneGoalCFrames[zoneId] or CFrame.new(0, 0, 0)

	-- 1) HD Simulator Map (gates en BKS_Goals)
	local hdGoal = findHDGoalModel(zoneId)
	if hdGoal then
		return hdGoal:GetPivot()
	end

	-- 2) Sistema legacy (workspace.Zones.Zone<n>)
	local zonesFolder = workspace:FindFirstChild("Zones")
	if not zonesFolder then
		zonesFolder = workspace:WaitForChild("Zones", 4)
	end

	if zonesFolder then
		local zoneModel = zonesFolder:FindFirstChild("Zone" .. tostring(zoneId))
		if zoneModel then
			local goal = findZoneGoalModel(zoneModel, zoneId)
			if goal then
				return goal:GetPivot()
			end
			return zoneModel:GetPivot()
		end
	end

	return fallback
end

function GameConfig.GetGoalPosition(zoneId: number): Vector3
	return GameConfig.GetGoalCFrame(zoneId).Position
end

-- Distancia = profundidad hacia la portería (eje -Z local del arco).
-- Esto evita penalizar al jugador por abrirse a los lados.
function GameConfig.ComputeKickDistance(playerPosition: Vector3, goalCFrame: CFrame, zoneId: number): number
	local zone = GameConfig.Zones[zoneId]
	if not zone then
		return 15
	end

	local localPos = goalCFrame:PointToObjectSpace(playerPosition)
	local depth = -localPos.Z
	if depth < 0 then
		depth = 0
	end
	local distance = math.floor(depth + 0.5)
	return math.clamp(distance, zone.minDistance, zone.maxDistance)
end

function GameConfig.CalculateMaxKickDistance(playerPower: number, zoneId: number): number
    local zone = GameConfig.Zones[zoneId]
    if not zone then
        return 15
    end
    local baseReach = zone.penaltyDistance or zone.minDistance
    local extraReach = math.max(0, (playerPower or 1) - 1) * GameConfig.KickPower.studsPerPower
    local reach = baseReach + extraReach
    return math.clamp(reach, zone.minDistance, zone.maxDistance)
end

-- Calcula el tamaño de las zonas del indicador según potencia y distancia
function GameConfig.CalculateIndicatorZones(playerPower, distance, zoneId)
    local zone = GameConfig.Zones[zoneId]
    if not zone then return 0.25, 0.30, 0.45 end

    local requiredPower = (distance / zone.maxDistance) * zone.requiredPower * 3
    local powerAdvantage = (playerPower - requiredPower) / math.max(requiredPower, 1)

    local greenSize = GameConfig.Indicator.baseGreenSize
        + powerAdvantage * GameConfig.Indicator.powerFactor
        - (distance - zone.minDistance) * GameConfig.Indicator.distanceFactor

    greenSize = math.clamp(greenSize, GameConfig.Indicator.minGreenSize, GameConfig.Indicator.maxGreenSize)

    local yellowSize = math.clamp(0.35 - greenSize * 0.3, 0.10, 0.40)
    local redSize = 1 - greenSize - yellowSize

    -- Asegurar que rojo sea al menos 15%
    if redSize < 0.15 then
        redSize = 0.15
        yellowSize = 1 - greenSize - redSize
    end

    return greenSize, yellowSize, redSize
end

-- Calcula la probabilidad de gol en zona amarilla según distancia
function GameConfig.CalculateYellowGoalProbability(distance, zoneId)
    local zone = GameConfig.Zones[zoneId]
    if not zone then return 0.3 end
    -- Más distancia = más suerte = más probabilidad
    local normalizedDist = (distance - zone.minDistance) / (zone.maxDistance - zone.minDistance)
    return math.clamp(0.2 + normalizedDist * 0.6, 0.2, 0.8)
end

-- Calcula coins ganados por un gol
function GameConfig.CalculateGoalCoins(distance, zoneId, ballMultiplier, rebirthMultiplier)
    local zone = GameConfig.Zones[zoneId]
    if not zone then return 0 end
    local coins = zone.baseCoinsPerGoal + distance * zone.distanceCoinMultiplier
    return math.floor(coins * ballMultiplier * rebirthMultiplier)
end

-- Obtiene los brainrots disponibles para una zona
function GameConfig.GetBrainrotsForZone(zoneId)
    local result = {}
    for _, brainrot in ipairs(GameConfig.Brainrots) do
        if brainrot.zone == zoneId then
            table.insert(result, brainrot)
        end
    end
    return result
end

-- Selecciona un brainrot aleatorio basado en rareza y distancia
function GameConfig.SelectRandomBrainrot(zoneId, distance)
    local zone = GameConfig.Zones[zoneId]
    if not zone then return nil end

    local available = GameConfig.GetBrainrotsForZone(zoneId)
    if #available == 0 then return nil end

    -- Ajustar pesos según distancia (más lejos = más probabilidad de raros)
    local normalizedDist = (distance - zone.minDistance) / (zone.maxDistance - zone.minDistance)
    local rareBonus = normalizedDist * 30 -- hasta +30 de peso extra para raros

    local totalWeight = 0
    local weights = {}
    for _, brainrot in ipairs(available) do
        local baseWeight = GameConfig.Rarities[brainrot.rarity].weight
        if brainrot.rarity == "Rare" then
            baseWeight = baseWeight + rareBonus * 0.5
        elseif brainrot.rarity == "Epic" then
            baseWeight = baseWeight + rareBonus * 0.3
        elseif brainrot.rarity == "Legendary" then
            baseWeight = baseWeight + rareBonus * 0.2
        end
        -- Boss solo aparece si estás lejos (distancia > 60% del máximo)
        if brainrot.isBoss and normalizedDist < 0.6 then
            baseWeight = 0
        end
        table.insert(weights, {brainrot = brainrot, weight = baseWeight})
        totalWeight = totalWeight + baseWeight
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, entry in ipairs(weights) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.brainrot
        end
    end

    return available[#available] -- fallback
end

-- Obtiene el costo del siguiente nivel de potencia
function GameConfig.GetPowerUpgradeCost(currentLevel)
    local nextLevel = GameConfig.PowerShop[currentLevel + 1]
    if not nextLevel then return nil end
    return nextLevel.cost
end

-- Obtiene datos de la siguiente pelota
function GameConfig.GetNextBallUpgrade(currentBallLevel)
    return GameConfig.BallShop[currentBallLevel + 1]
end

-- Obtiene los datos de rebirth para el siguiente rebirth
function GameConfig.GetNextRebirth(currentRebirth)
    return GameConfig.Rebirths[currentRebirth + 1]
end

GameConfig.Brainrots = buildBrainrotsFromPack(BrainrotPackManifest)

return GameConfig
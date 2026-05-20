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
-- BRAINROTS (referencia a modelos en Workspace.brainrotsmodels)
-- ═══════════════════════════════════════════
GameConfig.Brainrots = {
    -- Zona 1
    {id = "tralalero",     name = "Tralalero Tralala",       rarity = "Common",    zone = 1, coinsPerSec = 1,  minPower = 1},
    {id = "brrbrr",        name = "Brr Brr Patapim",         rarity = "Common",    zone = 1, coinsPerSec = 1.5, minPower = 1},
    {id = "chimpanzini",   name = "Chimpanzini Bananini",    rarity = "Common",    zone = 1, coinsPerSec = 2,  minPower = 1},
    {id = "bombardino",    name = "Bombardino Crocodilo",    rarity = "Rare",      zone = 1, coinsPerSec = 5,  minPower = 3},
    {id = "lirili",        name = "Lirili Larila",           rarity = "Epic",      zone = 1, coinsPerSec = 12, minPower = 5},
    -- Boss Zona 1
    {id = "cappuccino",    name = "Capuccino Assassino",     rarity = "Legendary", zone = 1, coinsPerSec = 30, minPower = 10, isBoss = true},

    -- Zona 2
    {id = "tungtung",      name = "Tung Tung Sahur",         rarity = "Common",    zone = 2, coinsPerSec = 4,  minPower = 15},
    {id = "ballerina",     name = "Ballerina Cappuccina",    rarity = "Common",    zone = 2, coinsPerSec = 5,  minPower = 15},
    {id = "crocodila",     name = "Quesadilla Crocodila",    rarity = "Rare",      zone = 2, coinsPerSec = 12, minPower = 18},
    {id = "trippi",        name = "Trippi Troppi",           rarity = "Epic",      zone = 2, coinsPerSec = 25, minPower = 22},
    {id = "bombombini",    name = "Bombombini Gusini",       rarity = "Legendary", zone = 2, coinsPerSec = 60, minPower = 30, isBoss = true},

    -- Zona 3
    {id = "glorbo",        name = "Glorbo Fruttodrillo",     rarity = "Common",    zone = 3, coinsPerSec = 10, minPower = 40},
    {id = "spaghetti",     name = "Spaghetti Tualetti",      rarity = "Common",    zone = 3, coinsPerSec = 12, minPower = 40},
    {id = "elefanto",      name = "Cocofanto Elefanto",     rarity = "Rare",      zone = 3, coinsPerSec = 28, minPower = 50},
    {id = "nuclearo",     name = "Nuclearo Dinossauro",     rarity = "Epic",      zone = 3, coinsPerSec = 55, minPower = 65},
    {id = "trenostruzzo",  name = "Trenostruzzo Turbo 3000",rarity = "Legendary", zone = 3, coinsPerSec = 120, minPower = 80, isBoss = true},
}

-- ═══════════════════════════════════════════
-- ZONAS
-- ═══════════════════════════════════════════
GameConfig.Zones = {
    [1] = {
        name = "Campo Tralalero",
        requiredPower = 1,
        maxDistance = 80,       -- studs desde la portería
        minDistance = 15,       -- distancia mínima (punto de penalty)
        penaltyDistance = 15,   -- punto de penalty
        goalWidth = 12,
        goalHeight = 8,
        baseCoinsPerGoal = 5,
        distanceCoinMultiplier = 0.5, -- coins extra por stud de distancia
    },
    [2] = {
        name = "Estadio Bombardino",
        requiredPower = 15,
        maxDistance = 100,
        minDistance = 20,
        penaltyDistance = 20,
        goalWidth = 10,
        goalHeight = 7,
        baseCoinsPerGoal = 15,
        distanceCoinMultiplier = 0.8,
    },
    [3] = {
        name = "Arena Nuclearo",
        requiredPower = 40,
        maxDistance = 120,
        minDistance = 25,
        penaltyDistance = 25,
        goalWidth = 8,
        goalHeight = 6,
        baseCoinsPerGoal = 40,
        distanceCoinMultiplier = 1.2,
    },
}

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

-- ═══════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════

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

return GameConfig
--[[
    PlayerData - Gestion de datos del jugador con DataStoreService
]]
local PlayerData = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local isStudio = RunService:IsStudio()
local playerStore = nil
local dataStoreAvailable = false

if not isStudio then
    dataStoreAvailable = pcall(function()
        local DataStoreService = game:GetService("DataStoreService")
        playerStore = DataStoreService:GetDataStore("BrainrotGoalKick_PlayerData_v2")
    end)
    if not dataStoreAvailable then
        warn("[PlayerData] DataStore no disponible, usando datos en memoria")
    end
else
    print("[PlayerData] Modo Studio detectado - datos en memoria (sin persistencia)")
end
local dataCache = {}
local AUTO_SAVE_INTERVAL = 120

local function getDefaultData()
    return {
        coins = 0,
        power = 1,
        ballLevel = 1,
        rebirths = 0,
        rebirthMultiplier = 1,
        currentZone = 1,
        brainrots = {},
        baseSlots = {},
        totalGoals = 0,
        totalKicks = 0,
        lastSave = os.time(),
    }
end

function PlayerData.LoadData(player)
    local key = "Player_" .. player.UserId
    if dataStoreAvailable and playerStore then
        local success, data = pcall(function()
            return playerStore:GetAsync(key)
        end)
        if success and data then
            local default = getDefaultData()
            for k, v in pairs(default) do
                if data[k] == nil then data[k] = v end
            end
            dataCache[player.UserId] = data
        else
            if not success then
                warn("[PlayerData] Error cargando datos de " .. player.Name .. ": " .. tostring(data))
            end
            dataCache[player.UserId] = getDefaultData()
        end
    else
        -- No DataStore available (Studio mode without publish)
        dataCache[player.UserId] = getDefaultData()
    end
    return dataCache[player.UserId]
end

function PlayerData.SaveData(player)
    local userId = player.UserId
    local data = dataCache[userId]
    if not data then return end
    if not dataStoreAvailable or not playerStore then return end
    local key = "Player_" .. userId
    data.lastSave = os.time()
    local success, err = pcall(function()
        playerStore:SetAsync(key, data)
    end)
    if not success then
        warn("[PlayerData] Error guardando datos de " .. player.Name .. ": " .. tostring(err))
    end
end

function PlayerData.GetData(player)
    return dataCache[player.UserId]
end

function PlayerData.AddCoins(player, amount)
    local data = dataCache[player.UserId]
    if data then data.coins = data.coins + amount end
end

function PlayerData.SpendCoins(player, amount)
    local data = dataCache[player.UserId]
    if data and data.coins >= amount then
        data.coins = data.coins - amount
        return true
    end
    return false
end

function PlayerData.SetPower(player, newPower)
    local data = dataCache[player.UserId]
    if data then data.power = newPower end
end

function PlayerData.SetBallLevel(player, newLevel)
    local data = dataCache[player.UserId]
    if data then data.ballLevel = newLevel end
end

function PlayerData.AddBrainrot(player, brainrotId)
    local data = dataCache[player.UserId]
    if data then
        table.insert(data.brainrots, {
            id = brainrotId,
            placedInBase = false,
            baseSlot = nil,
        })
    end
end

function PlayerData.PlaceBrainrotInBase(player, brainrotIndex, slotIndex)
    local data = dataCache[player.UserId]
    if data and data.brainrots[brainrotIndex] then
        data.brainrots[brainrotIndex].placedInBase = true
        data.brainrots[brainrotIndex].baseSlot = slotIndex
        data.baseSlots[slotIndex] = data.brainrots[brainrotIndex].id
    end
end

function PlayerData.RemoveBrainrotFromBase(player, brainrotIndex, slotIndex)
    local data = dataCache[player.UserId]
    if data and data.brainrots[brainrotIndex] then
        data.brainrots[brainrotIndex].placedInBase = false
        data.brainrots[brainrotIndex].baseSlot = nil
        data.baseSlots[slotIndex] = nil
    end
end

function PlayerData.PerformRebirth(player, newMultiplier)
    local data = dataCache[player.UserId]
    if data then
        data.rebirths = data.rebirths + 1
        data.rebirthMultiplier = newMultiplier
        data.coins = 0
        data.power = 1
        data.ballLevel = 1
        data.currentZone = 1
    end
end

function PlayerData.UnlockZone(player, zoneId)
    local data = dataCache[player.UserId]
    if data and zoneId > data.currentZone then
        data.currentZone = zoneId
    end
end

function PlayerData.IncrementGoals(player)
    local data = dataCache[player.UserId]
    if data then data.totalGoals = data.totalGoals + 1 end
end

function PlayerData.IncrementKicks(player)
    local data = dataCache[player.UserId]
    if data then data.totalKicks = data.totalKicks + 1 end
end

function PlayerData.CalculateBaseIncome(player)
    local GameConfig = require(game.ReplicatedStorage.GameConfig)
    local data = dataCache[player.UserId]
    if not data then return 0 end
    local totalIncome = 0
    for _, brainrotEntry in ipairs(data.brainrots) do
        if brainrotEntry.placedInBase then
            for _, brainrotData in ipairs(GameConfig.Brainrots) do
                if brainrotData.id == brainrotEntry.id then
                    totalIncome = totalIncome + brainrotData.coinsPerSec
                    break
                end
            end
        end
    end
    return totalIncome * data.rebirthMultiplier
end

function PlayerData.RemovePlayer(player)
    PlayerData.SaveData(player)
    dataCache[player.UserId] = nil
end

task.spawn(function()
    while task.wait(AUTO_SAVE_INTERVAL) do
        for userId, data in pairs(dataCache) do
            local player = Players:GetPlayerByUserId(userId)
            if player then
                PlayerData.SaveData(player)
            end
        end
    end
end)

return PlayerData
--[[
    BrainrotPackSetup - Carga Ultimate Brainrot Pack v1.1 en ServerStorage.BrainrotModels
    Debe ejecutarse antes que el resto del juego use porteros.
]]
local ServerStorage = game:GetService("ServerStorage")

local PACK_NAME = "UltimateBrainrotPack"
local MODELS_FOLDER_NAME = "BrainrotModels"

local function normalizeName(name: string): string
	return string.lower(name:gsub("%s+", ""):gsub("[^%w]", ""))
end

local function hasModelNamed(folder: Folder, modelName: string): boolean
	local norm = normalizeName(modelName)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and normalizeName(child.Name) == norm then
			return true
		end
	end
	return false
end

local function moveModelsIntoFolder(source: Instance, modelsFolder: Folder)
	for _, child in ipairs(source:GetChildren()) do
		if child:IsA("Model") then
			if not hasModelNamed(modelsFolder, child.Name) then
				child.Parent = modelsFolder
			end
		elseif child:IsA("Folder") then
			moveModelsIntoFolder(child, modelsFolder)
		end
	end
end

local pack = ServerStorage:WaitForChild(PACK_NAME, 120)
if not pack then
	warn("[BrainrotPackSetup] No se encontró " .. PACK_NAME .. " en ServerStorage (¿Rojo serve activo?)")
	return
end

local modelsFolder = ServerStorage:FindFirstChild(MODELS_FOLDER_NAME)
if not modelsFolder then
	modelsFolder = Instance.new("Folder")
	modelsFolder.Name = MODELS_FOLDER_NAME
	modelsFolder.Parent = ServerStorage
end

moveModelsIntoFolder(pack, modelsFolder)

print(string.format(
	"[BrainrotPackSetup] %d modelos del Ultimate Brainrot Pack en ServerStorage.%s",
	#modelsFolder:GetChildren(),
	MODELS_FOLDER_NAME
))

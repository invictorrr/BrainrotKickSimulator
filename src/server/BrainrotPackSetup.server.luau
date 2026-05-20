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

local function chooseBrainrotVariant(brainrotFolder: Instance): Model?
	if not brainrotFolder then
		return nil
	end

	-- Preferimos "Normal" para usar una sola variante por brainrot
	local normalVariant = brainrotFolder:FindFirstChild("Normal")
	if normalVariant and normalVariant:IsA("Model") then
		return normalVariant
	end

	for _, child in ipairs(brainrotFolder:GetChildren()) do
		if child:IsA("Model") then
			return child
		end
	end
	return nil
end

local function moveModelsIntoFolder(source: Instance, modelsFolder: Folder)
	local workspacePack = source:FindFirstChild("Ungroup in Workspace")
	local brainrotsFolder = workspacePack and workspacePack:FindFirstChild("Brainrots")

	-- Estructura esperada del Ultimate Pack: Brainrots/<Name>/<VariantModel>
	if brainrotsFolder and brainrotsFolder:IsA("Folder") then
		for _, brainrotFolder in ipairs(brainrotsFolder:GetChildren()) do
			local variant = chooseBrainrotVariant(brainrotFolder)
			if variant and not hasModelNamed(modelsFolder, brainrotFolder.Name) then
				local clone = variant:Clone()
				clone.Name = brainrotFolder.Name
				clone.Parent = modelsFolder
			end
		end
		return
	end

	-- Fallback genérico
	for _, child in ipairs(source:GetDescendants()) do
		if child:IsA("Model") and not hasModelNamed(modelsFolder, child.Name) then
			local clone = child:Clone()
			clone.Parent = modelsFolder
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

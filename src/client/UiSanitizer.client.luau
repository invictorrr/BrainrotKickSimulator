--[[
    UiSanitizer - Limpia caracteres raros (emojis, tofu boxes, simbolos rotos)
    de todos los TextLabel/TextButton en la UI al cargar y cuando se añaden nuevos.
]]
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function isAllowedCodepoint(cp: number): boolean
	if cp == 9 or cp == 10 or cp == 13 then
		return true
	end
	if cp >= 32 and cp <= 126 then
		return true -- ASCII imprimible
	end
	if cp == 0x00A1 or cp == 0x00BF then -- ! inverted, ¿
		return true
	end
	if cp >= 0x00C0 and cp <= 0x00FF then
		return true -- Latin-1 supplement (acentos españoles)
	end
	if cp >= 0x0100 and cp <= 0x024F then
		return true -- Latin extended
	end
	return false
end

local function sanitizeText(text: string): string
	if type(text) ~= "string" or text == "" then
		return text
	end

	local parts = {}
	for _, cp in utf8.codes(text) do
		if isAllowedCodepoint(cp) then
			table.insert(parts, utf8.char(cp))
		end
	end
	return table.concat(parts)
end

local function sanitizeGuiObject(obj: Instance)
	if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		local cleaned = sanitizeText(obj.Text)
		if cleaned ~= obj.Text then
			obj.Text = cleaned
		end
	end
end

local function sanitizeTree(root: Instance)
	for _, desc in ipairs(root:GetDescendants()) do
		sanitizeGuiObject(desc)
	end
	sanitizeGuiObject(root)
end

local function hookGui(root: Instance)
	sanitizeTree(root)
	root.DescendantAdded:Connect(function(desc)
		task.defer(function()
			sanitizeGuiObject(desc)
		end)
	end)
end

for _, gui in ipairs(playerGui:GetChildren()) do
	if gui:IsA("ScreenGui") then
		hookGui(gui)
	end
end

playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") then
		hookGui(child)
	end
end)

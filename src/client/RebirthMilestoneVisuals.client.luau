local Players = game:GetService("Players")

local player = Players.LocalPlayer
local dragonsFolder = workspace:WaitForChild("DragonWorkers")

local AURA_DEFS = {
	AscensionFlare = {
		Color = Color3.fromRGB(255, 185, 90),
		Rate = 12,
		Brightness = 1.1,
		Range = 9,
	},
	LegendOfIslands = {
		Color = Color3.fromRGB(170, 120, 255),
		Rate = 20,
		Brightness = 1.4,
		Range = 12,
	},
}

local COSMETIC_DEFS = {
	EternalExpeditionCloak = {
		Color = Color3.fromRGB(52, 38, 82),
		Accent = Color3.fromRGB(210, 175, 95),
	},
}

local TITLE_DEFS = {
	AscendantV = "Ascendant V",
}

local characterAttachments = {}
local characterAuras = {}
local dragonAuras = {}
local titleBillboard

local function clearAttachments(container)
	for _, instance in container do
		if instance and instance.Parent then
			instance:Destroy()
		end
	end
	table.clear(container)
end

local function getCharacterRoot(character)
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

local function applyCharacterCosmetic(character, cosmeticId)
	clearAttachments(characterAttachments)
	if typeof(cosmeticId) ~= "string" or cosmeticId == "" then
		return
	end

	local def = COSMETIC_DEFS[cosmeticId]
	local root = getCharacterRoot(character)
	if not def or not root then
		return
	end

	local cloak = Instance.new("Part")
	cloak.Name = "RebirthCosmeticCloak"
	cloak.Size = Vector3.new(2.8, 3.6, 0.18)
	cloak.Color = def.Color
	cloak.Material = Enum.Material.Fabric
	cloak.CanCollide = false
	cloak.CanQuery = false
	cloak.CanTouch = false
	cloak.Massless = true
	cloak.Anchored = false
	cloak.CFrame = root.CFrame * CFrame.new(0, 0.2, 0.55)
	cloak.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = cloak
	weld.Parent = cloak

	local trim = Instance.new("Part")
	trim.Name = "RebirthCosmeticTrim"
	trim.Size = Vector3.new(2.9, 0.18, 0.22)
	trim.Color = def.Accent
	trim.Material = Enum.Material.Neon
	trim.CanCollide = false
	trim.CanQuery = false
	trim.CanTouch = false
	trim.Massless = true
	trim.Anchored = false
	trim.CFrame = cloak.CFrame * CFrame.new(0, 1.7, 0)
	trim.Parent = character

	local trimWeld = Instance.new("WeldConstraint")
	trimWeld.Part0 = cloak
	trimWeld.Part1 = trim
	trimWeld.Parent = trim

	table.insert(characterAttachments, cloak)
	table.insert(characterAttachments, trim)
end

local function applyAuraToRoot(root, auraId, store)
	if store[root] then
		if store[root].Parent then
			store[root]:Destroy()
		end
		store[root] = nil
	end
	if typeof(auraId) ~= "string" or auraId == "" then
		return
	end

	local def = AURA_DEFS[auraId]
	if not def or not root then
		return
	end

	local container = Instance.new("Folder")
	container.Name = "RebirthAuraContainer"
	container.Parent = root

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RebirthAura"
	emitter.Color = ColorSequence.new(def.Color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(0.4, 1.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = def.Rate
	emitter.LightEmission = 0.85
	emitter.Parent = container

	local light = Instance.new("PointLight")
	light.Name = "RebirthAuraLight"
	light.Color = def.Color
	light.Brightness = def.Brightness
	light.Range = def.Range
	light.Parent = container

	store[root] = container
end

local function refreshDragonAuras()
	local auraId = player:GetAttribute("RebirthEquippedAura")
	for _, dragon in dragonsFolder:GetChildren() do
		if dragon:GetAttribute("OwnerUserId") == player.UserId then
			local root = dragon:FindFirstChild("DragonRoot", true)
			if root then
				applyAuraToRoot(root, auraId, dragonAuras)
			end
		end
	end
end

local function applyCharacterTitle(character, titleId)
	if titleBillboard and titleBillboard.Parent then
		titleBillboard:Destroy()
		titleBillboard = nil
	end
	if typeof(titleId) ~= "string" or titleId == "" then
		return
	end

	local root = getCharacterRoot(character)
	local displayText = TITLE_DEFS[titleId] or titleId
	if not root then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RebirthTitleBillboard"
	billboard.Size = UDim2.fromOffset(180, 28)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = displayText
	label.TextColor3 = Color3.fromRGB(255, 220, 130)
	label.TextStrokeTransparency = 0.35
	label.TextSize = 16
	label.Parent = billboard

	titleBillboard = billboard
end

local function applyCharacterRewards(character)
	applyCharacterCosmetic(character, player:GetAttribute("RebirthEquippedCosmetic"))
	applyCharacterTitle(character, player:GetAttribute("RebirthEquippedTitle"))
	local root = getCharacterRoot(character)
	if root then
		applyAuraToRoot(root, player:GetAttribute("RebirthEquippedAura"), characterAuras)
	end
end

local function onCharacterAdded(character)
	applyCharacterRewards(character)
	refreshDragonAuras()
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

player:GetAttributeChangedSignal("RebirthEquippedAura"):Connect(function()
	if player.Character then
		applyCharacterRewards(player.Character)
	end
	refreshDragonAuras()
end)

player:GetAttributeChangedSignal("RebirthEquippedCosmetic"):Connect(function()
	if player.Character then
		applyCharacterRewards(player.Character)
	end
end)

player:GetAttributeChangedSignal("RebirthEquippedTitle"):Connect(function()
	if player.Character then
		applyCharacterRewards(player.Character)
	end
end)

dragonsFolder.ChildAdded:Connect(function(dragon)
	if dragon:GetAttribute("OwnerUserId") == player.UserId then
		task.defer(refreshDragonAuras)
	end
end)

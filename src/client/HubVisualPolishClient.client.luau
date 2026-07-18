local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubVisualConfig = require(ReplicatedStorage:WaitForChild("HubVisualConfig"))
local QuestEvents = ReplicatedStorage:WaitForChild("QuestEvents")
local QuestUpdate = QuestEvents:WaitForChild("QuestUpdate")
local IslandEvents = ReplicatedStorage:WaitForChild("IslandEvents")
local PortalTravel = IslandEvents:WaitForChild("PortalTravel")

local player = Players.LocalPlayer
local COLORS = HubVisualConfig.Colors
local LOD = HubVisualConfig.LOD

local questReadyCount = 0
local indicators = {}
local shrineEmitters = {}
local shrineLights = {}
local lastClaimCelebrationAt = 0

local function isInHub()
	return (player:GetAttribute("CurrentZone") or "MainIsland") == "Hub"
end

local function getHubDistance()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return math.huge
	end
	return (root.Position - HubVisualConfig.HubCenter).Magnitude
end

local function createIndicator(anchor)
	local kind = anchor:GetAttribute("IndicatorKind")
	if not kind then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HubIndicator"
	billboard.Size = UDim2.fromOffset(52, 52)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Enabled = false
	billboard.Parent = anchor

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Image = (kind == "Reward") and HubVisualConfig.Icons.Gift or HubVisualConfig.Icons.Exclamation
	icon.Parent = billboard

	local glow = Instance.new("UIStroke")
	glow.Color = COLORS.GoldBright
	glow.Thickness = 2
	glow.Parent = icon

	indicators[anchor] = billboard

	task.spawn(function()
		while billboard.Parent do
			if billboard.Enabled then
				billboard.StudsOffset = Vector3.new(0, 1.5 + math.sin(os.clock() * 3) * 0.2, 0)
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

local function collectShrineEffects()
	local shrine = workspace:FindFirstChild("DailyRewardsShrine")
	if not shrine then
		return
	end

	for _, descendant in shrine:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			table.insert(shrineEmitters, descendant)
		elseif descendant:IsA("PointLight") and descendant.Parent and descendant.Parent:GetAttribute("ShrineCore") then
			table.insert(shrineLights, descendant)
		end
	end
end

local function setShrineIntensity(active)
	for _, emitter in shrineEmitters do
		if emitter.Parent then
			emitter.Rate = active and 18 or 8
		end
	end
	for _, light in shrineLights do
		if light.Parent then
			light.Brightness = active and 2.4 or 1.4
		end
	end
end

local function updateIndicators()
	local showQuest = questReadyCount > 0
	for anchor, billboard in indicators do
		if anchor.Parent then
			local kind = anchor:GetAttribute("IndicatorKind")
			local visible = false
			if kind == "Quest" then
				visible = showQuest
			elseif kind == "Reward" then
				visible = showQuest
			end
			billboard.Enabled = visible and isInHub()
		end
	end
	setShrineIntensity(showQuest and isInHub())
end

local function playCelebrationAt(buildingName)
	local building = workspace:FindFirstChild(buildingName)
	if not building then
		return
	end

	local anchor = building:FindFirstChild("VisualPolish", true)
	local position = building:GetPivot().Position + Vector3.new(0, 10, 0)
	if anchor then
		local shrineCore = building:FindFirstChild("ShrineCore", true)
		if shrineCore then
			position = shrineCore.Position
		end
	end

	local burstPart = Instance.new("Part")
	burstPart.Anchored = true
	burstPart.CanCollide = false
	burstPart.CanQuery = false
	burstPart.CanTouch = false
	burstPart.Transparency = 1
	burstPart.Size = Vector3.new(1, 1, 1)
	burstPart.CFrame = CFrame.new(position)
	burstPart.Parent = workspace

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxassetid://243660364"
	burst.Color = ColorSequence.new(COLORS.GoldBright, COLORS.Crystal)
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Speed = NumberRange.new(6, 12)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Parent = burstPart
	burst:Emit(36)

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://12221967"
	sound.Volume = 0.45
	sound.Parent = burstPart
	sound:Play()

	task.delay(2, function()
		burstPart:Destroy()
	end)
end

local function applyLod()
	local distance = getHubDistance()
	local mode = "full"
	if distance > LOD.DisabledDistance then
		mode = "off"
	elseif distance > LOD.ReducedDistance then
		mode = "reduced"
	elseif distance > LOD.FullDistance then
		mode = "medium"
	end

	local polishRoot = workspace:FindFirstChild("HubVisualPolish")
	if not polishRoot then
		return
	end

	for _, descendant in polishRoot:GetDescendants() do
		if descendant:GetAttribute("HubPolishEffect") or descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") then
			if descendant:IsA("ParticleEmitter") then
				local baseRate = descendant:GetAttribute("BaseRate")
				if not baseRate then
					baseRate = descendant.Rate
					descendant:SetAttribute("BaseRate", baseRate)
				end
				if mode == "off" then
					descendant.Enabled = false
				else
					descendant.Enabled = true
					local scale = (mode == "full") and 1 or (mode == "medium") and 0.65 or 0.35
					descendant.Rate = baseRate * scale
				end
			elseif descendant:IsA("Sound") then
				descendant.Volume = (mode == "off") and 0 or ((mode == "full") and 0.18 or 0.08)
			elseif descendant:IsA("Beam") then
				descendant.Enabled = mode ~= "off"
			end
		end
	end

	for _, portal in workspace:GetChildren() do
		if portal:IsA("Model") and (portal.Name == "HubPortal" or portal.Name == "MainIslandPortal" or portal.Name:match("^HubPortal%d+$")) then
			local core = portal:FindFirstChild("PortalCore")
			if core then
				for _, child in core:GetChildren() do
					if child:IsA("ParticleEmitter") then
						child.Enabled = mode ~= "off"
						if mode == "reduced" then
							child.Rate = 6
						elseif mode == "medium" then
							child.Rate = 9
						elseif mode == "full" then
							child.Rate = 12
						end
					elseif child:IsA("Sound") then
						child.Volume = (mode == "off") and 0 or 0.18
					end
				end
			end
		end
	end
end

local function updateNightEffects()
	local clockTime = Lighting.ClockTime
	local isNight = clockTime >= 18 or clockTime <= 6
	local polishRoot = workspace:FindFirstChild("HubVisualPolish")
	if not polishRoot then
		return
	end
	local ambience = polishRoot:FindFirstChild("HubAmbience")
	if not ambience then
		return
	end
	local fireflies = ambience:FindFirstChild("FireflyZone")
	if fireflies then
		local emitter = fireflies:FindFirstChild("Fireflies")
		if emitter then
			emitter.Rate = (isNight and isInHub()) and 8 or 0
		end
	end
end

local function playPortalEnterBurst()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxassetid://243660364"
	burst.Color = ColorSequence.new(COLORS.Portal, COLORS.GoldBright)
	burst.Lifetime = NumberRange.new(0.4, 0.9)
	burst.Speed = NumberRange.new(10, 18)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.LightEmission = 1
	burst.Parent = root
	burst:Emit(22)

	local hum = Instance.new("Sound")
	hum.SoundId = "rbxassetid://12222216"
	hum.Volume = 0.35
	hum.Parent = root
	hum:Play()

	task.delay(1.5, function()
		if burst.Parent then burst:Destroy() end
		if hum.Parent then hum:Destroy() end
	end)
end

local function bindIndicatorAnchors()
	for buildingKey, config in HubVisualConfig.Buildings do
		local model = workspace:FindFirstChild(config.ModelName)
		if model then
			for _, descendant in model:GetDescendants() do
				if descendant.Name == "IndicatorAnchor" and descendant:IsA("BasePart") then
					createIndicator(descendant)
				end
			end
		end
	end
end

task.defer(function()
	task.wait(1)
	bindIndicatorAnchors()
	collectShrineEffects()
	updateIndicators()
end)

QuestUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.Quests) ~= "table" then
		return
	end

	local previousReady = questReadyCount
	questReadyCount = 0
	for _, quest in payload.Quests do
		if quest.ReadyToClaim and not quest.Claimed then
			questReadyCount += 1
		end
	end

	if questReadyCount < previousReady and os.clock() - lastClaimCelebrationAt > 0.5 then
		lastClaimCelebrationAt = os.clock()
		if isInHub() then
			playCelebrationAt("DailyRewardsShrine")
		end
	end

	updateIndicators()
end)

player:GetAttributeChangedSignal("CurrentZone"):Connect(function()
	updateIndicators()
	updateNightEffects()
end)

PortalTravel.OnClientEvent:Connect(function(phase)
	if phase == "fadeOut" then
		playPortalEnterBurst()
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then
		return
	end
	if prompt.Name ~= "HubPolishPrompt" then
		return
	end
	if prompt.ActionText == "Claim" and prompt.ObjectText == "Daily Rewards" then
		if _G.DragonIslandOpenDailyReward then
			_G.DragonIslandOpenDailyReward()
		elseif _G.DragonIslandOpenQuests then
			_G.DragonIslandOpenQuests()
		end
	end
end)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered == player and prompt.Name == "HubPolishPrompt" and prompt.ObjectText:find("Portal") == nil then
		if prompt.ActionText == "Travel" or prompt.ActionText == "Return" then
			return
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if os.clock() % 0.75 < 0.02 then
		applyLod()
	end
end)

Lighting:GetPropertyChangedSignal("ClockTime"):Connect(updateNightEffects)
updateNightEffects()

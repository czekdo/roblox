local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local AdminConfig = require(ReplicatedStorage:WaitForChild("AdminConfig"))
local AdminBridge = require(script.Parent:WaitForChild("AdminBridge"))
local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))
local BuildingConfig = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))

local AdminEvents = ReplicatedStorage:WaitForChild("AdminEvents")
local AdminCommand = AdminEvents:WaitForChild("AdminCommand")
local AdminResult = AdminEvents:WaitForChild("AdminResult")
local CheckAdminAccess = AdminEvents:WaitForChild("CheckAdminAccess")

local HarvestUIUpdate = ReplicatedStorage:WaitForChild("HarvestEvents"):WaitForChild("HarvestUIUpdate")
local IslandUnlockState = ReplicatedStorage:WaitForChild("IslandEvents"):WaitForChild("IslandUnlockState")
local IslandTeleportRequest = ReplicatedStorage:WaitForChild("IslandEvents"):WaitForChild("IslandTeleportRequest")
local PortalTravel = ReplicatedStorage:WaitForChild("IslandEvents"):WaitForChild("PortalTravel")

local DATASTORES = {
	"IslandUnlocksV1",
	"KingdomProgressV1",
	"DragonWorkerLevelsV1",
	"DragonEggProgressV1",
	"DailyQuestProgressV1",
	"DragonIslandTutorialV1",
	"FixedBuildingProgressV1",
}

local TELEPORT_COOLDOWN = 0.5
local FADE_IN_TIME = 0.45
local FADE_HOLD_TIME = 0.15
local teleportCooldown = {}

local function isAdmin(player)
	return AdminConfig.IsAdmin(player)
end

local function sendResult(player, success, message, extra)
	AdminResult:FireClient(player, {
		success = success == true,
		message = tostring(message or ""),
		extra = extra,
	})
end

local function clampNumber(value, minValue, maxValue)
	local numberValue = math.floor(tonumber(value) or 0)
	return math.clamp(numberValue, minValue, maxValue)
end

local function setEssence(player, delta)
	local current = player:GetAttribute("DragonEssence") or 0
	local nextValue = current + delta
	if nextValue < 0 then
		return false, "Essence cannot go below 0"
	end
	player:SetAttribute("DragonEssence", nextValue)
	HarvestUIUpdate:FireClient(player, nextValue)
	return true, (delta >= 0 and "Added " or "Removed ") .. tostring(math.abs(delta)) .. " Dragon Essence"
end

local function fadeTeleport(player, targetCFrame, zoneName)
	if teleportCooldown[player] then
		return false, "Teleport cooling down"
	end
	local character = player.Character
	if not character then
		return false, "Character not ready"
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return false, "Character not ready"
	end

	teleportCooldown[player] = true
	task.delay(TELEPORT_COOLDOWN, function()
		teleportCooldown[player] = nil
	end)

	PortalTravel:FireClient(player, "fadeIn")
	task.wait(FADE_IN_TIME + FADE_HOLD_TIME)
	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = targetCFrame
	if zoneName then
		player:SetAttribute("CurrentZone", zoneName)
	end
	task.wait()
	PortalTravel:FireClient(player, "fadeOut")
	return true, "Teleported"
end

local function adminTeleport(player, destinationId)
	if destinationId == "Hub" then
		local ok, message = fadeTeleport(player, WorkspaceLayout.GetHubSpawnCFrame(), "Hub")
		return ok, message
	end
	if destinationId == "MainIsland" then
		local ok, message = fadeTeleport(player, WorkspaceLayout.GetIslandSpawnCFrame(), "MainIsland")
		return ok, message
	end

	local ok, result = AdminBridge.call("Islands", "teleport", player, destinationId, true)
	if ok then
		return true, result or "Teleported"
	end
	return false, result
end

local function refreshUI(player)
	local ok, message = AdminBridge.call("Harvest", "refreshUI", player)
	AdminBridge.call("Islands", "refreshState", player)
	AdminBridge.call("Buildings", "refreshState", player)
	AdminBridge.call("Quests", "refreshState", player)
	AdminBridge.call("Tutorial", "refreshState", player)
	AdminBridge.call("Kingdom", "refreshState", player)
	return true, ok and message or "UI refreshed"
end

local function savePlayer(player)
	local messages = {}
	for _, domain in { "Harvest", "Islands", "Buildings", "Quests", "Tutorial", "Kingdom" } do
		local ok, result = AdminBridge.call(domain, "save", player)
		if ok and result then
			table.insert(messages, result)
		end
	end
	return true, #messages > 0 and table.concat(messages, " | ") or "Save requested"
end

local function wipeDatastore(key, userId)
	if game.GameId == 0 then
		return true
	end
	local store = DataStoreService:GetDataStore(key)
	local success = pcall(function()
		store:RemoveAsync(tostring(userId))
	end)
	return success
end

local function wipePlayer(player)
	for _, storeName in DATASTORES do
		wipeDatastore(storeName, player.UserId)
	end
	for _, domain in { "Harvest", "Islands", "Buildings", "Quests", "Tutorial", "Kingdom" } do
		AdminBridge.call(domain, "wipe", player)
	end
	player:SetAttribute("DragonEssence", 0)
	player:SetAttribute("TutorialCompleted", false)
	player:SetAttribute("TutorialStep", 1)
	player:SetAttribute("KingdomLevel", 1)
	player:SetAttribute("QuestEggs", 0)
	HarvestUIUpdate:FireClient(player, 0)
	return true, "Save wiped. Rejoin to fully reload."
end

local handlers = {
	AddEssence = function(player, payload)
		local amount = clampNumber(payload and payload.amount, 1, 1e12)
		return setEssence(player, amount)
	end,
	RemoveEssence = function(player, payload)
		local amount = clampNumber(payload and payload.amount, 1, 1e12)
		return setEssence(player, -amount)
	end,
	GiveResource = function(player, payload)
		local resourceId = tostring(payload and payload.resourceId or "CrystalResource")
		local amount = clampNumber(payload and payload.amount, 1, 12)
		local ok, result = AdminBridge.call("Harvest", "spawnResourceNodes", player, resourceId, amount)
		if ok then
			return true, result or ("Spawned " .. amount .. " " .. resourceId .. " node(s)")
		end
		return false, result
	end,
	GiveEgg = function(player, payload)
		local eggType = tostring(payload and payload.eggType or "Common")
		if not DragonEggConfig.IsValidEggType(eggType) then
			return false, "Unknown egg type"
		end
		local ok, result = AdminBridge.call("Harvest", "giveEgg", player, eggType)
		if ok then
			return true, result or ("Granted " .. eggType .. " egg")
		end
		return false, result
	end,
	UnlockIsland = function(player, payload)
		local islandId = tostring(payload and payload.islandId or "")
		if islandId == "" then
			return false, "Missing island"
		end
		local ok, result = AdminBridge.call("Islands", "unlockIsland", player, islandId)
		if ok then
			return true, result or ("Unlocked " .. islandId)
		end
		return false, result
	end,
	UnlockAllIslands = function(player)
		local ok, result = AdminBridge.call("Islands", "unlockAll", player)
		if ok then
			return true, result or "All islands unlocked"
		end
		return false, result
	end,
	TeleportIsland = function(player, payload)
		local islandId = tostring(payload and payload.islandId or "Hub")
		local ok, message = adminTeleport(player, islandId)
		return ok, message
	end,
	SpawnCrystalNodes = function(player, payload)
		local count = clampNumber(payload and payload.count, 1, 5)
		local ok, result = AdminBridge.call("Harvest", "respawnCrystalNodes", player, count)
		if ok then
			return true, result or ("Spawned " .. count .. " crystal node(s)")
		end
		return false, result
	end,
	ResetTutorial = function(player)
		local ok, result = AdminBridge.call("Tutorial", "reset", player)
		if ok then
			return true, result or "Tutorial reset"
		end
		return false, result
	end,
	CompleteQuests = function(player)
		local ok, result = AdminBridge.call("Quests", "completeAll", player)
		if ok then
			return true, result or "Quests completed"
		end
		return false, result
	end,
	GiveDragon = function(player, payload)
		local ok, result = AdminBridge.call("Harvest", "giveDragon", player, payload)
		if ok then
			return true, result or "Dragon granted"
		end
		return false, result
	end,
	SpawnTestDragon = function(player, payload)
		local ok, result = AdminBridge.call("Harvest", "spawnTestDragon", player, payload)
		if ok then
			return true, result or "Test dragon spawned"
		end
		return false, result
	end,
	SetBuildingLevel = function(player, payload)
		local buildingId = tostring(payload and payload.buildingId or "")
		local level = clampNumber(payload and payload.level, 1, 25)
		if buildingId == "" then
			return false, "Missing building"
		end
		local ok, result = AdminBridge.call("Buildings", "setLevel", player, buildingId, level)
		if ok then
			return true, result or ("Set " .. buildingId .. " to level " .. level)
		end
		return false, result
	end,
	RefreshUI = function(player)
		return refreshUI(player)
	end,
	SavePlayer = function(player)
		return savePlayer(player)
	end,
	WipeSave = function(player)
		return wipePlayer(player)
	end,
	CompleteTutorial = function(player)
		local ok, result = AdminBridge.call("Tutorial", "complete", player)
		if ok then
			return true, result or "Tutorial completed"
		end
		return false, result
	end,
	RemoveDragon = function(player, payload)
		local ok, result = AdminBridge.call("Harvest", "removeDragon", player, payload)
		if ok then
			return true, result or "Dragon removed"
		end
		return false, result
	end,
	RemoveAllDragons = function(player)
		local ok, result = AdminBridge.call("Harvest", "removeAllDragons", player)
		if ok then
			return true, result or "All dragons removed"
		end
		return false, result
	end,
	ReloadPlayer = function(player)
		return refreshUI(player)
	end,
	SetBuildingMaxLevel = function(player, payload)
		local buildingId = tostring(payload and payload.buildingId or "")
		local maxLevel = BuildingConfig.Upgrade.MaxLevel or 25
		if buildingId == "" then
			return false, "Missing building"
		end
		local ok, result = AdminBridge.call("Buildings", "setLevel", player, buildingId, maxLevel)
		if ok then
			return true, result or ("Set " .. buildingId .. " to max level " .. maxLevel)
		end
		return false, result
	end,
	RespawnCrystalNodes = function(player)
		local ok, result = AdminBridge.call("Harvest", "respawnCrystalNodes", player)
		if ok then
			return true, result or "Crystal nodes respawned"
		end
		return false, result
	end,
}

CheckAdminAccess.OnServerInvoke = function(player)
	if not isAdmin(player) then
		return { isAdmin = false }
	end

	local eggTypes = {}
	for _, eggType in DragonEggConfig.GetRewardEggOrder() do
		local info = DragonEggConfig.GetEggTypeInfo(eggType)
		table.insert(eggTypes, {
			id = eggType,
			name = info.DisplayName,
			icon = info.Icon or DragonEggConfig.IconAssetId,
		})
	end

	local islands = {
		{ id = "Hub", name = "Hub" },
		{ id = "MainIsland", name = "Main Island" },
	}
	for _, island in IslandUnlockConfig.Islands do
		table.insert(islands, { id = island.Id, name = island.DisplayName })
	end

	local buildings = {}
	for _, buildingId in BuildingConfig.BuildingOrder do
		local info = BuildingConfig.Buildings[buildingId]
		if info then
			table.insert(buildings, { id = buildingId, name = info.DisplayName })
		end
	end

	return {
		isAdmin = true,
		resources = AdminConfig.ResourceTypes,
		eggTypes = eggTypes,
		islands = islands,
		dragonTypes = DragonEggConfig.DragonTypes,
		rarities = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Ancient" },
		buildings = buildings,
		maxBuildingLevel = BuildingConfig.Upgrade.MaxLevel or 25,
		tabs = AdminConfig.TabOrder,
	}
end

AdminCommand.OnServerEvent:Connect(function(player, action, payload)
	if not isAdmin(player) then
		return
	end
	if typeof(action) ~= "string" then
		return
	end

	local handler = handlers[action]
	if not handler then
		sendResult(player, false, "Unknown admin action")
		return
	end

	local ok, message = handler(player, payload)
	sendResult(player, ok, message)
end)

Players.PlayerRemoving:Connect(function(player)
	teleportCooldown[player] = nil
end)

print("[AdminPanelManager] Dev admin panel ready")

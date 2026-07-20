local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WorkshopCraftConfig = require(ReplicatedStorage:WaitForChild("WorkshopCraftConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))
local CraftEvents = ReplicatedStorage:WaitForChild("CraftEvents")
local RequestCraftData = CraftEvents:WaitForChild("RequestCraftData")
local CraftItem = CraftEvents:WaitForChild("CraftItem")
local CraftStateUpdated = CraftEvents:WaitForChild("CraftStateUpdated")
local QuestProgressSignal = ReplicatedStorage:WaitForChild("QuestEvents"):WaitForChild("QuestProgressSignal")

local function getWorkshopTier(player)
	local island = WorkspaceLayout.GetPlayerIsland(player)
	local workshop = island and island:FindFirstChild("Workshop")
	if workshop then
		return math.max(1, workshop:GetAttribute("CraftingRecipeTier") or 1)
	end
	return 1
end

local function buildPayload(player, message)
	local tier = getWorkshopTier(player)
	local recipes = {}
	for _, recipe in WorkshopCraftConfig.GetAvailableRecipes(tier) do
		table.insert(recipes, {
			id = recipe.Id,
			displayName = recipe.DisplayName,
			description = recipe.Description,
			cost = recipe.Cost,
			tier = recipe.Tier,
			rewardText = recipe.Reward.Text,
		})
	end
	return {
		recipeTier = tier,
		recipes = recipes,
		essence = player:GetAttribute("DragonEssence") or 0,
		message = message,
	}
end

local function sendState(player, message)
	CraftStateUpdated:FireClient(player, buildPayload(player, message))
end

local function applyReward(player, reward)
	-- "QuestEgg" is Craft's historical name for the shared "Eggs" reward type.
	if reward.Type == "QuestEgg" then
		reward = { Type = "Eggs", Amount = reward.Amount or 1 }
	end
	RewardService.Grant(player, reward, { Source = "Craft" })
end

RequestCraftData.OnServerInvoke = function(player)
	return buildPayload(player)
end

CraftItem.OnServerEvent:Connect(function(player, recipeId)
	if not RateLimiter.check(player, "CraftItem", 0.3) then
		return
	end
	recipeId = tostring(recipeId or "")
	local recipe = WorkshopCraftConfig.GetRecipe(recipeId)
	if not recipe then
		sendState(player, "Recipe not found")
		return
	end

	local tier = getWorkshopTier(player)
	if (recipe.Tier or 1) > tier then
		sendState(player, "Upgrade your Workshop to unlock this recipe")
		return
	end

	local essence = player:GetAttribute("DragonEssence") or 0
	if essence < recipe.Cost then
		sendState(player, "Need " .. tostring(recipe.Cost) .. " Dragon Essence")
		return
	end

	local found = AdminBridge.call("Harvest", "adjustEssence", player, -recipe.Cost)
	if not found then
		player:SetAttribute("DragonEssence", essence - recipe.Cost)
	end
	applyReward(player, recipe.Reward)
	QuestProgressSignal:Fire(player, "CraftItem", 1)
	sendState(player, "Crafted " .. recipe.DisplayName)
end)

print("[WorkshopCraftManager] Workshop crafting ready")

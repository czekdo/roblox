local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorkshopCraftConfig = require(ReplicatedStorage:WaitForChild("WorkshopCraftConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local CraftEvents = ReplicatedStorage:WaitForChild("CraftEvents")
local RequestCraftData = CraftEvents:WaitForChild("RequestCraftData")
local CraftItem = CraftEvents:WaitForChild("CraftItem")
local CraftStateUpdated = CraftEvents:WaitForChild("CraftStateUpdated")
local KingdomEvents = ReplicatedStorage:WaitForChild("KingdomEvents")
local GrantDecoration = KingdomEvents:WaitForChild("GrantDecoration")

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
	if reward.Type == "DragonEssence" then
		local essence = player:GetAttribute("DragonEssence") or 0
		player:SetAttribute("DragonEssence", essence + reward.Amount)
	elseif reward.Type == "TemporaryBoost" then
		local expiresAt = os.time() + reward.Duration
		player:SetAttribute(reward.BoostId .. "Multiplier", reward.Multiplier)
		player:SetAttribute(reward.BoostId .. "ExpiresAt", expiresAt)
	elseif reward.Type == "QuestEgg" then
		local questEggs = player:GetAttribute("QuestEggs") or 0
		player:SetAttribute("QuestEggs", questEggs + (reward.Amount or 1))
	elseif reward.Type == "Decoration" then
		GrantDecoration:Fire(player, reward.DecorationId)
	end
end

RequestCraftData.OnServerInvoke = function(player)
	return buildPayload(player)
end

CraftItem.OnServerEvent:Connect(function(player, recipeId)
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

	player:SetAttribute("DragonEssence", essence - recipe.Cost)
	applyReward(player, recipe.Reward)
	sendState(player, "Crafted " .. recipe.DisplayName)
end)

print("[WorkshopCraftManager] Workshop crafting ready")

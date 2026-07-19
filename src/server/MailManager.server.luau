local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local RewardService = require(ServerScriptService:WaitForChild("RewardService"))

local MailEvents = ReplicatedStorage:WaitForChild("MailEvents")
local RequestMailList = MailEvents:WaitForChild("RequestMailList")
local ClaimMail = MailEvents:WaitForChild("ClaimMail")

local MAIL_DATASTORE = "DragonIslandMailV1"

local mailStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(MAIL_DATASTORE)
	end)
	if success then
		mailStore = result
		dataStoreAvailable = true
	else
		warn("[MailManager] Mail DataStore unavailable; mail will not persist until publishing:", result)
	end
end

-- Mail entry shape: { Id, Title, Body, Reward (optional, RewardService reward table), Claimed, SentAt }
local playerMail = {}

local function saveDataNow(player)
	local mail = playerMail[player]
	if not mail or not dataStoreAvailable or not mailStore then
		return
	end
	local success, err = pcall(function()
		mailStore:UpdateAsync(tostring(player.UserId), function()
			return mail
		end)
	end)
	if not success then
		warn("[MailManager] Failed to save mail for", player.UserId, err)
	end
end

local function seedWelcomeMail()
	return {
		{
			Id = "welcome",
			Title = "Welcome, Dragon Keeper!",
			Body = "Thanks for building your kingdom. Here's a small gift to help you get started.",
			Reward = { Type = "DragonEssence", Amount = 150, Text = "+150 Dragon Essence" },
			Claimed = false,
			SentAt = os.time(),
		},
	}
end

local function loadPlayer(player)
	local mail = nil
	if dataStoreAvailable and mailStore then
		local success, result = pcall(function()
			return mailStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" then
			mail = result
		elseif not success then
			warn("[MailManager] Failed to load mail for", player.UserId, result)
		end
	end
	if not mail then
		mail = seedWelcomeMail()
	end
	playerMail[player] = mail
	if dataStoreAvailable then
		saveDataNow(player)
	end
end

local function countUnclaimed(mail)
	local count = 0
	for _, entry in mail do
		if not entry.Claimed then
			count += 1
		end
	end
	return count
end

RequestMailList.OnServerInvoke = function(player)
	if not playerMail[player] then
		loadPlayer(player)
	end
	local mail = playerMail[player]
	return {
		mail = mail,
		unclaimedCount = countUnclaimed(mail),
	}
end

ClaimMail.OnServerEvent:Connect(function(player, mailId)
	local mail = playerMail[player]
	if not mail or typeof(mailId) ~= "string" then
		return
	end
	for _, entry in mail do
		if entry.Id == mailId then
			if entry.Claimed then
				return
			end
			entry.Claimed = true
			if entry.Reward then
				RewardService.Grant(player, entry.Reward, { Source = "Mail" })
			end
			saveDataNow(player)
			return
		end
	end
end)

Players.PlayerAdded:Connect(loadPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveDataNow(player)
	playerMail[player] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveDataNow(player)
	end
end)

print("[MailManager] Mail system ready")

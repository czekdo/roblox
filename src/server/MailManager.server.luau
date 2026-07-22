local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

local MailEvents = ReplicatedStorage:WaitForChild("MailEvents")
local RequestMailList = MailEvents:WaitForChild("RequestMailList")
local ClaimMail = MailEvents:WaitForChild("ClaimMail")
local QuestProgressSignal = ReplicatedStorage:WaitForChild("QuestEvents"):WaitForChild("QuestProgressSignal")

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
	if not RateLimiter.check(player, "ClaimMail", 0.3) then
		return
	end
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
			if entry.Rewards then
				RewardService.GrantMany(player, entry.Rewards, { Source = "Mail" })
			end
			saveDataNow(player)
			QuestProgressSignal:Fire(player, "ClaimMail", 1)
			return
		end
	end
end)

-- Delivers mail to a UserId regardless of whether that player is online right now (e.g. weekly
-- leaderboard reward payouts, which need to reach players who aren't in this server or even
-- online at all). An online player's in-memory table is the live authoritative copy - writing
-- straight to the DataStore in that case would get silently clobbered the next time they leave
-- and saveDataNow() overwrites it with the (now stale) in-memory version. So: if they're online,
-- append to the live table and let the normal save path persist it; if not, write the DataStore
-- record directly.
local function grantMailToUserId(userId, mailEntry)
	if typeof(mailEntry) ~= "table" or typeof(mailEntry.Id) ~= "string" then
		return false, "Invalid mail entry"
	end
	mailEntry.Claimed = false
	mailEntry.SentAt = mailEntry.SentAt or os.time()

	local onlinePlayer = Players:GetPlayerByUserId(userId)
	if onlinePlayer then
		if not playerMail[onlinePlayer] then
			loadPlayer(onlinePlayer)
		end
		table.insert(playerMail[onlinePlayer], mailEntry)
		saveDataNow(onlinePlayer)
		return true
	end

	if not dataStoreAvailable or not mailStore then
		return false, "Mail DataStore unavailable"
	end
	local ok, err = pcall(function()
		mailStore:UpdateAsync(tostring(userId), function(existing)
			local mail = typeof(existing) == "table" and existing or seedWelcomeMail()
			table.insert(mail, mailEntry)
			return mail
		end)
	end)
	if not ok then
		warn("[MailManager] Failed to grant offline mail to", userId, err)
		return false, err
	end
	return true
end

AdminBridge.register("Mail", {
	grant = grantMailToUserId,
})

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

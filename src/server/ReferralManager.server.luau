local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local ReferralConfig = require(ReplicatedStorage:WaitForChild("ReferralConfig"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))

-- Both the containing folder and its RemoteFunctions are created here rather than relying on
-- manually-added Studio instances: those only exist as plain Instances (not Rojo-managed files),
-- so they silently vanish if added mid-session and the place isn't saved before a Studio restart.
-- Self-creating means this feature can never break that way.
local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemote(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local ReferralEvents = ensureFolder(ReplicatedStorage, "ReferralEvents")
local SubmitReferralCode = ensureRemote(ReferralEvents, "SubmitReferralCode", "RemoteFunction")
local RequestReferralInfo = ensureRemote(ReferralEvents, "RequestReferralInfo", "RemoteFunction")

local dataStoreAvailable = false
local linkStore, countStore
if game.GameId ~= 0 then
	local ok = pcall(function()
		linkStore = DataStoreService:GetDataStore(ReferralConfig.LinkDataStoreName)
		countStore = DataStoreService:GetDataStore(ReferralConfig.CountDataStoreName)
	end)
	dataStoreAvailable = ok
	if not ok then
		warn("[ReferralManager] DataStore unavailable; referrals disabled until published.")
	end
end

-- player -> { ReferrerUserId = number?, Qualified = boolean }
local playerLinks = {}

local function loadLink(player)
	local record = { ReferrerUserId = nil, Qualified = false }
	if dataStoreAvailable then
		local ok, result = pcall(function()
			return linkStore:GetAsync(tostring(player.UserId))
		end)
		if ok and typeof(result) == "table" then
			record = result
		end
	end
	playerLinks[player] = record
end

local function saveLink(player)
	if not dataStoreAvailable then
		return
	end
	local record = playerLinks[player]
	if not record then
		return
	end
	pcall(function()
		linkStore:SetAsync(tostring(player.UserId), record)
	end)
end

Players.PlayerAdded:Connect(loadLink)
for _, player in Players:GetPlayers() do
	task.spawn(loadLink, player)
end

Players.PlayerRemoving:Connect(function(player)
	playerLinks[player] = nil
end)

local function checkQualification(player)
	local record = playerLinks[player]
	if not record or not record.ReferrerUserId or record.Qualified then
		return
	end
	local level = player:GetAttribute("KingdomLevel") or 1
	if level < ReferralConfig.QualifyingKingdomLevel then
		return
	end

	record.Qualified = true
	saveLink(player)

	local mailEntry = {
		Id = "referral_" .. tostring(player.UserId) .. "_" .. tostring(os.time()),
		Title = "Friend Referral Reward!",
		Body = string.format(
			"%s reached Kingdom Level %d after joining with your invite - thanks for spreading the word!",
			player.Name,
			ReferralConfig.QualifyingKingdomLevel
		),
		Rewards = {
			{ Type = "PremiumCurrency", Amount = ReferralConfig.ReferrerReward.Gems, Text = "+" .. tostring(ReferralConfig.ReferrerReward.Gems) .. " Gems" },
			{ Type = "DragonEssence", Amount = ReferralConfig.ReferrerReward.Essence, Text = "+" .. tostring(ReferralConfig.ReferrerReward.Essence) .. " Dragon Essence" },
		},
	}
	AdminBridge.call("Mail", "grant", record.ReferrerUserId, mailEntry)

	if dataStoreAvailable and countStore then
		pcall(function()
			countStore:UpdateAsync(tostring(record.ReferrerUserId), function(old)
				return (tonumber(old) or 0) + 1
			end)
		end)
	end
end

local function watchPlayer(player)
	-- loadLink (a separate PlayerAdded connection above) may still be mid-flight on its own
	-- GetAsync call when this handler starts, since Roblox invokes every connected listener for
	-- the same join event without waiting for earlier ones to finish. Give it a moment so
	-- playerLinks[player] is populated before the first qualification check.
	task.wait(1)
	checkQualification(player)
	player:GetAttributeChangedSignal("KingdomLevel"):Connect(function()
		checkQualification(player)
	end)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(watchPlayer, player)
end

SubmitReferralCode.OnServerInvoke = function(player, friendUsername)
	if not RateLimiter.check(player, "SubmitReferralCode", 2) then
		return { ok = false, message = "Please wait a moment and try again." }
	end
	if typeof(friendUsername) ~= "string" or friendUsername == "" then
		return { ok = false, message = "Enter a username." }
	end
	local record = playerLinks[player]
	if not record then
		return { ok = false, message = "Not ready yet - try again in a moment." }
	end
	if record.ReferrerUserId then
		return { ok = false, message = "You've already used a referral code." }
	end
	local level = player:GetAttribute("KingdomLevel") or 1
	if level > ReferralConfig.MaxKingdomLevelToRedeem then
		return { ok = false, message = "Referral codes can only be used by a brand-new kingdom." }
	end

	local ok, resolvedUserId = pcall(function()
		return Players:GetUserIdFromNameAsync(friendUsername)
	end)
	if not ok or not resolvedUserId then
		return { ok = false, message = "Couldn't find a player with that username." }
	end
	if resolvedUserId == player.UserId then
		return { ok = false, message = "You can't refer yourself." }
	end

	record.ReferrerUserId = resolvedUserId
	record.Qualified = false
	saveLink(player)

	RewardService.GrantMany(player, {
		{ Type = "PremiumCurrency", Amount = ReferralConfig.NewPlayerReward.Gems, Text = "+" .. tostring(ReferralConfig.NewPlayerReward.Gems) .. " Gems" },
		{ Type = "DragonEssence", Amount = ReferralConfig.NewPlayerReward.Essence, Text = "+" .. tostring(ReferralConfig.NewPlayerReward.Essence) .. " Dragon Essence" },
	}, { Source = "Referral" })

	return {
		ok = true,
		message = "Welcome gift claimed! Your friend will be rewarded once you reach Kingdom Level "
			.. tostring(ReferralConfig.QualifyingKingdomLevel)
			.. ".",
	}
end

RequestReferralInfo.OnServerInvoke = function(player)
	local record = playerLinks[player] or {}
	local referralCount = 0
	if dataStoreAvailable and countStore then
		local ok, count = pcall(function()
			return countStore:GetAsync(tostring(player.UserId))
		end)
		if ok and typeof(count) == "number" then
			referralCount = count
		end
	end
	return {
		myUsername = player.Name,
		hasReferrer = record.ReferrerUserId ~= nil,
		canRedeem = record.ReferrerUserId == nil and (player:GetAttribute("KingdomLevel") or 1) <= ReferralConfig.MaxKingdomLevelToRedeem,
		referralCount = referralCount,
		qualifyingLevel = ReferralConfig.QualifyingKingdomLevel,
	}
end

print("[ReferralManager] Referral system ready")

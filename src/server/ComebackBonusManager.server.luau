local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local ComebackBonusConfig = require(ReplicatedStorage:WaitForChild("ComebackBonusConfig"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

local dataStoreAvailable = false
local lastSeenStore = nil
if game.GameId ~= 0 then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(ComebackBonusConfig.DataStoreName)
	end)
	if ok then
		lastSeenStore = result
		dataStoreAvailable = true
	else
		warn("[ComebackBonusManager] DataStore unavailable; comeback bonus disabled until published.")
	end
end

local function handlePlayer(player)
	if not dataStoreAvailable then
		return
	end

	-- Give MailManager's own PlayerAdded handler a head start loading this player's mail before we
	-- (from a completely separate script's PlayerAdded connection) potentially also touch it via
	-- AdminBridge's Mail.grant. Both would otherwise race to load/save the same in-memory table
	-- concurrently, and whichever GetAsync resolves last would silently clobber the other's write.
	task.wait(6)

	local now = os.time()
	local ok, lastSeen = pcall(function()
		return lastSeenStore:GetAsync(tostring(player.UserId))
	end)
	if ok and typeof(lastSeen) == "number" then
		local daysSince = math.floor((now - lastSeen) / 86400)
		local tier = ComebackBonusConfig.GetTierForDays(daysSince)
		if tier then
			local mailEntry = {
				Id = "comeback_" .. tostring(now),
				Title = tier.Label,
				Body = string.format(
					"You've been away %d day%s - here's something to help you catch back up!",
					daysSince,
					daysSince == 1 and "" or "s"
				),
				Rewards = {
					{ Type = "PremiumCurrency", Amount = tier.Gems, Text = "+" .. tostring(tier.Gems) .. " Gems" },
					{ Type = "DragonEssence", Amount = tier.Essence, Text = "+" .. tostring(tier.Essence) .. " Dragon Essence" },
				},
			}
			AdminBridge.call("Mail", "grant", player.UserId, mailEntry)
		end
	end

	pcall(function()
		lastSeenStore:SetAsync(tostring(player.UserId), now)
	end)
end

Players.PlayerAdded:Connect(handlePlayer)
for _, player in Players:GetPlayers() do
	task.spawn(handlePlayer, player)
end

print("[ComebackBonusManager] Comeback bonus ready")

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))
local AdminConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("AdminConfig"))

local BAN_DATASTORE = "DragonIslandBannedPlayersV1"

local dataStoreAvailable = false
local banStore = nil
if game.GameId ~= 0 then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(BAN_DATASTORE)
	end)
	if ok then
		banStore = result
		dataStoreAvailable = true
	else
		warn("[BanManager] DataStore unavailable; bans disabled until published.")
	end
end

local function resolveUserId(usernameOrId)
	local asNumber = tonumber(usernameOrId)
	if asNumber then
		return asNumber
	end
	local ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(tostring(usernameOrId))
	end)
	if ok and userId then
		return userId
	end
	return nil
end

local function getBanRecord(userId)
	if not dataStoreAvailable then
		return nil
	end
	local ok, result = pcall(function()
		return banStore:GetAsync(tostring(userId))
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	return nil
end

-- Checked on join, as early as possible - other systems' own PlayerAdded handlers may still fire
-- before Kick() actually disconnects the player, but that's harmless (e.g. a welcome mail record
-- being written for someone about to be removed anyway).
Players.PlayerAdded:Connect(function(player)
	local record = getBanRecord(player.UserId)
	if record then
		player:Kick("You are banned from this game. Reason: " .. tostring(record.reason or "No reason given"))
	end
end)

local function kickPlayer(admin, usernameOrId, reason)
	if not AdminConfig.IsAdmin(admin) then
		return { success = false, message = "Not authorized" }
	end
	local userId = resolveUserId(usernameOrId)
	if not userId then
		return { success = false, message = "Couldn't find that player" }
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target then
		return { success = false, message = "Player is not currently online" }
	end
	if AdminConfig.IsAdmin(target) then
		return { success = false, message = "Can't kick another admin" }
	end
	target:Kick(tostring(reason ~= "" and reason or "Kicked by an admin"))
	return { success = true, message = "Kicked " .. target.Name }
end

local function banPlayer(admin, usernameOrId, reason)
	if not AdminConfig.IsAdmin(admin) then
		return { success = false, message = "Not authorized" }
	end
	local userId = resolveUserId(usernameOrId)
	if not userId then
		return { success = false, message = "Couldn't find that player" }
	end
	local onlineTarget = Players:GetPlayerByUserId(userId)
	if onlineTarget and AdminConfig.IsAdmin(onlineTarget) then
		return { success = false, message = "Can't ban another admin" }
	end

	local record = {
		reason = (typeof(reason) == "string" and reason ~= "") and reason or "No reason given",
		bannedAt = os.time(),
		bannedBy = admin.UserId,
	}
	if not dataStoreAvailable then
		return { success = false, message = "DataStore unavailable - ban not saved" }
	end
	local ok, err = pcall(function()
		banStore:SetAsync(tostring(userId), record)
	end)
	if not ok then
		warn("[BanManager] Failed to save ban:", err)
		return { success = false, message = "Failed to save ban" }
	end

	if onlineTarget then
		onlineTarget:Kick("You have been banned from this game. Reason: " .. record.reason)
	end
	return { success = true, message = "Banned UserId " .. tostring(userId) }
end

local function unbanPlayer(admin, usernameOrId)
	if not AdminConfig.IsAdmin(admin) then
		return { success = false, message = "Not authorized" }
	end
	local userId = resolveUserId(usernameOrId)
	if not userId then
		return { success = false, message = "Couldn't find that player" }
	end
	if not dataStoreAvailable then
		return { success = false, message = "DataStore unavailable" }
	end
	local ok, err = pcall(function()
		banStore:RemoveAsync(tostring(userId))
	end)
	if not ok then
		warn("[BanManager] Failed to remove ban:", err)
		return { success = false, message = "Failed to unban" }
	end
	return { success = true, message = "Unbanned UserId " .. tostring(userId) }
end

AdminBridge.register("Moderation", {
	kick = kickPlayer,
	ban = banPlayer,
	unban = unbanPlayer,
})

print("[BanManager] Ban/kick moderation ready")

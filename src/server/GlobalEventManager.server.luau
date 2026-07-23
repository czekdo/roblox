local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local GlobalEventConfig = require(ReplicatedStorage:WaitForChild("GlobalEventConfig"))
local AdminConfig = require(ReplicatedStorage:WaitForChild("AdminConfig"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

-- Self-creating, same reasoning as the other RemoteEvents added this session: a manually-added
-- Studio Instance can vanish if the place isn't saved before a Studio restart, so the server
-- guarantees its own existence instead of depending on that.
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

local GlobalEventEvents = ensureFolder(ReplicatedStorage, "GlobalEventEvents")
local RequestGlobalEventState = ensureRemote(GlobalEventEvents, "RequestGlobalEventState", "RemoteFunction")
local GlobalEventChanged = ensureRemote(GlobalEventEvents, "GlobalEventChanged", "RemoteEvent")

local dataStoreAvailable = false
local eventStore = nil
if game.GameId ~= 0 then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GlobalEventConfig.DataStoreName)
	end)
	if ok then
		eventStore = result
		dataStoreAvailable = true
	else
		warn("[GlobalEventManager] DataStore unavailable; events disabled until published.")
	end
end

-- Local cache every other system on this server reads from. Shape: nil (no event) or
-- { type = string, multiplier = number, endsAt = unixTimestamp, label = string }.
local activeEvent = nil

local function isExpired(event)
	return not event or typeof(event.endsAt) ~= "number" or event.endsAt <= os.time()
end

local function broadcastState()
	local payload = (not isExpired(activeEvent)) and activeEvent or nil
	GlobalEventChanged:FireAllClients(payload)
end

local function loadFromStore()
	if not dataStoreAvailable then
		return
	end
	local ok, result = pcall(function()
		return eventStore:GetAsync("current")
	end)
	if ok and typeof(result) == "table" then
		activeEvent = result
	end
end

loadFromStore()

task.spawn(function()
	while true do
		task.wait(GlobalEventConfig.RefreshInterval)
		loadFromStore()
	end
end)

-- Read by DragonHarvestManager (essence per hit) and AscensionBonusService (hatch rarity luck) -
-- a cheap in-memory check, never a live DataStore read, since both are called on hot gameplay
-- paths (every harvest hit / every egg hatch).
local function getMultiplier(eventType)
	if isExpired(activeEvent) or activeEvent.type ~= eventType then
		return 1
	end
	return math.max(1, tonumber(activeEvent.multiplier) or 1)
end

local function getState()
	if isExpired(activeEvent) then
		return nil
	end
	return activeEvent
end

-- Registered functions here return a single message string (never a (bool, message) tuple) - the
-- same convention every other AdminBridge-registered domain in this codebase uses, since
-- AdminBridge.call's own "return true, method(...)" already expands a multi-value method result
-- into extra positional returns, silently breaking a caller that only captures 2 values.
local function startEvent(player, eventType, multiplier, durationHours, label)
	if not AdminConfig.IsAdmin(player) then
		return "Not authorized"
	end
	local typeInfo = GlobalEventConfig.Types[eventType]
	if not typeInfo then
		return "Unknown event type"
	end
	local numMultiplier = math.clamp(tonumber(multiplier) or 1, 1, 20)
	local numHours = math.clamp(tonumber(durationHours) or 1, 0.1, 24 * 30)

	activeEvent = {
		type = eventType,
		multiplier = numMultiplier,
		endsAt = os.time() + math.floor(numHours * 3600),
		label = (typeof(label) == "string" and label ~= "") and label or typeInfo.Label,
	}

	if dataStoreAvailable then
		local ok, err = pcall(function()
			eventStore:SetAsync("current", activeEvent)
		end)
		if not ok then
			warn("[GlobalEventManager] Failed to save event state:", err)
		end
	end

	broadcastState()
	return string.format("%s started: x%.2f for %.1fh", typeInfo.Label, numMultiplier, numHours)
end

local function endEvent(player)
	if not AdminConfig.IsAdmin(player) then
		return "Not authorized"
	end
	activeEvent = nil
	if dataStoreAvailable then
		pcall(function()
			eventStore:SetAsync("current", nil)
		end)
	end
	broadcastState()
	return "Event ended"
end

-- getMultiplier is registered here too (not just start/stop/getState) so DragonHarvestManager and
-- AscensionBonusService can read it through the same AdminBridge.call(...) pattern already used
-- everywhere else in this codebase for cross-script calls - this is a .server.luau Script, not a
-- ModuleScript, so other scripts can't require() it directly.
AdminBridge.register("GlobalEvent", {
	start = startEvent,
	stop = endEvent,
	getState = function()
		return getState()
	end,
	-- No player argument here (unlike start/stop) - callers are other server scripts checking a
	-- gameplay multiplier, not a player-triggered admin action.
	getMultiplier = function(eventType)
		return getMultiplier(eventType)
	end,
})

RequestGlobalEventState.OnServerInvoke = function()
	return getState()
end

print("[GlobalEventManager] Global events ready")

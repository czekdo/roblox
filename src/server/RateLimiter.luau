local Players = game:GetService("Players")

-- Per-player, per-key cooldown gate for RemoteEvent handlers. A client-side
-- debounce only stops a normal client; an exploiter firing the remote directly
-- bypasses it, so state-mutating handlers (currency/items/DataStore writes)
-- gate here on the server too.
local RateLimiter = {}

local lastCallByPlayer = {}

-- Returns true if the call is allowed (and records it), false if still on cooldown.
function RateLimiter.check(player, key, minInterval)
	local now = os.clock()
	local playerTimes = lastCallByPlayer[player]
	if not playerTimes then
		playerTimes = {}
		lastCallByPlayer[player] = playerTimes
	end
	local last = playerTimes[key]
	if last and (now - last) < minInterval then
		return false
	end
	playerTimes[key] = now
	return true
end

Players.PlayerRemoving:Connect(function(player)
	lastCallByPlayer[player] = nil
end)

return RateLimiter

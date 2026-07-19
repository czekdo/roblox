local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

local TradeEvents = ReplicatedStorage:WaitForChild("TradeEvents")
local RequestServerPlayers = TradeEvents:WaitForChild("RequestServerPlayers")
local RequestTradeableDragons = TradeEvents:WaitForChild("RequestTradeableDragons")
local RequestTrade = TradeEvents:WaitForChild("RequestTrade")
local RespondToTradeRequest = TradeEvents:WaitForChild("RespondToTradeRequest")
local UpdateOffer = TradeEvents:WaitForChild("UpdateOffer")
local ConfirmOffer = TradeEvents:WaitForChild("ConfirmOffer")
local CancelTrade = TradeEvents:WaitForChild("CancelTrade")
local TradeUpdate = TradeEvents:WaitForChild("TradeUpdate")

local MAX_DRAGONS_PER_OFFER = 10

-- [targetPlayer] = requestingPlayer. Only one incoming request per player at a time.
local pendingRequests = {}
-- [player] = session (both players in a session point at the SAME table).
local sessionByPlayer = {}

local function emptyOffer()
	return { Essence = 0, Gems = 0, DragonIds = {} }
end

local function setConfirmed(session, player, value)
	if session.PlayerA == player then
		session.ConfirmedA = value
	else
		session.ConfirmedB = value
	end
end

-- Enriches an offer's DragonIds (owner's own storage ids) into display info for the UI. Used for
-- both the owner's own side (to render their picks) and the opponent's side (to see what's offered).
local function enrichOffer(owner, offer)
	local dragons = {}
	for _, id in offer.DragonIds do
		local ok, snapshot = AdminBridge.call("Trading", "getStorageDragonSnapshot", owner, id)
		if ok and snapshot then
			table.insert(dragons, {
				Id = id,
				DragonType = snapshot.dragonType,
				Rarity = snapshot.rarity,
				Level = snapshot.level,
				EvolutionLevel = snapshot.evolutionLevel,
			})
		end
	end
	return { Essence = offer.Essence, Gems = offer.Gems, Dragons = dragons }
end

local function broadcastState(session)
	local playerA, playerB = session.PlayerA, session.PlayerB
	if playerA.Parent then
		TradeUpdate:FireClient(playerA, {
			type = "StateChanged",
			myOffer = enrichOffer(playerA, session.OfferA),
			theirOffer = enrichOffer(playerB, session.OfferB),
			myConfirmed = session.ConfirmedA,
			theirConfirmed = session.ConfirmedB,
		})
	end
	if playerB.Parent then
		TradeUpdate:FireClient(playerB, {
			type = "StateChanged",
			myOffer = enrichOffer(playerB, session.OfferB),
			theirOffer = enrichOffer(playerA, session.OfferA),
			myConfirmed = session.ConfirmedB,
			theirConfirmed = session.ConfirmedA,
		})
	end
end

local function endSession(session, reason)
	sessionByPlayer[session.PlayerA] = nil
	sessionByPlayer[session.PlayerB] = nil
	if session.PlayerA.Parent then
		TradeUpdate:FireClient(session.PlayerA, { type = "Cancelled", reason = reason })
	end
	if session.PlayerB.Parent then
		TradeUpdate:FireClient(session.PlayerB, { type = "Cancelled", reason = reason })
	end
end

-- Re-validates and executes the trade atomically: everything is checked first, and only mutated
-- once every check has passed, so a stale/invalidated offer never results in a partial trade.
local function executeTrade(session)
	local playerA, playerB = session.PlayerA, session.PlayerB
	if not playerA.Parent or not playerB.Parent then
		endSession(session, "A player left before the trade completed.")
		return
	end

	local essenceA = playerA:GetAttribute("DragonEssence") or 0
	local gemsA = playerA:GetAttribute("PremiumGems") or 0
	local essenceB = playerB:GetAttribute("DragonEssence") or 0
	local gemsB = playerB:GetAttribute("PremiumGems") or 0

	if session.OfferA.Essence > essenceA or session.OfferA.Gems > gemsA then
		endSession(session, playerA.DisplayName .. " no longer has enough offered currency.")
		return
	end
	if session.OfferB.Essence > essenceB or session.OfferB.Gems > gemsB then
		endSession(session, playerB.DisplayName .. " no longer has enough offered currency.")
		return
	end

	local snapshotsA, snapshotsB = {}, {}
	for _, id in session.OfferA.DragonIds do
		local ok, snapshot = AdminBridge.call("Trading", "getStorageDragonSnapshot", playerA, id)
		if not ok or not snapshot then
			endSession(session, "One of " .. playerA.DisplayName .. "'s offered dragons is no longer available.")
			return
		end
		table.insert(snapshotsA, { id = id, snapshot = snapshot })
	end
	for _, id in session.OfferB.DragonIds do
		local ok, snapshot = AdminBridge.call("Trading", "getStorageDragonSnapshot", playerB, id)
		if not ok or not snapshot then
			endSession(session, "One of " .. playerB.DisplayName .. "'s offered dragons is no longer available.")
			return
		end
		table.insert(snapshotsB, { id = id, snapshot = snapshot })
	end

	local _, canReceiveA = AdminBridge.call("Trading", "canReceiveDragonCount", playerA, #snapshotsB)
	local _, canReceiveB = AdminBridge.call("Trading", "canReceiveDragonCount", playerB, #snapshotsA)
	if not canReceiveA then
		endSession(session, playerA.DisplayName .. " doesn't have enough dragon storage space.")
		return
	end
	if not canReceiveB then
		endSession(session, playerB.DisplayName .. " doesn't have enough dragon storage space.")
		return
	end

	playerA:SetAttribute("DragonEssence", essenceA - session.OfferA.Essence + session.OfferB.Essence)
	playerA:SetAttribute("PremiumGems", gemsA - session.OfferA.Gems + session.OfferB.Gems)
	playerB:SetAttribute("DragonEssence", essenceB - session.OfferB.Essence + session.OfferA.Essence)
	playerB:SetAttribute("PremiumGems", gemsB - session.OfferB.Gems + session.OfferA.Gems)

	for _, entry in snapshotsA do
		AdminBridge.call("Trading", "removeStorageDragon", playerA, entry.id)
		AdminBridge.call("Trading", "grantStorageDragon", playerB, entry.snapshot)
	end
	for _, entry in snapshotsB do
		AdminBridge.call("Trading", "removeStorageDragon", playerB, entry.id)
		AdminBridge.call("Trading", "grantStorageDragon", playerA, entry.snapshot)
	end

	sessionByPlayer[playerA] = nil
	sessionByPlayer[playerB] = nil
	TradeUpdate:FireClient(playerA, { type = "Completed" })
	TradeUpdate:FireClient(playerB, { type = "Completed" })
end

RequestServerPlayers.OnServerInvoke = function(player)
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			table.insert(list, { UserId = other.UserId, DisplayName = other.DisplayName })
		end
	end
	return list
end

RequestTradeableDragons.OnServerInvoke = function(player)
	local ok, list = AdminBridge.call("Trading", "listStorageDragons", player)
	if ok then
		return list
	end
	return {}
end

RequestTrade.OnServerEvent:Connect(function(player, targetUserId)
	if sessionByPlayer[player] then
		return
	end
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or -1)
	if not target or target == player then
		return
	end
	if sessionByPlayer[target] then
		TradeUpdate:FireClient(player, { type = "Error", message = target.DisplayName .. " is already trading." })
		return
	end
	if pendingRequests[target] then
		TradeUpdate:FireClient(player, { type = "Error", message = target.DisplayName .. " already has a pending request." })
		return
	end
	pendingRequests[target] = player
	TradeUpdate:FireClient(target, { type = "Request", fromUserId = player.UserId, fromName = player.DisplayName })
	TradeUpdate:FireClient(player, { type = "RequestSent", toName = target.DisplayName })
end)

RespondToTradeRequest.OnServerEvent:Connect(function(player, accept)
	local requester = pendingRequests[player]
	if not requester then
		return
	end
	pendingRequests[player] = nil
	if not requester.Parent then
		return
	end
	if accept ~= true then
		TradeUpdate:FireClient(requester, { type = "Declined", byName = player.DisplayName })
		return
	end
	if sessionByPlayer[player] or sessionByPlayer[requester] then
		TradeUpdate:FireClient(requester, { type = "Error", message = "Trade could not start." })
		return
	end

	local session = {
		PlayerA = requester,
		PlayerB = player,
		OfferA = emptyOffer(),
		OfferB = emptyOffer(),
		ConfirmedA = false,
		ConfirmedB = false,
	}
	sessionByPlayer[requester] = session
	sessionByPlayer[player] = session
	TradeUpdate:FireClient(requester, { type = "SessionStarted", opponentUserId = player.UserId, opponentName = player.DisplayName })
	TradeUpdate:FireClient(player, { type = "SessionStarted", opponentUserId = requester.UserId, opponentName = requester.DisplayName })
	broadcastState(session)
end)

UpdateOffer.OnServerEvent:Connect(function(player, payload)
	local session = sessionByPlayer[player]
	if not session or typeof(payload) ~= "table" then
		return
	end

	local essence = math.clamp(math.floor(tonumber(payload.Essence) or 0), 0, player:GetAttribute("DragonEssence") or 0)
	local gems = math.clamp(math.floor(tonumber(payload.Gems) or 0), 0, player:GetAttribute("PremiumGems") or 0)

	local dragonIds = {}
	if typeof(payload.DragonIds) == "table" then
		local seen = {}
		for _, id in payload.DragonIds do
			local numId = tonumber(id)
			if numId and not seen[numId] and #dragonIds < MAX_DRAGONS_PER_OFFER then
				local ok, snapshot = AdminBridge.call("Trading", "getStorageDragonSnapshot", player, numId)
				if ok and snapshot then
					seen[numId] = true
					table.insert(dragonIds, numId)
				end
			end
		end
	end

	local offer = { Essence = essence, Gems = gems, DragonIds = dragonIds }
	if session.PlayerA == player then
		session.OfferA = offer
	else
		session.OfferB = offer
	end
	-- Any offer change invalidates both sides' prior confirmation - prevents a bait-and-switch
	-- where one side confirms, then the other swaps in a worse offer before the trade executes.
	session.ConfirmedA = false
	session.ConfirmedB = false
	broadcastState(session)
end)

ConfirmOffer.OnServerEvent:Connect(function(player)
	local session = sessionByPlayer[player]
	if not session then
		return
	end
	setConfirmed(session, player, true)
	broadcastState(session)
	if session.ConfirmedA and session.ConfirmedB then
		executeTrade(session)
	end
end)

CancelTrade.OnServerEvent:Connect(function(player)
	local session = sessionByPlayer[player]
	if not session then
		return
	end
	endSession(session, (player.DisplayName or "A player") .. " cancelled the trade.")
end)

Players.PlayerRemoving:Connect(function(player)
	pendingRequests[player] = nil
	for target, requester in pendingRequests do
		if requester == player then
			pendingRequests[target] = nil
		end
	end
	local session = sessionByPlayer[player]
	if session then
		endSession(session, (player.DisplayName or "The other player") .. " left the game.")
	end
end)

print("[TradingService] Trading ready")

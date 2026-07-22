local DragonAbilityEffects = {}

local ServerScriptService = game:GetService("ServerScriptService")
local AscensionBonusService = require(ServerScriptService:WaitForChild("AscensionBonusService"))

local resonanceEssenceByNode = setmetatable({}, { __mode = "k" })

local function getDragonState(dragon)
	if typeof(dragon) ~= "table" then
		return {}
	end
	if typeof(dragon.abilityState) ~= "table" then
		dragon.abilityState = {}
	end
	return dragon.abilityState
end

local function syncDragonAttributes(dragon, state)
	local model = typeof(dragon) == "table" and dragon.model
	if not model then
		return
	end
	model:SetAttribute("AbilityChainHits", state.chainHits or 0)
	model:SetAttribute("AbilityChainRequired", state.chainRequired or 0)
	model:SetAttribute("AbilityHeat", state.heat or 0)
	model:SetAttribute("AbilityHeatMax", state.heatMax or 0)
	model:SetAttribute("AbilityTide", state.tide or 0)
end

local function clearNodeAbilityState(node)
	if not node then
		return
	end
	node:SetAttribute("BrittleStacks", nil)
	node:SetAttribute("BrittleOwnerDragonId", nil)
	node:SetAttribute("Poisoned", nil)
	node:SetAttribute("PoisonOwnerDragonId", nil)
	resonanceEssenceByNode[node] = nil
end

local function getBrittleStacks(node, dragonId)
	if not node or not node.Parent then
		return 0
	end
	local ownerId = node:GetAttribute("BrittleOwnerDragonId")
	if ownerId ~= dragonId then
		return 0
	end
	return math.max(0, math.floor(tonumber(node:GetAttribute("BrittleStacks")) or 0))
end

local function setBrittleStacks(node, dragonId, stacks)
	if not node or not node.Parent then
		return
	end
	node:SetAttribute("BrittleOwnerDragonId", dragonId)
	node:SetAttribute("BrittleStacks", stacks)
end

local function isNodePoisonedByDragon(node, dragonId)
	if not node or not node.Parent then
		return false
	end
	if node:GetAttribute("Poisoned") ~= true then
		return false
	end
	return node:GetAttribute("PoisonOwnerDragonId") == dragonId
end

local function setNodePoisoned(node, dragonId)
	if not node or not node.Parent then
		return
	end
	node:SetAttribute("Poisoned", true)
	node:SetAttribute("PoisonOwnerDragonId", dragonId)
end

local function essenceFromPercent(harvestAmount, percent)
	return math.max(0, math.floor(harvestAmount * (percent or 0) + 0.5))
end

local Handlers = {}

function Handlers.Inferno(_player, _dragon, _node, hitData, params)
	local bonusEssence = 0
	if hitData.isCritical then
		bonusEssence = essenceFromPercent(hitData.harvestAmount, params.CritBonusPercent)
	end
	return {
		bonusEssence = bonusEssence,
		vfxTag = bonusEssence > 0 and "Inferno" or nil,
	}
end

function Handlers.ChainLightning(_player, dragon, _node, hitData, params)
	local state = getDragonState(dragon)
	local hitsPerChain = math.max(1, math.floor(tonumber(params.HitsPerChain) or 5))
	state.chainRequired = hitsPerChain
	state.chainHits = (state.chainHits or 0) + 1

	local bonusEssence = 0
	local vfxTag = nil
	if state.chainHits >= hitsPerChain then
		state.chainHits = 0
		bonusEssence = essenceFromPercent(hitData.harvestAmount, params.ChainEssencePercent)
		vfxTag = "ChainLightning"
	end

	syncDragonAttributes(dragon, state)
	return {
		bonusEssence = bonusEssence,
		vfxTag = vfxTag,
	}
end

function Handlers.NaturesBlessing(_player, _dragon, _node, hitData, params)
	local procChance = math.clamp(tonumber(params.ProcChance) or 0, 0, 1)
	if math.random() >= procChance then
		return {}
	end
	local bonusEssence = essenceFromPercent(hitData.harvestAmount, params.BloomPercent)
	if bonusEssence <= 0 then
		return {}
	end
	return {
		bonusEssence = bonusEssence,
		vfxTag = "NaturesBlessing",
	}
end

function Handlers.RoyalBlessing(_player, _dragon, _node, hitData, params)
	local procChance = math.clamp(tonumber(params.ProcChance) or 0, 0, 1)
	if math.random() >= procChance then
		return {}
	end
	local bonusEssence = essenceFromPercent(hitData.harvestAmount, params.FavorPercent)
	if bonusEssence <= 0 then
		return {}
	end
	return {
		bonusEssence = bonusEssence,
		vfxTag = "RoyalBlessing",
	}
end

function Handlers.VoidRift(_player, _dragon, _node, hitData, params)
	local procChance = math.clamp(tonumber(params.ProcChance) or 0, 0, 1)
	if math.random() >= procChance then
		return {}
	end
	local bonusEssence = essenceFromPercent(hitData.harvestAmount, params.RiftPercent)
	if bonusEssence <= 0 then
		return {}
	end
	return {
		bonusEssence = bonusEssence,
		vfxTag = "VoidRift",
	}
end

function Handlers.Starfall(_player, _dragon, _node, hitData, params)
	local procChance = math.clamp(tonumber(params.ProcChance) or 0, 0, 1)
	if math.random() >= procChance then
		return {}
	end
	local bonusEssence = essenceFromPercent(hitData.harvestAmount, params.StarfallPercent)
	if bonusEssence <= 0 then
		return {}
	end
	return {
		bonusEssence = bonusEssence,
		vfxTag = "Starfall",
	}
end

function Handlers.CrystalMaster(_player, dragon, node, _hitData, _params)
	-- Resonance is paid on node depletion; hits only accumulate tracked essence.
	return {
		bonusEssence = 0,
		vfxTag = nil,
		trackResonance = true,
	}
end

function Handlers.FrozenTouch(_player, dragon, node, hitData, params)
	local maxStacks = math.max(1, math.floor(params.MaxStacks or 3))
	local stacks = getBrittleStacks(node, dragon.id)
	local nextStacks = math.min(maxStacks, stacks + 1)
	setBrittleStacks(node, dragon.id, nextStacks)

	local bonusEssence = essenceFromPercent(hitData.harvestAmount, nextStacks * (params.EssencePerStack or 0.03))
	return {
		bonusEssence = bonusEssence,
		vfxTag = bonusEssence > 0 and "FrozenTouch" or nil,
	}
end

function Handlers.Corrosion(_player, dragon, node, hitData, params)
	local bonusEssence = 0
	if isNodePoisonedByDragon(node, dragon.id) then
		bonusEssence = essenceFromPercent(hitData.harvestAmount, params.PoisonEssencePercent)
	else
		setNodePoisoned(node, dragon.id)
		bonusEssence = essenceFromPercent(hitData.harvestAmount, params.PoisonEssencePercent)
	end
	return {
		bonusEssence = bonusEssence,
		vfxTag = bonusEssence > 0 and "Corrosion" or nil,
	}
end

function Handlers.MoltenCore(_player, dragon, _node, hitData, params)
	local state = getDragonState(dragon)
	local maxHeat = math.max(1, math.floor(tonumber(params.MaxHeat) or 3))
	state.heatMax = maxHeat
	state.heat = math.min(maxHeat, (state.heat or 0) + 1)

	local bonusEssence = essenceFromPercent(hitData.harvestAmount, state.heat * (params.HeatEssencePercent or 0.02))
	syncDragonAttributes(dragon, state)
	return {
		bonusEssence = bonusEssence,
		vfxTag = bonusEssence > 0 and "MoltenCore" or nil,
	}
end

function Handlers.OceanBlessing(_player, dragon, _node, hitData, params)
	local state = getDragonState(dragon)
	local tideRise = math.max(1, math.floor(tonumber(params.TideRisePerHit) or 20))
	state.tide = math.min(100, (state.tide or 0) + tideRise)

	local bonusEssence = 0
	local vfxTag = nil
	if state.tide >= 100 then
		state.tide = 0
		bonusEssence = essenceFromPercent(hitData.harvestAmount, params.SurgeEssencePercent)
		vfxTag = "OceanBlessing"
	end

	syncDragonAttributes(dragon, state)
	return {
		bonusEssence = bonusEssence,
		vfxTag = vfxTag,
	}
end

function DragonAbilityEffects.RecordNodeEssence(node, dragonId, essenceAmount)
	if not node or not dragonId or essenceAmount <= 0 then
		return
	end
	local byDragon = resonanceEssenceByNode[node]
	if not byDragon then
		byDragon = {}
		resonanceEssenceByNode[node] = byDragon
	end
	byDragon[dragonId] = (byDragon[dragonId] or 0) + essenceAmount
end

function DragonAbilityEffects.ResolveNodeDepletion(player, dragon, node, params, handlerId)
	if handlerId ~= "CrystalMaster" or not node then
		return {}
	end

	local byDragon = resonanceEssenceByNode[node]
	local earned = byDragon and byDragon[dragon.id] or 0
	local bonusEssence = essenceFromPercent(earned, params.ResonancePercent)
	if bonusEssence <= 0 then
		return {}
	end

	return {
		bonusEssence = bonusEssence,
		vfxTag = "CrystalMaster",
	}
end

function DragonAbilityEffects.GetHandler(handlerId)
	return Handlers[handlerId]
end

function DragonAbilityEffects.ClearNodeState(node)
	clearNodeAbilityState(node)
end

function DragonAbilityEffects.ApplyHandler(handlerId, player, dragon, node, hitData, params)
	local handler = Handlers[handlerId]
	if not handler then
		return {}
	end
	local adjustedParams = AscensionBonusService.ApplyAbilityLevelParams(player, handlerId, params)
	return handler(player, dragon, node, hitData, adjustedParams)
end

return DragonAbilityEffects

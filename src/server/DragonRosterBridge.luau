local DragonRosterBridge = {}

local implementation = nil

function DragonRosterBridge.register(impl)
	implementation = impl
end

local function requireImpl(methodName)
	if not implementation or typeof(implementation[methodName]) ~= "function" then
		return nil
	end
	return implementation[methodName]
end

function DragonRosterBridge.getRoster(player)
	local method = requireImpl("getRoster")
	return method and method(player) or {}
end

function DragonRosterBridge.getAcademyMultipliers(player)
	local method = requireImpl("getAcademyMultipliers")
	return method and method(player) or { TrainingTimeMultiplier = 1, XpGainMultiplier = 1 }
end

function DragonRosterBridge.getAcademyPosition(player)
	local method = requireImpl("getAcademyPosition")
	return method and method(player) or nil
end

function DragonRosterBridge.setDragonTraining(player, dragonId, isTraining, anchorPosition)
	local method = requireImpl("setDragonTraining")
	if method then
		return method(player, dragonId, isTraining, anchorPosition)
	end
	return false
end

function DragonRosterBridge.applyTrainingRewards(player, dragonId, levelReward, essenceReward)
	local method = requireImpl("applyTrainingRewards")
	if method then
		return method(player, dragonId, levelReward, essenceReward)
	end
	return false
end

function DragonRosterBridge.isDragonBusy(player, dragonId)
	local method = requireImpl("isDragonBusy")
	if method then
		return method(player, dragonId) == true
	end
	return true
end

return DragonRosterBridge
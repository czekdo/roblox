local ServerScriptService = game:GetService("ServerScriptService")

local RebirthDomainBridge = require(ServerScriptService:WaitForChild("RebirthDomainBridge"))
local RebirthAdapterRegistry = require(ServerScriptService:WaitForChild("RebirthAdapterRegistry"))

local DOMAIN_ID = "Training"

local function callDomain(methodName, ...)
	local ok, result = RebirthDomainBridge.Call(DOMAIN_ID, methodName, ...)
	if not ok then
		return nil
	end
	return result
end

RebirthAdapterRegistry.Register({
	id = "Training",
	priority = 25,
	getSnapshotPatch = function(player)
		return callDomain("getSnapshotPatch", player)
	end,
	canReset = function(player, context)
		local result = callDomain("canReset", player, context)
		if typeof(result) == "table" then
			return result
		end
		return { ok = true }
	end,
	resetRunState = function(player, context)
		local result = callDomain("resetRunState", player, context)
		if typeof(result) == "table" then
			return result
		end
		return { success = result ~= false }
	end,
	restorePermanentState = function(player, context)
		local result = callDomain("restorePermanentState", player, context)
		if typeof(result) == "table" then
			return result
		end
		return { success = result ~= false }
	end,
})

return {}

local ServerScriptService = game:GetService("ServerScriptService")

local RebirthDomainBridge = require(ServerScriptService:WaitForChild("RebirthDomainBridge"))
local RebirthAdapterRegistry = require(ServerScriptService:WaitForChild("RebirthAdapterRegistry"))

local BUILDING_DOMAIN = "Buildings"
local KINGDOM_DOMAIN = "Kingdom"

local function callDomain(domainId, methodName, ...)
	local ok, result = RebirthDomainBridge.Call(domainId, methodName, ...)
	if not ok then
		return nil
	end
	return result
end

RebirthAdapterRegistry.Register({
	id = "Building",
	priority = 20,
	getSnapshotPatch = function(player)
		local patch = callDomain(BUILDING_DOMAIN, "getSnapshotPatch", player) or {}
		local kingdomPatch = callDomain(KINGDOM_DOMAIN, "getSnapshotPatch", player)
		if typeof(kingdomPatch) == "table" then
			for key, value in kingdomPatch do
				patch[key] = value
			end
		end
		return patch
	end,
	canReset = function(player, context)
		for _, domainId in { BUILDING_DOMAIN, KINGDOM_DOMAIN } do
			local result = callDomain(domainId, "canReset", player, context)
			if typeof(result) == "table" and result.ok == false then
				return result
			end
		end
		return { ok = true }
	end,
	resetRunState = function(player, context)
		local buildingResult = callDomain(BUILDING_DOMAIN, "resetRunState", player, context)
		local kingdomResult = callDomain(KINGDOM_DOMAIN, "resetRunState", player, context)
		local buildingOk = typeof(buildingResult) ~= "table" or buildingResult.success ~= false
		local kingdomOk = typeof(kingdomResult) ~= "table" or kingdomResult.success ~= false
		return {
			success = buildingOk and kingdomOk,
			message = (not buildingOk and buildingResult and buildingResult.message)
				or (not kingdomOk and kingdomResult and kingdomResult.message)
				or nil,
		}
	end,
	restorePermanentState = function(player, context)
		local buildingResult = callDomain(BUILDING_DOMAIN, "restorePermanentState", player, context)
		local kingdomResult = callDomain(KINGDOM_DOMAIN, "restorePermanentState", player, context)
		local buildingOk = typeof(buildingResult) ~= "table" or buildingResult.success ~= false
		local kingdomOk = typeof(kingdomResult) ~= "table" or kingdomResult.success ~= false
		return {
			success = buildingOk and kingdomOk,
			message = (not buildingOk and buildingResult and buildingResult.message)
				or (not kingdomOk and kingdomResult and kingdomResult.message)
				or nil,
		}
	end,
})

return {}

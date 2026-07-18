local RebirthDomainBridge = {}

local domains = {}

function RebirthDomainBridge.Register(domainId, implementation)
	if typeof(domainId) ~= "string" or typeof(implementation) ~= "table" then
		return false
	end
	domains[domainId] = implementation
	return true
end

function RebirthDomainBridge.Unregister(domainId)
	if typeof(domainId) ~= "string" then
		return false
	end
	domains[domainId] = nil
	return true
end

function RebirthDomainBridge.Has(domainId, methodName)
	local implementation = domains[domainId]
	return implementation ~= nil and typeof(implementation[methodName]) == "function"
end

function RebirthDomainBridge.Call(domainId, methodName, ...)
	local implementation = domains[domainId]
	if not implementation then
		return false, nil
	end
	local method = implementation[methodName]
	if typeof(method) ~= "function" then
		return false, nil
	end
	return true, method(...)
end

return RebirthDomainBridge

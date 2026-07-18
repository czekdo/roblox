local AdminBridge = {}

local handlers = {}

function AdminBridge.register(domain, impl)
	if typeof(domain) ~= "string" or typeof(impl) ~= "table" then
		return
	end
	handlers[domain] = impl
end

function AdminBridge.call(domain, methodName, ...)
	local impl = handlers[domain]
	if not impl then
		return false, "System not ready: " .. tostring(domain)
	end
	local method = impl[methodName]
	if typeof(method) ~= "function" then
		return false, "Action unavailable: " .. tostring(methodName)
	end
	return true, method(...)
end

function AdminBridge.has(domain, methodName)
	local impl = handlers[domain]
	return impl and typeof(impl[methodName]) == "function"
end

return AdminBridge

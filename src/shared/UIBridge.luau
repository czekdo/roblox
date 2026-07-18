local UIBridge = {}

-- ============================================================
-- Generic broadcast (Subscribe/Fire) — for state that many
-- independent scripts need to react to, with no single owner.
-- ============================================================

local listeners = {}

-- Returns an unsubscribe function.
function UIBridge.Subscribe(eventName, fn)
	if typeof(eventName) ~= "string" or typeof(fn) ~= "function" then
		return function() end
	end
	local list = listeners[eventName]
	if not list then
		list = {}
		listeners[eventName] = list
	end
	table.insert(list, fn)

	local active = true
	return function()
		if not active then
			return
		end
		active = false
		for index, existing in list do
			if existing == fn then
				table.remove(list, index)
				break
			end
		end
	end
end

-- Fires synchronously, in subscribe order. A subscriber error is warned
-- and does not stop the remaining subscribers from running.
function UIBridge.Fire(eventName, ...)
	local list = listeners[eventName]
	if not list then
		return
	end
	for _, fn in table.clone(list) do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[UIBridge] Subscriber error for", eventName, err)
		end
	end
end

-- ============================================================
-- Modal registry — which top-level GUIs are currently open.
-- Single source of truth; DragonUIUXController owns the side
-- effects (nav lock, Theme.setModalLock, tutorial suppression)
-- by subscribing to "ModalLockChanged" instead of keeping its
-- own copy of this table.
-- ============================================================

local openModalNames = {}

local function getModalCount()
	local count = 0
	for _ in openModalNames do
		count += 1
	end
	return count
end

local function broadcastModalLockChanged()
	local names = {}
	for name in openModalNames do
		table.insert(names, name)
	end
	UIBridge.Fire("ModalLockChanged", #names > 0, names)
end

function UIBridge.NotifyModalOpened(guiName)
	if typeof(guiName) ~= "string" or guiName == "" then
		return
	end
	openModalNames[guiName] = true
	broadcastModalLockChanged()
end

function UIBridge.NotifyModalClosed(guiName)
	if typeof(guiName) == "string" then
		openModalNames[guiName] = nil
	end
	broadcastModalLockChanged()
end

function UIBridge.IsModalOpen()
	return getModalCount() > 0
end

function UIBridge.GetOpenModalNames()
	local names = {}
	for name in openModalNames do
		table.insert(names, name)
	end
	return names
end

function UIBridge.ResetModalRegistry()
	table.clear(openModalNames)
	broadcastModalLockChanged()
end

return UIBridge

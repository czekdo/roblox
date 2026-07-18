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

-- ============================================================
-- Panel registry — one owner per panel id. Replaces the old
-- pattern of every caller looking up _G.DragonIslandOpenX /
-- _G.DragonIslandCloseX (or, worse, _G[stringVariable]) by name.
-- ============================================================

local panels = {}

function UIBridge.RegisterPanel(id, handlers)
	if typeof(id) ~= "string" or id == "" or typeof(handlers) ~= "table" then
		return
	end
	panels[id] = handlers
end

function UIBridge.IsPanelRegistered(id)
	return panels[id] ~= nil
end

function UIBridge.OpenPanel(id, ...)
	local handlers = panels[id]
	if not handlers or typeof(handlers.Open) ~= "function" then
		return false
	end
	handlers.Open(...)
	return true
end

function UIBridge.ClosePanel(id)
	local handlers = panels[id]
	if not handlers or typeof(handlers.Close) ~= "function" then
		return false
	end
	handlers.Close()
	return true
end

-- Closes every registered panel that has a Close handler. A panel with a
-- broken closer does not stop the rest from closing.
function UIBridge.CloseAllPanels()
	for _, handlers in panels do
		if typeof(handlers.Close) == "function" then
			local ok, err = pcall(handlers.Close)
			if not ok then
				warn("[UIBridge] CloseAllPanels: a panel closer errored:", err)
			end
		end
	end
end

-- ============================================================
-- Named broadcast helpers — thin, discoverable wrappers over
-- Subscribe/Fire so callers don't need to know/guess a magic event
-- name string. The owning script (TutorialController for the first
-- two, HarvestClient for the third) is expected to Subscribe.
-- ============================================================

function UIBridge.SetTutorialSuppressed(value)
	UIBridge.Fire("TutorialSuppressedChanged", value == true)
end

function UIBridge.SetWorldPanelsSuppressed(value)
	UIBridge.Fire("WorldPanelsSuppressedChanged", value == true)
end

function UIBridge.Notify(message, color)
	UIBridge.Fire("Notify", message, color)
end

-- ============================================================
-- Commands — single-owner function slots for direct request/response
-- calls where the caller needs the callee's actual return value
-- (unlike Subscribe/Fire, which is fire-and-forget to every listener
-- and doesn't collect results).
-- ============================================================

local commands = {}

function UIBridge.RegisterCommand(name, fn)
	if typeof(name) == "string" and name ~= "" and typeof(fn) == "function" then
		commands[name] = fn
	end
end

function UIBridge.RunCommand(name, ...)
	local fn = commands[name]
	if not fn then
		return nil
	end
	return fn(...)
end

return UIBridge

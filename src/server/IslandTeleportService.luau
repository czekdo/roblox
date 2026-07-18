local IslandTeleportService = {}

local handlers = nil

function IslandTeleportService.Register(newHandlers)
	handlers = newHandlers
end

function IslandTeleportService.IsReady()
	return handlers ~= nil
end

function IslandTeleportService.IsUnlocked(player, islandId)
	if not handlers or not handlers.isUnlocked then
		return false
	end
	return handlers.isUnlocked(player, islandId)
end

function IslandTeleportService.TeleportToHub(player)
	if handlers and handlers.teleportToHub then
		handlers.teleportToHub(player)
	end
end

function IslandTeleportService.TeleportToIsland(player, islandId, force)
	if handlers and handlers.teleportToIsland then
		handlers.teleportToIsland(player, islandId, force)
	end
end

return IslandTeleportService

local ServerScriptService = game:GetService("ServerScriptService")
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))
local TutorialService = require(ServerScriptService:WaitForChild("TutorialService"))

TutorialService.init()

AdminBridge.register("Tutorial", {
	complete = function(player)
		return TutorialService.adminComplete(player)
	end,
	reset = function(player)
		return TutorialService.adminReset(player)
	end,
	refreshState = function(player)
		TutorialService.sendState(player)
		return "Tutorial UI refreshed"
	end,
	save = function(player)
		TutorialService.savePlayer(player)
		return "Tutorial progress saved"
	end,
	wipe = function(player)
		return TutorialService.adminReset(player)
	end,
})

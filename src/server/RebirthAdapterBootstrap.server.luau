local ServerScriptService = game:GetService("ServerScriptService")

require(ServerScriptService:WaitForChild("RebirthIslandAdapter"))
require(ServerScriptService:WaitForChild("RebirthBuildingAdapter"))
require(ServerScriptService:WaitForChild("RebirthTrainingAdapter"))
require(ServerScriptService:WaitForChild("RebirthDragonAdapter"))

print("[RebirthAdapterBootstrap] Island, Building, Dragon, and Training adapters registered")

local RunService = game:GetService("RunService")

local PREVIEW_NAME = "EditorPreviewIsland"

local function destroyPreview()
	local existingPreview = workspace:FindFirstChild(PREVIEW_NAME)
	if existingPreview then
		existingPreview:Destroy()
	end
end

if RunService:IsRunning() then
	destroyPreview()
end

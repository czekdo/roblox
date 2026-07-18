local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EggOpeningCamera = {}
EggOpeningCamera.__index = EggOpeningCamera

local function tween(instance, info, goals)
	local tweenObj = TweenService:Create(instance, info, goals)
	tweenObj:Play()
	return tweenObj
end

function EggOpeningCamera.new(camera)
	local self = setmetatable({}, EggOpeningCamera)
	self.camera = camera
	self.savedState = nil
	self.connections = {}
	self.shakeOffset = Vector3.zero
	self.idleAlpha = 0
	return self
end

function EggOpeningCamera:_track(connection)
	table.insert(self.connections, connection)
	return connection
end

function EggOpeningCamera:Begin(targetPosition, profile)
	if self.savedState then
		return
	end

	self.savedState = {
		type = self.camera.CameraType,
		fov = self.camera.FieldOfView,
		cframe = self.camera.CFrame,
	}

	self.camera.CameraType = Enum.CameraType.Scriptable
	self.focusPosition = targetPosition
	self.profile = profile

	local startCFrame = self.camera.CFrame
	local startFov = self.camera.FieldOfView
	local focus = targetPosition + Vector3.new(0, 1.4, 0)
	local offset = (startCFrame.Position - focus)
	if offset.Magnitude < 4 then
		offset = Vector3.new(0, 2.5, 9)
	end
	self.baseCFrame = CFrame.lookAt(focus + offset.Unit * math.clamp(offset.Magnitude, 7, 14), focus)
	self.targetCFrame = CFrame.lookAt(focus + Vector3.new(0, 1.8, 7.5), focus)
	self.targetFov = math.clamp(startFov * (0.76 / (profile.zoomStrength or 1)), 30, 58)

	self.zoomAlpha = 0
	self:_track(RunService.RenderStepped:Connect(function(dt)
		self.idleAlpha += dt
		self.zoomAlpha = math.clamp(self.zoomAlpha + dt * 0.45, 0, 1)

		local idle = Vector3.new(
			math.sin(self.idleAlpha * 0.7) * 0.08,
			math.cos(self.idleAlpha * 0.55) * 0.05,
			math.sin(self.idleAlpha * 0.35) * 0.04
		)

		local base = self.baseCFrame:Lerp(self.targetCFrame, self.zoomAlpha)
		local fov = startFov + (self.targetFov - startFov) * self.zoomAlpha
		self.camera.CFrame = base * CFrame.new(idle + self.shakeOffset)
		self.camera.FieldOfView = fov
	end))
end

function EggOpeningCamera:SetZoomStrength(multiplier)
	self.zoomAlpha = math.clamp(multiplier or 1, 0, 1)
end

function EggOpeningCamera:Shake(intensity, duration)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		if elapsed >= duration then
			self.shakeOffset = Vector3.zero
			connection:Disconnect()
			return
		end
		local decay = 1 - (elapsed / duration)
		self.shakeOffset = Vector3.new(
			(math.random() - 0.5) * intensity * decay,
			(math.random() - 0.5) * intensity * 0.6 * decay,
			(math.random() - 0.5) * intensity * 0.35 * decay
		)
	end)
	self:_track(connection)
end

function EggOpeningCamera:End()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	self.shakeOffset = Vector3.zero

	if not self.savedState then
		return
	end

	tween(self.camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = self.savedState.fov,
		CFrame = self.savedState.cframe,
	})

	task.delay(0.42, function()
		if self.savedState then
			self.camera.CameraType = self.savedState.type
			self.camera.FieldOfView = self.savedState.fov
			self.camera.CFrame = self.savedState.cframe
			self.savedState = nil
		end
	end)
end

return EggOpeningCamera

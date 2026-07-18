local DragonBoneAnimator = {}

local function sortByDistanceFrom(bones, origin)
	table.sort(bones, function(a, b)
		local da = (a.TransformedWorldCFrame.Position - origin).Magnitude
		local db = (b.TransformedWorldCFrame.Position - origin).Magnitude
		return da < db
	end)
	return bones
end

local function classifyBones(rootPart, allBones)
	local meshCF = rootPart.CFrame
	local rel = table.create(#allBones)
	local minY, maxY = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge

	for index, bone in allBones do
		local pos = meshCF:PointToObjectSpace(bone.TransformedWorldCFrame.Position)
		rel[index] = { bone = bone, pos = pos }
		minY = math.min(minY, pos.Y)
		maxY = math.max(maxY, pos.Y)
		minZ = math.min(minZ, pos.Z)
		maxZ = math.max(maxZ, pos.Z)
	end

	local ySpan = math.max(maxY - minY, 0.01)
	local zSpan = math.max(maxZ - minZ, 0.01)
	local body, neck, head, wingRight, wingLeft, tail = {}, {}, {}, {}, {}, {}

	for _, entry in rel do
		local bone = entry.bone
		local pos = entry.pos
		local absX = math.abs(pos.X)

		if bone.Name == "Bone_000" or bone.Name == "Bone_001" then
			body[#body + 1] = bone
		elseif absX >= 0.1 then
			if pos.X > 0 then
				wingRight[#wingRight + 1] = bone
			else
				wingLeft[#wingLeft + 1] = bone
			end
		elseif pos.Y >= maxY - ySpan * 0.35 and absX < 0.12 then
			if pos.Y >= maxY - ySpan * 0.12 then
				head[#head + 1] = bone
			else
				neck[#neck + 1] = bone
			end
		elseif pos.Z >= maxZ - zSpan * 0.35 and absX < 0.12 then
			tail[#tail + 1] = bone
		elseif absX < 0.08 then
			body[#body + 1] = bone
		end
	end

	local origin = meshCF.Position
	sortByDistanceFrom(wingRight, origin)
	sortByDistanceFrom(wingLeft, origin)
	sortByDistanceFrom(tail, origin)

	table.sort(head, function(a, b)
		return meshCF:PointToObjectSpace(a.TransformedWorldCFrame.Position).Y
			> meshCF:PointToObjectSpace(b.TransformedWorldCFrame.Position).Y
	end)
	table.sort(neck, function(a, b)
		return meshCF:PointToObjectSpace(a.TransformedWorldCFrame.Position).Y
			> meshCF:PointToObjectSpace(b.TransformedWorldCFrame.Position).Y
	end)

	if #body == 0 and allBones[1] then
		body[1] = allBones[1]
	end
	if #head == 0 and #neck > 0 then
		head[1] = table.remove(neck, 1)
	end

	return body, neck, head, wingRight, wingLeft, tail
end

function DragonBoneAnimator.BuildCache(dragon)
	local rootPart = dragon:FindFirstChild("DragonRoot")
	if not rootPart then
		return nil
	end

	local allBones = {}
	for _, bone in dragon:GetDescendants() do
		if bone:IsA("Bone") then
			allBones[#allBones + 1] = bone
		end
	end

	if #allBones == 0 then
		return nil
	end

	local body, neck, head, wingRight, wingLeft, tail = classifyBones(rootPart, allBones)

	return {
		body = body,
		neck = neck,
		head = head,
		wingRight = wingRight,
		wingLeft = wingLeft,
		tail = tail,
		allBones = allBones,
		headTrackYaw = 0,
		headTrackPitch = 0,
		turnRoll = 0,
		prevFacing = Vector3.new(0, 0, -1),
	}
end

local function resetBones(cache)
	for _, bone in cache.allBones do
		bone.Transform = CFrame.new()
	end
end

local function applyWingFlap(bones, phase, amplitude, direction)
	for index, bone in bones do
		local chainFactor = 0.55 + index * 0.12
		local angle = math.sin(phase + index * 0.35) * amplitude * chainFactor * direction
		bone.Transform = CFrame.Angles(angle, 0, angle * 0.08)
	end
end

local function applyBreathing(bones, time, intensity)
	local breath = math.sin(time * 1.6) * intensity
	for index, bone in bones do
		local scale = 0.65 + index * 0.35
		bone.Transform = CFrame.Angles(breath * scale, 0, breath * 0.15 * scale)
	end
end

local function applyTailSway(bones, time, amplitude, speed)
	for index, bone in bones do
		local chain = index * 0.9
		local sway = math.sin(time * speed + chain) * amplitude * (0.7 + index * 0.35)
		local lift = math.sin(time * speed * 0.8 + chain * 0.5) * amplitude * 0.25
		bone.Transform = CFrame.Angles(lift, sway, sway * 0.35)
	end
end

local function applyHeadTracking(cache, targetWorldPos, dragonPivot, dt, maxYaw, maxPitch)
	local fade = 1 - math.clamp(dt * 6, 0, 1)
	if not targetWorldPos then
		cache.headTrackYaw *= fade
		cache.headTrackPitch *= fade
		return
	end

	local headBone = cache.head[1] or cache.neck[1]
	if not headBone then
		return
	end

	local toTarget = targetWorldPos - headBone.TransformedWorldCFrame.Position
	if toTarget.Magnitude < 0.05 then
		return
	end

	local localDir = dragonPivot:VectorToObjectSpace(toTarget.Unit)
	local desiredYaw = math.clamp(math.atan2(localDir.X, -localDir.Z), -maxYaw, maxYaw)
	local desiredPitch = math.clamp(math.asin(math.clamp(localDir.Y, -1, 1)), -maxPitch, maxPitch)

	local alpha = math.clamp(dt * 8, 0, 1)
	cache.headTrackYaw += (desiredYaw - cache.headTrackYaw) * alpha
	cache.headTrackPitch += (desiredPitch - cache.headTrackPitch) * alpha

	local yawSplit = cache.headTrackYaw
	local pitchSplit = cache.headTrackPitch
	local neckCount = #cache.neck
	local headCount = #cache.head

	for index, bone in cache.neck do
		local weight = (neckCount - index + 1) / math.max(neckCount, 1)
		bone.Transform = CFrame.Angles(pitchSplit * 0.25 * weight, yawSplit * 0.35 * weight, 0)
	end
	for index, bone in cache.head do
		local weight = (headCount - index + 1) / math.max(headCount, 1)
		bone.Transform = CFrame.Angles(pitchSplit * 0.45 * weight, yawSplit * 0.55 * weight, 0)
	end
end

function DragonBoneAnimator.Animate(cache, params)
	if not cache then
		return
	end

	resetBones(cache)

	local state = params.state
	local time = params.time
	local dt = params.dt
	local isMoving = state == "moving"
	local isHarvesting = state == "harvesting"
	local isActive = isMoving or isHarvesting

	local flapSpeed = if isHarvesting then 9.5 elseif isMoving then 5.8 else 2.2
	local flapAmp = if isHarvesting then 0.55 elseif isMoving then 0.42 else 0.14
	local phase = time * flapSpeed

	applyBreathing(cache.body, time, if isActive then 0.018 else 0.035)
	applyWingFlap(cache.wingRight, phase, flapAmp, 1)
	applyWingFlap(cache.wingLeft, phase + math.pi, flapAmp, -1)

	local tailAmp = if isActive then 0.12 else 0.08
	local tailSpeed = if isActive then 3.4 else 2.0
	applyTailSway(cache.tail, time, tailAmp, tailSpeed)

	if params.facing and params.facing.Magnitude > 0.01 then
		local facing = params.facing.Unit
		local prev = cache.prevFacing
		if prev.Magnitude > 0.01 then
			local targetRoll = math.clamp(prev:Cross(facing).Y * 8, -0.35, 0.35)
			cache.turnRoll += (targetRoll - cache.turnRoll) * math.clamp(dt * 5, 0, 1)
		end
		cache.prevFacing = facing
	end

	if cache.body[2] and math.abs(cache.turnRoll) > 0.001 then
		cache.body[2].Transform *= CFrame.Angles(0, 0, cache.turnRoll)
	end

	if isMoving or isHarvesting then
		applyHeadTracking(cache, params.targetLookPos, params.dragonPivot, dt, 0.55, 0.35)
	else
		applyHeadTracking(cache, nil, params.dragonPivot, dt, 0.55, 0.35)
	end
end

return DragonBoneAnimator

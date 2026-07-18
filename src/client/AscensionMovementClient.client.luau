local Players = game:GetService("Players")

local player = Players.LocalPlayer
local BASE_WALK_SPEED = 16

local function applyMovementBonus(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	local function refresh()
		local bonus = player:GetAttribute("AscensionMovementSpeedBonus") or 0
		bonus = math.clamp(tonumber(bonus) or 0, 0, 2)
		humanoid.WalkSpeed = BASE_WALK_SPEED * (1 + bonus)
	end

	refresh()
	player:GetAttributeChangedSignal("AscensionMovementSpeedBonus"):Connect(refresh)
end

if player.Character then
	applyMovementBonus(player.Character)
end
player.CharacterAdded:Connect(applyMovementBonus)

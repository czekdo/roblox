local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ReferralEvents = ReplicatedStorage:WaitForChild("ReferralEvents")
local SubmitReferralCode = ReferralEvents:WaitForChild("SubmitReferralCode")
local RequestReferralInfo = ReferralEvents:WaitForChild("RequestReferralInfo")

local screenGui = nil
local panel = nil
local myUsernameLabel = nil
local referralCountLabel = nil
local redeemSection = nil
local friendUsernameBox = nil
local statusLabel = nil
local claimButton = nil

local function setStatus(text, good)
	if statusLabel then
		statusLabel.Text = text or ""
		statusLabel.TextColor3 = good and Theme.Colors.Success or Theme.Colors.Danger
	end
end

local function closeReferralPanel()
	if not screenGui or not panel then
		return
	end
	local dim = screenGui:FindFirstChild("DimBackground")
	Theme.closeModalWindow(screenGui, panel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(screenGui.Name)
		end
	end)
end

local function buildUi()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ReferralUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 32
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local dim = Theme.createDim(screenGui, 1)
	dim.Name = "DimBackground"
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeReferralPanel()
		end
	end)

	panel = Theme.createPanel({ Name = "ReferralPanel", Parent = screenGui, Size = UDim2.fromOffset(460, 420), Visible = false })
	panel:SetAttribute("OpenPosition", panel.Position)
	Theme.createCloseButton(panel, function()
		closeReferralPanel()
	end, 30)
	Theme.createWindowHeader(panel, "Invite Friends", "Earn Gems + Essence for every friend who joins", 8)

	Theme.createText({
		Name = "ShareLabel", Parent = panel, Text = "Share your username with a friend:",
		Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(16, 74),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 8,
	})

	local usernameWrap = Theme.createFrame({
		Name = "UsernameWrap", Parent = panel,
		Size = UDim2.new(1, -32, 0, 44), Position = UDim2.fromOffset(16, 96),
		Bg = Theme.Colors.NavyEdge, Corner = Theme.Corner.Medium, ZIndex = 8,
	})
	Theme.stroke(usernameWrap, Theme.Colors.Gold, 1.5, 0.35)
	myUsernameLabel = Theme.createText({
		Name = "MyUsername", Parent = usernameWrap, Text = player.Name,
		Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0),
		TextSize = 20, Font = Theme.Fonts.Title, Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	referralCountLabel = Theme.createText({
		Name = "ReferralCount", Parent = panel, Text = "Friends referred: 0",
		Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(16, 148),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 8,
	})

	local divider = Theme.createFrame({
		Name = "Divider", Parent = panel,
		Size = UDim2.new(1, -32, 0, 2), Position = UDim2.fromOffset(16, 182),
		Bg = Theme.Colors.Gold, BgTransparency = 0.5, ZIndex = 8,
	})

	redeemSection = Theme.createFrame({
		Name = "RedeemSection", Parent = panel,
		Size = UDim2.new(1, -32, 0, 170), Position = UDim2.fromOffset(16, 200),
		BgTransparency = 1, ZIndex = 8,
	})

	Theme.createText({
		Name = "RedeemLabel", Parent = redeemSection, Text = "Were you invited by a friend? Enter their username:",
		Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 0),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		Wrapped = true, ZIndex = 9,
	})

	local inputWrap = Theme.createFrame({
		Name = "InputWrap", Parent = redeemSection,
		Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 38),
		Bg = Theme.Colors.NavyEdge, Corner = Theme.Corner.Medium, ZIndex = 9,
	})
	Theme.stroke(inputWrap, Theme.Colors.Gold, 1.5, 0.45)

	friendUsernameBox = Instance.new("TextBox")
	friendUsernameBox.Size = UDim2.new(1, -16, 1, -8)
	friendUsernameBox.Position = UDim2.fromOffset(8, 4)
	friendUsernameBox.BackgroundTransparency = 1
	friendUsernameBox.Font = Theme.Fonts.Bold
	friendUsernameBox.PlaceholderText = "Friend's username"
	friendUsernameBox.PlaceholderColor3 = Theme.Colors.TextMuted
	friendUsernameBox.Text = ""
	friendUsernameBox.TextColor3 = Theme.Colors.TextLight
	friendUsernameBox.TextSize = 15
	friendUsernameBox.ClearTextOnFocus = false
	friendUsernameBox.ZIndex = 10
	friendUsernameBox.Parent = inputWrap

	claimButton = Theme.createButton({
		Name = "ClaimButton", Parent = redeemSection, Text = "Claim Welcome Gift",
		Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 86),
		Bg = Theme.Colors.Success, TextSize = 15, ZIndex = 9,
		OnClick = function()
			local username = friendUsernameBox.Text
			if typeof(username) ~= "string" or username == "" then
				setStatus("Enter a username first.", false)
				return
			end
			setStatus("Checking...", true)
			local ok, result = pcall(function()
				return SubmitReferralCode:InvokeServer(username)
			end)
			if ok and typeof(result) == "table" then
				setStatus(result.message, result.ok == true)
				if result.ok then
					friendUsernameBox.Text = ""
					redeemSection.Visible = false
				end
			else
				setStatus("Something went wrong. Try again.", false)
			end
		end,
	})

	statusLabel = Theme.createText({
		Name = "Status", Parent = panel, Text = "",
		Size = UDim2.new(1, -32, 0, 40), Position = UDim2.new(0, 16, 1, -50),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Center, Wrapped = true, ZIndex = 8,
	})
end

local function openReferralPanel()
	if not screenGui then
		buildUi()
	end
	screenGui.Enabled = true
	setStatus("", true)

	local ok, info = pcall(function()
		return RequestReferralInfo:InvokeServer()
	end)
	if ok and typeof(info) == "table" then
		myUsernameLabel.Text = info.myUsername or player.Name
		referralCountLabel.Text = "Friends referred: " .. tostring(info.referralCount or 0)
		if info.hasReferrer then
			redeemSection.Visible = false
			setStatus("You've already used a referral code - thanks for joining with a friend!", true)
		elseif info.canRedeem then
			redeemSection.Visible = true
		else
			redeemSection.Visible = false
			setStatus("Referral codes are only available for brand-new kingdoms.", false)
		end
	end

	local dim = screenGui:FindFirstChild("DimBackground")
	local opening = panel and not panel.Visible
	if opening then
		Theme.raiseModalGui(screenGui)
		if _G.DragonIslandNotifyModalOpened then
			_G.DragonIslandNotifyModalOpened(screenGui.Name)
		end
	end
	Theme.tweenOpen(panel, dim)
end

_G.DragonIslandOpenReferral = openReferralPanel
_G.DragonIslandCloseReferral = closeReferralPanel

UIBridge.RegisterPanel("Referral", { Open = openReferralPanel, Close = closeReferralPanel })

print("[ReferralClient] Referral UI ready")

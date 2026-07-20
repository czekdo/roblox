local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialData = require(ReplicatedStorage:WaitForChild("TutorialData"))

local TutorialStep = {}

function TutorialStep.isInfoStep(stepId)
	return TutorialData.IsInfoStep(stepId)
end

function TutorialStep.isVisibleGuiObject(object)
	if not object or not object:IsA("GuiObject") or not object.Visible then
		return false
	end
	local current = object
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return true
end

function TutorialStep.findByName(playerGui, name)
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Enabled then
			local match = gui:FindFirstChild(name, true)
			if match and TutorialStep.isVisibleGuiObject(match) then
				return match
			end
		end
	end
	return nil
end

function TutorialStep.findPurchaseButtonForEgg(playerGui, eggType)
	local card = TutorialStep.findByName(playerGui, eggType .. "EggCard")
	if card then
		local button = card:FindFirstChild("PurchaseButton", true)
		if button and TutorialStep.isVisibleGuiObject(button) then
			return button
		end
	end
	return nil
end

function TutorialStep.isEggShopOpen(playerGui)
	local gui = playerGui:FindFirstChild("EggShopUI")
	if not gui or not gui.Enabled then
		return false
	end
	local panel = gui:FindFirstChild("EggShopPanel", true)
	return panel and panel:IsA("GuiObject") and panel.Visible
end

function TutorialStep.isPanelOpen(playerGui, guiName, panelName)
	local gui = playerGui:FindFirstChild(guiName)
	if not gui or not gui.Enabled then
		return false
	end
	local panel = gui:FindFirstChild(panelName, true)
	return panel and panel:IsA("GuiObject") and panel.Visible
end

function TutorialStep.isCodexVisible(playerGui)
	if not TutorialStep.isPanelOpen(playerGui, "DragonRosterUI", "DragonRosterPanel") then
		return false
	end
	local gui = playerGui:FindFirstChild("DragonRosterUI")
	if not gui then
		return false
	end
	for _, descendant in gui:GetDescendants() do
		if descendant:IsA("TextLabel") and descendant.Text == "DRAGON CODEX" and descendant.Visible then
			return true
		end
		if descendant.Name:sub(1, 9) == "CodexRow_" and descendant:IsA("GuiObject") and descendant.Visible then
			return true
		end
	end
	return false
end

function TutorialStep.findTargetForStep(playerGui, stepId)
	local step = TutorialData.GetStepById(stepId)
	if not step or not step.Target then
		return nil
	end
	local target = step.Target

	if stepId == "BuyFirstEgg" then
		if TutorialStep.isEggShopOpen(playerGui) then
			return TutorialStep.findPurchaseButtonForEgg(playerGui, "Common")
				or TutorialStep.findByName(playerGui, "PurchaseButton")
		end
		return TutorialStep.findByName(playerGui, target.nav)
	end

	if stepId == "EquipFirstDragon" then
		if TutorialStep.isPanelOpen(playerGui, "DragonRosterUI", "DragonRosterPanel") then
			return TutorialStep.findByName(playerGui, "EquipButton")
		end
		return TutorialStep.findByName(playerGui, target.nav)
	end

	if stepId == "TrainFirstDragon" then
		if TutorialStep.isPanelOpen(playerGui, "DragonTrainingUI", "DragonTrainingPanel") then
			return TutorialStep.findByName(playerGui, target.button)
		end
		return TutorialStep.findByName(playerGui, target.nav)
	end

	if stepId == "MergeDragons" then
		if TutorialStep.isPanelOpen(playerGui, "DragonMergeUI", "DragonMergePanel") then
			return TutorialStep.findByName(playerGui, target.button)
		end
		return TutorialStep.findByName(playerGui, target.nav)
	end

	if stepId == "UpgradeKingdom" then
		if TutorialStep.isPanelOpen(playerGui, "BuildingUpgradeUI", "BuildingPanel") then
			return TutorialStep.findByName(playerGui, "ActionButton")
		end
		return TutorialStep.findByName(playerGui, target.nav)
	end

	if stepId == "ExplainDailyQuests" then
		if TutorialStep.isPanelOpen(playerGui, "DailyQuestUI", "QuestPanel") then
			return nil
		end
		return TutorialStep.findByName(playerGui, target.nav)
	end

	if stepId == "ExplainCodex" then
		if TutorialStep.isCodexVisible(playerGui) then
			return nil
		end
		if TutorialStep.isPanelOpen(playerGui, "DragonRosterUI", "DragonRosterPanel") then
			return TutorialStep.findByName(playerGui, target.button)
		end
		return TutorialStep.findByName(playerGui, target.nav)
	end

	if stepId == "IntroduceAscensionGate" then
		if TutorialStep.isPanelOpen(playerGui, "RebirthUI", "RebirthPanel") then
			return nil
		end
		return TutorialStep.findByName(playerGui, target.nav)
	end

	if stepId == "ExplainSellShop" then
		if TutorialStep.isPanelOpen(playerGui, "SellShopUI", "SellShopPanel") then
			return nil
		end
		return TutorialStep.findByName(playerGui, target.nav)
	end

	if target.button then
		local button = TutorialStep.findByName(playerGui, target.button)
		if button then
			return button
		end
	end
	if target.nav then
		return TutorialStep.findByName(playerGui, target.nav)
	end
	return nil
end

function TutorialStep.shouldAutoCompleteInfo(playerGui, stepId)
	if stepId == "ExplainDailyQuests" then
		return TutorialStep.isPanelOpen(playerGui, "DailyQuestUI", "QuestPanel")
	elseif stepId == "ExplainCodex" then
		return TutorialStep.isCodexVisible(playerGui)
	elseif stepId == "IntroduceAscensionGate" then
		return TutorialStep.isPanelOpen(playerGui, "RebirthUI", "RebirthPanel")
	elseif stepId == "ExplainSellShop" then
		return TutorialStep.isPanelOpen(playerGui, "SellShopUI", "SellShopPanel")
	end
	return false
end

return TutorialStep

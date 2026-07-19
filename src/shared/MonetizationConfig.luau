local MonetizationConfig = {}

-- PLACEHOLDER IDs. Replace Id = 0 with the real GamePass ID from Creator Dashboard > Monetization
-- > Passes once created. Until then, ShopClient shows these as "Coming Soon" and MonetizationService
-- skips the ownership check for any pass with Id <= 0 (UserOwnsGamePassAsync would error on a fake ID).
MonetizationConfig.GamePasses = {
	{
		Key = "VIP",
		Id = 0, -- TODO: fill in real GamePass ID
		Name = "VIP Pass",
		Description = "Permanent perks for supporters. (Perk details TBD.)",
		AttributeName = "OwnsVIP",
	},
}

-- PLACEHOLDER IDs. Replace Id = 0 with the real DeveloperProduct ID from Creator Dashboard once
-- created. ShopClient disables the Buy button for any product with Id <= 0.
MonetizationConfig.DeveloperProducts = {
	{
		Key = "GemsSmall",
		Id = 0, -- TODO: fill in real DeveloperProduct ID
		Name = "50 Gems",
		Reward = { Type = "PremiumCurrency", Amount = 50, Text = "+50 Gems" },
	},
	{
		Key = "GemsMedium",
		Id = 0, -- TODO: fill in real DeveloperProduct ID
		Name = "150 Gems (+20% bonus)",
		Reward = { Type = "PremiumCurrency", Amount = 150, Text = "+150 Gems" },
	},
	{
		Key = "GemsLarge",
		Id = 0, -- TODO: fill in real DeveloperProduct ID
		Name = "400 Gems (+45% bonus)",
		Reward = { Type = "PremiumCurrency", Amount = 400, Text = "+400 Gems" },
	},
}

function MonetizationConfig.GetProductById(productId)
	for _, product in MonetizationConfig.DeveloperProducts do
		if product.Id == productId then
			return product
		end
	end
	return nil
end

return MonetizationConfig

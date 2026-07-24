local MonetizationConfig = {}

MonetizationConfig.GamePasses = {
	{
		Key = "VIP",
		Id = 1919679707,
		Name = "VIP Pass",
		Description = "Grants the exclusive Royal Dragon",
		AttributeName = "OwnsVIP",
	},
	{
		Key = "AutoHatch",
		Id = 1928874679,
		Name = "Auto-Hatch Pass",
		Description = "Eggs repurchase and hatch on their own - no more standing at the shop.",
		AttributeName = "OwnsAutoHatch",
	},
}

MonetizationConfig.DeveloperProducts = {
	{
		Key = "GemsSmall",
		Id = 3610839685,
		Name = "50 Gems",
		Reward = { Type = "PremiumCurrency", Amount = 50, Text = "+50 Gems" },
	},
	{
		Key = "GemsMedium",
		Id = 3610839735,
		Name = "150 Gems (+20% bonus)",
		Reward = { Type = "PremiumCurrency", Amount = 150, Text = "+150 Gems" },
	},
	{
		Key = "GemsLarge",
		Id = 3610839778,
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

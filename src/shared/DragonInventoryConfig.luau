local DragonInventoryConfig = {
	DefaultStorageCapacity = 50,
	StorageCapacityByLevel = { 50, 75, 100, 125, 150 },
	CapacityPerLevelAfterTable = 25,
	MaxStorageCapacity = 10000,

	RarityTiebreaker = {
		Common = 1,
		Rare = 2,
		Epic = 3,
		Legendary = 4,
		Mythic = 5,
		Ancient = 6,
	},

	SortOptions = {
		"Power",
		"Training",
		"Stars",
		"Ability Level",
		"Rarity",
		"Species",
		"Newest",
		"Oldest",
	},

	FilterOptions = {
		"Species",
		"Rarity",
		"Favorites",
		"Locked",
		"Equipped",
		"Idle",
		"Training",
		"Harvesting",
	},
}

function DragonInventoryConfig.GetStorageCapacity(buildingLevel)
	local level = math.max(1, math.floor(tonumber(buildingLevel) or 1))
	local capacityTable = DragonInventoryConfig.StorageCapacityByLevel
	if #capacityTable == 0 then
		return DragonInventoryConfig.DefaultStorageCapacity
	end
	if level <= #capacityTable then
		return capacityTable[level]
	end
	local lastCapacity = capacityTable[#capacityTable]
	local extraLevels = level - #capacityTable
	local capacity = lastCapacity + extraLevels * (DragonInventoryConfig.CapacityPerLevelAfterTable or 25)
	return math.min(DragonInventoryConfig.MaxStorageCapacity, capacity)
end

return DragonInventoryConfig

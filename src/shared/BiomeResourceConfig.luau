local BiomeResourceConfig = {}

BiomeResourceConfig.NodesPerType = 5
BiomeResourceConfig.MinNodeSpacing = 18
BiomeResourceConfig.MaxPlacementAttempts = 320
BiomeResourceConfig.ScaleVariation = 0.1
BiomeResourceConfig.BaseCrystalScale = 3.35
BiomeResourceConfig.HitboxSize = Vector3.new(4.2, 6.4, 4.2)

BiomeResourceConfig.ExclusionRadius = {
	Spawn = 42,
	Portal = 50,
}

-- Inset from each island's placement Part edges when sampling positions.
BiomeResourceConfig.PlacementEdgeMargin = 0.08

-- Canonical resource names mapped to island unlock ids from IslandUnlockConfig.
-- Add new resource strings here to support future types without changing placer code.
BiomeResourceConfig.IslandResources = {
	Forest = { "EmeraldCrystal" },
	Cold = { "FrozenCrystal", "GlacialCrystal" },
	Lava = { "RubyCrystal", "ObsidianCrystal" },
	Storm = { "LightningCrystal" },
	Shadow = { "ShadowCrystal", "VoidCrystal" },
	Crystal = { "CrystalResource", "SapphireCrystal" },
	Celestial = { "CelestialCrystal", "StarCrystal" },
}

-- Optional aliases when Studio model names differ from canonical names.
BiomeResourceConfig.ResourceAliases = {
	FrozenCrystal = "frozencrystial",
	GlacialCrystal = "glacialcrystal",
	LightningCrystal = "lightningcrystal",
	ObsidianCrystal = "obsydiancrystal",
	ShadowCrystal = "shadowcrystal",
	VoidCrystal = "voidcrystal",
	CelestialCrystal = "celestialcrystal",
	StarCrystal = "starcrystal",
}

function BiomeResourceConfig.GetResourcesForIsland(islandId)
	return BiomeResourceConfig.IslandResources[islandId] or {}
end

return BiomeResourceConfig

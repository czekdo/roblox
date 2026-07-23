local GlobalEventConfig = {}

GlobalEventConfig.DataStoreName = "DragonIslandGlobalEventV1"

-- How often a server re-checks the DataStore for an event started/ended on a DIFFERENT server.
-- The server that actually starts/ends an event applies it to its own cache immediately - this
-- interval only matters for every other concurrently-running server noticing the change.
GlobalEventConfig.RefreshInterval = 30

GlobalEventConfig.Types = {
	EssenceBoost = { Label = "Essence Boost", Icon = "rbxassetid://113316632422703" },
	LuckBoost = { Label = "Luck Boost", Icon = "rbxassetid://78843852703854" },
}

-- Preset options surfaced in the admin panel - not a hard limit, just convenient buttons.
GlobalEventConfig.MultiplierPresets = { 1.25, 1.5, 2, 3 }
GlobalEventConfig.DurationPresetsHours = { 1, 6, 24, 72, 168 }

return GlobalEventConfig

local WeeklyLeaderboardConfig = {}

-- Which lifetime stat the weekly board measures progress against. The weekly value is NOT this
-- attribute directly - it's (current value - value recorded at the start of this week), so the
-- board reflects activity during the week rather than an all-time total that would always favor
-- the oldest players.
WeeklyLeaderboardConfig.SourceAttribute = "LifetimeEssence"

WeeklyLeaderboardConfig.TopN = 50
WeeklyLeaderboardConfig.UpdateInterval = 90

WeeklyLeaderboardConfig.BoardDataStorePrefix = "DragonIslandWeeklyBoard_"
WeeklyLeaderboardConfig.BaselineDataStoreName = "DragonIslandWeeklyBaselineV1"
WeeklyLeaderboardConfig.StateDataStoreName = "DragonIslandWeeklyStateV1"

local WEEK_SECONDS = 7 * 24 * 60 * 60

-- A plain integer that increments every 7 real-world days since the Unix epoch. Doesn't line up
-- with calendar weeks/Mondays, but it's deterministic and monotonic across every server without
-- any admin-set schedule, which is all a rotating weekly board needs.
function WeeklyLeaderboardConfig.GetCurrentWeekId()
	return math.floor(os.time() / WEEK_SECONDS)
end

function WeeklyLeaderboardConfig.GetWeekStartTime(weekId)
	return weekId * WEEK_SECONDS
end

function WeeklyLeaderboardConfig.GetSecondsUntilNextWeek()
	local current = os.time()
	local currentWeekId = WeeklyLeaderboardConfig.GetCurrentWeekId()
	local nextWeekStart = (currentWeekId + 1) * WEEK_SECONDS
	return math.max(0, nextWeekStart - current)
end

-- Rank tiers (inclusive), first match wins. Checked top-to-bottom so keep narrower/higher ranks first.
WeeklyLeaderboardConfig.RewardTiers = {
	{ MinRank = 1, MaxRank = 1, Gems = 500, Essence = 5000, Label = "#1 Essence Champion" },
	{ MinRank = 2, MaxRank = 3, Gems = 250, Essence = 2500, Label = "Top 3 Finish" },
	{ MinRank = 4, MaxRank = 10, Gems = 100, Essence = 1000, Label = "Top 10 Finish" },
	{ MinRank = 11, MaxRank = 50, Gems = 25, Essence = 250, Label = "Top 50 Finish" },
}

function WeeklyLeaderboardConfig.GetRewardForRank(rank)
	for _, tier in WeeklyLeaderboardConfig.RewardTiers do
		if rank >= tier.MinRank and rank <= tier.MaxRank then
			return tier
		end
	end
	return nil
end

return WeeklyLeaderboardConfig

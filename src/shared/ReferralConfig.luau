local ReferralConfig = {}

ReferralConfig.LinkDataStoreName = "DragonIslandReferralLinkV1"
ReferralConfig.CountDataStoreName = "DragonIslandReferralCountV1"

-- Referrer only gets paid once their friend has stuck around and actually played - this is the
-- one meaningful anti-abuse gate: without it, someone could farm rewards with disposable alt
-- accounts that join and immediately quit.
ReferralConfig.QualifyingKingdomLevel = 5

-- Only a brand-new account (still at the starting Kingdom Level) can enter a referral code - an
-- established player retroactively "using" a friend's code for free rewards would be exploitable.
ReferralConfig.MaxKingdomLevelToRedeem = 1

ReferralConfig.ReferrerReward = { Gems = 100, Essence = 1000 }
ReferralConfig.NewPlayerReward = { Gems = 50, Essence = 500 }

return ReferralConfig

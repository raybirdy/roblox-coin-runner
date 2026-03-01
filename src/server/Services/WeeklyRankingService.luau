--!strict
-- WeeklyRankingService
-- 주간 순위쟁탈전: 현재 주간 랭킹 조회 + 보상 체계 관리

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local LeaderboardService = require(script.Parent.LeaderboardService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local WeeklyRankingService = {}

-- 주간 보상 체계 (순위 → 젬)
WeeklyRankingService.REWARD_TIERS = {
	{ maxRank = 1,   gems = 300 },
	{ maxRank = 3,   gems = 150 },
	{ maxRank = 10,  gems = 50  },
	{ maxRank = 50,  gems = 20  },
	{ maxRank = 100, gems = 10  },
}

-- 현재 주간 순위 데이터 캐시 (60초 갱신)
local weeklyCache: { { rank: number, name: string, score: number } } = {}
local weeklyLastUpdate = 0
local WEEKLY_CACHE_DURATION = 60

-- ==================== 순위 조회 ====================

function WeeklyRankingService:GetWeeklyLeaderboard(): { { rank: number, name: string, score: number } }
	local now = tick()
	if now - weeklyLastUpdate < WEEKLY_CACHE_DURATION and #weeklyCache > 0 then
		return weeklyCache
	end

	local data = LeaderboardService:GetLeaderboard(20, "weekly")
	weeklyCache = data
	weeklyLastUpdate = now
	return data
end

-- 특정 점수의 예상 주간 순위 계산
function WeeklyRankingService:GetPlayerWeeklyRank(player: Player): number?
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return nil
	end
	local playerScore = playerData.highScore or 0
	if playerScore == 0 then
		return nil
	end

	local leaderboard = self:GetWeeklyLeaderboard()
	for _, entry in leaderboard do
		if entry.score <= playerScore then
			return entry.rank
		end
	end

	-- 리더보드에 없으면 리더보드 크기 + 1
	return #leaderboard + 1
end

-- 순위에 해당하는 보상 젬 계산
function WeeklyRankingService:GetRewardForRank(rank: number): number
	for _, tier in self.REWARD_TIERS do
		if rank <= tier.maxRank then
			return tier.gems
		end
	end
	return 0
end

-- ==================== 클라이언트 업데이트 ====================

-- 플레이어에게 현재 주간 순위 정보 전송
function WeeklyRankingService:SendWeeklyRankToPlayer(player: Player)
	local weeklyRank = self:GetPlayerWeeklyRank(player)
	local topPlayers = self:GetWeeklyLeaderboard()

	RemoteEvents.WeeklyRankUpdate:FireClient(player, {
		weeklyRank = weeklyRank,
		topPlayers = topPlayers,
		rewardTiers = self.REWARD_TIERS,
	})
end

-- ==================== 이벤트 연결 ====================

function WeeklyRankingService:SetupRemoteEvents()
	-- 리더보드 요청 시 주간 순위 함께 전송
	RemoteEvents.LeaderboardRequest.OnServerEvent:Connect(function(player: Player, data: { tab: string? }?)
		if data and data.tab == "weekly" then
			self:SendWeeklyRankToPlayer(player)
		end
	end)
	print("[WeeklyRankingService] Remote events connected")
end

print("[WeeklyRankingService] Initialized")

return WeeklyRankingService

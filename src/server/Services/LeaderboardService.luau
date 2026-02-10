--!strict
-- Leaderboard Service
-- 전체 사용자 리더보드 (OrderedDataStore 사용)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local LeaderboardService = {}

-- OrderedDataStore (Studio에서는 사용 불가)
local highScoreStore = nil
local success, err = pcall(function()
	highScoreStore = DataStoreService:GetOrderedDataStore("HighScores_v1")
end)

if not success then
	warn("[LeaderboardService] OrderedDataStore unavailable (Studio mode): " .. tostring(err))
end

-- 캐시된 리더보드 데이터
local cachedLeaderboard: { { rank: number, name: string, score: number } } = {}
local lastUpdateTime = 0
local CACHE_DURATION = 30 -- 30초마다 갱신

-- 리더보드 업데이트 (점수 저장)
function LeaderboardService:UpdateScore(player: Player, score: number)
	if not highScoreStore then
		print("[LeaderboardService] Studio mode - skipping score update")
		return
	end

	local userId = player.UserId
	local playerName = player.Name

	-- 기존 점수 확인
	local currentScore = 0
	local getSuccess, getData = pcall(function()
		return highScoreStore:GetAsync(userId)
	end)

	if getSuccess and getData then
		currentScore = getData
	end

	-- 새 점수가 더 높으면 업데이트
	if score > currentScore then
		local setSuccess, setErr = pcall(function()
			highScoreStore:SetAsync(userId, score)
		end)

		if setSuccess then
			print(`[LeaderboardService] Updated high score for {playerName}: {score}`)
			-- 캐시 무효화
			lastUpdateTime = 0
		else
			warn(`[LeaderboardService] Failed to update score: {setErr}`)
		end
	end
end

-- 리더보드 가져오기 (상위 N명)
function LeaderboardService:GetLeaderboard(count: number?): { { rank: number, name: string, score: number } }
	local maxCount = count or 10

	-- 캐시가 유효하면 캐시 반환
	if tick() - lastUpdateTime < CACHE_DURATION and #cachedLeaderboard > 0 then
		return cachedLeaderboard
	end

	if not highScoreStore then
		-- Studio 모드: 더미 데이터 반환
		return self:_getDummyLeaderboard()
	end

	local leaderboard: { { rank: number, name: string, score: number } } = {}

	local success, pages = pcall(function()
		return highScoreStore:GetSortedAsync(false, maxCount)
	end)

	if not success or not pages then
		warn("[LeaderboardService] Failed to get leaderboard")
		return cachedLeaderboard
	end

	local data = pages:GetCurrentPage()

	for rank, entry in ipairs(data) do
		local userId = entry.key
		local score = entry.value

		-- 플레이어 이름 가져오기
		local playerName = "Player"
		local nameSuccess, name = pcall(function()
			return Players:GetNameFromUserIdAsync(tonumber(userId) or 0)
		end)

		if nameSuccess and name then
			playerName = name
		end

		table.insert(leaderboard, {
			rank = rank,
			name = playerName,
			score = score,
		})
	end

	-- 캐시 업데이트
	cachedLeaderboard = leaderboard
	lastUpdateTime = tick()

	print(`[LeaderboardService] Leaderboard updated with {#leaderboard} entries`)

	return leaderboard
end

-- Studio 모드용 더미 데이터
function LeaderboardService:_getDummyLeaderboard(): { { rank: number, name: string, score: number } }
	return {
		{ rank = 1, name = "Champion", score = 15000 },
		{ rank = 2, name = "Runner", score = 12500 },
		{ rank = 3, name = "CoinMaster", score = 10000 },
		{ rank = 4, name = "SpeedKing", score = 8500 },
		{ rank = 5, name = "JumpHero", score = 7000 },
		{ rank = 6, name = "SlideAce", score = 5500 },
		{ rank = 7, name = "CoinHunter", score = 4000 },
		{ rank = 8, name = "FastFeet", score = 3000 },
		{ rank = 9, name = "Beginner", score = 2000 },
		{ rank = 10, name = "Newbie", score = 1000 },
	}
end

-- 플레이어 순위 가져오기
function LeaderboardService:GetPlayerRank(player: Player): number?
	if not highScoreStore then
		return nil
	end

	local userId = player.UserId

	-- 현재 점수 가져오기
	local success, score = pcall(function()
		return highScoreStore:GetAsync(userId)
	end)

	if not success or not score then
		return nil
	end

	-- 순위 계산 (해당 점수보다 높은 점수 개수 + 1)
	-- 참고: 정확한 순위 계산은 비용이 많이 들어 캐시된 리더보드에서 확인
	for _, entry in cachedLeaderboard do
		if entry.score == score then
			return entry.rank
		end
	end

	return nil
end

-- 리더보드 요청 이벤트 핸들러
RemoteEvents.LeaderboardRequest.OnServerEvent:Connect(function(player: Player)
	print(`[LeaderboardService] Leaderboard requested by {player.Name}`)

	local leaderboard = LeaderboardService:GetLeaderboard(10)
	local playerRank = LeaderboardService:GetPlayerRank(player)

	RemoteEvents.LeaderboardData:FireClient(player, {
		leaderboard = leaderboard,
		playerRank = playerRank,
	})
end)

print("[LeaderboardService] Initialized")

return LeaderboardService

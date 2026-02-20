--!strict
-- Leaderboard Service
-- 전체 사용자 리더보드 (OrderedDataStore 사용)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local LeaderboardService = {}

-- OrderedDataStore (Studio에서는 사용 불가)
local highScoreStore = nil
local dailyScoreStore = nil
local weeklyScoreStore = nil

local success, err = pcall(function()
	highScoreStore = DataStoreService:GetOrderedDataStore("HighScores_v1")

	-- 일간/주간 키는 날짜 기반
	local today = os.date("!%Y-%m-%d")
	local weekNum = os.date("!%Y-W%W")
	dailyScoreStore = DataStoreService:GetOrderedDataStore("DailyScores_" .. today)
	weeklyScoreStore = DataStoreService:GetOrderedDataStore("WeeklyScores_" .. weekNum)
end)

if not success then
	warn("[LeaderboardService] OrderedDataStore unavailable (Studio mode): " .. tostring(err))
end

-- 캐시된 리더보드 데이터 (탭별)
type LeaderboardEntry = { rank: number, name: string, score: number }
local cachedLeaderboards: { [string]: { LeaderboardEntry } } = {
	all = {},
	daily = {},
	weekly = {},
}
local lastUpdateTimes: { [string]: number } = { all = 0, daily = 0, weekly = 0 }
local CACHE_DURATION = 30 -- 30초마다 갱신

-- 리더보드 업데이트 (점수 저장)
function LeaderboardService:UpdateScore(player: Player, score: number)
	if not highScoreStore then
		print("[LeaderboardService] Studio mode - skipping score update")
		return
	end

	local userId = player.UserId
	local playerName = player.Name

	-- 전체 리더보드: 최고 점수만 저장
	local currentScore = 0
	local getSuccess, getData = pcall(function()
		return highScoreStore:GetAsync(userId)
	end)

	if getSuccess and getData then
		currentScore = getData
	end

	if score > currentScore then
		local setSuccess, setErr = pcall(function()
			highScoreStore:SetAsync(userId, score)
		end)

		if setSuccess then
			print(`[LeaderboardService] Updated high score for {playerName}: {score}`)
			lastUpdateTimes.all = 0
		else
			warn(`[LeaderboardService] Failed to update score: {setErr}`)
		end
	end

	-- 일간 리더보드: 오늘 최고 점수
	if dailyScoreStore then
		pcall(function()
			local dailyCurrent = dailyScoreStore:GetAsync(userId) or 0
			if score > dailyCurrent then
				dailyScoreStore:SetAsync(userId, score)
				lastUpdateTimes.daily = 0
			end
		end)
	end

	-- 주간 리더보드: 이번 주 최고 점수
	if weeklyScoreStore then
		pcall(function()
			local weeklyCurrent = weeklyScoreStore:GetAsync(userId) or 0
			if score > weeklyCurrent then
				weeklyScoreStore:SetAsync(userId, score)
				lastUpdateTimes.weekly = 0
			end
		end)
	end
end

-- 리더보드 가져오기 (상위 N명, 탭별)
function LeaderboardService:GetLeaderboard(count: number?, tab: string?): { LeaderboardEntry }
	local maxCount = count or 10
	local tabKey = tab or "all"

	-- 캐시가 유효하면 캐시 반환
	local lastUpdate = lastUpdateTimes[tabKey] or 0
	local cached = cachedLeaderboards[tabKey] or {}
	if tick() - lastUpdate < CACHE_DURATION and #cached > 0 then
		return cached
	end

	-- 탭별 DataStore 선택
	local store = highScoreStore
	if tabKey == "daily" then
		store = dailyScoreStore
	elseif tabKey == "weekly" then
		store = weeklyScoreStore
	end

	if not store then
		-- Studio 모드: 더미 데이터 반환
		return self:_getDummyLeaderboard()
	end

	local leaderboard: { LeaderboardEntry } = {}

	local success, pages = pcall(function()
		return store:GetSortedAsync(false, maxCount)
	end)

	if not success or not pages then
		warn(`[LeaderboardService] Failed to get {tabKey} leaderboard`)
		return cached
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

	-- DataStore is available but empty (fresh game) -> fallback to dummy data
	if #leaderboard == 0 then
		return self:_getDummyLeaderboard()
	end

	-- 캐시 업데이트
	cachedLeaderboards[tabKey] = leaderboard
	lastUpdateTimes[tabKey] = tick()

	print(`[LeaderboardService] {tabKey} leaderboard updated with {#leaderboard} entries`)

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
	local allCache = cachedLeaderboards.all or {}
	for _, entry in allCache do
		if entry.score == score then
			return entry.rank
		end
	end

	return nil
end

-- 리더보드 요청 이벤트 핸들러
RemoteEvents.LeaderboardRequest.OnServerEvent:Connect(function(player: Player, data: { tab: string? }?)
	-- 입력 검증 (data는 nil 허용)
	if data ~= nil and type(data) ~= "table" then
		return
	end
	if not RateLimiter.Check(player, "LeaderboardRequest", 2) then
		return
	end

	local tab = (data and type(data.tab) == "string") and data.tab or "all"
	print(`[LeaderboardService] Leaderboard requested by {player.Name} (tab: {tab})`)

	local leaderboard = LeaderboardService:GetLeaderboard(10, tab)
	local playerRank = LeaderboardService:GetPlayerRank(player)

	RemoteEvents.LeaderboardData:FireClient(player, {
		leaderboard = leaderboard,
		playerRank = playerRank,
		tab = tab,
	})
end)

-- 로비 리더보드 간판 업데이트
function LeaderboardService:UpdateLobbyDisplay()
	-- LobbyService에서 SurfaceGui 가져오기
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end

	local boardBackground = lobby:FindFirstChild("LeaderboardBackground") :: BasePart?
	if not boardBackground then
		return
	end

	local surfaceGui = boardBackground:FindFirstChild("LeaderboardGui") :: SurfaceGui?
	if not surfaceGui then
		return
	end

	local rankContainer = surfaceGui:FindFirstChild("RankContainer") :: Frame?
	if not rankContainer then
		return
	end

	-- 리더보드 데이터 가져오기 (로비 간판은 전체 리더보드)
	local leaderboard = self:GetLeaderboard(10, "all")

	-- 각 순위 슬롯 업데이트
	for i = 1, 10 do
		local rankFrame = rankContainer:FindFirstChild(`Rank{i}`) :: Frame?
		if not rankFrame then
			continue
		end

		local nameLabel = rankFrame:FindFirstChild("PlayerName") :: TextLabel?
		local scoreLabel = rankFrame:FindFirstChild("Score") :: TextLabel?

		if leaderboard[i] then
			local entry = leaderboard[i]
			if nameLabel then
				nameLabel.Text = entry.name
			end
			if scoreLabel then
				scoreLabel.Text = tostring(entry.score)
			end
		else
			if nameLabel then
				nameLabel.Text = "---"
			end
			if scoreLabel then
				scoreLabel.Text = "0"
			end
		end
	end

	print("[LeaderboardService] Lobby display updated")
end

-- 주기적 업데이트 (30초마다)
task.spawn(function()
	-- 초기 대기 (LobbyService가 먼저 초기화되도록)
	task.wait(3)

	while true do
		LeaderboardService:UpdateLobbyDisplay()
		task.wait(30)
	end
end)

print("[LeaderboardService] Initialized")

return LeaderboardService

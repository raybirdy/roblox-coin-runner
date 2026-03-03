--!strict
-- Daily Event Service
-- 요일별 테마 이벤트: 목표 달성 시 보상 지급, 진행도 추적

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local DailyEventService = {}

-- Per-player in-session progress (in memory, reset on game start)
local sessionProgress: { [Player]: number } = {}
local sessionGoalMet: { [Player]: boolean } = {}
local sessionThemeId: { [Player]: string } = {}

-- Get today's UTC date string "YYYY-MM-DD"
local function getTodayDate(): string
	local t = os.date("!*t") :: any
	return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

-- Get today's theme based on UTC day of week
function DailyEventService:GetTodayTheme(): any?
	local t = os.date("!*t")
	local wday = (t :: any).wday -- 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
	return GameConstants.DAILY_EVENT.THEMES[wday]
end

-- Initialize session for a player (called at game start)
function DailyEventService:InitSession(player: Player)
	local theme = self:GetTodayTheme()
	if not theme then
		return
	end

	-- Load saved progress for today (carry over if same day, otherwise start fresh)
	sessionProgress[player] = 0
	sessionGoalMet[player] = false
	sessionThemeId[player] = theme.id
end

-- Clean up when player leaves
function DailyEventService:OnPlayerLeave(player: Player)
	sessionProgress[player] = nil
	sessionGoalMet[player] = nil
	sessionThemeId[player] = nil
end

-- Called when coins are collected this frame (for collect_themed_coins goal)
function DailyEventService:OnCoinsCollected(player: Player, count: number)
	if not sessionProgress[player] then
		return
	end
	local theme = self:GetTodayTheme()
	if not theme or theme.goal ~= "collect_themed_coins" then
		return
	end
	sessionProgress[player] += count
end

-- Called with current distance in studs (for distance_run goal)
function DailyEventService:OnDistanceUpdate(player: Player, distanceStuds: number)
	if not sessionProgress[player] then
		return
	end
	local theme = self:GetTodayTheme()
	if not theme or theme.goal ~= "distance_run" then
		return
	end
	-- Convert studs to meters (approximate: 1 stud ≈ 0.28m, ~3.57 studs per meter)
	-- Use same conversion as score system: goalTarget is already in studs equivalent
	sessionProgress[player] = math.max(sessionProgress[player], math.floor(distanceStuds))
end

-- Called with current score (for score_reach goal)
function DailyEventService:OnScoreUpdate(player: Player, score: number)
	if not sessionProgress[player] then
		return
	end
	local theme = self:GetTodayTheme()
	if not theme or theme.goal ~= "score_reach" then
		return
	end
	sessionProgress[player] = math.max(sessionProgress[player], score)
end

-- Check if goal is newly met in this session and grant reward (once per day)
-- Returns true if reward was granted right now
function DailyEventService:CheckAndGrantReward(
	player: Player,
	playerData: any,
	PlayerDataService: any
): boolean
	local theme = self:GetTodayTheme()
	if not theme then
		return false
	end

	-- Already rewarded today
	local todayDate = getTodayDate()
	if playerData.dailyEventDate == todayDate and playerData.dailyEventCompleted == true then
		return false
	end

	-- Already granted in this session
	if sessionGoalMet[player] then
		return false
	end

	-- Check progress
	local progress = sessionProgress[player] or 0
	if progress < theme.goalTarget then
		return false
	end

	-- Grant reward
	sessionGoalMet[player] = true

	if theme.rewardType == "coins" then
		PlayerDataService:AddCoins(player, theme.rewardAmount)
	elseif theme.rewardType == "gems" then
		PlayerDataService:AddGems(player, theme.rewardAmount)
	end
	if theme.bonusGems and theme.bonusGems > 0 then
		PlayerDataService:AddGems(player, theme.bonusGems)
	end

	print(
		`[DailyEventService] Event reward granted to {player.Name}: {theme.displayName} → {theme.rewardType} x{theme.rewardAmount} + {theme.bonusGems} gems`
	)
	return true
end

-- Send event data to client (called on game start and lobby entry)
function DailyEventService:SendEventData(player: Player, playerData: any)
	local theme = self:GetTodayTheme()
	if not theme then
		return
	end

	local todayDate = getTodayDate()
	local alreadyCompleted = playerData.dailyEventDate == todayDate and playerData.dailyEventCompleted == true
	local savedProgress = if playerData.dailyEventDate == todayDate
		then (playerData.dailyEventProgress or 0)
		else 0

	RemoteEvents.DailyEventData:FireClient(player, {
		themeId = theme.id,
		displayName = theme.displayName,
		coinName = theme.coinName,
		coinColor = theme.coinColor, -- Color3 (can be nil for rainbow)
		goal = theme.goal,
		goalTarget = theme.goalTarget,
		goalDesc = theme.goalDesc,
		rewardType = theme.rewardType,
		rewardAmount = theme.rewardAmount,
		bonusGems = theme.bonusGems,
		speedModifier = theme.speedModifier,
		coinValueBonus = theme.coinValueBonus,
		progress = savedProgress,
		completed = alreadyCompleted,
	})
end

-- Fire real-time progress update during gameplay
function DailyEventService:FireProgressUpdate(player: Player, playerData: any)
	local theme = self:GetTodayTheme()
	if not theme then
		return
	end

	local todayDate = getTodayDate()
	local alreadyCompleted = playerData.dailyEventDate == todayDate and playerData.dailyEventCompleted == true

	RemoteEvents.DailyEventProgress:FireClient(player, {
		progress = sessionProgress[player] or 0,
		goalTarget = theme.goalTarget,
		goalType = theme.goal,
		completed = alreadyCompleted or (sessionGoalMet[player] == true),
	})
end

-- Persist session progress to PlayerData (called on EndGame)
function DailyEventService:PersistProgress(player: Player, playerData: any, PlayerDataService: any)
	local theme = self:GetTodayTheme()
	if not theme then
		return
	end

	local todayDate = getTodayDate()
	local currentProgress = sessionProgress[player] or 0

	-- Keep the best progress across sessions today
	local bestProgress = currentProgress
	if playerData.dailyEventDate == todayDate then
		bestProgress = math.max(currentProgress, playerData.dailyEventProgress or 0)
	end

	local isCompleted = (playerData.dailyEventDate == todayDate and playerData.dailyEventCompleted == true)
		or (sessionGoalMet[player] == true)

	PlayerDataService:SetDailyEventData(player, todayDate, isCompleted, bestProgress)
end

print("[DailyEventService] Initialized")

return DailyEventService

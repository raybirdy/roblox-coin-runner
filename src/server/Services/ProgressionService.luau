--!strict
-- Progression Service
-- 플레이어 진행도 통합 관리 (레벨, 일일 미션, 업적)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local ProgressionService = {}

-- ==================== 레벨 시스템 ====================

-- 다음 레벨까지 필요한 XP 반환
function ProgressionService:GetXPToNextLevel(level: number): number
	local xpTable = GameConstants.LEVEL.XP_TABLE
	if level >= GameConstants.LEVEL.MAX_LEVEL then
		return 0 -- 만렙
	end
	return xpTable[level] or xpTable[#xpTable]
end

-- XP 추가 및 레벨업 처리
function ProgressionService:AddXP(player: Player, amount: number)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	playerData.xp = (playerData.xp or 0) + amount
	local level = playerData.level or 1

	-- 레벨업 체크
	while level < GameConstants.LEVEL.MAX_LEVEL do
		local xpNeeded = self:GetXPToNextLevel(level)
		if playerData.xp >= xpNeeded then
			playerData.xp -= xpNeeded
			level += 1
			playerData.level = level
			self:_onLevelUp(player, level)
		else
			break
		end
	end

	-- 만렙이면 XP 캡
	if level >= GameConstants.LEVEL.MAX_LEVEL then
		playerData.xp = 0
	end

	-- 클라이언트에 XP 알림
	RemoteEvents.XPGained:FireClient(player, {
		xp = amount,
		totalXP = playerData.xp,
		level = playerData.level,
		xpToNext = self:GetXPToNextLevel(playerData.level),
	})

	-- 레벨 업적 체크
	self:CheckAchievements(player)
end

-- 레벨업 보상 지급
function ProgressionService:_onLevelUp(player: Player, newLevel: number)
	local coinReward = GameConstants.LEVEL.LEVEL_UP_COIN_REWARD
	local gemReward = 0

	-- 마일스톤 레벨 보상 (5, 10, 15, 20)
	for _, milestoneLevel in GameConstants.LEVEL.MILESTONE_LEVELS do
		if newLevel == milestoneLevel then
			gemReward = GameConstants.LEVEL.MILESTONE_GEM_REWARD
			break
		end
	end

	-- 보상 지급
	PlayerDataService:AddCoins(player, coinReward)
	if gemReward > 0 then
		PlayerDataService:AddGems(player, gemReward)
	end

	-- 클라이언트에 레벨업 알림
	RemoteEvents.LevelUp:FireClient(player, {
		newLevel = newLevel,
		rewards = { coins = coinReward, gems = gemReward > 0 and gemReward or nil },
	})

	print(`[ProgressionService] {player.Name} leveled up to {newLevel}!`)
end

-- ==================== 일일 미션 시스템 ====================

-- 오늘 날짜 키 생성
function ProgressionService:_getTodayKey(): string
	return os.date("!%Y-%m-%d") :: string
end

-- 일일 미션 초기화/리셋
function ProgressionService:InitDailyMissions(player: Player)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	local today = self:_getTodayKey()

	-- 이미 오늘 미션이 설정되어 있으면 스킵
	if playerData.dailyMissionDate == today and playerData.dailyMissions and #playerData.dailyMissions > 0 then
		return
	end

	-- 새 미션 생성
	local templates = GameConstants.MISSIONS.TEMPLATES
	local selectedMissions = {}
	local usedIndices: { [number]: boolean } = {}

	for _ = 1, GameConstants.MISSIONS.DAILY_COUNT do
		-- 중복 없이 랜덤 선택
		local idx
		repeat
			idx = math.random(1, #templates)
		until not usedIndices[idx]
		usedIndices[idx] = true

		local template = templates[idx]
		local target = template.targets[math.random(1, #template.targets)]

		table.insert(selectedMissions, {
			id = template.id,
			name = template.name,
			desc = string.gsub(template.desc, "{target}", tostring(target)),
			target = target,
			progress = 0,
			completed = false,
			reward = template.reward,
		})
	end

	playerData.dailyMissions = selectedMissions
	playerData.dailyMissionDate = today

	print(`[ProgressionService] Daily missions initialized for {player.Name}`)
end

-- 미션 진행도 업데이트
function ProgressionService:UpdateMissionProgress(player: Player, missionType: string, amount: number)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData or not playerData.dailyMissions then
		return
	end

	-- 날짜 확인 (다음날이면 리셋)
	local today = self:_getTodayKey()
	if playerData.dailyMissionDate ~= today then
		self:InitDailyMissions(player)
		return
	end

	local missions = playerData.dailyMissions :: { any }
	local changed = false

	for _, mission in missions do
		if mission.id == missionType and not mission.completed then
			mission.progress = math.min(mission.progress + amount, mission.target)
			changed = true

			if mission.progress >= mission.target then
				mission.completed = true
				self:_onMissionCompleted(player, mission)
			end
		end
	end

	if changed then
		-- 클라이언트에 미션 업데이트
		self:SendMissionUpdate(player)
	end
end

-- 미션 완료 보상
function ProgressionService:_onMissionCompleted(player: Player, mission: any)
	-- 코인 보상
	PlayerDataService:AddCoins(player, mission.reward)

	-- XP 보상
	self:AddXP(player, GameConstants.LEVEL.XP_PER_MISSION)

	print(`[ProgressionService] {player.Name} completed mission: {mission.name} (+{mission.reward} coins)`)
end

-- 미션 데이터 전송
function ProgressionService:SendMissionUpdate(player: Player)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData or not playerData.dailyMissions then
		return
	end

	RemoteEvents.MissionUpdate:FireClient(player, {
		missions = playerData.dailyMissions,
	})
end

-- ==================== 업적 시스템 ====================

-- 업적 달성 체크
function ProgressionService:CheckAchievements(player: Player)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	local completedList = playerData.completedAchievements or {}

	for _, achievement in GameConstants.ACHIEVEMENTS.LIST do
		-- 이미 달성한 업적 스킵
		local alreadyCompleted = false
		for _, completedId in completedList do
			if completedId == achievement.id then
				alreadyCompleted = true
				break
			end
		end
		if alreadyCompleted then
			continue
		end

		-- 조건 확인
		local currentValue = self:_getAchievementValue(playerData, achievement.condition)
		if currentValue >= achievement.target then
			self:_unlockAchievement(player, achievement)
		end
	end
end

-- 업적 조건 값 가져오기
function ProgressionService:_getAchievementValue(playerData: any, condition: string): number
	if condition == "games_played" then
		return playerData.gamesPlayed or 0
	elseif condition == "high_score" then
		return playerData.highScore or 0
	elseif condition == "total_coins" then
		return playerData.totalCoinsCollected or 0
	elseif condition == "total_distance" then
		return playerData.totalDistance or 0
	elseif condition == "level" then
		return playerData.level or 1
	end
	return 0
end

-- 업적 달성 처리
function ProgressionService:_unlockAchievement(player: Player, achievement: any)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	-- 달성 목록에 추가
	if not playerData.completedAchievements then
		playerData.completedAchievements = {}
	end
	table.insert(playerData.completedAchievements :: { string }, achievement.id)

	-- 보상 지급
	if achievement.rewardGems > 0 then
		PlayerDataService:AddGems(player, achievement.rewardGems)
	end
	if achievement.rewardXP > 0 then
		self:AddXP(player, achievement.rewardXP)
	end

	-- 클라이언트에 알림
	RemoteEvents.AchievementUnlocked:FireClient(player, {
		id = achievement.id,
		name = achievement.name,
		desc = achievement.desc,
		rewardGems = achievement.rewardGems,
		rewardXP = achievement.rewardXP,
	})

	print(`[ProgressionService] {player.Name} unlocked: {achievement.name}`)
end

-- ==================== 게임 이벤트 연동 ====================

-- 게임 종료 시 호출 (GameManager에서 호출)
function ProgressionService:OnGameEnd(player: Player, score: number, coinsEarned: number, distance: number)
	-- 게임 참여 XP
	self:AddXP(player, GameConstants.LEVEL.XP_PER_GAME)

	-- 점수 기반 XP
	local scoreXP = math.floor(score / 100) * GameConstants.LEVEL.XP_PER_SCORE_100
	if scoreXP > 0 then
		self:AddXP(player, scoreXP)
	end

	-- 미션 진행도 업데이트
	self:UpdateMissionProgress(player, "play_games", 1)
	self:UpdateMissionProgress(player, "collect_coins", coinsEarned)
	self:UpdateMissionProgress(player, "score_reach", score)
	self:UpdateMissionProgress(player, "distance_run", math.floor(distance))

	-- 업적 체크
	self:CheckAchievements(player)
end

-- 니어미스 시 호출
function ProgressionService:OnNearMiss(player: Player)
	self:UpdateMissionProgress(player, "near_miss", 1)
end

-- 콤보 달성 시 호출
function ProgressionService:OnComboReached(player: Player, combo: number)
	self:UpdateMissionProgress(player, "combo_reach", combo)
end

-- ==================== 데이터 요청 ====================

-- 전체 진행도 데이터 전송
function ProgressionService:SendProgressionData(player: Player)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	-- 미션 초기화 (필요 시)
	self:InitDailyMissions(player)

	local completedAchievements = playerData.completedAchievements or {}

	-- 업적 목록 (달성 여부 포함)
	local achievementsData = {}
	for _, ach in GameConstants.ACHIEVEMENTS.LIST do
		local isCompleted = false
		for _, completedId in completedAchievements do
			if completedId == ach.id then
				isCompleted = true
				break
			end
		end

		local currentValue = self:_getAchievementValue(playerData, ach.condition)

		table.insert(achievementsData, {
			id = ach.id,
			name = ach.name,
			desc = ach.desc,
			target = ach.target,
			current = math.min(currentValue, ach.target),
			completed = isCompleted,
			rewardGems = ach.rewardGems,
		})
	end

	RemoteEvents.ProgressionDataResponse:FireClient(player, {
		level = playerData.level or 1,
		xp = playerData.xp or 0,
		xpToNext = self:GetXPToNextLevel(playerData.level or 1),
		missions = playerData.dailyMissions or {},
		achievements = achievementsData,
	})
end

-- 진행도 데이터 요청 이벤트 핸들러
RemoteEvents.ProgressionDataRequest.OnServerEvent:Connect(function(player: Player)
	if not RateLimiter.Check(player, "ProgressionDataRequest", 1) then
		return
	end

	ProgressionService:SendProgressionData(player)
end)

print("[ProgressionService] Initialized")

return ProgressionService

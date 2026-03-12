--!strict
-- BossRunService
-- 보스 런 서버 로직: 세션 관리, 점수 추적, 보상 지급

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScenarioConstants = require(ReplicatedStorage.Shared.Constants.ScenarioConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)

local BossRunService = {}

type BossRunSession = {
	player: Player,
	chapterId: string,
	targetScore: number,
	timeLimit: number,
	startTime: number,
	playerScore: number,
	bossScore: number,
	speedMultiplier: number,
	lives: number,
	isActive: boolean,
	lastUpdateTime: number,
}

-- 활성 보스 런 세션 (플레이어별)
local activeBossRuns: { [Player]: BossRunSession } = {}

-- ==================== 보스 런 시작 ====================

function BossRunService:StartBossRun(player: Player, chapterId: string)
	local bossConfig = ScenarioConstants.BOSS_RUN
	local targetScore = bossConfig.TARGET_SCORES[chapterId]
	if not targetScore then
		warn(`[BossRunService] Unknown chapterId for boss run: {chapterId}`)
		return
	end

	-- 기존 세션이 있으면 정리
	if activeBossRuns[player] then
		activeBossRuns[player].isActive = false
		activeBossRuns[player] = nil
	end

	local session: BossRunSession = {
		player = player,
		chapterId = chapterId,
		targetScore = targetScore,
		timeLimit = bossConfig.TIME_LIMIT,
		startTime = tick(),
		playerScore = 0,
		bossScore = 0,
		speedMultiplier = bossConfig.SPEED_MULTIPLIER,
		lives = bossConfig.LIVES,
		isActive = true,
		lastUpdateTime = 0,
	}

	activeBossRuns[player] = session

	-- 클라이언트에 보스 런 시작 알림 (bossIntro 컷씬 포함)
	local cutscene = ScenarioConstants.CUTSCENES[chapterId]
		and ScenarioConstants.CUTSCENES[chapterId].bossIntro

	RemoteEvents.BossRunStart:FireClient(player, {
		chapterId = chapterId,
		bossName = bossConfig.BOSS_NAMES[chapterId],
		targetScore = targetScore,
		timeLimit = bossConfig.TIME_LIMIT,
		speedMultiplier = bossConfig.SPEED_MULTIPLIER,
		lives = bossConfig.LIVES,
		cutscene = cutscene,
	})

	print(`[BossRunService] Boss run started for {player.Name}: {chapterId} (target: {targetScore})`)
end

-- ==================== 업데이트 (GameManager Heartbeat에서 호출) ====================

function BossRunService:Update(deltaTime: number)
	local now = tick()

	for player, session in activeBossRuns do
		if not session.isActive then
			continue
		end

		local elapsed = now - session.startTime

		-- 타임아웃 체크
		if elapsed >= session.timeLimit then
			self:_endBossRun(player, false)
			continue
		end

		-- 보스 점수 시뮬레이션 (목표의 80%까지 선형 증가)
		session.bossScore = math.floor((elapsed / session.timeLimit) * session.targetScore * 0.80)

		-- 2초마다 클라이언트에 점수 업데이트
		if now - session.lastUpdateTime >= 2 then
			session.lastUpdateTime = now
			RemoteEvents.BossRunScoreUpdate:FireClient(player, {
				playerScore = session.playerScore,
				bossScore = session.bossScore,
				timeRemaining = math.max(0, session.timeLimit - elapsed),
			})
		end
	end
end

-- ==================== 점수 동기화 (GameManager에서 호출) ====================

function BossRunService:AddScore(player: Player, score: number)
	local session = activeBossRuns[player]
	if not session or not session.isActive then
		return
	end

	session.playerScore = score

	-- 목표 점수 달성 체크
	if session.playerScore >= session.targetScore then
		self:_endBossRun(player, true)
	end
end

-- ==================== 라이프 감소 (GameManager 장애물 충돌 시 호출) ====================

function BossRunService:OnHit(player: Player)
	local session = activeBossRuns[player]
	if not session or not session.isActive then
		return
	end

	session.lives -= 1
	print(`[BossRunService] {player.Name} hit! Boss run lives remaining: {session.lives}`)

	if session.lives <= 0 then
		self:_endBossRun(player, false)
	end
end

-- ==================== 보스 런 종료 ====================

function BossRunService:_endBossRun(player: Player, success: boolean)
	local session = activeBossRuns[player]
	if not session then
		return
	end

	session.isActive = false
	local chapterId = session.chapterId
	local rewards: { coins: number, gems: number }? = nil

	if success then
		-- 보상 지급
		rewards = ScenarioConstants.BOSS_RUN.CLEAR_REWARDS[chapterId]
		local playerData = PlayerDataService:GetPlayerData(player)
		if playerData and rewards then
			playerData.coins = (playerData.coins or 0) + rewards.coins
			playerData.gems = (playerData.gems or 0) + rewards.gems

			-- bossRunCompleted 마킹
			if not playerData.bossRunCompleted then
				playerData.bossRunCompleted = {}
			end
			playerData.bossRunCompleted[chapterId] = true

			-- highScore 갱신 (챕터 잠금 해제 minScore 조건 충족을 위해)
			if session.playerScore > (playerData.highScore or 0) then
				playerData.highScore = session.playerScore
			end

			RemoteEvents.GemsUpdated:FireClient(player, { gems = playerData.gems })
		end

		print(`[BossRunService] {player.Name} CLEARED boss run: {chapterId}! Rewards: coins={rewards and rewards.coins}, gems={rewards and rewards.gems}`)
	else
		print(`[BossRunService] {player.Name} FAILED boss run: {chapterId}`)
	end

	-- 결과 컷씬
	local cutsceneKey = if success then "bossWin" else "bossLose"
	local cutscene = ScenarioConstants.CUTSCENES[chapterId]
		and ScenarioConstants.CUTSCENES[chapterId][cutsceneKey]

	RemoteEvents.BossRunResult:FireClient(player, {
		success = success,
		playerScore = session.playerScore,
		targetScore = session.targetScore,
		chapterId = chapterId,
		rewards = rewards,
		cutscene = cutscene,
	})

	-- 세션 제거
	activeBossRuns[player] = nil

	-- 성공 시: ScenarioService에 챕터 완료 알리기 (지연)
	if success then
		task.delay(3, function()
			-- 챕터 완료 처리는 ScenarioService가 담당
			-- bossRunCompleted 플래그가 설정된 상태이므로
			-- ScenarioService의 _checkChapterCompletion이 다음 퀘스트 완료 시 챕터 클리어 처리
			-- 또는 즉시 챕터 완료 체크 트리거
			local ScenarioService = require(script.Parent.ScenarioService)
			ScenarioService:TriggerChapterCompletion(player, chapterId)
		end)
	end
end

-- ==================== 상태 조회 ====================

function BossRunService:IsBossRunActive(player: Player): boolean
	local session = activeBossRuns[player]
	return session ~= nil and session.isActive
end

function BossRunService:GetActiveSession(player: Player): BossRunSession?
	return activeBossRuns[player]
end

-- ==================== 원격 이벤트 ====================

function BossRunService:SetupRemoteEvents()
	RemoteEvents.BossRunRetry.OnServerEvent:Connect(function(player: Player, data: any)
		if type(data) ~= "table" or type(data.chapterId) ~= "string" then
			return
		end
		self:StartBossRun(player, data.chapterId)
	end)

	RemoteEvents.BossRunGiveUp.OnServerEvent:Connect(function(player: Player)
		local session = activeBossRuns[player]
		if session then
			self:_endBossRun(player, false)
		end
	end)

	print("[BossRunService] Remote events connected")
end

-- ==================== 플레이어 퇴장 정리 ====================

function BossRunService:OnPlayerRemoving(player: Player)
	activeBossRuns[player] = nil
end

return BossRunService

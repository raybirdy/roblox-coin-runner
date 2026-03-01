--!strict
-- Game Manager
-- 게임 전체 흐름 관리 (플레이어별 게임 세션)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ChunkService = require(script.Parent.ChunkService)
local CoinService = require(script.Parent.CoinService)
local ObstacleService = require(script.Parent.ObstacleService)
local PowerupService = require(script.Parent.PowerupService)
local NPCService = require(script.Parent.NPCService)
local TutorialService = require(script.Parent.TutorialService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local LobbyService = require(script.Parent.LobbyService)
local _ShopService = require(script.Parent.ShopService)
local BackgroundService = require(script.Parent.BackgroundService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MonetizationService = require(script.Parent.MonetizationService)
local ProgressionService = require(script.Parent.ProgressionService)
local ScenarioService = require(script.Parent.ScenarioService)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local GameManager = {}

type ScenarioStatBonuses = {
	speed: number,
	jump: number,
	coinValue: number,
	magnetRadius: number,
	maxLives: number,
	feverGauge: number,
}

-- 플레이어별 게임 세션 데이터
type GameSession = {
	player: Player,
	chunkService: any, -- ChunkService
	coinService: any, -- CoinService
	obstacleService: any, -- ObstacleService
	powerupService: any, -- PowerupService
	npcService: any, -- NPCService
	tutorialService: any, -- TutorialService
	backgroundService: any, -- BackgroundService
	isPlaying: boolean,
	startTime: number,
	startPosition: Vector3, -- 시작 위치 (거리 계산용)
	score: number,
	coins: number,
	lives: number,
	reviveCount: number, -- 부활 횟수
	startPowerups: { string }?, -- 게임 시작 시 사용할 파워업 목록
	comboCount: number, -- 연속 코인 수집 콤보
	lastCoinTime: number, -- 마지막 코인 수집 시간
	nearMissedObstacles: { [any]: boolean }, -- 니어미스 처리된 장애물 추적
	consecutiveHits: number, -- 연속 피격 횟수 (자비 청크용)
	nearRecordAlerted: boolean, -- Phase 2: near record alert sent
	-- Fever mode
	isFever: boolean,
	feverEndTime: number,
	feverCooldownEnd: number,
	-- Near miss chain
	nearMissChain: number,
	lastNearMissTime: number,
	-- Perfect run
	lastHitDistance: number,
	perfectRunAwarded: { [number]: boolean },
	-- Bonus score accumulator (near miss + combo bonuses)
	bonusScore: number,
	-- Phase B: Zone + Events + Stats
	currentZoneIndex: number,
	lastEventTime: number,
	nearMissCount: number,
	maxCombo: number,
	feverCount: number,
	-- Scenario
	powerupsCollected: number,
	scenarioStatBonuses: ScenarioStatBonuses,
	-- Skills
	unlockedSkillsSet: { [string]: boolean },
	lastShieldRegenTime: number,
	feverThreshold: number,
}

local activeSessions: { [Player]: GameSession } = {}

-- 위로 보상 추적 (플레이어별 연속 빠른 게임오버 횟수)
local consolationTracker: { [Player]: number } = {}
local globalTutorialService = TutorialService.new()

-- TutorialService에 PlayerDataService 연결
globalTutorialService:SetPlayerDataService(PlayerDataService)

-- 로비 초기화
LobbyService:Initialize()

-- 포탈 터치 감지 설정
local portalDebounce: { [Player]: number } = {}
local PORTAL_DEBOUNCE_TIME = 2 -- 2초 디바운스

local function setupPortalDetection()
	local portalTrigger = LobbyService:GetPortalTrigger()
	if portalTrigger then
		portalTrigger.Touched:Connect(function(hit: BasePart)
			local character = hit.Parent :: Model?
			if not character then
				return
			end

			local player = Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end

			-- 이미 게임 중이면 무시
			if activeSessions[player] then
				return
			end

			-- 디바운스 체크
			local now = tick()
			if portalDebounce[player] and (now - portalDebounce[player]) < PORTAL_DEBOUNCE_TIME then
				return
			end
			portalDebounce[player] = now

			-- 게임 시작 요청 처리
			print(`[GameManager] Portal touched by {player.Name}`)
			RemoteEvents.PortalEnter:FireClient(player)
		end)
		print("[GameManager] Portal detection set up")
	end
end

-- 포탈 터치 후 게임 시작 요청
RemoteEvents.PortalEnter.OnServerEvent:Connect(function(player: Player, data: { startPowerups: { string }? }?)
	print(`[GameManager] Portal enter confirmed by {player.Name}`)

	-- 입력 검증 (data는 nil 허용)
	if data ~= nil and type(data) ~= "table" then
		return
	end

	-- 시작 파워업 검증 및 사용
	local validPowerups: { string } = {}
	if data and type(data.startPowerups) == "table" then
		for _, powerupId in data.startPowerups do
			if PlayerDataService:UseStartPowerup(player, powerupId) then
				table.insert(validPowerups, powerupId)
				print(`[GameManager] Using start powerup: {powerupId}`)
			end
		end
	end

	-- 기존 세션이 있으면 정리
	if activeSessions[player] then
		GameManager.EndGame(player)
	end

	-- 새 세션 생성 (기존 GameStart 로직과 동일)
	local chunkService = ChunkService.new()
	local coinService = CoinService.new(player)
	local obstacleService = ObstacleService.new(player)
	local powerupService = PowerupService.new(player)
	local npcService = NPCService.new(player)
	local backgroundService = BackgroundService.new()

	-- 시작 위치 설정 및 플레이어 텔레포트
	local startPosition = Vector3.new(0, 2.5, GameConstants.PLAYER.Z_POSITION)
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.CFrame = CFrame.new(startPosition) * CFrame.Angles(0, math.rad(-90), 0)
			print(`[GameManager] Teleported {player.Name} to start position`)
		end
	end

	-- 시나리오 스탯 보너스 + 스킬 가져오기
	local statBonuses = ScenarioService:GetStatBonuses(player)
	local unlockedSkills = ScenarioService:GetUnlockedSkills(player)
	local unlockedSkillsSet: { [string]: boolean } = {}
	for _, skillId in unlockedSkills do
		unlockedSkillsSet[skillId] = true
	end
	local feverThreshold = if unlockedSkillsSet["fever_boost"]
		then math.floor(GameConstants.FEVER.COMBO_THRESHOLD / 1.3)
		else GameConstants.FEVER.COMBO_THRESHOLD

	local session: GameSession = {
		player = player,
		chunkService = chunkService,
		coinService = coinService,
		obstacleService = obstacleService,
		powerupService = powerupService,
		npcService = npcService,
		tutorialService = globalTutorialService,
		backgroundService = backgroundService,
		isPlaying = true,
		startTime = tick(),
		startPosition = startPosition,
		score = 0,
		coins = 0,
		lives = GameConstants.LIFE.STARTING_LIVES + statBonuses.maxLives,
		reviveCount = 0,
		startPowerups = validPowerups,
		comboCount = 0,
		lastCoinTime = 0,
		nearMissedObstacles = {},
		consecutiveHits = 0,
		nearRecordAlerted = false,
		isFever = false,
		feverEndTime = 0,
		feverCooldownEnd = 0,
		nearMissChain = 0,
		lastNearMissTime = 0,
		lastHitDistance = 0,
		perfectRunAwarded = {},
		bonusScore = 0,
		currentZoneIndex = 1,
		lastEventTime = 0,
		nearMissCount = 0,
		maxCombo = 0,
		feverCount = 0,
		powerupsCollected = 0,
		scenarioStatBonuses = statBonuses,
		unlockedSkillsSet = unlockedSkillsSet,
		lastShieldRegenTime = tick(),
		feverThreshold = feverThreshold,
	}

	activeSessions[player] = session

	-- 청크 서비스에 코인/장애물/파워업/NPC/배경 서비스 연결
	chunkService:SetCoinService(coinService)
	chunkService:SetObstacleService(obstacleService)
	chunkService:SetPowerupService(powerupService)
	chunkService:SetNPCService(npcService)
	chunkService:SetBackgroundService(backgroundService)

	-- 배경 서비스 시작
	backgroundService:StartGame()

	-- 청크 서비스 시작
	chunkService:StartGame()

	-- 파워업 서비스 시작
	powerupService:StartGame()

	-- Initial zone setup
	chunkService:SetCurrentZone(1)

	-- 시작 파워업 적용
	for _, powerupId in validPowerups do
		if powerupId == "start_magnet" then
			powerupService:ActivatePowerup("Magnet")
		elseif powerupId == "start_shield" then
			powerupService:ActivatePowerup("Shield")
		elseif powerupId == "start_double" then
			powerupService:ActivatePowerup("DoubleCoin")
		end
	end

	-- 튜토리얼 필요 여부 확인
	local needsTutorial = globalTutorialService:NeedsTutorial(player)

	-- 클라이언트에 게임 시작 알림
	RemoteEvents.GameStart:FireClient(player, {
		startTime = session.startTime,
		lives = session.lives,
		startTutorial = needsTutorial,
		startPosition = startPosition,
		startPowerups = validPowerups,
		scenarioStatBonuses = statBonuses,
		unlockedSkills = unlockedSkills,
	})

	print(`[GameManager] Game started for {player.Name} via portal`)
end)

-- 로비 복귀 처리
function GameManager.ReturnToLobby(player: Player)
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.CFrame = CFrame.new(GameConstants.LOBBY.SPAWN_POSITION) * CFrame.Angles(0, math.rad(-90), 0)
			print(`[GameManager] {player.Name} returned to lobby`)
		end
	end

	-- 클라이언트에 로비 복귀 알림
	RemoteEvents.ReturnToLobby:FireClient(player)
end

-- 클라이언트에서 로비 복귀 요청
RemoteEvents.ReturnToLobby.OnServerEvent:Connect(function(player: Player)
	print(`[GameManager] Return to lobby requested by {player.Name}`)

	-- 활성 세션이 남아있으면 정리 (부활 대기 중 로비 복귀 등)
	if activeSessions[player] then
		print(`[GameManager] Cleaning up active session for {player.Name} before returning to lobby`)
		GameManager.EndGame(player)
	end

	GameManager.ReturnToLobby(player)
end)

-- 상점 터치 감지 설정
local shopDebounce: { [Player]: number } = {}
local SHOP_DEBOUNCE_TIME = 2 -- 2초 디바운스

local function setupShopDetection()
	local shopTrigger = LobbyService:GetShopTrigger()
	if shopTrigger then
		shopTrigger.Touched:Connect(function(hit: BasePart)
			local character = hit.Parent :: Model?
			if not character then
				return
			end

			local player = Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end

			-- 게임 중이면 무시
			if activeSessions[player] then
				return
			end

			-- 디바운스 체크
			local lastOpen = shopDebounce[player]
			if lastOpen and (tick() - lastOpen) < SHOP_DEBOUNCE_TIME then
				return
			end
			shopDebounce[player] = tick()

			-- 상점 열기 알림
			RemoteEvents.ShopOpen:FireClient(player)
		end)
		print("[GameManager] Shop detection set up")
	end
end

-- 초기화 후 포탈/상점 감지 설정
task.defer(function()
	setupPortalDetection()
	setupShopDetection()
end)

-- 게임 시작 요청 처리
RemoteEvents.GameStart.OnServerEvent:Connect(function(player: Player)
	if not RateLimiter.Check(player, "GameStart", 2) then
		return
	end

	print(`[GameManager] Game start requested by {player.Name}`)

	-- 기존 세션이 있으면 정리
	if activeSessions[player] then
		GameManager.EndGame(player)
	end

	-- 새 세션 생성
	local chunkService = ChunkService.new()
	local coinService = CoinService.new(player)
	local obstacleService = ObstacleService.new(player)
	local powerupService = PowerupService.new(player)
	local npcService = NPCService.new(player)
	local backgroundService = BackgroundService.new()

	-- 시작 위치 설정 및 플레이어 텔레포트
	local startPosition = Vector3.new(0, 2.5, GameConstants.PLAYER.Z_POSITION)
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			-- 플레이어를 시작 위치로 텔레포트 (게임 재시작 시 필수)
			hrp.CFrame = CFrame.new(startPosition) * CFrame.Angles(0, math.rad(-90), 0)
			print(`[GameManager] Teleported {player.Name} to start position`)
		end
	end

	-- 시나리오 스탯 보너스 + 스킬 가져오기
	local statBonuses = ScenarioService:GetStatBonuses(player)
	local unlockedSkills = ScenarioService:GetUnlockedSkills(player)
	local unlockedSkillsSet2: { [string]: boolean } = {}
	for _, skillId in unlockedSkills do
		unlockedSkillsSet2[skillId] = true
	end
	local feverThreshold2 = if unlockedSkillsSet2["fever_boost"]
		then math.floor(GameConstants.FEVER.COMBO_THRESHOLD / 1.3)
		else GameConstants.FEVER.COMBO_THRESHOLD

	local session: GameSession = {
		player = player,
		chunkService = chunkService,
		coinService = coinService,
		obstacleService = obstacleService,
		powerupService = powerupService,
		npcService = npcService,
		tutorialService = globalTutorialService,
		backgroundService = backgroundService,
		isPlaying = true,
		startTime = tick(),
		startPosition = startPosition,
		score = 0,
		coins = 0,
		lives = GameConstants.LIFE.STARTING_LIVES + statBonuses.maxLives,
		reviveCount = 0,
		comboCount = 0,
		lastCoinTime = 0,
		nearMissedObstacles = {},
		consecutiveHits = 0,
		nearRecordAlerted = false,
		isFever = false,
		feverEndTime = 0,
		feverCooldownEnd = 0,
		nearMissChain = 0,
		lastNearMissTime = 0,
		lastHitDistance = 0,
		perfectRunAwarded = {},
		bonusScore = 0,
		currentZoneIndex = 1,
		lastEventTime = 0,
		nearMissCount = 0,
		maxCombo = 0,
		feverCount = 0,
		powerupsCollected = 0,
		scenarioStatBonuses = statBonuses,
		unlockedSkillsSet = unlockedSkillsSet2,
		lastShieldRegenTime = tick(),
		feverThreshold = feverThreshold2,
	}

	activeSessions[player] = session

	-- 청크 서비스에 코인/장애물/파워업/NPC/배경 서비스 연결
	chunkService:SetCoinService(coinService)
	chunkService:SetObstacleService(obstacleService)
	chunkService:SetPowerupService(powerupService)
	chunkService:SetNPCService(npcService)
	chunkService:SetBackgroundService(backgroundService)

	-- 배경 서비스 시작
	backgroundService:StartGame()

	-- 청크 서비스 시작
	chunkService:StartGame()

	-- 파워업 서비스 시작
	powerupService:StartGame()

	-- Initial zone setup
	chunkService:SetCurrentZone(1)

	-- 튜토리얼 필요 여부 확인
	local needsTutorial = globalTutorialService:NeedsTutorial(player)

	-- 클라이언트에 게임 시작 알림
	RemoteEvents.GameStart:FireClient(player, {
		startTime = session.startTime,
		lives = session.lives,
		startTutorial = needsTutorial,
		startPosition = startPosition,
		scenarioStatBonuses = statBonuses,
		unlockedSkills = unlockedSkills,
	})

	print(`[GameManager] Game started for {player.Name}`)
end)

-- 게임 오버 요청 처리
RemoteEvents.GameOver.OnServerEvent:Connect(function(player: Player)
	if not RateLimiter.Check(player, "GameOver", 1) then
		return
	end

	print(`[GameManager] Game over requested by {player.Name}`)
	GameManager.EndGame(player)
end)

-- 부활 요청 처리
RemoteEvents.Revive.OnServerEvent:Connect(function(player: Player)
	if not RateLimiter.Check(player, "Revive", 2) then
		return
	end

	local session = activeSessions[player]
	if not session then
		warn(`[GameManager] No session found for {player.Name} to revive`)
		RemoteEvents.Revive:FireClient(player, { success = false, reason = "no_session" })
		return
	end

	-- 부활 횟수 체크
	if session.reviveCount >= GameConstants.REVIVE.MAX_REVIVES then
		print(`[GameManager] {player.Name} has no revives left`)
		RemoteEvents.Revive:FireClient(player, { success = false, reason = "no_revives" })
		return
	end

	-- 부활 재화 차감: 부활권 우선 → 젬 차감
	local reviveMethod = "none"
	if PlayerDataService:UseReviveTicket(player) then
		reviveMethod = "ticket"
		print(`[GameManager] {player.Name} used revive ticket`)
	elseif PlayerDataService:SpendGems(player, GameConstants.SHOP.REVIVE_GEM_COST) then
		reviveMethod = "gems"
		local currentGems = PlayerDataService:GetGems(player)
		RemoteEvents.GemsUpdated:FireClient(player, { gems = currentGems })
		print(`[GameManager] {player.Name} spent {GameConstants.SHOP.REVIVE_GEM_COST} gems to revive`)
	else
		print(`[GameManager] {player.Name} has no revive tickets or gems`)
		RemoteEvents.Revive:FireClient(player, { success = false, reason = "no_currency" })
		return
	end

	-- 부활 처리
	session.reviveCount += 1
	session.lives = 1 -- 라이프 1개로 부활
	session.isPlaying = true

	-- 무적 상태 설정
	if session.obstacleService then
		session.obstacleService:OnObstacleHit() -- 무적 시간 활성화
	end

	print(`[GameManager] {player.Name} revived! (Revive #{session.reviveCount})`)

	-- 클라이언트에 부활 성공 알림
	RemoteEvents.Revive:FireClient(player, {
		success = true,
		lives = session.lives,
		revivesLeft = GameConstants.REVIVE.MAX_REVIVES - session.reviveCount,
		reviveMethod = reviveMethod,
	})

	-- 라이프 업데이트 알림
	RemoteEvents.LifeUpdate:FireClient(player, {
		lives = session.lives,
	})
end)

-- 게임 종료
function GameManager.EndGame(player: Player)
	local session = activeSessions[player]
	if not session then
		return
	end

	session.isPlaying = false

	-- 최종 점수 계산
	local finalScore = session.score
	local earnedCoins = session.coins
	local currentX = (
		player.Character
			and player.Character:FindFirstChild("HumanoidRootPart")
			and (player.Character.HumanoidRootPart :: BasePart).Position.X
		or session.startPosition.X
	)
	local distance = math.max(0, math.floor(currentX - session.startPosition.X))

	-- 플레이어 데이터 업데이트 및 저장
	PlayerDataService:OnGameEnd(player, finalScore, earnedCoins, distance)

	-- 최고 점수 가져오기
	local playerData = PlayerDataService:GetPlayerData(player)
	local highScore = playerData and playerData.highScore or 0

	-- 글로벌 리더보드 업데이트
	LeaderboardService:UpdateScore(player, highScore)

	-- 진행도 업데이트 (레벨, 미션, 업적)
	ProgressionService:OnGameEnd(player, finalScore, earnedCoins, distance)

	-- 시나리오 퀘스트 진행도 업데이트
	local sessionDuration = math.floor(tick() - session.startTime)
	local wasNoHit = session.lastHitDistance == 0 and finalScore > 0
	ScenarioService:UpdateQuestProgress(player, "play_games", 1)
	ScenarioService:UpdateQuestProgress(player, "score_reach", finalScore)
	ScenarioService:UpdateQuestProgress(player, "collect_coins", math.floor(session.coins))
	ScenarioService:UpdateQuestProgress(player, "near_miss", session.nearMissCount)
	ScenarioService:UpdateQuestProgress(player, "combo_ch", session.maxCombo)
	ScenarioService:UpdateQuestProgress(player, "distance_ch", distance)
	ScenarioService:UpdateQuestProgress(player, "survive_ch", sessionDuration)
	ScenarioService:UpdateQuestProgress(player, "powerup_ch", session.powerupsCollected)
	if wasNoHit then
		ScenarioService:UpdateQuestProgress(player, "no_hit_run_ch", 1)
	end

	-- 청크, 코인, 장애물, 파워업, NPC 정리
	if session.chunkService then
		session.chunkService:Destroy()
	end
	if session.coinService then
		session.coinService:Destroy()
	end
	if session.obstacleService then
		session.obstacleService:Destroy()
	end
	if session.powerupService then
		session.powerupService:Destroy()
	end
	if session.npcService then
		session.npcService:Destroy()
	end
	if session.backgroundService then
		session.backgroundService:Cleanup()
	end

	-- 신기록 여부 확인
	local isNewRecord = finalScore > 0 and finalScore >= highScore

	-- Phase 2: 신기록 축하 이벤트
	if isNewRecord then
		RemoteEvents.NewRecordCelebration:FireClient(player, {
			newRecord = finalScore,
		})
	end

	-- 위로 보상 체크
	local consolationReward = 0
	if finalScore < GameConstants.CONSOLATION.QUICK_DEATH_SCORE then
		consolationTracker[player] = (consolationTracker[player] or 0) + 1
		if consolationTracker[player] >= GameConstants.CONSOLATION.THRESHOLD then
			consolationReward = GameConstants.CONSOLATION.REWARD_COINS
			PlayerDataService:AddCoins(player, consolationReward)
			consolationTracker[player] = 0
			print(`[GameManager] Consolation reward: +{consolationReward} coins for {player.Name}`)
		end
	else
		consolationTracker[player] = 0
	end

	-- 클라이언트에 게임 오버 알림
	local playerData = PlayerDataService:GetPlayerData(player)
	RemoteEvents.GameOver:FireClient(player, {
		finalScore = finalScore,
		earnedCoins = earnedCoins,
		highScore = highScore,
		distance = distance,
		isNewRecord = isNewRecord,
		-- Phase B: 추가 통계
		nearMissCount = session.nearMissCount,
		maxCombo = session.maxCombo,
		feverCount = session.feverCount,
		zoneName = GameConstants.ZONE_THEMES[session.currentZoneIndex].displayName,
		almostMessage = GameManager._generateAlmostMessage(session),
		loginStreak = playerData and playerData.loginStreak or 0,
	})

	-- 위로 보상 알림 (별도 이벤트)
	if consolationReward > 0 then
		RemoteEvents.ConsolationReward:FireClient(player, { coins = consolationReward })
		-- 업데이트된 데이터 재전송
		RemoteEvents.PlayerDataLoaded:FireClient(player, PlayerDataService:GetPlayerData(player))
	end

	-- 세션 제거
	activeSessions[player] = nil

	print(`[GameManager] Game ended for {player.Name}: Score={finalScore}, Coins={earnedCoins}, HighScore={highScore}`)
	-- 로비 복귀는 Play Again 버튼 클릭 시 처리됨
end

-- 플레이어 퇴장 시 세션 정리
Players.PlayerRemoving:Connect(function(player: Player)
	if activeSessions[player] then
		GameManager.EndGame(player)
	end
	shopDebounce[player] = nil
	portalDebounce[player] = nil
	consolationTracker[player] = nil
	RateLimiter.CleanupPlayer(player)
end)

-- 메인 업데이트 루프 (모든 활성 세션)
RunService.Heartbeat:Connect(function(deltaTime: number)
	for player, session in activeSessions do
		if not session.isPlaying then
			continue
		end

		-- 플레이어 캐릭터 확인
		local character = player.Character
		if not character then
			continue
		end

		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end

		-- 청크 관리
		local chunkService = session.chunkService
		local coinService = session.coinService
		local obstacleService = session.obstacleService
		local powerupService = session.powerupService

		-- 오래된 청크 정리
		chunkService:CleanupOldChunks(hrp.Position)

		-- 배경 요소 정리 (플레이어 위치 업데이트)
		local backgroundService = session.backgroundService
		if backgroundService then
			backgroundService:UpdatePlayerPosition(hrp.Position)
		end

		-- Phase B: Zone 전환 체크
		local elapsedTime = tick() - session.startTime
		local newZoneIndex = 1
		for i = #GameConstants.ZONE_THEMES, 1, -1 do
			if elapsedTime >= GameConstants.ZONE_THEMES[i].startTime then
				newZoneIndex = i
				break
			end
		end
		if newZoneIndex ~= session.currentZoneIndex then
			session.currentZoneIndex = newZoneIndex
			chunkService:SetCurrentZone(session.currentZoneIndex)
			local theme = GameConstants.ZONE_THEMES[newZoneIndex]
			RemoteEvents.ZoneTransition:FireClient(player, {
				zoneIndex = newZoneIndex,
				zoneName = theme.name,
				displayName = theme.displayName,
			})
			chunkService:RequestTransitionChunk()
		end

		-- Phase B: 이벤트 청크 확률 체크
		local eventCooldown = GameConstants.EVENT_CHUNKS.COOLDOWN
		if (tick() - session.lastEventTime) >= eventCooldown then
			if
				elapsedTime >= GameConstants.EVENT_CHUNKS.GIANT_COIN.MIN_TIME
				and math.random() < GameConstants.EVENT_CHUNKS.GIANT_COIN.CHANCE
			then
				session.lastEventTime = tick()
				chunkService:RequestEventChunk("GiantCoin")
				RemoteEvents.EventChunkAlert:FireClient(player, { eventType = "GiantCoin" })
			elseif
				elapsedTime >= GameConstants.EVENT_CHUNKS.COIN_RUSH.MIN_TIME
				and math.random() < GameConstants.EVENT_CHUNKS.COIN_RUSH.CHANCE
			then
				session.lastEventTime = tick()
				chunkService:RequestEventChunk("CoinRush")
				RemoteEvents.EventChunkAlert:FireClient(player, { eventType = "CoinRush" })
			end
		end

		-- 새 청크 생성 필요 시
		if chunkService:CheckSpawnNewChunk(hrp.Position) then
			chunkService:SpawnNextChunk()
		end

		-- 파워업 수집 체크
		local collectedPowerups = powerupService:CheckPowerupCollection(hrp.Position)
		for _, powerupData in collectedPowerups do
			-- 파워업 효과 활성화
			powerupService:ActivatePowerup(powerupData.powerupType)

			-- 클라이언트에 수집 알림
			RemoteEvents.PowerupCollected:FireClient(player, {
				powerupType = powerupData.powerupType,
			})

			print(`[GameManager] Player {player.Name} collected {powerupData.powerupType} powerup`)
		end
		-- 시나리오: 파워업 수집 횟수 추적
		session.powerupsCollected += #collectedPowerups

		-- 코인 수집 체크 (자석 효과 적용, 피버 시 초강력 자석)
		local magnetRadius = powerupService:GetMagnetRadius() + session.scenarioStatBonuses.magnetRadius
		if session.isFever then
			magnetRadius = math.max(magnetRadius, GameConstants.FEVER.MAGNET_RADIUS)
		end
		local collectedCoins = coinService:CheckCoinCollection(hrp.Position, magnetRadius)
		local coinMultiplier = powerupService:GetCoinMultiplier()
			* MonetizationService:GetCoinMultiplier(player)
			* (1 + session.scenarioStatBonuses.coinValue)
		if session.isFever then
			coinMultiplier *= GameConstants.FEVER.COIN_MULTIPLIER
		end
		for _, coinData in collectedCoins do
			-- 2배 코인 적용 (파워업 + VIP 배율)
			local actualValue = coinData.value * coinMultiplier

			-- 세션 데이터 업데이트
			session.coins += actualValue

			-- 클라이언트에 수집 알림
			RemoteEvents.CoinCollected:FireClient(player, {
				coinType = coinData.type,
				coinValue = actualValue,
				totalCoins = session.coins,
				isDoubled = coinMultiplier > 1,
			})

			print(
				`[GameManager] Player {player.Name} collected {coinData.type} coin (+{actualValue}){coinMultiplier > 1 and " (x2)" or ""}`
			)
		end

		-- Phase B: 거인 코인 수집 체크
		if coinService:CheckGiantCoinCollection(hrp.Position) then
			session.coins += GameConstants.EVENT_CHUNKS.GIANT_COIN.REWARD
			RemoteEvents.GiantCoinCollected:FireClient(player, {
				reward = GameConstants.EVENT_CHUNKS.GIANT_COIN.REWARD,
			})
		end

		-- 콤보 시스템
		if #collectedCoins > 0 then
			local now = tick()
			if now - session.lastCoinTime < GameConstants.SCORE.COMBO_TIMEOUT then
				session.comboCount += #collectedCoins
			else
				session.comboCount = #collectedCoins
			end
			session.lastCoinTime = now

			-- 콤보 마일스톤 보너스 체크
			local prevCombo = session.comboCount - #collectedCoins
			local comboBonus = 0
			if session.comboCount >= 50 and prevCombo < 50 then
				comboBonus = GameConstants.SCORE.COMBO_50_BONUS
			elseif session.comboCount >= 30 and prevCombo < 30 then
				comboBonus = GameConstants.SCORE.COMBO_30_BONUS
			elseif session.comboCount >= 10 and prevCombo < 10 then
				comboBonus = GameConstants.SCORE.COMBO_10_BONUS
			end

			if comboBonus > 0 then
				session.bonusScore += comboBonus
				print(`[GameManager] Combo {session.comboCount}x! +{comboBonus} bonus for {player.Name}`)
			end

			-- Phase B: 최대 콤보 추적
			session.maxCombo = math.max(session.maxCombo, session.comboCount)

			-- 피버 모드 발동 체크 (fever_boost 스킬: 낮은 임계값)
			if
				not session.isFever
				and session.comboCount >= session.feverThreshold
				and now > session.feverCooldownEnd
			then
				session.isFever = true
				session.feverEndTime = now + GameConstants.FEVER.DURATION
				session.feverCount += 1 -- Phase B: 피버 횟수 추적
				RemoteEvents.FeverStart:FireClient(player, {
					duration = GameConstants.FEVER.DURATION,
					speedBoost = GameConstants.FEVER.SPEED_BOOST,
				})
				print(`[GameManager] FEVER MODE activated for {player.Name}!`)
			end

			-- 피버 게이지 업데이트
			RemoteEvents.FeverGaugeUpdate:FireClient(player, {
				combo = session.comboCount,
				threshold = session.feverThreshold,
				onCooldown = now < session.feverCooldownEnd,
			})

			-- 콤보 미션 진행도 업데이트
			ProgressionService:OnComboReached(player, session.comboCount)

			-- 클라이언트에 콤보 상태 알림
			RemoteEvents.ComboUpdate:FireClient(player, {
				combo = session.comboCount,
				bonus = comboBonus > 0 and comboBonus or nil,
			})
		else
			-- 콤보 타임아웃 체크
			if session.comboCount > 0 and tick() - session.lastCoinTime >= GameConstants.SCORE.COMBO_TIMEOUT then
				session.comboCount = 0
				RemoteEvents.ComboUpdate:FireClient(player, { combo = 0 })
				RemoteEvents.FeverGaugeUpdate:FireClient(player, {
					combo = 0,
					threshold = session.feverThreshold,
					onCooldown = tick() < session.feverCooldownEnd,
				})
			end
		end

		-- 피버 모드 종료 체크
		if session.isFever and tick() >= session.feverEndTime then
			session.isFever = false
			session.feverCooldownEnd = tick() + GameConstants.FEVER.COOLDOWN
			session.comboCount = 0 -- 피버 종료 시 콤보 리셋
			RemoteEvents.FeverEnd:FireClient(player)
			RemoteEvents.FeverGaugeUpdate:FireClient(player, {
				combo = 0,
				threshold = session.feverThreshold,
				onCooldown = true,
			})
			print(`[GameManager] FEVER MODE ended for {player.Name}`)
		end

		-- shield_regen 스킬: 60초마다 쉴드 자동 재생
		if session.unlockedSkillsSet["shield_regen"] then
			local now2 = tick()
			if now2 - session.lastShieldRegenTime >= 60 and not powerupService:HasShield() then
				session.lastShieldRegenTime = now2
				powerupService:ActivatePowerup("Shield")
				RemoteEvents.ShieldRegenerated:FireClient(player)
				print(`[GameManager] Shield regenerated for {player.Name} (skill)`)
			end
		end

		-- 낙하 감지 (Y < -10 이면 낙사)
		local FALL_THRESHOLD = -10
		if hrp.Position.Y < FALL_THRESHOLD then
			print(`[GameManager] Player {player.Name} fell off! Y: {hrp.Position.Y}`)

			-- 즉시 게임 오버 (낙사는 부활 불가)
			session.lives = 0
			GameManager.EndGame(player)
			continue
		end

		-- 장애물 충돌 체크
		local isSliding = hrp:GetAttribute("IsSliding") or false
		local isMini = powerupService:IsMiniSizeActive()
		local hitObstacle = obstacleService:CheckObstacleCollision(hrp.Position, isSliding, isMini)

		if hitObstacle and session.lives > 0 then
			-- 피버 모드 무적 체크
			if session.isFever and GameConstants.FEVER.INVINCIBLE then
				-- 피버 무적으로 통과
				print(`[GameManager] Player {player.Name} passed through obstacle (FEVER)!`)
			-- 무적 상태 체크
			elseif powerupService:IsInvincible() then
				-- 무적으로 통과
				print(`[GameManager] Player {player.Name} passed through obstacle (Invincible)!`)
			-- 쉴드 사용 시도
			elseif powerupService:TryUseShield() then
				-- 쉴드로 방어 성공
				print(`[GameManager] Player {player.Name} blocked obstacle with shield!`)

				-- 클라이언트에 쉴드 사용 알림
				RemoteEvents.PowerupCollected:FireClient(player, {
					powerupType = "ShieldUsed",
				})
			else
				-- 라이프 감소
				session.lives -= 1
				obstacleService:OnObstacleHit()

				-- magnet_burst 스킬: 피격 시 주변 30 studs 코인 흡수
				if session.unlockedSkillsSet["magnet_burst"] then
					local burstCoins = session.coinService:BurstCollectCoins(hrp.Position, 30)
					local burstTotal = 0
					for _, burstCoinData in burstCoins do
						burstTotal += burstCoinData.value
					end
					if burstTotal > 0 then
						session.coins += burstTotal
						RemoteEvents.SkillActivated:FireClient(player, {
							skillId = "magnet_burst",
							value = math.floor(burstTotal),
						})
						print(`[GameManager] Magnet burst: +{burstTotal} coins for {player.Name}`)
					end
				end

				-- 퍼펙트 런 리셋 (피격 시 현재 거리 기록)
				local hitX = hrp.Position.X - session.startPosition.X
				session.lastHitDistance = math.max(0, math.floor(hitX))

				-- 연속 피격 추적 (자비 청크)
				session.consecutiveHits += 1
				if session.consecutiveHits >= GameConstants.LIFE.MERCY_CHUNK_THRESHOLD then
					session.chunkService:RequestMercyChunks(GameConstants.LIFE.MERCY_CHUNK_COUNT)
					session.consecutiveHits = 0
					print(`[GameManager] Mercy chunks activated for {player.Name}`)
				end

				-- 클라이언트에 라이프 업데이트 알림
				RemoteEvents.LifeUpdate:FireClient(player, {
					lives = session.lives,
				})

				print(`[GameManager] Player {player.Name} hit obstacle! Lives: {session.lives}`)

				-- 라이프 0이면 부활 제안 또는 게임 오버
				if session.lives <= 0 then
					local canRevive = session.reviveCount < GameConstants.REVIVE.MAX_REVIVES

					if canRevive then
						-- 부활 가능 - 게임 일시정지하고 부활 제안
						session.isPlaying = false
						print(`[GameManager] Player {player.Name} can revive - offering revive`)

						-- 현재 점수 계산 (UI 표시용)
						local reviveX = player.Character
								and player.Character:FindFirstChild("HumanoidRootPart")
								and (player.Character.HumanoidRootPart :: BasePart).Position.X
							or session.startPosition.X
						local reviveDist = math.max(0, math.floor(reviveX - session.startPosition.X))
						local reviveData = PlayerDataService:GetPlayerData(player)
						local reviveHS = reviveData and reviveData.highScore or 0

						RemoteEvents.GameOver:FireClient(player, {
							canRevive = true,
							revivesLeft = GameConstants.REVIVE.MAX_REVIVES - session.reviveCount,
							finalScore = session.score,
							earnedCoins = session.coins,
							highScore = reviveHS,
							distance = reviveDist,
							isNewRecord = session.score > 0 and session.score >= reviveHS,
						})
					else
						-- 부활 불가 - 게임 오버
						print(`[GameManager] Player {player.Name} has no lives or revives left, ending game`)
						GameManager.EndGame(player)
					end
				end
			end
		end

		-- 니어미스 감지 (장애물 근접 회피 보너스) + 체인 시스템
		local nearMisses = obstacleService:CheckNearMiss(hrp.Position, isSliding, session.nearMissedObstacles, isMini)
		for _, obstaclePart in nearMisses do
			session.nearMissedObstacles[obstaclePart] = true
			session.consecutiveHits = 0 -- 회피 성공 시 연속 피격 리셋
			session.nearMissCount += 1 -- Phase B: 니어미스 횟수 추적

			-- 체인 업데이트
			local now = tick()
			local chainTimeout = GameConstants.NEAR_MISS_CHAIN.CHAIN_TIMEOUT
			if now - session.lastNearMissTime < chainTimeout then
				session.nearMissChain = math.min(session.nearMissChain + 1, 5)
			else
				session.nearMissChain = 1
			end
			session.lastNearMissTime = now

			-- 체인 등급에 따른 보너스 결정
			local chainData = GameConstants.NEAR_MISS_CHAIN.GRADES[session.nearMissChain]
			local bonus = if chainData then chainData.bonus else GameConstants.SCORE.NEAR_MISS_BONUS
			local chainText = if chainData then chainData.text else "Close!"

			session.bonusScore += bonus

			-- 기존 NearMiss 이벤트 (호환)
			RemoteEvents.NearMiss:FireClient(player, {
				bonus = bonus,
			})

			-- 체인 이벤트 (강화 피드백)
			RemoteEvents.NearMissChain:FireClient(player, {
				chain = session.nearMissChain,
				bonus = bonus,
				text = chainText,
			})

			-- 미션 진행도 업데이트
			ProgressionService:OnNearMiss(player)

			print(`[GameManager] Near miss chain {session.nearMissChain}x! +{bonus} ({chainText}) for {player.Name}`)
		end

		-- Phase 2: 신기록 임박 알림 (1회만)
		if not session.nearRecordAlerted then
			local playerData = PlayerDataService:GetPlayerData(player)
			local highScore = playerData and playerData.highScore or 0
			if highScore > 0 and session.score / highScore >= GameConstants.NEAR_RECORD.THRESHOLD_RATIO then
				session.nearRecordAlerted = true
				RemoteEvents.NearRecordAlert:FireClient(player, {
					currentScore = session.score,
					highScore = highScore,
				})
			end
		end

		-- 점수 업데이트 (이동 거리 기반)
		local distanceTraveled = hrp.Position.X - session.startPosition.X
		local distanceScore = math.max(0, math.floor(distanceTraveled * GameConstants.SCORE.DISTANCE_MULTIPLIER))

		-- 퍼펙트 런 마일스톤 체크
		local noHitDistance = math.floor(distanceTraveled) - session.lastHitDistance
		for _, milestone in GameConstants.PERFECT_RUN.MILESTONES do
			if noHitDistance >= milestone.distance and not session.perfectRunAwarded[milestone.distance] then
				session.perfectRunAwarded[milestone.distance] = true
				session.coins += milestone.bonus
				RemoteEvents.PerfectRunBonus:FireClient(player, {
					distance = milestone.distance,
					bonus = milestone.bonus,
					title = milestone.title,
				})
				print(`[GameManager] Perfect Run: {milestone.title} +{milestone.bonus} for {player.Name}`)
			end
		end

		-- 총 점수 = 거리 점수 + 코인 점수 + 보너스 점수 (니어미스/콤보)
		session.score = distanceScore + session.coins + session.bonusScore

		-- 점수 변경 시 클라이언트에 업데이트 알림 (0.5초마다)
		if tick() % 0.5 < deltaTime then
			RemoteEvents.ScoreUpdate:FireClient(player, {
				score = session.score,
				distance = math.floor(distanceTraveled),
				coins = session.coins,
			})
		end
	end
end)

-- Phase B: "거의 다 왔어!" 메시지 생성
function GameManager._generateAlmostMessage(session: GameSession): string?
	local elapsed = tick() - session.startTime
	local currentZoneIdx = session.currentZoneIndex
	local nextZone = GameConstants.ZONE_THEMES[currentZoneIdx + 1]

	-- 다음 zone까지 20초 이내였으면
	if nextZone then
		local timeToNext = nextZone.startTime - elapsed
		if timeToNext > 0 and timeToNext < 20 then
			return `{math.ceil(timeToNext)}초만 더 버텼으면 {nextZone.displayName}이었어!`
		end
	end

	-- 피버까지 남은 콤보
	local comboToFever = GameConstants.FEVER.COMBO_THRESHOLD - session.comboCount
	if comboToFever > 0 and comboToFever <= 15 then
		return `콤보 {comboToFever}개만 더 모았으면 피버였어!`
	end

	-- 신기록까지 남은 점수
	local playerData = PlayerDataService:GetPlayerData(session.player)
	if playerData then
		local scoreToRecord = playerData.highScore - session.score
		if scoreToRecord > 0 and scoreToRecord <= 200 then
			return `신기록까지 {scoreToRecord}점만 남았었어!`
		end
	end

	return nil
end

print("[GameManager] Initialized")

return GameManager

--!strict
-- Game Manager
-- 게임 전체 흐름 관리 (플레이어별 게임 세션)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local ScenarioConstants = require(ReplicatedStorage.Shared.Constants.ScenarioConstants)
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
local BossRunService = require(script.Parent.BossRunService)
local AsyncBattleService = require(script.Parent.AsyncBattleService)
local RealtimeBattleService = require(script.Parent.RealtimeBattleService)
local DailyEventService = require(script.Parent.DailyEventService)
local UpgradeService = require(script.Parent.UpgradeService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local PetService = require(script.Parent.PetService)
local RunSkillService = require(script.Parent.RunSkillService)
local BattlePassService = require(script.Parent.BattlePassService)
local GhostService = require(script.Parent.GhostService)
local TeamService = require(script.Parent.TeamService)
local CoopMatchService = require(script.Parent.CoopMatchService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local ActiveSkillService = require(script.Parent.ActiveSkillService)
local RandomEventService = require(script.Parent.RandomEventService)
local DailyChallengeService = require(script.Parent.DailyChallengeService)
local CharacterService = require(script.Parent.CharacterService)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

-- BattlePassService: Init registers the PlayerDataService dependency
BattlePassService:Init(PlayerDataService)

-- GhostService: Init registers RemoteEvent handlers and PlayerDataService dependency
local _ghostService = GhostService.new()
_ghostService:Init(PlayerDataService)

-- TeamService: Init registers RemoteEvent handlers and PlayerDataService dependency
TeamService:Init(PlayerDataService)

-- CoopMatchService: manages matchmaking queue and co-op sessions
CoopMatchService:Init()

local GameManager = {}

type ScenarioStatBonuses = {
	speed: number,
	jump: number,
	coinValue: number,
	magnetRadius: number,
	maxLives: number,
	feverGauge: number,
}

type UpgradeBonuses = {
	magnetBonus: number,
	coinValueBonus: number,
	easyStartTime: number,
	feverExtend: number,
	luckyCoinsBonus: number,
	comboBufferSeconds: number,
	startBoostSeconds: number,
	baseSpeedBonus: number,
	baseJumpBonus: number,
	baseLivesBonus: number,
	skillCooldownReduction: number,
	miniGameBonus: number,
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
	maxNearMissChain: number, -- 이번 런 최대 연속 니어미스
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
	-- Survival multiplier
	survivalStartTime: number,
	survivalMultiplierTier: number,
	-- Hit recovery rush
	hitRushEndTime: number,
	-- Super Fever
	lastFeverEndTime: number,
	isSuperFever: boolean,
	-- Mini Fever (15 combo)
	isMiniFever: boolean,
	miniFeverEndTime: number,
	miniFeverTriggeredAt: number, -- 마지막 미니 피버 발동 콤보 수
	-- Async Battle
	asyncBattleTarget: { targetName: string, targetScore: number }?,
	-- Daily Event
	coinsCollectedCount: number, -- 수집한 코인 아이템 개수 (value가 아닌 개수)
	lastEventProgressTime: number, -- 마지막 이벤트 진행도 업데이트 시각
	-- Upgrade bonuses
	upgradeBonuses: UpgradeBonuses,
	-- 보스 조우 연출
	_bossDialogueFired: boolean,
	-- VIP 혜택
	vipFreeReviveUsed: boolean, -- 이번 런 무료 부활 사용 여부
	-- 소모형 런 파워업 (런 시작 전 코인 소비)
	headStartActive: boolean,
	headStartEnd: number,
	coinBoostActive: boolean,
	coinBoostMultiplier: number,
	slowStartActive: boolean,
	slowStartEnd: number,
	-- Co-op
	coopSessionId: string?,    -- nil if solo run
	coopLaneZ: number,         -- Z offset for this player's lane (0 for solo)
	coopSharedLives: number,   -- shared lives in co-op (mirrors session)
	-- Session state
	sessionState: string,
	pausedDuration: number,
	pauseStartTime: number,
	-- Analytics reference
	_analyticsService: any?,
	equippedActiveSkill: string?,
	activeShieldHits: number,
	_dashActive: boolean,
	_dashSpeedMultiplier: number,
	_magnetBurstActive: boolean,
	_magnetBurstRadius: number,
	-- Special coins (ISSUE-033)
	_magnetBoostEndTime: number,
	_magnetBoostMultiplier: number,
	_rainbowBoostEndTime: number,
	_rainbowBoostMultiplier: number,
}

local activeSessions: { [Player]: GameSession } = {}
ActiveSkillService:SetActiveSessions(activeSessions)
CharacterService:SetActiveSessions(activeSessions)

-- 로비 대기 중 소모형 파워업 (gameStart 전 구매 목록, player별)
local pendingConsumables: { [Player]: { [string]: boolean } } = {}

-- 현재 점수 조회 (RealtimeBattleService에서 사용)
function GameManager.GetCurrentScore(player: Player): number?
	local session = activeSessions[player]
	return session and session.score or nil
end

-- RealtimeBattleService에 점수 조회 함수 등록
RealtimeBattleService:SetScoreGetter(GameManager.GetCurrentScore)

-- 위로 보상 추적 (플레이어별 연속 빠른 게임오버 횟수)
local consolationTracker: { [Player]: number } = {}

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
			local now = os.clock()
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
RemoteEvents.PortalEnter.OnServerEvent:Connect(function(player: Player, data: { startPowerups: { string }?, useZoneSkip: boolean?, preRunSkills: { string }? }?)
	print(`[GameManager] Portal enter confirmed by {player.Name}`)

	-- 입력 검증 (data는 nil 허용)
	if data ~= nil and type(data) ~= "table" then
		return
	end

	-- Zone Skip Start 계산
	local skipToZone = 1
	local timeOffset = 0
	if data and data.useZoneSkip == true then
		local pData = PlayerDataService:GetPlayerData(player)
		local maxZone = pData and pData.maxZoneReached or 1
		if maxZone >= GameConstants.ZONE_SKIP.MIN_ZONE_TO_UNLOCK then
			skipToZone = maxZone -- 달성한 Zone에서 바로 시작 (maxZone-1 버그 수정)
			local theme = GameConstants.ZONE_THEMES[skipToZone]
			timeOffset = theme and theme.startTime or 0
			print(`[GameManager] Zone Skip: {player.Name} starting at Zone {skipToZone} (offset {timeOffset}s)`)
		end
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

	-- 업그레이드 보너스 가져오기
	local upgBonuses1 = UpgradeService:GetUpgradeBonuses(player, PlayerDataService)

	local session: GameSession = {
		player = player,
		chunkService = chunkService,
		coinService = coinService,
		obstacleService = obstacleService,
		powerupService = powerupService,
		npcService = npcService,
		tutorialService = TutorialService,
		backgroundService = backgroundService,
		isPlaying = true,
		startTime = os.clock(),
		startPosition = startPosition,
		score = 0,
		coins = 0,
		lives = math.min(
			GameConstants.LIFE.STARTING_LIVES + statBonuses.maxLives
				+ (if PlayerDataService:HasVIP(player) then GameConstants.MONETIZATION.VIP_BENEFITS.extraLife else 0)
				+ upgBonuses1.baseLivesBonus,
			GameConstants.LIFE.MAX_TOTAL or 8
		),
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
		maxNearMissChain = 0,
		lastHitDistance = 0,
		perfectRunAwarded = {},
		bonusScore = 0,
		currentZoneIndex = skipToZone,
		lastEventTime = 0,
		nearMissCount = 0,
		maxCombo = 0,
		feverCount = 0,
		powerupsCollected = 0,
		scenarioStatBonuses = statBonuses,
		unlockedSkillsSet = unlockedSkillsSet,
		lastShieldRegenTime = os.clock(),
		feverThreshold = feverThreshold,
		survivalStartTime = os.clock(),
		survivalMultiplierTier = 0,
		hitRushEndTime = 0,
		lastFeverEndTime = 0,
		isSuperFever = false,
		isMiniFever = false,
		miniFeverEndTime = 0,
		miniFeverTriggeredAt = 0,
		coinsCollectedCount = 0,
		lastEventProgressTime = 0,
		upgradeBonuses = upgBonuses1,
		_bossDialogueFired = false,
		vipFreeReviveUsed = false,
		-- 소모형 런 파워업 기본값 (아래에서 갱신)
		headStartActive = false,
		headStartEnd = 0,
		coinBoostActive = false,
		coinBoostMultiplier = 1.0,
		slowStartActive = false,
		slowStartEnd = 0,
		coopSessionId = nil,
		coopLaneZ = 0,
		coopSharedLives = 0,
		sessionState = "running",
		pausedDuration = 0,
		pauseStartTime = 0,
		_analyticsService = AnalyticsService,
		equippedActiveSkill = (PlayerDataService:GetPlayerData(player) or {}).equippedActiveSkill,
		activeShieldHits = 0,
		_dashActive = false,
		_dashSpeedMultiplier = 1.0,
		_magnetBurstActive = false,
		_magnetBurstRadius = 0,
		_magnetBoostEndTime = 0,
		_magnetBoostMultiplier = 1,
		_rainbowBoostEndTime = 0,
		_rainbowBoostMultiplier = 1,
	}

	-- 소모형 런 파워업 적용
	local consumables1 = pendingConsumables[player]
	local activeConsumableIds1: { string } = {}
	if consumables1 then
		local now1 = tick()
		if consumables1["head_start"] then
			session.headStartActive = true
			session.headStartEnd = now1 + 10
			table.insert(activeConsumableIds1, "head_start")
		end
		if consumables1["coin_boost"] then
			session.coinBoostActive = true
			session.coinBoostMultiplier = 1.5
			table.insert(activeConsumableIds1, "coin_boost")
		end
		if consumables1["extra_life"] then
			session.lives += 1
			table.insert(activeConsumableIds1, "extra_life")
		end
		if consumables1["slow_start"] then
			session.slowStartActive = true
			session.slowStartEnd = now1 + 15
			table.insert(activeConsumableIds1, "slow_start")
		end
		pendingConsumables[player] = nil
		print(`[GameManager] Applied {#activeConsumableIds1} consumable(s) for {player.Name}: {table.concat(activeConsumableIds1, ", ")}`)
	end

	activeSessions[player] = session

	-- 데일리 이벤트 세션 초기화
	DailyEventService:InitSession(player)

	-- 런 스킬 세션 초기화
	RunSkillService:StartSession(player)

	-- 시작 전 장착 스킬 적용 (data.preRunSkills 또는 PlayerData.equippedRunSkills)
	local preRunSkillIds: { string } = {}
	if data and type(data.preRunSkills) == "table" then
		-- 클라이언트가 전송한 슬롯 (서버 보유 스킬과 교차 검증)
		local ownedSet: { [string]: boolean } = {}
		for _, id in PlayerDataService:GetUnlockedRunSkills(player) do
			ownedSet[id] = true
		end
		for _, skillId in data.preRunSkills do
			if ownedSet[skillId] then
				table.insert(preRunSkillIds, skillId)
			end
		end
	else
		-- 저장된 장착 슬롯 사용
		preRunSkillIds = PlayerDataService:GetEquippedRunSkills(player)
	end
	if #preRunSkillIds > 0 then
		RunSkillService:ApplyPreRunSkills(player, preRunSkillIds)
	end

	-- 업그레이드 보너스 적용
	chunkService:SetEasyStartTime(upgBonuses1.easyStartTime)
	coinService:SetLuckyCoinsBonus(upgBonuses1.luckyCoinsBonus)

	-- 청크 서비스에 코인/장애물/파워업/NPC/배경 서비스 연결
	chunkService:SetCoinService(coinService)
	chunkService:SetObstacleService(obstacleService)
	chunkService:SetPowerupService(powerupService)
	chunkService:SetNPCService(npcService)
	chunkService:SetBackgroundService(backgroundService)

	-- 배경 서비스 시작
	backgroundService:StartGame()

	-- 청크 서비스 시작 (Zone Skip 오프셋 적용)
	chunkService:StartGame(timeOffset)

	-- 파워업 서비스 시작 (Zone Skip 오프셋 적용)
	powerupService:StartGame(timeOffset)

	-- 장애물 서비스: 게임 시작 시간 설정 (Zone Skip 오프셋 적용)
	obstacleService:SetGameStartTime(tick(), timeOffset)

	-- Zone 설정 (Zone Skip 적용)
	chunkService:SetCurrentZone(skipToZone)

	-- 챕터 연동 맵 테마 설정 (IDEA-005)
	local activeChapterId = ScenarioService:GetActiveChapterId(player)
	chunkService:SetActiveChapterId(activeChapterId)

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

	-- Character passive: start_magnet (게임 시작 시 자동 자석 발동)
	local startMagnetDur = CharacterService:GetStartMagnetDuration(player, PlayerDataService)
	if startMagnetDur > 0 then
		powerupService:ActivatePowerup("Magnet")
		-- 기본 자석 시간 대신 캐릭터 패시브 시간 적용 (더 긴 쪽 유지)
		local defaultEnd = powerupService._magnetEndTime or 0
		local passiveEnd = tick() + startMagnetDur
		powerupService._magnetEndTime = math.max(defaultEnd, passiveEnd)
	end

	-- 런 목표 생성 및 클라이언트 전송
	ObjectiveService:GenerateObjectives(player)
	local runObjs1 = ObjectiveService:GetObjectives(player)
	local objPayload1 = {}
	if runObjs1 then
		for _, obj in runObjs1 do
			table.insert(objPayload1, { id = obj.id, desc = obj.desc, target = obj.target })
		end
	end
	RemoteEvents.RunObjectivesGenerated:FireClient(player, { objectives = objPayload1 })

	-- 튜토리얼 필요 여부 확인 (v3: step-based)
	local playerDataForTutorial1 = PlayerDataService:GetPlayerData(player)
	local tutorialStep1 = TutorialService:GetStepForRun(playerDataForTutorial1)
	local startTutorial1 = tutorialStep1 ~= nil
	if startTutorial1 then
		TutorialService:SetActiveStep(player, tutorialStep1)
	end

	-- 고스트 레이싱: 새 런 기록 시작
	_ghostService:StartRecording(player)

	-- 클라이언트에 게임 시작 알림
	-- 소모형 파워업 목록 클라이언트에 전송 (UI 피드백용)
	if #activeConsumableIds1 > 0 then
		RemoteEvents.ActiveConsumables:FireClient(player, { powerupIds = activeConsumableIds1 })
	end

	RemoteEvents.GameStart:FireClient(player, {
		startTime = session.startTime,
		lives = session.lives,
		tutorialStep = tutorialStep1,
		startPosition = startPosition,
		startPowerups = validPowerups,
		scenarioStatBonuses = statBonuses,
		unlockedSkills = unlockedSkills,
		dailyEventTheme = DailyEventService:GetTodayTheme(),
		startBoostSeconds = upgBonuses1.startBoostSeconds,
		startZone = skipToZone, -- Zone Skip: 클라이언트 ZoneController 즉시 전환용
		baseSpeedBonus = upgBonuses1.baseSpeedBonus,
		baseJumpBonus = upgBonuses1.baseJumpBonus,
	})

	print(`[GameManager] Game started for {player.Name} via portal (zone {skipToZone})`)
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
			if lastOpen and (os.clock() - lastOpen) < SHOP_DEBOUNCE_TIME then
				return
			end
			shopDebounce[player] = os.clock()

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

-- 소모형 런 파워업 구매 처리 (로비 상태에서만 허용)
RemoteEvents.BuyConsumable.OnServerEvent:Connect(function(player: Player, powerupId: unknown)
	-- 입력 검증
	if type(powerupId) ~= "string" then
		RemoteEvents.BuyConsumableResult:FireClient(player, {
			success = false,
			powerupId = "",
			remainingCoins = 0,
			error = "invalid_input",
		})
		return
	end

	-- 게임 진행 중에는 구매 불가
	if activeSessions[player] then
		RemoteEvents.BuyConsumableResult:FireClient(player, {
			success = false,
			powerupId = powerupId,
			remainingCoins = 0,
			error = "game_in_progress",
		})
		return
	end

	-- 유효한 파워업 ID인지 확인
	local powerupDef: { id: string, name: string, desc: string, coinCost: number }? = nil
	for _, def in GameConstants.CONSUMABLE_POWERUPS do
		if def.id == powerupId then
			powerupDef = def
			break
		end
	end

	if not powerupDef then
		RemoteEvents.BuyConsumableResult:FireClient(player, {
			success = false,
			powerupId = powerupId,
			remainingCoins = 0,
			error = "invalid_powerup",
		})
		return
	end

	-- 중복 구매 방지 (한 런 대기 중 동일 파워업 1회만)
	if not pendingConsumables[player] then
		pendingConsumables[player] = {}
	end
	if pendingConsumables[player][powerupId] then
		local pData = PlayerDataService:GetPlayerData(player)
		RemoteEvents.BuyConsumableResult:FireClient(player, {
			success = false,
			powerupId = powerupId,
			remainingCoins = pData and pData.coins or 0,
			error = "already_purchased",
		})
		return
	end

	-- 코인 차감 (서버에서 검증)
	local didSpend = PlayerDataService:SpendCoins(player, powerupDef.coinCost)
	if not didSpend then
		local pData = PlayerDataService:GetPlayerData(player)
		RemoteEvents.BuyConsumableResult:FireClient(player, {
			success = false,
			powerupId = powerupId,
			remainingCoins = pData and pData.coins or 0,
			error = "insufficient_coins",
		})
		return
	end

	-- 구매 성공: 대기 목록에 추가
	pendingConsumables[player][powerupId] = true

	local pData = PlayerDataService:GetPlayerData(player)
	local remaining = pData and pData.coins or 0
	print(`[GameManager] {player.Name} bought consumable powerup: {powerupId} (-{powerupDef.coinCost} coins, remaining: {remaining})`)

	RemoteEvents.BuyConsumableResult:FireClient(player, {
		success = true,
		powerupId = powerupId,
		remainingCoins = remaining,
	})
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

	-- 업그레이드 보너스 가져오기
	local upgBonuses2 = UpgradeService:GetUpgradeBonuses(player, PlayerDataService)

	-- 비동기 배틀 타겟 가져오기 (있는 경우)
	local battleTarget2 = AsyncBattleService:GetBattleTarget(player)
	AsyncBattleService:ClearBattleTarget(player)

	local session: GameSession = {
		player = player,
		chunkService = chunkService,
		coinService = coinService,
		obstacleService = obstacleService,
		powerupService = powerupService,
		npcService = npcService,
		tutorialService = TutorialService,
		backgroundService = backgroundService,
		isPlaying = true,
		startTime = os.clock(),
		startPosition = startPosition,
		score = 0,
		coins = 0,
		lives = math.min(
			GameConstants.LIFE.STARTING_LIVES + statBonuses.maxLives
				+ (if PlayerDataService:HasVIP(player) then GameConstants.MONETIZATION.VIP_BENEFITS.extraLife else 0)
				+ upgBonuses2.baseLivesBonus,
			GameConstants.LIFE.MAX_TOTAL or 8
		),
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
		maxNearMissChain = 0,
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
		lastShieldRegenTime = os.clock(),
		feverThreshold = feverThreshold2,
		asyncBattleTarget = battleTarget2,
		survivalStartTime = os.clock(),
		survivalMultiplierTier = 0,
		hitRushEndTime = 0,
		lastFeverEndTime = 0,
		isSuperFever = false,
		isMiniFever = false,
		miniFeverEndTime = 0,
		miniFeverTriggeredAt = 0,
		coinsCollectedCount = 0,
		lastEventProgressTime = 0,
		upgradeBonuses = upgBonuses2,
		_bossDialogueFired = false,
		vipFreeReviveUsed = false,
		-- 소모형 런 파워업 기본값 (아래에서 갱신)
		headStartActive = false,
		headStartEnd = 0,
		coinBoostActive = false,
		coinBoostMultiplier = 1.0,
		slowStartActive = false,
		slowStartEnd = 0,
		coopSessionId = nil,
		coopLaneZ = 0,
		coopSharedLives = 0,
		sessionState = "running",
		pausedDuration = 0,
		pauseStartTime = 0,
		_analyticsService = AnalyticsService,
		equippedActiveSkill = (PlayerDataService:GetPlayerData(player) or {}).equippedActiveSkill,
		activeShieldHits = 0,
		_dashActive = false,
		_dashSpeedMultiplier = 1.0,
		_magnetBurstActive = false,
		_magnetBurstRadius = 0,
		_magnetBoostEndTime = 0,
		_magnetBoostMultiplier = 1,
		_rainbowBoostEndTime = 0,
		_rainbowBoostMultiplier = 1,
	}

	-- 소모형 런 파워업 적용
	local consumables2 = pendingConsumables[player]
	local activeConsumableIds2: { string } = {}
	if consumables2 then
		local now2 = tick()
		if consumables2["head_start"] then
			session.headStartActive = true
			session.headStartEnd = now2 + 10
			table.insert(activeConsumableIds2, "head_start")
		end
		if consumables2["coin_boost"] then
			session.coinBoostActive = true
			session.coinBoostMultiplier = 1.5
			table.insert(activeConsumableIds2, "coin_boost")
		end
		if consumables2["extra_life"] then
			session.lives += 1
			table.insert(activeConsumableIds2, "extra_life")
		end
		if consumables2["slow_start"] then
			session.slowStartActive = true
			session.slowStartEnd = now2 + 15
			table.insert(activeConsumableIds2, "slow_start")
		end
		pendingConsumables[player] = nil
		print(`[GameManager] Applied {#activeConsumableIds2} consumable(s) for {player.Name}: {table.concat(activeConsumableIds2, ", ")}`)
	end

	activeSessions[player] = session

	-- 데일리 이벤트 세션 초기화
	DailyEventService:InitSession(player)

	-- 업그레이드 보너스 적용
	chunkService:SetEasyStartTime(upgBonuses2.easyStartTime)
	coinService:SetLuckyCoinsBonus(upgBonuses2.luckyCoinsBonus)

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

	-- 장애물 서비스: 게임 시작 시간 설정 (Chase Mob MIN_TIME 판단용)
	obstacleService:SetGameStartTime(tick())

	-- Initial zone setup
	chunkService:SetCurrentZone(1)

	-- 런 목표 생성 및 클라이언트 전송
	ObjectiveService:GenerateObjectives(player)
	local runObjs2 = ObjectiveService:GetObjectives(player)
	local objPayload2 = {}
	if runObjs2 then
		for _, obj in runObjs2 do
			table.insert(objPayload2, { id = obj.id, desc = obj.desc, target = obj.target })
		end
	end
	RemoteEvents.RunObjectivesGenerated:FireClient(player, { objectives = objPayload2 })

	-- 튜토리얼 필요 여부 확인 (v3: step-based)
	local playerDataForTutorial2 = PlayerDataService:GetPlayerData(player)
	local tutorialStep2 = TutorialService:GetStepForRun(playerDataForTutorial2)
	local startTutorial2 = tutorialStep2 ~= nil
	if startTutorial2 then
		TutorialService:SetActiveStep(player, tutorialStep2)
	end

	-- 소모형 파워업 목록 클라이언트에 전송 (UI 피드백용)
	if #activeConsumableIds2 > 0 then
		RemoteEvents.ActiveConsumables:FireClient(player, { powerupIds = activeConsumableIds2 })
	end

	-- 클라이언트에 게임 시작 알림
	RemoteEvents.GameStart:FireClient(player, {
		startTime = session.startTime,
		lives = session.lives,
		tutorialStep = tutorialStep2,
		startPosition = startPosition,
		scenarioStatBonuses = statBonuses,
		unlockedSkills = unlockedSkills,
		asyncBattle = session.asyncBattleTarget,
		dailyEventTheme = DailyEventService:GetTodayTheme(),
		startBoostSeconds = upgBonuses2.startBoostSeconds,
		baseSpeedBonus = upgBonuses2.baseSpeedBonus,
		baseJumpBonus = upgBonuses2.baseJumpBonus,
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

	-- VIP 무료 부활 체크 (런당 1회, 재화 미소모)
	local isVIP = PlayerDataService:HasVIP(player)
	local vipFreeRevive = isVIP
		and GameConstants.MONETIZATION.VIP_BENEFITS.freeRevive
		and not session.vipFreeReviveUsed

	-- 부활 횟수 체크 (VIP 무료 부활은 횟수 제한 우회)
	if session.reviveCount >= GameConstants.REVIVE.MAX_REVIVES and not vipFreeRevive then
		print(`[GameManager] {player.Name} has no revives left`)
		RemoteEvents.Revive:FireClient(player, { success = false, reason = "no_revives" })
		return
	end

	-- 부활 재화 차감: VIP 무료 → 부활권 → 젬
	local reviveMethod = "none"
	if vipFreeRevive then
		reviveMethod = "vip_free"
		session.vipFreeReviveUsed = true
		print(`[GameManager] {player.Name} used VIP free revive`)
	elseif PlayerDataService:UseReviveTicket(player) then
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

	-- 활성 랜덤 이벤트 강제 종료 (코인 레인 루프 등 클라이언트 효과 정리)
	RandomEventService:ForceEnd(player, session)

	-- 런 스킬 세션 종료
	RunSkillService:EndSession(player)

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

	-- maxZoneReached 업데이트 (저장 전에 갱신)
	local playerDataForZone = PlayerDataService:GetPlayerData(player)
	if playerDataForZone then
		local currentMax = playerDataForZone.maxZoneReached or 1
		if session.currentZoneIndex > currentMax then
			playerDataForZone.maxZoneReached = session.currentZoneIndex
			print(`[GameManager] maxZoneReached updated: {currentMax} -> {session.currentZoneIndex} for {player.Name}`)
		end
	end

	-- 플레이어 데이터 업데이트 및 저장
	PlayerDataService:OnGameEnd(player, finalScore, earnedCoins, distance)

	-- 최고 점수 가져오기
	local playerData = PlayerDataService:GetPlayerData(player)
	local highScore = playerData and playerData.highScore or 0

	-- 글로벌 리더보드 업데이트
	LeaderboardService:UpdateScore(player, highScore)

	-- 진행도 업데이트 (레벨, 미션, 업적)
	ProgressionService:OnGameEnd(player, finalScore, earnedCoins, distance)

	-- 배틀패스 XP 적립
	local bpXP = 0
	bpXP = bpXP + GameConstants.BATTLE_PASS.XP_SOURCES.RUN_COMPLETE
	bpXP = bpXP + math.floor(session.coins / 10) * GameConstants.BATTLE_PASS.XP_SOURCES.COIN_COLLECTED_PER_10
	if session.feverCount and session.feverCount > 0 then
		bpXP = bpXP + session.feverCount * GameConstants.BATTLE_PASS.XP_SOURCES.FEVER
	end
	BattlePassService:AddXP(player, bpXP)

	-- 팀 주간 코인 집계
	TeamService:AddWeeklyCoins(player, math.floor(earnedCoins))

	-- co-op: end session
	if session.coopSessionId then
		CoopMatchService:EndSession(player, math.floor(session.score))
	end

	-- 비동기 배틀 결과 처리
	AsyncBattleService:ProcessGameEnd(player, finalScore, session.asyncBattleTarget)

	-- 실시간 배틀 결과 처리
	RealtimeBattleService:OnGameEnd(player, finalScore)

	-- 데일리 이벤트 진행도 저장
	local playerDataForEvent = PlayerDataService:GetPlayerData(player)
	if playerDataForEvent then
		DailyEventService:PersistProgress(player, playerDataForEvent, PlayerDataService)
	end

	-- 일일 도전 과제: 런 완료 및 점수 집계
	DailyChallengeService:UpdateProgress(player, "play_runs", 1)
	DailyChallengeService:UpdateProgress(player, "score_total", math.floor(finalScore))
	if session.coopSessionId then
		DailyChallengeService:UpdateProgress(player, "coop_runs", 1)
	end

	-- 시나리오 퀘스트 진행도 업데이트
	local sessionDuration = math.floor(os.clock() - session.startTime)
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
	local consolationShield = false
	if finalScore < GameConstants.CONSOLATION.QUICK_DEATH_SCORE then
		consolationTracker[player] = (consolationTracker[player] or 0) + 1
		if consolationTracker[player] >= GameConstants.CONSOLATION.THRESHOLD then
			consolationReward = GameConstants.CONSOLATION.REWARD_COINS
			PlayerDataService:AddCoins(player, consolationReward)
			consolationTracker[player] = 0
			-- 위로 쉴드 지급 (다음 런 시작 파워업)
			if GameConstants.CONSOLATION.REWARD_SHIELD then
				consolationShield = true
				PlayerDataService:PurchaseStartPowerup(player, "shield", 0) -- 무료 지급
			end
			print(`[GameManager] Consolation reward: +{consolationReward} coins for {player.Name}`)
		end
	else
		consolationTracker[player] = 0
	end

	-- 런 목표 요약 (클라이언트 표시용)
	local runObjectives = ObjectiveService:GetObjectives(player)
	local objCompleted = 0
	local objTotal = 0
	if runObjectives then
		objTotal = #runObjectives
		for _, obj in runObjectives do
			if obj.completed then
				objCompleted += 1
			end
		end
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
		-- 런 목표 요약
		objectivesCompleted = objCompleted,
		objectivesTotal = objTotal,
		objectiveBonus = ObjectiveService:GetCompletionBonus(player),
		-- 스킨 리텐션 데이터
		equippedSkinId = playerData and playerData.equippedSkin or "default",
		playerTotalCoins = playerData and playerData.coins or 0,
		ownedSkins = playerData and playerData.ownedSkins or { "default" },
		-- TIER 3: 다음 구역 목표 힌트 (재도전 동기 부여)
		nextZoneInfo = (function()
			local elapsed = os.clock() - session.startTime
			local nextZone = GameConstants.ZONE_THEMES[session.currentZoneIndex + 1]
			if nextZone then
				return {
					displayName = nextZone.displayName,
					remainingSeconds = math.max(1, math.ceil(nextZone.startTime - elapsed)),
				}
			end
			return nil
		end)(),
	})

	-- 위로 보상 알림 (별도 이벤트)
	if consolationReward > 0 then
		RemoteEvents.ConsolationReward:FireClient(player, { coins = consolationReward, shield = consolationShield })
		-- 업데이트된 데이터 재전송
		RemoteEvents.PlayerDataLoaded:FireClient(player, PlayerDataService:GetPlayerData(player))
	end

	-- 런 목표 완료 보너스
	local objectiveBonus = ObjectiveService:GetCompletionBonus(player)
	if objectiveBonus > 0 then
		PlayerDataService:AddCoins(player, objectiveBonus)
		PlayerDataService:IncrementRunObjectivesCompleted(player)
		RemoteEvents.PlayerDataLoaded:FireClient(player, PlayerDataService:GetPlayerData(player))
		print(`[GameManager] Run objectives bonus: +{objectiveBonus} coins for {player.Name}`)
	end
	ObjectiveService:ClearObjectives(player)

	-- 고스트 레이싱: 런 기록 종료 및 저장 (신기록 시 갱신)
	_ghostService:FinishRecording(player, finalScore)

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
	_ghostService:OnPlayerRemoving(player)
	CoopMatchService:OnPlayerRemoving(player)
	DailyEventService:OnPlayerLeave(player)
	ObjectiveService:ClearObjectives(player)
	BossRunService:OnPlayerRemoving(player)
	shopDebounce[player] = nil
	portalDebounce[player] = nil
	consolationTracker[player] = nil
	pendingConsumables[player] = nil
	RateLimiter.CleanupPlayer(player)
end)

-- 메인 업데이트 루프 (모든 활성 세션)
RunService.Heartbeat:Connect(function(deltaTime: number)
	for player, session in activeSessions do
		if not session.isPlaying then
			continue
		end

		-- Random event update
		RandomEventService:Update(player, session, deltaTime)
		-- 펫 액티브 스킬 자동 발동 업데이트
		PetService:UpdatePetSkill(player, PlayerDataService, session, deltaTime)

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
		local elapsedTime = os.clock() - session.startTime
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
			coinService:SetCurrentZone(session.currentZoneIndex)
			local theme = GameConstants.ZONE_THEMES[newZoneIndex]
			RemoteEvents.ZoneTransition:FireClient(player, {
				zoneIndex = newZoneIndex,
				zoneName = theme.name,
				displayName = theme.displayName,
			})
			chunkService:RequestTransitionChunk()
			-- Zone 진입 후 2개 Bonus 청크 보장 (숨 고르기 리듬)
			chunkService:RequestBreatheChunks(2)
		end

		-- 보스 조우: 90초 생존 시 챕터 보스 등장 대사 (런당 1회)
		if not session._bossDialogueFired and elapsedTime >= 90 then
			session._bossDialogueFired = true
			local activeChapterId = ScenarioService:GetActiveChapterId(player)
			if activeChapterId then
				local cutscenes = ScenarioConstants.CUTSCENES[activeChapterId]
				if cutscenes and cutscenes.bossIntro and #cutscenes.bossIntro > 0 then
					local line1 = cutscenes.bossIntro[1]
					RemoteEvents.BossDialogue:FireClient(player, {
						characterId = line1.characterId or "coin_king",
						text = line1.text,
						isVillain = true,
					})
					if #cutscenes.bossIntro >= 2 then
						local line2 = cutscenes.bossIntro[2]
						task.delay(3, function()
							if activeSessions[player] then
								RemoteEvents.BossDialogue:FireClient(player, {
									characterId = line2.characterId or "coin_king",
									text = line2.text,
									isVillain = true,
								})
							end
						end)
					end
				end
			end
		end

		-- Phase B: 이벤트 청크 확률 체크
		local eventCooldown = GameConstants.EVENT_CHUNKS.COOLDOWN
		if (os.clock() - session.lastEventTime) >= eventCooldown then
			if
				elapsedTime >= GameConstants.EVENT_CHUNKS.GIANT_COIN.MIN_TIME
				and math.random() < GameConstants.EVENT_CHUNKS.GIANT_COIN.CHANCE
			then
				session.lastEventTime = os.clock()
				chunkService:RequestEventChunk("GiantCoin")
				RemoteEvents.EventChunkAlert:FireClient(player, { eventType = "GiantCoin" })
			elseif
				elapsedTime >= GameConstants.EVENT_CHUNKS.COIN_RUSH.MIN_TIME
				and math.random() < GameConstants.EVENT_CHUNKS.COIN_RUSH.CHANCE
			then
				session.lastEventTime = os.clock()
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

		-- 코인 수집 체크 (자석 효과 적용, 피버/슈퍼피버 시 초강력 자석)
		local magnetRadius = powerupService:GetMagnetRadius() + session.scenarioStatBonuses.magnetRadius + session.upgradeBonuses.magnetBonus + PetService:GetMagnetBonus(player, PlayerDataService) + CharacterService:GetMagnetBonus(player, PlayerDataService)
		-- Active Skill: magnet_burst 즉시 흡수 (발동 프레임에 반경 확장)
		local burstActive, burstRadius = ActiveSkillService:ConsumeMagnetBurst(session)
		if burstActive then
			magnetRadius = math.max(magnetRadius, burstRadius)
		end
		-- Character Skill: vortex (주변 코인 전부 흡수)
		if session._charVortexActive then
			magnetRadius = math.max(magnetRadius, session._charVortexRadius or 50)
		end
		-- Character Skill: magnet_field (자석 반경 2배)
		if session._charMagnetFieldActive then
			magnetRadius = magnetRadius * (session._charMagnetFieldMult or 2)
		end
		-- Pet Skill: auto_magnet (자동 자석 발동)
		if session._petAutoMagnetActive then
			magnetRadius = math.max(magnetRadius, GameConstants.POWERUP.MAGNET_RADIUS)
		end
		-- Pet Skill: auto_coin_burst (즉시 코인 흡수)
		if session._petCoinBurstActive then
			magnetRadius = math.max(magnetRadius, 35)
		end
		-- 특수 코인: Magnet 부스트 (자석 반경 배율)
		if os.clock() < session._magnetBoostEndTime then
			magnetRadius *= session._magnetBoostMultiplier
		end
		-- 헤드스타트 자석 효과 (일반 자석 반경과 동등)
		if session.headStartActive then
			magnetRadius = math.max(magnetRadius, GameConstants.MINI_FEVER.MAGNET_RADIUS)
		end
		if session.isSuperFever then
			magnetRadius = math.max(magnetRadius, GameConstants.SUPER_FEVER.MAGNET_RADIUS)
		elseif session.isFever then
			magnetRadius = math.max(magnetRadius, GameConstants.FEVER.MAGNET_RADIUS)
		elseif session.isMiniFever then
			magnetRadius = math.max(magnetRadius, GameConstants.MINI_FEVER.MAGNET_RADIUS)
		end
		local collectedCoins = coinService:CheckCoinCollection(hrp.Position, magnetRadius, deltaTime)
		local coinMultiplier = powerupService:GetCoinMultiplier()
			* MonetizationService:GetCoinMultiplier(player)
			* (1 + session.scenarioStatBonuses.coinValue)
			* (1 + session.upgradeBonuses.coinValueBonus)
			* PetService:GetCoinMultiplier(player, PlayerDataService)
		-- 소모형 코인 부스트 적용
		if session.coinBoostActive then
			coinMultiplier *= session.coinBoostMultiplier
		end
		-- RandomEvent: coin_rain 활성 시 코인 2배
		if session._coinRainActive then
			coinMultiplier *= 2
		end
		-- 콤보 실시간 배율 적용
		coinMultiplier *= (session.comboMultiplier or 1)
		-- 특수 코인: Rainbow 부스트 (스코어/코인 배율)
		if os.clock() < session._rainbowBoostEndTime then
			coinMultiplier *= session._rainbowBoostMultiplier
		end
		-- RandomEvent: bonus_time 활성 시 코인 배율 추가
		if session._bonusTimeActive then
			coinMultiplier *= (session._bonusTimeCoinMult or 1)
		end
		if session.isSuperFever then
			coinMultiplier *= GameConstants.SUPER_FEVER.COIN_MULTIPLIER
		elseif session.isFever then
			coinMultiplier *= GameConstants.FEVER.COIN_MULTIPLIER
		elseif session.isMiniFever then
			coinMultiplier *= GameConstants.MINI_FEVER.COIN_MULTIPLIER
		end
		-- 코인 배율 상한선 (경제 밸런스 보호, 스택 폭주 방지)
		local MAX_COIN_MULTIPLIER = 20
		coinMultiplier = math.min(coinMultiplier, MAX_COIN_MULTIPLIER)

		local hitRushActive = os.clock() < session.hitRushEndTime
		local hitRushMult = if hitRushActive then GameConstants.HIT_RECOVERY.COIN_MULTIPLIER else 1
		-- 특수 코인 효과 선집계 (ISSUE-033) — 콤보 계산 전에 부스트만 적용, Star 보너스는 콤보 로직 후 가산
		local starBonusCombo = 0
		for _, coinData in collectedCoins do
			if coinData.type == "Star" then
				starBonusCombo += GameConstants.SPECIAL_COINS.STAR.COMBO_BONUS or 5
			elseif coinData.type == "Magnet" then
				local cfg = GameConstants.SPECIAL_COINS.MAGNET
				session._magnetBoostEndTime = math.max(session._magnetBoostEndTime, os.clock() + cfg.DURATION)
				session._magnetBoostMultiplier = cfg.MULTIPLIER
			elseif coinData.type == "Rainbow" then
				local cfg = GameConstants.SPECIAL_COINS.RAINBOW
				session._rainbowBoostEndTime = math.max(session._rainbowBoostEndTime, os.clock() + cfg.DURATION)
				session._rainbowBoostMultiplier = cfg.SCORE_MULTIPLIER
			end
		end

		for _, coinData in collectedCoins do
			-- 2배 코인 적용 (파워업 + VIP 배율 + 히트 러시)
			local actualValue = coinData.value * coinMultiplier * hitRushMult

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

		-- 데일리 이벤트: 코인 수집 횟수 추적
		if #collectedCoins > 0 then
			session.coinsCollectedCount += #collectedCoins
			DailyEventService:OnCoinsCollected(player, #collectedCoins)
			-- 런 XP: 코인 1개당 +1 XP
			RunSkillService:AddXP(player, #collectedCoins * GameConstants.RUN_PROGRESSION.XP_PER_COIN)
			-- 일일 도전 과제: 코인 수집
			DailyChallengeService:UpdateProgress(player, "collect_coins", #collectedCoins)
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
			local now = os.clock()
			local comboTimeout = GameConstants.SCORE.COMBO_TIMEOUT + session.upgradeBonuses.comboBufferSeconds
			if now - session.lastCoinTime < comboTimeout then
				session.comboCount += #collectedCoins
			else
				session.comboCount = #collectedCoins
			end
			session.lastCoinTime = now

			-- 콤보 실시간 배율 계산
			local comboMult = GameConstants.COMBO_MULTIPLIER.DEFAULT_MULTIPLIER
			for _, tier in GameConstants.COMBO_MULTIPLIER.TIERS do
				if session.comboCount >= tier.threshold then
					comboMult = tier.multiplier
				end
			end
			session.comboMultiplier = comboMult

			-- 콤보 마일스톤 보너스 체크 (레거시 호환 + 추가 보상)
			local prevCombo = session.comboCount - #collectedCoins
			-- 특수 코인 Star 보너스는 prevCombo 계산 후 반영 (마일스톤 중복 방지)
			if starBonusCombo > 0 then
				session.comboCount += starBonusCombo
			end
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

			-- 미니 피버 발동 체크 (15 콤보, 정식 피버 미발동 상태에서만)
			local miniFeverThreshold = GameConstants.MINI_FEVER.COMBO_THRESHOLD
			if
				not session.isFever
				and not session.isMiniFever
				and session.comboCount >= miniFeverThreshold
				and session.miniFeverTriggeredAt < session.comboCount - miniFeverThreshold + 1
			then
				session.isMiniFever = true
				session.miniFeverEndTime = now + GameConstants.MINI_FEVER.DURATION
				session.miniFeverTriggeredAt = session.comboCount
				RemoteEvents.MiniFeverStart:FireClient(player, {
					duration = GameConstants.MINI_FEVER.DURATION,
				})
				print(`[GameManager] MINI FEVER activated for {player.Name}! Combo: {session.comboCount}`)
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
				session.feverCount += 1 -- Phase B: 피버 횟수 추적
				-- 일일 도전 과제: 피버 발동
				DailyChallengeService:UpdateProgress(player, "fever_count", 1)

				-- 슈퍼 피버 체인 체크: 직전 피버 종료로부터 CHAIN_WINDOW 이내 재발동
				local isChain = session.lastFeverEndTime > 0
					and (now - session.lastFeverEndTime) < GameConstants.SUPER_FEVER.CHAIN_WINDOW
				if isChain then
					session.isSuperFever = true
					session.feverEndTime = now + GameConstants.SUPER_FEVER.DURATION
					RemoteEvents.SuperFeverStart:FireClient(player, {
						duration = GameConstants.SUPER_FEVER.DURATION,
						speedBoost = GameConstants.SUPER_FEVER.SPEED_BOOST,
					})
					print(`[GameManager] SUPER FEVER activated for {player.Name}!`)
				else
					session.isSuperFever = false
					local feverDuration = GameConstants.FEVER.DURATION + session.upgradeBonuses.feverExtend + PetService:GetFeverBonus(player, PlayerDataService) + CharacterService:GetFeverExtend(player, PlayerDataService)
					session.feverEndTime = now + feverDuration
					RemoteEvents.FeverStart:FireClient(player, {
						duration = feverDuration,
						speedBoost = GameConstants.FEVER.SPEED_BOOST,
					})
					ProgressionService:AddXP(player, GameConstants.LEVEL.XP_PER_FEVER)
					-- 런 XP: 피버 돌입 +20 XP
					RunSkillService:AddXP(player, GameConstants.RUN_PROGRESSION.XP_PER_FEVER)
					print(`[GameManager] FEVER MODE activated for {player.Name}!`)
				end
			end

			-- 피버 게이지 업데이트 (콤보 배율 포함)
			RemoteEvents.FeverGaugeUpdate:FireClient(player, {
				combo = session.comboCount,
				threshold = session.feverThreshold,
				onCooldown = now < session.feverCooldownEnd,
				comboMultiplier = session.comboMultiplier or 1,
			})

			-- 콤보 미션 진행도 업데이트
			ProgressionService:OnComboReached(player, session.comboCount)

			-- 일일 도전 과제: 콤보 달성 (최고값 기준)
			DailyChallengeService:SetProgressIfHigher(player, "reach_combo", session.comboCount)

			-- 클라이언트에 콤보 상태 알림
			RemoteEvents.ComboUpdate:FireClient(player, {
				combo = session.comboCount,
				bonus = comboBonus > 0 and comboBonus or nil,
			})
		else
			-- 콤보 타임아웃 체크 (combo_buffer 업그레이드로 연장 가능)
			local comboTimeout = GameConstants.SCORE.COMBO_TIMEOUT + session.upgradeBonuses.comboBufferSeconds
			if session.comboCount > 0 and os.clock() - session.lastCoinTime >= comboTimeout then
				session.comboCount = 0
				RemoteEvents.ComboUpdate:FireClient(player, { combo = 0 })
				RemoteEvents.FeverGaugeUpdate:FireClient(player, {
					combo = 0,
					threshold = session.feverThreshold,
					onCooldown = os.clock() < session.feverCooldownEnd,
				})
			end
		end

		-- 미니 피버 종료 체크
		if session.isMiniFever and os.clock() >= session.miniFeverEndTime then
			session.isMiniFever = false
			RemoteEvents.MiniFeverEnd:FireClient(player)
			print(`[GameManager] MINI FEVER ended for {player.Name}`)
		end

		-- 피버 모드 종료 체크
		if session.isFever and os.clock() >= session.feverEndTime then
			session.isFever = false
			session.lastFeverEndTime = os.clock()
			session.isSuperFever = false
			session.isMiniFever = false -- 피버 종료 시 미니 피버도 해제
			local cooldownReduction = 1 - (session.upgradeBonuses.skillCooldownReduction or 0)
			local feverCooldown = GameConstants.FEVER.COOLDOWN * cooldownReduction
			-- COOLDOWN=0이면 즉시 재발동 가능 (콤보 재달성이 유일한 조건)
			session.feverCooldownEnd = os.clock() + feverCooldown
			session.comboCount = 0 -- 피버 종료 시 콤보 리셋
			session.miniFeverTriggeredAt = 0 -- 피버 종료 시 미니 피버 카운터 초기화
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
			local now2 = os.clock()
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

		-- 장애물 서비스: 플레이어 위치 최신화 (Chase Mob 스폰 위치 추적용)
		obstacleService:UpdatePlayerPosition(hrp.Position)

		-- Chase Mob 업데이트: 추격 NPC 이동 및 피격 판정
		-- 서버에서 플레이어 속도 추정 (GameConstants 기반 ramp 공식)
		local _chaseElapsed = elapsedTime
		local _t = math.min(_chaseElapsed / GameConstants.PHYSICS.SPEED_RAMP_TIME, 1)
		local _easedT = _t * _t * (3 - 2 * _t) -- smoothstep
		local _estimatedSpeed = GameConstants.PHYSICS.SPEED_MIN
			+ (GameConstants.PHYSICS.SPEED_MAX - GameConstants.PHYSICS.SPEED_MIN) * _easedT
		-- 피버/슈퍼피버 중에는 속도 배율 반영
		if session.isSuperFever then
			_estimatedSpeed = _estimatedSpeed * GameConstants.SUPER_FEVER.SPEED_BOOST
		elseif session.isFever then
			_estimatedSpeed = _estimatedSpeed * GameConstants.FEVER.SPEED_BOOST
		end
		-- Active Skill: dash 속도 배율 반영
		_estimatedSpeed = _estimatedSpeed * ActiveSkillService:GetDashMultiplier(session)
		-- RandomEvent: speed_shift 속도 배율 반영
		if session._speedShiftMultiplier and session._speedShiftMultiplier ~= 1.0 then
			_estimatedSpeed = _estimatedSpeed * session._speedShiftMultiplier
		end
		-- RandomEvent: bonus_time 감속 반영
		if session._bonusTimeActive then
			_estimatedSpeed = _estimatedSpeed * (session._bonusTimeSpeedMult or 1)
		end
		-- Pet Skill: auto_slow (코인 수집용 감속)
		if session._petSlowActive then
			_estimatedSpeed = _estimatedSpeed * 0.7
		end
		local chaseMobHit = obstacleService:UpdateChaseMobs(hrp.Position, _estimatedSpeed, session.isFever or session.isSuperFever)

		-- MushroomPad 밟기 판정 (Zone 3 전용)
		if obstacleService:CheckMushroomPad(hrp.Position) then
			RemoteEvents.MushroomBounce:FireClient(player)
		end

		-- GravityZone 진입/퇴장 판정 (Zone 5 전용)
		local gravityState = obstacleService:CheckGravityZone(hrp.Position)
		if gravityState == "enter" then
			RemoteEvents.GravityZoneEnter:FireClient(player)
		elseif gravityState == "exit" then
			RemoteEvents.GravityZoneExit:FireClient(player)
		end

		-- 장애물 충돌 체크
		local isSliding = hrp:GetAttribute("IsSliding") or false
		local isMini = powerupService:IsMiniSizeActive()
		-- Character passive: hitbox_reduction → isMini와 동일하게 축소 히트박스 적용
		local charPassive = CharacterService:GetPassiveBonus(player, PlayerDataService)
		local effectiveMini = isMini or (charPassive.type == "hitbox_reduction")
		-- RandomEvent: giant_mode 활성 시 히트박스 확대 안 함 (시각만 커짐, 판정은 유지)
		local hitObstacle = obstacleService:CheckObstacleCollision(hrp.Position, isSliding, effectiveMini)
			or chaseMobHit

		-- 헤드스타트 만료 체크 (10초 후 비활성화)
		if session.headStartActive and tick() >= session.headStartEnd then
			session.headStartActive = false
		end

		if hitObstacle and session.lives > 0 then
			-- 피버 모드 무적 체크
			if session.isFever and GameConstants.FEVER.INVINCIBLE then
				-- 피버 무적으로 통과
				print(`[GameManager] Player {player.Name} passed through obstacle (FEVER)!`)
			-- 헤드스타트 무적 체크
			elseif session.headStartActive then
				-- 헤드스타트 무적으로 통과
				print(`[GameManager] Player {player.Name} passed through obstacle (HeadStart)!`)
			-- Character Skill: dash 무적 (짧은 돌진 중 장애물 통과)
			elseif session._charDashActive then
				print(`[GameManager] Player {player.Name} dashed through obstacle (character skill)!`)
			-- Character Skill: shield 무적 (방패 스킬)
			elseif session._charShieldActive then
				print(`[GameManager] Player {player.Name} blocked obstacle with character shield!`)
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
			-- Active skill shield check
			elseif ActiveSkillService:ConsumeShieldHit(session) then
				-- Shield absorbed the hit
				RemoteEvents.SkillActivated:FireClient(player, { skillId = "shield_absorb" })
			-- Pet Skill: auto_shield (자동 방어)
			elseif PetService:ConsumePetShield(session) then
				print(`[GameManager] Player {player.Name} blocked obstacle with pet shield!`)
				RemoteEvents.PetSkillActivated:FireClient(player, { skillId = "shield_used" })
			-- Character passive: hit_resist (확률적 피격 무시)
			elseif CharacterService:HasHitResist(player, PlayerDataService) and math.random() < CharacterService:GetHitResistChance(player, PlayerDataService) then
				-- 캐릭터 패시브로 피격 저항 성공
				print(`[GameManager] Player {player.Name} resisted hit (character passive)!`)
				RemoteEvents.SkillActivated:FireClient(player, { skillId = "hit_resist" })
			else
				-- 라이프 감소
				session.lives -= 1
				obstacleService:OnObstacleHit()

				-- 콤보 리셋 (피격 시 콤보 배율 초기화)
				if GameConstants.COMBO_MULTIPLIER.RESET_ON_HIT then
					session.comboCount = 0
					session.comboMultiplier = GameConstants.COMBO_MULTIPLIER.DEFAULT_MULTIPLIER
					RemoteEvents.ComboUpdate:FireClient(player, {
						combo = 0,
						multiplier = 1,
					})
				end

				-- 보스 런 활성 시 보스 런 라이프도 감소
				if BossRunService:IsBossRunActive(player) then
					BossRunService:OnHit(player)
				end

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

				-- 미니 피버 해제 (피격 시)
				if session.isMiniFever then
					session.isMiniFever = false
					RemoteEvents.MiniFeverEnd:FireClient(player)
				end

				-- 생존 배율 리셋 + 히트 러시 시작
				session.survivalStartTime = os.clock()
				if session.survivalMultiplierTier > 0 then
					session.survivalMultiplierTier = 0
					RemoteEvents.SurvivalMultiplierUpdate:FireClient(player, { tier = 0, multiplier = 1.0 })
				end
				session.hitRushEndTime = os.clock() + GameConstants.HIT_RECOVERY.RUSH_DURATION
				RemoteEvents.HitRushStart:FireClient(player, { duration = GameConstants.HIT_RECOVERY.RUSH_DURATION })

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
			-- 일일 도전 과제: 장애물 회피
			DailyChallengeService:UpdateProgress(player, "dodge_obstacles", 1)

			-- 체인 업데이트
			local now = os.clock()
			local chainTimeout = GameConstants.NEAR_MISS_CHAIN.CHAIN_TIMEOUT
			if now - session.lastNearMissTime < chainTimeout then
				session.nearMissChain = math.min(session.nearMissChain + 1, 5)
			else
				session.nearMissChain = 1
			end
			session.lastNearMissTime = now
			session.maxNearMissChain = math.max(session.maxNearMissChain, session.nearMissChain)

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

			-- 런 XP: 니어미스 +5 XP
			RunSkillService:AddXP(player, GameConstants.RUN_PROGRESSION.XP_PER_NEAR_MISS)

			-- v3: 누적 회피 횟수 증가 (기사 해금 퀘스트)
			local totalDodged = PlayerDataService:IncrementObstaclesDodged(player)
			if totalDodged == 500 then
				ProgressionService:CheckAchievements(player)
			end

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

		-- 생존 배율 티어 업데이트
		local cleanTime = os.clock() - session.survivalStartTime
		local newTier = 0
		for i = #GameConstants.SURVIVAL_MULTIPLIER.TIERS, 1, -1 do
			if cleanTime >= GameConstants.SURVIVAL_MULTIPLIER.TIERS[i].minTime then
				newTier = i
				break
			end
		end
		if newTier ~= session.survivalMultiplierTier then
			session.survivalMultiplierTier = newTier
			local tierData = GameConstants.SURVIVAL_MULTIPLIER.TIERS[newTier]
			RemoteEvents.SurvivalMultiplierUpdate:FireClient(player, {
				tier = newTier,
				multiplier = if tierData then tierData.multiplier else 1.0,
				label = if tierData then tierData.label else nil,
			})
		end
		local survivalMult = if session.survivalMultiplierTier > 0
			then GameConstants.SURVIVAL_MULTIPLIER.TIERS[session.survivalMultiplierTier].multiplier
			else 1.0

		-- 점수 업데이트 (이동 거리 기반)
		local distanceTraveled = hrp.Position.X - session.startPosition.X
		local distanceScore = math.max(0, math.floor(distanceTraveled * GameConstants.SCORE.DISTANCE_MULTIPLIER * survivalMult))

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
		if os.clock() % 0.5 < deltaTime then
			RemoteEvents.ScoreUpdate:FireClient(player, {
				score = session.score,
				distance = math.floor(distanceTraveled),
				coins = session.coins,
			})

			-- 데일리 이벤트 + 런 목표 진행도 업데이트 (0.5초 간격)
			local now = os.clock()
			if now - session.lastEventProgressTime >= 0.5 then
				session.lastEventProgressTime = now
				DailyEventService:OnDistanceUpdate(player, distanceTraveled)
				DailyEventService:OnScoreUpdate(player, session.score)
				local playerData = PlayerDataService:GetPlayerData(player)
				if playerData then
					-- 목표 달성 체크 + 보상 지급 (최초 1회)
					local wasGranted = DailyEventService:CheckAndGrantReward(player, playerData, PlayerDataService)
					if wasGranted then
						-- 업데이트된 잔액 알림
						RemoteEvents.PlayerDataLoaded:FireClient(player, PlayerDataService:GetPlayerData(player))
					end
					DailyEventService:FireProgressUpdate(player, playerData)
				end
				-- 런 목표 진행도 업데이트
				ObjectiveService:UpdateProgress(player, session, distanceTraveled)
			end
		end

		-- 보스 런 활성 세션 점수 동기화
		if BossRunService:IsBossRunActive(player) then
			BossRunService:AddScore(player, session.score)
		end
	end

	-- 보스 런 타이머/보스점수 업데이트
	BossRunService:Update(deltaTime)
end)

-- Phase B: "거의 다 왔어!" 메시지 생성
function GameManager._generateAlmostMessage(session: GameSession): string?
	local elapsed = os.clock() - session.startTime
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

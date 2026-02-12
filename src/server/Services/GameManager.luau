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
local ShopService = require(script.Parent.ShopService)
local BackgroundService = require(script.Parent.BackgroundService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local MonetizationService = require(script.Parent.MonetizationService)

local GameManager = {}

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
}

local activeSessions: { [Player]: GameSession } = {}
local globalTutorialService = TutorialService.new()

-- TutorialService에 PlayerDataService 연결
globalTutorialService:SetPlayerDataService(PlayerDataService)

-- 로비 초기화
LobbyService:Initialize()

-- 포탈 터치 감지 설정
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

	-- 시작 파워업 검증 및 사용
	local validPowerups: { string } = {}
	if data and data.startPowerups then
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
		lives = GameConstants.LIFE.STARTING_LIVES,
		reviveCount = 0,
		startPowerups = validPowerups,
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

	local session: GameSession = {
		player = player,
		chunkService = chunkService,
		coinService = coinService,
		obstacleService = obstacleService,
		powerupService = powerupService,
		npcService = npcService,
		tutorialService = globalTutorialService,
		isPlaying = true,
		startTime = tick(),
		startPosition = startPosition,
		score = 0,
		coins = 0,
		lives = GameConstants.LIFE.STARTING_LIVES,
		reviveCount = 0,
	}

	activeSessions[player] = session

	-- 청크 서비스에 코인/장애물/파워업/NPC 서비스 연결
	chunkService:SetCoinService(coinService)
	chunkService:SetObstacleService(obstacleService)
	chunkService:SetPowerupService(powerupService)
	chunkService:SetNPCService(npcService)
	chunkService:StartGame()

	-- 파워업 서비스 시작
	powerupService:StartGame()

	-- 튜토리얼 필요 여부 확인
	local needsTutorial = globalTutorialService:NeedsTutorial(player)

	-- 클라이언트에 게임 시작 알림
	RemoteEvents.GameStart:FireClient(player, {
		startTime = session.startTime,
		lives = session.lives,
		startTutorial = needsTutorial,
		startPosition = startPosition,
	})

	print(`[GameManager] Game started for {player.Name}`)
end)

-- 게임 오버 요청 처리
RemoteEvents.GameOver.OnServerEvent:Connect(function(player: Player)
	print(`[GameManager] Game over requested by {player.Name}`)
	GameManager.EndGame(player)
end)

-- 부활 요청 처리
RemoteEvents.Revive.OnServerEvent:Connect(function(player: Player)
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

	-- 클라이언트에 게임 오버 알림
	RemoteEvents.GameOver:FireClient(player, {
		finalScore = finalScore,
		earnedCoins = earnedCoins,
		highScore = highScore,
		distance = distance,
		isNewRecord = isNewRecord,
	})

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

		-- 코인 수집 체크 (자석 효과 적용)
		local collectedCoins = coinService:CheckCoinCollection(hrp.Position, powerupService:GetMagnetRadius())
		local coinMultiplier = powerupService:GetCoinMultiplier() * MonetizationService:GetCoinMultiplier(player)
		for _, coinData in collectedCoins do
			-- 2배 코인 적용 (파워업 + VIP 배율)
			local actualValue = coinData.value * coinMultiplier

			-- 세션 데이터 업데이트
			session.coins += actualValue
			session.score += actualValue

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
		local hitObstacle = obstacleService:CheckObstacleCollision(hrp.Position, isSliding)

		if hitObstacle and session.lives > 0 then
			-- 무적 상태 체크
			if powerupService:IsInvincible() then
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

						RemoteEvents.GameOver:FireClient(player, {
							canRevive = true,
							revivesLeft = GameConstants.REVIVE.MAX_REVIVES - session.reviveCount,
						})
					else
						-- 부활 불가 - 게임 오버
						print(`[GameManager] Player {player.Name} has no lives or revives left, ending game`)
						GameManager.EndGame(player)
					end
				end
			end
		end

		-- 점수 업데이트 (이동 거리 기반)
		local distanceTraveled = hrp.Position.X - session.startPosition.X
		local distanceScore = math.max(0, math.floor(distanceTraveled * GameConstants.SCORE.DISTANCE_MULTIPLIER))

		-- 총 점수 = 거리 점수 + 코인 점수 (코인 수집 시 이미 추가됨)
		local previousScore = session.score
		session.score = distanceScore + session.coins

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

print("[GameManager] Initialized")

return GameManager

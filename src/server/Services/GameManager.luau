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
	isPlaying: boolean,
	startTime: number,
	startPosition: Vector3, -- 시작 위치 (거리 계산용)
	score: number,
	coins: number,
	lives: number,
}

local activeSessions: { [Player]: GameSession } = {}
local globalTutorialService = TutorialService.new()

-- TutorialService에 PlayerDataService 연결
globalTutorialService:SetPlayerDataService(PlayerDataService)

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
	local currentX = (player.Character and player.Character:FindFirstChild("HumanoidRootPart") and (player.Character.HumanoidRootPart :: BasePart).Position.X or session.startPosition.X)
	local distance = math.max(0, math.floor(currentX - session.startPosition.X))

	-- 플레이어 데이터 업데이트 및 저장
	PlayerDataService:OnGameEnd(player, finalScore, earnedCoins, distance)

	-- 최고 점수 가져오기
	local playerData = PlayerDataService:GetPlayerData(player)
	local highScore = playerData and playerData.highScore or 0

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

	-- 클라이언트에 게임 오버 알림
	RemoteEvents.GameOver:FireClient(player, {
		finalScore = finalScore,
		earnedCoins = earnedCoins,
		highScore = highScore,
	})

	-- 세션 제거
	activeSessions[player] = nil

	print(`[GameManager] Game ended for {player.Name}: Score={finalScore}, Coins={earnedCoins}, HighScore={highScore}`)
end

-- 플레이어 퇴장 시 세션 정리
Players.PlayerRemoving:Connect(function(player: Player)
	if activeSessions[player] then
		GameManager.EndGame(player)
	end
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
		for _, coinData in collectedCoins do
			-- 세션 데이터 업데이트
			session.coins += coinData.value
			session.score += coinData.value

			-- 클라이언트에 수집 알림
			RemoteEvents.CoinCollected:FireClient(player, {
				coinType = coinData.type,
				coinValue = coinData.value,
				totalCoins = session.coins,
			})

			print(`[GameManager] Player {player.Name} collected {coinData.type} coin (+{coinData.value})`)
		end

		-- 장애물 충돌 체크
		local isSliding = hrp:GetAttribute("IsSliding") or false
		local hitObstacle = obstacleService:CheckObstacleCollision(hrp.Position, isSliding)

		if hitObstacle and session.lives > 0 then
			-- 쉴드 사용 시도
			if powerupService:TryUseShield() then
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

				-- 라이프 0이면 게임 오버
				if session.lives <= 0 then
					print(`[GameManager] Player {player.Name} has no lives left, ending game`)
					GameManager.EndGame(player)
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

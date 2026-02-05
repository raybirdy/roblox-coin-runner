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

local GameManager = {}

-- 플레이어별 게임 세션 데이터
type GameSession = {
	player: Player,
	chunkService: any, -- ChunkService
	coinService: any, -- CoinService
	isPlaying: boolean,
	startTime: number,
	score: number,
	coins: number,
	lives: number,
}

local activeSessions: { [Player]: GameSession } = {}

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

	local session: GameSession = {
		player = player,
		chunkService = chunkService,
		coinService = coinService,
		isPlaying = true,
		startTime = tick(),
		score = 0,
		coins = 0,
		lives = GameConstants.LIFE.STARTING_LIVES,
	}

	activeSessions[player] = session

	-- 청크 서비스에 코인 서비스 연결
	chunkService:SetCoinService(coinService)
	chunkService:StartGame()

	-- 클라이언트에 게임 시작 알림
	RemoteEvents.GameStart:FireClient(player, {
		startTime = session.startTime,
		lives = session.lives,
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

	-- 청크 및 코인 정리
	if session.chunkService then
		session.chunkService:Destroy()
	end
	if session.coinService then
		session.coinService:Destroy()
	end

	-- 클라이언트에 게임 오버 알림
	RemoteEvents.GameOver:FireClient(player, {
		finalScore = finalScore,
		earnedCoins = earnedCoins,
		-- highScore는 DataStore에서 가져올 예정
	})

	-- 세션 제거
	activeSessions[player] = nil

	print(`[GameManager] Game ended for {player.Name}: Score={finalScore}, Coins={earnedCoins}`)
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

		-- 오래된 청크 정리
		chunkService:CleanupOldChunks(hrp.Position)

		-- 새 청크 생성 필요 시
		if chunkService:CheckSpawnNewChunk(hrp.Position) then
			chunkService:SpawnNextChunk()
		end

		-- 코인 수집 체크
		local collectedCoins = coinService:CheckCoinCollection(hrp.Position)
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

		-- 점수 업데이트 (이동 거리 기반 - 향후 구현)
		-- session.score = calculateScore(session)
	end
end)

print("[GameManager] Initialized")

return GameManager

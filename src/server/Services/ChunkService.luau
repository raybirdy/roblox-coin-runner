--!strict
-- Chunk Service
-- 청크 생성, 로딩, 삭제 관리

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local ChunkService = {}
ChunkService.__index = ChunkService

type ChunkData = {
	model: Model,
	position: Vector3,
	difficulty: string,
	startHeight: string,
	endHeight: string,
	spawnTime: number,
}

export type ChunkService = typeof(setmetatable(
	{} :: {
		_chunksFolder: Folder?, -- ServerStorage에 있는 청크 템플릿 폴더
		_activeChunks: { ChunkData }, -- 현재 활성 청크들
		_chunkCounter: number, -- 청크 생성 카운터
		_lastChunkEndHeight: string, -- 마지막 청크의 끝 높이
		_gameStartTime: number, -- 게임 시작 시간
		_coinService: any?, -- CoinService 참조 (코인 생성용)
		_obstacleService: any?, -- ObstacleService 참조 (장애물 생성용)
		_powerupService: any?, -- PowerupService 참조 (파워업 생성용)
		_npcService: any?, -- NPCService 참조 (NPC 생성용)
		_startZone: Model?, -- 시작 구역 (출발선 포함)
	},
	ChunkService
))

function ChunkService.new(): ChunkService
	local self = setmetatable({
		_chunksFolder = nil,
		_activeChunks = {},
		_chunkCounter = 0,
		_lastChunkEndHeight = "LOW", -- 초기 높이
		_gameStartTime = 0,
		_coinService = nil,
		_obstacleService = nil,
		_powerupService = nil,
		_npcService = nil,
		_startZone = nil,
	}, ChunkService)

	self:_loadChunkTemplates()

	return self
end

-- CoinService 설정 (GameManager에서 호출)
function ChunkService:SetCoinService(coinService: any)
	self._coinService = coinService
end

-- ObstacleService 설정 (GameManager에서 호출)
function ChunkService:SetObstacleService(obstacleService: any)
	self._obstacleService = obstacleService
end

-- PowerupService 설정 (GameManager에서 호출)
function ChunkService:SetPowerupService(powerupService: any)
	self._powerupService = powerupService
end

-- NPCService 설정 (GameManager에서 호출)
function ChunkService:SetNPCService(npcService: any)
	self._npcService = npcService
end

-- 청크 템플릿 로드
function ChunkService:_loadChunkTemplates()
	-- ServerStorage에서 Chunks 폴더 찾기 또는 생성
	self._chunksFolder = ServerStorage:FindFirstChild("Chunks")

	if not self._chunksFolder then
		-- 폴더가 없으면 생성 (나중에 Roblox Studio에서 채울 것)
		self._chunksFolder = Instance.new("Folder")
		self._chunksFolder.Name = "Chunks"
		self._chunksFolder.Parent = ServerStorage
		warn("[ChunkService] Chunks folder not found in ServerStorage. Created empty folder.")
		warn("[ChunkService] Please add chunk templates in Roblox Studio.")
	else
		local chunkCount = #self._chunksFolder:GetChildren()
		print(`[ChunkService] Loaded {chunkCount} chunk templates`)
	end
end

-- 게임 시작
function ChunkService:StartGame()
	print("[ChunkService] StartGame called")

	self._gameStartTime = tick()
	self._activeChunks = {}
	self._chunkCounter = 0
	self._lastChunkEndHeight = "LOW"

	-- 시작 구역 생성 (출발선 포함)
	self:_spawnStartZone()

	-- 초기 청크 생성
	print("[ChunkService] Spawning initial chunks...")
	for i = 1, GameConstants.CHUNK.MAX_LOADED do
		self:SpawnNextChunk()
	end

	print(`[ChunkService] Game started, {#self._activeChunks} chunks spawned`)
end

-- 시작 구역 생성 (출발선 + 바닥)
function ChunkService:_spawnStartZone()
	print("[ChunkService] _spawnStartZone called")

	-- 기존 시작 구역 제거
	if self._startZone then
		self._startZone:Destroy()
		self._startZone = nil
	end

	-- 시작 구역 모델 생성
	local startZone = Instance.new("Model")
	startZone.Name = "StartZone"

	-- 시작 바닥 (플레이어 뒤쪽 + 앞쪽으로 확장)
	local floorLength = 100 -- 출발 전후 바닥 길이
	local floor = Instance.new("Part")
	floor.Name = "StartFloor"
	floor.Size = Vector3.new(floorLength, 1, 30)
	floor.Position = Vector3.new(-20, 0.5, GameConstants.PLAYER.Z_POSITION) -- Y=0~1 (Baseplate 위)
	floor.Anchored = true
	floor.CanCollide = true
	floor.BrickColor = BrickColor.new("Medium stone grey")
	floor.Material = Enum.Material.Concrete
	floor.Parent = startZone

	print(`[ChunkService] Created floor at {floor.Position}`)

	-- 출발선 (빨간색 라인)
	local startLine = Instance.new("Part")
	startLine.Name = "StartLine"
	startLine.Size = Vector3.new(1, 0.3, 20)
	startLine.Position = Vector3.new(0, 1.15, GameConstants.PLAYER.Z_POSITION) -- 바닥 위
	startLine.Anchored = true
	startLine.CanCollide = false
	startLine.BrickColor = BrickColor.new("Bright red")
	startLine.Material = Enum.Material.Neon
	startLine.Parent = startZone

	-- "START" 텍스트 (BillboardGui)
	local startSign = Instance.new("Part")
	startSign.Name = "StartSign"
	startSign.Size = Vector3.new(0.5, 8, 0.5)
	startSign.Position = Vector3.new(-2, 5, GameConstants.PLAYER.Z_POSITION - 8)
	startSign.Anchored = true
	startSign.CanCollide = false
	startSign.BrickColor = BrickColor.new("White")
	startSign.Material = Enum.Material.SmoothPlastic
	startSign.Parent = startZone

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StartText"
	billboard.Size = UDim2.new(0, 200, 0, 100)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.Adornee = startSign
	billboard.Parent = startSign

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "START"
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	textLabel.TextSize = 48
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextStrokeTransparency = 0.5
	textLabel.Parent = billboard

	-- 장식용 체커 패턴 (출발선 주변)
	for i = 1, 6 do
		local checker = Instance.new("Part")
		checker.Name = `Checker{i}`
		checker.Size = Vector3.new(2, 0.2, 2)
		checker.Position = Vector3.new(-4 - (i * 2.5), 1.1, GameConstants.PLAYER.Z_POSITION - 6 + ((i % 2) * 4))
		checker.Anchored = true
		checker.CanCollide = false
		checker.BrickColor = (i % 2 == 0) and BrickColor.new("White") or BrickColor.new("Really black")
		checker.Material = Enum.Material.SmoothPlastic
		checker.Parent = startZone
	end

	-- PrimaryPart 설정
	startZone.PrimaryPart = floor

	startZone.Parent = workspace
	self._startZone = startZone

	print("[ChunkService] Start zone spawned with starting line")
	print(`[ChunkService] Floor position: {floor.Position}, Size: {floor.Size}`)
	print(`[ChunkService] StartLine position: {startLine.Position}`)
end

-- 다음 청크 생성
function ChunkService:SpawnNextChunk(): Model?
	local difficulty = self:_selectDifficulty()
	local chunkTemplate = self:_getChunkTemplate(difficulty, self._lastChunkEndHeight)

	if not chunkTemplate then
		warn(`[ChunkService] No suitable chunk template found for difficulty={difficulty}, height={self._lastChunkEndHeight}`)
		return nil
	end

	-- 청크 복사 및 배치
	local chunk = chunkTemplate:Clone()
	local spawnPosition = self:_calculateSpawnPosition()

	chunk:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
	chunk.Parent = workspace

	-- 청크 데이터 저장
	local startHeight = chunk:GetAttribute("StartHeight") or "LOW"
	local endHeight = chunk:GetAttribute("EndHeight") or "LOW"

	local chunkData: ChunkData = {
		model = chunk,
		position = spawnPosition,
		difficulty = difficulty,
		startHeight = startHeight,
		endHeight = endHeight,
		spawnTime = tick(),
	}

	table.insert(self._activeChunks, chunkData)
	self._chunkCounter += 1
	self._lastChunkEndHeight = endHeight

	-- 청크 내 코인 생성
	if self._coinService then
		self._coinService:SpawnCoinsInChunk(chunk, difficulty)
	end

	-- 청크 내 장애물 생성
	if self._obstacleService then
		self._obstacleService:SpawnObstaclesInChunk(chunk, difficulty)
	end

	-- 청크 내 파워업 생성 (확률적)
	if self._powerupService then
		self._powerupService:TrySpawnPowerupInChunk(chunk, difficulty)
	end

	-- 청크 내 NPC 생성 (NPC 청크만)
	if self._npcService and difficulty == "NPC" then
		self._npcService:SpawnNPCInChunk(chunk, difficulty)
	end

	print(`[ChunkService] Spawned chunk #{self._chunkCounter}: {difficulty} at {spawnPosition}`)

	return chunk
end

-- 난이도 선택 (시간대별 확률 기반)
function ChunkService:_selectDifficulty(): string
	local elapsedTime = tick() - self._gameStartTime

	-- 시간대에 맞는 확률 테이블 찾기
	local rateTable = nil
	for _, table in GameConstants.CHUNK_SPAWN_RATES do
		if elapsedTime <= table.maxTime then
			rateTable = table
			break
		end
	end

	if not rateTable then
		-- 기본값: 마지막 테이블 사용
		rateTable = GameConstants.CHUNK_SPAWN_RATES[#GameConstants.CHUNK_SPAWN_RATES]
	end

	-- 자비 구간 체크 (연속 피격 시 강제 Easy/Bonus - 향후 구현)
	-- TODO: 피격 카운터 확인

	-- 가중 랜덤 선택
	local rand = math.random()
	local cumulative = 0

	local difficulties = { "Easy", "Normal", "Hard", "Bonus", "NPC" }
	for _, diff in difficulties do
		cumulative += rateTable[diff]
		if rand <= cumulative then
			return diff
		end
	end

	return "Easy" -- 폴백
end

-- 청크 템플릿 가져오기 (난이도 및 높이 매칭)
function ChunkService:_getChunkTemplate(difficulty: string, requiredStartHeight: string): Model?
	if not self._chunksFolder then
		return nil
	end

	-- 해당 난이도의 모든 청크 수집
	local candidates = {}
	for _, chunk in self._chunksFolder:GetChildren() do
		if not chunk:IsA("Model") then
			continue
		end

		local chunkDifficulty = chunk:GetAttribute("Difficulty")
		local chunkStartHeight = chunk:GetAttribute("StartHeight")

		if chunkDifficulty == difficulty then
			-- 높이 매칭 체크 (인접 높이만 허용)
			if self:_isHeightCompatible(requiredStartHeight, chunkStartHeight) then
				table.insert(candidates, chunk)
			end
		end
	end

	-- 후보 중 랜덤 선택
	if #candidates > 0 then
		local index = math.random(1, #candidates)
		return candidates[index]
	end

	-- 매칭 실패 시 높이 조건 무시하고 재시도
	warn(`[ChunkService] No height-compatible chunks found for {difficulty}/{requiredStartHeight}, relaxing constraint`)
	for _, chunk in self._chunksFolder:GetChildren() do
		if chunk:IsA("Model") and chunk:GetAttribute("Difficulty") == difficulty then
			table.insert(candidates, chunk)
		end
	end

	if #candidates > 0 then
		return candidates[math.random(1, #candidates)]
	end

	return nil
end

-- 높이 호환성 체크 (인접 높이만 허용)
function ChunkService:_isHeightCompatible(requiredHeight: string, chunkHeight: string): boolean
	-- 같은 높이는 항상 허용
	if requiredHeight == chunkHeight then
		return true
	end

	-- 인접 높이 체크
	local heightOrder = { "LOW", "MID", "HIGH" }
	local requiredIndex = table.find(heightOrder, requiredHeight)
	local chunkIndex = table.find(heightOrder, chunkHeight)

	if requiredIndex and chunkIndex then
		-- 1단계 차이까지만 허용
		return math.abs(requiredIndex - chunkIndex) <= 1
	end

	return false
end

-- 청크 생성 위치 계산
function ChunkService:_calculateSpawnPosition(): Vector3
	if #self._activeChunks == 0 then
		-- 첫 청크는 출발선 바로 앞 (X=5)에서 시작
		return Vector3.new(5, 0, GameConstants.PLAYER.Z_POSITION)
	end

	-- 마지막 청크 뒤에 배치
	local lastChunk = self._activeChunks[#self._activeChunks]
	local newX = lastChunk.position.X + GameConstants.CHUNK.LENGTH

	-- 높이는 마지막 청크의 끝 높이에 맞춤
	local heightValue = 0
	if self._lastChunkEndHeight == "MID" then
		heightValue = GameConstants.CHUNK.HEIGHT_MID
	elseif self._lastChunkEndHeight == "HIGH" then
		heightValue = GameConstants.CHUNK.HEIGHT_HIGH
	end

	return Vector3.new(newX, heightValue, GameConstants.PLAYER.Z_POSITION)
end

-- 청크 삭제 (플레이어 뒤에 있는 청크)
function ChunkService:CleanupOldChunks(playerPosition: Vector3)
	local chunksToRemove = {}

	for i, chunkData in self._activeChunks do
		local distanceBehind = playerPosition.X - chunkData.position.X

		if distanceBehind > GameConstants.CHUNK.DELETE_DISTANCE then
			table.insert(chunksToRemove, i)
		end
	end

	-- 역순으로 제거 (인덱스 변경 방지)
	for i = #chunksToRemove, 1, -1 do
		local index = chunksToRemove[i]
		local chunkData = self._activeChunks[index]

		chunkData.model:Destroy()
		table.remove(self._activeChunks, index)

		print(`[ChunkService] Cleaned up chunk at {chunkData.position}`)
	end
end

-- 플레이어 위치에 따라 새 청크 로드 필요 여부 체크
function ChunkService:CheckSpawnNewChunk(playerPosition: Vector3): boolean
	if #self._activeChunks == 0 then
		return true
	end

	-- 가장 앞(오른쪽)에 있는 청크 찾기
	local frontmostChunk = self._activeChunks[1]
	for _, chunkData in self._activeChunks do
		if chunkData.position.X > frontmostChunk.position.X then
			frontmostChunk = chunkData
		end
	end

	-- 플레이어가 청크의 75% 지점을 지났는지 확인
	local chunkProgressThreshold = frontmostChunk.position.X
		+ (GameConstants.CHUNK.LENGTH * GameConstants.CHUNK.PRELOAD_THRESHOLD)

	return playerPosition.X >= chunkProgressThreshold
end

-- 활성 청크 수 반환
function ChunkService:GetActiveChunkCount(): number
	return #self._activeChunks
end

-- 정리
function ChunkService:Destroy()
	-- 시작 구역 제거
	if self._startZone then
		self._startZone:Destroy()
		self._startZone = nil
	end

	-- 청크들 제거
	for _, chunkData in self._activeChunks do
		if chunkData.model then
			chunkData.model:Destroy()
		end
	end
	self._activeChunks = {}
end

return ChunkService

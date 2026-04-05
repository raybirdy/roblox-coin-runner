--!strict
-- Chunk Service
-- 청크 생성, 로딩, 삭제 관리

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local ScenarioConstants = require(ReplicatedStorage.Shared.Constants.ScenarioConstants)
local EncounterLibrary = require(ReplicatedStorage.Shared.Constants.EncounterLibrary)
local PhraseLibrary = require(ReplicatedStorage.Shared.Constants.PhraseLibrary) -- IDEA-011
local ProceduralChunkGenerator = require(script.Parent.ProceduralChunkGenerator)

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
		_easyStartTime: number, -- easy_start 업그레이드 적용 시간 (초)
		_coinService: any?, -- CoinService 참조 (코인 생성용)
		_obstacleService: any?, -- ObstacleService 참조 (장애물 생성용)
		_powerupService: any?, -- PowerupService 참조 (파워업 생성용)
		_npcService: any?, -- NPCService 참조 (NPC 생성용)
		_backgroundService: any?, -- BackgroundService 참조 (배경 생성용)
		_startZone: Model?, -- 시작 구역 (출발선 포함)
		_mercyChunkCount: number, -- 남은 자비 청크 수
		_breatheChunkCount: number, -- 존 전환 시 강제 Bonus 숨 고르기 청크 수
		_currentZoneIndex: number, -- Phase B: 현재 zone
		_pendingTransitionChunk: boolean, -- Phase B: 전환 터널 대기
		_pendingEventChunk: string?, -- Phase B: 이벤트 청크 대기
		-- 호흡 패턴 (60초 이후 하드15s/이지10s 사이클)
		_breathPhaseStart: number,
		_breathIsHard: boolean,
		-- 스타 웨이브 (주기적 Bonus 구간)
		_nextStarWaveTime: number,
		_starWaveActive: boolean,
		_starWaveEndTime: number,
		_activeChapterId: string?, -- 챕터 연동 맵 테마 (IDEA-005)
		_phraseQueue: { string }, -- Phrase 기반 난이도 큐 (IDEA-011)
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
		_easyStartTime = 30, -- 기본 30초 (업그레이드 미구매 시 기존 동작 유지)
		_coinService = nil,
		_obstacleService = nil,
		_powerupService = nil,
		_npcService = nil,
		_backgroundService = nil,
		_startZone = nil,
		_mercyChunkCount = 0,
		_breatheChunkCount = 0,
		_currentZoneIndex = 1,
		_pendingTransitionChunk = false,
		_pendingEventChunk = nil,
		_breathPhaseStart = 0,
		_breathIsHard = true,
		_nextStarWaveTime = 0,
		_starWaveActive = false,
		_starWaveEndTime = 0,
		_activeChapterId = nil,
		_phraseQueue = {}, -- IDEA-011: Phrase 기반 난이도 큐
	}, ChunkService)

	self:_loadChunkTemplates()

	return self
end

-- 활성 챕터 설정 (GameManager에서 게임 시작 시 호출 — IDEA-005)
function ChunkService:SetActiveChapterId(chapterId: string?)
	self._activeChapterId = chapterId
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

-- BackgroundService 설정 (GameManager에서 호출)
function ChunkService:SetBackgroundService(backgroundService: any)
	self._backgroundService = backgroundService
end

-- easy_start 업그레이드 적용 시간 설정 (GameManager에서 호출)
function ChunkService:SetEasyStartTime(seconds: number)
	self._easyStartTime = seconds
end

-- Phase B: 현재 zone 설정
function ChunkService:SetCurrentZone(zoneIndex: number)
	self._currentZoneIndex = zoneIndex
	if self._obstacleService then
		self._obstacleService:SetCurrentZone(zoneIndex)
	end
end

-- Phase B: 전환 터널 요청
function ChunkService:RequestTransitionChunk()
	self._pendingTransitionChunk = true
end

-- Phase B: 이벤트 청크 요청
function ChunkService:RequestEventChunk(eventType: string)
	self._pendingEventChunk = eventType
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

-- 게임 시작 (timeOffset: Zone Skip 시 경과 시간 오프셋 (초), 기본 0)
function ChunkService:StartGame(timeOffset: number?)
	print("[ChunkService] StartGame called")

	-- timeOffset 만큼 게임 시작 시간을 앞당겨 경과 시간 계산에 반영
	local offset = timeOffset or 0
	self._gameStartTime = tick() - offset
	self._activeChunks = {}
	self._chunkCounter = 0
	self._lastChunkEndHeight = "LOW"

	-- 호흡 패턴 초기화 (timeOffset >= 60이면 즉시 호흡 패턴 진입)
	self._breathPhaseStart = tick() - offset
	self._breathIsHard = true
	self._nextStarWaveTime = math.random(75, 90)
	self._starWaveActive = false
	self._starWaveEndTime = 0

	-- 시작 구역 생성 (출발선 포함)
	self:_spawnStartZone()

	-- 초기 청크 생성
	print("[ChunkService] Spawning initial chunks...")
	for _ = 1, GameConstants.CHUNK.MAX_LOADED do
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
	billboard.Size = UDim2.new(0, 200, 0, 90)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Adornee = startSign
	billboard.AlwaysOnTop = true
	billboard.Parent = startSign

	-- 배경 프레임 (검은색 반투명)
	local bgFrame = Instance.new("Frame")
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bgFrame.BackgroundTransparency = 0.3
	bgFrame.BorderSizePixel = 4
	bgFrame.BorderColor3 = Color3.fromRGB(0, 255, 0)
	bgFrame.Parent = billboard

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "START"
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- 흰색 글자
	textLabel.TextSize = 48
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 150, 0) -- 초록 테두리
	textLabel.Parent = bgFrame

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
	local difficulty: string
	local eventType: string? = nil

	-- Phase B: 전환 터널 우선 → 이벤트 청크 → 일반 난이도
	if self._pendingTransitionChunk then
		self._pendingTransitionChunk = false
		difficulty = "Bonus"
	elseif self._pendingEventChunk then
		eventType = self._pendingEventChunk
		self._pendingEventChunk = nil
		difficulty = "Easy" -- 이벤트 청크는 Easy 기반
	else
		difficulty = self:_selectDifficulty()
	end

	-- Coin Waterfall 이벤트 (120초 이후 5% 확률, CoinRush가 아닐 때만)
	local elapsedForWaterfall = tick() - self._gameStartTime
	if not eventType
		and elapsedForWaterfall >= GameConstants.COIN_WATERFALL.MIN_TIME
		and math.random() < GameConstants.COIN_WATERFALL.CHANCE
	then
		eventType = "CoinWaterfall"
		difficulty = "Bonus"
	end

	-- Zone Climax: Zone 전환 직전 15초 — 현재 zone 마지막 구간 감지
	local isZoneClimax = false
	if not eventType then
		local zoneThresholds = GameConstants.ZONE_THRESHOLDS
		if zoneThresholds then
			local currentThreshold = zoneThresholds[self._currentZoneIndex] or math.huge
			local timeToTransition = currentThreshold - elapsedForWaterfall
			if timeToTransition > 0 and timeToTransition <= GameConstants.ZONE_CLIMAX.PRE_TRANSITION_TIME then
				isZoneClimax = true
			end
		end
	end

	local spawnPosition = self:_calculateSpawnPosition()

	-- Phase B: 현재 zone 테마 + 챕터 accentColor 오버레이 (IDEA-005)
	local theme = GameConstants.ZONE_THEMES[self._currentZoneIndex]
	if self._activeChapterId then
		local chapterTheme = ScenarioConstants.CHAPTER_THEMES[self._activeChapterId]
		if chapterTheme then
			-- 원본 테이블 수정 방지: 얕은 복사 후 chapterAccentColor 추가
			local themeCopy = {}
			for k, v in theme do
				themeCopy[k] = v
			end
			themeCopy.chapterAccentColor = chapterTheme.accentColor
			theme = themeCopy
		end
	end

	-- 템플릿 찾기 시도
	local chunkTemplate = self:_getChunkTemplate(difficulty, self._lastChunkEndHeight)
	local chunk: Model

	if chunkTemplate then
		-- 템플릿 기반 생성
		chunk = chunkTemplate:Clone()
		chunk:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
		chunk.Parent = workspace
	else
		-- 절차적 생성 (템플릿 없을 때) - theme + eventType 전달
		chunk = ProceduralChunkGenerator.Generate(difficulty, self._lastChunkEndHeight, spawnPosition, theme, eventType)
		print(`[ChunkService] Generated procedural chunk: {difficulty}{eventType and ` (Event: {eventType})` or ""}`)
	end

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

	-- 청크 내 장애물 생성 (안전 구역 이후부터, 이벤트 청크에는 장애물 없음)
	local obstacleInfos: { any } = {} -- { { position: Vector3, obstacleType: string } }
	local isInSafeZone = self._chunkCounter <= GameConstants.CHUNK.SAFE_ZONE_CHUNKS

	-- ── Encounter 기반 배치 (IDEA-010) ──────────────────────────────────────
	-- Normal/Hard 30% 확률로 EncounterLibrary에서 템플릿 선택 → 장애물+코인 동시 배치
	-- 선택 시 기존 랜덤 배치(SpawnObstaclesInChunk/SpawnCoinsInChunk)를 건너뜀
	local usedEncounter = false
	if self._obstacleService and self._coinService and not isInSafeZone and not eventType then
		if (difficulty == "Normal" or difficulty == "Hard") and math.random() < 0.30 then
			local pool = EncounterLibrary.getByDifficulty(difficulty)
			if #pool > 0 then
				local enc = pool[math.random(#pool)]
				local chunkCF = chunk:GetPrimaryPartCFrame()
				local chunkHalfX = chunk:GetExtentsSize().X / 2
				-- 청크 왼쪽 끝을 relX=0 기준으로 삼아 월드 좌표 계산
				local chunkLeftX = chunkCF.Position.X - chunkHalfX
				local chunkZ = chunkCF.Position.Z
				local baseY = chunkCF.Position.Y

				-- 장애물 스폰
				for _, obs in enc.obstacles do
					local obsPos = Vector3.new(chunkLeftX + obs.relX, baseY + obs.relY, chunkZ)
					self._obstacleService:SpawnObstacleAt(obs.obstacleType, obsPos)
					table.insert(obstacleInfos, { position = obsPos, obstacleType = obs.obstacleType })
				end

				-- 유도 코인 스폰 (Bronze — 방향 힌트)
				for _, c in enc.guidCoins do
					local coinPos = Vector3.new(chunkLeftX + c.relX, baseY + c.relY, chunkZ)
					self._coinService:SpawnCoinAt(coinPos, "Bronze")
				end

				-- 보상 코인 스폰 (Gold — 성공 피드백)
				for _, c in enc.rewardCoins do
					local coinPos = Vector3.new(chunkLeftX + c.relX, baseY + c.relY, chunkZ)
					self._coinService:SpawnCoinAt(coinPos, "Gold")
				end

				print(`[ChunkService] Encounter '{enc.id}' spawned at chunk #{self._chunkCounter} ({difficulty})`)
				usedEncounter = true
			end
		end
	end
	-- ────────────────────────────────────────────────────────────────────────

	if not usedEncounter and self._obstacleService and not isInSafeZone and not eventType then
		obstacleInfos = self._obstacleService:SpawnObstaclesInChunk(chunk, difficulty)
		-- Hard 청크: Chase Mob 등장 확률 체크 (60초 이후, 15% 확률)
		self._obstacleService:TrySpawnChaseMobForChunk(difficulty)
		-- Zone 고유 장애물: 현재 Zone 메커닉 설정에 따라 특수 장애물 추가 생성
		if difficulty == "Normal" or difficulty == "Hard" then
			local zoneMech = GameConstants.ZONE_MECHANICS[self._currentZoneIndex]
			local specialChance = (zoneMech and zoneMech.specialChance or 0)
				* (isZoneClimax and GameConstants.ZONE_CLIMAX.SPECIAL_CHANCE_MULT or 1.0)
			if zoneMech and zoneMech.specialObstacle and math.random() < specialChance then
				local chunkCF = chunk:GetPrimaryPartCFrame()
				local halfX = chunk:GetExtentsSize().X / 2
				-- 청크 중앙 근처에 특수 장애물 1개 추가 배치
				local specialX = (math.random() - 0.5) * halfX * 0.6
				local specialPos = chunkCF.Position + Vector3.new(specialX, 0, 0)
				self._obstacleService:_spawnObstacle(specialPos, zoneMech.specialObstacle)
				table.insert(obstacleInfos, { position = specialPos, obstacleType = zoneMech.specialObstacle })
			end
		end
	elseif isInSafeZone then
		print(`[ChunkService] Chunk #{self._chunkCounter} is in safe zone - no obstacles`)
	end

	-- CoinService 호환용 positions 추출
	local obstaclePositions: { Vector3 } = {}
	for _, info in obstacleInfos do
		table.insert(obstaclePositions, info.position)
	end

	-- 청크 내 코인 생성 (장애물 정보를 전달하여 ActionHint 패턴 적용)
	-- Encounter 배치 시 코인은 이미 스폰됐으므로 일반 경로만 건너뜀 (이벤트는 유지)
	if self._coinService then
		if eventType == "CoinRush" then
			-- 코인 러시: 대량 코인 (3회 호출)
			self._coinService:SpawnCoinsInChunk(chunk, "Bonus", obstaclePositions, obstacleInfos)
			self._coinService:SpawnCoinsInChunk(chunk, "Bonus", obstaclePositions, obstacleInfos)
			self._coinService:SpawnCoinsInChunk(chunk, "Bonus", obstaclePositions, obstacleInfos)
		elseif eventType == "GiantCoin" then
			-- 일반 코인 + 거인 코인
			self._coinService:SpawnCoinsInChunk(chunk, difficulty, obstaclePositions, obstacleInfos)
			self._coinService:SpawnGiantCoin(chunk, spawnPosition)
		elseif eventType == "CoinWaterfall" then
			-- 코인 폭포: WATERFALL 패턴으로 대각선 24개 + Bonus 추가
			self._coinService:SpawnCoinPattern(chunk, "waterfall", {})
			self._coinService:SpawnCoinsInChunk(chunk, "Bonus", {}, {})
			print(`[ChunkService] Coin Waterfall event at chunk #{self._chunkCounter}!`)
		elseif not usedEncounter then
			-- 일반 랜덤 배치 (Encounter 미사용 시에만)
			self._coinService:SpawnCoinsInChunk(chunk, difficulty, obstaclePositions, obstacleInfos)
			-- Zone Climax: 코인 밀도 2배 (추가 호출)
			if isZoneClimax then
				self._coinService:SpawnCoinsInChunk(chunk, difficulty, obstaclePositions, obstacleInfos)
			end
		end
	end

	-- Zone 고유 코인 패턴 생성 (coinPattern이 정의된 Zone에서만)
	if self._coinService and not isInSafeZone and not eventType then
		local zoneMechForCoin = GameConstants.ZONE_MECHANICS[self._currentZoneIndex]
		if zoneMechForCoin and zoneMechForCoin.coinPattern then
			-- 기존 패턴 대신 Zone 패턴 오버라이드는 하지 않음
			-- 별도 추가 호출로 Zone 고유 코인 생성 (MushroomPad/GravityZone 특수 배치)
			if difficulty == "Hard" then
				self._coinService:SpawnCoinPattern(chunk, zoneMechForCoin.coinPattern, {})
			end
		end
	end

	-- 스킬 루트 코인 생성 (Normal/Hard 청크, 장애물 있을 때만)
	if self._coinService and #obstacleInfos > 0 and not isInSafeZone and not eventType then
		if difficulty == "Normal" or difficulty == "Hard" then
			self._coinService:SpawnSkillRouteCoins(obstacleInfos, difficulty)
		end
	end

	-- 청크 내 파워업 생성 (확률적, 안전 구역 이후부터)
	if self._powerupService and not isInSafeZone and not eventType then
		self._powerupService:TrySpawnPowerupInChunk(chunk, difficulty)
	end

	-- 청크 내 NPC 생성 (NPC 청크만)
	if self._npcService and difficulty == "NPC" and not eventType then
		self._npcService:SpawnNPCInChunk(chunk, difficulty)
	end

	-- 청크 배경 요소 생성 (관중, 나무, 언덕) - theme 전달
	if self._backgroundService then
		self._backgroundService:AddBackgroundForChunk(spawnPosition, GameConstants.CHUNK.LENGTH, theme)
	end

	print(`[ChunkService] Spawned chunk #{self._chunkCounter}: {difficulty} at {spawnPosition}`)

	return chunk
end

-- 난이도 선택 (시간대별 확률 기반 + 호흡 패턴)
function ChunkService:_selectDifficulty(): string
	local elapsedTime = tick() - self._gameStartTime

	-- easy_start 업그레이드: 설정된 시간 동안 Easy/Bonus 청크만 등장
	if elapsedTime < self._easyStartTime then
		local rand = math.random()
		return if rand < 0.8 then "Easy" else "Bonus"
	end

	-- 스타 웨이브 체크: 주기적으로 5초간 Bonus 청크만 스폰 (코인 잔치)
	if not self._starWaveActive and elapsedTime >= self._nextStarWaveTime then
		self._starWaveActive = true
		self._starWaveEndTime = tick() + 5
		self._nextStarWaveTime = elapsedTime + math.random(75, 90)
		print(`[ChunkService] ⭐ Star wave at {math.floor(elapsedTime)}s!`)
	end
	if self._starWaveActive then
		if tick() < self._starWaveEndTime then
			return "Bonus"
		else
			self._starWaveActive = false
			print("[ChunkService] ⭐ Star wave ended")
		end
	end

	-- 시간대에 맞는 확률 테이블 찾기
	local rateTable = nil
	for _, table in GameConstants.CHUNK_SPAWN_RATES do
		if elapsedTime <= table.maxTime then
			rateTable = table
			break
		end
	end

	if not rateTable then
		rateTable = GameConstants.CHUNK_SPAWN_RATES[#GameConstants.CHUNK_SPAWN_RATES]
	end

	-- 존 전환 숨 고르기 구간 (Zone 진입 직후 2 Bonus 청크 보장)
	if self._breatheChunkCount > 0 then
		self._breatheChunkCount -= 1
		print(`[ChunkService] 🌿 Breathe chunk (zone entry): Bonus ({self._breatheChunkCount} remaining)`)
		return "Bonus"
	end

	-- 자비 구간 체크 (연속 피격 시 강제 Easy/Bonus)
	if self._mercyChunkCount > 0 then
		self._mercyChunkCount -= 1
		local mercyDifficulty = math.random() < 0.4 and "Bonus" or "Easy"
		print(`[ChunkService] Mercy chunk activated: {mercyDifficulty} ({self._mercyChunkCount} remaining)`)
		return mercyDifficulty
	end

	-- 2층 분기 맵: 30s+ 조건에서 10% 확률 (IDEA-003)
	if elapsedTime >= GameConstants.DUAL_FLOOR.MIN_ELAPSED_TIME then
		if math.random() < GameConstants.DUAL_FLOOR.SPAWN_CHANCE then
			print(`[ChunkService] 🏠 DualFloor chunk at {math.floor(elapsedTime)}s`)
			return "DualFloor"
		end
	end

	-- 다중 높이 플랫폼: 45s+ 조건에서 7% 확률 (IDEA-013)
	if elapsedTime >= GameConstants.MULTI_LANE.MIN_ELAPSED_TIME then
		if math.random() < GameConstants.MULTI_LANE.SPAWN_CHANCE then
			print(`[ChunkService] 🏔️ MultiLane chunk at {math.floor(elapsedTime)}s`)
			return "MultiLane"
		end
	end

	-- 호흡 패턴 (60초 이후: Hard 15s → Easy 10s 반복 사이클)
	if elapsedTime >= 60 then
		local phaseElapsed = tick() - self._breathPhaseStart
		if self._breathIsHard and phaseElapsed >= 15 then
			self._breathIsHard = false
			self._breathPhaseStart = tick()
			print("[ChunkService] 🌬️ Breath: easy phase")
		elseif not self._breathIsHard and phaseElapsed >= 10 then
			self._breathIsHard = true
			self._breathPhaseStart = tick()
			print("[ChunkService] 🌬️ Breath: hard phase")
		end

		-- 이지 호흡 구간: Easy/Bonus 위주로 확률 덮어쓰기
		if not self._breathIsHard then
			local rand = math.random()
			if rand < 0.60 then
				return "Easy"
			elseif rand < 0.80 then
				return "Bonus"
			elseif rand < 0.92 then
				return "NPC"
			else
				return "Normal"
			end
		end
	end

	-- Phrase 큐 소비 (IDEA-011): 기존 override 시스템을 통과한 경우에만 도달
	-- breathing/mercy/star-wave 등 우선순위 시스템이 위에서 먼저 처리됨
	if #self._phraseQueue > 0 then
		local queued = table.remove(self._phraseQueue, 1)
		if queued then
			return queued
		end
	end

	-- Phrase 큐가 비었으면 새 Phrase를 선택하여 큐 채움 (IDEA-011)
	local phrase = PhraseLibrary.pick(elapsedTime)
	-- 첫 번째 청크 난이도는 즉시 반환, 나머지는 큐에 저장
	for i = 2, #phrase.sequence do
		table.insert(self._phraseQueue, phrase.sequence[i].difficulty)
	end
	print(`[ChunkService] Phrase "{phrase.label}" ({phrase.id}): {#phrase.sequence} chunks queued`)
	return phrase.sequence[1].difficulty
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

		-- 청크 삭제 전: 플레이어 근처 코인을 workspace로 이전 (수집 기회 보장)
		-- SUPER_FEVER 자석 반경(40 studs)보다 큰 거리를 구조 거리로 사용
		local rescueDistance = GameConstants.SUPER_FEVER and GameConstants.SUPER_FEVER.MAGNET_RADIUS or 40
		rescueDistance = rescueDistance + 10 -- 여유 마진 추가
		for _, child in chunkData.model:GetChildren() do
			if child:IsA("Model") and (child.Name:find("Coin") or child.Name:find("coin")) then
				-- 코인 모델의 PrimaryPart 또는 첫 번째 BasePart로 거리 계산
				local refPart = child.PrimaryPart
				if not refPart then
					for _, part in child:GetChildren() do
						if part:IsA("BasePart") then
							refPart = part
							break
						end
					end
				end
				if refPart then
					local dist = (refPart.Position - playerPosition).Magnitude
					if dist <= rescueDistance then
						-- 플레이어 근처 코인: 청크 삭제 후에도 살아남도록 workspace로 이전
						child.Parent = workspace
					end
				end
			end
		end

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

	-- 최대 청크 수 제한
	if #self._activeChunks >= GameConstants.CHUNK.MAX_LOADED then
		return false
	end

	-- 가장 앞(오른쪽)에 있는 청크 찾기
	local frontmostChunk = self._activeChunks[1]
	for _, chunkData in self._activeChunks do
		if chunkData.position.X > frontmostChunk.position.X then
			frontmostChunk = chunkData
		end
	end

	-- 가장 앞 청크의 끝 위치
	local frontmostChunkEnd = frontmostChunk.position.X + GameConstants.CHUNK.LENGTH

	-- 플레이어 앞에 최소 거리만큼 청크가 있는지 확인
	local distanceAhead = frontmostChunkEnd - playerPosition.X

	return distanceAhead < GameConstants.CHUNK.MIN_AHEAD_DISTANCE
end

-- 자비 청크 요청 (GameManager에서 연속 피격 시 호출)
function ChunkService:RequestMercyChunks(count: number)
	self._mercyChunkCount = count
	print(`[ChunkService] Mercy mode activated: {count} easy chunks queued`)
end

-- 존 전환 시 숨 고르기 Bonus 청크 요청 (Zone 진입 직후 쉬어가기)
function ChunkService:RequestBreatheChunks(count: number)
	self._breatheChunkCount = count
	print(`[ChunkService] 🌿 Breathe mode activated: {count} bonus chunks queued (zone transition)`)
end

-- 활성 청크 수 반환
function ChunkService:GetActiveChunkCount(): number
	return #self._activeChunks
end

-- Unload N rear chunks (for minigame memory management)
function ChunkService:UnloadRearChunks(count: number)
	local removed = 0
	while removed < count and #self._activeChunks > 1 do
		local chunkData = table.remove(self._activeChunks, 1)
		if chunkData and chunkData.model then
			chunkData.model:Destroy()
		end
		removed += 1
	end
	if removed > 0 then
		print(`[ChunkService] Unloaded {removed} rear chunks for minigame`)
	end
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

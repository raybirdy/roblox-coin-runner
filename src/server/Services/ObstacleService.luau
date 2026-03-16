--!strict
-- Obstacle Service
-- 장애물 생성 및 충돌 처리

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local ObstacleService = {}
ObstacleService.__index = ObstacleService

type ObstacleData = {
	part: BasePart,
	obstacleType: string,
	spawnTime: number,
}

-- Chase Mob 전용 데이터 (동적으로 이동하는 추격 NPC)
type ChaseMobData = {
	part: BasePart,
	label: BillboardGui,
	spawnTime: number,
	lastUpdateTime: number,
}

export type ObstacleService = typeof(setmetatable(
	{} :: {
		_activeObstacles: { ObstacleData },
		_activeChaseMobs: { ChaseMobData }, -- 활성 추격 NPC 목록
		_player: Player,
		_lastHitTime: number,
		_isInvincible: boolean,
		_collidedObstacles: { [BasePart]: boolean }, -- already-hit tracking
		_gameStartTime: number, -- 게임 시작 시간 (Chase Mob MIN_TIME 판단용)
		_lastPlayerPosition: Vector3, -- 가장 최근의 플레이어 위치 (Chase Mob 스폰용)
		_currentZoneIndex: number, -- 현재 구역 인덱스 (장애물 색상 테마용)
	},
	ObstacleService
))

function ObstacleService.new(player: Player): ObstacleService
	local self = setmetatable({
		_activeObstacles = {},
		_activeChaseMobs = {},
		_player = player,
		_lastHitTime = 0,
		_isInvincible = false,
		_collidedObstacles = {},
		_gameStartTime = 0,
		_lastPlayerPosition = Vector3.zero,
		_currentZoneIndex = 1,
	}, ObstacleService)

	return self
end

-- 게임 시작 시간 설정 (GameManager에서 호출, timeOffset: Zone Skip 오프셋)
function ObstacleService:SetGameStartTime(startTime: number, timeOffset: number?)
	self._gameStartTime = startTime - (timeOffset or 0)
end

-- 현재 구역 설정 (ChunkService에서 Zone 전환 시 호출)
function ObstacleService:SetCurrentZone(zoneIndex: number)
	self._currentZoneIndex = zoneIndex
end

-- 현재 구역에 맞는 장애물 색상 반환
function ObstacleService:_getZoneObstacleColor(): Color3
	return GameConstants.ZONE_OBSTACLE_COLORS[self._currentZoneIndex]
		or GameConstants.ZONE_OBSTACLE_COLORS[1]
end

-- 플레이어 현재 위치 업데이트 (GameManager Heartbeat에서 호출)
function ObstacleService:UpdatePlayerPosition(position: Vector3)
	self._lastPlayerPosition = position
end

-- Chase Mob 스폰 (플레이어 위치 기준으로 즉시 생성)
function ObstacleService:SpawnChaseMob(playerPosition: Vector3)
	local cfg = GameConstants.CHASE_MOB
	local spawnPos = Vector3.new(
		playerPosition.X + cfg.SPAWN_OFFSET_X,
		playerPosition.Y,
		playerPosition.Z
	)

	-- 몸통 (Anchored = 위치 추적/충돌 기준)
	local mobBody = Instance.new("Part")
	mobBody.Name = "Obstacle_ChaseMob"
	mobBody.Size = cfg.SIZE -- 3×4×3
	mobBody.Position = spawnPos
	mobBody.Color = cfg.COLOR
	mobBody.Material = Enum.Material.SmoothPlastic
	mobBody.Anchored = true
	mobBody.CanCollide = false
	mobBody:SetAttribute("ObstacleType", "ChaseMob")
	mobBody.Parent = workspace

	-- 머리 (공 모양)
	local mobHead = Instance.new("Part")
	mobHead.Name = "ChaseMobHead"
	mobHead.Shape = Enum.PartType.Ball
	mobHead.Size = Vector3.new(2.5, 2.5, 2.5)
	mobHead.Color = cfg.COLOR
	mobHead.Material = Enum.Material.SmoothPlastic
	mobHead.Anchored = false
	mobHead.CanCollide = false
	mobHead.Position = spawnPos + Vector3.new(0, cfg.SIZE.Y / 2 + 1.25, 0)
	mobHead.Parent = workspace

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = mobBody
	headWeld.Part1 = mobHead
	headWeld.Parent = mobBody

	-- 눈 (흰색 구 2개)
	for _, xOff in { -0.55, 0.55 } do
		local eye = Instance.new("Part")
		eye.Name = "ChaseMobEye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.5, 0.5, 0.5)
		eye.Color = Color3.fromRGB(255, 255, 255)
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.Position = spawnPos + Vector3.new(xOff, cfg.SIZE.Y / 2 + 1.5, -1.1)
		eye.Parent = workspace

		local eyeWeld = Instance.new("WeldConstraint")
		eyeWeld.Part0 = mobBody
		eyeWeld.Part1 = eye
		eyeWeld.Parent = mobBody
	end

	-- PointLight (위협감 강조)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 80, 80)
	light.Brightness = 3
	light.Range = 12
	light.Parent = mobBody

	-- BillboardGui 라벨 (경고 아이콘)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ChaseMobLabel"
	billboard.Size = UDim2.new(0, 70, 0, 70)
	billboard.StudsOffset = Vector3.new(0, cfg.SIZE.Y / 2 + 3.5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = mobBody

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "😈"
	icon.TextScaled = true
	icon.Parent = billboard

	-- 색상 펄스 애니메이션 (빨강 ↔ 어두운 빨강 반복)
	task.defer(function()
		local pulseColor = Color3.fromRGB(255, 30, 30)
		local baseColor = cfg.COLOR
		while mobBody and mobBody.Parent do
			TweenService:Create(
				mobBody,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Color = pulseColor }
			):Play()
			task.wait(0.35)
			if not mobBody or not mobBody.Parent then break end
			TweenService:Create(
				mobBody,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Color = baseColor }
			):Play()
			task.wait(0.35)
		end
	end)

	-- 클라이언트에 경고 알림 전송
	RemoteEvents.ChaseMobWarning:FireClient(self._player)

	local mobData: ChaseMobData = {
		part = mobBody,
		label = billboard,
		spawnTime = tick(),
		lastUpdateTime = tick(),
	}
	table.insert(self._activeChaseMobs, mobData)
	print(`[ObstacleService] Spawned ChaseMob behind {self._player.Name} at {mobBody.Position}`)
end

-- Chase Mob 위치 업데이트 (GameManager Heartbeat에서 호출)
-- playerPosition: 현재 플레이어 HRP 위치
-- playerSpeed: 서버에서 추정한 현재 플레이어 속도 (studs/s)
-- isFever: 현재 피버 상태 여부
function ObstacleService:UpdateChaseMobs(playerPosition: Vector3, playerSpeed: number, isFever: boolean): boolean
	local cfg = GameConstants.CHASE_MOB
	local now = tick()
	local hitDetected = false

	for i = #self._activeChaseMobs, 1, -1 do
		local mobData = self._activeChaseMobs[i]
		local mobPart = mobData.part

		-- 파트 유효성 체크
		if not mobPart or not mobPart.Parent then
			table.remove(self._activeChaseMobs, i)
			continue
		end

		-- 최대 지속 시간 초과 시 제거
		local age = now - mobData.spawnTime
		if age >= cfg.DURATION then
			mobPart:Destroy()
			table.remove(self._activeChaseMobs, i)
			print(`[ObstacleService] ChaseMob expired after {cfg.DURATION}s`)
			continue
		end

		-- 플레이어와의 X 거리 계산
		local dx = playerPosition.X - mobPart.Position.X

		-- 피버 상태에서 일정 거리 이상 벌어지면 탈출 성공 → 제거
		if isFever and dx > cfg.ESCAPE_DISTANCE then
			mobPart:Destroy()
			table.remove(self._activeChaseMobs, i)
			print(`[ObstacleService] ChaseMob escaped (fever)! Distance: {dx}`)
			continue
		end

		-- 이동: 플레이어 속도 - SPEED_OFFSET만큼 X축으로 추격
		local mobSpeed = math.max(0, playerSpeed + cfg.SPEED_OFFSET)
		local dt = now - mobData.lastUpdateTime
		mobData.lastUpdateTime = now

		local newX = mobPart.Position.X + mobSpeed * dt
		mobPart.Position = Vector3.new(newX, mobPart.Position.Y, mobPart.Position.Z)

		-- 피격 판정: 플레이어와의 거리가 CATCH_DISTANCE 이하
		if not self._isInvincible and dx <= cfg.CATCH_DISTANCE and dx >= -cfg.CATCH_DISTANCE then
			hitDetected = true
			mobPart:Destroy()
			table.remove(self._activeChaseMobs, i)
			print(`[ObstacleService] ChaseMob caught {self._player.Name}! Distance: {dx}`)
		end
	end

	return hitDetected
end

-- Hard 청크 스폰 시 Chase Mob 등장 여부 결정 (ChunkService에서 호출)
-- _lastPlayerPosition 을 사용하므로 UpdatePlayerPosition이 먼저 호출되어야 함
function ObstacleService:TrySpawnChaseMobForChunk(difficulty: string)
	if difficulty ~= "Hard" then
		return
	end

	-- 게임 시작 후 MIN_TIME 이후부터만 등장
	local elapsed = tick() - self._gameStartTime
	if elapsed < GameConstants.CHASE_MOB.MIN_TIME then
		return
	end

	-- 확률 체크
	if math.random() >= GameConstants.CHASE_MOB.SPAWN_CHANCE then
		return
	end

	self:SpawnChaseMob(self._lastPlayerPosition)
end

-- 장애물 정보 타입 (위치 + 타입)
export type ObstacleInfo = {
	position: Vector3,
	obstacleType: string,
}

-- 리듬 패턴 생성 (OBSTACLE_RHYTHMS 기반)
-- startX: 청크 중심 기준 로컬 X — 리듬 시작 위치
-- 반응 시간 검증: 각 beat 간격이 RHYTHM_MIN_GAP 미만이면 자동 확장
function ObstacleService:_spawnObstacleRhythm(
	difficulty: string,
	startX: number,
	chunkCFrame: CFrame,
	chunkHalfX: number
): { ObstacleInfo }
	local rhythmPool = if difficulty == "Hard"
		then GameConstants.OBSTACLE_RHYTHMS.hard
		else GameConstants.OBSTACLE_RHYTHMS.normal
	if not rhythmPool or #rhythmPool == 0 then
		return {}
	end

	local rhythm = rhythmPool[math.random(1, #rhythmPool)]
	local spawnedInfos: { ObstacleInfo } = {}
	local MIN_GAP = GameConstants.RHYTHM_MIN_GAP

	-- 반응 시간 검증: beat 간격이 MIN_GAP 미만이면 확장
	local adjustedBeats: { { type: string, xOffset: number } } = {}
	local prevOffset = -math.huge
	for _, beat in rhythm.beats do
		local offset = beat.xOffset
		-- 이전 beat와의 간격이 MIN_GAP 미만이면 밀어냄
		if prevOffset ~= -math.huge and offset - prevOffset < MIN_GAP then
			offset = prevOffset + MIN_GAP
		end
		table.insert(adjustedBeats, { type = beat.type, xOffset = offset })
		prevOffset = offset
	end

	for _, beat in adjustedBeats do
		local localX = startX + beat.xOffset
		if localX > chunkHalfX - 5 then
			break
		end
		local worldPos = chunkCFrame.Position + Vector3.new(localX, 0, 0)
		self:_spawnObstacle(worldPos, beat.type)
		table.insert(spawnedInfos, { position = worldPos, obstacleType = beat.type })
	end

	if #spawnedInfos > 0 then
		print(`[ObstacleService] Spawned rhythm '{rhythm.name}' difficulty={difficulty} startX={startX}`)
	end
	return spawnedInfos
end

-- 콤보 패턴 생성 (청크 로컬 X 오프셋 기준으로 월드 위치 계산)
-- baseX: 청크 중심 기준 로컬 X 오프셋 (obstacleX와 동일 좌표계)
function ObstacleService:_spawnObstacleCombo(
	difficulty: string,
	baseX: number,
	chunkCFrame: CFrame,
	chunkHalfX: number
): { ObstacleInfo }
	local comboPool = if difficulty == "Hard"
		then GameConstants.OBSTACLE_COMBOS.hard
		else GameConstants.OBSTACLE_COMBOS.normal
	if not comboPool or #comboPool == 0 then
		return {}
	end

	local combo = comboPool[math.random(1, #comboPool)]
	local spawnedInfos: { ObstacleInfo } = {}

	for _, entry in combo.obstacles do
		local localX = baseX + entry.xOffset
		-- 청크 우측 경계 5 studs 여유 체크 (chunkHalfX - 5)
		if localX > chunkHalfX - 5 then
			break
		end
		local worldPos = chunkCFrame.Position + Vector3.new(localX, 0, 0)
		self:_spawnObstacle(worldPos, entry.type)
		table.insert(spawnedInfos, { position = worldPos, obstacleType = entry.type })
	end

	if #spawnedInfos > 0 then
		print(`[ObstacleService] Spawned combo '{combo.name}' difficulty={difficulty} baseX={baseX}`)
	end
	return spawnedInfos
end

-- 청크 내 장애물 생성 (생성된 장애물 정보 목록 반환 — 위치 + 타입)
function ObstacleService:SpawnObstaclesInChunk(chunk: Model, difficulty: string): { ObstacleInfo }
	local obstacleInfos: { ObstacleInfo } = {}

	-- 난이도별 장애물 개수 결정
	local obstacleCount = self:_getObstacleCountForDifficulty(difficulty)

	-- 청크 경계 계산
	local chunkCFrame = chunk:GetPrimaryPartCFrame()
	local chunkSize = chunk:GetExtentsSize()

	-- 장애물 배치 (간격 확보)
	-- ENTRY_SAFE: 청크 진입 직후 안전 구역 (이전 청크 장애물 회피 후 즉각 판단 방지)
	local ENTRY_SAFE = 15 -- 진입 15studs 안전 (52studs/s 기준 약 0.29초 반응 시간 보장)
	local availableLength = chunkSize.X - ENTRY_SAFE - 5 -- 진입 15 + 종료 5 여유

	-- Hard 청크: 최소 반응 간격 보장 (SPEED_MAX * 0.4초 = ~20.8 studs)
	if difficulty == "Hard" and obstacleCount > 1 then
		local MIN_OBSTACLE_GAP = GameConstants.PHYSICS.SPEED_MAX * 0.4
		local segmentLength = availableLength / obstacleCount
		while obstacleCount > 1 and segmentLength < MIN_OBSTACLE_GAP do
			obstacleCount = obstacleCount - 1
			segmentLength = availableLength / obstacleCount
		end
	end

	local chunkHalfX = chunkSize.X / 2
	-- 청크 시작 기준 로컬 X (왼쪽 끝 + 안전 진입 구간)
	local startX = -chunkHalfX + ENTRY_SAFE

	-- 리듬 패턴 우선 시도 (Normal 40%, Hard 60%)
	local rhythmChance = GameConstants.RHYTHM_CHANCE[difficulty] or 0
	if rhythmChance > 0 and math.random() < rhythmChance then
		local rhythmInfos = self:_spawnObstacleRhythm(difficulty, startX, chunkCFrame, chunkHalfX)
		if #rhythmInfos > 0 then
			-- 리듬이 청크를 채우므로 전체 obstacleInfos에 복사 후 반환
			for _, info in rhythmInfos do
				table.insert(obstacleInfos, info)
			end
			return obstacleInfos
		end
	end

	-- 리듬 미적용 시: 기존 콤보 → 단독 랜덤 배치 (하위호환)
	local comboChance = if difficulty == "Hard" then 0.25 elseif difficulty == "Normal" then 0.15 else 0
	local useCombo = comboChance > 0 and math.random() < comboChance

	for i = 1, obstacleCount do
		-- 장애물 위치 계산 (균등 배치 + 약간의 랜덤)
		local segmentLength = availableLength / obstacleCount
		local baseX = -chunkHalfX + ENTRY_SAFE + (i - 1) * segmentLength + segmentLength / 2
		local randomOffset = (math.random() - 0.5) * (segmentLength * 0.3)
		local obstacleX = baseX + randomOffset

		-- 첫 번째 슬롯에서 콤보 시도
		if i == 1 and useCombo then
			local comboInfos = self:_spawnObstacleCombo(difficulty, obstacleX, chunkCFrame, chunkHalfX)
			if #comboInfos > 0 then
				table.insert(obstacleInfos, comboInfos[1])
				-- 콤보가 청크 공간을 채우므로 나머지 단독 장애물은 스킵
				break
			end
			-- 콤보 풀이 비어있거나 실패했으면 단독 장애물로 폴백
		end

		local obstaclePosition = chunkCFrame.Position + Vector3.new(obstacleX, 0, 0)

		-- 장애물 타입 선택
		local obstacleType = self:_selectObstacleType(difficulty)

		-- 장애물 생성
		self:_spawnObstacle(obstaclePosition, obstacleType)

		table.insert(obstacleInfos, { position = obstaclePosition, obstacleType = obstacleType })
	end

	return obstacleInfos
end

-- 난이도별 장애물 개수 결정
function ObstacleService:_getObstacleCountForDifficulty(difficulty: string): number
	if difficulty == "Easy" then
		return math.random(0, 1) -- 쉬운 청크: 장애물 거의 없음 (0-1개)
	elseif difficulty == "Normal" then
		return math.random(1, 2) -- 보통: 1-2개
	elseif difficulty == "Hard" then
		return math.random(2, 4) -- 어려운 청크: 장애물 많음
	elseif difficulty == "Bonus" then
		return 0 -- 보너스는 장애물 없음
	elseif difficulty == "NPC" then
		return math.random(0, 1) -- NPC 청크도 장애물 적게
	end

	return 1 -- 기본값
end

-- 장애물 타입 선택
function ObstacleService:_selectObstacleType(difficulty: string): string
	local rand = math.random()

	if difficulty == "Easy" then
		-- Easy는 Low Wall만 (점프만 연습)
		return "LowWall"
	elseif difficulty == "Normal" then
		-- Normal: Low Wall + Tunnel + SpikeTrap + ExplodingBarrel (20%)
		if rand < 0.20 then
			return "ExplodingBarrel"
		elseif rand < 0.50 then
			return "LowWall"
		elseif rand < 0.78 then
			return "Tunnel"
		elseif rand < 0.93 then
			return "SpikeTrap"
		else
			return "Gap"
		end
	elseif difficulty == "Hard" then
		-- Hard: 모든 타입 + ExplodingBarrel (30%), ChaseMob은 SpawnObstaclesInChunk에서 별도 처리
		if rand < 0.30 then
			return "ExplodingBarrel"
		elseif rand < 0.49 then
			return "LowWall"
		elseif rand < 0.65 then
			return "Tunnel"
		elseif rand < 0.76 then
			return "SpikeTrap"
		elseif rand < 0.88 then
			return "DoubleWall"
		elseif rand < 0.96 then
			return "MovingWall"
		else
			return "Gap"
		end
	else
		return "LowWall"
	end
end

-- 장애물 생성 (BasePart)
function ObstacleService:_spawnObstacle(position: Vector3, obstacleType: string)
	local obstacle: BasePart

	if obstacleType == "LowWall" then
		-- 낮은 벽 (점프로 회피)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_LowWall"
		obstacle.Size = Vector3.new(2, GameConstants.OBSTACLE.LOW_WALL_HEIGHT, 10) -- 폭×높이×깊이
		obstacle.Position = position + Vector3.new(0, GameConstants.OBSTACLE.LOW_WALL_HEIGHT / 2, 0)
		obstacle.Color = Color3.fromRGB(200, 60, 60) -- 빨간색 (점프 = 빨간색)
		obstacle.Material = Enum.Material.SmoothPlastic
		obstacle.Transparency = 0.1
	elseif obstacleType == "Tunnel" then
		-- 공중 장애물 (슬라이드로 통과)
		-- 아래 공간은 비워두고 위쪽만 장애물로 생성
		local tunnelHeight = GameConstants.OBSTACLE.TUNNEL_HEIGHT -- 통과 가능한 높이 (3)
		local obstacleHeight = 6 -- 장애물 높이

		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_Tunnel"
		obstacle.Size = Vector3.new(4, obstacleHeight, 12)
		-- Y 위치: 터널 높이 위에 장애물 배치
		obstacle.Position = position + Vector3.new(0, tunnelHeight + obstacleHeight / 2, 0)
		obstacle.Color = Color3.fromRGB(0, 120, 200) -- 파란색 (슬라이드 = 파란색)
		obstacle.Material = Enum.Material.SmoothPlastic
		obstacle.Transparency = 0.2
	elseif obstacleType == "SpikeTrap" then
		-- 가시 함정 (바닥에 설치, 점프로 회피)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_SpikeTrap"
		obstacle.Size = Vector3.new(5, 2, 10)
		obstacle.Position = position + Vector3.new(0, 1, 0)
		obstacle.Color = Color3.fromRGB(255, 50, 50)
		obstacle.Material = Enum.Material.DiamondPlate
	elseif obstacleType == "DoubleWall" then
		-- 이중 벽 (두 번 점프 필요)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_DoubleWall"
		obstacle.Size = Vector3.new(2, GameConstants.OBSTACLE.LOW_WALL_HEIGHT, 8)
		obstacle.Position = position + Vector3.new(0, GameConstants.OBSTACLE.LOW_WALL_HEIGHT / 2, 0)
		obstacle.BrickColor = BrickColor.new("Bright red")

		-- 두 번째 벽 (첫 번째 벽 뒤에)
		local secondWall = Instance.new("Part")
		secondWall.Name = "Obstacle_DoubleWall_2"
		secondWall.Size = Vector3.new(2, GameConstants.OBSTACLE.LOW_WALL_HEIGHT + 1, 8)
		secondWall.Position = position + Vector3.new(5, (GameConstants.OBSTACLE.LOW_WALL_HEIGHT + 1) / 2, 0)
		secondWall.BrickColor = BrickColor.new("Bright red")
		secondWall.Anchored = true
		secondWall.CanCollide = false -- 저연령층 게임: 장애물 통과 가능
		secondWall.Material = Enum.Material.SmoothPlastic
		secondWall:SetAttribute("ObstacleType", "DoubleWall")
		secondWall.Parent = workspace

		-- 두 번째 벽도 장애물 데이터에 추가
		local secondWallData: ObstacleData = {
			part = secondWall,
			obstacleType = "DoubleWall",
			spawnTime = tick(),
		}
		table.insert(self._activeObstacles, secondWallData)
	elseif obstacleType == "Gap" then
		-- 구덩이 (점프로 건너기)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_Gap"
		local gapWidth = math.random(GameConstants.OBSTACLE.GAP_WIDTH_MIN, GameConstants.OBSTACLE.GAP_WIDTH_MAX)
		obstacle.Size = Vector3.new(gapWidth, 1, 12) -- 바닥 구멍
		obstacle.Position = position + Vector3.new(0, -5, 0) -- 아래로 내림 (낙사 판정용)
		obstacle.Color = Color3.fromRGB(30, 30, 30)
		obstacle.Transparency = 0.3

		-- 구덩이 테두리 (주황색 네온)
		for _, xOffset in { -gapWidth / 2 - 0.3, gapWidth / 2 + 0.3 } do
			local edge = Instance.new("Part")
			edge.Name = "GapEdge"
			edge.Size = Vector3.new(0.5, 1, 12)
			edge.Position = position + Vector3.new(xOffset, 0.5, 0)
			edge.Color = Color3.fromRGB(255, 100, 0)
			edge.Material = Enum.Material.Neon
			edge.CanCollide = false
			edge.Anchored = true
			edge.Parent = workspace
		end
	elseif obstacleType == "MovingWall" then
		-- 움직이는 벽 (Hard 전용, 타이밍 점프/통과로 회피)
		local wallHeight = GameConstants.OBSTACLE.MOVING_WALL_HEIGHT
		local wallWidth = GameConstants.OBSTACLE.MOVING_WALL_WIDTH
		local startHigh = math.random() > 0.5

		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_MovingWall"
		obstacle.Size = Vector3.new(wallWidth, wallHeight, 10)
		obstacle.Color = Color3.fromRGB(220, 50, 200) -- 마젠타 (움직이는 벽 = 마젠타)
		obstacle.Material = Enum.Material.Neon
		obstacle.Transparency = 0.1

		-- 시작 위치 (랜덤 위상)
		local yBottom = position.Y + wallHeight / 2
		local yTop = position.Y + GameConstants.OBSTACLE.MOVING_WALL_Y_MAX + wallHeight / 2
		obstacle.Position = if startHigh
			then position + Vector3.new(0, GameConstants.OBSTACLE.MOVING_WALL_Y_MAX + wallHeight / 2, 0)
			else position + Vector3.new(0, wallHeight / 2, 0)

		obstacle.Anchored = true
		obstacle.CanCollide = false
		obstacle.Material = Enum.Material.Neon
		obstacle:SetAttribute("ObstacleType", obstacleType)

		-- 구역 색상 틴트 적용 (60% 구역 색상 영향)
		local mwZoneColor = self:_getZoneObstacleColor()
		local mwBaseColor = obstacle.Color
		obstacle.Color = Color3.new(
			mwBaseColor.R * 0.40 + mwZoneColor.R * 0.60,
			mwBaseColor.G * 0.40 + mwZoneColor.G * 0.60,
			mwBaseColor.B * 0.40 + mwZoneColor.B * 0.60
		)

		obstacle.Parent = workspace

		-- 상하 왕복 트윈 시작 (자동 클라이언트 복제)
		task.defer(function()
			if obstacle and obstacle.Parent then
				local halfCycle = GameConstants.OBSTACLE.MOVING_WALL_CYCLE_TIME / 2
				local targetY = if startHigh then yBottom else yTop
				local tweenInfo = TweenInfo.new(halfCycle, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				TweenService:Create(obstacle, tweenInfo, {
					Position = Vector3.new(obstacle.Position.X, targetY, obstacle.Position.Z),
				}):Play()
			end
		end)

		-- 장애물 데이터 저장 후 return (아래 공통 코드 건너뜀)
		local obstacleData: ObstacleData = {
			part = obstacle,
			obstacleType = obstacleType,
			spawnTime = tick(),
		}
		table.insert(self._activeObstacles, obstacleData)
		print(`[ObstacleService] Spawned MovingWall at {position} (startHigh: {startHigh})`)
		return
	elseif obstacleType == "ExplodingBarrel" then
		-- 폭발 배럴 (Normal/Hard 전용, 범위 피해)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_ExplodingBarrel"
		obstacle.Size = GameConstants.EXPLODING_BARREL.SIZE
		obstacle.Position = position + Vector3.new(0, GameConstants.EXPLODING_BARREL.SIZE.Y / 2, 0)
		obstacle.Color = GameConstants.EXPLODING_BARREL.COLOR
		obstacle.Material = Enum.Material.SmoothPlastic
		obstacle.Transparency = 0.05
		obstacle.Shape = Enum.PartType.Cylinder

		-- 경고 PointLight (빨간 빛)
		local warnLight = Instance.new("PointLight")
		warnLight.Brightness = GameConstants.EXPLODING_BARREL.LIGHT_BRIGHTNESS
		warnLight.Range = GameConstants.EXPLODING_BARREL.LIGHT_RANGE
		warnLight.Color = Color3.fromRGB(255, 80, 30)
		warnLight.Parent = obstacle

		-- 폭발 위험 BillboardGui 라벨
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "BarrelLabel"
		billboard.Size = UDim2.new(0, 50, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = false
		billboard.Parent = obstacle

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.new(1, 0, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Text = "💥"
		icon.TextScaled = true
		icon.Parent = billboard

		-- 스폰 후 경고 점멸 이펙트 (0.5초 동안 빛 깜빡임)
		task.delay(0, function()
			if not obstacle or not obstacle.Parent then
				return
			end
			local pulseCount = 3
			local pulseDuration = GameConstants.EXPLODING_BARREL.WARNING_DURATION / (pulseCount * 2)
			for _ = 1, pulseCount do
				if not obstacle or not obstacle.Parent then
					break
				end
				warnLight.Brightness = GameConstants.EXPLODING_BARREL.LIGHT_BRIGHTNESS * 3
				task.wait(pulseDuration)
				if not obstacle or not obstacle.Parent then
					break
				end
				warnLight.Brightness = GameConstants.EXPLODING_BARREL.LIGHT_BRIGHTNESS
				task.wait(pulseDuration)
			end
		end)

		obstacle.Anchored = true
		obstacle.CanCollide = false
		obstacle:SetAttribute("ObstacleType", obstacleType)

		-- 구역 색상 틴트 적용 (60% 구역 색상 영향)
		local ebZoneColor = self:_getZoneObstacleColor()
		local ebBaseColor = obstacle.Color
		obstacle.Color = Color3.new(
			ebBaseColor.R * 0.40 + ebZoneColor.R * 0.60,
			ebBaseColor.G * 0.40 + ebZoneColor.G * 0.60,
			ebBaseColor.B * 0.40 + ebZoneColor.B * 0.60
		)

		obstacle.Parent = workspace

		-- 장애물 데이터 저장 후 return (공통 코드 건너뜀, 이미 Anchored/CanCollide 설정됨)
		local obstacleData: ObstacleData = {
			part = obstacle,
			obstacleType = obstacleType,
			spawnTime = tick(),
		}
		table.insert(self._activeObstacles, obstacleData)
		print(`[ObstacleService] Spawned ExplodingBarrel at {position}`)
		return
	else
		obstacle = Instance.new("Part")
		obstacle.Size = Vector3.new(2, 4, 8)
		obstacle.Position = position
	end

	obstacle.Anchored = true
	obstacle.CanCollide = false -- 저연령층 게임: 장애물 통과 가능 (에너지만 감소)
	obstacle.Material = Enum.Material.SmoothPlastic
	obstacle:SetAttribute("ObstacleType", obstacleType)

	-- 구역 색상 틴트 적용 (60% 구역 색상 영향)
	local zoneColor = self:_getZoneObstacleColor()
	local baseColor = obstacle.Color
	obstacle.Color = Color3.new(
		baseColor.R * 0.40 + zoneColor.R * 0.60,
		baseColor.G * 0.40 + zoneColor.G * 0.60,
		baseColor.B * 0.40 + zoneColor.B * 0.60
	)

	obstacle.Parent = workspace

	-- 장애물 데이터 저장
	local obstacleData: ObstacleData = {
		part = obstacle,
		obstacleType = obstacleType,
		spawnTime = tick(),
	}
	table.insert(self._activeObstacles, obstacleData)
end

-- 충돌 체크 (GameManager에서 호출)
function ObstacleService:CheckObstacleCollision(playerPosition: Vector3, isSliding: boolean, isMini: boolean?): boolean
	-- 무적 상태 확인
	if self._isInvincible then
		local elapsed = tick() - self._lastHitTime
		if elapsed >= GameConstants.LIFE.INVINCIBLE_DURATION then
			self._isInvincible = false
			print(`[ObstacleService] Invincibility ended for {self._player.Name}`)
		else
			return false -- 무적 중에는 충돌 무시
		end
	end

	for _, obstacleData in self._activeObstacles do
		local obstaclePart = obstacleData.part
		local obstacleType = obstacleData.obstacleType

		-- Skip obstacles that already caused a collision (prevents re-hit after slide end)
		if self._collidedObstacles[obstaclePart] then
			continue
		end

		-- X-axis distance for side-scrolling runner
		-- (Y is handled by type-specific evasion checks below)
		local xDistance = math.abs(obstaclePart.Position.X - playerPosition.X)

		-- Collision range: half obstacle width + player body margin
		-- Mini size reduces player margin (smaller hitbox)
		local PLAYER_MARGIN = if isMini then 1 else 2
		local collisionRadius = obstaclePart.Size.X / 2 + PLAYER_MARGIN

		-- ExplodingBarrel: 폭발 반경(4 studs) 이내이면 collisionRadius를 덮어씀
		if obstacleType == "ExplodingBarrel" then
			collisionRadius = math.max(collisionRadius, GameConstants.EXPLODING_BARREL.EXPLOSION_RADIUS)
		end

		if xDistance < collisionRadius then
			-- 장애물 타입별 회피 조건 확인
			if obstacleType == "LowWall" then
				-- LowWall: 점프 중이면 회피 성공
				if playerPosition.Y > GameConstants.OBSTACLE.LOW_WALL_HEIGHT then
					print(`[ObstacleService] {self._player.Name} jumped over LowWall!`)
					continue
				else
					self._collidedObstacles[obstaclePart] = true
					return true
				end
			elseif obstacleType == "ExplodingBarrel" then
				-- ExplodingBarrel: 점프로 피할 수 없음 (범위 피해), 단 공중 높이에서는 범위 외
				local barrelTop = obstaclePart.Position.Y + obstaclePart.Size.Y / 2
				if playerPosition.Y > barrelTop + GameConstants.EXPLODING_BARREL.EXPLOSION_RADIUS then
					-- 배럴 훨씬 위로 점프 시 회피
					print(`[ObstacleService] {self._player.Name} jumped over ExplodingBarrel!`)
					continue
				else
					self._collidedObstacles[obstaclePart] = true
					print(`[ObstacleService] {self._player.Name} caught in ExplodingBarrel blast!`)
					return true
				end
			elseif obstacleType == "Tunnel" then
				-- Tunnel: 슬라이드 중이거나 미니 사이즈이면 통과 가능
				local tunnelHeight = GameConstants.OBSTACLE.TUNNEL_HEIGHT
				local playerHeight = playerPosition.Y

				if isMini and playerHeight < tunnelHeight + 1 then
					-- 미니 사이즈: 슬라이드 없이 터널 통과
					print(`[ObstacleService] {self._player.Name} walked through Tunnel (MiniSize)!`)
					continue
				elseif isSliding and playerHeight < tunnelHeight then
					-- 슬라이드로 통과 성공
					print(`[ObstacleService] {self._player.Name} slid through Tunnel! (Y: {playerHeight})`)
					continue
				elseif playerHeight < tunnelHeight then
					-- 슬라이드 안하고 낮은 위치 - 통과 (달리다가 우연히 통과)
					print(`[ObstacleService] {self._player.Name} passed under Tunnel (Y: {playerHeight})`)
					continue
				else
					-- 충돌 (서 있거나 점프 중인데 터널 높이 이상)
					self._collidedObstacles[obstaclePart] = true
					print(`[ObstacleService] {self._player.Name} hit Tunnel! (Y: {playerHeight}, sliding: {isSliding})`)
					return true
				end
			elseif obstacleType == "SpikeTrap" then
				-- SpikeTrap: 점프로 회피 (가시 함정 높이 3.5 이상)
				if playerPosition.Y > 3.5 then
					print(`[ObstacleService] {self._player.Name} jumped over SpikeTrap!`)
					continue
				else
					self._collidedObstacles[obstaclePart] = true
					return true
				end
			elseif obstacleType == "DoubleWall" then
				-- DoubleWall: 점프로 회피 (연속 점프 필요)
				if playerPosition.Y > GameConstants.OBSTACLE.LOW_WALL_HEIGHT then
					print(`[ObstacleService] {self._player.Name} jumped over DoubleWall!`)
					continue
				else
					self._collidedObstacles[obstaclePart] = true
					return true
				end
			elseif obstacleType == "MovingWall" then
				-- MovingWall: 벽 위로 점프하거나 아래로 통과
				local wallBottom = obstaclePart.Position.Y - obstaclePart.Size.Y / 2
				local wallTop = obstaclePart.Position.Y + obstaclePart.Size.Y / 2

				if playerPosition.Y > wallTop then
					-- 벽 위로 점프 성공
					print(`[ObstacleService] {self._player.Name} jumped over MovingWall!`)
					continue
				elseif playerPosition.Y < wallBottom - 0.5 then
					-- 벽이 높아서 아래로 통과
					print(`[ObstacleService] {self._player.Name} passed under MovingWall!`)
					continue
				else
					-- 충돌
					self._collidedObstacles[obstaclePart] = true
					return true
				end
			elseif obstacleType == "Gap" then
				-- Gap: 점프 중이면 회피 성공
				if playerPosition.Y > 2 then
					print(`[ObstacleService] {self._player.Name} jumped over Gap!`)
					continue
				else
					self._collidedObstacles[obstaclePart] = true
					return true
				end
			end
		end
	end

	return false -- 충돌 없음
end

-- 충돌 처리 (라이프 감소 및 무적 설정)
function ObstacleService:OnObstacleHit()
	self._isInvincible = true
	self._lastHitTime = tick()
	print(
		`[ObstacleService] {self._player.Name} hit obstacle! Invincible for {GameConstants.LIFE.INVINCIBLE_DURATION}s`
	)
end

-- 무적 상태 확인
function ObstacleService:IsInvincible(): boolean
	return self._isInvincible
end

-- 니어미스 감지 (GameManager에서 호출)
function ObstacleService:CheckNearMiss(
	playerPosition: Vector3,
	isSliding: boolean,
	nearMissedSet: { [any]: boolean },
	_isMini: boolean?
): { BasePart }
	local nearMisses = {}
	local NEAR_MISS_X_RANGE = GameConstants.OBSTACLE.NEAR_MISS_X_RANGE
	local NEAR_MISS_Y_MARGIN = GameConstants.OBSTACLE.NEAR_MISS_Y_MARGIN

	for _, obstacleData in self._activeObstacles do
		local obstaclePart = obstacleData.part

		-- Skip if already near-missed
		if nearMissedSet[obstaclePart] then
			continue
		end

		local obstacleType = obstacleData.obstacleType
		local dx = playerPosition.X - obstaclePart.Position.X

		-- Player must be passing the obstacle (at or just past it)
		if dx < -1 or dx > NEAR_MISS_X_RANGE then
			continue
		end

		-- Check Y proximity for a "close call" dodge
		local isNearMiss = false

		if obstacleType == "LowWall" or obstacleType == "DoubleWall" then
			local wallTop = GameConstants.OBSTACLE.LOW_WALL_HEIGHT
			-- Jumped over and barely cleared
			if playerPosition.Y > wallTop and playerPosition.Y < wallTop + NEAR_MISS_Y_MARGIN then
				isNearMiss = true
			end
		elseif obstacleType == "SpikeTrap" then
			-- Jumped over spikes, barely cleared
			if playerPosition.Y > 3.5 and playerPosition.Y < 3.5 + NEAR_MISS_Y_MARGIN then
				isNearMiss = true
			end
		elseif obstacleType == "Tunnel" then
			local tunnelBottom = GameConstants.OBSTACLE.TUNNEL_HEIGHT
			-- Slid under and barely fit (must be actively sliding)
			if
				isSliding
				and playerPosition.Y < tunnelBottom
				and playerPosition.Y > tunnelBottom - NEAR_MISS_Y_MARGIN
			then
				isNearMiss = true
			end
		elseif obstacleType == "Gap" then
			-- Jumped over gap, barely cleared
			if playerPosition.Y > 2 and playerPosition.Y < 2 + NEAR_MISS_Y_MARGIN then
				isNearMiss = true
			end
		elseif obstacleType == "MovingWall" then
			-- MovingWall: barely jumped over or passed under
			local wallTop = obstaclePart.Position.Y + obstaclePart.Size.Y / 2
			local wallBottom = obstaclePart.Position.Y - obstaclePart.Size.Y / 2
			local justOverTop = playerPosition.Y > wallTop and playerPosition.Y < wallTop + NEAR_MISS_Y_MARGIN
			local justUnderBottom = playerPosition.Y < wallBottom and playerPosition.Y > wallBottom - NEAR_MISS_Y_MARGIN
			if justOverTop or justUnderBottom then
				isNearMiss = true
			end
		elseif obstacleType == "ExplodingBarrel" then
			-- ExplodingBarrel: 폭발 반경 바로 바깥으로 빠져나갈 때 니어미스
			-- dx = playerX - barrelX (양수: 플레이어가 배럴보다 앞에 있음)
			local blastRadius = GameConstants.EXPLODING_BARREL.EXPLOSION_RADIUS
			local absDx = math.abs(dx)
			if absDx >= blastRadius and absDx < blastRadius + NEAR_MISS_X_RANGE then
				isNearMiss = true
			end
		end

		if isNearMiss then
			table.insert(nearMisses, obstaclePart)
		end
	end

	return nearMisses
end

-- 청크 삭제 시 관련 장애물 정리
function ObstacleService:CleanupObstaclesInChunk(chunkPosition: Vector3, chunkSize: Vector3)
	for i = #self._activeObstacles, 1, -1 do
		local obstacleData = self._activeObstacles[i]
		local obstaclePos = obstacleData.part.Position

		-- 장애물이 청크 영역 내에 있는지 확인
		local isInChunk = math.abs(obstaclePos.X - chunkPosition.X) < chunkSize.X / 2
			and math.abs(obstaclePos.Y - chunkPosition.Y) < chunkSize.Y / 2
			and math.abs(obstaclePos.Z - chunkPosition.Z) < chunkSize.Z / 2

		if isInChunk then
			self._collidedObstacles[obstacleData.part] = nil
			obstacleData.part:Destroy()
			table.remove(self._activeObstacles, i)
		end
	end
end

-- 모든 장애물 정리 (게임 종료 시)
function ObstacleService:Destroy()
	for _, obstacleData in self._activeObstacles do
		if obstacleData.part then
			obstacleData.part:Destroy()
		end
	end
	self._activeObstacles = {}
	self._collidedObstacles = {}

	-- Chase Mob 정리
	for _, mobData in self._activeChaseMobs do
		if mobData.part then
			mobData.part:Destroy()
		end
	end
	self._activeChaseMobs = {}
end

return ObstacleService

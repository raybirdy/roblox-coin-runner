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

-- MushroomPad 전용 데이터 (유익 오브젝트 — 밟으면 점프력 증폭)
type MushroomPadData = {
	part: BasePart,
	spawnTime: number,
	lastBounceTime: number, -- 마지막 bounce 시각 (쿨다운용)
}

export type ObstacleService = typeof(setmetatable(
	{} :: {
		_activeObstacles: { ObstacleData },
		_activeChaseMobs: { ChaseMobData }, -- 활성 추격 NPC 목록
		_activeMushroomPads: { MushroomPadData }, -- 활성 버섯 패드 목록
		_player: Player,
		_lastHitTime: number,
		_isInvincible: boolean,
		_collidedObstacles: { [BasePart]: boolean }, -- already-hit tracking
		_gameStartTime: number, -- 게임 시작 시간 (Chase Mob MIN_TIME 판단용)
		_lastPlayerPosition: Vector3, -- 가장 최근의 플레이어 위치 (Chase Mob 스폰용)
		_currentZoneIndex: number, -- 현재 구역 인덱스 (장애물 색상 테마용)
		_gravityZoneActive: boolean, -- 저중력 구간 활성 여부
	},
	ObstacleService
))

function ObstacleService.new(player: Player): ObstacleService
	local self = setmetatable({
		_activeObstacles = {},
		_activeChaseMobs = {},
		_activeMushroomPads = {},
		_player = player,
		_lastHitTime = 0,
		_isInvincible = false,
		_collidedObstacles = {},
		_gameStartTime = 0,
		_lastPlayerPosition = Vector3.zero,
		_currentZoneIndex = 1,
		_gravityZoneActive = false,
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

-- 단일 장애물을 지정 위치에 생성 (Encounter 시스템 — IDEA-010)
function ObstacleService:SpawnObstacleAt(obstacleType: string, position: Vector3)
	self:_spawnObstacle(position, obstacleType)
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

		-- 존 제한 필터링: 특정 장애물은 해당 Zone 이후에만 등장
		-- PendulumLog/FallingRock: Zone 3+, LaserBeam: Zone 4+
		local zone = self._currentZoneIndex
		local isZoneRestricted = ((obstacleType == "PendulumLog" or obstacleType == "FallingRock") and zone < 3)
			or (obstacleType == "LaserBeam" and zone < 4)
		if isZoneRestricted then
			obstacleType = "LowWall" -- 해당 Zone 미만에서는 기본 장애물로 대체
		end

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
	elseif difficulty == "Bonus" or difficulty == "DualFloor" or difficulty == "MultiLane" then
		return 0 -- 보너스/분기맵 청크는 장애물 없음
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
		-- Normal: Low Wall + Tunnel + SpikeTrap + ExplodingBarrel + FallingRock
		-- Zone 3+ 제한은 ChunkService에서 처리, 여기는 확률만 정의
		if rand < 0.18 then
			return "ExplodingBarrel"
		elseif rand < 0.45 then
			return "LowWall"
		elseif rand < 0.68 then
			return "Tunnel"
		elseif rand < 0.82 then
			return "SpikeTrap"
		elseif rand < 0.92 then
			return "FallingRock" -- 10% (Zone 3+에서만 실제 스폰)
		else
			return "Gap"
		end
	elseif difficulty == "Hard" then
		-- Hard: 모든 타입 + 신규 5종, ChaseMob은 SpawnObstaclesInChunk에서 별도 처리
		if rand < 0.20 then
			return "ExplodingBarrel"
		elseif rand < 0.35 then
			return "LowWall"
		elseif rand < 0.48 then
			return "Tunnel"
		elseif rand < 0.56 then
			return "SpikeTrap"
		elseif rand < 0.65 then
			return "DoubleWall"
		elseif rand < 0.72 then
			return "MovingWall"
		elseif rand < 0.79 then
			return "PendulumLog" -- 7% (Zone 3+)
		elseif rand < 0.85 then
			return "LaserBeam" -- 6% (Zone 4+)
		elseif rand < 0.89 then
			return "FallingRock" -- 4% (Zone 3+)
		elseif rand < 0.94 then
			return "RotatingBar" -- 5% (IDEA-004)
		elseif rand < 0.98 then
			return "FallingDebris" -- 4% (IDEA-004)
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
	elseif obstacleType == "MushroomPad" then
		-- 버섯 트램폴린 (Zone 3 전용, 유익 오브젝트 — 밟으면 점프력 2배)
		local pad = Instance.new("Part")
		pad.Name = "MushroomPad"
		pad.Size = GameConstants.MUSHROOM_PAD.SIZE
		pad.Position = position + Vector3.new(0, GameConstants.MUSHROOM_PAD.SIZE.Y / 2, 0)
		pad.Color = GameConstants.MUSHROOM_PAD.COLOR
		pad.Material = Enum.Material.SmoothPlastic
		pad.Transparency = 0.1
		pad.Anchored = true
		pad.CanCollide = false
		pad:SetAttribute("ObstacleType", "MushroomPad")

		-- 버섯 라벨
		local bb2 = Instance.new("BillboardGui")
		bb2.Name = "MushroomLabel"
		bb2.Size = UDim2.new(0, 50, 0, 50)
		bb2.StudsOffset = Vector3.new(0, 2, 0)
		bb2.AlwaysOnTop = false
		bb2.Parent = pad

		local lbl2 = Instance.new("TextLabel")
		lbl2.Size = UDim2.new(1, 0, 1, 0)
		lbl2.BackgroundTransparency = 1
		lbl2.Text = "🍄"
		lbl2.TextScaled = true
		lbl2.Parent = bb2

		pad.Parent = workspace

		local padData: MushroomPadData = {
			part = pad,
			spawnTime = tick(),
			lastBounceTime = 0,
		}
		table.insert(self._activeMushroomPads, padData)
		print(`[ObstacleService] Spawned MushroomPad at {position}`)
		return

	elseif obstacleType == "GravityZone" then
		-- 저중력 구간 마커 (Zone 5 전용, 플레이어가 통과 시 RemoteEvent 발송)
		-- 비주얼 마커: 파란 네온 얇은 바닥 판
		local marker = Instance.new("Part")
		marker.Name = "GravityZoneMarker"
		marker.Size = GameConstants.GRAVITY_ZONE.MARKER_SIZE
		marker.Position = position + Vector3.new(0, 0.3, 0) -- 바닥 살짝 위
		marker.Color = GameConstants.GRAVITY_ZONE.MARKER_COLOR
		marker.Material = Enum.Material.Neon
		marker.Transparency = 0.5
		marker.Anchored = true
		marker.CanCollide = false
		marker:SetAttribute("ObstacleType", "GravityZone")
		marker.Parent = workspace

		-- GravityZone은 장애물이 아닌 구간 표시자 — _activeObstacles에 넣지 않음
		-- 대신 _gravityZoneActive 플래그로 관리 (GameManager가 CheckGravityZone으로 판정)
		local zoneData: ObstacleData = {
			part = marker,
			obstacleType = "GravityZone",
			spawnTime = tick(),
		}
		table.insert(self._activeObstacles, zoneData)
		print(`[ObstacleService] Spawned GravityZone marker at {position}`)
		return

	elseif obstacleType == "FlowerWind" then
		-- 꽃잎 바람 (Zone 2 전용, LowWall과 동일한 회피 동작 — 점프)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_FlowerWind"
		obstacle.Size = GameConstants.FLOWER_WIND.SIZE
		obstacle.Position = position + Vector3.new(0, GameConstants.FLOWER_WIND.SIZE.Y / 2, 0)
		obstacle.Color = GameConstants.FLOWER_WIND.COLOR
		obstacle.Material = Enum.Material.SmoothPlastic
		obstacle.Transparency = 0.3

		-- 꽃잎 파티클 BillboardGui
		local bb = Instance.new("BillboardGui")
		bb.Name = "FlowerLabel"
		bb.Size = UDim2.new(0, 40, 0, 40)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = false
		bb.Parent = obstacle

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "🌸"
		lbl.TextScaled = true
		lbl.Parent = bb

		obstacle.Anchored = true
		obstacle.CanCollide = false
		obstacle:SetAttribute("ObstacleType", obstacleType)
		obstacle.Parent = workspace

		-- 좌우 흔들림 트윈 (Sine 무한 반복)
		task.defer(function()
			if not obstacle or not obstacle.Parent then return end
			local baseX = obstacle.Position.X
			local amp = GameConstants.FLOWER_WIND.SWAY_AMPLITUDE
			local halfCycle = GameConstants.FLOWER_WIND.SWAY_CYCLE / 2
			local tweenInfo = TweenInfo.new(halfCycle, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			TweenService:Create(obstacle, tweenInfo, {
				Position = Vector3.new(baseX + amp, obstacle.Position.Y, obstacle.Position.Z),
			}):Play()
		end)

		local fwData: ObstacleData = {
			part = obstacle,
			obstacleType = obstacleType,
			spawnTime = tick(),
		}
		table.insert(self._activeObstacles, fwData)
		print(`[ObstacleService] Spawned FlowerWind at {position}`)
		return

	elseif obstacleType == "ShadowWall" then
		-- 그림자 벽 (Zone 4 전용, LowWall과 동일한 회피 — 점프, 단 서서히 나타남)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_ShadowWall"
		obstacle.Size = GameConstants.SHADOW_WALL.SIZE
		obstacle.Position = position + Vector3.new(0, GameConstants.SHADOW_WALL.SIZE.Y / 2, 0)
		obstacle.Color = GameConstants.SHADOW_WALL.COLOR
		obstacle.Material = Enum.Material.SmoothPlastic
		obstacle.Transparency = GameConstants.SHADOW_WALL.ALPHA_START -- 처음엔 거의 투명

		obstacle.Anchored = true
		obstacle.CanCollide = false
		obstacle:SetAttribute("ObstacleType", obstacleType)
		obstacle.Parent = workspace

		-- 서서히 나타나는 페이드인 트윈
		task.defer(function()
			if not obstacle or not obstacle.Parent then return end
			local tweenInfo = TweenInfo.new(
				GameConstants.SHADOW_WALL.FADE_TIME, Enum.EasingStyle.Linear, Enum.EasingDirection.Out
			)
			TweenService:Create(obstacle, tweenInfo, {
				Transparency = GameConstants.SHADOW_WALL.ALPHA_END,
			}):Play()
		end)

		local swData: ObstacleData = {
			part = obstacle,
			obstacleType = obstacleType,
			spawnTime = tick(),
		}
		table.insert(self._activeObstacles, swData)
		print(`[ObstacleService] Spawned ShadowWall at {position}`)
		return

	elseif obstacleType == "PendulumLog" then
		-- 상하 스윙 통나무 (Zone 3+, Hard 전용 — 타이밍 맞춰 통과)
		local logSize = GameConstants.PENDULUM_LOG.SIZE
		local startHigh = math.random() > 0.5

		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_PendulumLog"
		obstacle.Size = logSize
		obstacle.Color = GameConstants.PENDULUM_LOG.COLOR
		obstacle.Material = Enum.Material.WoodPlanks
		obstacle.Transparency = 0.05
		obstacle.Shape = Enum.PartType.Cylinder

		local yMin = position.Y + logSize.Y / 2
		local yMax = position.Y + GameConstants.PENDULUM_LOG.SWING_Y_MAX + logSize.Y / 2
		obstacle.Position = if startHigh
			then Vector3.new(position.X, yMax, position.Z)
			else Vector3.new(position.X, yMin, position.Z)

		obstacle.Anchored = true
		obstacle.CanCollide = false
		obstacle:SetAttribute("ObstacleType", obstacleType)

		-- 구역 색상 틴트 적용 (40% 베이스 + 60% 구역)
		local plZoneColor = self:_getZoneObstacleColor()
		local plBaseColor = obstacle.Color
		obstacle.Color = Color3.new(
			plBaseColor.R * 0.40 + plZoneColor.R * 0.60,
			plBaseColor.G * 0.40 + plZoneColor.G * 0.60,
			plBaseColor.B * 0.40 + plZoneColor.B * 0.60
		)

		-- 통나무 라벨
		local plBb = Instance.new("BillboardGui")
		plBb.Name = "PendulumLabel"
		plBb.Size = UDim2.new(0, 50, 0, 50)
		plBb.StudsOffset = Vector3.new(0, 3, 0)
		plBb.AlwaysOnTop = false
		plBb.Parent = obstacle

		local plLbl = Instance.new("TextLabel")
		plLbl.Size = UDim2.new(1, 0, 1, 0)
		plLbl.BackgroundTransparency = 1
		plLbl.Text = "🪵"
		plLbl.TextScaled = true
		plLbl.Parent = plBb

		obstacle.Parent = workspace

		-- 상하 왕복 트윈 (Sine 무한 반복)
		task.defer(function()
			if not obstacle or not obstacle.Parent then return end
			local halfCycle = GameConstants.PENDULUM_LOG.SWING_CYCLE / 2
			local targetY = if startHigh then yMin else yMax
			local tweenInfo = TweenInfo.new(halfCycle, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			TweenService:Create(obstacle, tweenInfo, {
				Position = Vector3.new(obstacle.Position.X, targetY, obstacle.Position.Z),
			}):Play()
		end)

		local plData: ObstacleData = {
			part = obstacle,
			obstacleType = obstacleType,
			spawnTime = tick(),
		}
		table.insert(self._activeObstacles, plData)
		print(`[ObstacleService] Spawned PendulumLog at {position} (startHigh: {startHigh})`)
		return

	elseif obstacleType == "LaserBeam" then
		-- On/Off 토글 레이저 (Zone 4+, Hard 전용)
		local beamHeight = GameConstants.LASER_BEAM.HEIGHT

		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_LaserBeam"
		obstacle.Size = GameConstants.LASER_BEAM.SIZE
		obstacle.Position = position + Vector3.new(0, beamHeight, 0)
		obstacle.Color = GameConstants.LASER_BEAM.COLOR_ON
		obstacle.Material = Enum.Material.Neon
		obstacle.Transparency = 0.1
		obstacle.Anchored = true
		obstacle.CanCollide = false
		obstacle:SetAttribute("ObstacleType", obstacleType)
		obstacle:SetAttribute("LaserActive", true)

		-- 레이저 이미터 기둥 (좌우, obstacle 자식 → Destroy 시 자동 정리)
		for _, zOff in { -5.5, 5.5 } do
			local emitter = Instance.new("Part")
			emitter.Name = "LaserEmitter"
			emitter.Size = Vector3.new(1, beamHeight * 2, 1)
			emitter.Position = position + Vector3.new(0, beamHeight, zOff)
			emitter.Color = Color3.fromRGB(60, 60, 60)
			emitter.Material = Enum.Material.Metal
			emitter.Anchored = true
			emitter.CanCollide = false
			emitter.Parent = obstacle
		end

		-- 레이저 경고 라벨
		local lbBb = Instance.new("BillboardGui")
		lbBb.Name = "LaserLabel"
		lbBb.Size = UDim2.new(0, 50, 0, 50)
		lbBb.StudsOffset = Vector3.new(0, 2, 0)
		lbBb.AlwaysOnTop = false
		lbBb.Parent = obstacle

		local lbLbl = Instance.new("TextLabel")
		lbLbl.Size = UDim2.new(1, 0, 1, 0)
		lbLbl.BackgroundTransparency = 1
		lbLbl.Text = "⚡"
		lbLbl.TextScaled = true
		lbLbl.Parent = lbBb

		obstacle.Parent = workspace

		-- On/Off 토글 루프 (비동기, pcall로 파괴된 파트 접근 보호)
		task.defer(function()
			local onDur = GameConstants.LASER_BEAM.ON_DURATION
			local offDur = GameConstants.LASER_BEAM.OFF_DURATION
			while obstacle and obstacle.Parent do
				local ok = pcall(function()
					-- ON 상태
					obstacle:SetAttribute("LaserActive", true)
					obstacle.Color = GameConstants.LASER_BEAM.COLOR_ON
					obstacle.Material = Enum.Material.Neon
					obstacle.Transparency = 0.1
				end)
				if not ok then break end
				task.wait(onDur)
				if not obstacle or not obstacle.Parent then break end
				local ok2 = pcall(function()
					-- OFF 상태
					obstacle:SetAttribute("LaserActive", false)
					obstacle.Color = GameConstants.LASER_BEAM.COLOR_OFF
					obstacle.Material = Enum.Material.SmoothPlastic
					obstacle.Transparency = 0.7
				end)
				if not ok2 then break end
				task.wait(offDur)
			end
		end)

		local lbData: ObstacleData = {
			part = obstacle,
			obstacleType = obstacleType,
			spawnTime = tick(),
		}
		table.insert(self._activeObstacles, lbData)
		print(`[ObstacleService] Spawned LaserBeam at {position}`)
		return

	elseif obstacleType == "FallingRock" then
		-- 낙석 (Zone 3+, Normal/Hard — 경고 그림자 후 바위 낙하)
		local rockConst = GameConstants.FALLING_ROCK

		-- 바닥 경고 그림자 (즉시 표시, obstacle 자식 → Destroy 시 자동 정리)
		-- obstacle보다 먼저 생성하여 workspace에 임시 배치 후, obstacle 생성 후 자식으로 이동
		local warning = Instance.new("Part")
		warning.Name = "FallingRock_Warning"
		warning.Size = rockConst.WARNING_SIZE
		warning.Position = position + Vector3.new(0, 0.15, 0)
		warning.Color = rockConst.WARNING_COLOR
		warning.Material = Enum.Material.Neon
		warning.Transparency = 0.3
		warning.Anchored = true
		warning.CanCollide = false

		-- 경고 점멸 이펙트
		task.defer(function()
			if not warning or not warning.Parent then return end
			local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 3, true)
			TweenService:Create(warning, tweenInfo, { Transparency = 0.8 }):Play()
		end)

		-- 바위 (높은 곳에서 대기 → WARNING_TIME 후 낙하)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_FallingRock"
		obstacle.Size = rockConst.SIZE
		obstacle.Position = position + Vector3.new(0, rockConst.DROP_HEIGHT, 0)
		obstacle.Color = rockConst.COLOR
		obstacle.Material = Enum.Material.Slate
		obstacle.Transparency = 0.0
		obstacle.Anchored = true
		obstacle.CanCollide = false
		obstacle:SetAttribute("ObstacleType", obstacleType)
		obstacle:SetAttribute("RockLanded", false)

		-- 구역 색상 틴트
		local frZoneColor = self:_getZoneObstacleColor()
		local frBaseColor = obstacle.Color
		obstacle.Color = Color3.new(
			frBaseColor.R * 0.40 + frZoneColor.R * 0.60,
			frBaseColor.G * 0.40 + frZoneColor.G * 0.60,
			frBaseColor.B * 0.40 + frZoneColor.B * 0.60
		)

		-- 바위 경고 라벨
		local frBb = Instance.new("BillboardGui")
		frBb.Name = "RockLabel"
		frBb.Size = UDim2.new(0, 60, 0, 60)
		frBb.StudsOffset = Vector3.new(0, 3, 0)
		frBb.AlwaysOnTop = false
		frBb.Parent = obstacle

		local frLbl = Instance.new("TextLabel")
		frLbl.Size = UDim2.new(1, 0, 1, 0)
		frLbl.BackgroundTransparency = 1
		frLbl.Text = "🪨"
		frLbl.TextScaled = true
		frLbl.Parent = frBb

		obstacle.Parent = workspace
		-- 경고 그림자를 obstacle 자식으로 배치 (Destroy 시 자동 정리)
		warning.Parent = workspace

		-- 경고 시간 후 낙하 트윈
		task.defer(function()
			task.wait(rockConst.WARNING_TIME)
			if not obstacle or not obstacle.Parent then return end
			local landY = position.Y + rockConst.SIZE.Y / 2
			local tweenInfo = TweenInfo.new(rockConst.DROP_SPEED, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
			local tween = TweenService:Create(obstacle, tweenInfo, {
				Position = Vector3.new(obstacle.Position.X, landY, obstacle.Position.Z),
			})
			tween.Completed:Connect(function()
				if obstacle and obstacle.Parent then
					obstacle:SetAttribute("RockLanded", true)
				end
				-- 경고 제거
				if warning and warning.Parent then
					warning:Destroy()
				end
			end)
			tween:Play()
		end)

		local frData: ObstacleData = {
			part = obstacle,
			obstacleType = obstacleType,
			spawnTime = tick(),
			warningPart = warning, -- 경고 그림자 참조 (cleanup 시 함께 정리)
		}
		table.insert(self._activeObstacles, frData)
		print(`[ObstacleService] Spawned FallingRock at {position}`)
		return

	elseif obstacleType == "RotatingBar" then
		-- 회전 장애물 (Hard 전용, 타이밍 점프/슬라이드 — IDEA-004)
		local barConst = GameConstants.ROTATING_BAR
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_RotatingBar"
		obstacle.Size = barConst.SIZE
		obstacle.CFrame = CFrame.new(position.X, position.Y + barConst.PIVOT_Y, position.Z)
		obstacle.Color = barConst.COLOR
		obstacle.Material = Enum.Material.Neon
		obstacle.Transparency = 0.1
		obstacle.Anchored = true
		obstacle.CanCollide = false
		obstacle:SetAttribute("ObstacleType", obstacleType)

		-- 경고 BillboardGui
		local rbBb = Instance.new("BillboardGui")
		rbBb.Name = "RotatingBarLabel"
		rbBb.Size = UDim2.new(0, 50, 0, 50)
		rbBb.StudsOffset = Vector3.new(0, barConst.PIVOT_Y + 2, 0)
		rbBb.AlwaysOnTop = false
		rbBb.Parent = obstacle
		local rbLbl = Instance.new("TextLabel")
		rbLbl.Size = UDim2.new(1, 0, 1, 0)
		rbLbl.BackgroundTransparency = 1
		rbLbl.Text = "🔄"
		rbLbl.TextScaled = true
		rbLbl.Parent = rbBb

		-- ISSUE-032: 깜빡이는 경고등 (이동 장애물 위협 강화)
		local rbLight = Instance.new("PointLight")
		rbLight.Name = "WarningLight"
		rbLight.Color = GameConstants.OBSTACLE_WARNING.MOVING_LIGHT_COLOR
		rbLight.Brightness = GameConstants.OBSTACLE_WARNING.MOVING_LIGHT_BRIGHTNESS
		rbLight.Range = GameConstants.OBSTACLE_WARNING.MOVING_LIGHT_RANGE
		rbLight.Shadows = false
		rbLight.Parent = obstacle
		task.defer(function()
			local halfBlink = GameConstants.OBSTACLE_WARNING.MOVING_BLINK_CYCLE / 2
			local blinkInfo = TweenInfo.new(halfBlink, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
			TweenService:Create(rbLight, blinkInfo, { Brightness = 0.2 }):Play()
		end)

		obstacle.Parent = workspace

		-- X축 기준 회전 트윈 (수평 ↔ 수직, 1.5s 사이클, 네트워크 복제)
		task.defer(function()
			if not obstacle or not obstacle.Parent then return end
			local halfCycle = barConst.CYCLE_TIME / 2
			local tweenInfo = TweenInfo.new(halfCycle, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			local pivot = obstacle.CFrame
			TweenService:Create(obstacle, tweenInfo, {
				CFrame = pivot * CFrame.Angles(math.pi / 2, 0, 0),
			}):Play()
		end)

		local rbData: ObstacleData = {
			part = obstacle,
			obstacleType = obstacleType,
			spawnTime = tick(),
		}
		table.insert(self._activeObstacles, rbData)
		print(`[ObstacleService] Spawned RotatingBar at {position}`)
		return

	elseif obstacleType == "FallingDebris" then
		-- 낙하 잔해 (Hard 전용, 3연속 파편 낙하 — IDEA-004)
		local dbConst = GameConstants.FALLING_DEBRIS
		local spawnTimeDb = tick()

		for i = 1, dbConst.COUNT do
			local xOffset = (i - (dbConst.COUNT + 1) / 2) * dbConst.SPACING
			local debrisPos = Vector3.new(position.X + xOffset, position.Y, position.Z)
			local debrisDropPos = Vector3.new(position.X + xOffset, position.Y + dbConst.DROP_HEIGHT, position.Z)

			-- 경고 그림자
			local warning = Instance.new("Part")
			warning.Name = "FallingDebris_Warning"
			warning.Size = Vector3.new(dbConst.PIECE_SIZE.X + 1, 0.2, dbConst.PIECE_SIZE.Z)
			warning.Position = debrisPos + Vector3.new(0, 0.15, 0)
			warning.Color = dbConst.WARNING_COLOR
			warning.Material = Enum.Material.Neon
			warning.Transparency = 0.4
			warning.Anchored = true
			warning.CanCollide = false
			warning.Parent = workspace

			-- ISSUE-032: 깜빡이는 경고등
			local dbLight = Instance.new("PointLight")
			dbLight.Name = "WarningLight"
			dbLight.Color = GameConstants.OBSTACLE_WARNING.MOVING_LIGHT_COLOR
			dbLight.Brightness = GameConstants.OBSTACLE_WARNING.MOVING_LIGHT_BRIGHTNESS
			dbLight.Range = GameConstants.OBSTACLE_WARNING.MOVING_LIGHT_RANGE
			dbLight.Shadows = false
			dbLight.Parent = warning
			task.defer(function()
				if not warning or not warning.Parent then return end
				local halfBlink = GameConstants.OBSTACLE_WARNING.MOVING_BLINK_CYCLE / 2
				local blinkInfo = TweenInfo.new(halfBlink, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
				TweenService:Create(dbLight, blinkInfo, { Brightness = 0.2 }):Play()
			end)

			-- 파편
			local piece = Instance.new("Part")
			piece.Name = "Obstacle_FallingDebris"
			piece.Size = dbConst.PIECE_SIZE
			piece.Position = debrisDropPos
			piece.Color = dbConst.COLOR
			piece.Material = Enum.Material.Slate
			piece.Transparency = 0
			piece.Anchored = true
			piece.CanCollide = false
			piece:SetAttribute("ObstacleType", "FallingDebris")
			piece:SetAttribute("DebrisLanded", false)
			piece.Parent = workspace

			local pieceData: ObstacleData = {
				part = piece,
				obstacleType = "FallingDebris",
				spawnTime = spawnTimeDb,
				warningPart = warning,
			}
			table.insert(self._activeObstacles, pieceData)

			-- 딜레이 후 낙하 (스태거 효과)
			local fallDelay = (i - 1) * dbConst.STAGGER_TIME
			task.delay(dbConst.WARNING_TIME + fallDelay, function()
				if not piece or not piece.Parent then
					if warning and warning.Parent then warning:Destroy() end
					return
				end
				local landY = debrisPos.Y + dbConst.PIECE_SIZE.Y / 2
				local tweenInfo = TweenInfo.new(dbConst.DROP_SPEED, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
				local tween = TweenService:Create(piece, tweenInfo, {
					Position = Vector3.new(piece.Position.X, landY, piece.Position.Z),
				})
				tween.Completed:Connect(function()
					if piece and piece.Parent then piece:SetAttribute("DebrisLanded", true) end
					if warning and warning.Parent then warning:Destroy() end
				end)
				tween:Play()
			end)
		end

		print(`[ObstacleService] Spawned FallingDebris x{dbConst.COUNT} at {position}`)
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

	-- ISSUE-032: 경고 Decal — 장애물 양 측면(Front/Back)에 빨강/주황 경고 표시
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local decal = Instance.new("Decal")
		decal.Name = "WarningDecal_" .. face.Name
		decal.Face = face
		decal.Color3 = GameConstants.OBSTACLE_WARNING.OUTLINE_COLOR
		decal.Transparency = GameConstants.OBSTACLE_WARNING.OUTLINE_TRANSPARENCY
		-- 빈 텍스처: 색상만으로 경고 표시 (Roblox 기본 placeholder는 흰색)
		decal.Texture = "rbxasset://textures/whiteBkgd.png"
		decal.Parent = obstacle
	end

	obstacle.Parent = workspace

	-- 장애물 데이터 저장
	local obstacleData: ObstacleData = {
		part = obstacle,
		obstacleType = obstacleType,
		spawnTime = tick(),
	}
	table.insert(self._activeObstacles, obstacleData)
end

-- 버섯 패드 밟기 판정 (GameManager Heartbeat에서 호출)
-- 반환: true이면 이번 프레임에 밟힘 (GameManager가 RemoteEvent 전송)
function ObstacleService:CheckMushroomPad(playerPosition: Vector3): boolean
	local now = tick()
	local DETECT = GameConstants.MUSHROOM_PAD.DETECT_RADIUS
	local COOLDOWN = GameConstants.MUSHROOM_PAD.COOLDOWN

	for _, padData in self._activeMushroomPads do
		if not padData.part or not padData.part.Parent then
			continue
		end
		-- 쿨다운 체크
		if now - padData.lastBounceTime < COOLDOWN then
			continue
		end
		local padPos = padData.part.Position
		local dx = math.abs(playerPosition.X - padPos.X)
		local dy = playerPosition.Y - padPos.Y -- 플레이어가 패드 위에 있어야 함
		if dx < DETECT and dy > 0 and dy < DETECT then
			padData.lastBounceTime = now
			return true
		end
	end
	return false
end

-- GravityZone 마커 판정 (GameManager Heartbeat에서 호출)
-- 반환: "enter" | "exit" | nil
function ObstacleService:CheckGravityZone(playerPosition: Vector3): string?
	local inZone = false
	local HALF = GameConstants.GRAVITY_ZONE.MARKER_SIZE.X / 2

	for _, obstacleData in self._activeObstacles do
		if obstacleData.obstacleType ~= "GravityZone" then
			continue
		end
		if not obstacleData.part or not obstacleData.part.Parent then
			continue
		end
		local markerPos = obstacleData.part.Position
		if math.abs(playerPosition.X - markerPos.X) < HALF then
			inZone = true
			break
		end
	end

	if inZone and not self._gravityZoneActive then
		self._gravityZoneActive = true
		return "enter"
	elseif not inZone and self._gravityZoneActive then
		self._gravityZoneActive = false
		return "exit"
	end
	return nil
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
			elseif obstacleType == "PendulumLog" then
				-- PendulumLog: 통나무가 높이 올라간 틈에 통과
				local logBottom = obstaclePart.Position.Y - obstaclePart.Size.Y / 2
				local logTop = obstaclePart.Position.Y + obstaclePart.Size.Y / 2
				if playerPosition.Y > logTop then
					-- 통나무 위로 점프
					print(`[ObstacleService] {self._player.Name} jumped over PendulumLog!`)
					continue
				elseif logBottom > GameConstants.PENDULUM_LOG.CLEAR_Y then
					-- 통나무가 높이 올라가 있으면 아래로 통과
					print(`[ObstacleService] {self._player.Name} passed under PendulumLog! (logBottom: {logBottom})`)
					continue
				else
					self._collidedObstacles[obstaclePart] = true
					return true
				end
			elseif obstacleType == "LaserBeam" then
				-- LaserBeam: Off일 때 통과 가능, On일 때 점프로 회피
				local isActive = obstaclePart:GetAttribute("LaserActive")
				if not isActive then
					-- 레이저 Off — 자유 통과
					print(`[ObstacleService] {self._player.Name} passed through LaserBeam (OFF)!`)
					continue
				elseif playerPosition.Y > GameConstants.LASER_BEAM.HEIGHT + 1 then
					-- 레이저 위로 점프
					print(`[ObstacleService] {self._player.Name} jumped over LaserBeam!`)
					continue
				elseif isSliding and playerPosition.Y < GameConstants.LASER_BEAM.HEIGHT - 1 then
					-- 슬라이드로 레이저 아래 통과
					print(`[ObstacleService] {self._player.Name} slid under LaserBeam!`)
					continue
				else
					self._collidedObstacles[obstaclePart] = true
					return true
				end
			elseif obstacleType == "FallingRock" then
				-- FallingRock: 착지 전이면 안전, 착지 후 위치에 있으면 충돌
				local hasLanded = obstaclePart:GetAttribute("RockLanded")
				if not hasLanded then
					-- 아직 낙하 중 (상공에 있음) — 충돌 안 함
					continue
				end
				-- 착지 후: 바위 위로 점프하면 회피
				local rockTop = obstaclePart.Position.Y + obstaclePart.Size.Y / 2
				if playerPosition.Y > rockTop then
					print(`[ObstacleService] {self._player.Name} jumped over FallingRock!`)
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
		elseif obstacleType == "PendulumLog" then
			-- PendulumLog: 통나무 아래를 아슬아슬하게 통과
			local logBottom = obstaclePart.Position.Y - obstaclePart.Size.Y / 2
			if logBottom > GameConstants.PENDULUM_LOG.CLEAR_Y
				and logBottom < GameConstants.PENDULUM_LOG.CLEAR_Y + NEAR_MISS_Y_MARGIN then
				isNearMiss = true
			end
		elseif obstacleType == "LaserBeam" then
			-- LaserBeam: On 상태에서 점프로 아슬아슬하게 넘을 때
			local isActive = obstaclePart:GetAttribute("LaserActive")
			if isActive then
				local beamY = GameConstants.LASER_BEAM.HEIGHT + 1
				if playerPosition.Y > beamY and playerPosition.Y < beamY + NEAR_MISS_Y_MARGIN then
					isNearMiss = true
				end
			end
		elseif obstacleType == "FallingRock" then
			-- FallingRock: 착지 직후 바위 바로 위를 스치며 통과
			local hasLanded = obstaclePart:GetAttribute("RockLanded")
			if hasLanded then
				local rockTop = obstaclePart.Position.Y + obstaclePart.Size.Y / 2
				if playerPosition.Y > rockTop and playerPosition.Y < rockTop + NEAR_MISS_Y_MARGIN then
					isNearMiss = true
				end
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
			-- FallingRock 경고 그림자 함께 정리
			if obstacleData.warningPart and obstacleData.warningPart.Parent then
				obstacleData.warningPart:Destroy()
			end
			obstacleData.part:Destroy()
			table.remove(self._activeObstacles, i)
		end
	end

	-- MushroomPad도 청크 범위 내 정리
	for i = #self._activeMushroomPads, 1, -1 do
		local padData = self._activeMushroomPads[i]
		local padPos = padData.part.Position
		local isInChunk = math.abs(padPos.X - chunkPosition.X) < chunkSize.X / 2
		if isInChunk then
			padData.part:Destroy()
			table.remove(self._activeMushroomPads, i)
		end
	end
end

-- 모든 장애물 정리 (게임 종료 시)
function ObstacleService:Destroy()
	for _, obstacleData in self._activeObstacles do
		-- FallingRock 경고 그림자 함께 정리
		if obstacleData.warningPart and obstacleData.warningPart.Parent then
			obstacleData.warningPart:Destroy()
		end
		if obstacleData.part then
			obstacleData.part:Destroy()
		end
	end
	self._activeObstacles = {}
	self._collidedObstacles = {}

	-- MushroomPad 정리
	for _, padData in self._activeMushroomPads do
		if padData.part then
			padData.part:Destroy()
		end
	end
	self._activeMushroomPads = {}
	self._gravityZoneActive = false

	-- Chase Mob 정리
	for _, mobData in self._activeChaseMobs do
		if mobData.part then
			mobData.part:Destroy()
		end
	end
	self._activeChaseMobs = {}
end

return ObstacleService

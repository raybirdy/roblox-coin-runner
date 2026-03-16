--!strict
-- Coin Service
-- 코인 생성 및 수집 처리

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local CoinService = {}
CoinService.__index = CoinService

type CoinData = {
	part: BasePart,
	value: number,
	type: string,
	spawnTime: number,
}

export type CoinService = typeof(setmetatable(
	{} :: {
		_activeCoins: { CoinData },
		_connections: { RBXScriptConnection },
		_player: Player,
		_spawnCount: number, -- 코인 밀도 리듬: Normal/Hard 청크 카운터
		_luckyCoinsBonus: number, -- lucky_coins 업그레이드 보너스 (Silver 확률 증가)
	},
	CoinService
))

function CoinService.new(player: Player): CoinService
	local self = setmetatable({
		_activeCoins = {},
		_connections = {},
		_player = player,
		_spawnCount = 0,
		_luckyCoinsBonus = 0,
	}, CoinService)

	self:_setupCollisionHandlers()

	return self
end

-- =====================================================================
-- 패턴 생성 함수 (청크 중심 기준 상대 XY 오프셋 반환)
-- 반환: { {x: number, y: number} }
-- x: 청크 중심으로부터 좌우 오프셋 (studs)
-- y: 바닥으로부터 높이 (studs, COIN_MIN_Y 기준으로 더해짐)
-- =====================================================================

-- LINE: 일정 높이의 수평선 (달리기 경로 그대로)
local function patternLine(count: number, halfWidth: number): { { x: number, y: number } }
	local positions = {}
	local spacing = (halfWidth * 1.6) / math.max(count - 1, 1)
	local startX = -halfWidth * 0.8
	local runHeight = 2.5 -- 달리기 높이 (바닥 + 2.5)
	for i = 0, count - 1 do
		table.insert(positions, { x = startX + i * spacing, y = runHeight })
	end
	return positions
end

-- ARC: 아치형 (quadratic bezier, 점프를 유도하는 곡선)
local function patternArc(count: number, halfWidth: number): { { x: number, y: number } }
	local positions = {}
	local arcWidth = halfWidth * 1.6
	local arcHeight = 7 -- 아치 최고점
	local baseHeight = 2.5
	for i = 0, count - 1 do
		local t = i / math.max(count - 1, 1) -- 0~1
		local x = -halfWidth * 0.8 + t * arcWidth
		-- quadratic bezier: P = (1-t)^2*P0 + 2t(1-t)*P1 + t^2*P2
		-- P0.y=baseHeight, P1.y=arcHeight, P2.y=baseHeight
		local y = (1 - t) ^ 2 * baseHeight + 2 * t * (1 - t) * arcHeight + t ^ 2 * baseHeight
		table.insert(positions, { x = x, y = y })
	end
	return positions
end

-- ZIGZAG: 낮→높 교대 반복 (리듬감 있는 수집)
local function patternZigzag(count: number, halfWidth: number): { { x: number, y: number } }
	local positions = {}
	local spacing = (halfWidth * 1.6) / math.max(count - 1, 1)
	local startX = -halfWidth * 0.8
	local lowY = 2.0
	local highY = 6.0
	for i = 0, count - 1 do
		local x = startX + i * spacing
		local y = if i % 2 == 0 then lowY else highY
		table.insert(positions, { x = x, y = y })
	end
	return positions
end

-- STEP_UP: 계단식 상승 (장애물 전 점프 유도)
local function patternStepUp(count: number, halfWidth: number): { { x: number, y: number } }
	local positions = {}
	local spacing = (halfWidth * 1.6) / math.max(count - 1, 1)
	local startX = -halfWidth * 0.8
	local minY = 2.0
	local maxY = 8.0
	for i = 0, count - 1 do
		local t = i / math.max(count - 1, 1)
		local x = startX + i * spacing
		local y = minY + t * (maxY - minY)
		table.insert(positions, { x = x, y = y })
	end
	return positions
end

-- STEP_DOWN: 계단식 하강 (장애물 후 착지 안내)
local function patternStepDown(count: number, halfWidth: number): { { x: number, y: number } }
	local positions = {}
	local spacing = (halfWidth * 1.6) / math.max(count - 1, 1)
	local startX = -halfWidth * 0.8
	local minY = 2.0
	local maxY = 8.0
	for i = 0, count - 1 do
		local t = i / math.max(count - 1, 1)
		local x = startX + i * spacing
		local y = maxY - t * (maxY - minY)
		table.insert(positions, { x = x, y = y })
	end
	return positions
end

-- SPREAD: 넓게 퍼진 배치 (Easy 전용, 초보자 친화적)
-- Y를 고정 지상 높이(2.0)로 유지해 도로 레인과 일정하게 맞춤
local function patternSpread(count: number, halfWidth: number): { { x: number, y: number } }
	local positions = {}
	local rng = Random.new()
	local usedX: { number } = {}
	local MIN_SPACING = 5
	local GROUND_Y = 2.0 -- 도로 표면 기준 일정 높이

	for _ = 1, count do
		local x = 0
		local valid = false
		for _attempt = 1, 8 do
			x = rng:NextNumber(-halfWidth * 0.85, halfWidth * 0.85)

			valid = true
			for _, ux in usedX do
				if math.abs(x - ux) < MIN_SPACING then
					valid = false
					break
				end
			end
			if valid then
				break
			end
		end
		table.insert(usedX, x)
		table.insert(positions, { x = x, y = GROUND_Y })
	end
	return positions
end

-- CORRIDOR: 장애물 사이 통로 배치 (Hard 전용, 동선 유도)
local function patternCorridor(
	count: number,
	halfWidth: number,
	obstacleXList: { number }
): { { x: number, y: number } }
	local positions = {}
	local SAFE = 7 -- 장애물 X로부터 안전 거리

	-- 장애물이 없으면 zigzag로 대체
	if #obstacleXList == 0 then
		return patternZigzag(count, halfWidth)
	end

	-- 통과 가능한 X 구간 계산 (장애물 사이 슬롯)
	local safeSlots: { { xMin: number, xMax: number } } = {}
	local sortedObs = table.clone(obstacleXList)
	table.sort(sortedObs)

	-- 청크 왼쪽 끝 ~ 첫 장애물
	if sortedObs[1] - (-halfWidth) > SAFE * 2 then
		table.insert(safeSlots, { xMin = -halfWidth * 0.9, xMax = sortedObs[1] - SAFE })
	end
	-- 장애물 사이
	for i = 1, #sortedObs - 1 do
		local gap = sortedObs[i + 1] - sortedObs[i]
		if gap > SAFE * 2 then
			table.insert(safeSlots, { xMin = sortedObs[i] + SAFE, xMax = sortedObs[i + 1] - SAFE })
		end
	end
	-- 마지막 장애물 ~ 청크 오른쪽 끝
	if halfWidth - sortedObs[#sortedObs] > SAFE * 2 then
		table.insert(safeSlots, { xMin = sortedObs[#sortedObs] + SAFE, xMax = halfWidth * 0.9 })
	end

	-- 슬롯이 없으면 zigzag 대체
	if #safeSlots == 0 then
		return patternZigzag(count, halfWidth)
	end

	-- 각 슬롯에 균등하게 코인 배분
	local perSlot = math.max(1, math.floor(count / #safeSlots))
	for _, slot in safeSlots do
		local slotW = slot.xMax - slot.xMin
		local n = math.min(perSlot, count - #positions)
		if n <= 0 then
			break
		end
		local spacing = slotW / math.max(n, 1)
		for i = 0, n - 1 do
			local x = slot.xMin + i * spacing + spacing * 0.5
			-- Y를 고정 지상 높이로 유지 (랜덤 제거 → 도로 레인과 일정하게)
			table.insert(positions, { x = x, y = 2.5 })
		end
	end

	return positions
end

-- =====================================================================
-- ActionHint 패턴 (장애물 타입 → 올바른 액션을 코인으로 안내)
-- obsRelX: 청크 중심 기준 장애물 상대 X (코인 배치 기준점으로 사용)
-- =====================================================================

-- JUMP_ARC: LowWall/SpikeTrap/Gap 직전 포물선 아치 → 점프 유도
-- 장애물 앞 ~10studs에서 아치가 시작해 장애물 위를 넘어가도록 배치
local function patternActionJumpArc(count: number, halfWidth: number, obsRelX: number): { { x: number, y: number } }
	local positions = {}
	local arcSpan = halfWidth * 1.0 -- 아치 전체 폭
	local startX = obsRelX - arcSpan * 0.65 -- 장애물 앞 65%에서 시작
	local arcHeight = 8.0
	local baseHeight = 2.5
	for i = 0, count - 1 do
		local t = i / math.max(count - 1, 1)
		local x = startX + t * arcSpan
		-- quadratic bezier peak at t=0.5
		local y = (1 - t) ^ 2 * baseHeight + 2 * t * (1 - t) * arcHeight + t ^ 2 * baseHeight
		x = math.clamp(x, -halfWidth * 0.9, halfWidth * 0.9)
		table.insert(positions, { x = x, y = y })
	end
	return positions
end

-- SLIDE_DOWN: Tunnel 직전 하강선 → 슬라이드 유도
-- 장애물 앞에서 점점 낮아져 지상에 붙는 코인 경로
local function patternActionSlideDown(count: number, halfWidth: number, obsRelX: number): { { x: number, y: number } }
	local positions = {}
	local slideSpan = halfWidth * 0.9
	local startX = obsRelX - slideSpan * 0.8
	local highY = 5.5
	local lowY = 1.5 -- 지면 바짝, 슬라이드 자세 유도
	for i = 0, count - 1 do
		local t = i / math.max(count - 1, 1)
		local x = startX + t * slideSpan
		local y = highY - t * (highY - lowY)
		x = math.clamp(x, -halfWidth * 0.9, halfWidth * 0.9)
		table.insert(positions, { x = x, y = y })
	end
	return positions
end

-- DOUBLE_ARC: DoubleWall 직전 두 개의 연속 아치 → 연속 점프 유도
local function patternActionDoubleArc(count: number, halfWidth: number, obsRelX: number): { { x: number, y: number } }
	local positions = {}
	local half = math.ceil(count / 2)
	local arcSpan = halfWidth * 0.65
	local arcHeight = 7.5
	local baseHeight = 2.5
	-- 첫 번째 아치 (장애물 앞)
	local start1 = obsRelX - arcSpan * 1.2
	for i = 0, half - 1 do
		local t = i / math.max(half - 1, 1)
		local x = start1 + t * arcSpan
		local y = (1 - t) ^ 2 * baseHeight + 2 * t * (1 - t) * arcHeight + t ^ 2 * baseHeight
		x = math.clamp(x, -halfWidth * 0.9, halfWidth * 0.9)
		table.insert(positions, { x = x, y = y })
	end
	-- 두 번째 아치 (장애물 직후)
	local start2 = obsRelX + arcSpan * 0.1
	local remaining = count - half
	for i = 0, remaining - 1 do
		local t = i / math.max(remaining - 1, 1)
		local x = start2 + t * arcSpan
		local y = (1 - t) ^ 2 * baseHeight + 2 * t * (1 - t) * arcHeight + t ^ 2 * baseHeight
		x = math.clamp(x, -halfWidth * 0.9, halfWidth * 0.9)
		table.insert(positions, { x = x, y = y })
	end
	return positions
end

-- AVOID_SIDE: ExplodingBarrel 폭발 후 안전 구간 코인 → 측면 회피 안내
-- 장애물 뒤쪽에 넉넉한 지상 코인 (폭발 반경 벗어난 위치)
local function patternActionAvoidSide(count: number, halfWidth: number, obsRelX: number): { { x: number, y: number } }
	local positions = {}
	local safeOffset = 10 -- 폭발 반경 넘어선 위치
	local span = halfWidth * 0.9
	local startX = obsRelX + safeOffset
	local groundY = 2.5
	for i = 0, count - 1 do
		local t = i / math.max(count - 1, 1)
		local x = startX + t * span * 0.5
		x = math.clamp(x, -halfWidth * 0.9, halfWidth * 0.9)
		table.insert(positions, { x = x, y = groundY })
	end
	return positions
end

-- TIMING_CLUSTER: MovingWall 주변 타이밍 코인 → 안전 창문 통과 유도
-- 벽 이동 주기(2s) 기준으로 안전 구간 앞뒤에 코인 군집
local function patternActionTimingCluster(
	count: number,
	halfWidth: number,
	obsRelX: number
): { { x: number, y: number } }
	local positions = {}
	local clusterA = count -- 장애물 직전 클러스터
	local beforeX = obsRelX - 8
	local spacing = 3.5
	local groundY = 2.5
	local highY = 9.0 -- 벽 위 코인 (높이 점프 유도)
	local n = math.ceil(clusterA / 2)
	for i = 0, n - 1 do
		local x = beforeX - i * spacing
		x = math.clamp(x, -halfWidth * 0.9, halfWidth * 0.9)
		table.insert(positions, { x = x, y = groundY })
	end
	for i = 0, n - 1 do
		local x = beforeX - i * spacing
		x = math.clamp(x, -halfWidth * 0.9, halfWidth * 0.9)
		table.insert(positions, { x = x, y = highY })
		if #positions >= count then
			break
		end
	end
	return positions
end

-- WAVE: 사인파 코인 경로 (Normal 리듬감, 점프+달리기 반복)
local function patternWave(count: number, halfWidth: number): { { x: number, y: number } }
	local positions = {}
	local span = halfWidth * 1.6
	local startX = -halfWidth * 0.8
	local midY = 4.5
	local amplitude = 3.5 -- 중앙에서 위아래 진폭
	local cycles = 1.5 -- 전체 사인 파형 수
	for i = 0, count - 1 do
		local t = i / math.max(count - 1, 1)
		local x = startX + t * span
		local y = midY + amplitude * math.sin(t * cycles * 2 * math.pi)
		table.insert(positions, { x = x, y = y })
	end
	return positions
end

-- SWOOP: 급하강 후 급상승 (V자형, 타이밍 수집 챌린지)
local function patternSwoop(count: number, halfWidth: number): { { x: number, y: number } }
	local positions = {}
	local span = halfWidth * 1.6
	local startX = -halfWidth * 0.8
	local highY = 8.0
	local lowY = 1.5
	for i = 0, count - 1 do
		local t = i / math.max(count - 1, 1)
		local x = startX + t * span
		-- V 곡선: 0에서 내려가다 0.5에서 최저, 다시 올라감
		local v = math.abs(t - 0.5) * 2 -- 0→1 (0.5에서 0, 양 끝에서 1)
		local y = lowY + v * (highY - lowY)
		table.insert(positions, { x = x, y = y })
	end
	return positions
end

-- DOUBLE_LINE: 두 줄 수평선 (Bonus 전용, 대량 수집)
local function patternDoubleLine(count: number, halfWidth: number): { { x: number, y: number } }
	local positions = {}
	local half = math.ceil(count / 2)
	local spacing = (halfWidth * 1.6) / math.max(half - 1, 1)
	local startX = -halfWidth * 0.8
	local lowY = 2.5
	local highY = 6.0
	for i = 0, half - 1 do
		local x = startX + i * spacing
		table.insert(positions, { x = x, y = lowY })
		if #positions < count then
			table.insert(positions, { x = x, y = highY })
		end
	end
	return positions
end

-- lucky_coins 업그레이드 보너스 설정 (GameManager에서 호출)
function CoinService:SetLuckyCoinsBonus(bonus: number)
	self._luckyCoinsBonus = bonus
end

-- =====================================================================
-- 패턴 선택 (난이도 + 장애물 타입 반영)
-- obstacleInfos: { { position: Vector3, obstacleType: string } }
-- =====================================================================

-- ActionHint 장애물 타입 → 패턴 이름 매핑
local ACTION_HINT_MAP: { [string]: string } = {
	LowWall = "action_jump_arc",
	SpikeTrap = "action_jump_arc",
	Gap = "action_jump_arc",
	Tunnel = "action_slide_down",
	DoubleWall = "action_double_arc",
	ExplodingBarrel = "action_avoid_side",
	MovingWall = "action_timing_cluster",
}

function CoinService:_selectPattern(difficulty: string, obstaclePositions: { Vector3 }, obstacleInfos: { any }?): string
	-- ActionHint: 장애물 타입이 있으면 70% 확률로 ActionHint 패턴 사용
	if obstacleInfos and #obstacleInfos > 0 then
		local firstInfo = obstacleInfos[1]
		local hintPattern = ACTION_HINT_MAP[firstInfo.obstacleType]
		if hintPattern and math.random() < 0.70 then
			return hintPattern
		end
	end

	local patterns = GameConstants.COIN_PATTERNS[difficulty:upper()] or GameConstants.COIN_PATTERNS.NORMAL

	-- Hard에서 장애물이 있으면 corridor 우선
	if difficulty == "Hard" and #obstaclePositions > 0 then
		if math.random() < 0.6 then
			return "corridor"
		end
	end

	-- Normal에서 장애물이 있으면 step 계열 우선
	if difficulty == "Normal" and #obstaclePositions > 0 then
		if math.random() < 0.4 then
			return if math.random() < 0.5 then "step_up" else "step_down"
		end
	end

	return patterns[math.random(1, #patterns)]
end

-- =====================================================================
-- 패턴별 위치 생성 (청크 절대 좌표로 변환)
-- obstacleInfos: { { position: Vector3, obstacleType: string } } (선택)
-- =====================================================================
function CoinService:_generatePatternPositions(
	chunkCFrame: CFrame,
	pattern: string,
	coinCount: number,
	obstaclePositions: { Vector3 }
): { Vector3 }
	-- GetExtentsSize는 장식 파트에 따라 청크마다 달라지므로
	-- 고정된 CHUNK.LENGTH로 halfWidth를 계산해 X 배치를 일정하게 유지한다.
	local halfWidth = GameConstants.CHUNK.LENGTH * 0.45
	local chunkCenter = chunkCFrame.Position

	-- 장애물 X 좌표 리스트 (청크 중심 기준 상대값)
	local obstacleXList: { number } = {}
	for _, obsPos in obstaclePositions do
		table.insert(obstacleXList, obsPos.X - chunkCenter.X)
	end

	-- ActionHint 패턴: 첫 번째 장애물 상대 X 기준으로 코인 배치
	local firstObsRelX = if #obstacleXList > 0 then obstacleXList[1] else 0

	-- 패턴별 상대 오프셋 생성
	local offsets: { { x: number, y: number } }
	if pattern == "line" then
		offsets = patternLine(coinCount, halfWidth)
	elseif pattern == "arc" then
		offsets = patternArc(coinCount, halfWidth)
	elseif pattern == "zigzag" then
		offsets = patternZigzag(coinCount, halfWidth)
	elseif pattern == "step_up" then
		offsets = patternStepUp(coinCount, halfWidth)
	elseif pattern == "step_down" then
		offsets = patternStepDown(coinCount, halfWidth)
	elseif pattern == "spread" then
		offsets = patternSpread(coinCount, halfWidth)
	elseif pattern == "corridor" then
		offsets = patternCorridor(coinCount, halfWidth, obstacleXList)
	elseif pattern == "wave" then
		offsets = patternWave(coinCount, halfWidth)
	elseif pattern == "swoop" then
		offsets = patternSwoop(coinCount, halfWidth)
	elseif pattern == "action_jump_arc" then
		offsets = patternActionJumpArc(coinCount, halfWidth, firstObsRelX)
	elseif pattern == "action_slide_down" then
		offsets = patternActionSlideDown(coinCount, halfWidth, firstObsRelX)
	elseif pattern == "action_double_arc" then
		offsets = patternActionDoubleArc(coinCount, halfWidth, firstObsRelX)
	elseif pattern == "action_avoid_side" then
		offsets = patternActionAvoidSide(coinCount, halfWidth, firstObsRelX)
	elseif pattern == "action_timing_cluster" then
		offsets = patternActionTimingCluster(coinCount, halfWidth, firstObsRelX)
	else
		offsets = patternDoubleLine(coinCount, halfWidth)
	end

	-- 절대 좌표로 변환
	local result: { Vector3 } = {}
	for _, offset in offsets do
		local worldPos = Vector3.new(chunkCenter.X + offset.x, chunkCenter.Y + offset.y, chunkCenter.Z)
		table.insert(result, worldPos)
	end
	return result
end

-- =====================================================================
-- 청크 내 코인 생성 (패턴 기반)
-- obstacleInfos: { { position: Vector3, obstacleType: string } } (선택)
-- =====================================================================
function CoinService:SpawnCoinsInChunk(
	chunk: Model,
	difficulty: string,
	obstaclePositions: { Vector3 }?,
	obstacleInfos: { any }?
)
	obstaclePositions = obstaclePositions or {}
	obstacleInfos = obstacleInfos or {}

	-- 코인 개수 결정
	local coinCount = self:_getCoinCountForDifficulty(difficulty)

	-- 청크 중심 좌표 계산
	local chunkCFrame = chunk:GetPrimaryPartCFrame()

	-- 패턴 선택 (장애물 타입 기반 ActionHint 패턴 포함)
	local pattern =
		self:_selectPattern(difficulty, obstaclePositions :: { Vector3 }, obstacleInfos :: { any })

	-- 패턴 위치 생성
	local positions =
		self:_generatePatternPositions(chunkCFrame, pattern, coinCount, obstaclePositions :: { Vector3 })

	-- ActionHint 패턴은 안전 거리 검증 완화 (코인이 장애물 앞에 의도적으로 배치)
	local isActionHint = pattern:sub(1, 7) == "action_"
	local SAFE_DISTANCE = if isActionHint then 3 else 5

	for _, coinPosition in positions do
		local overlaps = false
		for _, obsPos in obstaclePositions :: { Vector3 } do
			if math.abs(coinPosition.X - obsPos.X) < SAFE_DISTANCE then
				overlaps = true
				break
			end
		end
		if not overlaps then
			local coinType = self:_selectCoinType(difficulty)
			self:_spawnCoin(coinPosition, coinType)
		end
	end

	-- Leading Coins: 일반 패턴일 때 장애물 앞 8~12 studs에 예고 코인 2~3개 생성
	-- ActionHint 패턴은 이미 유도 코인을 포함하므로 중복 생성 안 함
	if not isActionHint and #(obstaclePositions :: { Vector3 }) > 0 then
		local chunkCFrame2 = chunk:GetPrimaryPartCFrame()
		local LEAD_OFFSET = 10 -- 장애물 앞 10 studs
		local LEAD_SPACING = 3.5
		local LEAD_COUNT = 2
		local LEAD_Y = 5.5 -- 눈에 잘 띄는 중간 높이

		for _, obsPos in obstaclePositions :: { Vector3 } do
			for i = 1, LEAD_COUNT do
				local lx = obsPos.X - LEAD_OFFSET - (i - 1) * LEAD_SPACING
				local ly = chunkCFrame2.Position.Y + LEAD_Y
				local lz = chunkCFrame2.Position.Z
				self:_spawnCoin(Vector3.new(lx, ly, lz), "Bronze")
			end
		end
	end
end

-- 난이도별 코인 개수 결정 (밀도 리듬 적용)
function CoinService:_getCoinCountForDifficulty(difficulty: string): number
	local counts = GameConstants.COIN_COUNTS[difficulty:upper()]
	if not counts then
		return 5
	end
	local base = math.random(counts.min, counts.max)

	-- Normal/Hard 청크에 코인 밀도 리듬 적용 (DENSE_EVERY번째마다 폭발적 밀도)
	if difficulty == "Normal" or difficulty == "Hard" then
		self._spawnCount = self._spawnCount + 1
		if self._spawnCount % GameConstants.COIN_RHYTHM.DENSE_EVERY == 0 then
			base = math.min(
				math.ceil(base * GameConstants.COIN_RHYTHM.DENSE_MULTIPLIER),
				GameConstants.COIN_RHYTHM.DENSE_MAX
			)
		end
	end

	return base
end

-- 코인 타입 선택 (가중 랜덤)
-- lucky_coins 업그레이드: Silver 확률 += _luckyCoinsBonus, Bronze에서 차감
function CoinService:_selectCoinType(difficulty: string): string
	local rand = math.random()
	local bonus = math.clamp(self._luckyCoinsBonus, 0, 0.35)

	if difficulty == "Bonus" then
		if rand < 0.05 then
			return "Diamond"
		elseif rand < 0.25 then
			return "Gold"
		elseif rand < 0.55 + bonus then
			return "Silver"
		else
			return "Bronze"
		end
	elseif difficulty == "Hard" then
		if rand < 0.03 then
			return "Diamond"
		elseif rand < 0.10 then
			return "Gold"
		elseif rand < 0.30 + bonus then
			return "Silver"
		else
			return "Bronze"
		end
	else
		if rand < 0.01 then
			return "Diamond"
		elseif rand < 0.06 then
			return "Gold"
		elseif rand < 0.21 + bonus then
			return "Silver"
		else
			return "Bronze"
		end
	end
end

-- 코인 생성 (Model with multiple parts)
function CoinService:_spawnCoin(position: Vector3, coinType: string)
	local value = GameConstants.COIN.BRONZE_VALUE
	local outerColor: Color3
	local innerColor: Color3

	if coinType == "Diamond" then
		outerColor = Color3.fromRGB(120, 200, 255)
		innerColor = Color3.fromRGB(200, 240, 255)
		value = GameConstants.COIN.DIAMOND_VALUE
	elseif coinType == "Gold" then
		outerColor = Color3.fromRGB(255, 215, 0)
		innerColor = Color3.fromRGB(255, 240, 100)
		value = GameConstants.COIN.GOLD_VALUE
	elseif coinType == "Silver" then
		outerColor = Color3.fromRGB(192, 192, 192)
		innerColor = Color3.fromRGB(230, 230, 240)
		value = GameConstants.COIN.SILVER_VALUE
	elseif coinType == "Bronze" then
		outerColor = Color3.fromRGB(205, 127, 50)
		innerColor = Color3.fromRGB(255, 170, 80)
		value = GameConstants.COIN.BRONZE_VALUE
	else
		outerColor = Color3.fromRGB(205, 127, 50)
		innerColor = Color3.fromRGB(255, 170, 80)
	end

	local coinModel = Instance.new("Model")
	coinModel.Name = "Coin_" .. coinType

	local outerRing = Instance.new("Part")
	outerRing.Name = "OuterRing"
	outerRing.Shape = Enum.PartType.Cylinder
	outerRing.Size = Vector3.new(0.25, 2.8, 2.8)
	outerRing.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)
	outerRing.Anchored = true
	outerRing.CanCollide = false
	outerRing.Color = outerColor
	outerRing.Material = Enum.Material.Metal
	outerRing.Reflectance = 0.4
	outerRing.Parent = coinModel

	local innerCircle = Instance.new("Part")
	innerCircle.Name = "InnerCircle"
	innerCircle.Shape = Enum.PartType.Cylinder
	innerCircle.Size = Vector3.new(0.28, 2.0, 2.0)
	innerCircle.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)
	innerCircle.Anchored = true
	innerCircle.CanCollide = false
	innerCircle.Color = innerColor
	innerCircle.Material = Enum.Material.Neon
	innerCircle.Parent = coinModel

	local centerDot = Instance.new("Part")
	centerDot.Name = "CenterDot"
	centerDot.Shape = Enum.PartType.Cylinder
	centerDot.Size = Vector3.new(0.3, 0.8, 0.8)
	centerDot.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)
	centerDot.Anchored = true
	centerDot.CanCollide = false
	centerDot.Color = outerColor
	centerDot.Material = Enum.Material.Neon
	centerDot.Parent = coinModel

	coinModel.PrimaryPart = outerRing
	outerRing:SetAttribute("CoinValue", value)
	outerRing:SetAttribute("CoinType", coinType)
	coinModel.Parent = workspace

	self:_startCoinRotation(coinModel)

	local coinData: CoinData = {
		part = outerRing,
		value = value,
		type = coinType,
		spawnTime = tick(),
	}
	table.insert(self._activeCoins, coinData)
end

-- 코인 회전 애니메이션
function CoinService:_startCoinRotation(coinModel: Model)
	local primaryPart = coinModel.PrimaryPart
	if not primaryPart then
		return
	end

	local startAngle = math.random() * 360
	local basePosition = primaryPart.Position

	task.spawn(function()
		local angle = startAngle
		while coinModel and coinModel.Parent and primaryPart and primaryPart.Parent do
			angle = angle + 5
			if angle >= 360 then
				angle = angle - 360
			end
			local newCFrame = CFrame.new(basePosition) * CFrame.Angles(0, math.rad(angle), 0)
			coinModel:SetPrimaryPartCFrame(newCFrame)
			task.wait(0.025)
		end
	end)
end

-- 충돌 감지 핸들러 설정
function CoinService:_setupCollisionHandlers()
	local character = self._player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
end

-- 플레이어 위치로 코인 수집 체크 (GameManager에서 호출)
function CoinService:CheckCoinCollection(playerPosition: Vector3, magnetRadius: number?): { CoinData }
	local collectedCoins = {}
	local baseRadius = 3
	local collectionRadius = baseRadius
	if magnetRadius and magnetRadius > 0 then
		collectionRadius = magnetRadius
	end

	-- 캐릭터가 +X 방향으로 달리므로, 정면(X) 수집 범위를 절반으로 압축해
	-- 코인이 시각적으로 캐릭터에 닿기 전에 수집되는 문제를 방지한다.
	-- 자석 효과 중에는 전방향 구형 판정을 유지한다.
	local useMagnet = magnetRadius and magnetRadius > 0

	for i = #self._activeCoins, 1, -1 do
		local coinData = self._activeCoins[i]
		local delta = coinData.part.Position - playerPosition

		local effectiveDist: number
		if useMagnet then
			-- 자석: 모든 방향 동일한 구형 판정
			effectiveDist = delta.Magnitude
		else
			-- 일반: 전진 방향(+X) 판정 거리를 2배 가중 → 실제 수집 범위 절반(1.5 studs)
			effectiveDist = Vector3.new(delta.X * 2, delta.Y, delta.Z).Magnitude
		end

		if effectiveDist < collectionRadius then
			table.insert(collectedCoins, coinData)

			local coinModel = coinData.part.Parent
			if coinModel and coinModel:IsA("Model") then
				coinModel:Destroy()
			else
				coinData.part:Destroy()
			end
			table.remove(self._activeCoins, i)
		end
	end

	return collectedCoins
end

-- 자석 폭발: 반경 내 모든 코인 즉시 수집 (magnet_burst 스킬용)
function CoinService:BurstCollectCoins(playerPosition: Vector3, radius: number): { CoinData }
	local collectedCoins = {}
	for i = #self._activeCoins, 1, -1 do
		local coinData = self._activeCoins[i]
		local distance = (coinData.part.Position - playerPosition).Magnitude
		if distance < radius then
			table.insert(collectedCoins, coinData)
			local coinModel = coinData.part.Parent
			if coinModel and coinModel:IsA("Model") then
				coinModel:Destroy()
			else
				coinData.part:Destroy()
			end
			table.remove(self._activeCoins, i)
		end
	end
	return collectedCoins
end

-- 청크 삭제 시 관련 코인 정리
function CoinService:CleanupCoinsInChunk(chunkPosition: Vector3, chunkSize: Vector3)
	for i = #self._activeCoins, 1, -1 do
		local coinData = self._activeCoins[i]
		local coinPos = coinData.part.Position

		local isInChunk = math.abs(coinPos.X - chunkPosition.X) < chunkSize.X / 2
			and math.abs(coinPos.Y - chunkPosition.Y) < chunkSize.Y / 2
			and math.abs(coinPos.Z - chunkPosition.Z) < chunkSize.Z / 2

		if isInChunk then
			local coinModel = coinData.part.Parent
			if coinModel and coinModel:IsA("Model") then
				coinModel:Destroy()
			else
				coinData.part:Destroy()
			end
			table.remove(self._activeCoins, i)
		end
	end
end

-- Phase B: 거인 코인 생성
function CoinService:SpawnGiantCoin(chunk: Model, chunkPosition: Vector3)
	local config = GameConstants.EVENT_CHUNKS.GIANT_COIN

	local coinModel = Instance.new("Model")
	coinModel.Name = "GiantCoin"

	local outerRing = Instance.new("Part")
	outerRing.Name = "OuterRing"
	outerRing.Shape = Enum.PartType.Cylinder
	outerRing.Size = Vector3.new(1, config.SIZE, config.SIZE)
	outerRing.CFrame = CFrame.new(chunkPosition.X + GameConstants.CHUNK.LENGTH / 2, config.HEIGHT, chunkPosition.Z)
		* CFrame.Angles(0, math.rad(90), 0)
	outerRing.Anchored = true
	outerRing.CanCollide = false
	outerRing.Color = Color3.fromRGB(0, 191, 255)
	outerRing.Material = Enum.Material.Neon
	outerRing:SetAttribute("GiantCoin", true)
	outerRing.Parent = coinModel

	local innerCircle = Instance.new("Part")
	innerCircle.Name = "InnerCircle"
	innerCircle.Shape = Enum.PartType.Cylinder
	innerCircle.Size = Vector3.new(1.2, config.SIZE * 0.7, config.SIZE * 0.7)
	innerCircle.CFrame = outerRing.CFrame
	innerCircle.Anchored = true
	innerCircle.CanCollide = false
	innerCircle.Color = Color3.fromRGB(150, 230, 255)
	innerCircle.Material = Enum.Material.Neon
	innerCircle.Parent = coinModel

	coinModel.PrimaryPart = outerRing
	coinModel.Parent = chunk

	self:_startCoinRotation(coinModel)

	local coinData: CoinData = {
		part = outerRing,
		value = config.REWARD,
		type = "Giant",
		spawnTime = tick(),
	}
	table.insert(self._activeCoins, coinData)
end

-- Phase B: 거인 코인 수집 체크
function CoinService:CheckGiantCoinCollection(playerPosition: Vector3): boolean
	for i = #self._activeCoins, 1, -1 do
		local coinData = self._activeCoins[i]
		if coinData.part and coinData.part:GetAttribute("GiantCoin") then
			local distance = (coinData.part.Position - playerPosition).Magnitude
			if distance < 6 then
				local coinModel = coinData.part.Parent
				if coinModel and coinModel:IsA("Model") then
					coinModel:Destroy()
				else
					coinData.part:Destroy()
				end
				table.remove(self._activeCoins, i)
				return true
			end
		end
	end
	return false
end

-- 모든 코인 정리 (게임 종료 시)
function CoinService:Destroy()
	for _, coinData in self._activeCoins do
		if coinData.part then
			local coinModel = coinData.part.Parent
			if coinModel and coinModel:IsA("Model") then
				coinModel:Destroy()
			else
				coinData.part:Destroy()
			end
		end
	end
	self._activeCoins = {}

	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return CoinService

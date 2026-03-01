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
	},
	CoinService
))

function CoinService.new(player: Player): CoinService
	local self = setmetatable({
		_activeCoins = {},
		_connections = {},
		_player = player,
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
local function patternSpread(count: number, halfWidth: number): { { x: number, y: number } }
	local positions = {}
	local rng = Random.new()
	local usedX: { number } = {}
	local MIN_SPACING = 5

	for _ = 1, count do
		local x = 0
		local y = 0
		local valid = false
		for _attempt = 1, 8 do
			x = rng:NextNumber(-halfWidth * 0.85, halfWidth * 0.85)
			y = 2.0 + rng:NextNumber(0, 4.0) -- 낮은 높이 유지

			-- 기존 코인과 너무 가깝지 않은지 체크
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
		table.insert(positions, { x = x, y = y })
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
			local y = 2.5 + math.random() * 3.0
			table.insert(positions, { x = x, y = y })
		end
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

-- =====================================================================
-- 패턴 선택 (난이도 + 장애물 유무 반영)
-- =====================================================================
function CoinService:_selectPattern(difficulty: string, obstaclePositions: { Vector3 }): string
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
-- =====================================================================
function CoinService:_generatePatternPositions(
	chunkCFrame: CFrame,
	chunkSize: Vector3,
	pattern: string,
	coinCount: number,
	obstaclePositions: { Vector3 }
): { Vector3 }
	local halfWidth = chunkSize.X * 0.45
	local chunkCenter = chunkCFrame.Position

	-- 장애물 X 좌표 리스트 (청크 중심 기준 상대값)
	local obstacleXList: { number } = {}
	for _, obsPos in obstaclePositions do
		table.insert(obstacleXList, obsPos.X - chunkCenter.X)
	end

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
-- =====================================================================
function CoinService:SpawnCoinsInChunk(chunk: Model, difficulty: string, obstaclePositions: { Vector3 }?)
	obstaclePositions = obstaclePositions or {}

	-- 코인 개수 결정
	local coinCount = self:_getCoinCountForDifficulty(difficulty)

	-- 청크 경계 계산
	local chunkCFrame = chunk:GetPrimaryPartCFrame()
	local chunkSize = chunk:GetExtentsSize()

	-- 패턴 선택
	local pattern = self:_selectPattern(difficulty, obstaclePositions :: { Vector3 })

	-- 패턴 위치 생성
	local positions =
		self:_generatePatternPositions(chunkCFrame, chunkSize, pattern, coinCount, obstaclePositions :: { Vector3 })

	-- 장애물 안전 거리 최종 검증
	local SAFE_DISTANCE = 5

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
end

-- 난이도별 코인 개수 결정
function CoinService:_getCoinCountForDifficulty(difficulty: string): number
	local counts = GameConstants.COIN_COUNTS[difficulty:upper()]
	if counts then
		return math.random(counts.min, counts.max)
	end
	return 5
end

-- 코인 타입 선택 (가중 랜덤)
function CoinService:_selectCoinType(difficulty: string): string
	local rand = math.random()

	if difficulty == "Bonus" then
		if rand < 0.05 then
			return "Diamond"
		elseif rand < 0.25 then
			return "Gold"
		elseif rand < 0.55 then
			return "Silver"
		else
			return "Bronze"
		end
	elseif difficulty == "Hard" then
		if rand < 0.03 then
			return "Diamond"
		elseif rand < 0.10 then
			return "Gold"
		elseif rand < 0.30 then
			return "Silver"
		else
			return "Bronze"
		end
	else
		if rand < 0.01 then
			return "Diamond"
		elseif rand < 0.06 then
			return "Gold"
		elseif rand < 0.21 then
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

	for i = #self._activeCoins, 1, -1 do
		local coinData = self._activeCoins[i]
		local distance = (coinData.part.Position - playerPosition).Magnitude

		if distance < collectionRadius then
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

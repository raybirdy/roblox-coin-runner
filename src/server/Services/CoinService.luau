--!strict
-- Coin Service
-- 코인 생성 및 수집 처리

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

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

-- 청크 내 코인 생성
function CoinService:SpawnCoinsInChunk(chunk: Model, difficulty: string)
	-- 난이도별 코인 개수 결정
	local coinCount = self:_getCoinCountForDifficulty(difficulty)

	-- 청크 경계 계산
	local chunkCFrame = chunk:GetPrimaryPartCFrame()
	local chunkSize = chunk:GetExtentsSize()

	-- 코인 배치 가능 영역 (청크 중앙 60%, 양옆 여백)
	local spawnAreaWidth = chunkSize.X * 0.6
	local spawnAreaHeight = chunkSize.Y * 0.8

	for i = 1, coinCount do
		-- 랜덤 위치 생성
		local randomX = (math.random() - 0.5) * spawnAreaWidth
		local randomY = math.random() * spawnAreaHeight
		local randomZ = 0

		local coinPosition = chunkCFrame.Position + Vector3.new(randomX, randomY, randomZ)

		-- 코인 타입 결정 (MVP: 대부분 Bronze)
		local coinType = self:_selectCoinType(difficulty)

		-- 코인 생성
		self:_spawnCoin(coinPosition, coinType)
	end
end

-- 난이도별 코인 개수 결정
function CoinService:_getCoinCountForDifficulty(difficulty: string): number
	-- 목표: 초당 1~2 코인
	-- 청크 통과 시간 ≈ 2초 (평균 속도 40 studs/s, 청크 길이 80 studs)
	-- 따라서 청크당 2~4개

	if difficulty == "Easy" then
		return math.random(3, 5) -- Easy는 코인 많게
	elseif difficulty == "Normal" then
		return math.random(2, 4)
	elseif difficulty == "Hard" then
		return math.random(1, 3) -- Hard는 코인 적게 (장애물 회피에 집중)
	elseif difficulty == "Bonus" then
		return math.random(10, 15) -- Bonus 청크는 코인 대량
	elseif difficulty == "NPC" then
		return math.random(2, 3)
	end

	return 3 -- 기본값
end

-- 코인 타입 선택 (가중 랜덤)
function CoinService:_selectCoinType(difficulty: string): string
	-- MVP: 대부분 Bronze, 가끔 Silver/Gold
	local rand = math.random()

	if difficulty == "Bonus" then
		-- Bonus 청크에서는 고급 코인 확률 높음
		if rand < 0.20 then
			return "Gold"
		elseif rand < 0.50 then
			return "Silver"
		else
			return "Bronze"
		end
	else
		-- 일반 청크
		if rand < 0.05 then
			return "Gold"
		elseif rand < 0.20 then
			return "Silver"
		else
			return "Bronze"
		end
	end
end

-- 코인 생성 (Model with multiple parts)
function CoinService:_spawnCoin(position: Vector3, coinType: string)
	-- 코인 타입별 색상 및 가치 결정
	local value = GameConstants.COIN.BRONZE_VALUE
	local outerColor: Color3
	local innerColor: Color3

	if coinType == "Bronze" then
		outerColor = Color3.fromRGB(205, 127, 50) -- 브론즈 색
		innerColor = Color3.fromRGB(255, 170, 80) -- 밝은 브론즈
		value = GameConstants.COIN.BRONZE_VALUE
	elseif coinType == "Silver" then
		outerColor = Color3.fromRGB(192, 192, 192) -- 실버 색
		innerColor = Color3.fromRGB(230, 230, 240) -- 밝은 실버
		value = GameConstants.COIN.SILVER_VALUE
	elseif coinType == "Gold" then
		outerColor = Color3.fromRGB(255, 215, 0) -- 골드 색
		innerColor = Color3.fromRGB(255, 240, 100) -- 밝은 골드
		value = GameConstants.COIN.GOLD_VALUE
	else
		outerColor = Color3.fromRGB(205, 127, 50)
		innerColor = Color3.fromRGB(255, 170, 80)
	end

	-- 코인 모델 생성
	local coinModel = Instance.new("Model")
	coinModel.Name = "Coin_" .. coinType

	-- 외부 링 (코인 테두리) - Cylinder를 Z축으로 회전하여 원형 면이 플레이어를 향하게
	local outerRing = Instance.new("Part")
	outerRing.Name = "OuterRing"
	outerRing.Shape = Enum.PartType.Cylinder
	outerRing.Size = Vector3.new(0.25, 2.8, 2.8) -- 얇고 넓은 원기둥 (X가 두께)
	outerRing.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)) -- Z축 90도 회전
	outerRing.Anchored = true
	outerRing.CanCollide = false
	outerRing.Color = outerColor
	outerRing.Material = Enum.Material.Metal
	outerRing.Reflectance = 0.4
	outerRing.Parent = coinModel

	-- 내부 원 (코인 중앙 - 더 밝은 색)
	local innerCircle = Instance.new("Part")
	innerCircle.Name = "InnerCircle"
	innerCircle.Shape = Enum.PartType.Cylinder
	innerCircle.Size = Vector3.new(0.28, 2.0, 2.0) -- 약간 두껍고 작은 원
	innerCircle.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	innerCircle.Anchored = true
	innerCircle.CanCollide = false
	innerCircle.Color = innerColor
	innerCircle.Material = Enum.Material.Neon
	innerCircle.Parent = coinModel

	-- 코인 중앙 장식 (별 모양 대신 작은 원)
	local centerDot = Instance.new("Part")
	centerDot.Name = "CenterDot"
	centerDot.Shape = Enum.PartType.Cylinder
	centerDot.Size = Vector3.new(0.3, 0.8, 0.8) -- 작은 중앙 점
	centerDot.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	centerDot.Anchored = true
	centerDot.CanCollide = false
	centerDot.Color = outerColor
	centerDot.Material = Enum.Material.Neon
	centerDot.Parent = coinModel

	-- PrimaryPart 설정
	coinModel.PrimaryPart = outerRing

	-- Attribute로 값 저장 (서버 검증용)
	outerRing:SetAttribute("CoinValue", value)
	outerRing:SetAttribute("CoinType", coinType)

	coinModel.Parent = workspace

	-- 회전 애니메이션 시작
	self:_startCoinRotation(coinModel)

	-- 코인 데이터 저장
	local coinData: CoinData = {
		part = outerRing, -- 충돌 감지용 메인 파트
		value = value,
		type = coinType,
		spawnTime = tick(),
	}
	table.insert(self._activeCoins, coinData)
end

-- 코인 회전 애니메이션 (Y축 기준 회전 - 코인이 빙글빙글)
function CoinService:_startCoinRotation(coinModel: Model)
	local primaryPart = coinModel.PrimaryPart
	if not primaryPart then
		return
	end

	-- 랜덤 시작 각도 (동기화 방지)
	local startAngle = math.random() * 360
	local basePosition = primaryPart.Position

	-- 회전 애니메이션 (무한 반복)
	task.spawn(function()
		local angle = startAngle
		while coinModel and coinModel.Parent and primaryPart and primaryPart.Parent do
			angle = angle + 5 -- 회전 속도 (프레임당 5도)
			if angle >= 360 then
				angle = angle - 360
			end

			-- Y축 기준 회전 + 기본 Z축 90도 유지 (코인이 세로로 서서 빙글빙글)
			local newCFrame = CFrame.new(basePosition)
				* CFrame.Angles(0, math.rad(angle), math.rad(90))
			coinModel:SetPrimaryPartCFrame(newCFrame)

			task.wait(0.025) -- ~40 FPS 회전
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

	-- Touched 이벤트는 CanCollide=false여도 발생함
	-- 하지만 더 정확한 방법은 Region3 또는 GetPartBoundsInBox 사용
	-- MVP에서는 간단하게 매 프레임 거리 체크로 구현
	-- (Heartbeat에서 GameManager가 호출할 예정)
end

-- 플레이어 위치로 코인 수집 체크 (GameManager에서 호출)
function CoinService:CheckCoinCollection(playerPosition: Vector3, magnetRadius: number?): { CoinData }
	local collectedCoins = {}

	-- 기본 수집 반경 (캐릭터 크기 + 약간의 여유)
	local baseRadius = 3

	-- 자석 효과가 있으면 반경 증가
	local collectionRadius = baseRadius
	if magnetRadius and magnetRadius > 0 then
		collectionRadius = magnetRadius
	end

	for i = #self._activeCoins, 1, -1 do
		local coinData = self._activeCoins[i]
		local distance = (coinData.part.Position - playerPosition).Magnitude

		if distance < collectionRadius then
			-- 코인 수집
			table.insert(collectedCoins, coinData)

			-- 서버에서 코인 제거 (Model 전체 삭제)
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

		-- 코인이 청크 영역 내에 있는지 확인
		local isInChunk = math.abs(coinPos.X - chunkPosition.X) < chunkSize.X / 2
			and math.abs(coinPos.Y - chunkPosition.Y) < chunkSize.Y / 2
			and math.abs(coinPos.Z - chunkPosition.Z) < chunkSize.Z / 2

		if isInChunk then
			-- Model 전체 삭제
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

-- 모든 코인 정리 (게임 종료 시)
function CoinService:Destroy()
	for _, coinData in self._activeCoins do
		if coinData.part then
			-- Model 전체 삭제
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

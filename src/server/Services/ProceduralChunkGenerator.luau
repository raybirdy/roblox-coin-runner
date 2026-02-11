--!strict
-- Procedural Chunk Generator
-- 절차적으로 청크 생성 (Roblox Studio 없이 코드로 레벨 디자인)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local ProceduralChunkGenerator = {}

-- 청크 생성 설정
local CHUNK_CONFIG = {
	-- 바닥 설정
	FLOOR_WIDTH = 20, -- Z축 폭
	FLOOR_THICKNESS = 1,

	-- 장애물 패턴 (난이도별)
	PATTERNS = {
		Easy = {
			{ type = "empty" }, -- 빈 공간
			{ type = "low_wall" }, -- 낮은 벽 (점프)
			{ type = "gap_small" }, -- 작은 구덩이
			{ type = "coins_line" }, -- 코인 라인
		},
		Normal = {
			{ type = "low_wall" },
			{ type = "high_wall" }, -- 높은 벽 (슬라이드)
			{ type = "gap_medium" }, -- 중간 구덩이
			{ type = "low_high_combo" }, -- 낮은벽 + 높은벽 조합
			{ type = "platform_jump" }, -- 플랫폼 점프
		},
		Hard = {
			{ type = "high_wall" },
			{ type = "gap_large" }, -- 큰 구덩이
			{ type = "double_obstacle" }, -- 연속 장애물
			{ type = "moving_platform" }, -- 움직이는 플랫폼 (시각적)
			{ type = "spike_zone" }, -- 스파이크 구간
		},
		Bonus = {
			{ type = "coin_heaven" }, -- 코인 대량
			{ type = "rainbow_path" }, -- 무지개 길
		},
		NPC = {
			{ type = "npc_cheer" }, -- NPC 응원 구간
		},
	},

	-- 높이 전환 확률
	HEIGHT_TRANSITION = {
		LOW = { LOW = 0.7, MID = 0.3, HIGH = 0.0 },
		MID = { LOW = 0.3, MID = 0.4, HIGH = 0.3 },
		HIGH = { LOW = 0.0, MID = 0.3, HIGH = 0.7 },
	},
}

-- 청크 생성 (메인 함수)
function ProceduralChunkGenerator.Generate(
	difficulty: string,
	startHeight: string,
	position: Vector3
): Model
	local chunk = Instance.new("Model")
	chunk.Name = `Chunk_{difficulty}_{startHeight}`

	-- 끝 높이 결정
	local endHeight = ProceduralChunkGenerator._selectEndHeight(startHeight)

	-- Attributes 설정
	chunk:SetAttribute("Difficulty", difficulty)
	chunk:SetAttribute("StartHeight", startHeight)
	chunk:SetAttribute("EndHeight", endHeight)
	chunk:SetAttribute("Procedural", true)

	-- 바닥 생성
	local floor = ProceduralChunkGenerator._createFloor(position, startHeight, endHeight)
	floor.Parent = chunk
	chunk.PrimaryPart = floor

	-- 난이도별 장식 생성
	ProceduralChunkGenerator._addDecorations(chunk, position, difficulty)

	-- 높이 전환 경사로 (필요시)
	if startHeight ~= endHeight then
		ProceduralChunkGenerator._createRamp(chunk, position, startHeight, endHeight)
	end

	-- 난이도별 시각 효과
	ProceduralChunkGenerator._addDifficultyVisuals(chunk, position, difficulty)

	chunk.Parent = workspace

	return chunk
end

-- 끝 높이 선택
function ProceduralChunkGenerator._selectEndHeight(startHeight: string): string
	local transitions = CHUNK_CONFIG.HEIGHT_TRANSITION[startHeight]
	if not transitions then
		return "LOW"
	end

	local rand = math.random()
	local cumulative = 0

	for height, probability in transitions do
		cumulative += probability
		if rand <= cumulative then
			return height
		end
	end

	return startHeight
end

-- 바닥 생성
function ProceduralChunkGenerator._createFloor(
	position: Vector3,
	startHeight: string,
	endHeight: string
): Part
	local chunkLength = GameConstants.CHUNK.LENGTH

	-- 높이값 계산
	local startY = ProceduralChunkGenerator._getHeightValue(startHeight)
	local endY = ProceduralChunkGenerator._getHeightValue(endHeight)
	local avgY = (startY + endY) / 2

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(chunkLength, CHUNK_CONFIG.FLOOR_THICKNESS, CHUNK_CONFIG.FLOOR_WIDTH)
	floor.Position = Vector3.new(
		position.X + chunkLength / 2,
		avgY + CHUNK_CONFIG.FLOOR_THICKNESS / 2,
		position.Z
	)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Color = Color3.fromRGB(90, 90, 100)
	floor.Material = Enum.Material.Concrete

	return floor
end

-- 높이값 반환
function ProceduralChunkGenerator._getHeightValue(height: string): number
	if height == "LOW" then
		return GameConstants.CHUNK.HEIGHT_LOW
	elseif height == "MID" then
		return GameConstants.CHUNK.HEIGHT_MID
	elseif height == "HIGH" then
		return GameConstants.CHUNK.HEIGHT_HIGH
	end
	return 0
end

-- 경사로 생성 (높이 전환 시)
function ProceduralChunkGenerator._createRamp(
	chunk: Model,
	position: Vector3,
	startHeight: string,
	endHeight: string
)
	local chunkLength = GameConstants.CHUNK.LENGTH
	local startY = ProceduralChunkGenerator._getHeightValue(startHeight)
	local endY = ProceduralChunkGenerator._getHeightValue(endHeight)

	-- 경사로 길이 (청크 중간 부분)
	local rampLength = chunkLength * 0.4
	local rampStartX = position.X + chunkLength * 0.3

	-- 경사 각도 계산
	local heightDiff = endY - startY
	local angle = math.atan2(heightDiff, rampLength)

	local ramp = Instance.new("Part")
	ramp.Name = "Ramp"
	ramp.Size = Vector3.new(rampLength, 1, CHUNK_CONFIG.FLOOR_WIDTH - 2)
	ramp.CFrame = CFrame.new(
		rampStartX + rampLength / 2,
		(startY + endY) / 2 + 0.5,
		position.Z
	) * CFrame.Angles(0, 0, -angle)
	ramp.Anchored = true
	ramp.CanCollide = true
	ramp.Color = Color3.fromRGB(100, 100, 110)
	ramp.Material = Enum.Material.Concrete
	ramp.Parent = chunk

	-- 경사로 가이드 라인
	local guideLine = Instance.new("Part")
	guideLine.Name = "RampGuide"
	guideLine.Size = Vector3.new(rampLength, 0.2, 0.5)
	guideLine.CFrame = ramp.CFrame * CFrame.new(0, 0.6, 0)
	guideLine.Anchored = true
	guideLine.CanCollide = false
	guideLine.Color = Color3.fromRGB(255, 200, 50)
	guideLine.Material = Enum.Material.Neon
	guideLine.Parent = chunk
end

-- 장식 추가
function ProceduralChunkGenerator._addDecorations(chunk: Model, position: Vector3, difficulty: string)
	local chunkLength = GameConstants.CHUNK.LENGTH

	-- 측면 레일/가드
	for _, zOffset in { -CHUNK_CONFIG.FLOOR_WIDTH / 2 - 0.5, CHUNK_CONFIG.FLOOR_WIDTH / 2 + 0.5 } do
		local rail = Instance.new("Part")
		rail.Name = "SideRail"
		rail.Size = Vector3.new(chunkLength, 0.5, 0.5)
		rail.Position = Vector3.new(
			position.X + chunkLength / 2,
			1.25,
			position.Z + zOffset
		)
		rail.Anchored = true
		rail.CanCollide = false
		rail.Color = Color3.fromRGB(150, 150, 160)
		rail.Material = Enum.Material.Metal
		rail.Parent = chunk
	end

	-- 바닥 라인 마킹
	local lineCount = math.floor(chunkLength / 20)
	for i = 1, lineCount do
		local line = Instance.new("Part")
		line.Name = `FloorLine_{i}`
		line.Size = Vector3.new(0.3, 0.1, CHUNK_CONFIG.FLOOR_WIDTH - 4)
		line.Position = Vector3.new(
			position.X + i * 20,
			1.05,
			position.Z
		)
		line.Anchored = true
		line.CanCollide = false
		line.Color = Color3.fromRGB(200, 200, 200)
		line.Material = Enum.Material.SmoothPlastic
		line.Parent = chunk
	end
end

-- 난이도별 시각 효과
function ProceduralChunkGenerator._addDifficultyVisuals(chunk: Model, position: Vector3, difficulty: string)
	local chunkLength = GameConstants.CHUNK.LENGTH

	if difficulty == "Bonus" then
		-- 보너스 청크: 반짝이는 테두리
		ProceduralChunkGenerator._addBonusVisuals(chunk, position)
	elseif difficulty == "Hard" then
		-- 하드 청크: 경고 표시
		ProceduralChunkGenerator._addHardVisuals(chunk, position)
	elseif difficulty == "NPC" then
		-- NPC 청크: 환영 아치
		ProceduralChunkGenerator._addNPCVisuals(chunk, position)
	end
end

-- 보너스 청크 시각 효과
function ProceduralChunkGenerator._addBonusVisuals(chunk: Model, position: Vector3)
	local chunkLength = GameConstants.CHUNK.LENGTH

	-- 입구 아치 (금색)
	local arch = Instance.new("Part")
	arch.Name = "BonusArch"
	arch.Size = Vector3.new(2, 10, 22)
	arch.Position = Vector3.new(position.X + 2, 6, position.Z)
	arch.Anchored = true
	arch.CanCollide = false
	arch.Color = Color3.fromRGB(255, 215, 0)
	arch.Material = Enum.Material.Neon
	arch.Transparency = 0.3
	arch.Parent = chunk

	-- "BONUS" 텍스트 (SurfaceGui로 3D 공간에 표시)
	local signPart = Instance.new("Part")
	signPart.Name = "BonusSign"
	signPart.Size = Vector3.new(0.3, 3, 6)
	signPart.Position = Vector3.new(position.X - 2, 8, position.Z)
	signPart.Color = Color3.fromRGB(30, 30, 40)
	signPart.Material = Enum.Material.SmoothPlastic
	signPart.CanCollide = false
	signPart.Anchored = true
	signPart.Parent = chunk

	-- 간판 테두리 (금색 네온)
	local signBorder = Instance.new("Part")
	signBorder.Name = "BonusSignBorder"
	signBorder.Size = Vector3.new(0.1, 3.2, 6.2)
	signBorder.Position = Vector3.new(position.X - 2.15, 8, position.Z)
	signBorder.Color = Color3.fromRGB(255, 215, 0)
	signBorder.Material = Enum.Material.Neon
	signBorder.CanCollide = false
	signBorder.Anchored = true
	signBorder.Parent = chunk

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "BonusGui"
	surfaceGui.Face = Enum.NormalId.Left -- 플레이어 방향(-X)을 향함
	surfaceGui.CanvasSize = Vector2.new(200, 100)
	surfaceGui.Parent = signPart

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "BONUS!"
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(200, 150, 0)
	text.Parent = surfaceGui

	-- 별 장식
	for i = 1, 5 do
		local star = Instance.new("Part")
		star.Name = `Star_{i}`
		star.Shape = Enum.PartType.Ball
		star.Size = Vector3.new(1.5, 1.5, 1.5)
		star.Position = Vector3.new(
			position.X + 10 + i * 12,
			8 + math.sin(i) * 2,
			position.Z + math.cos(i * 2) * 5
		)
		star.Anchored = true
		star.CanCollide = false
		star.Color = Color3.fromRGB(255, 255, 100)
		star.Material = Enum.Material.Neon
		star.Parent = chunk
	end
end

-- 하드 청크 시각 효과
function ProceduralChunkGenerator._addHardVisuals(chunk: Model, position: Vector3)
	local chunkLength = GameConstants.CHUNK.LENGTH

	-- 경고 표시판
	local warningSign = Instance.new("Part")
	warningSign.Name = "WarningSign"
	warningSign.Size = Vector3.new(0.5, 4, 4)
	warningSign.Position = Vector3.new(position.X + 2, 5, position.Z - 8)
	warningSign.Anchored = true
	warningSign.CanCollide = false
	warningSign.Transparency = 1
	warningSign.Parent = chunk

	-- 경고 텍스트 (잘 보이도록 배경 추가)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 140, 0, 70)
	billboard.Adornee = warningSign
	billboard.AlwaysOnTop = true
	billboard.Parent = warningSign

	-- 배경 프레임 (검은색 반투명)
	local bgFrame = Instance.new("Frame")
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bgFrame.BackgroundTransparency = 0.3
	bgFrame.BorderSizePixel = 3
	bgFrame.BorderColor3 = Color3.fromRGB(255, 50, 50)
	bgFrame.Parent = billboard

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "HARD!"
	text.TextColor3 = Color3.fromRGB(255, 255, 255) -- 흰색 글자
	text.TextSize = 36
	text.Font = Enum.Font.GothamBlack
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(200, 0, 0) -- 빨간 테두리
	text.Parent = bgFrame

	-- 빨간 테두리 라인
	for _, zOffset in { -CHUNK_CONFIG.FLOOR_WIDTH / 2, CHUNK_CONFIG.FLOOR_WIDTH / 2 } do
		local dangerLine = Instance.new("Part")
		dangerLine.Name = "DangerLine"
		dangerLine.Size = Vector3.new(chunkLength, 0.3, 0.3)
		dangerLine.Position = Vector3.new(
			position.X + chunkLength / 2,
			1.15,
			position.Z + zOffset
		)
		dangerLine.Anchored = true
		dangerLine.CanCollide = false
		dangerLine.Color = Color3.fromRGB(255, 50, 50)
		dangerLine.Material = Enum.Material.Neon
		dangerLine.Parent = chunk
	end
end

-- NPC 청크 시각 효과
function ProceduralChunkGenerator._addNPCVisuals(chunk: Model, position: Vector3)
	-- 환영 아치
	local welcomeArch = Instance.new("Part")
	welcomeArch.Name = "WelcomeArch"
	welcomeArch.Size = Vector3.new(2, 8, 18)
	welcomeArch.Position = Vector3.new(position.X + 2, 5, position.Z)
	welcomeArch.Anchored = true
	welcomeArch.CanCollide = false
	welcomeArch.Color = Color3.fromRGB(255, 150, 200)
	welcomeArch.Material = Enum.Material.Neon
	welcomeArch.Transparency = 0.5
	welcomeArch.Parent = chunk

	-- 하트 장식
	for i = 1, 3 do
		local heart = Instance.new("Part")
		heart.Name = `Heart_{i}`
		heart.Shape = Enum.PartType.Ball
		heart.Size = Vector3.new(1.2, 1.2, 1.2)
		heart.Position = Vector3.new(
			position.X + 2,
			10 + i * 1.5,
			position.Z + (i - 2) * 3
		)
		heart.Anchored = true
		heart.CanCollide = false
		heart.Color = Color3.fromRGB(255, 100, 150)
		heart.Material = Enum.Material.Neon
		heart.Parent = chunk
	end
end

print("[ProceduralChunkGenerator] Module loaded")

return ProceduralChunkGenerator

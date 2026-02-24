--!strict
-- Speed Effect Controller
-- 속도감 연출: 스피드 라인 + 캐릭터 Trail
-- 파티클 없이 가벼운 효과

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local SpeedEffectController = {}
SpeedEffectController.__index = SpeedEffectController

export type SpeedEffectController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_character: Model?,
		_humanoidRootPart: BasePart?,
		_speedLines: { Part },
		_speedLinesFolder: Folder?,
		_trail: Trail?,
		_trailAttachment0: Attachment?,
		_trailAttachment1: Attachment?,
		_isRunning: boolean,
		_currentSpeed: number,
		_connections: { RBXScriptConnection },
	},
	SpeedEffectController
))

function SpeedEffectController.new(player: Player): SpeedEffectController
	local self = setmetatable({
		_player = player,
		_character = nil,
		_humanoidRootPart = nil,
		_speedLines = {},
		_speedLinesFolder = nil,
		_trail = nil,
		_trailAttachment0 = nil,
		_trailAttachment1 = nil,
		_isRunning = false,
		_currentSpeed = 0,
		_connections = {},
	}, SpeedEffectController)

	return self
end

-- 게임 시작 시 호출
function SpeedEffectController:StartGame(character: Model)
	self._character = character
	self._humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	self._isRunning = true
	self._currentSpeed = GameConstants.PHYSICS.SPEED_MIN

	-- Trail 생성
	self:_createTrail()

	-- 스피드 라인 폴더 생성
	self:_createSpeedLinesFolder()

	-- 스피드 라인 생성
	self:_createSpeedLines()

	-- 업데이트 루프
	local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		if self._isRunning then
			self:_update(deltaTime)
		end
	end)
	table.insert(self._connections, connection)

	print("[SpeedEffectController] Started")
end

-- 게임 종료 시 호출
function SpeedEffectController:StopGame()
	self._isRunning = false
	self._currentSpeed = 0

	-- Trail 숨기기
	if self._trail then
		self._trail.Enabled = false
	end

	-- 스피드 라인 숨기기
	for _, line in self._speedLines do
		line.Transparency = 1
	end

	print("[SpeedEffectController] Stopped")
end

-- 속도 업데이트 (PlayerController에서 호출)
function SpeedEffectController:SetSpeed(speed: number)
	self._currentSpeed = speed
end

-- Trail 생성
function SpeedEffectController:_createTrail()
	if not self._humanoidRootPart then
		return
	end

	local trailConfig = GameConstants.BACKGROUND.TRAIL
	if not trailConfig.ENABLED then
		return
	end

	-- 기존 Trail 제거
	self:_removeTrail()

	-- Attachment 생성
	self._trailAttachment0 = Instance.new("Attachment")
	self._trailAttachment0.Name = "TrailAttachment0"
	self._trailAttachment0.Position = Vector3.new(0, 1, 0) -- 위쪽
	self._trailAttachment0.Parent = self._humanoidRootPart

	self._trailAttachment1 = Instance.new("Attachment")
	self._trailAttachment1.Name = "TrailAttachment1"
	self._trailAttachment1.Position = Vector3.new(0, -1, 0) -- 아래쪽
	self._trailAttachment1.Parent = self._humanoidRootPart

	-- Trail 생성
	self._trail = Instance.new("Trail")
	self._trail.Name = "SpeedTrail"
	self._trail.Attachment0 = self._trailAttachment0
	self._trail.Attachment1 = self._trailAttachment1
	self._trail.Lifetime = trailConfig.LIFETIME
	self._trail.MinLength = trailConfig.MIN_LENGTH
	self._trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, trailConfig.WIDTH[1]),
		NumberSequenceKeypoint.new(1, trailConfig.WIDTH[2]),
	})
	self._trail.Color = ColorSequence.new(trailConfig.COLOR)
	self._trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, trailConfig.TRANSPARENCY[1]),
		NumberSequenceKeypoint.new(1, trailConfig.TRANSPARENCY[2]),
	})
	self._trail.LightEmission = 0.5
	self._trail.Enabled = true
	self._trail.Parent = self._humanoidRootPart

	print("[SpeedEffectController] Trail created")
end

-- Trail 제거
function SpeedEffectController:_removeTrail()
	if self._trail then
		self._trail:Destroy()
		self._trail = nil
	end
	if self._trailAttachment0 then
		self._trailAttachment0:Destroy()
		self._trailAttachment0 = nil
	end
	if self._trailAttachment1 then
		self._trailAttachment1:Destroy()
		self._trailAttachment1 = nil
	end
end

-- 스피드 라인 폴더 생성
function SpeedEffectController:_createSpeedLinesFolder()
	-- 기존 폴더 제거
	if self._speedLinesFolder then
		self._speedLinesFolder:Destroy()
	end

	self._speedLinesFolder = Instance.new("Folder")
	self._speedLinesFolder.Name = "SpeedLines"
	self._speedLinesFolder.Parent = workspace
end

-- 스피드 라인 생성
function SpeedEffectController:_createSpeedLines()
	if not self._speedLinesFolder then
		return
	end

	local lineConfig = GameConstants.BACKGROUND.SPEED_LINES
	if not lineConfig.ENABLED then
		return
	end

	-- 기존 라인 제거
	for _, line in self._speedLines do
		line:Destroy()
	end
	self._speedLines = {}

	-- 새 라인 생성
	for i = 1, lineConfig.COUNT do
		local line = Instance.new("Part")
		line.Name = `SpeedLine_{i}`
		line.Size = Vector3.new(lineConfig.LENGTH, 0.15, 0.15)
		line.Anchored = true
		line.CanCollide = false
		line.Color = Color3.fromRGB(255, 255, 255)
		line.Material = Enum.Material.Neon
		line.Transparency = 0.5
		line.CastShadow = false
		line.Parent = self._speedLinesFolder

		-- 랜덤 시작 위치
		self:_resetSpeedLine(line, true)

		table.insert(self._speedLines, line)
	end

	print(`[SpeedEffectController] Created {lineConfig.COUNT} speed lines`)
end

-- 스피드 라인 위치 리셋
function SpeedEffectController:_resetSpeedLine(line: Part, randomX: boolean)
	if not self._humanoidRootPart then
		return
	end

	local lineConfig = GameConstants.BACKGROUND.SPEED_LINES
	local playerPos = self._humanoidRootPart.Position

	-- 랜덤 Y, Z 위치
	local yPos = math.random(lineConfig.Y_RANGE[1], lineConfig.Y_RANGE[2])
	local zPos = math.random(lineConfig.Z_RANGE[1] * 10, lineConfig.Z_RANGE[2] * 10) / 10

	-- X 위치: 플레이어 앞쪽에서 시작
	local xPos
	if randomX then
		xPos = playerPos.X + math.random(10, 60)
	else
		xPos = playerPos.X + 50 + math.random(0, 20)
	end

	line.Position = Vector3.new(xPos, yPos, zPos)
	line.Transparency = 0.3 + math.random() * 0.3
end

-- 매 프레임 업데이트
function SpeedEffectController:_update(deltaTime: number)
	if not self._humanoidRootPart then
		return
	end

	-- Trail 투명도 조절 (속도에 따라)
	self:_updateTrail()

	-- 스피드 라인 이동
	self:_updateSpeedLines(deltaTime)
end

-- Trail 업데이트
function SpeedEffectController:_updateTrail()
	if not self._trail then
		return
	end

	local trailConfig = GameConstants.BACKGROUND.TRAIL

	-- 속도에 따라 Trail 강도 조절
	local speedRatio = (self._currentSpeed - GameConstants.PHYSICS.SPEED_MIN)
		/ (GameConstants.PHYSICS.SPEED_MAX - GameConstants.PHYSICS.SPEED_MIN)
	speedRatio = math.clamp(speedRatio, 0, 1)

	-- 속도가 낮으면 Trail 약하게
	local baseTransparency = trailConfig.TRANSPARENCY[1]
	local adjustedTransparency = baseTransparency + (1 - speedRatio) * 0.4

	self._trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, adjustedTransparency),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- Lifetime도 속도에 따라 조절
	self._trail.Lifetime = trailConfig.LIFETIME * (0.5 + speedRatio * 0.5)
end

-- 스피드 라인 업데이트
function SpeedEffectController:_updateSpeedLines(deltaTime: number)
	if not self._humanoidRootPart then
		return
	end

	local lineConfig = GameConstants.BACKGROUND.SPEED_LINES
	if not lineConfig.ENABLED then
		return
	end

	local playerPos = self._humanoidRootPart.Position

	-- 속도에 따른 라인 속도
	local lineSpeed = self._currentSpeed * lineConfig.SPEED_MULTIPLIER

	-- 속도가 낮으면 라인 투명하게
	local speedRatio = (self._currentSpeed - GameConstants.PHYSICS.SPEED_MIN)
		/ (GameConstants.PHYSICS.SPEED_MAX - GameConstants.PHYSICS.SPEED_MIN)
	speedRatio = math.clamp(speedRatio, 0, 1)

	for _, line in self._speedLines do
		-- 라인 이동 (플레이어 뒤쪽으로)
		local newX = line.Position.X - lineSpeed * deltaTime
		line.Position = Vector3.new(newX, line.Position.Y, line.Position.Z)

		-- 속도에 따른 투명도
		line.Transparency = 0.3 + (1 - speedRatio) * 0.5

		-- 플레이어 뒤쪽으로 지나가면 리셋
		if line.Position.X < playerPos.X - 20 then
			self:_resetSpeedLine(line, false)
		end
	end
end

-- 캐릭터 업데이트 (리스폰 시)
function SpeedEffectController:UpdateCharacter(newCharacter: Model)
	self._character = newCharacter
	self._humanoidRootPart = newCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- Trail 재생성
	if self._isRunning then
		self:_createTrail()
	end
end

-- 정리
function SpeedEffectController:Destroy()
	self._isRunning = false

	-- 연결 해제
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	-- Trail 제거
	self:_removeTrail()

	-- 스피드 라인 제거
	for _, line in self._speedLines do
		line:Destroy()
	end
	self._speedLines = {}

	if self._speedLinesFolder then
		self._speedLinesFolder:Destroy()
		self._speedLinesFolder = nil
	end
end

return SpeedEffectController

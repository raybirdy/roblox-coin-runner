--!strict
-- Player Controller
-- 플레이어 캐릭터 이동 및 물리 제어

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local PlayerController = {}
PlayerController.__index = PlayerController

type State = "Idle" | "Running" | "Jumping" | "Sliding" | "Falling"

export type PlayerController = typeof(setmetatable(
	{} :: {
		player: Player,
		character: Model,
		humanoidRootPart: BasePart,
		humanoid: Humanoid,

		-- 상태
		state: State,
		isGrounded: boolean,
		canDoubleJump: boolean,
		isSliding: boolean,

		-- 속도
		currentSpeed: number,
		gameStartTime: number,

		-- 점프
		jumpVelocity: BodyVelocity?,
		verticalVelocity: number,

		-- Z축 고정
		alignPosition: AlignPosition?,

		-- 연결
		_connections: { RBXScriptConnection },
	},
	PlayerController
))

function PlayerController.new(player: Player, character: Model): PlayerController
	local hrp = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local self = setmetatable({
		player = player,
		character = character,
		humanoidRootPart = hrp,
		humanoid = humanoid,

		state = "Idle",
		isGrounded = true,
		canDoubleJump = false,
		isSliding = false,

		currentSpeed = GameConstants.PHYSICS.SPEED_MIN,
		gameStartTime = 0,

		jumpVelocity = nil,
		verticalVelocity = 0,

		alignPosition = nil,

		_connections = {},
	}, PlayerController)

	self:_setupZAxisConstraint()
	self:_setupPhysics()

	return self
end

-- 게임 시작
function PlayerController:StartGame()
	self.gameStartTime = tick()
	self.currentSpeed = GameConstants.PHYSICS.SPEED_MIN
	self.state = "Running"

	-- RunService 루프 시작
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		self:_update(deltaTime)
	end)
	table.insert(self._connections, connection)

	print(`[PlayerController] Game started for {self.player.Name}`)
end

-- 게임 종료
function PlayerController:StopGame()
	self.state = "Idle"
	self.currentSpeed = 0
	print(`[PlayerController] Game stopped for {self.player.Name}`)
end

-- Z축 고정 설정 (2D 평면 유지)
function PlayerController:_setupZAxisConstraint()
	local attachment = Instance.new("Attachment")
	attachment.Name = "ZAxisAttachment"
	attachment.Parent = self.humanoidRootPart

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "ZAxisAlign"
	alignPosition.Attachment0 = attachment
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.MaxForce = 10000
	alignPosition.MaxVelocity = math.huge
	alignPosition.Responsiveness = 200
	alignPosition.Parent = self.humanoidRootPart

	-- 목표 위치 설정 (X, Y는 자유, Z는 0 고정)
	local function updatePosition()
		local currentPos = self.humanoidRootPart.Position
		alignPosition.Position = Vector3.new(currentPos.X, currentPos.Y, GameConstants.PLAYER.Z_POSITION)
	end

	-- 지속적으로 Z축 위치 업데이트
	local conn = RunService.Heartbeat:Connect(updatePosition)
	table.insert(self._connections, conn)

	self.alignPosition = alignPosition

	print("[PlayerController] Z-axis constraint set up")
end

-- 물리 설정
function PlayerController:_setupPhysics()
	-- Humanoid 설정
	self.humanoid.WalkSpeed = 0 -- 자동 전진을 사용하므로 걷기 비활성화
	self.humanoid.JumpPower = 0 -- 커스텀 점프 사용
	self.humanoid.AutoRotate = false -- 회전 고정 (오른쪽 보기)

	-- 캐릭터 회전 고정 (오른쪽을 향하기)
	self.humanoidRootPart.CFrame = CFrame.new(self.humanoidRootPart.Position) * CFrame.Angles(0, math.rad(-90), 0)

	print("[PlayerController] Physics set up")
end

-- 메인 업데이트 루프
function PlayerController:_update(deltaTime: number)
	if self.state == "Idle" then
		return
	end

	-- 속도 업데이트 (시간에 따라 증가)
	self:_updateSpeed()

	-- 전진 이동
	self:_moveForward(deltaTime)

	-- 바닥 감지
	self:_checkGrounded()

	-- 점프 물리 (공중에 있을 때)
	if not self.isGrounded then
		self:_applyGravity(deltaTime)
	end

	-- 슬라이드 종료 체크
	if self.isSliding then
		self:_updateSlide(deltaTime)
	end
end

-- 속도 증가 (EaseOutQuad)
function PlayerController:_updateSpeed()
	local elapsedTime = tick() - self.gameStartTime
	local t = math.min(elapsedTime / GameConstants.PHYSICS.SPEED_RAMP_TIME, 1)

	-- EaseOutQuad: 1 - (1 - t)^2
	local easedT = 1 - math.pow(1 - t, 2)

	local minSpeed = GameConstants.PHYSICS.SPEED_MIN
	local maxSpeed = GameConstants.PHYSICS.SPEED_MAX

	self.currentSpeed = minSpeed + (maxSpeed - minSpeed) * easedT
end

-- 전진 이동
function PlayerController:_moveForward(deltaTime: number)
	local currentPos = self.humanoidRootPart.Position
	local moveDistance = self.currentSpeed * deltaTime

	-- X축으로 이동 (오른쪽)
	local newPos = currentPos + Vector3.new(moveDistance, 0, 0)
	self.humanoidRootPart.CFrame = CFrame.new(newPos) * CFrame.Angles(0, math.rad(-90), 0)
end

-- 바닥 감지 (Y 위치 기반)
function PlayerController:_checkGrounded()
	local currentY = self.humanoidRootPart.Position.Y
	local groundHeight = 2.5 -- 캐릭터 높이의 절반 (바닥에 서 있을 때 중심 높이)
	local tolerance = 1.0 -- 허용 오차 (증가)

	local wasGrounded = self.isGrounded
	self.isGrounded = math.abs(currentY - groundHeight) < tolerance

	-- 착지 시
	if self.isGrounded and not wasGrounded and (self.state == "Jumping" or self.state == "Falling") then
		self.state = "Running"
		self.canDoubleJump = false
		self.verticalVelocity = 0
		print(`[PlayerController] Landed - Y: {currentY}`)
	end

	-- 공중으로 올라갔을 때
	if not self.isGrounded and wasGrounded and self.state == "Running" then
		self.state = "Falling"
		print(`[PlayerController] Airborne - Y: {currentY}`)
	end
end

-- 점프
function PlayerController:Jump()
	-- 슬라이드 중에는 점프 불가
	if self.isSliding then
		print("[PlayerController] Cannot jump while sliding")
		return
	end

	-- 1단 점프 (바닥에 있을 때)
	if self.isGrounded then
		self:_performJump(GameConstants.PHYSICS.JUMP_HEIGHT_FIRST)
		self.canDoubleJump = true
		print(`[PlayerController] First jump - Y: {self.humanoidRootPart.Position.Y}`)
		return
	end

	-- 2단 점프 (공중에서)
	if self.canDoubleJump then
		self:_performJump(GameConstants.PHYSICS.JUMP_HEIGHT_SECOND)
		self.canDoubleJump = false
		print(`[PlayerController] Second jump - Y: {self.humanoidRootPart.Position.Y}`)
		return
	end

	-- 점프 불가 상태
	print(`[PlayerController] Cannot jump - Grounded: {self.isGrounded}, CanDoubleJump: {self.canDoubleJump}, State: {self.state}`)
end

-- 점프 실행
function PlayerController:_performJump(jumpHeight: number)
	self.state = "Jumping"
	self.isGrounded = false

	-- 점프 초기 속도 계산 (v = sqrt(2 * g * h))
	local gravity = GameConstants.PHYSICS.GRAVITY
	self.verticalVelocity = math.sqrt(2 * gravity * jumpHeight)

	print(`[PlayerController] Jump velocity: {self.verticalVelocity}`)
end

-- 중력 적용
function PlayerController:_applyGravity(deltaTime: number)
	local gravity = GameConstants.PHYSICS.GRAVITY

	-- 수직 속도 감소 (중력)
	self.verticalVelocity -= gravity * deltaTime

	-- Y축 이동
	local currentPos = self.humanoidRootPart.Position
	local newY = currentPos.Y + (self.verticalVelocity * deltaTime)

	-- 최소 높이 제한 (바닥 아래로 떨어지지 않도록)
	local minHeight = 2.5 -- 캐릭터 높이의 절반
	if newY < minHeight then
		newY = minHeight
		self.verticalVelocity = 0
		self.isGrounded = true
	end

	self.humanoidRootPart.CFrame = CFrame.new(currentPos.X, newY, GameConstants.PLAYER.Z_POSITION)
		* CFrame.Angles(0, math.rad(-90), 0)
end

-- 슬라이드
function PlayerController:Slide()
	if self.isSliding then
		print("[PlayerController] Already sliding")
		return
	end

	self.isSliding = true
	self.state = "Sliding"

	-- 서버에 슬라이딩 상태 전달 (Attribute 사용)
	self.humanoidRootPart:SetAttribute("IsSliding", true)

	-- 히트박스 축소
	-- TODO: 실제 히트박스 변경 (CharacterMesh 또는 Accessory 처리 필요)

	print("[PlayerController] Slide started")

	-- 자동 해제 타이머
	task.delay(GameConstants.PHYSICS.SLIDE_DURATION, function()
		if self.isSliding then
			self:_endSlide()
		end
	end)
end

-- 슬라이드 업데이트
function PlayerController:_updateSlide(deltaTime: number)
	-- 슬라이드 중 추가 로직 (예: 애니메이션 재생)
end

-- 슬라이드 종료
function PlayerController:_endSlide()
	self.isSliding = false
	self.state = "Running"

	-- 서버에 슬라이딩 종료 전달
	self.humanoidRootPart:SetAttribute("IsSliding", false)

	-- 히트박스 복구
	-- TODO: 실제 히트박스 복구

	print("[PlayerController] Slide ended")
end

-- 정리
function PlayerController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	if self.alignPosition then
		self.alignPosition:Destroy()
	end
end

return PlayerController

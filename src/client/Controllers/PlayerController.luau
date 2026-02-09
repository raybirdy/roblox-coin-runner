--!strict
-- Player Controller
-- 플레이어 캐릭터 이동 및 물리 제어
-- 물리 엔진과 협력하는 방식으로 구현

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local PlayerController = {}
PlayerController.__index = PlayerController

type State = "Idle" | "Running" | "Jumping" | "Sliding" | "Falling"

-- 상수
local GROUND_RAYCAST_DISTANCE = 3.5 -- 바닥 감지 레이캐스트 거리
local GROUND_HEIGHT = 2.5 -- 캐릭터 중심 높이 (바닥에 서 있을 때)

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
		speedMultiplier: number, -- 튜토리얼 슬로모션용
		gameStartTime: number,

		-- 점프
		verticalVelocity: number,

		-- Z축 고정
		alignPosition: AlignPosition?,

		-- 연결
		_connections: { RBXScriptConnection },
		_gameConnection: RBXScriptConnection?, -- Heartbeat 게임 루프 연결

		-- 디버그
		_lastJumpTime: number,
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
		speedMultiplier = 1.0, -- 기본 속도
		gameStartTime = 0,

		verticalVelocity = 0,

		alignPosition = nil,

		_connections = {},
		_gameConnection = nil,

		_lastJumpTime = 0,
	}, PlayerController)

	self:_setupZAxisConstraint()
	self:_setupPhysics()

	return self
end

-- 게임 시작
function PlayerController:StartGame()
	-- 이전 게임 연결이 있으면 먼저 정리
	if self._gameConnection then
		self._gameConnection:Disconnect()
		self._gameConnection = nil
		print("[PlayerController] Previous game connection disconnected")
	end

	-- 모든 상태 초기화
	self.gameStartTime = tick()
	self.currentSpeed = GameConstants.PHYSICS.SPEED_MIN
	self.speedMultiplier = 1.0
	self.state = "Running"
	self.isGrounded = true
	self.canDoubleJump = false
	self.isSliding = false
	self.verticalVelocity = 0
	self._lastJumpTime = 0

	-- 속도 초기화
	self.humanoidRootPart.AssemblyLinearVelocity = Vector3.zero

	-- RunService 루프 시작
	self._gameConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		self:_update(deltaTime)
	end)

	print(`[PlayerController] Game started for {self.player.Name}`)
end

-- 게임 종료
function PlayerController:StopGame()
	-- 게임 루프 연결 해제 (먼저!)
	if self._gameConnection then
		self._gameConnection:Disconnect()
		self._gameConnection = nil
		print("[PlayerController] Game connection disconnected")
	end

	-- 상태 초기화
	self.state = "Idle"
	self.currentSpeed = 0
	self.isSliding = false
	self.canDoubleJump = false
	self.verticalVelocity = 0

	-- 속도 정지
	self.humanoidRootPart.AssemblyLinearVelocity = Vector3.zero

	print(`[PlayerController] Game stopped for {self.player.Name}`)
end

-- 속도 배율 설정 (튜토리얼 슬로모션용)
function PlayerController:SetSpeedMultiplier(multiplier: number)
	self.speedMultiplier = multiplier
	print(`[PlayerController] Speed multiplier set to {multiplier * 100}%`)
end

-- 캐릭터 업데이트 (리스폰 시 호출)
function PlayerController:UpdateCharacter(newCharacter: Model)
	-- 기존 연결 정리
	self:StopGame()

	-- 새 캐릭터 참조 업데이트
	self.character = newCharacter
	self.humanoidRootPart = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	self.humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid

	-- 영구 연결 정리 (Z축 고정 등)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	if self.alignPosition then
		self.alignPosition:Destroy()
		self.alignPosition = nil
	end

	-- 물리 및 제약 조건 재설정
	self:_setupZAxisConstraint()
	self:_setupPhysics()

	print("[PlayerController] Character updated after respawn")
end

-- Z축 고정 설정 (2D 평면 유지) - AlignPosition 대신 직접 제어
function PlayerController:_setupZAxisConstraint()
	-- Attachment 생성 (회전 고정용)
	local attachment = Instance.new("Attachment")
	attachment.Name = "ZAxisAttachment"
	attachment.Parent = self.humanoidRootPart

	-- AlignPosition 제거 - Y축에도 힘을 가해서 캐릭터가 떠오르는 문제 발생
	-- 대신 _moveForward()에서 Z축 속도를 0으로 유지하고, 필요시 위치 보정

	self.alignPosition = nil

	print("[PlayerController] Z-axis constraint set up (velocity-based)")
end

-- 물리 설정
function PlayerController:_setupPhysics()
	-- Humanoid 설정
	self.humanoid.WalkSpeed = 0 -- 자동 전진을 사용하므로 걷기 비활성화
	self.humanoid.JumpPower = 0 -- 커스텀 점프 사용
	self.humanoid.AutoRotate = false -- 회전 고정 (오른쪽 보기)

	-- 회전 고정 (오른쪽을 향하기) - AlignOrientation 사용
	local attachment = self.humanoidRootPart:FindFirstChild("ZAxisAttachment")
	if attachment then
		local alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Name = "RotationLock"
		alignOrientation.Attachment0 = attachment
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.MaxTorque = 100000
		alignOrientation.Responsiveness = 200
		alignOrientation.CFrame = CFrame.Angles(0, math.rad(-90), 0) -- 오른쪽 바라보기
		alignOrientation.Parent = self.humanoidRootPart
	end

	-- 초기 회전 설정
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

	-- 바닥 감지 (Raycast)
	self:_checkGrounded()

	-- 전진 이동 (AssemblyLinearVelocity 사용)
	self:_moveForward()

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

-- 전진 이동 (AssemblyLinearVelocity 사용)
function PlayerController:_moveForward()
	local targetSpeedX = self.currentSpeed * self.speedMultiplier

	-- 현재 Y 속도 유지 (중력/점프), X 설정, Z는 0으로 고정
	local currentVel = self.humanoidRootPart.AssemblyLinearVelocity
	self.humanoidRootPart.AssemblyLinearVelocity = Vector3.new(targetSpeedX, currentVel.Y, 0)

	-- Z축 위치 보정 (드리프트 방지)
	local pos = self.humanoidRootPart.Position
	local targetZ = GameConstants.PLAYER.Z_POSITION
	if math.abs(pos.Z - targetZ) > 0.1 then
		self.humanoidRootPart.CFrame = CFrame.new(pos.X, pos.Y, targetZ)
			* CFrame.Angles(0, math.rad(-90), 0)
	end
end

-- 바닥 감지 (Raycast 사용)
function PlayerController:_checkGrounded()
	local rayOrigin = self.humanoidRootPart.Position
	local rayDirection = Vector3.new(0, -GROUND_RAYCAST_DISTANCE, 0)

	-- 자기 자신 제외
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { self.character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	local wasGrounded = self.isGrounded
	local currentY = self.humanoidRootPart.Position.Y
	local currentVelY = self.humanoidRootPart.AssemblyLinearVelocity.Y

	-- 바닥 감지: Raycast 히트 또는 Y 위치가 충분히 낮음
	-- Y 속도 조건 완화: 위로 강하게 올라가는 중이 아니면 바닥 판정
	if result then
		-- Raycast로 바닥 감지 (거리 3.0 이하이고 위로 빠르게 올라가지 않으면)
		local distanceToGround = result.Distance
		self.isGrounded = distanceToGround < 3.0 and currentVelY < 5.0
	else
		-- Raycast 실패 시 Y 위치로 판정 (조건 완화)
		self.isGrounded = currentY <= GROUND_HEIGHT + 1.0 and currentVelY < 5.0
	end

	-- 착지 시
	if self.isGrounded and not wasGrounded then
		if self.state == "Jumping" or self.state == "Falling" then
			self.state = "Running"
			self.canDoubleJump = false
			-- Y 속도 리셋 (착지 시 바운스 방지)
			local vel = self.humanoidRootPart.AssemblyLinearVelocity
			self.humanoidRootPart.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
			print(`[PlayerController] Landed - Y: {currentY}`)
		end
	end

	-- 공중으로 떨어졌을 때 (점프가 아닌 자연 낙하)
	if not self.isGrounded and wasGrounded and self.state == "Running" then
		self.state = "Falling"
		self.canDoubleJump = true -- 낙하 시에도 더블 점프 허용
		print(`[PlayerController] Airborne - Y: {currentY}`)
	end
end

-- 점프
function PlayerController:Jump()
	-- 게임이 시작되지 않았으면 무시
	if self.state == "Idle" then
		return
	end

	-- 슬라이드 중에는 점프 불가
	if self.isSliding then
		print("[PlayerController] Cannot jump while sliding")
		return
	end

	-- 점프 쿨다운 (연타 방지) - 0.1초로 단축
	local now = tick()
	if now - self._lastJumpTime < 0.1 then
		return
	end

	-- 1단 점프 (바닥에 있을 때)
	if self.isGrounded then
		self:_performJump(GameConstants.PHYSICS.JUMP_HEIGHT_FIRST)
		self.canDoubleJump = true
		self._lastJumpTime = now
		print(`[PlayerController] First jump - Y: {self.humanoidRootPart.Position.Y}`)
		return
	end

	-- 2단 점프 (공중에서)
	if self.canDoubleJump then
		self:_performJump(GameConstants.PHYSICS.JUMP_HEIGHT_SECOND)
		self.canDoubleJump = false
		self._lastJumpTime = now
		print(`[PlayerController] Second jump - Y: {self.humanoidRootPart.Position.Y}`)
		return
	end

	-- 점프 불가 상태 (로그 빈도 줄이기)
	-- print(`[PlayerController] Cannot jump - Grounded: {self.isGrounded}, CanDoubleJump: {self.canDoubleJump}, State: {self.state}`)
end

-- 점프 실행 (AssemblyLinearVelocity 사용)
function PlayerController:_performJump(jumpHeight: number)
	self.state = "Jumping"
	self.isGrounded = false

	-- 점프 초기 속도 계산 (v = sqrt(2 * g * h))
	local gravity = GameConstants.PHYSICS.GRAVITY
	local jumpVelocity = math.sqrt(2 * gravity * jumpHeight)

	-- AssemblyLinearVelocity로 점프 (X 속도 유지, Y 설정)
	local currentVel = self.humanoidRootPart.AssemblyLinearVelocity
	self.humanoidRootPart.AssemblyLinearVelocity = Vector3.new(currentVel.X, jumpVelocity, 0)

	print(`[PlayerController] Jump velocity: {jumpVelocity}`)
end

-- 슬라이드
function PlayerController:Slide()
	-- 게임이 시작되지 않았으면 무시
	if self.state == "Idle" then
		return
	end

	-- 이미 슬라이드 중이면 무시
	if self.isSliding then
		print("[PlayerController] Already sliding")
		return
	end

	-- 공중에서는 슬라이드 불가
	if not self.isGrounded then
		print("[PlayerController] Cannot slide while airborne")
		return
	end

	self.isSliding = true
	self.state = "Sliding"

	-- 서버에 슬라이딩 상태 전달 (Attribute 사용)
	self.humanoidRootPart:SetAttribute("IsSliding", true)

	-- 히트박스 축소 (간단한 구현: 캐릭터 스케일 축소)
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
	-- 슬라이드 중 바닥을 벗어나면 즉시 종료
	if not self.isGrounded then
		self:_endSlide()
		self.state = "Falling"
	end
end

-- 슬라이드 종료
function PlayerController:_endSlide()
	if not self.isSliding then
		return
	end

	self.isSliding = false

	-- 바닥에 있으면 Running, 아니면 Falling
	if self.isGrounded then
		self.state = "Running"
	else
		self.state = "Falling"
	end

	-- 서버에 슬라이딩 종료 전달
	self.humanoidRootPart:SetAttribute("IsSliding", false)

	-- 히트박스 복구
	-- TODO: 실제 히트박스 복구

	print("[PlayerController] Slide ended")
end

-- 정리
function PlayerController:Destroy()
	-- 게임 루프 연결 해제
	if self._gameConnection then
		self._gameConnection:Disconnect()
		self._gameConnection = nil
	end

	-- 영구 연결 (Z축 고정 등) 해제
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	if self.alignPosition then
		self.alignPosition:Destroy()
	end
end

return PlayerController

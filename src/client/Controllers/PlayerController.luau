--!strict
-- Player Controller
-- 플레이어 캐릭터 이동 및 물리 제어
-- 물리 엔진과 협력하는 방식으로 구현

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local AnimationController = require(script.Parent.AnimationController)

-- 전역 연결 관리 (Rojo 업데이트 시 중복 방지)
local _globalGameConnection: RBXScriptConnection? = nil
local _lastUpdateTime: number = 0 -- 프레임당 한 번만 업데이트

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

		-- 속도 제어
		_linearVelocity: LinearVelocity?,

		-- 애니메이션
		_animationController: AnimationController.AnimationController?,

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

		_linearVelocity = nil,

		_animationController = nil,

		_connections = {},
		_gameConnection = nil,

		_lastJumpTime = 0,
	}, PlayerController)

	self:_setupZAxisConstraint()
	self:_setupPhysics()
	self:_setupLinearVelocity()
	self:_setupAnimations()

	return self
end

-- 애니메이션 설정
function PlayerController:_setupAnimations()
	self._animationController = AnimationController.new(self.humanoid)
	print("[PlayerController] Animation controller initialized")
end

-- 게임 시작
function PlayerController:StartGame()
	-- 이전 게임 연결 완전 정리 (중복 방지)
	self:_cleanupGameConnection()

	-- 전역 시간 초기화 (중복 업데이트 방지)
	_lastUpdateTime = 0

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

	-- 속도 완전 초기화
	self.humanoidRootPart.AssemblyLinearVelocity = Vector3.zero

	-- RunService 루프 시작 (전역 연결 사용 - 중복 방지)
	local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		self:_update(deltaTime)
	end)

	-- 전역과 인스턴스 모두에 저장
	_globalGameConnection = connection
	self._gameConnection = connection

	-- 달리기 애니메이션 시작
	if self._animationController then
		self._animationController:PlayRun()
	end

	print(`[PlayerController] Game started for {self.player.Name} - Speed: {self.currentSpeed}`)
end

-- 게임 연결 정리 (중복 호출 방지)
function PlayerController:_cleanupGameConnection()
	-- 전역 연결 해제 (Rojo 업데이트 시에도 확실히 해제)
	if _globalGameConnection then
		_globalGameConnection:Disconnect()
		_globalGameConnection = nil
	end

	if self._gameConnection then
		self._gameConnection:Disconnect()
		self._gameConnection = nil
	end

	print("[PlayerController] Game connection cleaned up")
end

-- 게임 종료
function PlayerController:StopGame()
	-- 게임 루프 연결 해제 (먼저!)
	self:_cleanupGameConnection()

	-- 상태 초기화
	self.state = "Idle"
	self.currentSpeed = 0
	self.speedMultiplier = 1.0
	self.isSliding = false
	self.canDoubleJump = false
	self.verticalVelocity = 0

	-- 속도 완전 정지
	self.humanoidRootPart.AssemblyLinearVelocity = Vector3.zero

	-- 애니메이션 정지
	if self._animationController then
		self._animationController:PlayIdle()
	end

	print(`[PlayerController] Game stopped for {self.player.Name}`)
end

-- 속도 배율 설정 (튜토리얼 슬로모션용)
function PlayerController:SetSpeedMultiplier(multiplier: number)
	local oldMultiplier = self.speedMultiplier
	self.speedMultiplier = multiplier
	local effectiveSpeed = self.currentSpeed * multiplier
	print(`[PlayerController] Speed: {oldMultiplier * 100}% -> {multiplier * 100}% (effective: {math.floor(effectiveSpeed)} studs/s)`)
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

	if self._linearVelocity then
		self._linearVelocity:Destroy()
		self._linearVelocity = nil
	end

	-- 애니메이션 컨트롤러 정리
	if self._animationController then
		self._animationController:Destroy()
		self._animationController = nil
	end

	-- 물리 및 제약 조건 재설정
	self:_setupZAxisConstraint()
	self:_setupPhysics()
	self:_setupLinearVelocity()
	self:_setupAnimations()

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

-- LinearVelocity 제거 (더 이상 사용하지 않음)
function PlayerController:_setupLinearVelocity()
	-- 기존 LinearVelocity 제거
	local existingLV = self.humanoidRootPart:FindFirstChild("RunnerVelocity")
	if existingLV then
		existingLV:Destroy()
	end
	if self._linearVelocity then
		self._linearVelocity:Destroy()
		self._linearVelocity = nil
	end

	-- 이제 CFrame + AssemblyLinearVelocity 하이브리드 방식 사용
	print("[PlayerController] Using CFrame hybrid movement")
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
	-- 프레임당 한 번만 업데이트 (중복 연결 방지)
	local now = tick()
	if now - _lastUpdateTime < 0.001 then
		return -- 너무 빠른 업데이트는 무시 (1ms 이내)
	end
	_lastUpdateTime = now

	if self.state == "Idle" then
		return
	end

	-- 속도 업데이트 (시간에 따라 증가)
	self:_updateSpeed()

	-- 바닥 감지 (Raycast)
	self:_checkGrounded()

	-- 전진 이동 (CFrame으로 X축 직접 이동)
	self:_moveForward(deltaTime)

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

-- 전진 이동 (CFrame으로 X축 직접 이동)
function PlayerController:_moveForward(deltaTime: number)
	local targetSpeedX = self.currentSpeed * self.speedMultiplier

	-- 속도 상한선 (버그 방지)
	local maxSpeed = GameConstants.PHYSICS.SPEED_MAX
	targetSpeedX = math.min(targetSpeedX, maxSpeed)

	-- 이동 거리 계산
	local moveDistance = targetSpeedX * deltaTime

	-- 현재 위치
	local pos = self.humanoidRootPart.Position
	local newX = pos.X + moveDistance

	-- X축 이동, Y는 현재 위치 유지 (물리 엔진이 처리), Z는 고정
	self.humanoidRootPart.CFrame = CFrame.new(newX, pos.Y, GameConstants.PLAYER.Z_POSITION)
		* CFrame.Angles(0, math.rad(-90), 0)
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

			-- 달리기 애니메이션 재생
			if self._animationController then
				self._animationController:PlayRun()
			end

			print(`[PlayerController] Landed - Y: {currentY}`)
		end
	end

	-- 공중으로 떨어졌을 때 (점프가 아닌 자연 낙하)
	if not self.isGrounded and wasGrounded and self.state == "Running" then
		self.state = "Falling"
		self.canDoubleJump = true -- 낙하 시에도 더블 점프 허용

		-- 낙하 애니메이션 재생
		if self._animationController then
			self._animationController:PlayFall()
		end

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

	-- 점프 애니메이션 재생
	if self._animationController then
		self._animationController:PlayJump()
	end

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

	-- 슬라이드 애니메이션 재생
	if self._animationController then
		self._animationController:PlaySlide()
	end

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

		-- 낙하 애니메이션 재생
		if self._animationController then
			self._animationController:PlayFall()
		end
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

		-- 달리기 애니메이션 재생
		if self._animationController then
			self._animationController:PlayRun()
		end
	else
		self.state = "Falling"

		-- 낙하 애니메이션 재생
		if self._animationController then
			self._animationController:PlayFall()
		end
	end

	-- 서버에 슬라이딩 종료 전달
	self.humanoidRootPart:SetAttribute("IsSliding", false)

	print("[PlayerController] Slide ended")
end

-- 정리
function PlayerController:Destroy()
	-- 게임 루프 연결 해제
	self:_cleanupGameConnection()

	-- 영구 연결 (Z축 고정 등) 해제
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	if self.alignPosition then
		self.alignPosition:Destroy()
	end

	if self._linearVelocity then
		self._linearVelocity:Destroy()
	end

	-- 애니메이션 컨트롤러 정리
	if self._animationController then
		self._animationController:Destroy()
		self._animationController = nil
	end
end

return PlayerController

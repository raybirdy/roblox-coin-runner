--!strict
-- Camera Controller
-- 카메라 위치 및 시각 효과 관리

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CameraController = {}
CameraController.__index = CameraController

export type CameraController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_camera: Camera,
		_character: Model,
		_humanoidRootPart: BasePart?,
		_connections: { RBXScriptConnection },
		_cameraOffset: Vector3,
		_targetCFrame: CFrame,
		_shakeIntensity: number,
		_shakeDecay: number,
		_isGameMode: boolean, -- 게임 모드 여부 (true = 사이드뷰, false = 기본 카메라)
		_cameraDistance: number, -- 적응형 카메라 거리
	},
	CameraController
))

-- 사이드뷰 카메라 설정
local BASE_SIDE_DISTANCE = 40 -- 기준 카메라 Z축 거리 (1920px 기준)
local MIN_SIDE_DISTANCE = 32
local MAX_SIDE_DISTANCE = 45
local CAMERA_HEIGHT = 12 -- 카메라 높이
local LOOK_AHEAD = 20 -- 캐릭터를 화면 왼쪽 ~30%에 배치하기 위한 X 오프셋
local LOOK_HEIGHT = 5 -- 시선 기준 높이
local CAMERA_SMOOTHNESS = 0.15 -- 카메라 부드러움 (0~1, 낮을수록 부드러움)

-- viewport 기반 적응형 카메라 거리 계산
local function calculateAdaptiveDistance(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return BASE_SIDE_DISTANCE
	end
	local viewportX = camera.ViewportSize.X
	local ratio = viewportX / 1920
	return math.clamp(BASE_SIDE_DISTANCE * ratio, MIN_SIDE_DISTANCE, MAX_SIDE_DISTANCE)
end

function CameraController.new(player: Player, character: Model): CameraController
	local self = setmetatable({
		_player = player,
		_camera = Workspace.CurrentCamera,
		_character = character,
		_humanoidRootPart = nil,
		_connections = {},
		_cameraOffset = Vector3.new(0, 0, 0),
		_targetCFrame = CFrame.new(),
		_shakeIntensity = 0,
		_shakeDecay = 0.95,
		_isGameMode = false, -- 시작 시 로비 모드 (기본 카메라)
		_cameraDistance = calculateAdaptiveDistance(),
	}, CameraController)

	self:_initialize()

	return self
end

-- 초기화
function CameraController:_initialize()
	-- HumanoidRootPart 가져오기
	self._humanoidRootPart = self._character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not self._humanoidRootPart then
		warn("[CameraController] HumanoidRootPart not found")
		return
	end

	-- 로비 모드로 시작 (기본 카메라)
	self:SetLobbyMode()

	-- 업데이트 루프
	local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		-- 게임 모드일 때만 커스텀 카메라 업데이트
		if self._isGameMode then
			self:_updateCamera(deltaTime)
		end
	end)
	table.insert(self._connections, connection)

	-- ViewportSize 변경 시 카메라 거리 재계산
	local camera = Workspace.CurrentCamera
	if camera then
		local viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self._cameraDistance = calculateAdaptiveDistance()
		end)
		table.insert(self._connections, viewportConn)
	end

	-- 카메라 흔들림 이벤트 설정
	self:_setupCameraShakeEvent()

	print("[CameraController] Camera initialized")
end

-- 로비 모드 (기본 Roblox 카메라)
function CameraController:SetLobbyMode()
	self._isGameMode = false
	self._camera.CameraType = Enum.CameraType.Custom

	-- 현재 캐릭터의 Humanoid를 CameraSubject로 설정
	local currentCharacter = self._player.Character
	if currentCharacter then
		local humanoid = currentCharacter:FindFirstChild("Humanoid")
		if humanoid then
			self._camera.CameraSubject = humanoid
		end
	end

	print("[CameraController] Switched to lobby mode (default camera)")
end

-- 게임 모드 (사이드뷰 카메라)
function CameraController:SetGameMode()
	self._isGameMode = true
	self._camera.CameraType = Enum.CameraType.Scriptable

	-- 카메라 거리 재계산
	self._cameraDistance = calculateAdaptiveDistance()

	-- 초기 카메라 위치 설정
	self._targetCFrame = self:_calculateCameraPosition()
	self._camera.CFrame = self._targetCFrame

	print("[CameraController] Switched to game mode (side-view camera)")
end

-- 카메라 흔들림 이벤트 설정
function CameraController:_setupCameraShakeEvent()
	-- BindableEvent 생성 또는 가져오기
	local cameraShakeEvent = ReplicatedStorage:FindFirstChild("CameraShake")
	if not cameraShakeEvent then
		cameraShakeEvent = Instance.new("BindableEvent")
		cameraShakeEvent.Name = "CameraShake"
		cameraShakeEvent.Parent = ReplicatedStorage
	end

	-- 이벤트 연결
	local connection = (cameraShakeEvent :: BindableEvent).Event:Connect(function(intensity: number)
		self:Shake(intensity)
	end)
	table.insert(self._connections, connection)
end

-- 카메라 위치 계산 (사이드뷰)
function CameraController:_calculateCameraPosition(): CFrame
	if not self._humanoidRootPart then
		return CFrame.new()
	end

	local characterPosition = self._humanoidRootPart.Position

	-- 사이드뷰: 카메라를 Z축 양방향(+Z)에 배치, 캐릭터 앞쪽을 더 보여줌
	local cameraPosition = Vector3.new(characterPosition.X + LOOK_AHEAD, CAMERA_HEIGHT, self._cameraDistance)
		+ self._cameraOffset

	-- 캐릭터 평면(Z=0)을 바라봄
	local lookAtPosition = Vector3.new(characterPosition.X + LOOK_AHEAD, LOOK_HEIGHT, 0)

	return CFrame.lookAt(cameraPosition, lookAtPosition)
end

-- 카메라 업데이트 (매 프레임)
function CameraController:_updateCamera(deltaTime: number)
	if not self._humanoidRootPart then
		return
	end

	-- 목표 카메라 위치 계산
	local targetCFrame = self:_calculateCameraPosition()

	-- 부드러운 보간 (deltaTime 기반으로 프레임레이트 독립적)
	local factor = 1 - math.pow(1 - CAMERA_SMOOTHNESS, deltaTime * 60)
	self._targetCFrame = self._targetCFrame:Lerp(targetCFrame, factor)

	-- 화면 흔들림 적용
	local shakeCFrame = CFrame.new()
	if self._shakeIntensity > 0.01 then
		local shakeX = (math.random() - 0.5) * self._shakeIntensity
		local shakeY = (math.random() - 0.5) * self._shakeIntensity
		shakeCFrame = CFrame.new(shakeX, shakeY, 0)

		-- 흔들림 감쇠
		self._shakeIntensity *= self._shakeDecay
	else
		self._shakeIntensity = 0
	end

	-- 최종 카메라 적용
	self._camera.CFrame = self._targetCFrame * shakeCFrame
end

-- 화면 흔들림 트리거
function CameraController:Shake(intensity: number)
	self._shakeIntensity = math.max(self._shakeIntensity, intensity)
end

-- 카메라 줌 (일시적)
function CameraController:Zoom(amount: number, duration: number)
	local originalDistance = self._cameraDistance
	self._cameraDistance += amount

	task.delay(duration, function()
		self._cameraDistance = originalDistance
	end)
end

-- 캐릭터 업데이트 (리스폰 시 호출)
function CameraController:UpdateCharacter(newCharacter: Model)
	self._character = newCharacter
	self._humanoidRootPart = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart?

	if self._humanoidRootPart then
		-- 카메라 위치 즉시 업데이트
		self._targetCFrame = self:_calculateCameraPosition()
		self._camera.CFrame = self._targetCFrame
		print("[CameraController] Character updated after respawn")
	end
end

-- 정리
function CameraController:Destroy()
	-- 카메라 타입 복구
	self._camera.CameraType = Enum.CameraType.Custom

	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return CameraController

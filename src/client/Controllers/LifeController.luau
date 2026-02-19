--!strict
-- Life Controller
-- 라이프 업데이트 및 피드백 처리

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local LifeController = {}
LifeController.__index = LifeController

export type LifeController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_currentLives: number,
		_damageGui: ScreenGui?,
		_damageFrame: Frame?,
		_damageSound: Sound?,
	},
	LifeController
))

function LifeController.new(): LifeController
	local self = setmetatable({
		_connections = {},
		_currentLives = GameConstants.LIFE.STARTING_LIVES,
		_damageGui = nil,
		_damageFrame = nil,
		_damageSound = nil,
	}, LifeController)

	self:_setupEventHandlers()
	self:_createDamageEffects()

	return self
end

-- 피격 이펙트 UI 생성
function LifeController:_createDamageEffects()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- 빨간 화면 플래시 GUI
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DamageGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	self._damageGui = screenGui

	-- 빨간 프레임 (비네트 효과)
	local damageFrame = Instance.new("Frame")
	damageFrame.Name = "DamageFrame"
	damageFrame.Size = UDim2.new(1, 0, 1, 0)
	damageFrame.Position = UDim2.new(0, 0, 0, 0)
	damageFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	damageFrame.BackgroundTransparency = 1 -- 처음엔 투명
	damageFrame.BorderSizePixel = 0
	damageFrame.Parent = screenGui
	self._damageFrame = damageFrame

	-- 피격 사운드
	local sound = Instance.new("Sound")
	sound.Name = "DamageSound"
	sound.SoundId = "rbxassetid://138446295" -- 피격 사운드 (임시)
	sound.Volume = 0.7
	sound.Parent = SoundService
	self._damageSound = sound
end

-- 피격 이펙트 재생
function LifeController:_playDamageEffect()
	-- 빨간 화면 플래시
	if self._damageFrame then
		-- Phase 2: Enhanced vignette damage effect
		self._damageFrame.BackgroundTransparency = 0.4

		local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(self._damageFrame, tweenInfo, {
			BackgroundTransparency = 1,
		})
		tween:Play()
	end

	-- 피격 사운드
	if self._damageSound then
		self._damageSound:Play()
	end
end

-- 라이프 업데이트 이벤트 처리
function LifeController:_setupEventHandlers()
	local connection = RemoteEvents.LifeUpdate.OnClientEvent:Connect(function(data)
		self:OnLifeUpdate(data)
	end)

	table.insert(self._connections, connection)
end

-- 라이프 변경 시 호출
function LifeController:OnLifeUpdate(data: { lives: number })
	local previousLives = self._currentLives
	self._currentLives = data.lives

	-- 라이프 감소 피드백
	if data.lives < previousLives then
		print(`[LifeController] Lost a life! Remaining lives: {data.lives}`)

		-- 피격 이펙트 재생
		self:_playDamageEffect()

		-- Phase 2: Haptic feedback for damage
		pcall(function()
			local HapticService = game:GetService("HapticService")
			if HapticService:IsVibrationSupported(Enum.UserInputType.Gamepad1) then
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0.8)
				task.delay(0.3, function()
					pcall(function()
						HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Large, 0)
					end)
				end)
			end
		end)

		-- 화면 흔들림 트리거 (CameraController에 알림)
		local cameraShakeEvent = ReplicatedStorage:FindFirstChild("CameraShake")
		if cameraShakeEvent and cameraShakeEvent:IsA("BindableEvent") then
			cameraShakeEvent:Fire(1.0) -- 강한 흔들림
		end
	end

	-- 라이프 0 경고
	if data.lives == 0 then
		print("[LifeController] No lives left! Game Over imminent...")
	end
end

-- 현재 라이프 반환
function LifeController:GetCurrentLives(): number
	return self._currentLives
end

-- 정리
function LifeController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	if self._damageGui then
		self._damageGui:Destroy()
	end
	if self._damageSound then
		self._damageSound:Destroy()
	end
end

return LifeController

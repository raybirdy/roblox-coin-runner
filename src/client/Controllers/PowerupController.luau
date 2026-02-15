--!strict
-- Powerup Controller
-- 파워업 수집 피드백 처리 (UI 표시, 사운드, 이펙트)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local PowerupController = {}
PowerupController.__index = PowerupController

export type PowerupController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_activePowerups: { [string]: boolean },
		_powerupGui: ScreenGui?,
		_powerupContainer: Frame?,
		_powerupIcons: { [string]: Frame },
		_powerupSound: Sound?,
	},
	PowerupController
))

function PowerupController.new(): PowerupController
	local self = setmetatable({
		_connections = {},
		_activePowerups = {},
		_powerupGui = nil,
		_powerupContainer = nil,
		_powerupIcons = {},
		_powerupSound = nil,
	}, PowerupController)

	self:_createPowerupUI()
	self:_createPowerupSound()
	self:_setupEventHandlers()

	return self
end

-- 파워업 UI 생성 (활성 파워업 아이콘 표시)
function PowerupController:_createPowerupUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- 파워업 전용 ScreenGui
	local powerupGui = Instance.new("ScreenGui")
	powerupGui.Name = "PowerupUI"
	powerupGui.ResetOnSpawn = false
	powerupGui.Parent = playerGui
	self._powerupGui = powerupGui

	-- 파워업 아이콘 컨테이너 (화면 왼쪽 중앙)
	local container = Instance.new("Frame")
	container.Name = "PowerupContainer"
	container.Size = UDim2.new(0, 80, 0, 300)
	container.Position = UDim2.new(0, 10, 0.5, -140)
	container.BackgroundTransparency = 1
	container.Parent = powerupGui
	self._powerupContainer = container

	-- UIListLayout으로 아이콘 정렬
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = container

	print("[PowerupController] Powerup UI created")
end

-- 파워업 사운드 생성
function PowerupController:_createPowerupSound()
	local sound = Instance.new("Sound")
	sound.Name = "PowerupSound"
	sound.SoundId = "rbxassetid://138446295" -- 파워업 사운드
	sound.Volume = 0.6
	sound.Parent = SoundService
	self._powerupSound = sound
end

-- 파워업 아이콘 표시
function PowerupController:_showPowerupIcon(powerupType: string, duration: number)
	if not self._powerupContainer then
		return
	end

	-- 아이콘 설정
	local iconData = {
		Magnet = { emoji = "🧲", color = Color3.fromRGB(50, 150, 255), name = "자석" },
		Shield = { emoji = "🛡️", color = Color3.fromRGB(50, 200, 50), name = "쉴드" },
		Invincible = { emoji = "⭐", color = Color3.fromRGB(255, 215, 0), name = "무적" },
		DoubleCoin = { emoji = "💰", color = Color3.fromRGB(255, 165, 0), name = "2배" },
	}

	local config = iconData[powerupType]
	if not config then
		return
	end

	-- 기존 아이콘이 있으면 제거
	if self._powerupIcons[powerupType] then
		self._powerupIcons[powerupType]:Destroy()
		self._powerupIcons[powerupType] = nil
	end

	-- 아이콘 프레임 생성
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = `PowerupIcon_{powerupType}`
	iconFrame.Size = UDim2.new(0, 70, 0, 70)
	iconFrame.BackgroundColor3 = config.color
	iconFrame.BackgroundTransparency = 0.2
	iconFrame.Parent = self._powerupContainer

	-- 둥근 모서리
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = iconFrame

	-- 테두리
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Parent = iconFrame

	-- 이모지
	local emoji = Instance.new("TextLabel")
	emoji.Name = "Emoji"
	emoji.Size = UDim2.new(1, 0, 0.7, 0)
	emoji.BackgroundTransparency = 1
	emoji.Text = config.emoji
	emoji.TextSize = 36
	emoji.Parent = iconFrame

	-- 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.7, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = config.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = iconFrame

	-- 저장
	self._powerupIcons[powerupType] = iconFrame

	-- 등장 애니메이션
	iconFrame.Size = UDim2.new(0, 0, 0, 0)
	local appearTween =
		TweenService:Create(iconFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 70, 0, 70),
		})
	appearTween:Play()

	-- 지속 시간 후 제거
	task.delay(duration, function()
		if iconFrame and iconFrame.Parent then
			-- 사라지는 애니메이션
			local disappearTween =
				TweenService:Create(iconFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = UDim2.new(0, 0, 0, 0),
					BackgroundTransparency = 1,
				})
			disappearTween:Play()
			disappearTween.Completed:Connect(function()
				iconFrame:Destroy()
				self._powerupIcons[powerupType] = nil
			end)
		end
	end)

	print(`[PowerupController] Showing {powerupType} icon for {duration}s`)
end

-- 파워업 수집 이벤트 처리
function PowerupController:_setupEventHandlers()
	local connection = RemoteEvents.PowerupCollected.OnClientEvent:Connect(function(data)
		self:OnPowerupCollected(data)
	end)

	table.insert(self._connections, connection)
end

-- 파워업 수집 시 호출
function PowerupController:OnPowerupCollected(data: { powerupType: string })
	local powerupType = data.powerupType

	-- 사운드 재생
	if self._powerupSound and powerupType ~= "ShieldUsed" then
		self._powerupSound:Play()
	end

	-- 파티클 효과 재생
	if powerupType ~= "ShieldUsed" then
		self:_playPowerupParticle(powerupType)
	end

	if powerupType == "Magnet" then
		print(`[PowerupController] Magnet activated! (Duration: {GameConstants.POWERUP.MAGNET_DURATION}s)`)
		self._activePowerups["Magnet"] = true
		self:_showPowerupIcon("Magnet", GameConstants.POWERUP.MAGNET_DURATION)

		task.delay(GameConstants.POWERUP.MAGNET_DURATION, function()
			self._activePowerups["Magnet"] = false
			print("[PowerupController] Magnet expired")
		end)
	elseif powerupType == "Shield" then
		print(`[PowerupController] Shield activated! (Uses: {GameConstants.POWERUP.SHIELD_USES})`)
		self._activePowerups["Shield"] = true
		self:_showPowerupIcon("Shield", 60) -- 쉴드는 사용할 때까지 표시
	elseif powerupType == "Invincible" then
		print(`[PowerupController] Invincible activated! (Duration: {GameConstants.POWERUP.INVINCIBLE_DURATION}s)`)
		self._activePowerups["Invincible"] = true
		self:_showPowerupIcon("Invincible", GameConstants.POWERUP.INVINCIBLE_DURATION)

		task.delay(GameConstants.POWERUP.INVINCIBLE_DURATION, function()
			self._activePowerups["Invincible"] = false
			print("[PowerupController] Invincible expired")
		end)
	elseif powerupType == "DoubleCoin" then
		print(`[PowerupController] DoubleCoin activated! (Duration: {GameConstants.POWERUP.DOUBLE_COIN_DURATION}s)`)
		self._activePowerups["DoubleCoin"] = true
		self:_showPowerupIcon("DoubleCoin", GameConstants.POWERUP.DOUBLE_COIN_DURATION)

		task.delay(GameConstants.POWERUP.DOUBLE_COIN_DURATION, function()
			self._activePowerups["DoubleCoin"] = false
			print("[PowerupController] DoubleCoin expired")
		end)
	elseif powerupType == "ShieldUsed" then
		print("[PowerupController] Shield blocked an obstacle!")
		self._activePowerups["Shield"] = false
		self:_playShieldBreakParticle()

		-- 쉴드 아이콘 제거
		if self._powerupIcons["Shield"] then
			self._powerupIcons["Shield"]:Destroy()
			self._powerupIcons["Shield"] = nil
		end
	end
end

-- 파워업 획득 파티클 효과
function PowerupController:_playPowerupParticle(powerupType: string)
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	-- 파워업별 색상 설정
	local colorData = {
		Magnet = Color3.fromRGB(50, 150, 255),
		Shield = Color3.fromRGB(50, 200, 50),
		Invincible = Color3.fromRGB(255, 215, 0),
		DoubleCoin = Color3.fromRGB(255, 165, 0),
	}
	local color = colorData[powerupType] or Color3.fromRGB(255, 255, 255)

	-- 파티클 이미터 생성
	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp

	local particle = Instance.new("ParticleEmitter")
	particle.Color = ColorSequence.new(color)
	particle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 2),
		NumberSequenceKeypoint.new(1, 0),
	})
	particle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	particle.Lifetime = NumberRange.new(0.8, 1.5)
	particle.Speed = NumberRange.new(10, 25)
	particle.SpreadAngle = Vector2.new(360, 360)
	particle.Rate = 0
	particle.LightEmission = 0.5
	particle.Parent = attachment

	-- 파티클 버스트 (모바일 성능 최적화)
	particle:Emit(20)

	-- 정리
	task.delay(2, function()
		attachment:Destroy()
	end)
end

-- 쉴드 파괴 파티클 효과
function PowerupController:_playShieldBreakParticle()
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	-- 파티클 이미터 생성
	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp

	local particle = Instance.new("ParticleEmitter")
	particle.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 200, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 255, 200)),
	})
	particle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 0),
	})
	particle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	particle.Lifetime = NumberRange.new(0.3, 0.6)
	particle.Speed = NumberRange.new(20, 40)
	particle.SpreadAngle = Vector2.new(360, 360)
	particle.Rate = 0
	particle.LightEmission = 0.8
	particle.Parent = attachment

	-- 파티클 버스트 (파괴 효과, 모바일 성능 최적화)
	particle:Emit(25)

	-- 정리
	task.delay(1, function()
		attachment:Destroy()
	end)
end

-- 파워업 활성 여부 확인
function PowerupController:IsPowerupActive(powerupType: string): boolean
	return self._activePowerups[powerupType] == true
end

-- 정리
function PowerupController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
	self._activePowerups = {}

	if self._powerupGui then
		self._powerupGui:Destroy()
	end
	if self._powerupSound then
		self._powerupSound:Destroy()
	end
	self._powerupIcons = {}
end

return PowerupController

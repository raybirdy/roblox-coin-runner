--!strict
-- Coin Controller
-- 코인 수집 피드백 처리 (시각/청각 효과)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local CoinController = {}
CoinController.__index = CoinController

export type CoinController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_totalCoins: number,
		_popupGui: ScreenGui?,
		_coinSound: Sound?,
	},
	CoinController
))

function CoinController.new(): CoinController
	local self = setmetatable({
		_connections = {},
		_totalCoins = 0,
		_popupGui = nil,
		_coinSound = nil,
	}, CoinController)

	self:_setupEventHandlers()
	self:_createPopupGui()
	self:_createCoinSound()

	return self
end

-- 팝업 GUI 생성
function CoinController:_createPopupGui()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CoinPopupGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	self._popupGui = screenGui
end

-- 코인 사운드 생성
function CoinController:_createCoinSound()
	local sound = Instance.new("Sound")
	sound.Name = "CoinSound"
	sound.SoundId = "rbxassetid://138446295" -- 코인 수집 사운드
	sound.Volume = 0.5
	sound.Parent = SoundService
	self._coinSound = sound
end

-- 코인 팝업 표시 (+1, +5 등)
function CoinController:_showCoinPopup(value: number, coinType: string, isDoubled: boolean?)
	if not self._popupGui then
		return
	end

	-- 색상 설정 (코인 종류에 따라)
	local color = Color3.fromRGB(255, 215, 0) -- 기본 금색
	if coinType == "Silver" then
		color = Color3.fromRGB(192, 192, 192)
	elseif coinType == "Diamond" then
		color = Color3.fromRGB(0, 191, 255)
	end

	-- 2배 코인이면 주황색으로 강조
	if isDoubled then
		color = Color3.fromRGB(255, 140, 0)
	end

	-- 팝업 라벨 생성
	local popup = Instance.new("TextLabel")
	popup.Name = "CoinPopup"
	popup.Size = UDim2.new(0, 150, 0, 50)
	popup.Position = UDim2.new(0.5, -75, 0.4, 0)
	popup.BackgroundTransparency = 1
	popup.TextColor3 = color
	popup.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	popup.TextStrokeTransparency = 0.3
	popup.TextSize = isDoubled and 42 or 36 -- 2배일 때 더 크게
	popup.Font = Enum.Font.GothamBold
	popup.Text = isDoubled and `+{value} x2!` or `+{value}`
	popup.Parent = self._popupGui

	-- 위로 올라가면서 사라지는 애니메이션
	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(popup, tweenInfo, {
		Position = UDim2.new(0.5, -75, 0.3, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

-- 코인 수집 이벤트 처리
function CoinController:_setupEventHandlers()
	local connection = RemoteEvents.CoinCollected.OnClientEvent:Connect(function(data)
		self:OnCoinCollected(data)
	end)

	table.insert(self._connections, connection)
end

-- 코인 수집 시 호출
function CoinController:OnCoinCollected(
	data: {
		coinType: string,
		coinValue: number,
		totalCoins: number,
		isDoubled: boolean?,
	}
)
	self._totalCoins = data.totalCoins

	-- 사운드 재생
	if self._coinSound then
		self._coinSound:Play()
	end

	-- 팝업 표시 (2배 코인인 경우 특별 표시)
	self:_showCoinPopup(data.coinValue, data.coinType, data.isDoubled)

	-- 파티클 효과 재생
	self:_playCoinParticle(data.coinType, data.isDoubled)

	local doubledText = data.isDoubled and " (x2!)" or ""
	print(`[CoinController] Collected {data.coinType} coin! +{data.coinValue}{doubledText} (Total: {data.totalCoins})`)
end

-- 코인 수집 파티클 효과
function CoinController:_playCoinParticle(coinType: string, isDoubled: boolean?)
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	-- 파티클 색상 설정
	local color = Color3.fromRGB(255, 215, 0) -- 기본 금색
	if coinType == "Silver" then
		color = Color3.fromRGB(192, 192, 192)
	elseif coinType == "Diamond" then
		color = Color3.fromRGB(0, 191, 255)
	end

	-- 2배 코인이면 주황색
	if isDoubled then
		color = Color3.fromRGB(255, 140, 0)
	end

	-- 파티클 이미터 생성
	local attachment = Instance.new("Attachment")
	attachment.Parent = hrp

	local particle = Instance.new("ParticleEmitter")
	particle.Color = ColorSequence.new(color)
	particle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	particle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	particle.Lifetime = NumberRange.new(0.5, 1)
	particle.Speed = NumberRange.new(5, 15)
	particle.SpreadAngle = Vector2.new(180, 180)
	particle.Rate = 0
	particle.Acceleration = Vector3.new(0, 10, 0)
	particle.Parent = attachment

	-- 파티클 버스트
	particle:Emit(isDoubled and 30 or 15)

	-- 정리
	task.delay(1.5, function()
		attachment:Destroy()
	end)
end

-- 현재 총 코인 수 반환
function CoinController:GetTotalCoins(): number
	return self._totalCoins
end

-- 정리
function CoinController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	if self._popupGui then
		self._popupGui:Destroy()
	end
	if self._coinSound then
		self._coinSound:Destroy()
	end
end

return CoinController

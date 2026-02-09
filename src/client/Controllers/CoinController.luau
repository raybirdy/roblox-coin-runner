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
function CoinController:_showCoinPopup(value: number, coinType: string)
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

	-- 팝업 라벨 생성
	local popup = Instance.new("TextLabel")
	popup.Name = "CoinPopup"
	popup.Size = UDim2.new(0, 100, 0, 50)
	popup.Position = UDim2.new(0.5, -50, 0.4, 0)
	popup.BackgroundTransparency = 1
	popup.TextColor3 = color
	popup.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	popup.TextStrokeTransparency = 0.3
	popup.TextSize = 36
	popup.Font = Enum.Font.GothamBold
	popup.Text = `+{value}`
	popup.Parent = self._popupGui

	-- 위로 올라가면서 사라지는 애니메이션
	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(popup, tweenInfo, {
		Position = UDim2.new(0.5, -50, 0.3, 0),
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
function CoinController:OnCoinCollected(data: { coinType: string, coinValue: number, totalCoins: number })
	self._totalCoins = data.totalCoins

	-- 사운드 재생
	if self._coinSound then
		self._coinSound:Play()
	end

	-- 팝업 표시
	self:_showCoinPopup(data.coinValue, data.coinType)

	print(`[CoinController] Collected {data.coinType} coin! +{data.coinValue} (Total: {data.totalCoins})`)
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

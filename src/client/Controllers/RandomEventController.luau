--!strict
-- RandomEventController (v3)
-- Client-side random event visual effects

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local RandomEventController = {}
RandomEventController.__index = RandomEventController

function RandomEventController.new()
	local self = setmetatable({}, RandomEventController)
	self._player = Players.LocalPlayer
	self._connections = {} :: { RBXScriptConnection }
	self._gui = nil :: ScreenGui?
	self._activeEffects = {} :: { [string]: any }
	self._originalFogEnd = 10000
	return self
end

function RandomEventController:Init()
	local startConn = RemoteEvents.RandomEventStart.OnClientEvent:Connect(function(data: any)
		self:_onEventStart(data)
	end)
	table.insert(self._connections, startConn)

	local endConn = RemoteEvents.RandomEventEnd.OnClientEvent:Connect(function(data: any)
		self:_onEventEnd(data)
	end)
	table.insert(self._connections, endConn)

	self._originalFogEnd = Lighting.FogEnd

	print("[RandomEventController] Initialized")
end

function RandomEventController:_onEventStart(data: any)
	local eventId = data.eventId
	local config = data.eventConfig

	-- Create notification GUI
	self:_showEventNotification(config)

	-- Apply visual effect
	if eventId == "coin_rain" then
		-- Golden screen tint
		self:_applyColorCorrection("coin_rain", Color3.fromRGB(255, 215, 0), 0.15)
		-- Coin rain particle effect (코인 비 시각 이펙트)
		self:_startCoinRainEffect()

	elseif eventId == "speed_shift" then
		-- Motion blur effect via color correction
		self:_applyColorCorrection("speed_shift", Color3.fromRGB(100, 150, 255), 0.1)

	elseif eventId == "giant_mode" then
		-- Scale player character (3축 모두 적용: Height, Width, Depth)
		local character = self._player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
			if humanoid then
				local scale = config.scaleFactor or 1.8
				local scaleNames = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }
				for _, scaleName in scaleNames do
					local scaleValue = humanoid:FindFirstChild(scaleName) :: NumberValue?
					if scaleValue then
						self._activeEffects["original_" .. scaleName] = scaleValue.Value
						TweenService:Create(scaleValue, TweenInfo.new(0.5), { Value = scale }):Play()
					end
				end
			end
		end

	elseif eventId == "gravity_flip" then
		-- Reduce gravity
		local gravMult = config.gravityMultiplier or 0.4
		self._activeEffects["original_gravity"] = workspace.Gravity
		TweenService:Create(workspace, TweenInfo.new(0.5), {
			Gravity = 196.2 * gravMult,
		}):Play()

	elseif eventId == "fog" then
		-- Add fog
		self._activeEffects["original_fog_end"] = Lighting.FogEnd
		TweenService:Create(Lighting, TweenInfo.new(1), {
			FogEnd = config.fogEnd or 80,
			FogColor = Color3.fromRGB(180, 180, 200),
		}):Play()

	elseif eventId == "bonus_time" then
		-- Golden celebration tint + coin rain effect
		self:_applyColorCorrection("bonus_time", Color3.fromRGB(255, 230, 100), 0.2)
		self:_startCoinRainEffect()
	end

	self._activeEffects[eventId] = true
end

function RandomEventController:_onEventEnd(data: any)
	local eventId = data.eventId

	-- Revert visual effect
	if eventId == "coin_rain" or eventId == "speed_shift" then
		self:_removeColorCorrection(eventId)
		if eventId == "coin_rain" then
			self:_stopCoinRainEffect()
		end

	elseif eventId == "giant_mode" then
		-- Revert all scale axes
		local character = self._player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
			if humanoid then
				local scaleNames = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }
				for _, scaleName in scaleNames do
					local scaleValue = humanoid:FindFirstChild(scaleName) :: NumberValue?
					if scaleValue then
						local original = self._activeEffects["original_" .. scaleName] or 1.0
						TweenService:Create(scaleValue, TweenInfo.new(0.5), { Value = original }):Play()
					end
				end
			end
		end

	elseif eventId == "gravity_flip" then
		local original = self._activeEffects["original_gravity"] or 196.2
		TweenService:Create(workspace, TweenInfo.new(0.5), { Gravity = original }):Play()

	elseif eventId == "fog" then
		local originalEnd = self._activeEffects["original_fog_end"] or 10000
		TweenService:Create(Lighting, TweenInfo.new(1), {
			FogEnd = originalEnd,
			FogColor = Color3.fromRGB(192, 192, 192),
		}):Play()

	elseif eventId == "bonus_time" then
		self:_removeColorCorrection("bonus_time")
		self:_stopCoinRainEffect()
	end

	self._activeEffects[eventId] = nil

	-- Remove notification
	if self._gui then
		local notif = self._gui:FindFirstChild("EventNotification")
		if notif then
			TweenService:Create(notif, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.delay(0.3, function()
				if notif.Parent then notif:Destroy() end
			end)
		end
	end
end

function RandomEventController:_showEventNotification(config: any)
	if not self._gui then
		local gui = Instance.new("ScreenGui")
		gui.Name = "RandomEventGui"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 70
		gui.Parent = self._player.PlayerGui
		self._gui = gui
	end

	-- Remove old notification
	local old = self._gui:FindFirstChild("EventNotification")
	if old then old:Destroy() end

	local label = Instance.new("TextLabel")
	label.Name = "EventNotification"
	label.Size = UDim2.new(0, 250, 0, 40)
	label.Position = UDim2.new(0.5, -125, 0, 80)
	label.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	label.BackgroundTransparency = 0.3
	label.Text = (config.emoji or "") .. " " .. (config.displayName or config.id)
	label.TextSize = 20
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Parent = self._gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	-- Slide in
	label.Position = UDim2.new(0.5, -125, 0, -40)
	TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -125, 0, 80),
	}):Play()
end

function RandomEventController:_applyColorCorrection(name: string, tintColor: Color3, saturation: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "RE_" .. name
	cc.TintColor = tintColor
	cc.Saturation = saturation
	cc.Parent = Lighting
end

function RandomEventController:_removeColorCorrection(name: string)
	local cc = Lighting:FindFirstChild("RE_" .. name)
	if cc then
		cc:Destroy()
	end
end

function RandomEventController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	-- Revert any lingering effects
	for name, _ in self._activeEffects do
		pcall(function()
			self:_removeColorCorrection(name)
		end)
	end
end

-- Coin Rain visual effect: 화면 상단에서 금색 코인 파트가 떨어지는 이펙트
-- 참조 카운트로 coin_rain과 bonus_time이 동시에 사용 가능
function RandomEventController:_startCoinRainEffect()
	-- 참조 카운트 증가
	self._coinRainRefCount = (self._coinRainRefCount or 0) + 1

	-- 이미 루프가 돌고 있으면 카운트만 증가
	if self._coinRainRefCount > 1 then return end

	local character = self._player.Character
	if not character then return end

	self._coinRainActive = true

	task.defer(function()
		while self._coinRainActive do
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp then break end

			-- 플레이어 주변에 코인 파트 스폰 (시각 전용)
			for _ = 1, 3 do
				local coin = Instance.new("Part")
				coin.Name = "CoinRainDrop"
				coin.Size = Vector3.new(1.2, 1.2, 0.3)
				coin.Shape = Enum.PartType.Cylinder
				coin.Color = Color3.fromRGB(255, 215, 0)
				coin.Material = Enum.Material.Neon
				coin.Anchored = true
				coin.CanCollide = false
				coin.Position = hrp.Position + Vector3.new(math.random(-8, 8), math.random(15, 22), math.random(-4, 4))
				coin.Parent = workspace

				-- 낙하 트윈
				local endY = hrp.Position.Y - 3
				local tweenInfo = TweenInfo.new(0.6 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				local tween = TweenService:Create(coin, tweenInfo, {
					Position = Vector3.new(coin.Position.X, endY, coin.Position.Z),
					Transparency = 0.8,
				})
				tween.Completed:Connect(function()
					if coin.Parent then coin:Destroy() end
				end)
				tween:Play()
			end

			task.wait(0.15)
		end
	end)
end

function RandomEventController:_stopCoinRainEffect()
	-- 참조 카운트 감소
	self._coinRainRefCount = math.max(0, (self._coinRainRefCount or 0) - 1)

	-- 아직 다른 이벤트가 사용 중이면 루프 유지
	if self._coinRainRefCount > 0 then return end

	self._coinRainActive = false
	-- 잔여 코인 파트 정리
	for _, part in workspace:GetChildren() do
		if part.Name == "CoinRainDrop" then
			part:Destroy()
		end
	end
end

-- Suppress unused variable warning for GameConstants (used for type context only)
local _ = GameConstants

return RandomEventController

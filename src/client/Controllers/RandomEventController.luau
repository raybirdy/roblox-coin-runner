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

	print("[RandomEventController] Event START:", eventId)

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
		-- Scale player character
		local character = self._player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
			if humanoid then
				local scale = config.scaleFactor or 1.8
				-- R15: Humanoid 하위 NumberValue로 스케일 조정 (공식 방법)
				local scaleNames = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }
				local r15Found = false
				for _, scaleName in scaleNames do
					local scaleValue = humanoid:FindFirstChild(scaleName) :: NumberValue?
					if scaleValue then
						r15Found = true
						self._activeEffects["original_" .. scaleName] = scaleValue.Value
						TweenService:Create(scaleValue, TweenInfo.new(0.5), { Value = scale }):Play()
					end
				end

				-- R6 폴백: Model:ScaleTo() 사용 (BasePart 개별 크기 조절은 애니메이션에 의해 덮어씌워짐)
				if not r15Found then
					self._activeEffects["giant_model_scaled"] = true
					local charAny = character :: any
					charAny:ScaleTo(scale)
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

	print("[RandomEventController] Event END:", eventId)

	-- Revert visual effect
	if eventId == "coin_rain" or eventId == "speed_shift" then
		self:_removeColorCorrection(eventId)
		if eventId == "coin_rain" then
			self:_stopCoinRainEffect()
		end

	elseif eventId == "giant_mode" then
		-- Revert scale
		local character = self._player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
			if humanoid then
				local scaleNames = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }
				local r15Reverted = false
				for _, scaleName in scaleNames do
					local scaleValue = humanoid:FindFirstChild(scaleName) :: NumberValue?
					if scaleValue then
						r15Reverted = true
						local original = self._activeEffects["original_" .. scaleName] or 1.0
						TweenService:Create(scaleValue, TweenInfo.new(0.5), { Value = original }):Play()
						self._activeEffects["original_" .. scaleName] = nil
					end
				end

				-- R6 폴백: ScaleTo(1.0)로 원래 크기 복원
				if not r15Reverted and self._activeEffects["giant_model_scaled"] then
					local charAny = character :: any
					charAny:ScaleTo(1.0)
					self._activeEffects["giant_model_scaled"] = nil
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

	-- _coinRainActive를 캐릭터 체크 전에 설정해 refCount 디싱크 방지
	self._coinRainActive = true

	if not self._player.Character then
		warn("[RandomEventController] _startCoinRainEffect: character is nil at start, loop will wait for spawn")
	end

	-- 코인 파트를 담을 Folder 생성 (정리 시 Destroy만 호출하면 됨)
	if not self._coinRainFolder or not self._coinRainFolder.Parent then
		local folder = Instance.new("Folder")
		folder.Name = "CoinRainEffects"
		folder.Parent = workspace
		self._coinRainFolder = folder
	end
	local folder = self._coinRainFolder

	task.defer(function()
		while self._coinRainActive do
			-- 루프 반복마다 캐릭터 재취득 (리스폰 대응)
			local character = self._player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not hrp then
				task.wait(0.15)
				continue
			end

			-- 폴더가 사라졌으면 루프 종료 (EndGame 시 Folder:Destroy()가 호출된 경우)
			if not folder.Parent then
				self._coinRainActive = false
				break
			end

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
				coin.Parent = folder

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
	-- Folder 통째로 파괴 (workspace 전체 순회 불필요)
	if self._coinRainFolder and self._coinRainFolder.Parent then
		self._coinRainFolder:Destroy()
		self._coinRainFolder = nil
	end
end

-- Suppress unused variable warning for GameConstants (used for type context only)
local _ = GameConstants

return RandomEventController

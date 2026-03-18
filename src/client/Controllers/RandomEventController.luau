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
				local bodyScale = humanoid:FindFirstChild("BodyHeightScale") :: NumberValue?
				if bodyScale then
					self._activeEffects["original_scale"] = bodyScale.Value
					TweenService:Create(bodyScale, TweenInfo.new(0.5), { Value = scale }):Play()
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
	end

	self._activeEffects[eventId] = true
end

function RandomEventController:_onEventEnd(data: any)
	local eventId = data.eventId

	-- Revert visual effect
	if eventId == "coin_rain" or eventId == "speed_shift" then
		self:_removeColorCorrection(eventId)

	elseif eventId == "giant_mode" then
		local character = self._player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
			if humanoid then
				local bodyScale = humanoid:FindFirstChild("BodyHeightScale") :: NumberValue?
				if bodyScale then
					local original = self._activeEffects["original_scale"] or 1.0
					TweenService:Create(bodyScale, TweenInfo.new(0.5), { Value = original }):Play()
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

-- Suppress unused variable warning for GameConstants (used for type context only)
local _ = GameConstants

return RandomEventController

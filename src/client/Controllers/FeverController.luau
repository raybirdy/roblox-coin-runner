--!strict
-- Fever Controller
-- Fever mode visual effects, gauge UI, and sound feedback

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local FeverController = {}
FeverController.__index = FeverController

export type FeverController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_isFever: boolean,
		_isSuperFever: boolean,
		_gaugeGui: ScreenGui?,
		_gaugeFrame: Frame?,
		_gaugeFill: Frame?,
		_gaugeLabel: TextLabel?,
		_feverOverlay: ScreenGui?,
		_feverFrame: Frame?,
		_feverSound: Sound?,
		_feverEndSound: Sound?,
		_particleAttachment: Attachment?,
		_particleEmitter: ParticleEmitter?,
		_characterGlow: PointLight?,
		_colorCycleConnection: RBXScriptConnection?,
		_onFeverStart: ((speedBoost: number) -> ())?,
		_onFeverEnd: (() -> ())?,
	},
	FeverController
))

function FeverController.new(): FeverController
	local self = setmetatable({
		_connections = {},
		_isFever = false,
		_isSuperFever = false,
		_gaugeGui = nil,
		_gaugeFrame = nil,
		_gaugeFill = nil,
		_gaugeLabel = nil,
		_feverOverlay = nil,
		_feverFrame = nil,
		_feverSound = nil,
		_feverEndSound = nil,
		_particleAttachment = nil,
		_particleEmitter = nil,
		_characterGlow = nil,
		_colorCycleConnection = nil,
		_onFeverStart = nil,
		_onFeverEnd = nil,
	}, FeverController)

	self:_createGaugeUI()
	self:_createOverlay()
	self:_createSounds()
	self:_setupEventHandlers()

	return self
end

-- Fever gauge UI (bottom-center, above mobile buttons)
function FeverController:_createGaugeUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "FeverGaugeUI"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	self._gaugeGui = gui

	-- Gauge container
	local gaugeW = ResponsiveUtil.scaledOffset(200)
	local gaugeH = ResponsiveUtil.scaledOffset(16)
	local frame = Instance.new("Frame")
	frame.Name = "GaugeFrame"
	frame.Size = UDim2.new(0, gaugeW, 0, gaugeH)
	frame.Position = UDim2.new(0.5, -gaugeW / 2, 0, ResponsiveUtil.scaledOffset(10))
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	frame.BackgroundTransparency = 0.3
	frame.Visible = false
	frame.Parent = gui
	self._gaugeFrame = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 50)
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = frame

	-- Fill bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, -4)
	fill.Position = UDim2.new(0, 2, 0, 2)
	fill.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
	fill.Parent = frame
	self._gaugeFill = fill

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
	label.Font = Enum.Font.GothamBold
	label.Text = "FEVER"
	label.ZIndex = 2
	label.Parent = frame
	self._gaugeLabel = label

	print("[FeverController] Gauge UI created")
end

-- Screen overlay for fever visual effect
function FeverController:_createOverlay()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "FeverOverlayUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	self._feverOverlay = gui

	local frame = Instance.new("Frame")
	frame.Name = "FeverOverlay"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	self._feverFrame = frame
end

-- Fever sounds
function FeverController:_createSounds()
	local startSound = Instance.new("Sound")
	startSound.Name = "FeverStartSound"
	startSound.SoundId = "rbxassetid://9120386948" -- Power Up SFX (energetic, positive)
	startSound.Volume = 0.9
	startSound.PlaybackSpeed = 1.3 -- Upbeat tone for fever start
	startSound.Parent = SoundService
	self._feverSound = startSound

	local endSound = Instance.new("Sound")
	endSound.Name = "FeverEndSound"
	endSound.SoundId = "rbxassetid://6653110952" -- Wind Down SFX (deactivation tone)
	endSound.Volume = 0.6
	endSound.PlaybackSpeed = 0.8 -- Calm, wind-down tone
	endSound.Parent = SoundService
	self._feverEndSound = endSound
end

-- Event handlers
function FeverController:_setupEventHandlers()
	local feverStartConn = RemoteEvents.FeverStart.OnClientEvent:Connect(function(data)
		self:_onFeverStarted(data)
	end)
	table.insert(self._connections, feverStartConn)

	local feverEndConn = RemoteEvents.FeverEnd.OnClientEvent:Connect(function()
		self:_onFeverEnded()
	end)
	table.insert(self._connections, feverEndConn)

	local gaugeConn = RemoteEvents.FeverGaugeUpdate.OnClientEvent:Connect(function(data)
		self:_updateGauge(data)
	end)
	table.insert(self._connections, gaugeConn)

	local superFeverConn = RemoteEvents.SuperFeverStart.OnClientEvent:Connect(function(data)
		self:_onSuperFeverStarted(data)
	end)
	table.insert(self._connections, superFeverConn)
end

-- Fever started
function FeverController:_onFeverStarted(data: { duration: number, speedBoost: number })
	self._isFever = true

	-- Play sound
	if self._feverSound then
		self._feverSound:Play()
	end

	-- Screen overlay flash
	if self._feverFrame then
		self._feverFrame.BackgroundTransparency = 0.5
		local fadeTween = TweenService:Create(
			self._feverFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.85 }
		)
		fadeTween:Play()
	end

	-- Character glow + particle
	self:_startCharacterEffects()

	-- Rainbow color cycle on overlay
	self:_startColorCycle()

	-- Gauge shows "FEVER!" text
	if self._gaugeLabel then
		self._gaugeLabel.Text = "FEVER!"
		self._gaugeLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	end
	if self._gaugeFill then
		self._gaugeFill.Size = UDim2.new(1, -4, 1, -4)
		self._gaugeFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	end

	-- Callback to PlayerController for speed boost
	if self._onFeverStart then
		self._onFeverStart(data.speedBoost)
	end

	-- Show big announcement
	self:_showFeverAnnouncement()

	print(`[FeverController] FEVER MODE! Duration: {data.duration}s`)
end

-- Fever ended
function FeverController:_onFeverEnded()
	self._isFever = false
	self._isSuperFever = false

	-- Play end sound
	if self._feverEndSound then
		self._feverEndSound:Play()
	end

	-- Fade out overlay
	if self._feverFrame then
		local fadeTween = TweenService:Create(
			self._feverFrame,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		fadeTween:Play()
	end

	-- Stop character effects
	self:_stopCharacterEffects()

	-- Stop color cycle
	self:_stopColorCycle()

	-- Reset gauge
	if self._gaugeLabel then
		self._gaugeLabel.Text = "FEVER"
		self._gaugeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	-- Callback
	if self._onFeverEnd then
		self._onFeverEnd()
	end

	print("[FeverController] Fever ended")
end

-- Update gauge fill
function FeverController:_updateGauge(data: { combo: number, threshold: number, onCooldown: boolean })
	if not self._gaugeFrame or not self._gaugeFill then
		return
	end

	-- Show gauge during game
	self._gaugeFrame.Visible = true

	if self._isFever then
		return -- Don't update fill during fever (it stays full)
	end

	local ratio = math.clamp(data.combo / data.threshold, 0, 1)
	local maxWidth = self._gaugeFrame.AbsoluteSize.X - 4

	TweenService:Create(self._gaugeFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, maxWidth * ratio, 1, -4),
	}):Play()

	-- Color gradient based on progress
	if data.onCooldown then
		self._gaugeFill.BackgroundColor3 = Color3.fromRGB(100, 100, 120) -- Gray during cooldown
		if self._gaugeLabel then
			self._gaugeLabel.Text = "COOLDOWN"
		end
	elseif ratio >= 0.8 then
		self._gaugeFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50) -- Red near threshold
		if self._gaugeLabel then
			self._gaugeLabel.Text = `FEVER {math.floor(ratio * 100)}%`
		end
	elseif ratio >= 0.5 then
		self._gaugeFill.BackgroundColor3 = Color3.fromRGB(255, 150, 0) -- Orange
		if self._gaugeLabel then
			self._gaugeLabel.Text = `FEVER {math.floor(ratio * 100)}%`
		end
	else
		self._gaugeFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50) -- Yellow
		if self._gaugeLabel then
			self._gaugeLabel.Text = `FEVER {math.floor(ratio * 100)}%`
		end
	end
end

-- Character glow and particle effects
function FeverController:_startCharacterEffects()
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	-- PointLight for glow
	local light = Instance.new("PointLight")
	light.Name = "FeverGlow"
	light.Color = Color3.fromRGB(255, 200, 50)
	light.Brightness = 3
	light.Range = 20
	light.Parent = hrp
	self._characterGlow = light

	-- Particle emitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "FeverParticle"
	attachment.Parent = hrp
	self._particleAttachment = attachment

	local particle = Instance.new("ParticleEmitter")
	particle.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 50)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(50, 255, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 100, 255)),
	})
	particle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(0.5, 2.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	particle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	particle.Lifetime = NumberRange.new(0.5, 1.0)
	particle.Speed = NumberRange.new(5, 15)
	particle.SpreadAngle = Vector2.new(360, 360)
	particle.Rate = 25 -- Mobile-friendly count
	particle.LightEmission = 0.8
	particle.Parent = attachment
	self._particleEmitter = particle
end

-- Stop character effects
function FeverController:_stopCharacterEffects()
	if self._particleEmitter then
		self._particleEmitter.Rate = 0
	end

	-- Delayed cleanup for particle fade
	task.delay(1.5, function()
		if self._particleAttachment then
			self._particleAttachment:Destroy()
			self._particleAttachment = nil
		end
		self._particleEmitter = nil
	end)

	if self._characterGlow then
		-- Fade out glow
		TweenService:Create(
			self._characterGlow,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = 0 }
		):Play()
		task.delay(0.5, function()
			if self._characterGlow then
				self._characterGlow:Destroy()
				self._characterGlow = nil
			end
		end)
	end
end

-- Rainbow color cycle on overlay
function FeverController:_startColorCycle()
	self:_stopColorCycle()

	local hue = 0
	local conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		if not self._isFever or not self._feverFrame then
			return
		end
		hue = (hue + dt * 0.5) % 1
		self._feverFrame.BackgroundColor3 = Color3.fromHSV(hue, 0.6, 1)

		-- Character glow color cycle
		if self._characterGlow then
			self._characterGlow.Color = Color3.fromHSV(hue, 0.8, 1)
		end
	end)
	self._colorCycleConnection = conn
end

function FeverController:_stopColorCycle()
	if self._colorCycleConnection then
		self._colorCycleConnection:Disconnect()
		self._colorCycleConnection = nil
	end
end

-- Big announcement text
function FeverController:_showFeverAnnouncement()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = playerGui:FindFirstChild("GameUI") :: ScreenGui?
	if not screenGui then
		return
	end

	local label = Instance.new("TextLabel")
	label.Name = "FeverAnnouncement"
	label.Size = UDim2.new(1, 0, 0, 80)
	label.Position = UDim2.new(0, 0, 0.3, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 220, 50)
	label.TextSize = ResponsiveUtil.scaledTextSize(10, 8)
	label.Font = Enum.Font.GothamBlack
	label.Text = "FEVER!"
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(200, 50, 0)
	label.ZIndex = 50
	label.Parent = screenGui

	-- Scale up animation
	local growTween = TweenService:Create(
		label,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ TextSize = ResponsiveUtil.scaledTextSize(60, 40) }
	)
	growTween:Play()

	-- Fade out after 1.5s
	task.delay(1.5, function()
		if label and label.Parent then
			local fadeTween = TweenService:Create(
				label,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			)
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				label:Destroy()
			end)
		end
	end)
end

-- Set callbacks for PlayerController integration
function FeverController:OnFeverStart(callback: (speedBoost: number) -> ())
	self._onFeverStart = callback
end

function FeverController:OnFeverEnd(callback: () -> ())
	self._onFeverEnd = callback
end

-- Check if fever is active
function FeverController:IsFever(): boolean
	return self._isFever
end

-- Hide gauge (lobby/game over)
function FeverController:HideGauge()
	if self._gaugeFrame then
		self._gaugeFrame.Visible = false
	end
end

-- Show gauge (game start)
function FeverController:ShowGauge()
	if self._gaugeFrame then
		self._gaugeFrame.Visible = true
	end
	-- Reset gauge
	if self._gaugeFill then
		self._gaugeFill.Size = UDim2.new(0, 0, 1, -4)
	end
	if self._gaugeLabel then
		self._gaugeLabel.Text = "FEVER 0%"
		self._gaugeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

-- Cleanup
function FeverController:Destroy()
	self:_stopColorCycle()
	self:_stopCharacterEffects()

	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	if self._gaugeGui then
		self._gaugeGui:Destroy()
	end
	if self._feverOverlay then
		self._feverOverlay:Destroy()
	end
	if self._feverSound then
		self._feverSound:Destroy()
	end
	if self._feverEndSound then
		self._feverEndSound:Destroy()
	end
end

-- Super Fever started (fever chain within CHAIN_WINDOW)
function FeverController:_onSuperFeverStarted(data: { duration: number, speedBoost: number })
	self._isFever = true
	self._isSuperFever = true

	-- Play fever sound (reuse)
	if self._feverSound then
		self._feverSound.PlaybackSpeed = 1.6 -- Higher pitch for super
		self._feverSound:Play()
	end

	-- Purple overlay
	if self._feverFrame then
		self._feverFrame.BackgroundColor3 = Color3.fromRGB(140, 0, 200)
		self._feverFrame.BackgroundTransparency = 0.5
		TweenService:Create(
			self._feverFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.75 }
		):Play()
	end

	-- Character glow purple
	self:_startCharacterEffects()

	-- Stop rainbow cycle, use fixed purple
	self:_stopColorCycle()
	if self._characterGlow then
		self._characterGlow.Color = Color3.fromRGB(200, 100, 255)
		self._characterGlow.Brightness = 2.5
	end

	-- Gauge shows "SUPER!" text in purple
	if self._gaugeLabel then
		self._gaugeLabel.Text = "SUPER!"
		self._gaugeLabel.TextColor3 = Color3.fromRGB(200, 100, 255)
	end
	if self._gaugeFill then
		self._gaugeFill.Size = UDim2.new(1, -4, 1, -4)
		self._gaugeFill.BackgroundColor3 = Color3.fromRGB(140, 0, 200)
	end

	-- Speed boost callback
	if self._onFeverStart then
		self._onFeverStart(data.speedBoost)
	end

	-- Big announcement
	self:_showSuperFeverAnnouncement()

	print(`[FeverController] SUPER FEVER! Duration: {data.duration}s`)
end

-- Super Fever announcement (bigger, purple)
function FeverController:_showSuperFeverAnnouncement()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = playerGui:FindFirstChild("GameUI") :: ScreenGui?
	if not screenGui then
		return
	end

	local label = Instance.new("TextLabel")
	label.Name = "SuperFeverAnnouncement"
	label.Size = UDim2.new(1, 0, 0, 80)
	label.Position = UDim2.new(0, 0, 0.25, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(220, 130, 255)
	label.TextSize = ResponsiveUtil.scaledTextSize(10, 8)
	label.Font = Enum.Font.GothamBlack
	label.Text = "🌟 SUPER FEVER!! 🌟"
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(80, 0, 140)
	label.ZIndex = 51
	label.Parent = screenGui

	-- Scale up
	TweenService:Create(
		label,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ TextSize = ResponsiveUtil.scaledTextSize(64, 44) }
	):Play()

	-- Pulse color twice
	task.spawn(function()
		for _ = 1, 2 do
			task.wait(0.5)
			if not label or not label.Parent then
				break
			end
			TweenService:Create(label, TweenInfo.new(0.2), { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
			task.wait(0.2)
			if not label or not label.Parent then
				break
			end
			TweenService:Create(label, TweenInfo.new(0.2), { TextColor3 = Color3.fromRGB(220, 130, 255) }):Play()
		end
	end)

	-- Fade out after 2s
	task.delay(2, function()
		if label and label.Parent then
			local fadeTween = TweenService:Create(
				label,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			)
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				label:Destroy()
			end)
		end
	end)
end

return FeverController

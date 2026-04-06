--!strict
-- Fever Controller
-- Fever mode visual effects, gauge UI, and sound feedback

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local FeverController = {}
FeverController.__index = FeverController

export type FeverController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_isFever: boolean,
		_isSuperFever: boolean,
		_isMiniFever: boolean,
		_miniFeverGlow: PointLight?,
		_gaugeGui: ScreenGui?,
		_gaugeFrame: Frame?,
		_gaugeFill: Frame?,
		_gaugeLabel: TextLabel?,
		_feverOverlay: ScreenGui?,
		_feverFrame: Frame?,
		_edgeGlowFrame: Frame?, -- 콤보 빌드업 엣지 글로우 오버레이
		_feverSound: Sound?,
		_feverEndSound: Sound?,
		_miniFeverSound: Sound?,
		_particleAttachment: Attachment?,
		_particleEmitter: ParticleEmitter?,
		_characterGlow: PointLight?,
		_colorCycleConnection: RBXScriptConnection?,
		_gaugePulseConnection: RBXScriptConnection?,
		_onFeverStart: ((speedBoost: number, duration: number) -> ())?,
		_onFeverEnd: (() -> ())?,
		_feverBloom: BloomEffect?,        -- 피버 포스트 프로세싱
		_feverColorCorrection: ColorCorrectionEffect?, -- 피버 색조 보정
		_coopFeverActive: boolean, -- co-op fever: enhanced effect for both lanes
	},
	FeverController
))

function FeverController.new(): FeverController
	local self = setmetatable({
		_connections = {},
		_isFever = false,
		_isSuperFever = false,
		_isMiniFever = false,
		_miniFeverGlow = nil,
		_gaugeGui = nil,
		_gaugeFrame = nil,
		_gaugeFill = nil,
		_gaugeLabel = nil,
		_feverOverlay = nil,
		_feverFrame = nil,
		_edgeGlowFrame = nil,
		_feverSound = nil,
		_feverEndSound = nil,
		_miniFeverSound = nil,
		_particleAttachment = nil,
		_particleEmitter = nil,
		_characterGlow = nil,
		_colorCycleConnection = nil,
		_gaugePulseConnection = nil,
		_onFeverStart = nil,
		_onFeverEnd = nil,
		_feverBloom = nil,
		_feverColorCorrection = nil,
		_coopFeverActive = false,
	}, FeverController)

	self:_createGaugeUI()
	self:_createOverlay()
	self:_createEdgeGlow()
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
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.DisplayOrder = 8
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
	gui.ScreenInsets = Enum.ScreenInsets.None
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

-- 콤보 빌드업 엣지 글로우 (화면 테두리 점점 밝아지는 효과)
function FeverController:_createEdgeGlow()
	local gui = self._feverOverlay -- feverOverlay ScreenGui 재사용 (별도 ScreenGui 비용 절약)
	if not gui then
		return
	end

	-- 화면 테두리 글로우 Frame (UIGradient로 엣지에서 안쪽으로 페이드)
	local edgeFrame = Instance.new("Frame")
	edgeFrame.Name = "EdgeGlowFrame"
	edgeFrame.Size = UDim2.new(1, 0, 1, 0)
	edgeFrame.BackgroundColor3 = Color3.fromRGB(255, 180, 50) -- 황금색
	edgeFrame.BackgroundTransparency = 1 -- 처음엔 완전 투명
	edgeFrame.BorderSizePixel = 0
	edgeFrame.ZIndex = 1 -- FeverOverlay(ZIndex 기본)보다 낮게
	edgeFrame.Parent = gui
	self._edgeGlowFrame = edgeFrame

	-- UIGradient: 테두리만 빛나게 (중앙은 투명)
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3), -- 엣지: 30% 불투명
		NumberSequenceKeypoint.new(0.15, 1), -- 중앙 방향으로 완전 투명
		NumberSequenceKeypoint.new(0.85, 1),
		NumberSequenceKeypoint.new(1, 0.3), -- 반대 엣지
	})
	gradient.Rotation = 90
	gradient.Parent = edgeFrame
end

-- Fever sounds
function FeverController:_createSounds()
	local startSound = Instance.new("Sound")
	startSound.Name = "FeverStartSound"
	startSound.SoundId = "rbxassetid://1848354536" -- Fanfare / 피버 시작 (밝고 신남)
	startSound.Volume = 0.9
	startSound.PlaybackSpeed = 1.3 -- Upbeat tone for fever start
	startSound.Parent = SoundService
	self._feverSound = startSound

	local endSound = Instance.new("Sound")
	endSound.Name = "FeverEndSound"
	endSound.SoundId = "" -- TODO: 피버 종료 Wind-down 사운드 (rbxassetid 교체 필요)
	endSound.Volume = 0.6
	endSound.PlaybackSpeed = 0.8 -- Calm, wind-down tone
	endSound.Parent = SoundService
	self._feverEndSound = endSound

	-- 미니 피버 사운드 (정식 피버보다 가벼운 차임 효과)
	local miniFeverSound = Instance.new("Sound")
	miniFeverSound.Name = "MiniFeverSound"
	miniFeverSound.SoundId = "" -- TODO: 미니 피버 Chime 사운드 (rbxassetid 교체 필요)
	miniFeverSound.Volume = 0.6
	miniFeverSound.PlaybackSpeed = 1.0 -- 정식 피버(1.3)보다 낮은 피치
	miniFeverSound.Parent = SoundService
	self._miniFeverSound = miniFeverSound
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

	local miniFeverStartConn = RemoteEvents.MiniFeverStart.OnClientEvent:Connect(function(data)
		self:_onMiniFeverStarted(data)
	end)
	table.insert(self._connections, miniFeverStartConn)

	local miniFeverEndConn = RemoteEvents.MiniFeverEnd.OnClientEvent:Connect(function()
		self:_onMiniFeverEnded()
	end)
	table.insert(self._connections, miniFeverEndConn)
end

-- Fever started
function FeverController:_onFeverStarted(data: { duration: number, speedBoost: number })
	self._isFever = true

	-- Play sound
	if self._feverSound then
		self._feverSound:Play()
	end

	-- Screen overlay flash (co-op: more intense double flash)
	if self._feverFrame then
		local flashTransparency = self._coopFeverActive and 0.2 or 0.5
		local fadeTransparency = self._coopFeverActive and 0.7 or 0.85
		self._feverFrame.BackgroundTransparency = flashTransparency
		local fadeTween = TweenService:Create(
			self._feverFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = fadeTransparency }
		)
		fadeTween:Play()
		if self._coopFeverActive then
			-- Second flash pulse for co-op
			fadeTween.Completed:Connect(function()
				if self._feverFrame and self._isFever then
					self._feverFrame.BackgroundTransparency = flashTransparency
					TweenService:Create(
						self._feverFrame,
						TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ BackgroundTransparency = fadeTransparency }
					):Play()
				end
			end)
		end
	end

	-- Character glow + particle
	self:_startCharacterEffects()

	-- Rainbow color cycle on overlay
	self:_startColorCycle()

	-- 포스트 프로세싱: 화면 전체 bloom + 채도 강화
	self:_startPostProcessing()

	-- Gauge shows "FEVER!" text
	if self._gaugeLabel then
		self._gaugeLabel.Text = "FEVER!"
		self._gaugeLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	end
	if self._gaugeFill then
		self._gaugeFill.Size = UDim2.new(1, -4, 1, -4)
		self._gaugeFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	end

	-- Callback to PlayerController for speed boost (+ duration for camera zoom)
	if self._onFeverStart then
		self._onFeverStart(data.speedBoost, data.duration)
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

	-- 포스트 프로세싱 해제
	self:_stopPostProcessing()

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

-- Update gauge fill + 콤보 빌드업 피드백 계단
function FeverController:_updateGauge(data: { combo: number, threshold: number, onCooldown: boolean })
	if not self._gaugeFrame or not self._gaugeFill then
		return
	end

	-- Show gauge during game
	self._gaugeFrame.Visible = true

	if self._isFever then
		-- 피버 중 엣지 글로우 숨기기
		if self._edgeGlowFrame then
			self._edgeGlowFrame.BackgroundTransparency = 1
		end
		return -- Don't update fill during fever (it stays full)
	end

	local ratio = math.clamp(data.combo / data.threshold, 0, 1)
	local maxWidth = self._gaugeFrame.AbsoluteSize.X - 4

	TweenService:Create(self._gaugeFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, maxWidth * ratio, 1, -4),
	}):Play()

	-- ===== 콤보 빌드업 피드백 계단 =====
	-- 엣지 글로우: ratio에 비례해 점점 선명해짐 (0% 투명 → 80%에서 강하게)
	if self._edgeGlowFrame and not data.onCooldown then
		local glowAlpha = math.max(0, (ratio - 0.3) / 0.7) -- 30% 이상부터 서서히
		local glowTransparency = 1 - (glowAlpha * 0.7) -- 최대 0.3 (30% 불투명)
		TweenService:Create(self._edgeGlowFrame, TweenInfo.new(0.3), {
			BackgroundTransparency = glowTransparency,
		}):Play()
		-- 색상: 황금 → 주황 → 빨강
		if ratio >= 0.9 then
			self._edgeGlowFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		elseif ratio >= 0.6 then
			self._edgeGlowFrame.BackgroundColor3 = Color3.fromRGB(255, 130, 0)
		else
			self._edgeGlowFrame.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		end
	elseif self._edgeGlowFrame then
		-- 쿨다운 또는 리셋 시 엣지 글로우 꺼짐
		TweenService:Create(self._edgeGlowFrame, TweenInfo.new(0.5), {
			BackgroundTransparency = 1,
		}):Play()
	end

	-- 게이지 펄스: ratio >= 0.8 시 심장박동처럼 펄스 시작
	if ratio >= 0.8 and not data.onCooldown then
		if not self._gaugePulseConnection then
			self._gaugePulseConnection = game:GetService("RunService").Heartbeat:Connect(function(_dt)
				if not self._gaugeFrame then
					return
				end
				-- 게이지 테두리 펄스
				local stroke = self._gaugeFrame:FindFirstChildOfClass("UIStroke")
				if stroke then
					local t = os.clock()
					local pulse = math.sin(t * 8) * 0.5 + 0.5 -- 8 rad/s 진동
					stroke.Thickness = 2 + pulse * 2 -- 2~4px 진동
				end
			end)
		end
	else
		-- 펄스 중지
		if self._gaugePulseConnection then
			self._gaugePulseConnection:Disconnect()
			self._gaugePulseConnection = nil
			-- 두께 원복
			local stroke = self._gaugeFrame:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = 2
			end
		end
	end

	-- Color gradient based on progress
	if data.onCooldown then
		self._gaugeFill.BackgroundColor3 = Color3.fromRGB(100, 100, 120) -- Gray during cooldown
		if self._gaugeLabel then
			self._gaugeLabel.Text = "COOLDOWN"
		end
	elseif ratio >= 0.93 then
		self._gaugeFill.BackgroundColor3 = Color3.fromRGB(255, 20, 20) -- 강렬한 빨강
		if self._gaugeLabel then
			self._gaugeLabel.Text = "⚡ ALMOST!"
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

-- 피버 포스트 프로세싱 활성 (BloomEffect + ColorCorrection)
function FeverController:_startPostProcessing()
	-- BloomEffect (화면 전체 발광)
	if not self._feverBloom then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "FeverBloom"
		bloom.Intensity = 0
		bloom.Size = 24
		bloom.Threshold = 0.9
		bloom.Parent = Lighting
		self._feverBloom = bloom
	end
	TweenService:Create(
		self._feverBloom,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Intensity = 1.2 }
	):Play()

	-- ColorCorrection (채도 + 밝기 강화 → 화면이 더 생생해짐)
	if not self._feverColorCorrection then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "FeverColorCorrection"
		cc.Saturation = 0
		cc.Brightness = 0
		cc.Contrast = 0
		cc.Parent = Lighting
		self._feverColorCorrection = cc
	end
	TweenService:Create(
		self._feverColorCorrection,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Saturation = 0.5, Brightness = 0.06 }
	):Play()
end

-- 피버 포스트 프로세싱 해제 (부드럽게 원복)
function FeverController:_stopPostProcessing()
	if self._feverBloom then
		local bloom = self._feverBloom
		TweenService:Create(
			bloom,
			TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Intensity = 0 }
		):Play()
		task.delay(0.7, function()
			if bloom and bloom.Parent then
				bloom:Destroy()
			end
		end)
		self._feverBloom = nil
	end

	if self._feverColorCorrection then
		local cc = self._feverColorCorrection
		TweenService:Create(
			cc,
			TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Saturation = 0, Brightness = 0 }
		):Play()
		task.delay(0.7, function()
			if cc and cc.Parent then
				cc:Destroy()
			end
		end)
		self._feverColorCorrection = nil
	end
end

-- Rainbow color cycle on overlay
function FeverController:_startColorCycle()
	self:_stopColorCycle()

	local hue = 0
	local BASE_BRIGHTNESS = 3
	local PULSE_SPEED = 4 -- rad/s
	local conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		if not self._isFever or not self._feverFrame then
			return
		end
		hue = (hue + dt * 0.5) % 1
		self._feverFrame.BackgroundColor3 = Color3.fromHSV(hue, 0.6, 1)

		-- Character glow: 색상 + 밝기 펄스 + 범위 펄스
		if self._characterGlow then
			self._characterGlow.Color = Color3.fromHSV(hue, 0.8, 1)
			-- 밝기 펄스: 2.5 ~ 4.5 사인파
			self._characterGlow.Brightness = BASE_BRIGHTNESS + math.sin(tick() * PULSE_SPEED) * 1.0
			-- 범위 펄스: 18 ~ 24 사인파
			self._characterGlow.Range = 20 + math.sin(tick() * 3) * 4
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
function FeverController:OnFeverStart(callback: (speedBoost: number, duration: number) -> ())
	self._onFeverStart = callback
end

function FeverController:OnFeverEnd(callback: () -> ())
	self._onFeverEnd = callback
end

-- Co-op fever: broadcast enhanced effect to both lanes
function FeverController:SetCoopFeverEffect(enabled: boolean)
	self._coopFeverActive = enabled
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
-- Sprint 18: Fever는 이제 Fever Coin 수집으로만 발동 → 콤보 게이지 표시 제거
function FeverController:ShowGauge()
	if self._gaugeFrame then
		self._gaugeFrame.Visible = false
	end
end

-- Cleanup
function FeverController:Destroy()
	self:_stopColorCycle()
	self:_stopCharacterEffects()
	self:_stopPostProcessing()

	if self._gaugePulseConnection then
		self._gaugePulseConnection:Disconnect()
		self._gaugePulseConnection = nil
	end

	if self._miniFeverGlow then
		self._miniFeverGlow:Destroy()
		self._miniFeverGlow = nil
	end

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
	if self._miniFeverSound then
		self._miniFeverSound:Destroy()
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

	-- Speed boost callback (duration 전달: 카메라 줌 지속시간에 사용)
	if self._onFeverStart then
		self._onFeverStart(data.speedBoost, data.duration)
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

-- Mini Fever started (15 combo) - 가벼운 녹색 글로우 + 어나운스
function FeverController:_onMiniFeverStarted(_data: { duration: number })
	if self._isFever then
		return -- 정식 피버 중엔 미니 피버 시각효과 무시
	end
	self._isMiniFever = true

	-- 사운드 재생
	if self._miniFeverSound then
		self._miniFeverSound:Play()
	end

	-- 캐릭터에 녹색 글로우 추가
	local player = Players.LocalPlayer
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local glow = Instance.new("PointLight")
			glow.Name = "MiniFeverGlow"
			glow.Color = Color3.fromRGB(80, 255, 120) -- 녹색
			glow.Brightness = 1.5
			glow.Range = 15
			glow.Parent = hrp
			self._miniFeverGlow = glow
		end
	end

	-- 게이지 테두리 색 변경 (녹색)
	if self._gaugeFrame then
		local stroke = self._gaugeFrame:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(80, 255, 120) }):Play()
		end
	end

	-- 어나운스 텍스트
	self:_showMiniFeverAnnouncement()

	print("[FeverController] MINI FEVER!")
end

-- Mini Fever ended
function FeverController:_onMiniFeverEnded()
	self._isMiniFever = false

	-- 글로우 제거
	if self._miniFeverGlow then
		TweenService:Create(
			self._miniFeverGlow,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = 0 }
		):Play()
		task.delay(0.3, function()
			if self._miniFeverGlow then
				self._miniFeverGlow:Destroy()
				self._miniFeverGlow = nil
			end
		end)
	end

	-- 게이지 테두리 색 원복
	if self._gaugeFrame and not self._isFever then
		local stroke = self._gaugeFrame:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.3), { Color = Color3.fromRGB(255, 200, 50) }):Play()
		end
	end

	print("[FeverController] Mini Fever ended")
end

-- Mini Fever 어나운스 (FEVER!보다 작게)
function FeverController:_showMiniFeverAnnouncement()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = playerGui:FindFirstChild("GameUI") :: ScreenGui?
	if not screenGui then
		return
	end

	local label = Instance.new("TextLabel")
	label.Name = "MiniFeverAnnouncement"
	label.Size = UDim2.new(1, 0, 0, 50)
	label.Position = UDim2.new(0, 0, 0.38, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(80, 255, 120) -- 녹색
	label.TextSize = ResponsiveUtil.scaledTextSize(8, 6)
	label.Font = Enum.Font.GothamBold
	label.Text = "✨ 미니 피버! 2배 코인!"
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 80, 30)
	label.ZIndex = 49
	label.Parent = screenGui

	-- 살짝 커졌다가 사라짐
	TweenService:Create(
		label,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ TextSize = ResponsiveUtil.scaledTextSize(28, 20) }
	):Play()

	task.delay(1.2, function()
		if label and label.Parent then
			local fadeTween = TweenService:Create(
				label,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
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

--!strict
-- Weather Controller (IDEA-007)
-- 챕터/존별 비주얼 전용 날씨 파티클 연출 (게임플레이 영향 없음)
-- 종류: rain(도시), sand_dust(사막), snowflakes(설원), sparkles(숲), stars(우주)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

-- 날씨 타입 → ParticleEmitter 프리셋
local WEATHER_PRESETS = {
	-- Zone 1 (초원): 반짝이는 꽃가루
	sparkles = {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 255, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 100)),
		}),
		LightEmission = 0.6,
		LightInfluence = 0.3,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.8, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Speed = NumberRange.new(1, 3),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-45, 45),
		SpreadAngle = Vector2.new(60, 60),
		Rate = 25,
		Lifetime = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Top,
	},
	-- Zone 2 (꽃길): 꽃잎
	petals = {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 160, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 140, 180)),
		}),
		LightEmission = 0.1,
		LightInfluence = 0.8,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.6, 0.4),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Speed = NumberRange.new(0.5, 2),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		SpreadAngle = Vector2.new(80, 80),
		Rate = 20,
		Lifetime = NumberRange.new(3, 5),
		EmissionDirection = Enum.NormalId.Top,
	},
	-- Zone 3 (버섯숲): 보라색 포자
	spores = {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 100, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 60, 160)),
		}),
		LightEmission = 0.4,
		LightInfluence = 0.5,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.8, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Speed = NumberRange.new(0.3, 1.5),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-30, 30),
		SpreadAngle = Vector2.new(70, 70),
		Rate = 18,
		Lifetime = NumberRange.new(2, 5),
		EmissionDirection = Enum.NormalId.Top,
	},
	-- Zone 4 (석양): 황금빛 먼지
	dust = {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 50)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 130, 30)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 90, 20)),
		}),
		LightEmission = 0.3,
		LightInfluence = 0.7,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.5, 0.18),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.7, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Speed = NumberRange.new(1, 4),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		SpreadAngle = Vector2.new(50, 50),
		Rate = 20,
		Lifetime = NumberRange.new(1.5, 3),
		EmissionDirection = Enum.NormalId.Top,
	},
	-- Zone 5 (별빛): 별똥별
	stars = {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 220, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 180, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 130, 220)),
		}),
		LightEmission = 0.8,
		LightInfluence = 0.2,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.3, 0.2),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Speed = NumberRange.new(5, 12),
		Rotation = NumberRange.new(0, 180),
		RotSpeed = NumberRange.new(0, 0),
		SpreadAngle = Vector2.new(15, 15),
		Rate = 15,
		Lifetime = NumberRange.new(0.8, 1.8),
		EmissionDirection = Enum.NormalId.Front,
	},
}

-- Zone 인덱스 → 날씨 타입 매핑
local ZONE_WEATHER = {
	[1] = "sparkles",
	[2] = "petals",
	[3] = "spores",
	[4] = "dust",
	[5] = "stars",
}

-- 파티클 방출 Part를 플레이어 위 높이에 배치
local EMITTER_Y_OFFSET = 18  -- 플레이어 머리 위 18 studs
local EMITTER_SIZE = Vector3.new(30, 1, 8)  -- 넓게 분산
local MAX_PARTICLES = 50 -- 성능 제한

local WeatherController = {}
WeatherController.__index = WeatherController

export type WeatherController = typeof(setmetatable(
	{} :: {
		_emitterPart: Part?,
		_particleEmitter: ParticleEmitter?,
		_heartbeatConn: RBXScriptConnection?,
		_currentZone: number,
		_isGameActive: boolean,
	},
	WeatherController
))

function WeatherController.new(): WeatherController
	local self = setmetatable({
		_emitterPart = nil,
		_particleEmitter = nil,
		_heartbeatConn = nil,
		_currentZone = 0,
		_isGameActive = false,
	}, WeatherController)

	self:_createEmitter()

	return self
end

function WeatherController:_createEmitter()
	local part = Instance.new("Part")
	part.Name = "WeatherEmitter"
	part.Size = EMITTER_SIZE
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.CFrame = CFrame.new(0, -500, 0) -- 게임 시작 전 숨겨두기
	part.Parent = workspace
	self._emitterPart = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "WeatherParticle"
	emitter.Enabled = false
	emitter.Parent = part
	self._particleEmitter = emitter
end

-- 파티클 프리셋 적용
function WeatherController:_applyPreset(presetName: string)
	local preset = WEATHER_PRESETS[presetName]
	if not preset or not self._particleEmitter then return end

	local e = self._particleEmitter
	e.Color = preset.Color
	e.LightEmission = preset.LightEmission
	e.LightInfluence = preset.LightInfluence
	e.Size = preset.Size
	e.Transparency = preset.Transparency
	e.Speed = preset.Speed
	e.Rotation = preset.Rotation
	e.RotSpeed = preset.RotSpeed
	e.SpreadAngle = preset.SpreadAngle
	e.Rate = math.min(preset.Rate, MAX_PARTICLES)
	e.Lifetime = preset.Lifetime
	e.EmissionDirection = preset.EmissionDirection
end

-- 게임 시작
function WeatherController:StartGame()
	self._isGameActive = true
	self:_startFollowLoop()
end

-- 게임 종료
function WeatherController:EndGame()
	self._isGameActive = false
	self._currentZone = 0
	if self._particleEmitter then
		self._particleEmitter.Enabled = false
	end
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end
end

-- Zone 전환 시 날씨 변경
function WeatherController:SetZone(zoneIndex: number)
	if zoneIndex == self._currentZone then return end
	self._currentZone = zoneIndex

	local weatherType = ZONE_WEATHER[zoneIndex]
	if not weatherType then
		if self._particleEmitter then
			self._particleEmitter.Enabled = false
		end
		return
	end

	self:_applyPreset(weatherType)
	if self._particleEmitter then
		self._particleEmitter.Enabled = self._isGameActive
	end

	print(`[WeatherController] Zone {zoneIndex} → {weatherType}`)
end

-- 파티클 방출 Part를 플레이어 위에 따라다니게 함
function WeatherController:_startFollowLoop()
	local player = Players.LocalPlayer

	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
	end

	self._heartbeatConn = RunService.Heartbeat:Connect(function()
		if not self._isGameActive then return end
		local character = player.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not self._emitterPart then return end

		local pos = root.Position
		self._emitterPart.CFrame = CFrame.new(pos.X, pos.Y + EMITTER_Y_OFFSET, pos.Z)
	end)
end

function WeatherController:Destroy()
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end
	if self._emitterPart then
		self._emitterPart:Destroy()
		self._emitterPart = nil
	end
end

return WeatherController

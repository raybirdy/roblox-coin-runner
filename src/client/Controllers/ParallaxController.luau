--!strict
-- Parallax Controller (IDEA-002)
-- 2-layer background parallax: 플레이어 이동 시 원거리/중거리 배경이 다른 속도로 스크롤

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

-- 레이어 설정
local FAR_PARALLAX = 0.15 -- X방향 시차 비율 (플레이어 X의 15%만 따라감)
local MID_PARALLAX = 0.40 -- X방향 시차 비율 (플레이어 X의 40%만 따라감)
local FAR_Z_OFFSET = 220 -- 플레이어 뒤 거리 (원거리)
local MID_Z_OFFSET = 90 -- 플레이어 뒤 거리 (중거리)
local FAR_Y = 22 -- 원거리 레이어 높이
local MID_Y = 12 -- 중거리 레이어 높이
local FAR_SIZE = Vector3.new(1200, 70, 2)
local MID_SIZE = Vector3.new(700, 35, 2)

local ParallaxController = {}
ParallaxController.__index = ParallaxController

export type ParallaxController = typeof(setmetatable(
	{} :: {
		_farLayer: Part?,
		_midLayer: Part?,
		_heartbeatConn: RBXScriptConnection?,
		_currentZoneIndex: number,
	},
	ParallaxController
))

function ParallaxController.new(): ParallaxController
	local self = setmetatable({
		_farLayer = nil,
		_midLayer = nil,
		_heartbeatConn = nil,
		_currentZoneIndex = 1,
	}, ParallaxController)

	self:_createLayers()
	self:_startUpdate()

	return self
end

function ParallaxController:_createLayers()
	local defaultTheme = GameConstants.ZONE_THEMES[1]

	-- 원거리 레이어 (하늘/언덕 배경)
	local far = Instance.new("Part")
	far.Name = "ParallaxFar"
	far.Size = FAR_SIZE
	far.Anchored = true
	far.CanCollide = false
	far.CanTouch = false
	far.CastShadow = false
	far.Material = Enum.Material.SmoothPlastic
	far.BrickColor = BrickColor.new(defaultTheme.skyAmbient)
	far.CFrame = CFrame.new(0, FAR_Y, -FAR_Z_OFFSET)
	far.Parent = workspace
	self._farLayer = far

	-- 중거리 레이어 (언덕/나무 배경)
	local mid = Instance.new("Part")
	mid.Name = "ParallaxMid"
	mid.Size = MID_SIZE
	mid.Anchored = true
	mid.CanCollide = false
	mid.CanTouch = false
	mid.CastShadow = false
	mid.Material = Enum.Material.SmoothPlastic
	mid.BrickColor = BrickColor.new(defaultTheme.hillColor)
	mid.CFrame = CFrame.new(0, MID_Y, -MID_Z_OFFSET)
	mid.Parent = workspace
	self._midLayer = mid
end

function ParallaxController:_startUpdate()
	local player = Players.LocalPlayer

	self._heartbeatConn = RunService.Heartbeat:Connect(function()
		local character = player.Character
		if not character then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end

		local pos = root.Position

		-- 원거리: X는 플레이어의 15%만 따라감, Z는 항상 플레이어 뒤 고정
		if self._farLayer then
			self._farLayer.CFrame = CFrame.new(
				pos.X * FAR_PARALLAX,
				FAR_Y,
				pos.Z - FAR_Z_OFFSET
			)
		end

		-- 중거리: X는 플레이어의 40%만 따라감
		if self._midLayer then
			self._midLayer.CFrame = CFrame.new(
				pos.X * MID_PARALLAX,
				MID_Y,
				pos.Z - MID_Z_OFFSET
			)
		end
	end)
end

-- Zone 전환 시 배경 색상 업데이트
function ParallaxController:SetZoneTheme(zoneIndex: number)
	if zoneIndex == self._currentZoneIndex then
		return
	end
	self._currentZoneIndex = zoneIndex

	local theme = GameConstants.ZONE_THEMES[zoneIndex]
	if not theme then
		return
	end

	if self._farLayer then
		self._farLayer.BrickColor = BrickColor.new(theme.skyAmbient)
	end
	if self._midLayer then
		self._midLayer.BrickColor = BrickColor.new(theme.hillColor)
	end
end

function ParallaxController:Destroy()
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end
	if self._farLayer then
		self._farLayer:Destroy()
		self._farLayer = nil
	end
	if self._midLayer then
		self._midLayer:Destroy()
		self._midLayer = nil
	end
end

return ParallaxController

--!strict
-- Zone Controller
-- Zone 전환 시 Lighting 속성을 TweenService로 부드럽게 전환 + Zone 이름 팝업

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local ZoneController = {}
ZoneController.__index = ZoneController

export type ZoneController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_currentZone: number,
		_zoneGui: ScreenGui?,
		_zoneLabel: TextLabel?,
	},
	ZoneController
))

function ZoneController.new(): ZoneController
	local self = setmetatable({
		_connections = {},
		_currentZone = 1,
		_zoneGui = nil,
		_zoneLabel = nil,
	}, ZoneController)

	self:_createZoneUI()

	return self
end

-- Zone UI 생성 (팝업 라벨)
function ZoneController:_createZoneUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ZoneUI"
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.Parent = playerGui
	self._zoneGui = screenGui

	local label = Instance.new("TextLabel")
	label.Name = "ZoneLabel"
	label.Size = ResponsiveUtil.clampedSize(400, 60, 0.80, 0.12)
	local labelW = math.min(400, ResponsiveUtil.getViewportSize().X * 0.80)
	label.Position = UDim2.new(0.5, -labelW / 2, 0, ResponsiveUtil.scaledOffset(80))
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.BackgroundTransparency = 0.4
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = ResponsiveUtil.scaledTextSize(28, 20)
	label.Font = Enum.Font.GothamBlack
	label.Text = ""
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Visible = false
	label.Parent = screenGui
	self._zoneLabel = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
end

-- Zone 전환 연출
function ZoneController:TransitionToZone(zoneIndex: number, displayName: string)
	if zoneIndex == self._currentZone then
		return
	end

	self._currentZone = zoneIndex
	local theme = GameConstants.ZONE_THEMES[zoneIndex]
	if not theme then
		return
	end

	-- 1) Lighting 전환 (2초 Tween)
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local lightingTween = TweenService:Create(Lighting, tweenInfo, {
		OutdoorAmbient = theme.skyAmbient,
		ClockTime = theme.clockTime,
	})
	lightingTween:Play()

	-- 2) Zone 이름 팝업 표시
	if self._zoneLabel then
		-- Zone 아이콘
		local icons = {
			Meadow = "",
			FlowerPath = "",
			MushroomWood = "",
			Sunset = "",
			Starlight = "",
		}
		local icon = icons[theme.name] or ""
		self._zoneLabel.Text = `{icon} {displayName}`
		self._zoneLabel.BackgroundColor3 = theme.skyAmbient
		self._zoneLabel.BackgroundTransparency = 0.3
		self._zoneLabel.TextTransparency = 0
		self._zoneLabel.Visible = true

		-- 2초 후 페이드 아웃
		task.delay(2, function()
			if self._zoneLabel and self._zoneLabel.Parent then
				local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				local fadeTween = TweenService:Create(self._zoneLabel, fadeInfo, {
					TextTransparency = 1,
					BackgroundTransparency = 1,
				})
				fadeTween:Play()
				fadeTween.Completed:Connect(function()
					if self._zoneLabel and self._zoneLabel.Parent then
						self._zoneLabel.Visible = false
					end
				end)
			end
		end)
	end

	print(`[ZoneController] Transitioned to zone {zoneIndex}: {displayName}`)
end

-- Meadow 테마로 복원 (게임 종료 시)
function ZoneController:ResetToDefault()
	self._currentZone = 1
	local defaultTheme = GameConstants.ZONE_THEMES[1]
	if not defaultTheme then
		return
	end

	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local lightingTween = TweenService:Create(Lighting, tweenInfo, {
		OutdoorAmbient = defaultTheme.skyAmbient,
		ClockTime = defaultTheme.clockTime,
	})
	lightingTween:Play()

	-- Zone 라벨 숨기기
	if self._zoneLabel then
		self._zoneLabel.Visible = false
	end
end

-- 정리
function ZoneController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}

	if self._zoneGui then
		self._zoneGui:Destroy()
		self._zoneGui = nil
	end
end

return ZoneController

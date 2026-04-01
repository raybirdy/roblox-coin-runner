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
		_flashFrame: Frame?,
		_labelTween: Tween?,
	},
	ZoneController
))

function ZoneController.new(): ZoneController
	local self = setmetatable({
		_connections = {},
		_currentZone = 1,
		_zoneGui = nil,
		_zoneLabel = nil,
		_flashFrame = nil,
		_labelTween = nil,
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
	screenGui.DisplayOrder = 11
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

	-- 존 전환 화면 플래시 (전체화면 색상 오버레이)
	local flash = Instance.new("Frame")
	flash.Name = "ZoneFlash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.Position = UDim2.new(0, 0, 0, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 10
	flash.Parent = screenGui
	self._flashFrame = flash
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
		FogColor = theme.fogColor,
		FogStart = theme.fogStart,
		FogEnd = theme.fogEnd,
	})
	lightingTween:Play()

	-- 2) 화면 플래시 (존 테마 색상으로 0.45s 페이드 아웃)
	if self._flashFrame then
		self._flashFrame.BackgroundColor3 = theme.skyAmbient
		self._flashFrame.BackgroundTransparency = 0.35
		local flashInfo = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(self._flashFrame, flashInfo, { BackgroundTransparency = 1 }):Play()
	end

	-- 3) Zone 이름 팝업: 위에서 슬라이드 인 + 스케일 바운스
	if self._zoneLabel then
		-- 진행 중인 트윈 취소
		if self._labelTween then
			self._labelTween:Cancel()
			self._labelTween = nil
		end

		local icons = {
			Meadow = "🌿",
			FlowerPath = "🌸",
			MushroomWood = "🍄",
			Sunset = "🌅",
			Starlight = "⭐",
		}
		local icon = icons[theme.name] or ""
		local labelW = math.min(400, ResponsiveUtil.getViewportSize().X * 0.80)
		local finalY = ResponsiveUtil.scaledOffset(80)
		local smallTextSize = ResponsiveUtil.scaledTextSize(18, 14)
		local normalTextSize = ResponsiveUtil.scaledTextSize(28, 20)

		-- 시작: 위쪽에서 작게
		self._zoneLabel.Text = `{icon} {displayName}`
		self._zoneLabel.BackgroundColor3 = theme.skyAmbient
		self._zoneLabel.BackgroundTransparency = 0.3
		self._zoneLabel.TextTransparency = 0
		self._zoneLabel.TextSize = smallTextSize
		self._zoneLabel.Position = UDim2.new(0.5, -labelW / 2, 0, finalY - 48)
		self._zoneLabel.Visible = true

		-- Back 이징으로 슬라이드 인 + 텍스트 확대
		local slideInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local slideTween = TweenService:Create(self._zoneLabel, slideInfo, {
			Position = UDim2.new(0.5, -labelW / 2, 0, finalY),
			TextSize = normalTextSize,
		})
		slideTween:Play()
		self._labelTween = slideTween

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
		FogColor = defaultTheme.fogColor,
		FogStart = defaultTheme.fogStart,
		FogEnd = defaultTheme.fogEnd,
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

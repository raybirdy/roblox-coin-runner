--!strict
-- Lucky Spin Controller
-- 룰렛 스핀 UI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local LuckySpinController = {}
LuckySpinController.__index = LuckySpinController

export type LuckySpinController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_screenGui: ScreenGui?,
		_wheelFrame: Frame?,
		_spinButton: TextButton?,
		_gemSpinButton: TextButton?,
		_resultFrame: Frame?,
		_rotationValue: NumberValue?,
		_connections: { RBXScriptConnection },
		_isSpinning: boolean,
		_isOpen: boolean,
		_freeSpinsLeft: number,
		_openButton: TextButton?,
	},
	LuckySpinController
))

-- Wheel segment colors
local SEGMENT_COLORS = {
	Color3.fromRGB(255, 80, 80), -- red
	Color3.fromRGB(80, 180, 255), -- blue
	Color3.fromRGB(255, 200, 50), -- gold
	Color3.fromRGB(80, 220, 120), -- green
	Color3.fromRGB(200, 100, 255), -- purple
	Color3.fromRGB(255, 150, 50), -- orange
	Color3.fromRGB(100, 200, 200), -- teal
}

function LuckySpinController.new(player: Player): LuckySpinController
	local self = setmetatable({
		_player = player,
		_screenGui = nil,
		_wheelFrame = nil,
		_spinButton = nil,
		_gemSpinButton = nil,
		_resultFrame = nil,
		_rotationValue = nil,
		_connections = {},
		_isSpinning = false,
		_isOpen = false,
		_freeSpinsLeft = 1,
		_openButton = nil,
	}, LuckySpinController)

	self:_createUI()
	self:_createLobbyButton()
	self:_setupEventHandlers()

	return self
end

-- 로비에 스핀 버튼 생성
function LuckySpinController:_createLobbyButton()
	local playerGui = self._player:WaitForChild("PlayerGui")

	-- Find existing GameUI ScreenGui or create
	local gameUI = playerGui:FindFirstChild("GameUI") :: ScreenGui?
	if not gameUI then
		return
	end

	local spinBtn = Instance.new("TextButton")
	spinBtn.Name = "LuckySpinButton"
	spinBtn.Size = UDim2.new(0, ResponsiveUtil.scaledOffset(56), 0, ResponsiveUtil.scaledOffset(56))
	spinBtn.Position = UDim2.new(0, ResponsiveUtil.scaledOffset(12), 0.5, -ResponsiveUtil.scaledOffset(28))
	spinBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 255)
	spinBtn.Text = "🎰"
	spinBtn.TextSize = ResponsiveUtil.scaledTextSize(28, 20)
	spinBtn.Font = Enum.Font.GothamBold
	spinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	spinBtn.AutoButtonColor = true
	spinBtn.Visible = true
	spinBtn.Parent = gameUI
	self._openButton = spinBtn

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = spinBtn

	spinBtn.MouseButton1Click:Connect(function()
		if not self._isOpen then
			self:_showWheel()
		end
	end)
end

-- UI 생성
function LuckySpinController:_createUI()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LuckySpinGui"
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.DisplayOrder = 18
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	-- Overlay (터치 닫기 지원)
	local overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Visible = false
	overlay.Parent = screenGui

	overlay.MouseButton1Click:Connect(function()
		if not self._isSpinning then
			self:_hideWheel()
		end
	end)

	-- Main panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = ResponsiveUtil.clampedSize(340, 460, 0.90, 0.88)
	panel.Position = ResponsiveUtil.clampedPosition(340, 460, 0.90, 0.88)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(200, 100, 255)
	panelStroke.Thickness = 2
	panelStroke.Parent = panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "Lucky Spin!"
	title.TextColor3 = Color3.fromRGB(255, 200, 100)
	title.TextSize = ResponsiveUtil.scaledTextSize(22, 16)
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	-- Wheel container (clipped circle)
	local wheelContainer = Instance.new("Frame")
	wheelContainer.Name = "WheelContainer"
	local wheelSize = ResponsiveUtil.scaledOffset(260)
	wheelContainer.Size = UDim2.new(0, wheelSize, 0, wheelSize)
	wheelContainer.Position = UDim2.new(0.5, -wheelSize / 2, 0, ResponsiveUtil.scaledOffset(50))
	wheelContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	wheelContainer.ClipsDescendants = true
	wheelContainer.Parent = panel

	local wheelCorner = Instance.new("UICorner")
	wheelCorner.CornerRadius = UDim.new(0.5, 0)
	wheelCorner.Parent = wheelContainer

	-- Wheel frame (rotates)
	local wheelFrame = Instance.new("Frame")
	wheelFrame.Name = "Wheel"
	wheelFrame.Size = UDim2.new(1, 0, 1, 0)
	wheelFrame.Position = UDim2.new(0, 0, 0, 0)
	wheelFrame.BackgroundTransparency = 1
	wheelFrame.Parent = wheelContainer
	self._wheelFrame = wheelFrame

	-- Rotation tracking value
	local rotVal = Instance.new("NumberValue")
	rotVal.Name = "Rotation"
	rotVal.Value = 0
	rotVal.Parent = wheelFrame
	self._rotationValue = rotVal

	-- Create segments (text labels arranged in circle)
	local rewards = GameConstants.LUCKY_SPIN.REWARDS
	local segmentCount = #rewards
	local halfWheel = wheelSize / 2
	local segW = ResponsiveUtil.scaledOffset(80)
	local segH = ResponsiveUtil.scaledOffset(30)
	local segRadius = wheelSize * 0.346 -- 90/260 ratio
	for i, reward in rewards do
		local angle = (i - 1) * (360 / segmentCount)
		local segFrame = Instance.new("Frame")
		segFrame.Name = `Segment{i}`
		segFrame.Size = UDim2.new(0, segW, 0, segH)
		-- Position segments in a circle
		local rad = math.rad(angle - 90) -- start from top
		local cx = halfWheel + math.cos(rad) * segRadius - segW / 2
		local cy = halfWheel + math.sin(rad) * segRadius - segH / 2
		segFrame.Position = UDim2.new(0, cx, 0, cy)
		segFrame.BackgroundColor3 = SEGMENT_COLORS[(i - 1) % #SEGMENT_COLORS + 1]
		segFrame.BackgroundTransparency = 0.2
		segFrame.BorderSizePixel = 0
		segFrame.Parent = wheelFrame

		local segCorner = Instance.new("UICorner")
		segCorner.CornerRadius = UDim.new(0, 6)
		segCorner.Parent = segFrame

		local segLabel = Instance.new("TextLabel")
		segLabel.Name = "Label"
		segLabel.Size = UDim2.new(1, 0, 1, 0)
		segLabel.BackgroundTransparency = 1
		segLabel.Text = reward.name
		segLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		segLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
		segLabel.Font = Enum.Font.GothamBold
		segLabel.TextScaled = true
		segLabel.Parent = segFrame
	end

	-- Pointer (top center)
	local pointer = Instance.new("TextLabel")
	pointer.Name = "Pointer"
	pointer.Size = UDim2.new(0, ResponsiveUtil.scaledOffset(30), 0, ResponsiveUtil.scaledOffset(30))
	pointer.Position = UDim2.new(0.5, -ResponsiveUtil.scaledOffset(15), 0, ResponsiveUtil.scaledOffset(42))
	pointer.BackgroundTransparency = 1
	pointer.Text = "▼"
	pointer.TextColor3 = Color3.fromRGB(255, 50, 50)
	pointer.TextSize = ResponsiveUtil.scaledTextSize(24, 18)
	pointer.Font = Enum.Font.GothamBold
	pointer.ZIndex = 10
	pointer.Parent = panel

	-- Free spin button
	local spinButton = Instance.new("TextButton")
	spinButton.Name = "SpinButton"
	spinButton.Size = UDim2.new(0.42, 0, 0, ResponsiveUtil.scaledOffset(44))
	spinButton.Position = UDim2.new(0.04, 0, 1, -ResponsiveUtil.scaledOffset(80))
	spinButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
	spinButton.Text = "FREE Spin!"
	spinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	spinButton.TextSize = ResponsiveUtil.scaledTextSize(16, 12)
	spinButton.Font = Enum.Font.GothamBold
	spinButton.AutoButtonColor = true
	spinButton.Parent = panel
	self._spinButton = spinButton

	local spinBtnCorner = Instance.new("UICorner")
	spinBtnCorner.CornerRadius = UDim.new(0, 10)
	spinBtnCorner.Parent = spinButton

	-- Gem spin button
	local gemSpinBtn = Instance.new("TextButton")
	gemSpinBtn.Name = "GemSpinButton"
	gemSpinBtn.Size = UDim2.new(0.42, 0, 0, ResponsiveUtil.scaledOffset(44))
	gemSpinBtn.Position = UDim2.new(0.54, 0, 1, -ResponsiveUtil.scaledOffset(80))
	gemSpinBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
	gemSpinBtn.Text = `💎 {GameConstants.LUCKY_SPIN.EXTRA_SPIN_GEM_COST} Spin`
	gemSpinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	gemSpinBtn.TextSize = ResponsiveUtil.scaledTextSize(16, 12)
	gemSpinBtn.Font = Enum.Font.GothamBold
	gemSpinBtn.AutoButtonColor = true
	gemSpinBtn.Parent = panel
	self._gemSpinButton = gemSpinBtn

	local gemBtnCorner = Instance.new("UICorner")
	gemBtnCorner.CornerRadius = UDim.new(0, 10)
	gemBtnCorner.Parent = gemSpinBtn

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -40, 0, 8)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
	closeBtn.TextSize = ResponsiveUtil.scaledTextSize(18, 14)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel

	-- Result frame
	local resultFrame = Instance.new("Frame")
	resultFrame.Name = "ResultFrame"
	resultFrame.Size = UDim2.new(0.72, 0, 0, ResponsiveUtil.scaledOffset(80))
	resultFrame.Position = UDim2.new(0.14, 0, 0, ResponsiveUtil.scaledOffset(320))
	resultFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	resultFrame.BorderSizePixel = 0
	resultFrame.Visible = false
	resultFrame.Parent = panel
	self._resultFrame = resultFrame

	local resultCorner = Instance.new("UICorner")
	resultCorner.CornerRadius = UDim.new(0, 10)
	resultCorner.Parent = resultFrame

	local resultLabel = Instance.new("TextLabel")
	resultLabel.Name = "ResultLabel"
	resultLabel.Size = UDim2.new(1, 0, 1, 0)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Text = ""
	resultLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	resultLabel.TextSize = ResponsiveUtil.scaledTextSize(18, 14)
	resultLabel.Font = Enum.Font.GothamBold
	resultLabel.Parent = resultFrame

	-- Button events
	spinButton.MouseButton1Click:Connect(function()
		self:_requestSpin(false)
	end)

	gemSpinBtn.MouseButton1Click:Connect(function()
		self:_requestSpin(true)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		self:_hideWheel()
	end)

	-- Sync rotation with visual
	rotVal.Changed:Connect(function()
		if self._wheelFrame then
			self._wheelFrame.Rotation = rotVal.Value
		end
	end)
end

-- 스핀 요청
function LuckySpinController:_requestSpin(useGems: boolean)
	if self._isSpinning then
		return
	end
	self._isSpinning = true

	-- 버튼 비활성화
	if self._spinButton then
		self._spinButton.Active = false
	end
	if self._gemSpinButton then
		self._gemSpinButton.Active = false
	end

	-- 결과 숨기기
	if self._resultFrame then
		self._resultFrame.Visible = false
	end

	-- 서버에 요청
	RemoteEvents.SpinRequest:FireServer({ useGems = useGems })
end

-- 스핀 애니메이션 재생
function LuckySpinController:_playSpinAnimation(rewardId: string, callback: () -> ())
	if not self._rotationValue then
		if callback then
			callback()
		end
		return
	end

	-- 보상 인덱스 찾기
	local rewards = GameConstants.LUCKY_SPIN.REWARDS
	local targetIndex = 1
	for i, reward in rewards do
		if reward.id == rewardId then
			targetIndex = i
			break
		end
	end

	-- 목표 각도 계산 (해당 세그먼트에 멈춤)
	local segmentAngle = 360 / #rewards
	local targetAngle = -(targetIndex - 1) * segmentAngle
	-- 3~5바퀴 회전 + 목표 각도
	local fullRotations = (math.random(3, 5)) * 360
	local finalAngle = self._rotationValue.Value + fullRotations + targetAngle - (self._rotationValue.Value % 360)

	-- 스핀 트윈 (점진 감속)
	local spinTween = TweenService:Create(
		self._rotationValue,
		TweenInfo.new(3.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Value = finalAngle }
	)

	spinTween.Completed:Connect(function()
		if callback then
			callback()
		end
	end)
	spinTween:Play()
end

-- 결과 표시
function LuckySpinController:_showResult(data: any)
	if self._resultFrame then
		self._resultFrame.Visible = true
		local label = self._resultFrame:FindFirstChild("ResultLabel") :: TextLabel?
		if label then
			local icon = if data.type == "gems" then "💎" else "🪙"
			label.Text = `{icon} {data.rewardName}!`
		end
	end

	-- 버튼 다시 활성화
	self._isSpinning = false
	self:_updateButtons()
end

-- 버튼 상태 업데이트
function LuckySpinController:_updateButtons()
	if self._spinButton then
		if self._freeSpinsLeft > 0 then
			self._spinButton.Active = true
			self._spinButton.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
			self._spinButton.Text = "FREE Spin!"
		else
			self._spinButton.Active = false
			self._spinButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			self._spinButton.Text = "Used"
		end
	end

	if self._gemSpinButton then
		self._gemSpinButton.Active = true
		self._gemSpinButton.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
	end
end

-- 휠 보이기
function LuckySpinController:_showWheel()
	if self._isOpen then
		return
	end
	self._isOpen = true

	local overlay = self._screenGui and self._screenGui:FindFirstChild("Overlay") :: Frame?
	if overlay then
		overlay.Visible = true
	end

	local panel = self._screenGui and self._screenGui:FindFirstChild("Panel") :: Frame?
	if panel then
		panel.Visible = true
		panel.Size = UDim2.new(0, 0, 0, 0)
		panel.Position = UDim2.new(0.5, 0, 0.5, 0)

		local tween = TweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = ResponsiveUtil.clampedSize(340, 460, 0.90, 0.88),
			Position = ResponsiveUtil.clampedPosition(340, 460, 0.90, 0.88),
		})
		tween:Play()
	end
end

-- 휠 숨기기
function LuckySpinController:_hideWheel()
	if not self._isOpen then
		return
	end
	self._isOpen = false

	local panel = self._screenGui and self._screenGui:FindFirstChild("Panel") :: Frame?
	if panel then
		local tween = TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),
		})
		tween:Play()
		tween.Completed:Connect(function()
			if panel then
				panel.Visible = false
			end
		end)
	end

	local overlay = self._screenGui and self._screenGui:FindFirstChild("Overlay") :: Frame?
	if overlay then
		overlay.Visible = false
	end

	if self._resultFrame then
		self._resultFrame.Visible = false
	end
end

-- 이벤트 핸들러
function LuckySpinController:_setupEventHandlers()
	local conn = RemoteEvents.SpinResult.OnClientEvent:Connect(function(data)
		if data.error then
			-- 에러 처리
			self._isSpinning = false
			self:_updateButtons()

			if data.error == "not_enough_gems" then
				if self._resultFrame then
					self._resultFrame.Visible = true
					local label = self._resultFrame:FindFirstChild("ResultLabel") :: TextLabel?
					if label then
						label.Text = "Not enough gems!"
					end
				end
			end
			return
		end

		-- 무료 스핀 남은 횟수 업데이트
		self._freeSpinsLeft = data.freeSpinsLeft or 0

		-- 스핀 애니메이션 → 결과 표시
		self:_playSpinAnimation(data.rewardId, function()
			self:_showResult(data)
		end)
	end)
	table.insert(self._connections, conn)
end

-- 휠 열림 상태 확인
function LuckySpinController:IsOpen(): boolean
	return self._isOpen
end

-- 휠 닫기 (외부 호출용)
function LuckySpinController:Hide()
	if not self._isSpinning then
		self:_hideWheel()
	end
end

-- 정리
function LuckySpinController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	if self._screenGui then
		self._screenGui:Destroy()
	end
end

return LuckySpinController

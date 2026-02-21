--!strict
-- Login Reward Controller
-- 일일 출석 보상 UI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local LoginRewardController = {}
LoginRewardController.__index = LoginRewardController

export type LoginRewardController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_screenGui: ScreenGui?,
		_popupFrame: Frame?,
		_dayFrames: { Frame },
		_claimButton: TextButton?,
		_connections: { RBXScriptConnection },
		_isOpen: boolean,
	},
	LoginRewardController
))

function LoginRewardController.new(player: Player): LoginRewardController
	local self = setmetatable({
		_player = player,
		_screenGui = nil,
		_popupFrame = nil,
		_dayFrames = {},
		_claimButton = nil,
		_connections = {},
		_isOpen = false,
	}, LoginRewardController)

	self:_createUI()
	self:_setupEventHandlers()

	return self
end

-- UI 생성
function LoginRewardController:_createUI()
	local playerGui = self._player:WaitForChild("PlayerGui")

	-- ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LoginRewardGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 20
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	-- 어두운 배경
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.Parent = screenGui

	-- 팝업 프레임
	local popup = Instance.new("Frame")
	popup.Name = "PopupFrame"
	popup.Size = ResponsiveUtil.clampedSize(360, 420, 0.90, 0.85)
	popup.Position = ResponsiveUtil.clampedPosition(360, 420, 0.90, 0.85)
	popup.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	popup.BorderSizePixel = 0
	popup.Visible = false
	popup.Parent = screenGui
	self._popupFrame = popup

	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 16)
	popupCorner.Parent = popup

	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = Color3.fromRGB(255, 200, 50)
	popupStroke.Thickness = 2
	popupStroke.Parent = popup

	-- 타이틀
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "Daily Login Reward"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextSize = ResponsiveUtil.scaledTextSize(22, 16)
	title.Font = Enum.Font.GothamBold
	title.Parent = popup

	-- 스트릭 표시
	local streakLabel = Instance.new("TextLabel")
	streakLabel.Name = "StreakLabel"
	streakLabel.Size = UDim2.new(1, 0, 0, 24)
	streakLabel.Position = UDim2.new(0, 0, 0, 48)
	streakLabel.BackgroundTransparency = 1
	streakLabel.Text = ""
	streakLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	streakLabel.TextSize = ResponsiveUtil.scaledTextSize(14, 11)
	streakLabel.Font = Enum.Font.Gotham
	streakLabel.Parent = popup

	-- 7일 그리드
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "GridFrame"
	gridFrame.Size = UDim2.new(1, -ResponsiveUtil.scaledOffset(24), 0, ResponsiveUtil.scaledOffset(240))
	gridFrame.Position = UDim2.new(0, ResponsiveUtil.scaledOffset(12), 0, ResponsiveUtil.scaledOffset(80))
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = popup

	self._dayFrames = {}
	local rewards = GameConstants.LOGIN_REWARDS.REWARDS
	for i = 1, 7 do
		local row = math.ceil(i / 4) - 1
		local col = (i - 1) % 4
		local isSecondRow = (row == 1)
		-- Second row has 3 items, center them
		local cardW = ResponsiveUtil.scaledOffset(74)
		local cardH = ResponsiveUtil.scaledOffset(105)
		local spacing = ResponsiveUtil.scaledOffset(82)
		local xOffset = col * spacing + ResponsiveUtil.scaledOffset(4)
		if isSecondRow then
			xOffset = (col * spacing) + ResponsiveUtil.scaledOffset(45)
		end

		local dayFrame = Instance.new("Frame")
		dayFrame.Name = `Day{i}`
		dayFrame.Size = UDim2.new(0, cardW, 0, cardH)
		dayFrame.Position = UDim2.new(0, xOffset, 0, row * ResponsiveUtil.scaledOffset(120))
		dayFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
		dayFrame.BorderSizePixel = 0
		dayFrame.Parent = gridFrame

		local dayCorner = Instance.new("UICorner")
		dayCorner.CornerRadius = UDim.new(0, 8)
		dayCorner.Parent = dayFrame

		-- Day label
		local dayLabel = Instance.new("TextLabel")
		dayLabel.Name = "DayLabel"
		dayLabel.Size = UDim2.new(1, 0, 0, 20)
		dayLabel.Position = UDim2.new(0, 0, 0, 4)
		dayLabel.BackgroundTransparency = 1
		dayLabel.Text = `Day {i}`
		dayLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		dayLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
		dayLabel.Font = Enum.Font.Gotham
		dayLabel.Parent = dayFrame

		-- Reward icon (emoji)
		local rewardIcon = Instance.new("TextLabel")
		rewardIcon.Name = "RewardIcon"
		rewardIcon.Size = UDim2.new(1, 0, 0, 36)
		rewardIcon.Position = UDim2.new(0, 0, 0, 26)
		rewardIcon.BackgroundTransparency = 1
		local reward = rewards[i]
		rewardIcon.Text = if reward.type == "gems" then "◆" else "●"
		rewardIcon.TextSize = ResponsiveUtil.scaledTextSize(28, 20)
		rewardIcon.Font = Enum.Font.GothamBold
		rewardIcon.Parent = dayFrame

		-- Reward amount
		local rewardAmount = Instance.new("TextLabel")
		rewardAmount.Name = "RewardAmount"
		rewardAmount.Size = UDim2.new(1, 0, 0, 18)
		rewardAmount.Position = UDim2.new(0, 0, 0, 64)
		rewardAmount.BackgroundTransparency = 1
		rewardAmount.Text = tostring(reward.amount)
		rewardAmount.TextColor3 = Color3.fromRGB(255, 255, 255)
		rewardAmount.TextSize = ResponsiveUtil.scaledTextSize(14, 11)
		rewardAmount.Font = Enum.Font.GothamBold
		rewardAmount.Parent = dayFrame

		-- Check mark (for claimed days)
		local checkMark = Instance.new("TextLabel")
		checkMark.Name = "CheckMark"
		checkMark.Size = UDim2.new(1, 0, 0, 20)
		checkMark.Position = UDim2.new(0, 0, 0, 84)
		checkMark.BackgroundTransparency = 1
		checkMark.Text = ""
		checkMark.TextSize = ResponsiveUtil.scaledTextSize(14, 11)
		checkMark.Font = Enum.Font.GothamBold
		checkMark.Parent = dayFrame

		table.insert(self._dayFrames, dayFrame)
	end

	-- 수령 버튼
	local claimButton = Instance.new("TextButton")
	claimButton.Name = "ClaimButton"
	claimButton.Size = UDim2.new(0.6, 0, 0, ResponsiveUtil.scaledOffset(46))
	claimButton.Position = UDim2.new(0.2, 0, 1, -ResponsiveUtil.scaledOffset(60))
	claimButton.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
	claimButton.Text = "Claim!"
	claimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	claimButton.TextSize = ResponsiveUtil.scaledTextSize(18, 14)
	claimButton.Font = Enum.Font.GothamBold
	claimButton.AutoButtonColor = true
	claimButton.Parent = popup
	self._claimButton = claimButton

	local claimCorner = Instance.new("UICorner")
	claimCorner.CornerRadius = UDim.new(0, 10)
	claimCorner.Parent = claimButton

	-- 닫기 버튼
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 32, 0, 32)
	closeButton.Position = UDim2.new(1, -40, 0, 8)
	closeButton.BackgroundTransparency = 1
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(180, 180, 180)
	closeButton.TextSize = ResponsiveUtil.scaledTextSize(18, 14)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = popup

	-- 버튼 이벤트
	claimButton.MouseButton1Click:Connect(function()
		RemoteEvents.LoginRewardClaim:FireServer()
		claimButton.Active = false
		claimButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		claimButton.Text = "Claimed!"
	end)

	closeButton.MouseButton1Click:Connect(function()
		self:_hidePopup()
	end)
end

-- 팝업 표시 (Back easing)
function LoginRewardController:_showPopup()
	if self._isOpen then
		return
	end
	self._isOpen = true

	local overlay = self._screenGui and self._screenGui:FindFirstChild("Overlay") :: Frame?
	if overlay then
		overlay.Visible = true
	end

	if self._popupFrame then
		self._popupFrame.Visible = true
		self._popupFrame.Size = UDim2.new(0, 0, 0, 0)
		self._popupFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

		local appearTween =
			TweenService:Create(self._popupFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = ResponsiveUtil.clampedSize(360, 420, 0.90, 0.85),
				Position = ResponsiveUtil.clampedPosition(360, 420, 0.90, 0.85),
			})
		appearTween:Play()
	end
end

-- 팝업 숨기기 (Quad easing)
function LoginRewardController:_hidePopup()
	if not self._isOpen then
		return
	end
	self._isOpen = false

	if self._popupFrame then
		local disappearTween =
			TweenService:Create(self._popupFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0),
				Position = UDim2.new(0.5, 0, 0.5, 0),
			})
		disappearTween:Play()
		disappearTween.Completed:Connect(function()
			if self._popupFrame then
				self._popupFrame.Visible = false
			end
		end)
	end

	local overlay = self._screenGui and self._screenGui:FindFirstChild("Overlay") :: Frame?
	if overlay then
		overlay.Visible = false
	end
end

-- 7일 그리드 업데이트
function LoginRewardController:_updateGrid(data: any)
	local rewardDay = data.rewardDay or 1
	local alreadyClaimed = data.alreadyClaimed or false
	local loginStreak = data.loginStreak or 1
	local multiplier = data.multiplier or 1

	-- 스트릭 표시
	local streakLabel = self._popupFrame and self._popupFrame:FindFirstChild("StreakLabel") :: TextLabel?
	if streakLabel then
		local multText = if multiplier > 1 then ` (x{multiplier} bonus!)` else ""
		streakLabel.Text = `Streak: {loginStreak} days{multText}`
	end

	-- 각 날짜 프레임 업데이트
	for i, dayFrame in self._dayFrames do
		local checkMark = dayFrame:FindFirstChild("CheckMark") :: TextLabel?
		local dayStroke = dayFrame:FindFirstChild("DayStroke") :: UIStroke?

		-- 기존 stroke 제거
		if dayStroke then
			dayStroke:Destroy()
		end

		if i < rewardDay then
			-- 이전 날짜 (수령 완료)
			dayFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
			if checkMark then
				checkMark.Text = "✓"
				checkMark.TextColor3 = Color3.fromRGB(100, 200, 100)
			end
		elseif i == rewardDay then
			-- 오늘 (하이라이트)
			if alreadyClaimed then
				dayFrame.BackgroundColor3 = Color3.fromRGB(40, 80, 50)
				if checkMark then
					checkMark.Text = "✓"
					checkMark.TextColor3 = Color3.fromRGB(100, 255, 100)
				end
			else
				dayFrame.BackgroundColor3 = Color3.fromRGB(80, 60, 20)
				local stroke = Instance.new("UIStroke")
				stroke.Name = "DayStroke"
				stroke.Color = Color3.fromRGB(255, 200, 50)
				stroke.Thickness = 2
				stroke.Parent = dayFrame
				if checkMark then
					checkMark.Text = "TODAY"
					checkMark.TextColor3 = Color3.fromRGB(255, 220, 100)
				end
			end
		else
			-- 미래 날짜
			dayFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
			if checkMark then
				checkMark.Text = ""
			end
		end
	end

	-- 수령 버튼 상태
	if self._claimButton then
		if alreadyClaimed then
			self._claimButton.Active = false
			self._claimButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			self._claimButton.Text = "Claimed!"
		else
			self._claimButton.Active = true
			self._claimButton.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
			self._claimButton.Text = "Claim!"
		end
	end
end

-- 이벤트 핸들러 설정
function LoginRewardController:_setupEventHandlers()
	local conn = RemoteEvents.LoginRewardData.OnClientEvent:Connect(function(data)
		self:_updateGrid(data)

		-- 보상 수령 연출
		if data.justClaimed then
			-- 이미 열려 있으면 그리드만 업데이트
			print(`[LoginRewardController] Claimed reward: {data.reward.amount} {data.reward.type}`)
		else
			-- 팝업 표시 (미수령 시에만)
			if not data.alreadyClaimed then
				task.delay(1, function()
					self:_showPopup()
				end)
			end
		end
	end)
	table.insert(self._connections, conn)
end

-- 정리
function LoginRewardController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	if self._screenGui then
		self._screenGui:Destroy()
	end
end

return LoginRewardController

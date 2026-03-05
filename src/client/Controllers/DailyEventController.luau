--!strict
-- Daily Event Controller
-- 데일리 이벤트 로비 배너 + 게임 중 HUD

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local DailyEventController = {}
DailyEventController.__index = DailyEventController

export type DailyEventController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_connections: { RBXScriptConnection },
		_lobbyGui: ScreenGui?,
		_hudGui: ScreenGui?,
		_hudProgressBar: Frame?,
		_hudLabel: TextLabel?,
		_currentTheme: any?,
		_currentProgress: number,
		_goalCompleted: boolean,
		_isGameActive: boolean,
		_dismissed: boolean,
		_pulseConnection: RBXScriptConnection?,
	},
	DailyEventController
))

-- Theme icons by theme id
local THEME_ICONS: { [string]: string } = {
	golden = "🌟",
	cherry = "🍒",
	star = "⭐",
	speed = "⚡",
	heart = "❤️",
	diamond = "💎",
	rainbow = "🌈",
}

function DailyEventController.new(player: Player): DailyEventController
	local self = setmetatable({
		_player = player,
		_connections = {},
		_lobbyGui = nil,
		_hudGui = nil,
		_hudProgressBar = nil,
		_hudLabel = nil,
		_currentTheme = nil,
		_currentProgress = 0,
		_goalCompleted = false,
		_isGameActive = false,
		_dismissed = false,
		_pulseConnection = nil,
	}, DailyEventController)

	self:_createLobbyBanner()
	self:_createHud()
	self:_setupEventHandlers()

	return self
end

-- Lobby banner: shown in lobby, top-center below level bar
function DailyEventController:_createLobbyBanner()
	local player = self._player
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DailyEventBannerUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Enabled = false
	gui.Parent = playerGui
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	self._lobbyGui = gui

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Size = ResponsiveUtil.clampedSize(300, 54, 0.80, 0.12)
	banner.Position = UDim2.new(0.5, -math.min(150, ResponsiveUtil.getViewportSize().X * 0.40), 0, math.max(70, ResponsiveUtil.scaledOffset(90)))
	banner.BackgroundColor3 = Color3.fromRGB(15, 20, 45)
	banner.BackgroundTransparency = 0.15
	banner.BorderSizePixel = 0
	banner.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Name = "BannerStroke"
	stroke.Color = Color3.fromRGB(100, 140, 255)
	stroke.Thickness = 2
	stroke.Parent = banner

	-- Top row: icon + displayName
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -12, 0, 22)
	titleLabel.Position = UDim2.new(0, 8, 0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
	titleLabel.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "📅 데일리 이벤트 로딩 중..."
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Parent = banner

	-- Bottom row: goalDesc + reward (narrowed to leave room for close button)
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescLabel"
	descLabel.Size = UDim2.new(1, -40, 0, 18)
	descLabel.Position = UDim2.new(0, 8, 0, 28)
	descLabel.BackgroundTransparency = 1
	descLabel.TextColor3 = Color3.fromRGB(150, 170, 220)
	descLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
	descLabel.Font = Enum.Font.Gotham
	descLabel.Text = ""
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = banner

	-- Close (X) button: top-right corner of banner
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -28, 0, 4)
	closeBtn.AnchorPoint = Vector2.new(0, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
	closeBtn.BackgroundTransparency = 0.3
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "✕"
	closeBtn.ZIndex = 5
	closeBtn.Parent = banner

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 6)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self._dismissed = true
		if self._lobbyGui then
			self._lobbyGui.Enabled = false
		end
	end)
end

-- In-game HUD: top-right, shows progress during run
function DailyEventController:_createHud()
	local player = self._player
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DailyEventHudUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.Parent = playerGui
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	self._hudGui = gui

	local hudFrame = Instance.new("Frame")
	hudFrame.Name = "HudFrame"
	hudFrame.Size = UDim2.new(0, math.max(140, ResponsiveUtil.scaledOffset(160)), 0, math.max(40, ResponsiveUtil.scaledOffset(46)))
	hudFrame.Position = UDim2.new(1, -math.max(150, ResponsiveUtil.scaledOffset(170)), 0, math.max(130, ResponsiveUtil.scaledOffset(155))) -- 메인 HUD(~138px) 아래에 배치
	hudFrame.BackgroundColor3 = Color3.fromRGB(10, 15, 35)
	hudFrame.BackgroundTransparency = 0.2
	hudFrame.BorderSizePixel = 0
	hudFrame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = hudFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 120, 220)
	stroke.Thickness = 1.5
	stroke.Parent = hudFrame

	-- Goal label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -8, 0, 22)
	label.Position = UDim2.new(0, 6, 0, 2)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(200, 220, 255)
	label.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
	label.Font = Enum.Font.GothamBold
	label.Text = "이벤트 목표"
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = hudFrame
	self._hudLabel = label

	-- Progress bar background
	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(1, -12, 0, 10)
	barBg.Position = UDim2.new(0, 6, 0, 28)
	barBg.BackgroundColor3 = Color3.fromRGB(30, 35, 60)
	barBg.BorderSizePixel = 0
	barBg.Parent = hudFrame

	local barBgCorner = Instance.new("UICorner")
	barBgCorner.CornerRadius = UDim.new(0, 4)
	barBgCorner.Parent = barBg

	-- Progress bar fill
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	self._hudProgressBar = fill

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill
end

-- Event handlers
function DailyEventController:_setupEventHandlers()
	-- Receive full event data
	local dataConn = RemoteEvents.DailyEventData.OnClientEvent:Connect(function(data)
		-- Reset dismissed state when a new event day arrives
		local prevThemeId = self._currentTheme and self._currentTheme.themeId
		if prevThemeId ~= data.themeId then
			self._dismissed = false
		end
		self._currentTheme = data
		self._currentProgress = data.progress or 0
		self._goalCompleted = data.completed == true
		self:_refreshLobbyBanner()
		if self._isGameActive then
			self:_refreshHud()
		end
	end)
	table.insert(self._connections, dataConn)

	-- Receive progress updates during run
	local progressConn = RemoteEvents.DailyEventProgress.OnClientEvent:Connect(function(data)
		self._currentProgress = data.progress or 0
		if data.completed and not self._goalCompleted then
			self._goalCompleted = true
			self:_showCompletionEffect()
		end
		if self._isGameActive then
			self:_refreshHud()
		end
	end)
	table.insert(self._connections, progressConn)
end

-- Refresh lobby banner content
function DailyEventController:_refreshLobbyBanner()
	local gui = self._lobbyGui
	if not gui then
		return
	end

	local banner = gui:FindFirstChild("Banner")
	if not banner then
		return
	end

	local titleLabel = banner:FindFirstChild("TitleLabel") :: TextLabel?
	local descLabel = banner:FindFirstChild("DescLabel") :: TextLabel?
	local stroke = banner:FindFirstChild("BannerStroke") :: UIStroke?

	local theme = self._currentTheme
	if not theme then
		if titleLabel then
			titleLabel.Text = "📅 데일리 이벤트 로딩 중..."
		end
		return
	end

	local icon = THEME_ICONS[theme.themeId] or "🎯"

	if self._goalCompleted then
		-- Completed state: gold color
		if titleLabel then
			titleLabel.Text = `{icon} {theme.displayName} · CLEAR! ✅`
			titleLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
		end
		if descLabel then
			local rewardText = if theme.rewardType == "gems"
				then `💎 {theme.rewardAmount} 젬 + 💎 {theme.bonusGems} 보너스`
				else `🪙 {theme.rewardAmount} 코인 + 💎 {theme.bonusGems} 젬`
			descLabel.Text = `완료! 보상: {rewardText}`
			descLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
		end
		if stroke then
			stroke.Color = Color3.fromRGB(255, 200, 50)
		end
	else
		-- Incomplete state
		if titleLabel then
			titleLabel.Text = `{icon} {theme.displayName}`
			titleLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
		end
		if descLabel then
			local progress = self._currentProgress
			local target = theme.goalTarget
			local rewardText = if theme.rewardType == "gems"
				then `💎 {theme.rewardAmount} 젬`
				else `🪙 {theme.rewardAmount} 코인`
			descLabel.Text = `{theme.goalDesc} ({progress}/{target}) → {rewardText}`
			descLabel.TextColor3 = Color3.fromRGB(150, 170, 220)
		end
		if stroke then
			stroke.Color = Color3.fromRGB(100, 140, 255)
		end

		-- Pulse animation for incomplete events
		self:_startPulse(banner)
	end
end

-- Refresh in-game HUD
function DailyEventController:_refreshHud()
	local theme = self._currentTheme
	if not theme then
		return
	end

	local label = self._hudLabel
	local fill = self._hudProgressBar

	if self._goalCompleted then
		if label then
			label.Text = "이벤트 CLEAR! ✅"
			label.TextColor3 = Color3.fromRGB(255, 215, 80)
		end
		if fill then
			TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 1, 0) }):Play()
			fill.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
		end
	else
		local progress = self._currentProgress
		local target = theme.goalTarget
		local ratio = math.clamp(progress / math.max(target, 1), 0, 1)

		if label then
			label.Text = `{theme.coinName}: {progress}/{target}`
			label.TextColor3 = Color3.fromRGB(200, 220, 255)
		end
		if fill then
			TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(ratio, 0, 1, 0),
			}):Play()
			fill.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
		end
	end
end

-- Completion celebration effect
function DailyEventController:_showCompletionEffect()
	local gui = self._hudGui
	if not gui then
		return
	end

	local label = Instance.new("TextLabel")
	label.Name = "EventClear"
	label.Size = UDim2.new(0, 280, 0, 60)
	label.Position = UDim2.new(0.5, -140, 0.4, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextSize = ResponsiveUtil.scaledTextSize(12, 9)
	label.Font = Enum.Font.GothamBlack
	label.Text = "🎉 이벤트 CLEAR!"
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(180, 100, 0)
	label.ZIndex = 20
	label.Parent = gui

	TweenService:Create(
		label,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ TextSize = 44 }
	):Play()

	task.delay(2, function()
		if label and label.Parent then
			TweenService:Create(
				label,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			):Play()
			task.delay(0.5, function()
				if label and label.Parent then
					label:Destroy()
				end
			end)
		end
	end)

	print("[DailyEventController] Event completion effect shown")
end

-- Pulse animation on lobby banner (stops when completed)
function DailyEventController:_startPulse(banner: Frame)
	if self._pulseConnection then
		self._pulseConnection:Disconnect()
		self._pulseConnection = nil
	end

	local stroke = banner:FindFirstChild("BannerStroke") :: UIStroke?
	if not stroke then
		return
	end

	local t = 0
	self._pulseConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
		if self._goalCompleted then
			if self._pulseConnection then
				self._pulseConnection:Disconnect()
				self._pulseConnection = nil
			end
			return
		end
		t = (t + dt * 1.5) % (math.pi * 2)
		local alpha = (math.sin(t) + 1) / 2
		stroke.Transparency = alpha * 0.6
	end)
end

-- Called at game start (show HUD)
function DailyEventController:StartGame()
	self._isGameActive = true
	if self._hudGui then
		self._hudGui.Enabled = true
	end
	if self._lobbyGui then
		self._lobbyGui.Enabled = false
	end
	self:_refreshHud()
end

-- Called at game over (hide HUD)
function DailyEventController:EndGame()
	self._isGameActive = false
	if self._hudGui then
		self._hudGui.Enabled = false
	end
end

-- Called when returning to lobby (show banner if not dismissed)
function DailyEventController:ShowInLobby()
	self._isGameActive = false
	if self._lobbyGui then
		self._lobbyGui.Enabled = not self._dismissed
	end
	if self._hudGui then
		self._hudGui.Enabled = false
	end
end

-- Cleanup
function DailyEventController:Destroy()
	if self._pulseConnection then
		self._pulseConnection:Disconnect()
		self._pulseConnection = nil
	end
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	if self._lobbyGui then
		self._lobbyGui:Destroy()
	end
	if self._hudGui then
		self._hudGui:Destroy()
	end
end

return DailyEventController

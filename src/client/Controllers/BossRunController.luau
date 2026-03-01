--!strict
-- BossRunController
-- 보스 런 클라이언트 HUD: 진행도 바, 타이머, 결과 화면

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local BossRunController = {}
BossRunController.__index = BossRunController

export type BossRunController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_connections: { RBXScriptConnection },
		_gui: ScreenGui?,
		_hudFrame: Frame?,
		_timerLabel: TextLabel?,
		_playerScoreBar: Frame?,
		_bossScoreBar: Frame?,
		_playerScoreLabel: TextLabel?,
		_bossScoreLabel: TextLabel?,
		_targetScoreLabel: TextLabel?,
		_bossNameLabel: TextLabel?,
		_isActive: boolean,
		_currentChapterId: string?,
		_currentTargetScore: number,
	},
	BossRunController
))

function BossRunController.new(): BossRunController
	local self = setmetatable({
		_player = Players.LocalPlayer,
		_connections = {},
		_gui = nil,
		_hudFrame = nil,
		_timerLabel = nil,
		_playerScoreBar = nil,
		_bossScoreBar = nil,
		_playerScoreLabel = nil,
		_bossScoreLabel = nil,
		_targetScoreLabel = nil,
		_bossNameLabel = nil,
		_isActive = false,
		_currentChapterId = nil,
		_currentTargetScore = 500,
	}, BossRunController)

	self:_createGui()
	self:_setupEventHandlers()

	return self
end

-- ==================== GUI 생성 ====================

function BossRunController:_createGui()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "BossRunGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 16
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	-- HUD 프레임 (화면 상단 중앙)
	local hudFrame = Instance.new("Frame")
	hudFrame.Name = "BossRunHud"
	hudFrame.Size = UDim2.new(0, 320, 0, 82)
	hudFrame.Position = UDim2.new(0.5, -160, 0, 8)
	hudFrame.BackgroundColor3 = Color3.fromRGB(20, 10, 10)
	hudFrame.BackgroundTransparency = 0.15
	hudFrame.BorderSizePixel = 0
	hudFrame.Parent = gui
	self._hudFrame = hudFrame

	local hudCorner = Instance.new("UICorner")
	hudCorner.CornerRadius = UDim.new(0, 10)
	hudCorner.Parent = hudFrame

	local hudStroke = Instance.new("UIStroke")
	hudStroke.Color = Color3.fromRGB(200, 50, 50)
	hudStroke.Thickness = 2
	hudStroke.Parent = hudFrame

	-- 보스 이름 레이블
	local bossNameLabel = Instance.new("TextLabel")
	bossNameLabel.Name = "BossNameLabel"
	bossNameLabel.Size = UDim2.new(1, -70, 0, 18)
	bossNameLabel.Position = UDim2.new(0, 8, 0, 4)
	bossNameLabel.BackgroundTransparency = 1
	bossNameLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	bossNameLabel.TextSize = 12
	bossNameLabel.Font = Enum.Font.GothamBold
	bossNameLabel.Text = "🦊 VS ?"
	bossNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	bossNameLabel.Parent = hudFrame
	self._bossNameLabel = bossNameLabel

	-- 타이머 레이블
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(0, 60, 0, 18)
	timerLabel.Position = UDim2.new(1, -66, 0, 4)
	timerLabel.BackgroundTransparency = 1
	timerLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	timerLabel.TextSize = 14
	timerLabel.Font = Enum.Font.GothamBlack
	timerLabel.Text = "90s"
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	timerLabel.Parent = hudFrame
	self._timerLabel = timerLabel

	-- 진행 바 배경
	local progBg = Instance.new("Frame")
	progBg.Name = "ProgressBarBg"
	progBg.Size = UDim2.new(1, -16, 0, 20)
	progBg.Position = UDim2.new(0, 8, 0, 26)
	progBg.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	progBg.BorderSizePixel = 0
	progBg.Parent = hudFrame

	local progBgCorner = Instance.new("UICorner")
	progBgCorner.CornerRadius = UDim.new(0, 6)
	progBgCorner.Parent = progBg

	-- 플레이어 점수 바 (좌→우, 초록)
	local playerScoreBar = Instance.new("Frame")
	playerScoreBar.Name = "PlayerScoreBar"
	playerScoreBar.Size = UDim2.new(0, 0, 1, 0)
	playerScoreBar.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
	playerScoreBar.BorderSizePixel = 0
	playerScoreBar.Parent = progBg
	self._playerScoreBar = playerScoreBar

	local playerBarCorner = Instance.new("UICorner")
	playerBarCorner.CornerRadius = UDim.new(0, 6)
	playerBarCorner.Parent = playerScoreBar

	-- 보스 점수 바 (우→좌, 빨강)
	local bossScoreBar = Instance.new("Frame")
	bossScoreBar.Name = "BossScoreBar"
	bossScoreBar.Size = UDim2.new(0, 0, 1, 0)
	bossScoreBar.AnchorPoint = Vector2.new(1, 0)
	bossScoreBar.Position = UDim2.new(1, 0, 0, 0)
	bossScoreBar.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	bossScoreBar.BorderSizePixel = 0
	bossScoreBar.Parent = progBg
	self._bossScoreBar = bossScoreBar

	local bossBarCorner = Instance.new("UICorner")
	bossBarCorner.CornerRadius = UDim.new(0, 6)
	bossBarCorner.Parent = bossScoreBar

	-- 점수 레이블 행
	local scoreRow = Instance.new("Frame")
	scoreRow.Name = "ScoreRow"
	scoreRow.Size = UDim2.new(1, -16, 0, 16)
	scoreRow.Position = UDim2.new(0, 8, 0, 50)
	scoreRow.BackgroundTransparency = 1
	scoreRow.Parent = hudFrame

	local playerScoreLabel = Instance.new("TextLabel")
	playerScoreLabel.Name = "PlayerScore"
	playerScoreLabel.Size = UDim2.new(0.4, 0, 1, 0)
	playerScoreLabel.BackgroundTransparency = 1
	playerScoreLabel.TextColor3 = Color3.fromRGB(100, 230, 120)
	playerScoreLabel.TextSize = 11
	playerScoreLabel.Font = Enum.Font.GothamBold
	playerScoreLabel.Text = "🏃 0"
	playerScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	playerScoreLabel.Parent = scoreRow
	self._playerScoreLabel = playerScoreLabel

	local targetScoreLabel = Instance.new("TextLabel")
	targetScoreLabel.Name = "TargetScore"
	targetScoreLabel.Size = UDim2.new(0.2, 0, 1, 0)
	targetScoreLabel.Position = UDim2.new(0.4, 0, 0, 0)
	targetScoreLabel.BackgroundTransparency = 1
	targetScoreLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	targetScoreLabel.TextSize = 10
	targetScoreLabel.Font = Enum.Font.Gotham
	targetScoreLabel.Text = "목표: 500"
	targetScoreLabel.TextXAlignment = Enum.TextXAlignment.Center
	targetScoreLabel.Parent = scoreRow
	self._targetScoreLabel = targetScoreLabel

	local bossScoreLabel = Instance.new("TextLabel")
	bossScoreLabel.Name = "BossScore"
	bossScoreLabel.Size = UDim2.new(0.4, 0, 1, 0)
	bossScoreLabel.Position = UDim2.new(0.6, 0, 0, 0)
	bossScoreLabel.BackgroundTransparency = 1
	bossScoreLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	bossScoreLabel.TextSize = 11
	bossScoreLabel.Font = Enum.Font.GothamBold
	bossScoreLabel.Text = "🦊 0"
	bossScoreLabel.TextXAlignment = Enum.TextXAlignment.Right
	bossScoreLabel.Parent = scoreRow
	self._bossScoreLabel = bossScoreLabel
end

-- ==================== 이벤트 핸들러 ====================

function BossRunController:_setupEventHandlers()
	local conn1 = RemoteEvents.BossRunStart.OnClientEvent:Connect(function(data)
		self:Show(data)
	end)
	table.insert(self._connections, conn1)

	local conn2 = RemoteEvents.BossRunScoreUpdate.OnClientEvent:Connect(function(data)
		self:UpdateScore(data.playerScore, data.bossScore, data.timeRemaining)
	end)
	table.insert(self._connections, conn2)

	local conn3 = RemoteEvents.BossRunResult.OnClientEvent:Connect(function(data)
		self:ShowResult(data.success, data)
	end)
	table.insert(self._connections, conn3)
end

-- ==================== HUD 표시/업데이트 ====================

function BossRunController:Show(data: any)
	self._isActive = true
	self._currentChapterId = data.chapterId
	self._currentTargetScore = data.targetScore

	-- 보스 이름 설정
	if self._bossNameLabel then
		self._bossNameLabel.Text = `🦊 VS {data.bossName}`
	end
	if self._targetScoreLabel then
		self._targetScoreLabel.Text = `목표: {data.targetScore}`
	end
	if self._timerLabel then
		self._timerLabel.Text = `{data.timeLimit}s`
	end

	-- HUD 표시
	if self._gui then
		self._gui.Enabled = true
	end

	-- 입장 애니메이션
	if self._hudFrame then
		self._hudFrame.Position = UDim2.new(0.5, -160, 0, -100)
		TweenService:Create(self._hudFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -160, 0, 8),
		}):Play()
	end
end

function BossRunController:UpdateScore(playerScore: number, bossScore: number, timeRemaining: number)
	if not self._isActive then
		return
	end

	local target = self._currentTargetScore
	local playerRatio = math.min(playerScore / target, 1)
	local bossRatio = math.min(bossScore / target, 1)

	-- 점수 바 업데이트
	if self._playerScoreBar then
		TweenService:Create(self._playerScoreBar, TweenInfo.new(0.3), {
			Size = UDim2.new(playerRatio, 0, 1, 0),
		}):Play()
	end
	if self._bossScoreBar then
		TweenService:Create(self._bossScoreBar, TweenInfo.new(0.3), {
			Size = UDim2.new(bossRatio, 0, 1, 0),
		}):Play()
	end

	-- 레이블 업데이트
	if self._playerScoreLabel then
		self._playerScoreLabel.Text = `🏃 {playerScore}`
	end
	if self._bossScoreLabel then
		self._bossScoreLabel.Text = `🦊 {bossScore}`
	end
	if self._timerLabel then
		local seconds = math.ceil(timeRemaining)
		self._timerLabel.Text = `{seconds}s`
		-- 10초 이하 시 빨간색
		self._timerLabel.TextColor3 = if seconds <= 10
			then Color3.fromRGB(255, 80, 80)
			else Color3.fromRGB(255, 200, 100)
	end
end

function BossRunController:Hide()
	self._isActive = false
	if self._gui then
		self._gui.Enabled = false
	end
end

-- ==================== 결과 화면 ====================

function BossRunController:ShowResult(success: boolean, data: any)
	self._isActive = false

	local playerGui = self._player:WaitForChild("PlayerGui")

	local resultGui = Instance.new("ScreenGui")
	resultGui.Name = "BossRunResultGui"
	resultGui.ResetOnSpawn = false
	resultGui.DisplayOrder = 25
	resultGui.Parent = playerGui

	-- 배경 딤
	local dimBg = Instance.new("Frame")
	dimBg.Size = UDim2.new(1, 0, 1, 0)
	dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimBg.BackgroundTransparency = 0.5
	dimBg.BorderSizePixel = 0
	dimBg.Parent = resultGui

	-- 결과 카드
	local card = Instance.new("Frame")
	card.Name = "ResultCard"
	card.Size = UDim2.new(0, 320, 0, 260)
	card.Position = UDim2.new(0.5, -160, 0.5, -130)
	card.BackgroundColor3 = if success then Color3.fromRGB(15, 30, 15) else Color3.fromRGB(30, 10, 10)
	card.BorderSizePixel = 0
	card.Parent = resultGui

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = if success then Color3.fromRGB(80, 220, 100) else Color3.fromRGB(220, 60, 60)
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	-- 결과 이모지
	local resultEmoji = Instance.new("TextLabel")
	resultEmoji.Size = UDim2.new(1, 0, 0, 60)
	resultEmoji.Position = UDim2.new(0, 0, 0, 10)
	resultEmoji.BackgroundTransparency = 1
	resultEmoji.Text = if success then "🏆" else "💀"
	resultEmoji.TextSize = 48
	resultEmoji.Font = Enum.Font.GothamBold
	resultEmoji.Parent = card

	-- 결과 제목
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 30)
	titleLabel.Position = UDim2.new(0, 10, 0, 72)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = if success then Color3.fromRGB(100, 255, 120) else Color3.fromRGB(255, 100, 100)
	titleLabel.TextSize = 22
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = if success then "보스 런 클리어!" else "도전 실패..."
	titleLabel.Parent = card

	-- 점수 정보
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Size = UDim2.new(1, -20, 0, 20)
	scoreLabel.Position = UDim2.new(0, 10, 0, 108)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	scoreLabel.TextSize = 14
	scoreLabel.Font = Enum.Font.Gotham
	scoreLabel.Text = `점수: {data.playerScore} / {data.targetScore}`
	scoreLabel.Parent = card

	-- 보상 (성공 시)
	if success and data.rewards then
		local rewardLabel = Instance.new("TextLabel")
		rewardLabel.Size = UDim2.new(1, -20, 0, 24)
		rewardLabel.Position = UDim2.new(0, 10, 0, 132)
		rewardLabel.BackgroundTransparency = 1
		rewardLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
		rewardLabel.TextSize = 14
		rewardLabel.Font = Enum.Font.GothamBold
		rewardLabel.Text = `🪙 +{data.rewards.coins}코인   💎 +{data.rewards.gems}젬`
		rewardLabel.Parent = card
	end

	local btnY = if success then 170 else 160

	-- 확인/재도전 버튼
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(1, -24, 0, 44)
	confirmBtn.Position = UDim2.new(0, 12, 0, btnY)
	confirmBtn.BackgroundColor3 = if success
		then Color3.fromRGB(40, 140, 60)
		else Color3.fromRGB(60, 40, 140)
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.TextSize = 16
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.Text = if success then "계속하기" else "재도전"
	confirmBtn.Parent = card

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 10)
	confirmCorner.Parent = confirmBtn

	-- 포기 버튼 (실패 시)
	if not success then
		local giveUpBtn = Instance.new("TextButton")
		giveUpBtn.Size = UDim2.new(1, -24, 0, 32)
		giveUpBtn.Position = UDim2.new(0, 12, 0, 220)
		giveUpBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
		giveUpBtn.TextColor3 = Color3.fromRGB(200, 150, 150)
		giveUpBtn.TextSize = 13
		giveUpBtn.Font = Enum.Font.Gotham
		giveUpBtn.Text = "포기 (로비로 돌아가기)"
		giveUpBtn.Parent = card

		local giveUpCorner = Instance.new("UICorner")
		giveUpCorner.CornerRadius = UDim.new(0, 8)
		giveUpCorner.Parent = giveUpBtn

		giveUpBtn.MouseButton1Click:Connect(function()
			RemoteEvents.BossRunGiveUp:FireServer()
			resultGui:Destroy()
			if self._gui then
				self._gui.Enabled = false
			end
		end)
	end

	-- 등장 애니메이션
	card.Position = UDim2.new(0.5, -160, 0.5, -90)
	card.BackgroundTransparency = 1
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -160, 0.5, -130),
		BackgroundTransparency = 0,
	}):Play()

	confirmBtn.MouseButton1Click:Connect(function()
		if not success then
			-- 재도전
			RemoteEvents.BossRunRetry:FireServer({ chapterId = data.chapterId })
		end
		resultGui:Destroy()
		if self._gui then
			self._gui.Enabled = false
		end
	end)
end

return BossRunController

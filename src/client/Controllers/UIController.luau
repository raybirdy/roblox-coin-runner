--!strict
-- UI Controller
-- 게임 UI 관리 (점수, 코인, 라이프 표시)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local UIController = {}
UIController.__index = UIController

export type UIController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_playerGui: PlayerGui,
		_screenGui: ScreenGui?,
		_scoreLabel: TextLabel?,
		_coinsLabel: TextLabel?,
		_livesLabel: TextLabel?,
		_livesContainer: Frame?,
		_heartLabels: { TextLabel },
		_currentLives: number,
		_distanceLabel: TextLabel?,
		_gameOverFrame: Frame?,
		_startMenuFrame: Frame?,
		_jumpButton: TextButton?,
		_slideButton: TextButton?,
		_tutorialBanner: Frame?, -- 튜토리얼 배너
		_tutorialNotification: Frame?, -- 튜토리얼 종료 알림
		_countdownLabel: TextLabel?, -- 카운트다운 표시
		_connections: { RBXScriptConnection },
		_onJumpCallback: (() -> ())?,
		_onSlideCallback: (() -> ())?,
	},
	UIController
))

function UIController.new(player: Player): UIController
	local self = setmetatable({
		_player = player,
		_playerGui = player:WaitForChild("PlayerGui") :: PlayerGui,
		_screenGui = nil,
		_scoreLabel = nil,
		_coinsLabel = nil,
		_livesLabel = nil,
		_livesContainer = nil,
		_heartLabels = {},
		_currentLives = GameConstants.LIFE.STARTING_LIVES,
		_distanceLabel = nil,
		_gameOverFrame = nil,
		_startMenuFrame = nil,
		_jumpButton = nil,
		_slideButton = nil,
		_tutorialBanner = nil,
		_tutorialNotification = nil,
		_countdownLabel = nil,
		_connections = {},
		_onJumpCallback = nil,
		_onSlideCallback = nil,
	}, UIController)

	self:_createUI()
	self:_createMobileControls()
	self:_setupEventHandlers()
	self:ShowStartMenu() -- 시작 시 메뉴 표시

	return self
end

-- UI 생성
function UIController:_createUI()
	-- ScreenGui 생성
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = self._playerGui
	self._screenGui = screenGui

	-- 점수 표시 (상단 중앙)
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(0, 200, 0, 50)
	scoreLabel.Position = UDim2.new(0.5, -100, 0, 10)
	scoreLabel.BackgroundTransparency = 0.3
	scoreLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	scoreLabel.TextSize = 24
	scoreLabel.Font = Enum.Font.GothamBold
	scoreLabel.Text = "Score: 0"
	scoreLabel.Parent = screenGui
	self._scoreLabel = scoreLabel

	-- 둥근 모서리
	local scoreCorner = Instance.new("UICorner")
	scoreCorner.CornerRadius = UDim.new(0, 8)
	scoreCorner.Parent = scoreLabel

	-- 코인 표시 (상단 왼쪽)
	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "CoinsLabel"
	coinsLabel.Size = UDim2.new(0, 150, 0, 40)
	coinsLabel.Position = UDim2.new(0, 10, 0, 10)
	coinsLabel.BackgroundTransparency = 0.3
	coinsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- 금색
	coinsLabel.TextSize = 20
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.Text = "🪙 0"
	coinsLabel.Parent = screenGui
	self._coinsLabel = coinsLabel

	-- 둥근 모서리
	local coinsCorner = Instance.new("UICorner")
	coinsCorner.CornerRadius = UDim.new(0, 8)
	coinsCorner.Parent = coinsLabel

	-- 라이프 컨테이너 (상단 오른쪽)
	local livesContainer = Instance.new("Frame")
	livesContainer.Name = "LivesContainer"
	livesContainer.Size = UDim2.new(0, 150, 0, 50)
	livesContainer.Position = UDim2.new(1, -160, 0, 10)
	livesContainer.BackgroundTransparency = 0.3
	livesContainer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	livesContainer.Parent = screenGui
	self._livesContainer = livesContainer

	-- 둥근 모서리
	local livesCorner = Instance.new("UICorner")
	livesCorner.CornerRadius = UDim.new(0, 8)
	livesCorner.Parent = livesContainer

	-- 개별 하트 생성
	self._heartLabels = {}
	for i = 1, GameConstants.LIFE.STARTING_LIVES do
		local heart = Instance.new("TextLabel")
		heart.Name = `Heart{i}`
		heart.Size = UDim2.new(0, 40, 0, 40)
		heart.Position = UDim2.new(0, 10 + (i - 1) * 45, 0.5, -20)
		heart.BackgroundTransparency = 1
		heart.TextColor3 = Color3.fromRGB(255, 50, 50)
		heart.TextSize = 32
		heart.Font = Enum.Font.GothamBold
		heart.Text = "❤️"
		heart.Parent = livesContainer
		table.insert(self._heartLabels, heart)
	end

	-- 기존 livesLabel은 숨김 처리 (호환성)
	local livesLabel = Instance.new("TextLabel")
	livesLabel.Name = "LivesLabel"
	livesLabel.Visible = false
	livesLabel.Parent = screenGui
	self._livesLabel = livesLabel

	-- 거리 표시 (점수 아래)
	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "DistanceLabel"
	distanceLabel.Size = UDim2.new(0, 200, 0, 40)
	distanceLabel.Position = UDim2.new(0.5, -100, 0, 65)
	distanceLabel.BackgroundTransparency = 0.3
	distanceLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	distanceLabel.TextColor3 = Color3.fromRGB(100, 200, 255) -- 파란색
	distanceLabel.TextSize = 18
	distanceLabel.Font = Enum.Font.Gotham
	distanceLabel.Text = "Distance: 0m"
	distanceLabel.Parent = screenGui
	self._distanceLabel = distanceLabel

	-- 둥근 모서리
	local distanceCorner = Instance.new("UICorner")
	distanceCorner.CornerRadius = UDim.new(0, 8)
	distanceCorner.Parent = distanceLabel

	-- 게임 오버 프레임 (초기 숨김)
	local gameOverFrame = Instance.new("Frame")
	gameOverFrame.Name = "GameOverFrame"
	gameOverFrame.Size = UDim2.new(0, 450, 0, 480)
	gameOverFrame.Position = UDim2.new(0.5, -225, 0.5, -240)
	gameOverFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	gameOverFrame.BackgroundTransparency = 0.15
	gameOverFrame.Visible = false
	gameOverFrame.Parent = screenGui
	self._gameOverFrame = gameOverFrame

	-- 둥근 모서리
	local gameOverCorner = Instance.new("UICorner")
	gameOverCorner.CornerRadius = UDim.new(0, 20)
	gameOverCorner.Parent = gameOverFrame

	-- 테두리
	local gameOverStroke = Instance.new("UIStroke")
	gameOverStroke.Color = Color3.fromRGB(255, 255, 255)
	gameOverStroke.Thickness = 3
	gameOverStroke.Transparency = 0.3
	gameOverStroke.Parent = gameOverFrame

	-- 게임 오버 텍스트
	local gameOverTitle = Instance.new("TextLabel")
	gameOverTitle.Name = "Title"
	gameOverTitle.Size = UDim2.new(1, 0, 0, 60)
	gameOverTitle.Position = UDim2.new(0, 0, 0, 20)
	gameOverTitle.BackgroundTransparency = 1
	gameOverTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	gameOverTitle.TextSize = 42
	gameOverTitle.Font = Enum.Font.GothamBold
	gameOverTitle.Text = "GAME OVER"
	gameOverTitle.Parent = gameOverFrame

	-- NEW RECORD 배지 (초기 숨김)
	local newRecordLabel = Instance.new("TextLabel")
	newRecordLabel.Name = "NewRecord"
	newRecordLabel.Size = UDim2.new(0, 200, 0, 40)
	newRecordLabel.Position = UDim2.new(0.5, -100, 0, 75)
	newRecordLabel.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	newRecordLabel.BackgroundTransparency = 0.1
	newRecordLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	newRecordLabel.TextSize = 22
	newRecordLabel.Font = Enum.Font.GothamBold
	newRecordLabel.Text = "🎉 NEW RECORD! 🎉"
	newRecordLabel.Visible = false
	newRecordLabel.Parent = gameOverFrame

	local newRecordCorner = Instance.new("UICorner")
	newRecordCorner.CornerRadius = UDim.new(0, 8)
	newRecordCorner.Parent = newRecordLabel

	-- 최종 점수
	local finalScoreLabel = Instance.new("TextLabel")
	finalScoreLabel.Name = "FinalScore"
	finalScoreLabel.Size = UDim2.new(1, 0, 0, 50)
	finalScoreLabel.Position = UDim2.new(0, 0, 0, 130)
	finalScoreLabel.BackgroundTransparency = 1
	finalScoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	finalScoreLabel.TextSize = 32
	finalScoreLabel.Font = Enum.Font.GothamBold
	finalScoreLabel.Text = "Score: 0"
	finalScoreLabel.Parent = gameOverFrame

	-- 거리 표시
	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "Distance"
	distanceLabel.Size = UDim2.new(1, 0, 0, 35)
	distanceLabel.Position = UDim2.new(0, 0, 0, 180)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	distanceLabel.TextSize = 20
	distanceLabel.Font = Enum.Font.Gotham
	distanceLabel.Text = "🏃 Distance: 0m"
	distanceLabel.Parent = gameOverFrame

	-- 획득 코인
	local earnedCoinsLabel = Instance.new("TextLabel")
	earnedCoinsLabel.Name = "EarnedCoins"
	earnedCoinsLabel.Size = UDim2.new(1, 0, 0, 35)
	earnedCoinsLabel.Position = UDim2.new(0, 0, 0, 220)
	earnedCoinsLabel.BackgroundTransparency = 1
	earnedCoinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	earnedCoinsLabel.TextSize = 20
	earnedCoinsLabel.Font = Enum.Font.Gotham
	earnedCoinsLabel.Text = "🪙 Coins: 0"
	earnedCoinsLabel.Parent = gameOverFrame

	-- 최고 점수
	local highScoreLabel = Instance.new("TextLabel")
	highScoreLabel.Name = "HighScore"
	highScoreLabel.Size = UDim2.new(1, 0, 0, 40)
	highScoreLabel.Position = UDim2.new(0, 0, 0, 270)
	highScoreLabel.BackgroundTransparency = 1
	highScoreLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	highScoreLabel.TextSize = 24
	highScoreLabel.Font = Enum.Font.GothamBold
	highScoreLabel.Text = "🏆 High Score: 0"
	highScoreLabel.Parent = gameOverFrame

	-- 재시작 버튼
	local restartButton = Instance.new("TextButton")
	restartButton.Name = "RestartButton"
	restartButton.Size = UDim2.new(0, 280, 0, 70)
	restartButton.Position = UDim2.new(0.5, -140, 0, 340)
	restartButton.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
	restartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	restartButton.TextSize = 32
	restartButton.Font = Enum.Font.GothamBold
	restartButton.Text = "▶ PLAY AGAIN"
	restartButton.Parent = gameOverFrame

	-- 둥근 모서리
	local restartCorner = Instance.new("UICorner")
	restartCorner.CornerRadius = UDim.new(0, 16)
	restartCorner.Parent = restartButton

	-- 버튼 테두리
	local restartStroke = Instance.new("UIStroke")
	restartStroke.Color = Color3.fromRGB(255, 255, 255)
	restartStroke.Thickness = 2
	restartStroke.Transparency = 0.5
	restartStroke.Parent = restartButton

	-- 버튼 클릭 이벤트
	restartButton.MouseButton1Click:Connect(function()
		self:OnRestartButtonClicked()
	end)

	-- 시작 메뉴 프레임 (초기 화면)
	local startMenuFrame = Instance.new("Frame")
	startMenuFrame.Name = "StartMenuFrame"
	startMenuFrame.Size = UDim2.new(0, 500, 0, 400)
	startMenuFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
	startMenuFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	startMenuFrame.BackgroundTransparency = 0.3
	startMenuFrame.Visible = false
	startMenuFrame.Parent = screenGui
	self._startMenuFrame = startMenuFrame

	-- 게임 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 80)
	titleLabel.Position = UDim2.new(0, 0, 0, 30)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = 48
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "COIN RUNNER"
	titleLabel.Parent = startMenuFrame

	-- 부제목
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.new(1, 0, 0, 30)
	subtitleLabel.Position = UDim2.new(0, 0, 0, 120)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	subtitleLabel.TextSize = 20
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Text = "Collect coins, dodge obstacles!"
	subtitleLabel.Parent = startMenuFrame

	-- 플레이 버튼
	local playButton = Instance.new("TextButton")
	playButton.Name = "PlayButton"
	playButton.Size = UDim2.new(0, 250, 0, 60)
	playButton.Position = UDim2.new(0.5, -125, 0, 200)
	playButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
	playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	playButton.TextSize = 32
	playButton.Font = Enum.Font.GothamBold
	playButton.Text = "PLAY"
	playButton.Parent = startMenuFrame

	-- 둥근 모서리
	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, 12)
	playCorner.Parent = playButton

	-- 플레이 버튼 클릭
	playButton.MouseButton1Click:Connect(function()
		self:OnPlayButtonClicked()
	end)

	-- 조작법 안내
	local controlsLabel = Instance.new("TextLabel")
	controlsLabel.Name = "Controls"
	controlsLabel.Size = UDim2.new(1, 0, 0, 80)
	controlsLabel.Position = UDim2.new(0, 0, 0, 290)
	controlsLabel.BackgroundTransparency = 1
	controlsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	controlsLabel.TextSize = 16
	controlsLabel.Font = Enum.Font.Gotham
	controlsLabel.Text = "Controls:\nJUMP: Space / W / ↑\nSLIDE: S / ↓"
	controlsLabel.Parent = startMenuFrame

	-- 튜토리얼 배너 (화면 상단)
	local tutorialBanner = Instance.new("Frame")
	tutorialBanner.Name = "TutorialBanner"
	tutorialBanner.Size = UDim2.new(0, 300, 0, 50)
	tutorialBanner.Position = UDim2.new(0.5, -150, 0, 120)
	tutorialBanner.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	tutorialBanner.BackgroundTransparency = 0.2
	tutorialBanner.Visible = false
	tutorialBanner.Parent = screenGui
	self._tutorialBanner = tutorialBanner

	local tutorialCorner = Instance.new("UICorner")
	tutorialCorner.CornerRadius = UDim.new(0, 12)
	tutorialCorner.Parent = tutorialBanner

	local tutorialStroke = Instance.new("UIStroke")
	tutorialStroke.Color = Color3.fromRGB(255, 255, 255)
	tutorialStroke.Thickness = 2
	tutorialStroke.Parent = tutorialBanner

	local tutorialLabel = Instance.new("TextLabel")
	tutorialLabel.Name = "Label"
	tutorialLabel.Size = UDim2.new(1, 0, 1, 0)
	tutorialLabel.BackgroundTransparency = 1
	tutorialLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tutorialLabel.TextSize = 22
	tutorialLabel.Font = Enum.Font.GothamBold
	tutorialLabel.Text = "연습 모드"
	tutorialLabel.Parent = tutorialBanner

	-- 튜토리얼 종료 알림 (화면 중앙)
	local tutorialNotification = Instance.new("Frame")
	tutorialNotification.Name = "TutorialNotification"
	tutorialNotification.Size = UDim2.new(0, 400, 0, 100)
	tutorialNotification.Position = UDim2.new(0.5, -200, 0.4, -50)
	tutorialNotification.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	tutorialNotification.BackgroundTransparency = 0.1
	tutorialNotification.Visible = false
	tutorialNotification.Parent = screenGui
	self._tutorialNotification = tutorialNotification

	local notificationCorner = Instance.new("UICorner")
	notificationCorner.CornerRadius = UDim.new(0, 16)
	notificationCorner.Parent = tutorialNotification

	local notificationStroke = Instance.new("UIStroke")
	notificationStroke.Color = Color3.fromRGB(255, 255, 255)
	notificationStroke.Thickness = 3
	notificationStroke.Parent = tutorialNotification

	local notificationLabel = Instance.new("TextLabel")
	notificationLabel.Name = "Label"
	notificationLabel.Size = UDim2.new(1, 0, 1, 0)
	notificationLabel.BackgroundTransparency = 1
	notificationLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	notificationLabel.TextSize = 28
	notificationLabel.Font = Enum.Font.GothamBold
	notificationLabel.Text = "연습 완료! 게임 시작!"
	notificationLabel.Parent = tutorialNotification

	-- 카운트다운 표시 (화면 중앙, 크게)
	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "CountdownLabel"
	countdownLabel.Size = UDim2.new(0, 300, 0, 200)
	countdownLabel.Position = UDim2.new(0.5, -150, 0.5, -100)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countdownLabel.TextSize = 120
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.Text = ""
	countdownLabel.TextStrokeTransparency = 0.3
	countdownLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	countdownLabel.Visible = false
	countdownLabel.ZIndex = 100 -- 다른 UI 위에 표시
	countdownLabel.Parent = screenGui
	self._countdownLabel = countdownLabel

	print("[UIController] UI created")
end

-- 모바일 컨트롤 생성
function UIController:_createMobileControls()
	if not self._screenGui then
		return
	end

	-- 점프 버튼 (오른쪽 하단)
	local jumpButton = Instance.new("TextButton")
	jumpButton.Name = "JumpButton"
	jumpButton.Size = UDim2.new(0, GameConstants.UI.TOUCH_BUTTON_SIZE, 0, GameConstants.UI.TOUCH_BUTTON_SIZE)
	jumpButton.Position = UDim2.new(1, -GameConstants.UI.TOUCH_BUTTON_SIZE - 20, 1, -GameConstants.UI.TOUCH_BUTTON_SIZE - 20)
	jumpButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255) -- 파란색
	jumpButton.BackgroundTransparency = 0.3
	jumpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	jumpButton.TextSize = 32
	jumpButton.Font = Enum.Font.GothamBold
	jumpButton.Text = "↑\nJUMP"
	jumpButton.TextYAlignment = Enum.TextYAlignment.Center
	jumpButton.Parent = self._screenGui
	self._jumpButton = jumpButton

	-- 둥근 모서리
	local jumpCorner = Instance.new("UICorner")
	jumpCorner.CornerRadius = UDim.new(0, 12)
	jumpCorner.Parent = jumpButton

	-- 테두리
	local jumpStroke = Instance.new("UIStroke")
	jumpStroke.Color = Color3.fromRGB(255, 255, 255)
	jumpStroke.Thickness = 2
	jumpStroke.Transparency = 0.5
	jumpStroke.Parent = jumpButton

	-- 슬라이드 버튼 (왼쪽 하단)
	local slideButton = Instance.new("TextButton")
	slideButton.Name = "SlideButton"
	slideButton.Size = UDim2.new(0, GameConstants.UI.TOUCH_BUTTON_SIZE, 0, GameConstants.UI.TOUCH_BUTTON_SIZE)
	slideButton.Position = UDim2.new(0, 20, 1, -GameConstants.UI.TOUCH_BUTTON_SIZE - 20)
	slideButton.BackgroundColor3 = Color3.fromRGB(255, 150, 0) -- 주황색
	slideButton.BackgroundTransparency = 0.3
	slideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	slideButton.TextSize = 32
	slideButton.Font = Enum.Font.GothamBold
	slideButton.Text = "↓\nSLIDE"
	slideButton.TextYAlignment = Enum.TextYAlignment.Center
	slideButton.Parent = self._screenGui
	self._slideButton = slideButton

	-- 둥근 모서리
	local slideCorner = Instance.new("UICorner")
	slideCorner.CornerRadius = UDim.new(0, 12)
	slideCorner.Parent = slideButton

	-- 테두리
	local slideStroke = Instance.new("UIStroke")
	slideStroke.Color = Color3.fromRGB(255, 255, 255)
	slideStroke.Thickness = 2
	slideStroke.Transparency = 0.5
	slideStroke.Parent = slideButton

	-- 버튼 클릭 이벤트
	jumpButton.MouseButton1Click:Connect(function()
		if self._onJumpCallback then
			self._onJumpCallback()
		end
	end)

	slideButton.MouseButton1Click:Connect(function()
		if self._onSlideCallback then
			self._onSlideCallback()
		end
	end)

	-- 초기에는 숨김 (게임 시작 시 표시)
	jumpButton.Visible = false
	slideButton.Visible = false

	print("[UIController] Mobile controls created")
end

-- 이벤트 핸들러 설정
function UIController:_setupEventHandlers()
	-- 점수 업데이트
	local scoreConnection = RemoteEvents.ScoreUpdate.OnClientEvent:Connect(function(data)
		self:UpdateScore(data.score, data.distance, data.coins)
	end)
	table.insert(self._connections, scoreConnection)

	-- 라이프 업데이트
	local lifeConnection = RemoteEvents.LifeUpdate.OnClientEvent:Connect(function(data)
		self:UpdateLives(data.lives)
	end)
	table.insert(self._connections, lifeConnection)

	-- 코인 수집
	local coinConnection = RemoteEvents.CoinCollected.OnClientEvent:Connect(function(data)
		self:UpdateCoins(data.totalCoins)
	end)
	table.insert(self._connections, coinConnection)

	-- 게임 오버
	local gameOverConnection = RemoteEvents.GameOver.OnClientEvent:Connect(function(data)
		self:ShowGameOver(data.finalScore, data.earnedCoins, data.highScore, data.distance, data.isNewRecord)
	end)
	table.insert(self._connections, gameOverConnection)

	print("[UIController] Event handlers set up")
end

-- 점수 업데이트
function UIController:UpdateScore(score: number, distance: number, coins: number)
	if self._scoreLabel then
		self._scoreLabel.Text = `Score: {score}`
	end
	if self._distanceLabel then
		self._distanceLabel.Text = `Distance: {distance}m`
	end
end

-- 코인 업데이트
function UIController:UpdateCoins(coins: number)
	if self._coinsLabel then
		self._coinsLabel.Text = `🪙 {coins}`
	end
end

-- 라이프 업데이트
function UIController:UpdateLives(lives: number)
	local previousLives = self._currentLives
	self._currentLives = lives

	-- 개별 하트 업데이트
	for i, heart in ipairs(self._heartLabels) do
		if i <= lives then
			-- 살아있는 하트
			heart.Text = "❤️"
			heart.TextTransparency = 0
		else
			-- 잃은 하트
			heart.Text = "🖤"
			heart.TextTransparency = 0.3
		end
	end

	-- 라이프 감소 시 애니메이션
	if lives < previousLives and lives > 0 then
		local lostHeartIndex = lives + 1
		if lostHeartIndex <= #self._heartLabels then
			local heart = self._heartLabels[lostHeartIndex]

			-- 하트가 커졌다가 작아지는 애니메이션
			heart.TextSize = 48
			local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
			local tween = TweenService:Create(heart, tweenInfo, {
				TextSize = 32,
			})
			tween:Play()
		end
	end
end

-- 점프 콜백 설정
function UIController:OnJump(callback: () -> ())
	self._onJumpCallback = callback
end

-- 슬라이드 콜백 설정
function UIController:OnSlide(callback: () -> ())
	self._onSlideCallback = callback
end

-- 게임 오버 화면 표시
function UIController:ShowGameOver(finalScore: number, earnedCoins: number, highScore: number?, distance: number?, isNewRecord: boolean?)
	if not self._gameOverFrame then
		return
	end

	-- 최종 점수 표시
	local finalScoreLabel = self._gameOverFrame:FindFirstChild("FinalScore") :: TextLabel?
	if finalScoreLabel then
		finalScoreLabel.Text = `Score: {finalScore}`
	end

	-- 거리 표시
	local distanceLabel = self._gameOverFrame:FindFirstChild("Distance") :: TextLabel?
	if distanceLabel then
		distanceLabel.Text = `🏃 Distance: {distance or 0}m`
	end

	local earnedCoinsLabel = self._gameOverFrame:FindFirstChild("EarnedCoins") :: TextLabel?
	if earnedCoinsLabel then
		earnedCoinsLabel.Text = `🪙 Coins: {earnedCoins}`
	end

	-- 최고 점수 표시
	local highScoreLabel = self._gameOverFrame:FindFirstChild("HighScore") :: TextLabel?
	if highScoreLabel and highScore then
		highScoreLabel.Text = `🏆 High Score: {highScore}`
	end

	-- NEW RECORD 표시
	local newRecordLabel = self._gameOverFrame:FindFirstChild("NewRecord") :: TextLabel?
	if newRecordLabel then
		newRecordLabel.Visible = isNewRecord == true
	end

	-- 게임 오버 프레임 표시 (등장 애니메이션)
	self._gameOverFrame.Size = UDim2.new(0, 0, 0, 0)
	self._gameOverFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	self._gameOverFrame.Visible = true

	local appearTween = TweenService:Create(self._gameOverFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 450, 0, 480),
		Position = UDim2.new(0.5, -225, 0.5, -240),
	})
	appearTween:Play()

	-- NEW RECORD 애니메이션 (깜빡임)
	if isNewRecord and newRecordLabel then
		task.spawn(function()
			for i = 1, 6 do
				if not newRecordLabel or not newRecordLabel.Parent then
					break
				end
				newRecordLabel.BackgroundTransparency = 0.5
				task.wait(0.2)
				if not newRecordLabel or not newRecordLabel.Parent then
					break
				end
				newRecordLabel.BackgroundTransparency = 0.1
				task.wait(0.2)
			end
		end)
	end

	print(`[UIController] Game Over displayed - Score: {finalScore}, Coins: {earnedCoins}, Distance: {distance or 0}m, HighScore: {highScore or 0}, NewRecord: {isNewRecord or false}`)
end

-- 플레이 버튼 클릭 처리
function UIController:OnPlayButtonClicked()
	print("[UIController] Play button clicked")

	-- 시작 메뉴 숨기기
	self:HideStartMenu()

	-- 서버에 게임 시작 요청
	RemoteEvents.GameStart:FireServer()
end

-- 재시작 버튼 클릭 처리
function UIController:OnRestartButtonClicked()
	print("[UIController] Restart button clicked")

	-- 게임 오버 화면 숨기기
	self:HideGameOver()

	-- 서버에 게임 시작 요청
	RemoteEvents.GameStart:FireServer()
end

-- 시작 메뉴 표시
function UIController:ShowStartMenu()
	if self._startMenuFrame then
		self._startMenuFrame.Visible = true
	end

	-- 게임 UI 숨기기
	if self._scoreLabel then
		self._scoreLabel.Visible = false
	end
	if self._coinsLabel then
		self._coinsLabel.Visible = false
	end
	if self._livesContainer then
		self._livesContainer.Visible = false
	end
	if self._distanceLabel then
		self._distanceLabel.Visible = false
	end
	if self._jumpButton then
		self._jumpButton.Visible = false
	end
	if self._slideButton then
		self._slideButton.Visible = false
	end
end

-- 시작 메뉴 숨기기
function UIController:HideStartMenu()
	if self._startMenuFrame then
		self._startMenuFrame.Visible = false
	end

	-- 게임 UI 표시
	if self._scoreLabel then
		self._scoreLabel.Visible = true
	end
	if self._coinsLabel then
		self._coinsLabel.Visible = true
	end
	if self._livesContainer then
		self._livesContainer.Visible = true
	end
	if self._distanceLabel then
		self._distanceLabel.Visible = true
	end
	if self._jumpButton then
		self._jumpButton.Visible = true
	end
	if self._slideButton then
		self._slideButton.Visible = true
	end
end

-- 게임 오버 화면 숨기기 (재시작 시)
function UIController:HideGameOver()
	if self._gameOverFrame then
		self._gameOverFrame.Visible = false

		-- NEW RECORD 숨기기
		local newRecordLabel = self._gameOverFrame:FindFirstChild("NewRecord") :: TextLabel?
		if newRecordLabel then
			newRecordLabel.Visible = false
		end
	end

	-- UI 초기화
	self:UpdateScore(0, 0, 0)
	self:UpdateCoins(0)
	self:UpdateLives(GameConstants.LIFE.STARTING_LIVES)
end

-- 튜토리얼 배너 표시
function UIController:ShowTutorialBanner()
	if self._tutorialBanner then
		self._tutorialBanner.Visible = true
	end
	print("[UIController] Tutorial banner shown")
end

-- 튜토리얼 배너 숨기기
function UIController:HideTutorialBanner()
	if self._tutorialBanner then
		self._tutorialBanner.Visible = false
	end
end

-- 튜토리얼 완료 알림 표시 (잠시 후 자동 숨김)
function UIController:ShowTutorialComplete()
	-- 배너 숨기기
	self:HideTutorialBanner()

	-- 완료 알림 표시
	if self._tutorialNotification then
		self._tutorialNotification.Visible = true

		-- 2초 후 자동 숨김
		task.delay(2, function()
			if self._tutorialNotification then
				self._tutorialNotification.Visible = false
			end
		end)
	end
	print("[UIController] Tutorial complete notification shown")
end

-- 카운트다운 표시 (3, 2, 1, 시작!)
function UIController:ShowCountdown(onComplete: () -> ())
	if not self._countdownLabel then
		-- 카운트다운 UI 없으면 바로 시작
		if onComplete then
			onComplete()
		end
		return
	end

	local countdownLabel = self._countdownLabel
	countdownLabel.Visible = true

	-- 카운트다운 시퀀스
	local sequence = {
		{ text = "3", color = Color3.fromRGB(255, 100, 100), duration = 0.8 },
		{ text = "2", color = Color3.fromRGB(255, 200, 100), duration = 0.8 },
		{ text = "1", color = Color3.fromRGB(100, 255, 100), duration = 0.8 },
		{ text = "시작!", color = Color3.fromRGB(100, 200, 255), duration = 0.6 },
	}

	local totalDelay = 0
	for i, step in ipairs(sequence) do
		task.delay(totalDelay, function()
			countdownLabel.Text = step.text
			countdownLabel.TextColor3 = step.color

			-- 마지막 스텝에서 콜백 호출
			if i == #sequence then
				task.delay(step.duration, function()
					countdownLabel.Visible = false
					if onComplete then
						onComplete()
					end
				end)
			end
		end)
		totalDelay += step.duration
	end

	print("[UIController] Countdown started")
end

-- 정리
function UIController:Destroy()
	if self._screenGui then
		self._screenGui:Destroy()
	end

	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return UIController

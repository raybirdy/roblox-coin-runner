--!strict
-- UI Controller
-- 게임 UI 관리 (점수, 코인, 라이프 표시)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

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
		_hudFrame: Frame?,
		_gameOverFrame: Frame?,
		_startMenuFrame: Frame?,
		_jumpButton: TextButton?,
		_slideButton: TextButton?,
		_reviveButton: TextButton?, -- 부활 버튼
		_tutorialBanner: Frame?, -- 튜토리얼 배너
		_tutorialNotification: Frame?, -- 튜토리얼 종료 알림
		_countdownLabel: TextLabel?, -- 카운트다운 표시
		_lobbyGuide: Frame?, -- 로비 안내 텍스트
		_highScoreDisplay: Frame?, -- 로비 최고 점수 표시
		_lobbyGuideAnimation: boolean?, -- 로비 안내 펄스 애니메이션 활성 여부
		_lobbyCharacterBtn: TextButton?, -- 캐릭터 선택 버튼
		_onCharacterSelectCallback: (() -> ())?, -- 캐릭터 선택 버튼 콜백
		_multiplierBadge: Frame?, -- 생존 배율 뱃지
		_gameOverDim: Frame?, -- 게임오버 배경 딤 오버레이
		_coinLabelBaseSize: number, -- UpdateCoins 인플레이션 방지용 고정 기준 텍스트 크기
		_connections: { RBXScriptConnection },
		_onJumpCallback: (() -> ())?,
		_onSlideCallback: (() -> ())?,
		_onSlideEndCallback: (() -> ())?,
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
		_hudFrame = nil,
		_gameOverFrame = nil,
		_startMenuFrame = nil,
		_jumpButton = nil,
		_slideButton = nil,
		_reviveButton = nil,
		_tutorialBanner = nil,
		_tutorialNotification = nil,
		_countdownLabel = nil,
		_lobbyGuide = nil,
		_highScoreDisplay = nil,
		_lobbyGuideAnimation = false,
		_lobbyCharacterBtn = nil,
		_onCharacterSelectCallback = nil,
		_multiplierBadge = nil,
		_gameOverDim = nil,
		_coinLabelBaseSize = 0,
		_connections = {},
		_onJumpCallback = nil,
		_onSlideCallback = nil,
		_onSlideEndCallback = nil,
	}, UIController)

	self:_createUI()
	self:_createMobileControls()
	self:_setupEventHandlers()
	self:ShowLobbyUI() -- 시작 시 로비 UI 표시

	return self
end

-- UI 생성
function UIController:_createUI()
	-- ScreenGui 생성
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- 부모-자식 계층으로 ZIndex 적용 (검정 화면 방지)
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.DisplayOrder = 9 -- ObjectiveHUD(7), DailyEventHUD(8) 위에, 팝업 모달(10+) 아래
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- 자식이 항상 부모 위에 렌더링되도록
	screenGui.Parent = self._playerGui
	self._screenGui = screenGui

	-- 우측 상단 HUD (세로 컴팩트 배치)
	local hudFrame = Instance.new("Frame")
	hudFrame.Name = "HudFrame"
	local hudW = ResponsiveUtil.scaledOffset(160)
	local hudH = ResponsiveUtil.scaledOffset(130)
	hudFrame.Size = UDim2.new(0, hudW, 0, hudH)
	hudFrame.Position = UDim2.new(1, -hudW - ResponsiveUtil.scaledOffset(10), 0, ResponsiveUtil.scaledOffset(8))
	hudFrame.BackgroundTransparency = 0.4
	hudFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	hudFrame.Parent = screenGui
	self._hudFrame = hudFrame

	local hudCorner = Instance.new("UICorner")
	hudCorner.CornerRadius = UDim.new(0, 10)
	hudCorner.Parent = hudFrame

	-- 하트 (최상단)
	local livesContainer = Instance.new("Frame")
	livesContainer.Name = "LivesContainer"
	livesContainer.Size = UDim2.new(1, 0, 0, 28)
	livesContainer.Position = UDim2.new(0, 0, 0, 6)
	livesContainer.BackgroundTransparency = 1
	livesContainer.Parent = hudFrame
	self._livesContainer = livesContainer

	-- 개별 하트 생성
	self._heartLabels = {}
	local heartSize = math.max(20, ResponsiveUtil.scaledOffset(28))
	local heartSpacing = math.max(22, ResponsiveUtil.scaledOffset(30))
	for i = 1, GameConstants.LIFE.STARTING_LIVES do
		local heart = Instance.new("TextLabel")
		heart.Name = `Heart{i}`
		heart.Size = UDim2.new(0, heartSize, 0, heartSize)
		heart.Position = UDim2.new(0, ResponsiveUtil.scaledOffset(6) + (i - 1) * heartSpacing, 0, 0)
		heart.BackgroundTransparency = 1
		heart.TextColor3 = Color3.fromRGB(255, 50, 50)
		heart.TextSize = ResponsiveUtil.scaledTextSize(20, 14)
		heart.Font = Enum.Font.GothamBold
		heart.Text = "❤️"
		heart.Parent = livesContainer
		table.insert(self._heartLabels, heart)
	end

	-- 점수
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(1, -16, 0, 24)
	scoreLabel.Position = UDim2.new(0, 8, 0, 34)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	scoreLabel.TextSize = ResponsiveUtil.scaledTextSize(18, 14)
	scoreLabel.Font = Enum.Font.GothamBold
	scoreLabel.Text = "⭐ 0"
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	scoreLabel.Parent = hudFrame
	self._scoreLabel = scoreLabel

	-- 거리
	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "DistanceLabel"
	distanceLabel.Size = UDim2.new(1, -16, 0, 24)
	distanceLabel.Position = UDim2.new(0, 8, 0, 58)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	distanceLabel.TextSize = ResponsiveUtil.scaledTextSize(16, 13)
	distanceLabel.Font = Enum.Font.Gotham
	distanceLabel.Text = "🏃 0m"
	distanceLabel.TextXAlignment = Enum.TextXAlignment.Left
	distanceLabel.Parent = hudFrame
	self._distanceLabel = distanceLabel

	-- 코인
	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "CoinsLabel"
	coinsLabel.Size = UDim2.new(1, -16, 0, 24)
	coinsLabel.Position = UDim2.new(0, 8, 0, 82)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	coinsLabel.TextSize = ResponsiveUtil.scaledTextSize(16, 13)
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.Text = "🪙 0"
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinsLabel.Parent = hudFrame
	self._coinsLabel = coinsLabel
	self._coinLabelBaseSize = coinsLabel.TextSize -- 인플레이션 방지: 생성 시점 크기 고정

	-- 기존 livesLabel은 숨김 처리 (호환성)
	local livesLabel = Instance.new("TextLabel")
	livesLabel.Name = "LivesLabel"
	livesLabel.Visible = false
	livesLabel.Parent = screenGui
	self._livesLabel = livesLabel

	-- 게임오버 배경 딤 오버레이 (gameOverFrame 뒤에 표시)
	local gameOverDim = Instance.new("Frame")
	gameOverDim.Name = "GameOverDim"
	gameOverDim.Size = UDim2.new(1, 0, 1, 0)
	gameOverDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	gameOverDim.BackgroundTransparency = 0.55 -- 0.45→0.55: 배경을 살짝 밝게 해 프레임과 대비 확보
	gameOverDim.BorderSizePixel = 0
	gameOverDim.Visible = false
	gameOverDim.ZIndex = 2
	gameOverDim.Parent = screenGui
	self._gameOverDim = gameOverDim

	-- 게임 오버 프레임 (초기 숨김) — 컴팩트 사이즈
	local gameOverFrame = Instance.new("Frame")
	gameOverFrame.Name = "GameOverFrame"
	gameOverFrame.ZIndex = 3
	gameOverFrame.Size = ResponsiveUtil.clampedSize(380, 360, 0.88, 0.70)
	gameOverFrame.Position = ResponsiveUtil.clampedPosition(380, 360, 0.88, 0.70)
	gameOverFrame.BackgroundColor3 = Color3.fromRGB(28, 35, 75) -- 선명한 다크 네이비
	gameOverFrame.BackgroundTransparency = 0.05
	gameOverFrame.Visible = false
	gameOverFrame.Parent = screenGui
	self._gameOverFrame = gameOverFrame

	-- 둥근 모서리
	local gameOverCorner = Instance.new("UICorner")
	gameOverCorner.CornerRadius = UDim.new(0, 16)
	gameOverCorner.Parent = gameOverFrame

	-- 테두리 (밝은 파란색, 선명하게)
	local gameOverStroke = Instance.new("UIStroke")
	gameOverStroke.Color = Color3.fromRGB(120, 160, 255)
	gameOverStroke.Thickness = 2
	gameOverStroke.Transparency = 0.0
	gameOverStroke.Parent = gameOverFrame

	-- 게임 오버 텍스트
	local gameOverTitle = Instance.new("TextLabel")
	gameOverTitle.Name = "Title"
	gameOverTitle.Size = UDim2.new(1, 0, 0, 40)
	gameOverTitle.Position = UDim2.new(0, 0, 0, 10)
	gameOverTitle.BackgroundTransparency = 1
	gameOverTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	gameOverTitle.TextSize = ResponsiveUtil.scaledTextSize(32, 20)
	gameOverTitle.Font = Enum.Font.GothamBold
	gameOverTitle.Text = "GAME OVER"
	gameOverTitle.Parent = gameOverFrame

	-- NEW RECORD 배지 (초기 숨김)
	local newRecordLabel = Instance.new("TextLabel")
	newRecordLabel.Name = "NewRecord"
	newRecordLabel.Size = UDim2.new(0, 180, 0, 30)
	newRecordLabel.Position = UDim2.new(0.5, -90, 0, 50)
	newRecordLabel.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	newRecordLabel.BackgroundTransparency = 0.1
	newRecordLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	newRecordLabel.TextSize = ResponsiveUtil.scaledTextSize(18, 13)
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
	finalScoreLabel.Size = UDim2.new(1, 0, 0, 36)
	finalScoreLabel.Position = UDim2.new(0, 0, 0, 85)
	finalScoreLabel.BackgroundTransparency = 1
	finalScoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	finalScoreLabel.TextSize = ResponsiveUtil.scaledTextSize(26, 18)
	finalScoreLabel.Font = Enum.Font.GothamBold
	finalScoreLabel.Text = "Score: 0"
	finalScoreLabel.Parent = gameOverFrame

	-- 거리 + 코인 한 줄 (가로 배치)
	local statsRow = Instance.new("Frame")
	statsRow.Name = "StatsRow"
	statsRow.Size = UDim2.new(1, -20, 0, 28)
	statsRow.Position = UDim2.new(0, 10, 0, 125)
	statsRow.BackgroundTransparency = 1
	statsRow.Parent = gameOverFrame

	local goDistanceLabel = Instance.new("TextLabel")
	goDistanceLabel.Name = "Distance"
	goDistanceLabel.Size = UDim2.new(0.5, 0, 1, 0)
	goDistanceLabel.Position = UDim2.new(0, 0, 0, 0)
	goDistanceLabel.BackgroundTransparency = 1
	goDistanceLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	goDistanceLabel.TextSize = ResponsiveUtil.scaledTextSize(16, 12)
	goDistanceLabel.Font = Enum.Font.Gotham
	goDistanceLabel.Text = "🏃 0m"
	goDistanceLabel.TextXAlignment = Enum.TextXAlignment.Center
	goDistanceLabel.Parent = statsRow

	local earnedCoinsLabel = Instance.new("TextLabel")
	earnedCoinsLabel.Name = "EarnedCoins"
	earnedCoinsLabel.Size = UDim2.new(0.5, 0, 1, 0)
	earnedCoinsLabel.Position = UDim2.new(0.5, 0, 0, 0)
	earnedCoinsLabel.BackgroundTransparency = 1
	earnedCoinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	earnedCoinsLabel.TextSize = ResponsiveUtil.scaledTextSize(16, 12)
	earnedCoinsLabel.Font = Enum.Font.Gotham
	earnedCoinsLabel.Text = "🪙 0"
	earnedCoinsLabel.TextXAlignment = Enum.TextXAlignment.Center
	earnedCoinsLabel.Parent = statsRow

	-- 최고 점수
	local highScoreLabel = Instance.new("TextLabel")
	highScoreLabel.Name = "HighScore"
	highScoreLabel.Size = UDim2.new(1, 0, 0, 28)
	highScoreLabel.Position = UDim2.new(0, 0, 0, 157)
	highScoreLabel.BackgroundTransparency = 1
	highScoreLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	highScoreLabel.TextSize = ResponsiveUtil.scaledTextSize(18, 13)
	highScoreLabel.Font = Enum.Font.GothamBold
	highScoreLabel.Text = "🏆 High Score: 0"
	highScoreLabel.Parent = gameOverFrame

	-- PLAY AGAIN 버튼
	local restartButton = Instance.new("TextButton")
	restartButton.Name = "RestartButton"
	restartButton.Size = UDim2.new(0.44, 0, 0, 48)
	restartButton.Position = UDim2.new(0.03, 0, 1, -62)
	restartButton.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
	restartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	restartButton.TextSize = ResponsiveUtil.scaledTextSize(18, 13)
	restartButton.Font = Enum.Font.GothamBold
	restartButton.Text = "▶ PLAY AGAIN"
	restartButton.Parent = gameOverFrame

	local restartCorner = Instance.new("UICorner")
	restartCorner.CornerRadius = UDim.new(0, 10)
	restartCorner.Parent = restartButton

	local restartStroke = Instance.new("UIStroke")
	restartStroke.Color = Color3.fromRGB(255, 255, 255)
	restartStroke.Thickness = 2
	restartStroke.Transparency = 0.5
	restartStroke.Parent = restartButton

	restartButton.MouseButton1Click:Connect(function()
		self:OnRestartButtonClicked()
	end)

	-- LOBBY 버튼
	local lobbyButton = Instance.new("TextButton")
	lobbyButton.Name = "LobbyButton"
	lobbyButton.Size = UDim2.new(0.44, 0, 0, 48)
	lobbyButton.Position = UDim2.new(0.53, 0, 1, -62)
	lobbyButton.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
	lobbyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	lobbyButton.TextSize = ResponsiveUtil.scaledTextSize(18, 13)
	lobbyButton.Font = Enum.Font.GothamBold
	lobbyButton.Text = "🏠 LOBBY"
	lobbyButton.Parent = gameOverFrame

	local lobbyCorner = Instance.new("UICorner")
	lobbyCorner.CornerRadius = UDim.new(0, 10)
	lobbyCorner.Parent = lobbyButton

	local lobbyStroke = Instance.new("UIStroke")
	lobbyStroke.Color = Color3.fromRGB(255, 255, 255)
	lobbyStroke.Thickness = 2
	lobbyStroke.Transparency = 0.5
	lobbyStroke.Parent = lobbyButton

	lobbyButton.MouseButton1Click:Connect(function()
		self:OnLobbyButtonClicked()
	end)

	-- 부활 버튼 (초기 숨김)
	local reviveButton = Instance.new("TextButton")
	reviveButton.Name = "ReviveButton"
	reviveButton.Size = UDim2.new(0.7, 0, 0, 50)
	reviveButton.Position = UDim2.new(0.15, 0, 1, -118)
	reviveButton.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	reviveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	reviveButton.TextSize = ResponsiveUtil.scaledTextSize(22, 16)
	reviveButton.Font = Enum.Font.GothamBold
	reviveButton.Text = "💫 REVIVE (5💎)"
	reviveButton.Visible = false
	reviveButton.Parent = gameOverFrame
	self._reviveButton = reviveButton

	local reviveCorner = Instance.new("UICorner")
	reviveCorner.CornerRadius = UDim.new(0, 12)
	reviveCorner.Parent = reviveButton

	local reviveStroke = Instance.new("UIStroke")
	reviveStroke.Color = Color3.fromRGB(255, 255, 255)
	reviveStroke.Thickness = 2
	reviveStroke.Transparency = 0.5
	reviveStroke.Parent = reviveButton

	reviveButton.MouseButton1Click:Connect(function()
		self:OnReviveButtonClicked()
	end)

	-- 시작 메뉴 프레임 (초기 화면)
	local startMenuFrame = Instance.new("Frame")
	startMenuFrame.Name = "StartMenuFrame"
	startMenuFrame.Size = ResponsiveUtil.clampedSize(500, 400, 0.92, 0.85)
	startMenuFrame.Position = ResponsiveUtil.clampedPosition(500, 400, 0.92, 0.85)
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
	titleLabel.TextSize = ResponsiveUtil.scaledTextSize(48, 28)
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
	subtitleLabel.TextSize = ResponsiveUtil.scaledTextSize(20, 14)
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
	playButton.TextSize = ResponsiveUtil.scaledTextSize(32, 20)
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
	controlsLabel.TextSize = ResponsiveUtil.scaledTextSize(16, 12)
	controlsLabel.Font = Enum.Font.Gotham
	controlsLabel.Text = if UserInputService.TouchEnabled
		then "Controls:\nJUMP: Swipe Up / Button\nSLIDE: Swipe Down / Button"
		else "Controls:\nJUMP: Space / W / ↑\nSLIDE: S / ↓"
	controlsLabel.Parent = startMenuFrame

	-- 튜토리얼 배너 (화면 상단)
	local tutorialBanner = Instance.new("Frame")
	tutorialBanner.Name = "TutorialBanner"
	tutorialBanner.Size = ResponsiveUtil.clampedSize(300, 50, 0.80, 0.10)
	tutorialBanner.Position = ResponsiveUtil.clampedPosition(300, 50, 0.80, 0.10)
	-- Shift upward from center
	tutorialBanner.Position = UDim2.new(
		tutorialBanner.Position.X.Scale,
		tutorialBanner.Position.X.Offset,
		0,
		ResponsiveUtil.scaledOffset(120)
	)
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
	tutorialLabel.TextSize = ResponsiveUtil.scaledTextSize(22, 16)
	tutorialLabel.Font = Enum.Font.GothamBold
	tutorialLabel.Text = "연습 모드"
	tutorialLabel.Parent = tutorialBanner

	-- 튜토리얼 종료 알림 (화면 중앙)
	local tutorialNotification = Instance.new("Frame")
	tutorialNotification.Name = "TutorialNotification"
	tutorialNotification.Size = ResponsiveUtil.clampedSize(400, 100, 0.85, 0.20)
	tutorialNotification.Position = ResponsiveUtil.clampedPosition(400, 100, 0.85, 0.20)
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
	notificationLabel.TextSize = ResponsiveUtil.scaledTextSize(28, 18)
	notificationLabel.Font = Enum.Font.GothamBold
	notificationLabel.Text = "연습 완료! 게임 시작!"
	notificationLabel.Parent = tutorialNotification

	-- 카운트다운 표시 (화면 중앙, 크게)
	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "CountdownLabel"
	countdownLabel.Size = ResponsiveUtil.clampedSize(300, 200, 0.60, 0.40)
	countdownLabel.Position = ResponsiveUtil.clampedPosition(300, 200, 0.60, 0.40)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countdownLabel.TextSize = ResponsiveUtil.scaledTextSize(120, 60)
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.Text = ""
	countdownLabel.TextStrokeTransparency = 0.3
	countdownLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	countdownLabel.Visible = false
	countdownLabel.ZIndex = 100 -- 다른 UI 위에 표시
	countdownLabel.Parent = screenGui
	self._countdownLabel = countdownLabel

	-- 로비 안내 텍스트 (화면 하단) - 개선된 가시성
	local lobbyGuide = Instance.new("Frame")
	lobbyGuide.Name = "LobbyGuide"
	lobbyGuide.Size = ResponsiveUtil.clampedSize(450, 70, 0.92, 0.15)
	lobbyGuide.Position = UDim2.new(0.5, -math.min(450, ResponsiveUtil.getViewportSize().X * 0.92) / 2, 1, -110)
	lobbyGuide.BackgroundColor3 = Color3.fromRGB(0, 50, 0)
	lobbyGuide.BackgroundTransparency = 0.15
	lobbyGuide.Visible = false
	lobbyGuide.Parent = screenGui
	self._lobbyGuide = lobbyGuide

	local guideCorner = Instance.new("UICorner")
	guideCorner.CornerRadius = UDim.new(0, 16)
	guideCorner.Parent = lobbyGuide

	local guideStroke = Instance.new("UIStroke")
	guideStroke.Color = Color3.fromRGB(0, 255, 100)
	guideStroke.Thickness = 3
	guideStroke.Parent = lobbyGuide

	local guideLabel = Instance.new("TextLabel")
	guideLabel.Name = "Label"
	guideLabel.Size = UDim2.new(1, 0, 1, 0)
	guideLabel.BackgroundTransparency = 1
	guideLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	guideLabel.TextSize = ResponsiveUtil.scaledTextSize(26, 18)
	guideLabel.Font = Enum.Font.GothamBlack
	guideLabel.Text = "➤ 포탈로 이동해서 게임 시작! ➤"
	guideLabel.TextStrokeTransparency = 0
	guideLabel.TextStrokeColor3 = Color3.fromRGB(0, 100, 0)
	guideLabel.Parent = lobbyGuide

	-- 캐릭터 선택 버튼 (로비 우측 하단)
	local charBtn = Instance.new("TextButton")
	charBtn.Name = "CharacterSelectBtn"
	charBtn.Size = UDim2.new(0, ResponsiveUtil.scaledOffset(120), 0, ResponsiveUtil.scaledOffset(44))
	charBtn.Position = UDim2.new(1, -ResponsiveUtil.scaledOffset(130), 1, -ResponsiveUtil.scaledOffset(120))
	charBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 160)
	charBtn.BackgroundTransparency = 0.1
	charBtn.BorderSizePixel = 0
	charBtn.Text = "🎭 캐릭터"
	charBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	charBtn.TextSize = ResponsiveUtil.scaledTextSize(15, 12)
	charBtn.Font = Enum.Font.GothamBold
	charBtn.Visible = false
	charBtn.Parent = screenGui
	self._lobbyCharacterBtn = charBtn

	Instance.new("UICorner", charBtn).CornerRadius = UDim.new(0, 10)
	local charBtnStroke = Instance.new("UIStroke")
	charBtnStroke.Color = Color3.fromRGB(120, 160, 255)
	charBtnStroke.Thickness = 2
	charBtnStroke.Parent = charBtn

	charBtn.MouseButton1Click:Connect(function()
		if self._onCharacterSelectCallback then
			self._onCharacterSelectCallback()
		end
	end)

	-- 로비 최고 점수 표시 (우측 상단 - 이동 방해 안 함)
	local highScoreDisplay = Instance.new("Frame")
	highScoreDisplay.Name = "HighScoreDisplay"
	local hsW = ResponsiveUtil.scaledOffset(200)
	local hsH = ResponsiveUtil.scaledOffset(100)
	highScoreDisplay.Size = UDim2.new(0, hsW, 0, hsH)
	highScoreDisplay.Position = UDim2.new(1, -hsW - ResponsiveUtil.scaledOffset(10), 0, ResponsiveUtil.scaledOffset(10))
	highScoreDisplay.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
	highScoreDisplay.BackgroundTransparency = 0.15
	highScoreDisplay.Visible = false
	highScoreDisplay.Parent = screenGui
	self._highScoreDisplay = highScoreDisplay

	local hsCorner = Instance.new("UICorner")
	hsCorner.CornerRadius = UDim.new(0, 16)
	hsCorner.Parent = highScoreDisplay

	-- 테두리 추가 (금색)
	local hsStroke = Instance.new("UIStroke")
	hsStroke.Color = Color3.fromRGB(255, 215, 0)
	hsStroke.Thickness = 3
	hsStroke.Parent = highScoreDisplay

	local hsTitle = Instance.new("TextLabel")
	hsTitle.Name = "Title"
	hsTitle.Size = UDim2.new(1, 0, 0, 25)
	hsTitle.Position = UDim2.new(0, 0, 0, 5)
	hsTitle.BackgroundTransparency = 1
	hsTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	hsTitle.TextSize = ResponsiveUtil.scaledTextSize(16, 12)
	hsTitle.Font = Enum.Font.GothamBlack
	hsTitle.Text = "MY BEST"
	hsTitle.TextStrokeTransparency = 0.5
	hsTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hsTitle.Parent = highScoreDisplay

	local hsScore = Instance.new("TextLabel")
	hsScore.Name = "Score"
	hsScore.Size = UDim2.new(1, 0, 0, 28)
	hsScore.Position = UDim2.new(0, 0, 0, 32)
	hsScore.BackgroundTransparency = 1
	hsScore.TextColor3 = Color3.fromRGB(255, 255, 255)
	hsScore.TextSize = ResponsiveUtil.scaledTextSize(20, 14)
	hsScore.Font = Enum.Font.GothamBold
	hsScore.Text = "Score: 0"
	hsScore.TextStrokeTransparency = 0.3
	hsScore.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hsScore.Parent = highScoreDisplay

	local hsCoins = Instance.new("TextLabel")
	hsCoins.Name = "Coins"
	hsCoins.Size = UDim2.new(1, 0, 0, 25)
	hsCoins.Position = UDim2.new(0, 0, 0, 62)
	hsCoins.BackgroundTransparency = 1
	hsCoins.TextColor3 = Color3.fromRGB(255, 215, 0)
	hsCoins.TextSize = ResponsiveUtil.scaledTextSize(16, 12)
	hsCoins.Font = Enum.Font.GothamBold
	hsCoins.Text = "Coins: 0"
	hsCoins.TextStrokeTransparency = 0.3
	hsCoins.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hsCoins.Parent = highScoreDisplay

	print("[UIController] UI created")
end

-- 모바일 컨트롤 생성
function UIController:_createMobileControls()
	if not self._screenGui then
		return
	end

	local btnSize = GameConstants.UI.TOUCH_BUTTON_SIZE
	local btnMargin = 34 -- Increased for home indicator safe area

	-- 점프 버튼 (오른쪽 하단)
	local jumpButton = Instance.new("TextButton")
	jumpButton.Name = "JumpButton"
	jumpButton.Size = UDim2.new(0, btnSize, 0, btnSize)
	jumpButton.Position = UDim2.new(1, -btnSize - btnMargin, 1, -btnSize - btnMargin)
	jumpButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
	jumpButton.BackgroundTransparency = 0.2
	jumpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	jumpButton.TextSize = ResponsiveUtil.scaledTextSize(36, 24)
	jumpButton.Font = Enum.Font.GothamBold
	jumpButton.Text = "↑\nJUMP"
	jumpButton.TextYAlignment = Enum.TextYAlignment.Center
	jumpButton.Parent = self._screenGui
	self._jumpButton = jumpButton

	local jumpCorner = Instance.new("UICorner")
	jumpCorner.CornerRadius = UDim.new(0, 16)
	jumpCorner.Parent = jumpButton

	local jumpStroke = Instance.new("UIStroke")
	jumpStroke.Color = Color3.fromRGB(255, 255, 255)
	jumpStroke.Thickness = 3
	jumpStroke.Transparency = 0.3
	jumpStroke.Parent = jumpButton

	-- 슬라이드 버튼 (왼쪽 하단)
	local slideButton = Instance.new("TextButton")
	slideButton.Name = "SlideButton"
	slideButton.Size = UDim2.new(0, btnSize, 0, btnSize)
	slideButton.Position = UDim2.new(0, btnMargin, 1, -btnSize - btnMargin)
	slideButton.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
	slideButton.BackgroundTransparency = 0.2
	slideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	slideButton.TextSize = ResponsiveUtil.scaledTextSize(36, 24)
	slideButton.Font = Enum.Font.GothamBold
	slideButton.Text = "↓\nSLIDE"
	slideButton.TextYAlignment = Enum.TextYAlignment.Center
	slideButton.Parent = self._screenGui
	self._slideButton = slideButton

	local slideCorner = Instance.new("UICorner")
	slideCorner.CornerRadius = UDim.new(0, 16)
	slideCorner.Parent = slideButton

	local slideStroke = Instance.new("UIStroke")
	slideStroke.Color = Color3.fromRGB(255, 255, 255)
	slideStroke.Thickness = 3
	slideStroke.Transparency = 0.3
	slideStroke.Parent = slideButton

	-- 터치 프레스 피드백 (버튼 누를 때 축소, 뗄 때 복구)
	local function addPressFeedback(button: TextButton)
		local originalSize = button.Size
		local pressInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local releaseInfo = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

		local shrunkSize = UDim2.new(
			originalSize.X.Scale,
			math.floor(originalSize.X.Offset * 0.9),
			originalSize.Y.Scale,
			math.floor(originalSize.Y.Offset * 0.9)
		)

		button.MouseButton1Down:Connect(function()
			TweenService:Create(button, pressInfo, { Size = shrunkSize }):Play()
			button.BackgroundTransparency = 0.1
		end)

		button.MouseButton1Up:Connect(function()
			TweenService:Create(button, releaseInfo, { Size = originalSize }):Play()
			button.BackgroundTransparency = 0.2
		end)
	end

	addPressFeedback(jumpButton)
	addPressFeedback(slideButton)

	-- 버튼 터치 이벤트 (MouseButton1Down으로 즉각 반응)
	jumpButton.MouseButton1Down:Connect(function()
		if self._onJumpCallback then
			self._onJumpCallback()
		end
	end)

	slideButton.MouseButton1Down:Connect(function()
		if self._onSlideCallback then
			self._onSlideCallback()
		end
	end)

	slideButton.MouseButton1Up:Connect(function()
		if self._onSlideEndCallback then
			self._onSlideEndCallback()
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
		self:ShowGameOver(
			data.finalScore,
			data.earnedCoins,
			data.highScore,
			data.distance,
			data.isNewRecord,
			data.canRevive,
			data -- Phase B: 추가 통계 전체 전달
		)
	end)
	table.insert(self._connections, gameOverConnection)

	-- 부활 응답
	local reviveConnection = RemoteEvents.Revive.OnClientEvent:Connect(function(data)
		if data.success then
			print(`[UIController] Revive successful! Lives: {data.lives}`)
			self:UpdateLives(data.lives)
		else
			print(`[UIController] Revive failed: {data.reason}`)
		end
	end)
	table.insert(self._connections, reviveConnection)

	-- Phase 2: Near Record Alert
	local nearRecordConn = RemoteEvents.NearRecordAlert.OnClientEvent:Connect(function(data)
		self:ShowNearRecordAlert(data)
	end)
	table.insert(self._connections, nearRecordConn)

	-- Phase 2: New Record Celebration
	local newRecordConn = RemoteEvents.NewRecordCelebration.OnClientEvent:Connect(function(_data)
		self:ShowNewRecordCelebration()
	end)
	table.insert(self._connections, newRecordConn)

	-- 생존 배율 업데이트
	local survivalMultConn = RemoteEvents.SurvivalMultiplierUpdate.OnClientEvent:Connect(function(data)
		self:UpdateSurvivalMultiplierBadge(data)
	end)
	table.insert(self._connections, survivalMultConn)

	-- 히트 러시 시작
	local hitRushConn = RemoteEvents.HitRushStart.OnClientEvent:Connect(function(data)
		self:ShowHitRushToast(data.duration)
	end)
	table.insert(self._connections, hitRushConn)

	print("[UIController] Event handlers set up")
end

-- 점수 업데이트
function UIController:UpdateScore(score: number, distance: number, _coins: number)
	if self._scoreLabel then
		self._scoreLabel.Text = `⭐ {score}`
	end
	if self._distanceLabel then
		self._distanceLabel.Text = `🏃 {distance}m`
	end
end

-- 코인 업데이트 (바운스 + 금색 플래시 애니메이션)
function UIController:UpdateCoins(coins: number)
	if not self._coinsLabel then
		return
	end
	self._coinsLabel.Text = `🪙 {coins}`

	-- 고정 기준 크기에서 펀치 (연속 수집 시 누진 인플레이션 방지)
	local baseSize = self._coinLabelBaseSize
	self._coinsLabel.TextSize = baseSize + 7
	self._coinsLabel.TextColor3 = Color3.fromRGB(255, 255, 200) -- 밝은 황금 플래시

	TweenService:Create(
		self._coinsLabel,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ TextSize = baseSize, TextColor3 = Color3.fromRGB(255, 215, 0) }
	):Play()
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
			heart.TextSize = ResponsiveUtil.scaledTextSize(34, 22)
			local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
			local tween = TweenService:Create(heart, tweenInfo, {
				TextSize = ResponsiveUtil.scaledTextSize(22, 14),
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

-- 슬라이드 종료 콜백 설정
function UIController:OnSlideEnd(callback: () -> ())
	self._onSlideEndCallback = callback
end

-- 게임 오버 화면 표시
function UIController:ShowGameOver(
	finalScore: number,
	earnedCoins: number,
	highScore: number?,
	distance: number?,
	isNewRecord: boolean?,
	canRevive: boolean?,
	extraData: any? -- Phase B: 추가 통계
)
	if not self._gameOverFrame then
		return
	end

	-- 배경 딤 표시
	if self._gameOverDim then
		self._gameOverDim.Visible = true
	end

	-- 최종 점수 표시
	local finalScoreLabel = self._gameOverFrame:FindFirstChild("FinalScore") :: TextLabel?
	if finalScoreLabel then
		finalScoreLabel.Text = `Score: {finalScore}`
	end

	-- 거리 표시
	local statsRow = self._gameOverFrame:FindFirstChild("StatsRow") :: Frame?
	local distanceLabel = if statsRow then statsRow:FindFirstChild("Distance") :: TextLabel? else nil
	if distanceLabel then
		distanceLabel.Text = `🏃 {distance or 0}m`
	end

	local earnedCoinsLabel = if statsRow then statsRow:FindFirstChild("EarnedCoins") :: TextLabel? else nil
	if earnedCoinsLabel then
		earnedCoinsLabel.Text = `🪙 {earnedCoins}`
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

	-- Phase B: 추가 통계 행 (기존 것 제거 후 재생성)
	local existingStats2 = self._gameOverFrame:FindFirstChild("StatsRow2")
	if existingStats2 then
		existingStats2:Destroy()
	end
	local existingZone = self._gameOverFrame:FindFirstChild("ZoneReached")
	if existingZone then
		existingZone:Destroy()
	end
	local existingAlmost = self._gameOverFrame:FindFirstChild("AlmostMessage")
	if existingAlmost then
		existingAlmost:Destroy()
	end
	local existingNextZone = self._gameOverFrame:FindFirstChild("NextZoneHint")
	if existingNextZone then
		existingNextZone:Destroy()
	end

	-- RetentionHint: 기존 제거 후 재생성
	local existingHint = self._gameOverFrame:FindFirstChild("RetentionHint")
	if existingHint then
		existingHint:Destroy()
	end

	-- 스킨 섹션: 기존 제거 후 재생성
	local existingSkinBadge = self._gameOverFrame:FindFirstChild("SkinBadge")
	if existingSkinBadge then
		existingSkinBadge:Destroy()
	end
	local existingSkinNext = self._gameOverFrame:FindFirstChild("SkinNext")
	if existingSkinNext then
		existingSkinNext:Destroy()
	end

	if not canRevive and extraData and extraData.loginStreak ~= nil then
		local streak = extraData.loginStreak or 0
		local nextDay = (streak % 7) + 1
		local REWARDS = { "50🪙", "100🪙", "5💎", "200🪙", "10💎", "300🪙", "20💎+트레일" }
		local nextRewardText = REWARDS[nextDay] or "보상"

		local hint = Instance.new("TextLabel")
		hint.Name = "RetentionHint"
		hint.Size = UDim2.new(0.9, 0, 0, 36)
		hint.Position = UDim2.new(0.05, 0, 1, -105)
		hint.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
		hint.BackgroundTransparency = 0.0
		hint.Text = `🎁 내일 다시 오면 {nextRewardText} 보상! (Day {nextDay})`
		hint.TextColor3 = Color3.fromRGB(180, 255, 180)
		hint.TextSize = ResponsiveUtil.scaledTextSize(14, 11)
		hint.Font = Enum.Font.GothamBold
		hint.TextXAlignment = Enum.TextXAlignment.Center
		hint.Parent = self._gameOverFrame

		local hintCorner = Instance.new("UICorner")
		hintCorner.CornerRadius = UDim.new(0, 6)
		hintCorner.Parent = hint
	end

	if extraData and not canRevive then
		-- 런 목표 달성 요약 배지
		local objTotal = extraData.objectivesTotal or 0
		if objTotal > 0 then
			local objCompleted = extraData.objectivesCompleted or 0
			local objBonus = extraData.objectiveBonus or 0
			local allDone = objCompleted >= objTotal

			local objRow = Instance.new("Frame")
			objRow.Name = "ObjSummaryRow"
			objRow.Size = UDim2.new(1, -20, 0, 26)
			objRow.Position = UDim2.new(0, 10, 0, 183)
			objRow.BackgroundColor3 = if allDone
				then Color3.fromRGB(25, 100, 25)
				else Color3.fromRGB(80, 70, 15)
			objRow.BackgroundTransparency = 0.0
			objRow.Parent = self._gameOverFrame

			local objCorner = Instance.new("UICorner")
			objCorner.CornerRadius = UDim.new(0, 6)
			objCorner.Parent = objRow

			local objText = Instance.new("TextLabel")
			objText.Size = UDim2.new(1, 0, 1, 0)
			objText.BackgroundTransparency = 1
			objText.Font = Enum.Font.GothamBold
			objText.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
			objText.TextXAlignment = Enum.TextXAlignment.Center
			if allDone then
				objText.TextColor3 = Color3.fromRGB(100, 255, 100)
				objText.Text = if objBonus > 0
					then `🎯 목표 전부 달성! (+{objBonus}🪙 보너스)`
					else `🎯 목표 {objCompleted}/{objTotal} 달성!`
			else
				objText.TextColor3 = Color3.fromRGB(255, 220, 100)
				objText.Text = `🎯 목표 {objCompleted}/{objTotal} 달성`
			end
			objText.Parent = objRow
		end

		-- StatsRow2: NearMiss + MaxCombo + FeverCount
		local statsRow2 = Instance.new("Frame")
		statsRow2.Name = "StatsRow2"
		statsRow2.Size = UDim2.new(1, -20, 0, 24)
		statsRow2.Position = UDim2.new(0, 10, 0, 213)
		statsRow2.BackgroundTransparency = 1
		statsRow2.Parent = self._gameOverFrame

		local nearMissLabel = Instance.new("TextLabel")
		nearMissLabel.Name = "NearMiss"
		nearMissLabel.Size = UDim2.new(0.33, 0, 1, 0)
		nearMissLabel.Position = UDim2.new(0, 0, 0, 0)
		nearMissLabel.BackgroundTransparency = 1
		nearMissLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
		nearMissLabel.TextSize = ResponsiveUtil.scaledTextSize(14, 10)
		nearMissLabel.Font = Enum.Font.Gotham
		nearMissLabel.Text = `NearMiss {extraData.nearMissCount or 0}`
		nearMissLabel.TextXAlignment = Enum.TextXAlignment.Center
		nearMissLabel.Parent = statsRow2

		local maxComboLabel = Instance.new("TextLabel")
		maxComboLabel.Name = "MaxCombo"
		maxComboLabel.Size = UDim2.new(0.33, 0, 1, 0)
		maxComboLabel.Position = UDim2.new(0.33, 0, 0, 0)
		maxComboLabel.BackgroundTransparency = 1
		maxComboLabel.TextColor3 = Color3.fromRGB(255, 100, 50)
		maxComboLabel.TextSize = ResponsiveUtil.scaledTextSize(14, 10)
		maxComboLabel.Font = Enum.Font.Gotham
		maxComboLabel.Text = `Combo {extraData.maxCombo or 0}`
		maxComboLabel.TextXAlignment = Enum.TextXAlignment.Center
		maxComboLabel.Parent = statsRow2

		local feverLabel = Instance.new("TextLabel")
		feverLabel.Name = "Fever"
		feverLabel.Size = UDim2.new(0.34, 0, 1, 0)
		feverLabel.Position = UDim2.new(0.66, 0, 0, 0)
		feverLabel.BackgroundTransparency = 1
		feverLabel.TextColor3 = Color3.fromRGB(255, 50, 255)
		feverLabel.TextSize = ResponsiveUtil.scaledTextSize(14, 10)
		feverLabel.Font = Enum.Font.Gotham
		feverLabel.Text = `Fever {extraData.feverCount or 0}`
		feverLabel.TextXAlignment = Enum.TextXAlignment.Center
		feverLabel.Parent = statsRow2

		-- Zone 도달 라벨
		if extraData.zoneName then
			local zoneLabel = Instance.new("TextLabel")
			zoneLabel.Name = "ZoneReached"
			zoneLabel.Size = UDim2.new(1, -20, 0, 22)
			zoneLabel.Position = UDim2.new(0, 10, 0, 241)
			zoneLabel.BackgroundTransparency = 1
			zoneLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
			zoneLabel.TextSize = ResponsiveUtil.scaledTextSize(14, 10)
			zoneLabel.Font = Enum.Font.GothamBold
			zoneLabel.Text = `{extraData.zoneName}까지 도달!`
			zoneLabel.Parent = self._gameOverFrame
		end

		-- "거의 다 왔어!" 메시지
		if extraData.almostMessage then
			local almostLabel = Instance.new("TextLabel")
			almostLabel.Name = "AlmostMessage"
			almostLabel.Size = UDim2.new(1, -20, 0, 28)
			almostLabel.Position = UDim2.new(0, 10, 0, 267)
			almostLabel.BackgroundTransparency = 1
			almostLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
			almostLabel.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
			almostLabel.Font = Enum.Font.GothamBold
			almostLabel.Text = `"{extraData.almostMessage}"`
			almostLabel.TextWrapped = true
			almostLabel.Parent = self._gameOverFrame
		end

		-- TIER 3: 다음 구역 목표 힌트 (재도전 동기 부여)
		if extraData.nextZoneInfo then
			local nextZoneInfo = extraData.nextZoneInfo
			local hintLabel = Instance.new("TextLabel")
			hintLabel.Name = "NextZoneHint"
			hintLabel.Size = UDim2.new(1, -20, 0, 24)
			hintLabel.Position = UDim2.new(0, 10, 0, 298)
			hintLabel.BackgroundTransparency = 1
			hintLabel.TextColor3 = Color3.fromRGB(100, 220, 255)
			hintLabel.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
			hintLabel.Font = Enum.Font.GothamBold
			hintLabel.Text = `🗺️ 다음 구역: {nextZoneInfo.displayName} ({nextZoneInfo.remainingSeconds}초 더!)`
			hintLabel.Parent = self._gameOverFrame
		end
	end

	-- 스킨 배지 + 다음 스킨 진행바 (비부활 화면에서만, 스킨 데이터 있을 때)
	if not canRevive and extraData and extraData.equippedSkinId then
		-- 장착 스킨 정보 찾기
		local equippedSkinData = nil
		for _, skin in GameConstants.SHOP.SKINS do
			if skin.id == extraData.equippedSkinId then
				equippedSkinData = skin
				break
			end
		end

		if equippedSkinData then
			-- 현재 스킨 배지 (스킨 색상 배경)
			local skinBadge = Instance.new("Frame")
			skinBadge.Name = "SkinBadge"
			skinBadge.Size = UDim2.new(1, -20, 0, 22)
			skinBadge.Position = UDim2.new(0, 10, 1, -160)
			skinBadge.BackgroundColor3 = equippedSkinData.color
			skinBadge.BackgroundTransparency = 0.2
			skinBadge.Parent = self._gameOverFrame

			local skinBadgeCorner = Instance.new("UICorner")
			skinBadgeCorner.CornerRadius = UDim.new(0, 6)
			skinBadgeCorner.Parent = skinBadge

			local skinBadgeText = Instance.new("TextLabel")
			skinBadgeText.Size = UDim2.new(1, 0, 1, 0)
			skinBadgeText.BackgroundTransparency = 1
			skinBadgeText.Text = `🎨 현재 스킨: {equippedSkinData.name}`
			skinBadgeText.TextColor3 = Color3.fromRGB(255, 255, 255)
			skinBadgeText.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
			skinBadgeText.Font = Enum.Font.GothamBold
			skinBadgeText.TextXAlignment = Enum.TextXAlignment.Center
			skinBadgeText.Parent = skinBadge

			-- 다음 미보유 코인 스킨 찾기 (오름차순 정렬된 SHOP.SKINS 기준)
			local ownedSkins: { string } = extraData.ownedSkins or { "default" }
			local nextSkin = nil
			for _, skin in GameConstants.SHOP.SKINS do
				if skin.currency == "coins" and skin.price > 0 then
					local owned = false
					for _, ownedId in ownedSkins do
						if ownedId == skin.id then
							owned = true
							break
						end
					end
					if not owned then
						nextSkin = skin
						break
					end
				end
			end

			if nextSkin then
				local totalCoins = extraData.playerTotalCoins or 0
				local progress = math.min(totalCoins, nextSkin.price)
				local filled = math.floor(progress / nextSkin.price * 10)
				local bar = string.rep("█", filled) .. string.rep("░", 10 - filled)

				local skinNextLabel = Instance.new("TextLabel")
				skinNextLabel.Name = "SkinNext"
				skinNextLabel.Size = UDim2.new(1, -20, 0, 20)
				skinNextLabel.Position = UDim2.new(0, 10, 1, -133)
				skinNextLabel.BackgroundTransparency = 1
				skinNextLabel.Text = `다음: {nextSkin.name}  {bar}  {progress}/{nextSkin.price}🪙`
				skinNextLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
				skinNextLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
				skinNextLabel.Font = Enum.Font.Gotham
				skinNextLabel.TextXAlignment = Enum.TextXAlignment.Center
				skinNextLabel.Parent = self._gameOverFrame
			end
		end
	end

	-- 버튼들 가져오기
	local restartButton = self._gameOverFrame:FindFirstChild("RestartButton") :: TextButton?
	local lobbyButton = self._gameOverFrame:FindFirstChild("LobbyButton") :: TextButton?

	-- 부활 가능 시 버튼 배치 (비율 기반)
	if canRevive then
		if self._reviveButton then
			self._reviveButton.Visible = true
			self._reviveButton.Size = UDim2.new(0.7, 0, 0, 50)
			self._reviveButton.Position = UDim2.new(0.15, 0, 1, -118)
		end
		if restartButton then
			restartButton.Visible = true
			restartButton.Position = UDim2.new(0.03, 0, 1, -62)
		end
		if lobbyButton then
			lobbyButton.Visible = true
			lobbyButton.Position = UDim2.new(0.53, 0, 1, -62)
		end
	else
		if self._reviveButton then
			self._reviveButton.Visible = false
		end
		if restartButton then
			restartButton.Visible = true
			restartButton.Position = UDim2.new(0.03, 0, 1, -62)
		end
		if lobbyButton then
			lobbyButton.Visible = true
			lobbyButton.Position = UDim2.new(0.53, 0, 1, -62)
		end
	end

	-- 게임 오버 프레임 표시 (등장 애니메이션)
	self._gameOverFrame.Size = UDim2.new(0, 0, 0, 0)
	self._gameOverFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	self._gameOverFrame.Visible = true

	-- Phase B: 추가 통계가 있을 때 프레임 높이 확장
	local hasExtraStats = extraData and not canRevive
	local frameHeight = if canRevive then 380 elseif hasExtraStats then 523 else 360
	local targetSize = ResponsiveUtil.clampedSize(380, frameHeight, 0.88, 0.78)
	local targetPos = ResponsiveUtil.clampedPosition(380, frameHeight, 0.88, 0.78)
	local appearTween =
		TweenService:Create(self._gameOverFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = targetSize,
			Position = targetPos,
		})
	appearTween:Play()

	-- NEW RECORD 애니메이션 (깜빡임)
	if isNewRecord and newRecordLabel then
		task.spawn(function()
			for _ = 1, 6 do
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

	print(
		`[UIController] Game Over displayed - Score: {finalScore}, Coins: {earnedCoins}, Distance: {distance or 0}m, HighScore: {highScore or 0}, NewRecord: {isNewRecord or false}`
	)
end

-- 플레이 버튼 클릭 처리
function UIController:OnPlayButtonClicked()
	print("[UIController] Play button clicked")

	-- 시작 메뉴 숨기기
	self:HideStartMenu()

	-- 서버에 게임 시작 요청
	RemoteEvents.GameStart:FireServer()
end

-- 재시작 버튼 클릭 처리 (바로 게임 재시작)
function UIController:OnRestartButtonClicked()
	print("[UIController] Play Again clicked - restarting game")

	-- 버튼 비활성화 (서버 응답 대기 중 이중 클릭 방지)
	if self._gameOverFrame then
		local restartBtn = self._gameOverFrame:FindFirstChild("RestartButton") :: TextButton?
		local lobbyBtn = self._gameOverFrame:FindFirstChild("LobbyButton") :: TextButton?
		if restartBtn then
			restartBtn.Active = false
			restartBtn.Text = "..."
		end
		if lobbyBtn then
			lobbyBtn.Active = false
		end
	end

	-- 서버에 게임 시작 요청 (HideGameOver는 GameStart.OnClientEvent에서 처리)
	RemoteEvents.GameStart:FireServer()
end

-- 로비 버튼 클릭 처리 (로비로 복귀)
function UIController:OnLobbyButtonClicked()
	print("[UIController] Lobby button clicked - returning to lobby")

	-- 버튼 비활성화 (서버 응답 대기 중 이중 클릭 방지)
	if self._gameOverFrame then
		local restartBtn = self._gameOverFrame:FindFirstChild("RestartButton") :: TextButton?
		local lobbyBtn = self._gameOverFrame:FindFirstChild("LobbyButton") :: TextButton?
		if restartBtn then
			restartBtn.Active = false
		end
		if lobbyBtn then
			lobbyBtn.Active = false
			lobbyBtn.Text = "..."
		end
	end

	-- 서버에 로비 복귀 요청 (HideGameOver는 ReturnToLobby.OnClientEvent에서 처리)
	RemoteEvents.ReturnToLobby:FireServer()
end

-- 부활 버튼 클릭 처리
function UIController:OnReviveButtonClicked()
	print("[UIController] Revive button clicked")

	-- 게임 오버 화면 숨기기
	self:HideGameOver()

	-- 서버에 부활 요청
	RemoteEvents.Revive:FireServer()
end

-- 로비 UI 표시
function UIController:ShowLobbyUI()
	-- 로비 안내 표시
	if self._lobbyGuide then
		self._lobbyGuide.Visible = true
	end
	if self._highScoreDisplay then
		self._highScoreDisplay.Visible = true
	end
	if self._lobbyCharacterBtn then
		self._lobbyCharacterBtn.Visible = true
	end

	-- 게임 UI 숨기기
	if self._hudFrame then
		self._hudFrame.Visible = false
	end
	if self._livesContainer then
		self._livesContainer.Visible = false
	end
	if self._jumpButton then
		self._jumpButton.Visible = false
	end
	if self._slideButton then
		self._slideButton.Visible = false
	end

	-- 시작 메뉴 숨기기 (더 이상 사용 안 함)
	if self._startMenuFrame then
		self._startMenuFrame.Visible = false
	end

	-- 로비 안내 텍스트 펄스 애니메이션 (task.spawn 루프 - 코드베이스 표준 패턴)
	self._lobbyGuideAnimation = true
	if self._lobbyGuide then
		task.spawn(function()
			local guide = self._lobbyGuide
			if not guide then
				return
			end
			local stroke = guide:FindFirstChildOfClass("UIStroke")
			local label = guide:FindFirstChild("Label") :: TextLabel?

			while self._lobbyGuideAnimation and guide and guide.Parent do
				-- Fade out (밝아짐)
				local tweenOut = TweenService:Create(
					guide,
					TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ BackgroundTransparency = 0.55 }
				)
				tweenOut:Play()
				if stroke then
					TweenService:Create(
						stroke :: UIStroke,
						TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{ Thickness = 5 }
					):Play()
				end
				if label then
					TweenService:Create(
						label,
						TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{ TextSize = ResponsiveUtil.scaledTextSize(30, 20) }
					):Play()
				end
				tweenOut.Completed:Wait()

				if not self._lobbyGuideAnimation or not guide or not guide.Parent then
					break
				end

				-- Fade in (원래대로)
				local tweenIn = TweenService:Create(
					guide,
					TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ BackgroundTransparency = 0.15 }
				)
				tweenIn:Play()
				if stroke then
					TweenService:Create(
						stroke :: UIStroke,
						TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{ Thickness = 3 }
					):Play()
				end
				if label then
					TweenService:Create(
						label,
						TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{ TextSize = ResponsiveUtil.scaledTextSize(26, 18) }
					):Play()
				end
				tweenIn.Completed:Wait()
			end
		end)
	end
end

-- 로비 UI 숨기기 (게임 시작 시)
function UIController:HideLobbyUI()
	-- 로비 안내 펄스 애니메이션 정리 (플래그 off → 루프 자동 종료)
	self._lobbyGuideAnimation = false
	if self._lobbyGuide then
		self._lobbyGuide.BackgroundTransparency = 0.15

		local stroke = self._lobbyGuide:FindFirstChildOfClass("UIStroke")
		if stroke then
			(stroke :: UIStroke).Thickness = 3
		end

		local label = self._lobbyGuide:FindFirstChild("Label") :: TextLabel?
		if label then
			label.TextSize = ResponsiveUtil.scaledTextSize(26, 18)
		end
	end

	-- 로비 UI 숨기기
	if self._lobbyGuide then
		self._lobbyGuide.Visible = false
	end
	if self._highScoreDisplay then
		self._highScoreDisplay.Visible = false
	end
	if self._lobbyCharacterBtn then
		self._lobbyCharacterBtn.Visible = false
	end

	-- 게임 UI 표시
	if self._hudFrame then
		self._hudFrame.Visible = true
	end
	if self._livesContainer then
		self._livesContainer.Visible = true
	end
	if self._jumpButton then
		self._jumpButton.Visible = true
	end
	if self._slideButton then
		self._slideButton.Visible = true
	end

	-- UI 값 초기화
	self:UpdateScore(0, 0, 0)
	self:UpdateCoins(0)
	self:UpdateLives(GameConstants.LIFE.STARTING_LIVES)
end

-- 캐릭터 선택 버튼 콜백 등록
function UIController:SetCharacterSelectCallback(callback: () -> ())
	self._onCharacterSelectCallback = callback
end

-- 최고 점수 표시 업데이트
function UIController:UpdateHighScoreDisplay(highScore: number, coins: number)
	if not self._highScoreDisplay then
		return
	end

	local scoreLabel = self._highScoreDisplay:FindFirstChild("Score") :: TextLabel?
	if scoreLabel then
		scoreLabel.Text = `Score: {highScore}`
	end

	local coinsLabel = self._highScoreDisplay:FindFirstChild("Coins") :: TextLabel?
	if coinsLabel then
		coinsLabel.Text = `Coins: {coins}`
	end
end

-- 시작 메뉴 표시 (호환성 유지)
function UIController:ShowStartMenu()
	self:ShowLobbyUI()
end

-- 시작 메뉴 숨기기 (호환성 유지)
function UIController:HideStartMenu()
	self:HideLobbyUI()
end

-- 게임 오버 화면 복구 (부활 실패 시 - 기존 스코어 데이터 유지, 부활 버튼만 숨김)
function UIController:RestoreGameOver()
	if self._gameOverFrame then
		self._gameOverFrame.Visible = true
	end
	if self._reviveButton then
		self._reviveButton.Visible = false -- 이미 실패했으므로 부활 버튼 재노출 안 함
	end
end

-- 게임 오버 화면 숨기기 (재시작 시)
function UIController:HideGameOver()
	if self._gameOverFrame then
		self._gameOverFrame.Visible = false

		-- 배경 딤 숨기기
		if self._gameOverDim then
			self._gameOverDim.Visible = false
		end

		-- NEW RECORD 숨기기
		local newRecordLabel = self._gameOverFrame:FindFirstChild("NewRecord") :: TextLabel?
		if newRecordLabel then
			newRecordLabel.Visible = false
		end

		-- Phase B: 추가 통계 UI 정리
		local statsRow2 = self._gameOverFrame:FindFirstChild("StatsRow2")
		if statsRow2 then
			statsRow2:Destroy()
		end
		local zoneReached = self._gameOverFrame:FindFirstChild("ZoneReached")
		if zoneReached then
			zoneReached:Destroy()
		end
		local almostMsg = self._gameOverFrame:FindFirstChild("AlmostMessage")
		if almostMsg then
			almostMsg:Destroy()
		end
		local objSummary = self._gameOverFrame:FindFirstChild("ObjSummaryRow")
		if objSummary then
			objSummary:Destroy()
		end

		-- 버튼 위치 초기화
		local restartButton = self._gameOverFrame:FindFirstChild("RestartButton") :: TextButton?
		if restartButton then
			restartButton.Visible = true
			restartButton.Active = true
			restartButton.Text = "▶ PLAY AGAIN"
			restartButton.Position = UDim2.new(0.03, 0, 1, -62)
		end

		local lobbyButton = self._gameOverFrame:FindFirstChild("LobbyButton") :: TextButton?
		if lobbyButton then
			lobbyButton.Visible = true
			lobbyButton.Active = true
			lobbyButton.Text = "🏠 LOBBY"
			lobbyButton.Position = UDim2.new(0.53, 0, 1, -62)
		end
	end

	-- 부활 버튼 숨기기
	if self._reviveButton then
		self._reviveButton.Visible = false
	end
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
		local notif = self._tutorialNotification
		notif.BackgroundTransparency = 1
		local textLabel = notif:FindFirstChildOfClass("TextLabel")
		if textLabel then
			textLabel.TextTransparency = 1
		end
		notif.Visible = true
		TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.2,
		}):Play()
		if textLabel then
			TweenService:Create(textLabel, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		end
		task.delay(2, function()
			if not notif or not notif.Parent then return end
			local fadeOut = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			})
			fadeOut:Play()
			if textLabel and textLabel.Parent then
				TweenService:Create(textLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			end
			fadeOut.Completed:Connect(function()
				if notif and notif.Parent then
					notif.Visible = false
				end
			end)
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

			-- 팝 애니메이션: 큰 TextSize에서 목표 크기로 줄어들기
			local popSize = ResponsiveUtil.scaledTextSize(72, 36)
			local targetSize = ResponsiveUtil.scaledTextSize(48, 28)
			countdownLabel.TextSize = popSize
			TweenService:Create(countdownLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				TextSize = targetSize,
			}):Play()

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

-- 게임 피드백 플로팅 텍스트 (니어미스, 콤보 등)
function UIController:ShowGameFeedback(text: string, color: Color3)
	if not self._screenGui then
		return
	end

	local feedbackLabel = Instance.new("TextLabel")
	feedbackLabel.Name = "GameFeedback"
	feedbackLabel.Size = ResponsiveUtil.clampedSize(300, 50, 0.70, 0.10)
	local feedbackW = math.min(300, ResponsiveUtil.getViewportSize().X * 0.70)
	feedbackLabel.Position = UDim2.new(0.5, -feedbackW / 2, 0.4, 0)
	feedbackLabel.BackgroundTransparency = 1
	feedbackLabel.TextColor3 = color
	feedbackLabel.TextSize = ResponsiveUtil.scaledTextSize(28, 18)
	feedbackLabel.Font = Enum.Font.GothamBlack
	feedbackLabel.Text = text
	feedbackLabel.TextStrokeTransparency = 0
	feedbackLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	feedbackLabel.Parent = self._screenGui

	-- Float up and fade out
	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(feedbackLabel, tweenInfo, {
		Position = UDim2.new(0.5, -150, 0.3, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		feedbackLabel:Destroy()
	end)
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

-- Phase 2: 신기록 임박 알림 HUD
function UIController:ShowNearRecordAlert(data: { currentScore: number, highScore: number })
	if not self._screenGui then
		return
	end

	-- 기존 알림 제거
	local existing = self._screenGui:FindFirstChild("NearRecordFrame")
	if existing then
		existing:Destroy()
	end

	local frame = Instance.new("Frame")
	frame.Name = "NearRecordFrame"
	frame.Size = ResponsiveUtil.clampedSize(300, 36, 0.80, 0.08)
	-- Y=0.80 상대 위치로 모바일 버튼(슬라이드/점프) 영역과 겹치지 않게 배치
	frame.Position = UDim2.new(
		0.5,
		-math.min(300, ResponsiveUtil.getViewportSize().X * 0.80) / 2,
		0.80,
		0
	)
	frame.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = self._screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = `MY BEST: {data.highScore} <- YOU: {data.currentScore}`
	label.TextColor3 = Color3.fromRGB(50, 30, 0)
	label.TextSize = ResponsiveUtil.scaledTextSize(14, 11)
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	-- Pulse animation
	task.spawn(function()
		for _ = 1, 15 do
			if not frame or not frame.Parent then
				break
			end
			local fadeOut =
				TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { BackgroundTransparency = 0.7 })
			fadeOut:Play()
			fadeOut.Completed:Wait()
			if not frame or not frame.Parent then
				break
			end
			local fadeIn =
				TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { BackgroundTransparency = 0.2 })
			fadeIn:Play()
			fadeIn.Completed:Wait()
		end
		if frame and frame.Parent then
			frame:Destroy()
		end
	end)
end

-- Phase 2: 신기록 축하 이펙트
function UIController:ShowNewRecordCelebration()
	if not self._screenGui then
		return
	end

	local celebFrame = Instance.new("Frame")
	celebFrame.Name = "CelebrationFrame"
	celebFrame.Size = UDim2.new(1, 0, 1, 0)
	celebFrame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	celebFrame.BackgroundTransparency = 0.8
	celebFrame.BorderSizePixel = 0
	celebFrame.Parent = self._screenGui

	local celebLabel = Instance.new("TextLabel")
	celebLabel.Name = "CelebLabel"
	celebLabel.Size = UDim2.new(1, 0, 0, 60)
	celebLabel.Position = UDim2.new(0, 0, 0.35, 0)
	celebLabel.BackgroundTransparency = 1
	celebLabel.Text = "NEW RECORD!"
	celebLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	celebLabel.TextSize = ResponsiveUtil.scaledTextSize(40, 24)
	celebLabel.Font = Enum.Font.GothamBold
	celebLabel.TextStrokeTransparency = 0
	celebLabel.TextStrokeColor3 = Color3.fromRGB(150, 80, 0)
	celebLabel.Parent = celebFrame

	-- Scale animation
	celebLabel.TextSize = ResponsiveUtil.scaledTextSize(10, 8)
	local growTween = TweenService:Create(
		celebLabel,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ TextSize = ResponsiveUtil.scaledTextSize(40, 24) }
	)
	growTween:Play()

	-- Flash effect
	task.spawn(function()
		for _ = 1, 4 do
			if not celebFrame or not celebFrame.Parent then
				break
			end
			local flashTween = TweenService:Create(celebFrame, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 })
			flashTween:Play()
			flashTween.Completed:Wait()
			if not celebFrame or not celebFrame.Parent then
				break
			end
			local unflashTween = TweenService:Create(celebFrame, TweenInfo.new(0.2), { BackgroundTransparency = 0.9 })
			unflashTween:Play()
			unflashTween.Completed:Wait()
		end

		task.wait(1)
		if celebFrame and celebFrame.Parent then
			local fadeTween = TweenService:Create(celebFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
			local labelFade = TweenService:Create(
				celebLabel,
				TweenInfo.new(0.5),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			)
			fadeTween:Play()
			labelFade:Play()
			fadeTween.Completed:Wait()
			if celebFrame and celebFrame.Parent then
				celebFrame:Destroy()
			end
		end
	end)
end

-- 생존 배율 뱃지 업데이트
function UIController:UpdateSurvivalMultiplierBadge(data: { tier: number, multiplier: number, label: string? })
	if not self._screenGui then
		return
	end

	-- 기존 뱃지 제거
	if self._multiplierBadge then
		self._multiplierBadge:Destroy()
		self._multiplierBadge = nil
	end

	-- tier 0 = 배율 없음 → 뱃지 숨김
	if data.tier == 0 then
		return
	end

	-- 배율 뱃지 생성 (HUD 우측 상단)
	local badge = Instance.new("Frame")
	badge.Name = "SurvivalMultiplierBadge"
	badge.Size = UDim2.new(0, 90, 0, 32)
	badge.Position = UDim2.new(1, -100, 0, 155) -- 메인 HUD(~138px) 아래에 배치
	badge.BackgroundColor3 = if data.tier >= 3
		then Color3.fromRGB(80, 0, 160) -- 3단계: 보라
		elseif data.tier == 2
		then Color3.fromRGB(20, 80, 200) -- 2단계: 파랑
		else Color3.fromRGB(200, 80, 20) -- 1단계: 주황
	badge.BackgroundTransparency = 0.15
	badge.BorderSizePixel = 0
	badge.ZIndex = 5
	badge.Parent = self._screenGui
	self._multiplierBadge = badge

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = badge

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = data.label or `x{data.multiplier}`
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = ResponsiveUtil.scaledTextSize(15, 12)
	label.Font = Enum.Font.GothamBold
	label.ZIndex = 6
	label.Parent = badge

	-- 출현 애니메이션
	badge.Size = UDim2.new(0, 0, 0, 32)
	TweenService:Create(badge, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 90, 0, 32),
	}):Play()

	-- 마일스톤 토스트 (배율 상승 시)
	local toastText = if data.tier >= 3
		then "💎 생존 배율 MAX! x3.0"
		elseif data.tier == 2
		then "⚡ 생존 배율 업! x2.0"
		else "🔥 생존 배율 시작! x1.5"
	self:_showSurvivalToast(toastText)
end

-- 생존 배율 토스트 (간소)
function UIController:_showSurvivalToast(text: string)
	if not self._screenGui then
		return
	end
	local toast = Instance.new("TextLabel")
	toast.Name = "SurvivalToast"
	toast.Size = UDim2.new(0, 260, 0, 30)
	toast.Position = UDim2.new(0.5, -130, 0.75, 0)
	toast.BackgroundTransparency = 1
	toast.Text = text
	toast.TextColor3 = Color3.fromRGB(255, 220, 60)
	toast.TextSize = ResponsiveUtil.scaledTextSize(16, 13)
	toast.Font = Enum.Font.GothamBold
	toast.TextStrokeTransparency = 0.4
	toast.ZIndex = 8
	toast.Parent = self._screenGui

	TweenService:Create(toast, TweenInfo.new(0.2), { Position = UDim2.new(0.5, -130, 0.72, 0) }):Play()
	task.delay(1.5, function()
		if toast and toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(0.4, function()
				if toast and toast.Parent then
					toast:Destroy()
				end
			end)
		end
	end)
end

-- 히트 러시 토스트
function UIController:ShowHitRushToast(duration: number)
	if not self._screenGui then
		return
	end
	local toast = Instance.new("Frame")
	toast.Name = "HitRushToast"
	toast.Size = UDim2.new(0, 220, 0, 40)
	toast.Position = UDim2.new(0.5, -110, 0.65, 0)
	toast.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	toast.BackgroundTransparency = 0.2
	toast.BorderSizePixel = 0
	toast.ZIndex = 8
	toast.Parent = self._screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = `💰 코인 러시! x{GameConstants.HIT_RECOVERY.COIN_MULTIPLIER}`
	label.TextColor3 = Color3.fromRGB(255, 255, 200)
	label.TextSize = ResponsiveUtil.scaledTextSize(16, 13)
	label.Font = Enum.Font.GothamBold
	label.ZIndex = 9
	label.Parent = toast

	-- 슬라이드 인
	toast.Position = UDim2.new(0.5, -110, 0.7, 0)
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -110, 0.65, 0),
	}):Play()

	task.delay(duration - 0.4, function()
		if toast and toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(
				label,
				TweenInfo.new(0.4),
				{ TextTransparency = 1, TextStrokeTransparency = 1 }
			):Play()
			task.delay(0.4, function()
				if toast and toast.Parent then
					toast:Destroy()
				end
			end)
		end
	end)
end

return UIController

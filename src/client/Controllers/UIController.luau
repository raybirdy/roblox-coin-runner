--!strict
-- UI Controller
-- 게임 UI 관리 (점수, 코인, 라이프 표시)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		_distanceLabel: TextLabel?,
		_gameOverFrame: Frame?,
		_startMenuFrame: Frame?,
		_jumpButton: TextButton?,
		_slideButton: TextButton?,
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
		_distanceLabel = nil,
		_gameOverFrame = nil,
		_startMenuFrame = nil,
		_jumpButton = nil,
		_slideButton = nil,
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

	-- 라이프 표시 (상단 오른쪽)
	local livesLabel = Instance.new("TextLabel")
	livesLabel.Name = "LivesLabel"
	livesLabel.Size = UDim2.new(0, 150, 0, 40)
	livesLabel.Position = UDim2.new(1, -160, 0, 10)
	livesLabel.BackgroundTransparency = 0.3
	livesLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	livesLabel.TextColor3 = Color3.fromRGB(255, 0, 0) -- 빨간색
	livesLabel.TextSize = 20
	livesLabel.Font = Enum.Font.GothamBold
	livesLabel.Text = "❤️ 3"
	livesLabel.Parent = screenGui
	self._livesLabel = livesLabel

	-- 둥근 모서리
	local livesCorner = Instance.new("UICorner")
	livesCorner.CornerRadius = UDim.new(0, 8)
	livesCorner.Parent = livesLabel

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
	gameOverFrame.Size = UDim2.new(0, 450, 0, 400)
	gameOverFrame.Position = UDim2.new(0.5, -225, 0.5, -200)
	gameOverFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	gameOverFrame.BackgroundTransparency = 0.2
	gameOverFrame.Visible = false
	gameOverFrame.Parent = screenGui
	self._gameOverFrame = gameOverFrame

	-- 둥근 모서리
	local gameOverCorner = Instance.new("UICorner")
	gameOverCorner.CornerRadius = UDim.new(0, 16)
	gameOverCorner.Parent = gameOverFrame

	-- 테두리
	local gameOverStroke = Instance.new("UIStroke")
	gameOverStroke.Color = Color3.fromRGB(255, 255, 255)
	gameOverStroke.Thickness = 3
	gameOverStroke.Transparency = 0.5
	gameOverStroke.Parent = gameOverFrame

	-- 게임 오버 텍스트
	local gameOverTitle = Instance.new("TextLabel")
	gameOverTitle.Name = "Title"
	gameOverTitle.Size = UDim2.new(1, 0, 0, 60)
	gameOverTitle.Position = UDim2.new(0, 0, 0, 20)
	gameOverTitle.BackgroundTransparency = 1
	gameOverTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	gameOverTitle.TextSize = 36
	gameOverTitle.Font = Enum.Font.GothamBold
	gameOverTitle.Text = "GAME OVER"
	gameOverTitle.Parent = gameOverFrame

	-- 최종 점수
	local finalScoreLabel = Instance.new("TextLabel")
	finalScoreLabel.Name = "FinalScore"
	finalScoreLabel.Size = UDim2.new(1, 0, 0, 40)
	finalScoreLabel.Position = UDim2.new(0, 0, 0, 100)
	finalScoreLabel.BackgroundTransparency = 1
	finalScoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	finalScoreLabel.TextSize = 24
	finalScoreLabel.Font = Enum.Font.Gotham
	finalScoreLabel.Text = "Score: 0"
	finalScoreLabel.Parent = gameOverFrame

	-- 획득 코인
	local earnedCoinsLabel = Instance.new("TextLabel")
	earnedCoinsLabel.Name = "EarnedCoins"
	earnedCoinsLabel.Size = UDim2.new(1, 0, 0, 40)
	earnedCoinsLabel.Position = UDim2.new(0, 0, 0, 150)
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
	highScoreLabel.Position = UDim2.new(0, 0, 0, 200)
	highScoreLabel.BackgroundTransparency = 1
	highScoreLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	highScoreLabel.TextSize = 22
	highScoreLabel.Font = Enum.Font.GothamBold
	highScoreLabel.Text = "🏆 High Score: 0"
	highScoreLabel.Parent = gameOverFrame

	-- 재시작 버튼
	local restartButton = Instance.new("TextButton")
	restartButton.Name = "RestartButton"
	restartButton.Size = UDim2.new(0, 250, 0, 60)
	restartButton.Position = UDim2.new(0.5, -125, 0, 280)
	restartButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
	restartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	restartButton.TextSize = 28
	restartButton.Font = Enum.Font.GothamBold
	restartButton.Text = "PLAY AGAIN"
	restartButton.Parent = gameOverFrame

	-- 둥근 모서리
	local restartCorner = Instance.new("UICorner")
	restartCorner.CornerRadius = UDim.new(0, 12)
	restartCorner.Parent = restartButton

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
		self:ShowGameOver(data.finalScore, data.earnedCoins, data.highScore)
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
	if self._livesLabel then
		local hearts = string.rep("❤️", lives)
		self._livesLabel.Text = hearts
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
function UIController:ShowGameOver(finalScore: number, earnedCoins: number, highScore: number?)
	if not self._gameOverFrame then
		return
	end

	-- 최종 점수 표시
	local finalScoreLabel = self._gameOverFrame:FindFirstChild("FinalScore") :: TextLabel?
	if finalScoreLabel then
		finalScoreLabel.Text = `Final Score: {finalScore}`
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

	-- 게임 오버 프레임 표시
	self._gameOverFrame.Visible = true

	print(`[UIController] Game Over displayed - Score: {finalScore}, Coins: {earnedCoins}, HighScore: {highScore or 0}`)
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
	if self._livesLabel then
		self._livesLabel.Visible = false
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
	if self._livesLabel then
		self._livesLabel.Visible = true
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
	end

	-- UI 초기화
	self:UpdateScore(0, 0, 0)
	self:UpdateCoins(0)
	self:UpdateLives(GameConstants.LIFE.STARTING_LIVES)
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

--!strict
-- Leaderboard Controller
-- 리더보드 관련 클라이언트 로직 (로비에 물리적 간판 + 클릭 시 팝업)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local LeaderboardController = {}
LeaderboardController.__index = LeaderboardController

export type LeaderboardController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_playerRank: number?,
		_currentTab: string,
		_connections: { RBXScriptConnection },
		_popupGui: ScreenGui?,
		_popupFrame: Frame?,
		_contentFrame: Frame?,
		_tabButtons: { [string]: TextButton },
		_rankLabels: { [number]: { name: TextLabel, score: TextLabel } },
		_playerRankLabel: TextLabel?,
		_isPopupOpen: boolean,
	},
	LeaderboardController
))

function LeaderboardController.new(player: Player): LeaderboardController
	local self = setmetatable({
		_player = player,
		_playerRank = nil,
		_currentTab = "all",
		_connections = {},
		_popupGui = nil,
		_popupFrame = nil,
		_contentFrame = nil,
		_tabButtons = {},
		_rankLabels = {},
		_playerRankLabel = nil,
		_isPopupOpen = false,
	}, LeaderboardController)

	self:_createPopupGui()
	self:_setupEventHandlers()
	self:_setupClickDetector()

	return self
end

-- 팝업 ScreenGui 생성
function LeaderboardController:_createPopupGui()
	local playerGui = self._player:WaitForChild("PlayerGui")

	-- ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LeaderboardPopupGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 15
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	self._popupGui = screenGui

	-- 딤 배경
	local dimBg = Instance.new("TextButton")
	dimBg.Name = "DimBackground"
	dimBg.Size = UDim2.new(1, 0, 1, 0)
	dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimBg.BackgroundTransparency = 0.5
	dimBg.Text = ""
	dimBg.AutoButtonColor = false
	dimBg.Parent = screenGui

	dimBg.MouseButton1Click:Connect(function()
		self:ClosePopup()
	end)

	-- 팝업 프레임
	local popupFrame = Instance.new("Frame")
	popupFrame.Name = "PopupFrame"
	popupFrame.Size = UDim2.new(0, 400, 0, 520)
	popupFrame.Position = UDim2.new(0.5, -200, 0.5, -260)
	popupFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	popupFrame.BorderSizePixel = 0
	popupFrame.Parent = screenGui
	self._popupFrame = popupFrame

	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 12)
	popupCorner.Parent = popupFrame

	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = Color3.fromRGB(255, 215, 0)
	popupStroke.Thickness = 2
	popupStroke.Parent = popupFrame

	-- 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -60, 0, 40)
	titleLabel.Position = UDim2.new(0, 15, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = 24
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "LEADERBOARD"
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = popupFrame

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -46, 0, 12)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 20
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.Parent = popupFrame

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:ClosePopup()
	end)

	-- 탭 컨테이너
	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.Size = UDim2.new(1, -30, 0, 36)
	tabContainer.Position = UDim2.new(0, 15, 0, 55)
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = popupFrame

	-- 탭 버튼 생성
	local tabs = {
		{ key = "all", label = "ALL" },
		{ key = "daily", label = "DAILY" },
		{ key = "weekly", label = "WEEKLY" },
	}

	local tabWidth = math.floor((370 - 2 * 5) / 3) -- 3개 탭, 간격 5px
	for i, tab in tabs do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = "Tab_" .. tab.key
		tabBtn.Size = UDim2.new(0, tabWidth, 1, 0)
		tabBtn.Position = UDim2.new(0, (i - 1) * (tabWidth + 5), 0, 0)
		tabBtn.BackgroundColor3 = tab.key == "all" and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(50, 50, 70)
		tabBtn.TextColor3 = tab.key == "all" and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)
		tabBtn.TextSize = 14
		tabBtn.Font = Enum.Font.GothamBold
		tabBtn.Text = tab.label
		tabBtn.Parent = tabContainer

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 8)
		tabCorner.Parent = tabBtn

		tabBtn.MouseButton1Click:Connect(function()
			self:_onTabClicked(tab.key)
		end)

		self._tabButtons[tab.key] = tabBtn
	end

	-- 콘텐츠 영역
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -30, 0, 370)
	contentFrame.Position = UDim2.new(0, 15, 0, 100)
	contentFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	contentFrame.BorderSizePixel = 0
	contentFrame.Parent = popupFrame
	self._contentFrame = contentFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 8)
	contentCorner.Parent = contentFrame

	-- 10개의 순위 슬롯 미리 생성
	for i = 1, 10 do
		local rankFrame = Instance.new("Frame")
		rankFrame.Name = `Rank{i}`
		rankFrame.Size = UDim2.new(1, -20, 0, 33)
		rankFrame.Position = UDim2.new(0, 10, 0, 5 + (i - 1) * 35)
		rankFrame.BackgroundTransparency = (i % 2 == 0) and 0.9 or 1
		rankFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
		rankFrame.Parent = contentFrame

		local frameCorner = Instance.new("UICorner")
		frameCorner.CornerRadius = UDim.new(0, 4)
		frameCorner.Parent = rankFrame

		-- 순위별 색상
		local rankColors = {
			[1] = Color3.fromRGB(255, 215, 0), -- 금
			[2] = Color3.fromRGB(192, 192, 192), -- 은
			[3] = Color3.fromRGB(205, 127, 50), -- 동
		}
		local textColor = rankColors[i] or Color3.fromRGB(200, 200, 200)

		-- 순위 번호
		local rankLabel = Instance.new("TextLabel")
		rankLabel.Name = "RankNum"
		rankLabel.Size = UDim2.new(0, 35, 1, 0)
		rankLabel.Position = UDim2.new(0, 5, 0, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.TextColor3 = textColor
		rankLabel.TextSize = 16
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.Text = `#{i}`
		rankLabel.TextXAlignment = Enum.TextXAlignment.Left
		rankLabel.Parent = rankFrame

		-- 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.Size = UDim2.new(0, 200, 1, 0)
		nameLabel.Position = UDim2.new(0, 45, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = "---"
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = rankFrame

		-- 점수
		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Name = "Score"
		scoreLabel.Size = UDim2.new(0, 80, 1, 0)
		scoreLabel.Position = UDim2.new(1, -90, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		scoreLabel.TextSize = 14
		scoreLabel.Font = Enum.Font.GothamBold
		scoreLabel.Text = "0"
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Parent = rankFrame

		self._rankLabels[i] = { name = nameLabel, score = scoreLabel }
	end

	-- 내 순위 라벨 (하단)
	local myRankLabel = Instance.new("TextLabel")
	myRankLabel.Name = "MyRank"
	myRankLabel.Size = UDim2.new(1, -30, 0, 30)
	myRankLabel.Position = UDim2.new(0, 15, 1, -40)
	myRankLabel.BackgroundTransparency = 1
	myRankLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	myRankLabel.TextSize = 14
	myRankLabel.Font = Enum.Font.GothamBold
	myRankLabel.Text = ""
	myRankLabel.TextXAlignment = Enum.TextXAlignment.Left
	myRankLabel.Parent = popupFrame
	self._playerRankLabel = myRankLabel
end

-- ClickDetector 연결 (로비 리더보드 간판)
function LeaderboardController:_setupClickDetector()
	-- workspace.Lobby가 생성될 때까지 대기
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 10)
		if not lobby then
			warn("[LeaderboardController] Lobby not found")
			return
		end

		local board = lobby:WaitForChild("LeaderboardBackground", 10) :: BasePart?
		if not board then
			warn("[LeaderboardController] LeaderboardBackground not found")
			return
		end

		local clickDetector = board:WaitForChild("LeaderboardClick", 10) :: ClickDetector?
		if not clickDetector then
			warn("[LeaderboardController] LeaderboardClick not found")
			return
		end

		local clickConnection = clickDetector.MouseClick:Connect(function()
			if self._isPopupOpen then
				self:ClosePopup()
			else
				self:OpenPopup()
			end
		end)
		table.insert(self._connections, clickConnection)

		print("[LeaderboardController] ClickDetector connected")
	end)
end

-- 이벤트 핸들러 설정
function LeaderboardController:_setupEventHandlers()
	-- 리더보드 데이터 수신
	local dataConnection = RemoteEvents.LeaderboardData.OnClientEvent:Connect(function(data)
		self._playerRank = data.playerRank
		self:_updatePopupContent(data.leaderboard, data.playerRank, data.tab)
		print(`[LeaderboardController] Data received (tab: {data.tab or "all"}, rank: {data.playerRank or "N/A"})`)
	end)
	table.insert(self._connections, dataConnection)

	print("[LeaderboardController] Event handlers set up")
end

-- 탭 클릭 핸들러
function LeaderboardController:_onTabClicked(tab: string)
	self._currentTab = tab

	-- 탭 버튼 스타일 업데이트
	for key, btn in self._tabButtons do
		if key == tab then
			btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			btn.TextColor3 = Color3.fromRGB(0, 0, 0)
		else
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
			btn.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end

	-- 서버에 해당 탭 데이터 요청
	self:RequestUpdate()
end

-- 팝업 콘텐츠 업데이트
function LeaderboardController:_updatePopupContent(
	leaderboard: { { rank: number, name: string, score: number } }?,
	playerRank: number?,
	_tab: string?
)
	if not leaderboard then
		return
	end

	-- 순위 슬롯 업데이트
	for i = 1, 10 do
		local labels = self._rankLabels[i]
		if not labels then
			continue
		end

		if leaderboard[i] then
			local entry = leaderboard[i]
			labels.name.Text = entry.name
			labels.score.Text = tostring(entry.score)
		else
			labels.name.Text = "---"
			labels.score.Text = "0"
		end
	end

	-- 내 순위 표시
	if self._playerRankLabel then
		if playerRank then
			self._playerRankLabel.Text = `My Rank: #{playerRank}`
		else
			self._playerRankLabel.Text = "My Rank: Not ranked"
		end
	end
end

-- 팝업 열기
function LeaderboardController:OpenPopup()
	if self._isPopupOpen then
		return
	end
	self._isPopupOpen = true

	if self._popupGui then
		self._popupGui.Enabled = true
	end

	-- 팝업 등장 애니메이션
	if self._popupFrame then
		self._popupFrame.Size = UDim2.new(0, 400, 0, 0)
		self._popupFrame.Position = UDim2.new(0.5, -200, 0.5, 0)

		local tween = TweenService:Create(self._popupFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 400, 0, 520),
			Position = UDim2.new(0.5, -200, 0.5, -260),
		})
		tween:Play()
	end

	-- 현재 탭 데이터 요청
	self:RequestUpdate()

	print("[LeaderboardController] Popup opened")
end

-- 팝업 닫기
function LeaderboardController:ClosePopup()
	if not self._isPopupOpen then
		return
	end
	self._isPopupOpen = false

	-- 팝업 닫기 애니메이션
	if self._popupFrame then
		local tween = TweenService:Create(self._popupFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 400, 0, 0),
			Position = UDim2.new(0.5, -200, 0.5, 0),
		})
		tween:Play()
		tween.Completed:Connect(function()
			if self._popupGui then
				self._popupGui.Enabled = false
			end
		end)
	else
		if self._popupGui then
			self._popupGui.Enabled = false
		end
	end

	print("[LeaderboardController] Popup closed")
end

-- 리더보드 데이터 요청 (서버에서 로비 간판 업데이트)
function LeaderboardController:RequestUpdate()
	RemoteEvents.LeaderboardRequest:FireServer({ tab = self._currentTab })
end

-- 탭 전환
function LeaderboardController:SwitchTab(tab: string)
	self:_onTabClicked(tab)
end

-- 현재 탭 가져오기
function LeaderboardController:GetCurrentTab(): string
	return self._currentTab
end

-- 내 순위 가져오기
function LeaderboardController:GetPlayerRank(): number?
	return self._playerRank
end

-- 로비 진입 시 호출 (리더보드 요청)
function LeaderboardController:Show()
	-- 서버에 리더보드 데이터 요청 (로비 간판 업데이트 트리거)
	self:RequestUpdate()
	print("[LeaderboardController] Requested leaderboard update")
end

-- 게임 시작 시 호출
function LeaderboardController:Hide()
	-- 팝업이 열려있으면 닫기
	if self._isPopupOpen then
		self:ClosePopup()
	end
	print("[LeaderboardController] Game started (lobby board remains)")
end

-- 표시 여부
function LeaderboardController:IsVisible(): boolean
	return self._isPopupOpen
end

-- 정리
function LeaderboardController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	if self._popupGui then
		self._popupGui:Destroy()
		self._popupGui = nil
	end
end

return LeaderboardController

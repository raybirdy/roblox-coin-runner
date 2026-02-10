--!strict
-- Leaderboard Controller
-- 로비 리더보드 UI 관리

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local LeaderboardController = {}
LeaderboardController.__index = LeaderboardController

export type LeaderboardController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_playerGui: PlayerGui,
		_screenGui: ScreenGui?,
		_leaderboardFrame: Frame?,
		_connections: { RBXScriptConnection },
		_isVisible: boolean,
	},
	LeaderboardController
))

function LeaderboardController.new(player: Player): LeaderboardController
	local self = setmetatable({
		_player = player,
		_playerGui = player:WaitForChild("PlayerGui") :: PlayerGui,
		_screenGui = nil,
		_leaderboardFrame = nil,
		_connections = {},
		_isVisible = false,
	}, LeaderboardController)

	self:_createUI()
	self:_setupEventHandlers()

	return self
end

-- 리더보드 UI 생성
function LeaderboardController:_createUI()
	-- ScreenGui 생성
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LeaderboardUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = self._playerGui
	self._screenGui = screenGui

	-- 리더보드 프레임 (왼쪽에 배치)
	local leaderboardFrame = Instance.new("Frame")
	leaderboardFrame.Name = "LeaderboardFrame"
	leaderboardFrame.Size = UDim2.new(0, 280, 0, 400)
	leaderboardFrame.Position = UDim2.new(0, 20, 0.5, -200)
	leaderboardFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
	leaderboardFrame.BackgroundTransparency = 0.15
	leaderboardFrame.Visible = false
	leaderboardFrame.Parent = screenGui
	self._leaderboardFrame = leaderboardFrame

	-- 둥근 모서리
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 16)
	frameCorner.Parent = leaderboardFrame

	-- 테두리
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(255, 215, 0)
	frameStroke.Thickness = 3
	frameStroke.Parent = leaderboardFrame

	-- 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 50)
	titleLabel.Position = UDim2.new(0, 0, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = 28
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "LEADERBOARD"
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.Parent = leaderboardFrame

	-- 순위 목록 컨테이너
	local listContainer = Instance.new("ScrollingFrame")
	listContainer.Name = "ListContainer"
	listContainer.Size = UDim2.new(1, -20, 0, 300)
	listContainer.Position = UDim2.new(0, 10, 0, 55)
	listContainer.BackgroundTransparency = 1
	listContainer.ScrollBarThickness = 4
	listContainer.ScrollingDirection = Enum.ScrollingDirection.Y
	listContainer.Parent = leaderboardFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = listContainer

	-- 내 순위 표시 (하단)
	local myRankFrame = Instance.new("Frame")
	myRankFrame.Name = "MyRankFrame"
	myRankFrame.Size = UDim2.new(1, -20, 0, 40)
	myRankFrame.Position = UDim2.new(0, 10, 1, -50)
	myRankFrame.BackgroundColor3 = Color3.fromRGB(0, 100, 50)
	myRankFrame.BackgroundTransparency = 0.3
	myRankFrame.Parent = leaderboardFrame

	local myRankCorner = Instance.new("UICorner")
	myRankCorner.CornerRadius = UDim.new(0, 8)
	myRankCorner.Parent = myRankFrame

	local myRankLabel = Instance.new("TextLabel")
	myRankLabel.Name = "MyRankLabel"
	myRankLabel.Size = UDim2.new(1, 0, 1, 0)
	myRankLabel.BackgroundTransparency = 1
	myRankLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	myRankLabel.TextSize = 18
	myRankLabel.Font = Enum.Font.GothamBold
	myRankLabel.Text = "MY RANK: -"
	myRankLabel.TextStrokeTransparency = 0.5
	myRankLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	myRankLabel.Parent = myRankFrame

	print("[LeaderboardController] UI created")
end

-- 이벤트 핸들러 설정
function LeaderboardController:_setupEventHandlers()
	-- 리더보드 데이터 수신
	local dataConnection = RemoteEvents.LeaderboardData.OnClientEvent:Connect(function(data)
		self:_updateLeaderboard(data.leaderboard, data.playerRank)
	end)
	table.insert(self._connections, dataConnection)

	print("[LeaderboardController] Event handlers set up")
end

-- 리더보드 업데이트
function LeaderboardController:_updateLeaderboard(leaderboard: { { rank: number, name: string, score: number } }, playerRank: number?)
	if not self._leaderboardFrame then
		return
	end

	local listContainer = self._leaderboardFrame:FindFirstChild("ListContainer") :: ScrollingFrame?
	if not listContainer then
		return
	end

	-- 기존 항목 제거
	for _, child in listContainer:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- 순위별 색상
	local rankColors = {
		[1] = Color3.fromRGB(255, 215, 0), -- 금
		[2] = Color3.fromRGB(192, 192, 192), -- 은
		[3] = Color3.fromRGB(205, 127, 50), -- 동
	}

	-- 순위 항목 생성
	for _, entry in leaderboard do
		local entryFrame = Instance.new("Frame")
		entryFrame.Name = `Rank{entry.rank}`
		entryFrame.Size = UDim2.new(1, 0, 0, 28)
		entryFrame.BackgroundColor3 = entry.rank <= 3 and rankColors[entry.rank] or Color3.fromRGB(60, 60, 80)
		entryFrame.BackgroundTransparency = entry.rank <= 3 and 0.3 or 0.5
		entryFrame.LayoutOrder = entry.rank
		entryFrame.Parent = listContainer

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 6)
		entryCorner.Parent = entryFrame

		-- 순위 번호
		local rankLabel = Instance.new("TextLabel")
		rankLabel.Name = "Rank"
		rankLabel.Size = UDim2.new(0, 35, 1, 0)
		rankLabel.Position = UDim2.new(0, 5, 0, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.TextColor3 = entry.rank <= 3 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
		rankLabel.TextSize = 16
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.Text = `#{entry.rank}`
		rankLabel.TextXAlignment = Enum.TextXAlignment.Left
		rankLabel.Parent = entryFrame

		-- 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(0, 120, 1, 0)
		nameLabel.Position = UDim2.new(0, 40, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = entry.name
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = entryFrame

		-- 점수
		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Name = "Score"
		scoreLabel.Size = UDim2.new(0, 80, 1, 0)
		scoreLabel.Position = UDim2.new(1, -85, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		scoreLabel.TextSize = 14
		scoreLabel.Font = Enum.Font.GothamBold
		scoreLabel.Text = tostring(entry.score)
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Parent = entryFrame
	end

	-- 캔버스 크기 업데이트
	local layout = listContainer:FindFirstChild("UIListLayout") :: UIListLayout?
	if layout then
		listContainer.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end

	-- 내 순위 업데이트
	local myRankFrame = self._leaderboardFrame:FindFirstChild("MyRankFrame") :: Frame?
	if myRankFrame then
		local myRankLabel = myRankFrame:FindFirstChild("MyRankLabel") :: TextLabel?
		if myRankLabel then
			if playerRank then
				myRankLabel.Text = `MY RANK: #{playerRank}`
			else
				myRankLabel.Text = "MY RANK: Not ranked"
			end
		end
	end

	print(`[LeaderboardController] Updated with {#leaderboard} entries`)
end

-- 리더보드 표시
function LeaderboardController:Show()
	if not self._leaderboardFrame then
		return
	end

	self._isVisible = true
	self._leaderboardFrame.Visible = true

	-- 서버에 리더보드 데이터 요청
	RemoteEvents.LeaderboardRequest:FireServer()

	-- 등장 애니메이션
	self._leaderboardFrame.Position = UDim2.new(-0.3, 0, 0.5, -200)
	local tween = TweenService:Create(self._leaderboardFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 20, 0.5, -200),
	})
	tween:Play()

	print("[LeaderboardController] Shown")
end

-- 리더보드 숨기기
function LeaderboardController:Hide()
	if not self._leaderboardFrame then
		return
	end

	self._isVisible = false

	-- 사라지는 애니메이션
	local tween = TweenService:Create(self._leaderboardFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(-0.3, 0, 0.5, -200),
	})
	tween:Play()
	tween.Completed:Connect(function()
		if self._leaderboardFrame and not self._isVisible then
			self._leaderboardFrame.Visible = false
		end
	end)

	print("[LeaderboardController] Hidden")
end

-- 표시 여부
function LeaderboardController:IsVisible(): boolean
	return self._isVisible
end

-- 정리
function LeaderboardController:Destroy()
	if self._screenGui then
		self._screenGui:Destroy()
	end

	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return LeaderboardController

--!strict
-- RankingController
-- 주간 순위쟁탈전 UI: 로비 버튼 + 팝업 (현재 순위 + 보상 체계)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local RankingController = {}
RankingController.__index = RankingController

export type RankingController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_connections: { RBXScriptConnection },
		_gui: ScreenGui?,
		_popupFrame: Frame?,
		_lobbyButton: TextButton?,
		_isOpen: boolean,
		-- 순위 데이터
		_myWeeklyRank: number?,
		-- 순위 슬롯
		_rankLabels: { [number]: { name: TextLabel, score: TextLabel, reward: TextLabel? } },
		_myRankLabel: TextLabel?,
	},
	RankingController
))

function RankingController.new(player: Player): RankingController
	local self = setmetatable({
		_player = player,
		_connections = {},
		_gui = nil,
		_popupFrame = nil,
		_lobbyButton = nil,
		_isOpen = false,
		_myWeeklyRank = nil,
		_rankLabels = {},
		_myRankLabel = nil,
	}, RankingController)

	self:_createGui()
	self:_setupEventHandlers()

	return self
end

-- ==================== GUI 생성 ====================

function RankingController:_createGui()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "RankingGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 16
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	-- 딤 배경
	local dimBg = Instance.new("TextButton")
	dimBg.Name = "DimBackground"
	dimBg.Size = UDim2.new(1, 0, 1, 0)
	dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimBg.BackgroundTransparency = 0.5
	dimBg.Text = ""
	dimBg.AutoButtonColor = false
	dimBg.Parent = gui

	dimBg.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- 팝업 프레임
	local popupFrame = Instance.new("Frame")
	popupFrame.Name = "RankingPopup"
	popupFrame.Size = ResponsiveUtil.clampedSize(420, 580, 0.94, 0.92)
	popupFrame.Position = ResponsiveUtil.clampedPosition(420, 580, 0.94, 0.92)
	popupFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 40)
	popupFrame.BorderSizePixel = 0
	popupFrame.Parent = gui
	self._popupFrame = popupFrame

	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 14)
	popupCorner.Parent = popupFrame

	-- 황금 테두리
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 0)
	stroke.Thickness = 2.5
	stroke.Parent = popupFrame

	-- 타이틀 배경
	local titleBg = Instance.new("Frame")
	titleBg.Name = "TitleBg"
	titleBg.Size = UDim2.new(1, 0, 0, 54)
	titleBg.Position = UDim2.new(0, 0, 0, 0)
	titleBg.BackgroundColor3 = Color3.fromRGB(20, 30, 70)
	titleBg.BorderSizePixel = 0
	titleBg.Parent = popupFrame

	local titleBgCorner = Instance.new("UICorner")
	titleBgCorner.CornerRadius = UDim.new(0, 14)
	titleBgCorner.Parent = titleBg

	-- 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -60, 1, 0)
	titleLabel.Position = UDim2.new(0, 16, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 210, 0)
	titleLabel.TextSize = ResponsiveUtil.scaledTextSize(22, 16)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "🏆 주간 순위쟁탈전"
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBg

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -50, 0, 7)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "✕"
	closeBtn.Parent = popupFrame

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- 내 순위 배너
	local myRankBanner = Instance.new("Frame")
	myRankBanner.Size = UDim2.new(1, -24, 0, 42)
	myRankBanner.Position = UDim2.new(0, 12, 0, 60)
	myRankBanner.BackgroundColor3 = Color3.fromRGB(30, 60, 120)
	myRankBanner.BorderSizePixel = 0
	myRankBanner.Parent = popupFrame

	local myRankCorner = Instance.new("UICorner")
	myRankCorner.CornerRadius = UDim.new(0, 8)
	myRankCorner.Parent = myRankBanner

	local myRankLabel = Instance.new("TextLabel")
	myRankLabel.Size = UDim2.new(1, -10, 1, 0)
	myRankLabel.Position = UDim2.new(0, 10, 0, 0)
	myRankLabel.BackgroundTransparency = 1
	myRankLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	myRankLabel.TextSize = ResponsiveUtil.scaledTextSize(15, 12)
	myRankLabel.Font = Enum.Font.GothamBold
	myRankLabel.Text = "내 현재 순위: 집계 중..."
	myRankLabel.TextXAlignment = Enum.TextXAlignment.Left
	myRankLabel.Parent = myRankBanner
	self._myRankLabel = myRankLabel

	-- 보상 체계 헤더
	local rewardHeader = Instance.new("TextLabel")
	rewardHeader.Size = UDim2.new(1, -24, 0, 24)
	rewardHeader.Position = UDim2.new(0, 12, 0, 108)
	rewardHeader.BackgroundTransparency = 1
	rewardHeader.TextColor3 = Color3.fromRGB(180, 180, 200)
	rewardHeader.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
	rewardHeader.Font = Enum.Font.Gotham
	rewardHeader.Text = "순위별 주간 보상 (매주 월요일 지급)"
	rewardHeader.TextXAlignment = Enum.TextXAlignment.Left
	rewardHeader.Parent = popupFrame

	-- 리더보드 헤더
	local boardHeader = Instance.new("Frame")
	boardHeader.Size = UDim2.new(1, -24, 0, 28)
	boardHeader.Position = UDim2.new(0, 12, 0, 135)
	boardHeader.BackgroundColor3 = Color3.fromRGB(40, 45, 70)
	boardHeader.BorderSizePixel = 0
	boardHeader.Parent = popupFrame

	local boardHeaderCorner = Instance.new("UICorner")
	boardHeaderCorner.CornerRadius = UDim.new(0, 6)
	boardHeaderCorner.Parent = boardHeader

	local headerRank = Instance.new("TextLabel")
	headerRank.Size = UDim2.new(0, 40, 1, 0)
	headerRank.Position = UDim2.new(0, 8, 0, 0)
	headerRank.BackgroundTransparency = 1
	headerRank.TextColor3 = Color3.fromRGB(180, 180, 200)
	headerRank.TextSize = 11
	headerRank.Font = Enum.Font.GothamBold
	headerRank.Text = "순위"
	headerRank.Parent = boardHeader

	local headerName = Instance.new("TextLabel")
	headerName.Size = UDim2.new(0, 170, 1, 0)
	headerName.Position = UDim2.new(0, 52, 0, 0)
	headerName.BackgroundTransparency = 1
	headerName.TextColor3 = Color3.fromRGB(180, 180, 200)
	headerName.TextSize = 11
	headerName.Font = Enum.Font.GothamBold
	headerName.Text = "플레이어"
	headerName.TextXAlignment = Enum.TextXAlignment.Left
	headerName.Parent = boardHeader

	local headerScore = Instance.new("TextLabel")
	headerScore.Size = UDim2.new(0, 70, 1, 0)
	headerScore.Position = UDim2.new(1, -140, 0, 0)
	headerScore.BackgroundTransparency = 1
	headerScore.TextColor3 = Color3.fromRGB(180, 180, 200)
	headerScore.TextSize = 11
	headerScore.Font = Enum.Font.GothamBold
	headerScore.Text = "점수"
	headerScore.TextXAlignment = Enum.TextXAlignment.Right
	headerScore.Parent = boardHeader

	local headerReward = Instance.new("TextLabel")
	headerReward.Size = UDim2.new(0, 60, 1, 0)
	headerReward.Position = UDim2.new(1, -65, 0, 0)
	headerReward.BackgroundTransparency = 1
	headerReward.TextColor3 = Color3.fromRGB(255, 215, 0)
	headerReward.TextSize = 11
	headerReward.Font = Enum.Font.GothamBold
	headerReward.Text = "보상"
	headerReward.TextXAlignment = Enum.TextXAlignment.Center
	headerReward.Parent = boardHeader

	-- 리더보드 슬롯 (최대 10개)
	local rankColors = {
		[1] = Color3.fromRGB(255, 215, 0),
		[2] = Color3.fromRGB(192, 192, 192),
		[3] = Color3.fromRGB(205, 127, 50),
	}

	for i = 1, 10 do
		local rowBg = Instance.new("Frame")
		rowBg.Name = `Rank{i}`
		rowBg.Size = UDim2.new(1, -24, 0, 30)
		rowBg.Position = UDim2.new(0, 12, 0, 163 + (i - 1) * 32)
		rowBg.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(25, 30, 55) or Color3.fromRGB(20, 25, 45)
		rowBg.BorderSizePixel = 0
		rowBg.Parent = popupFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = rowBg

		local textColor = rankColors[i] or Color3.fromRGB(200, 200, 210)

		local rankNum = Instance.new("TextLabel")
		rankNum.Name = "RankNum"
		rankNum.Size = UDim2.new(0, 40, 1, 0)
		rankNum.Position = UDim2.new(0, 8, 0, 0)
		rankNum.BackgroundTransparency = 1
		rankNum.TextColor3 = textColor
		rankNum.TextSize = ResponsiveUtil.scaledTextSize(14, 11)
		rankNum.Font = Enum.Font.GothamBold
		rankNum.Text = `#{i}`
		rankNum.Parent = rowBg

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "PlayerName"
		nameLbl.Size = UDim2.new(0, 170, 1, 0)
		nameLbl.Position = UDim2.new(0, 52, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextColor3 = Color3.fromRGB(240, 240, 255)
		nameLbl.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
		nameLbl.Font = Enum.Font.Gotham
		nameLbl.Text = "---"
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = rowBg

		local scoreLbl = Instance.new("TextLabel")
		scoreLbl.Name = "Score"
		scoreLbl.Size = UDim2.new(0, 70, 1, 0)
		scoreLbl.Position = UDim2.new(1, -140, 0, 0)
		scoreLbl.BackgroundTransparency = 1
		scoreLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
		scoreLbl.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
		scoreLbl.Font = Enum.Font.GothamBold
		scoreLbl.Text = "0"
		scoreLbl.TextXAlignment = Enum.TextXAlignment.Right
		scoreLbl.Parent = rowBg

		local rewardLbl = Instance.new("TextLabel")
		rewardLbl.Name = "Reward"
		rewardLbl.Size = UDim2.new(0, 60, 1, 0)
		rewardLbl.Position = UDim2.new(1, -65, 0, 0)
		rewardLbl.BackgroundTransparency = 1
		rewardLbl.TextColor3 = Color3.fromRGB(100, 220, 120)
		rewardLbl.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
		rewardLbl.Font = Enum.Font.GothamBold
		rewardLbl.Text = ""
		rewardLbl.TextXAlignment = Enum.TextXAlignment.Center
		rewardLbl.Parent = rowBg

		self._rankLabels[i] = { name = nameLbl, score = scoreLbl, reward = rewardLbl }
	end

	-- 로비 트리거 버튼 (우측 상단 고정)
	local lobbyGui = Instance.new("ScreenGui")
	lobbyGui.Name = "RankingLobbyButton"
	lobbyGui.ResetOnSpawn = false
	lobbyGui.DisplayOrder = 12
	lobbyGui.Enabled = false
	lobbyGui.Parent = playerGui

	local lobbyBtn = Instance.new("TextButton")
	lobbyBtn.Name = "TrophyButton"
	lobbyBtn.Size = UDim2.new(0, 52, 0, 52)
	lobbyBtn.Position = UDim2.new(1, -64, 0, 120)
	lobbyBtn.BackgroundColor3 = Color3.fromRGB(20, 30, 70)
	lobbyBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
	lobbyBtn.TextSize = 26
	lobbyBtn.Font = Enum.Font.GothamBold
	lobbyBtn.Text = "🏆"
	lobbyBtn.Parent = lobbyGui

	local lobbyBtnCorner = Instance.new("UICorner")
	lobbyBtnCorner.CornerRadius = UDim.new(0, 12)
	lobbyBtnCorner.Parent = lobbyBtn

	local lobbyBtnStroke = Instance.new("UIStroke")
	lobbyBtnStroke.Color = Color3.fromRGB(255, 200, 0)
	lobbyBtnStroke.Thickness = 2
	lobbyBtnStroke.Parent = lobbyBtn

	lobbyBtn.MouseButton1Click:Connect(function()
		self:Open()
	end)

	self._lobbyButton = lobbyGui
end

-- ==================== 이벤트 ====================

function RankingController:_setupEventHandlers()
	local rankConn = RemoteEvents.WeeklyRankUpdate.OnClientEvent:Connect(function(data)
		self:_updateRankingData(data)
	end)
	table.insert(self._connections, rankConn)
end

function RankingController:_updateRankingData(data: any)
	local topPlayers = data.topPlayers or {}
	local rewardTiers = data.rewardTiers or {}
	local myRank = data.weeklyRank

	self._myWeeklyRank = myRank

	-- 내 순위 배너 업데이트
	if self._myRankLabel then
		if myRank then
			local rewardGems = self:_getRewardForRank(myRank, rewardTiers)
			local rewardText = rewardGems > 0 and ` (💎 +{rewardGems} 보상 예정)` or ""
			self._myRankLabel.Text = `내 현재 순위: #{myRank}{rewardText}`
		else
			self._myRankLabel.Text = "내 현재 순위: 미집계 (게임 플레이 필요)"
		end
	end

	-- 순위 슬롯 업데이트
	for i = 1, 10 do
		local labels = self._rankLabels[i]
		if not labels then
			continue
		end

		local entry = topPlayers[i]
		if entry then
			labels.name.Text = entry.name
			labels.score.Text = tostring(entry.score)
			-- 보상 계산
			local gems = self:_getRewardForRank(entry.rank, rewardTiers)
			if labels.reward then
				labels.reward.Text = gems > 0 and `💎{gems}` or "-"
			end
			-- 내 플레이어 하이라이트
			if entry.name == self._player.Name then
				labels.name.TextColor3 = Color3.fromRGB(100, 220, 255)
			else
				labels.name.TextColor3 = Color3.fromRGB(240, 240, 255)
			end
		else
			labels.name.Text = "---"
			labels.score.Text = "0"
			if labels.reward then
				labels.reward.Text = ""
			end
		end
	end
end

function RankingController:_getRewardForRank(rank: number, tiers: { any }): number
	for _, tier in tiers do
		if rank <= tier.maxRank then
			return tier.gems
		end
	end
	return 0
end

-- ==================== 열기/닫기 ====================

function RankingController:Open()
	if self._isOpen then
		return
	end
	self._isOpen = true

	local gui = self._gui
	if gui then
		gui.Enabled = true
	end

	-- 팝업 애니메이션
	if self._popupFrame then
		local targetSize = ResponsiveUtil.clampedSize(420, 580, 0.94, 0.92)
		local targetW = targetSize.X.Offset
		self._popupFrame.Size = UDim2.new(0, targetW, 0, 0)
		self._popupFrame.Position = UDim2.new(0.5, -targetW / 2, 0.5, 0)

		TweenService:Create(
			self._popupFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{
				Size = targetSize,
				Position = ResponsiveUtil.clampedPosition(420, 580, 0.94, 0.92),
			}
		):Play()
	end

	-- 주간 랭킹 데이터 요청 (LeaderboardRequest weekly)
	RemoteEvents.LeaderboardRequest:FireServer({ tab = "weekly" })
end

function RankingController:Close()
	if not self._isOpen then
		return
	end
	self._isOpen = false

	if self._popupFrame then
		local w = self._popupFrame.Size.X.Offset
		TweenService:Create(
			self._popupFrame,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Size = UDim2.new(0, w, 0, 0),
				Position = UDim2.new(0.5, -w / 2, 0.5, 0),
			}
		):Play()

		task.delay(0.25, function()
			if self._gui and not self._isOpen then
				self._gui.Enabled = false
			end
		end)
	else
		if self._gui then
			self._gui.Enabled = false
		end
	end
end

function RankingController:ShowInLobby()
	if self._lobbyButton then
		self._lobbyButton.Enabled = true
	end
end

function RankingController:HideForGame()
	if self._isOpen then
		self:Close()
	end
	if self._lobbyButton then
		self._lobbyButton.Enabled = false
	end
end

function RankingController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	if self._lobbyButton then
		self._lobbyButton:Destroy()
		self._lobbyButton = nil
	end
end

return RankingController

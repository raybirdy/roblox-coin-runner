--!strict
-- RealtimeBattleController
-- 실시간 배틀: 대기 UI + 게임 중 상대 점수 HUD + 결과 오버레이

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local RealtimeBattleController = {}
RealtimeBattleController.__index = RealtimeBattleController

export type RealtimeBattleController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_connections: { RBXScriptConnection },
		-- 대기 화면
		_queueGui: ScreenGui?,
		_queueTimerLabel: TextLabel?,
		_queueTask: thread?,
		-- 게임 중 HUD
		_hudGui: ScreenGui?,
		_opponentNameLabel: TextLabel?,
		_opponentScoreLabel: TextLabel?,
		-- 결과 오버레이
		_resultGui: ScreenGui?,
		-- 로비 버튼 GUI
		_lobbyGui: ScreenGui?,
		-- 현재 상태
		_isQueuing: boolean,
		_isInBattle: boolean,
		_currentOpponentName: string?,
	},
	RealtimeBattleController
))

function RealtimeBattleController.new(player: Player): RealtimeBattleController
	local self = setmetatable({
		_player = player,
		_connections = {},
		_queueGui = nil,
		_queueTimerLabel = nil,
		_queueTask = nil,
		_hudGui = nil,
		_opponentNameLabel = nil,
		_opponentScoreLabel = nil,
		_resultGui = nil,
		_lobbyGui = nil,
		_isQueuing = false,
		_isInBattle = false,
		_currentOpponentName = nil,
	}, RealtimeBattleController)

	self:_createGui()
	self:_setupEventHandlers()

	return self
end

-- ==================== GUI 생성 ====================

function RealtimeBattleController:_createGui()
	local playerGui = self._player:WaitForChild("PlayerGui")

	-- ── 대기 화면 ──────────────────────────────────────────
	local queueGui = Instance.new("ScreenGui")
	queueGui.Name = "BattleQueueGui"
	queueGui.ResetOnSpawn = false
	queueGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	queueGui.DisplayOrder = 22
	queueGui.Enabled = false
	queueGui.Parent = playerGui
	self._queueGui = queueGui

	local queueDim = Instance.new("Frame")
	queueDim.Size = UDim2.new(1, 0, 1, 0)
	queueDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	queueDim.BackgroundTransparency = 0.5
	queueDim.BorderSizePixel = 0
	queueDim.Parent = queueGui

	local queuePanel = Instance.new("Frame")
	queuePanel.Size = UDim2.new(0, 300, 0, 180)
	queuePanel.Position = UDim2.new(0.5, -150, 0.38, 0)
	queuePanel.BackgroundColor3 = Color3.fromRGB(15, 20, 50)
	queuePanel.BorderSizePixel = 0
	queuePanel.Parent = queueGui

	local queueCorner = Instance.new("UICorner")
	queueCorner.CornerRadius = UDim.new(0, 14)
	queueCorner.Parent = queuePanel

	local queueStroke = Instance.new("UIStroke")
	queueStroke.Color = Color3.fromRGB(100, 150, 255)
	queueStroke.Thickness = 2
	queueStroke.Parent = queuePanel

	local queueTitle = Instance.new("TextLabel")
	queueTitle.Size = UDim2.new(1, 0, 0, 50)
	queueTitle.BackgroundTransparency = 1
	queueTitle.TextColor3 = Color3.fromRGB(100, 180, 255)
	queueTitle.TextSize = ResponsiveUtil.scaledTextSize(20, 16)
	queueTitle.Font = Enum.Font.GothamBlack
	queueTitle.Text = "⚔️ 실시간 배틀"
	queueTitle.Parent = queuePanel

	local queueStatus = Instance.new("TextLabel")
	queueStatus.Size = UDim2.new(1, 0, 0, 30)
	queueStatus.Position = UDim2.new(0, 0, 0, 50)
	queueStatus.BackgroundTransparency = 1
	queueStatus.TextColor3 = Color3.fromRGB(200, 200, 220)
	queueStatus.TextSize = ResponsiveUtil.scaledTextSize(14, 10)
	queueStatus.Font = Enum.Font.Gotham
	queueStatus.Text = "상대를 찾는 중..."
	queueStatus.Parent = queuePanel

	local queueTimer = Instance.new("TextLabel")
	queueTimer.Name = "Timer"
	queueTimer.Size = UDim2.new(1, 0, 0, 36)
	queueTimer.Position = UDim2.new(0, 0, 0, 82)
	queueTimer.BackgroundTransparency = 1
	queueTimer.TextColor3 = Color3.fromRGB(255, 215, 0)
	queueTimer.TextSize = ResponsiveUtil.scaledTextSize(22, 14)
	queueTimer.Font = Enum.Font.GothamBold
	queueTimer.Text = "12"
	queueTimer.Parent = queuePanel
	self._queueTimerLabel = queueTimer

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0, 140, 0, 36)
	cancelBtn.Position = UDim2.new(0.5, -70, 0, 130)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.TextSize = ResponsiveUtil.scaledTextSize(14, 10)
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.Text = "취소"
	cancelBtn.Parent = queuePanel

	local cancelBtnCorner = Instance.new("UICorner")
	cancelBtnCorner.CornerRadius = UDim.new(0, 8)
	cancelBtnCorner.Parent = cancelBtn

	cancelBtn.MouseButton1Click:Connect(function()
		self:_leaveQueue()
	end)

	-- ── 게임 중 HUD ──────────────────────────────────────────
	local hudGui = Instance.new("ScreenGui")
	hudGui.Name = "BattleHud"
	hudGui.ResetOnSpawn = false
	hudGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	hudGui.DisplayOrder = 21
	hudGui.Enabled = false
	hudGui.Parent = playerGui
	self._hudGui = hudGui

	local hudFrame = Instance.new("Frame")
	hudFrame.Size = UDim2.new(0, 200, 0, 56)
	hudFrame.Position = UDim2.new(0, 10, 0.5, -28)
	hudFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 50)
	hudFrame.BackgroundTransparency = 0.15
	hudFrame.BorderSizePixel = 0
	hudFrame.Parent = hudGui

	local hudCorner = Instance.new("UICorner")
	hudCorner.CornerRadius = UDim.new(0, 10)
	hudCorner.Parent = hudFrame

	local hudStroke = Instance.new("UIStroke")
	hudStroke.Color = Color3.fromRGB(100, 150, 255)
	hudStroke.Thickness = 2
	hudStroke.Parent = hudFrame

	local hudVsLabel = Instance.new("TextLabel")
	hudVsLabel.Size = UDim2.new(1, -8, 0, 22)
	hudVsLabel.Position = UDim2.new(0, 4, 0, 4)
	hudVsLabel.BackgroundTransparency = 1
	hudVsLabel.TextColor3 = Color3.fromRGB(150, 180, 255)
	hudVsLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
	hudVsLabel.Font = Enum.Font.GothamBold
	hudVsLabel.Text = "⚔️ VS"
	hudVsLabel.TextXAlignment = Enum.TextXAlignment.Left
	hudVsLabel.Parent = hudFrame

	local opponentNameLabel = Instance.new("TextLabel")
	opponentNameLabel.Name = "OpponentName"
	opponentNameLabel.Size = UDim2.new(1, -8, 0, 16)
	opponentNameLabel.Position = UDim2.new(0, 4, 0, 22)
	opponentNameLabel.BackgroundTransparency = 1
	opponentNameLabel.TextColor3 = Color3.fromRGB(200, 210, 255)
	opponentNameLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
	opponentNameLabel.Font = Enum.Font.Gotham
	opponentNameLabel.Text = "---"
	opponentNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	opponentNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	opponentNameLabel.Parent = hudFrame
	self._opponentNameLabel = opponentNameLabel

	local opponentScoreLabel = Instance.new("TextLabel")
	opponentScoreLabel.Name = "OpponentScore"
	opponentScoreLabel.Size = UDim2.new(1, -8, 0, 18)
	opponentScoreLabel.Position = UDim2.new(0, 4, 0, 36)
	opponentScoreLabel.BackgroundTransparency = 1
	opponentScoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	opponentScoreLabel.TextSize = ResponsiveUtil.scaledTextSize(16, 11)
	opponentScoreLabel.Font = Enum.Font.GothamBold
	opponentScoreLabel.Text = "0점"
	opponentScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	opponentScoreLabel.Parent = hudFrame
	self._opponentScoreLabel = opponentScoreLabel

	-- ── 결과 오버레이 ──────────────────────────────────────────
	local resultGui = Instance.new("ScreenGui")
	resultGui.Name = "BattleResultGui"
	resultGui.ResetOnSpawn = false
	resultGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	resultGui.DisplayOrder = 26
	resultGui.Enabled = false
	resultGui.Parent = playerGui
	self._resultGui = resultGui

	local resultDim = Instance.new("Frame")
	resultDim.Size = UDim2.new(1, 0, 1, 0)
	resultDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	resultDim.BackgroundTransparency = 0.45
	resultDim.BorderSizePixel = 0
	resultDim.Parent = resultGui

	local resultFrame = Instance.new("Frame")
	resultFrame.Name = "ResultFrame"
	resultFrame.Size = UDim2.new(0, 360, 0, 230)
	resultFrame.Position = UDim2.new(0.5, -180, 0.33, 0)
	resultFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 50)
	resultFrame.BorderSizePixel = 0
	resultFrame.Parent = resultGui

	local resultCorner = Instance.new("UICorner")
	resultCorner.CornerRadius = UDim.new(0, 14)
	resultCorner.Parent = resultFrame

	local resultStroke = Instance.new("UIStroke")
	resultStroke.Name = "ResultStroke"
	resultStroke.Color = Color3.fromRGB(100, 150, 255)
	resultStroke.Thickness = 2.5
	resultStroke.Parent = resultFrame

	local resultTitle = Instance.new("TextLabel")
	resultTitle.Name = "ResultTitle"
	resultTitle.Size = UDim2.new(1, 0, 0, 68)
	resultTitle.BackgroundTransparency = 1
	resultTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	resultTitle.TextSize = ResponsiveUtil.scaledTextSize(24, 15)
	resultTitle.Font = Enum.Font.GothamBlack
	resultTitle.Text = "🏆 승리!"
	resultTitle.Parent = resultFrame

	local resultDetail = Instance.new("TextLabel")
	resultDetail.Name = "ResultDetail"
	resultDetail.Size = UDim2.new(1, -20, 0, 60)
	resultDetail.Position = UDim2.new(0, 10, 0, 72)
	resultDetail.BackgroundTransparency = 1
	resultDetail.TextColor3 = Color3.fromRGB(200, 200, 220)
	resultDetail.TextSize = ResponsiveUtil.scaledTextSize(14, 10)
	resultDetail.Font = Enum.Font.Gotham
	resultDetail.TextWrapped = true
	resultDetail.Text = ""
	resultDetail.Parent = resultFrame

	local resultReward = Instance.new("TextLabel")
	resultReward.Name = "ResultReward"
	resultReward.Size = UDim2.new(1, 0, 0, 36)
	resultReward.Position = UDim2.new(0, 0, 0, 135)
	resultReward.BackgroundTransparency = 1
	resultReward.TextColor3 = Color3.fromRGB(80, 220, 100)
	resultReward.TextSize = ResponsiveUtil.scaledTextSize(20, 13)
	resultReward.Font = Enum.Font.GothamBold
	resultReward.Text = ""
	resultReward.Parent = resultFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 180, 0, 36)
	closeBtn.Position = UDim2.new(0.5, -90, 0, 180)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = ResponsiveUtil.scaledTextSize(14, 10)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "닫기"
	closeBtn.Parent = resultFrame

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		resultGui.Enabled = false
	end)

	-- ── 로비 버튼 (⚔️ 배틀) ──────────────────────────────────
	local lobbyGui = Instance.new("ScreenGui")
	lobbyGui.Name = "BattleLobbyButton"
	lobbyGui.ResetOnSpawn = false
	lobbyGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	lobbyGui.DisplayOrder = 12
	lobbyGui.Enabled = false
	lobbyGui.Parent = playerGui
	self._lobbyGui = lobbyGui

	local battleBtn = Instance.new("TextButton")
	battleBtn.Name = "BattleButton"
	battleBtn.Size = UDim2.new(0, 52, 0, 52)
	battleBtn.Position = UDim2.new(1, -64, 0, 182)
	battleBtn.BackgroundColor3 = Color3.fromRGB(20, 30, 80)
	battleBtn.TextColor3 = Color3.fromRGB(100, 170, 255)
	battleBtn.TextSize = ResponsiveUtil.scaledTextSize(22, 14)
	battleBtn.Font = Enum.Font.GothamBold
	battleBtn.Text = "⚔️"
	battleBtn.Parent = lobbyGui

	local battleBtnCorner = Instance.new("UICorner")
	battleBtnCorner.CornerRadius = UDim.new(0, 12)
	battleBtnCorner.Parent = battleBtn

	local battleBtnStroke = Instance.new("UIStroke")
	battleBtnStroke.Color = Color3.fromRGB(100, 150, 255)
	battleBtnStroke.Thickness = 2
	battleBtnStroke.Parent = battleBtn

	battleBtn.MouseButton1Click:Connect(function()
		self:_enterQueue()
	end)
end

-- ==================== 이벤트 ====================

function RealtimeBattleController:_setupEventHandlers()
	-- 매칭 완료
	local matchConn = RemoteEvents.BattleMatchFound.OnClientEvent:Connect(function(data)
		self:_onMatchFound(data)
	end)
	table.insert(self._connections, matchConn)

	-- 상대 점수 업데이트
	local scoreConn = RemoteEvents.BattleOpponentScore.OnClientEvent:Connect(function(data)
		if self._isInBattle and self._opponentScoreLabel then
			self._opponentScoreLabel.Text = `{data.score}점`
		end
	end)
	table.insert(self._connections, scoreConn)

	-- 배틀 결과
	local resultConn = RemoteEvents.BattleResult.OnClientEvent:Connect(function(data)
		self:_showResult(data)
	end)
	table.insert(self._connections, resultConn)
end

-- ==================== 큐 관리 ====================

function RealtimeBattleController:_enterQueue()
	if self._isQueuing or self._isInBattle then
		return
	end
	self._isQueuing = true

	-- 대기 화면 표시
	if self._queueGui then
		self._queueGui.Enabled = true
	end

	-- 타이머 카운트다운
	local remaining = 12
	self._queueTask = task.spawn(function()
		while remaining > 0 and self._isQueuing do
			if self._queueTimerLabel then
				self._queueTimerLabel.Text = tostring(remaining)
			end
			task.wait(1)
			remaining -= 1
		end
	end)

	RemoteEvents.BattleQueueEnter:FireServer()
end

function RealtimeBattleController:_leaveQueue()
	if not self._isQueuing then
		return
	end
	self._isQueuing = false

	if self._queueGui then
		self._queueGui.Enabled = false
	end

	RemoteEvents.BattleQueueLeave:FireServer()
end

function RealtimeBattleController:_onMatchFound(data: any)
	self._isQueuing = false
	self._isInBattle = true
	self._currentOpponentName = data.opponentName

	-- 대기 화면 닫기
	if self._queueGui then
		self._queueGui.Enabled = false
	end

	-- 상대 정보 설정
	if self._opponentNameLabel then
		local tag = data.isBot and " 🤖" or ""
		self._opponentNameLabel.Text = `{data.opponentName}{tag}`
	end
	if self._opponentScoreLabel then
		self._opponentScoreLabel.Text = "0점"
	end

	print(`[RealtimeBattleController] Match found: vs {data.opponentName} (bot: {data.isBot})`)
end

-- ==================== 게임 활성화 ====================

function RealtimeBattleController:SetGameActive(active: boolean)
	if active and self._isInBattle then
		-- 게임 시작: HUD 표시
		if self._hudGui then
			self._hudGui.Enabled = true
		end
	elseif not active then
		-- 게임 종료: HUD 숨기기
		if self._hudGui then
			self._hudGui.Enabled = false
		end
		self._isInBattle = false
	end
end

-- ==================== 로비 표시/숨기기 ====================

function RealtimeBattleController:ShowInLobby()
	if self._lobbyGui then
		self._lobbyGui.Enabled = true
	end
end

function RealtimeBattleController:HideForGame()
	if self._lobbyGui then
		self._lobbyGui.Enabled = false
	end
	-- 큐에 있었으면 취소
	if self._isQueuing then
		self:_leaveQueue()
	end
end

-- ==================== 결과 표시 ====================

function RealtimeBattleController:_showResult(data: any)
	local resultGui = self._resultGui
	if not resultGui then
		return
	end

	local resultFrame = resultGui:FindFirstChild("ResultFrame") :: Frame?
	if not resultFrame then
		return
	end

	local titleLbl = resultFrame:FindFirstChild("ResultTitle") :: TextLabel?
	local detailLbl = resultFrame:FindFirstChild("ResultDetail") :: TextLabel?
	local rewardLbl = resultFrame:FindFirstChild("ResultReward") :: TextLabel?
	local stroke = resultFrame:FindFirstChild("ResultStroke") :: UIStroke?

	if data.won then
		if titleLbl then
			titleLbl.Text = "🏆 승리!"
			titleLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
		end
		if stroke then
			stroke.Color = Color3.fromRGB(255, 215, 0)
		end
		if detailLbl then
			detailLbl.Text = `{data.opponentName}를 이겼어요!\n내 점수: {data.myScore}점 vs 상대: {data.opponentScore}점`
		end
		if rewardLbl then
			if data.reward and data.reward > 0 then
				rewardLbl.Text = `💎 +{data.reward} 젬 획득!`
			else
				rewardLbl.Text = ""
			end
		end
	else
		if titleLbl then
			titleLbl.Text = "💪 아깝다!"
			titleLbl.TextColor3 = Color3.fromRGB(150, 150, 255)
		end
		if stroke then
			stroke.Color = Color3.fromRGB(150, 150, 255)
		end
		if detailLbl then
			detailLbl.Text = `{data.opponentName}에게 졌어요.\n내 점수: {data.myScore}점 vs 상대: {data.opponentScore}점`
		end
		if rewardLbl then
			rewardLbl.Text = "다시 도전해보세요!"
		end
	end

	-- 등장 애니메이션
	resultFrame.Size = UDim2.new(0, 360, 0, 0)
	resultGui.Enabled = true
	TweenService:Create(
		resultFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 360, 0, 230) }
	):Play()

	-- 8초 후 자동 닫기
	task.delay(8, function()
		if resultGui then
			resultGui.Enabled = false
		end
	end)
end

-- ==================== 정리 ====================

function RealtimeBattleController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	if self._queueGui then
		self._queueGui:Destroy()
		self._queueGui = nil
	end
	if self._hudGui then
		self._hudGui:Destroy()
		self._hudGui = nil
	end
	if self._resultGui then
		self._resultGui:Destroy()
		self._resultGui = nil
	end
	if self._lobbyGui then
		self._lobbyGui:Destroy()
		self._lobbyGui = nil
	end
end

return RealtimeBattleController

--!strict
-- AsyncBattleController
-- 비동기 배틀 클라이언트: 게임 중 목표 점수 HUD + 결과 오버레이

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local AsyncBattleController = {}
AsyncBattleController.__index = AsyncBattleController

export type AsyncBattleController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_connections: { RBXScriptConnection },
		_hudGui: ScreenGui?,
		_resultGui: ScreenGui?,
		_targetScoreLabel: TextLabel?,
		_currentBattle: { targetName: string, targetScore: number }?,
	},
	AsyncBattleController
))

function AsyncBattleController.new(player: Player): AsyncBattleController
	local self = setmetatable({
		_player = player,
		_connections = {},
		_hudGui = nil,
		_resultGui = nil,
		_targetScoreLabel = nil,
		_currentBattle = nil,
	}, AsyncBattleController)

	self:_createGui()
	self:_setupEventHandlers()

	return self
end

-- ==================== GUI 생성 ====================

function AsyncBattleController:_createGui()
	local playerGui = self._player:WaitForChild("PlayerGui")

	-- 배틀 HUD (게임 중 상단 목표 점수 표시)
	local hudGui = Instance.new("ScreenGui")
	hudGui.Name = "AsyncBattleHud"
	hudGui.ResetOnSpawn = false
	hudGui.DisplayOrder = 20
	hudGui.Enabled = false
	hudGui.Parent = playerGui
	self._hudGui = hudGui

	local hudFrame = Instance.new("Frame")
	hudFrame.Size = UDim2.new(0, 210, 0, 50)
	hudFrame.Position = UDim2.new(0.5, -105, 0, 56)
	hudFrame.BackgroundColor3 = Color3.fromRGB(30, 15, 50)
	hudFrame.BackgroundTransparency = 0.15
	hudFrame.BorderSizePixel = 0
	hudFrame.Parent = hudGui

	local hudCorner = Instance.new("UICorner")
	hudCorner.CornerRadius = UDim.new(0, 10)
	hudCorner.Parent = hudFrame

	local hudStroke = Instance.new("UIStroke")
	hudStroke.Color = Color3.fromRGB(220, 80, 80)
	hudStroke.Thickness = 2
	hudStroke.Parent = hudFrame

	local vsLabel = Instance.new("TextLabel")
	vsLabel.Size = UDim2.new(1, 0, 0.45, 0)
	vsLabel.Position = UDim2.new(0, 0, 0, 0)
	vsLabel.BackgroundTransparency = 1
	vsLabel.TextColor3 = Color3.fromRGB(255, 130, 130)
	vsLabel.TextSize = 11
	vsLabel.Font = Enum.Font.GothamBold
	vsLabel.Text = "⚔️ 도전 모드"
	vsLabel.Parent = hudFrame

	local targetScoreLabel = Instance.new("TextLabel")
	targetScoreLabel.Name = "TargetScore"
	targetScoreLabel.Size = UDim2.new(1, 0, 0.55, 0)
	targetScoreLabel.Position = UDim2.new(0, 0, 0.45, 0)
	targetScoreLabel.BackgroundTransparency = 1
	targetScoreLabel.TextColor3 = Color3.fromRGB(255, 210, 210)
	targetScoreLabel.TextSize = 14
	targetScoreLabel.Font = Enum.Font.GothamBold
	targetScoreLabel.Text = "목표: ---"
	targetScoreLabel.Parent = hudFrame
	self._targetScoreLabel = targetScoreLabel

	-- 결과 오버레이
	local resultGui = Instance.new("ScreenGui")
	resultGui.Name = "AsyncBattleResult"
	resultGui.ResetOnSpawn = false
	resultGui.DisplayOrder = 25
	resultGui.Enabled = false
	resultGui.Parent = playerGui
	self._resultGui = resultGui

	local dimBg = Instance.new("Frame")
	dimBg.Size = UDim2.new(1, 0, 1, 0)
	dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimBg.BackgroundTransparency = 0.45
	dimBg.BorderSizePixel = 0
	dimBg.Parent = resultGui

	local resultFrame = Instance.new("Frame")
	resultFrame.Name = "ResultFrame"
	resultFrame.Size = UDim2.new(0, 350, 0, 210)
	resultFrame.Position = UDim2.new(0.5, -175, 0.34, 0)
	resultFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 50)
	resultFrame.BorderSizePixel = 0
	resultFrame.Parent = resultGui

	local resultCorner = Instance.new("UICorner")
	resultCorner.CornerRadius = UDim.new(0, 14)
	resultCorner.Parent = resultFrame

	local resultStroke = Instance.new("UIStroke")
	resultStroke.Name = "ResultStroke"
	resultStroke.Color = Color3.fromRGB(255, 215, 0)
	resultStroke.Thickness = 2.5
	resultStroke.Parent = resultFrame

	local resultTitle = Instance.new("TextLabel")
	resultTitle.Name = "ResultTitle"
	resultTitle.Size = UDim2.new(1, 0, 0, 64)
	resultTitle.BackgroundTransparency = 1
	resultTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
	resultTitle.TextSize = 34
	resultTitle.Font = Enum.Font.GothamBlack
	resultTitle.Text = "🏆 승리!"
	resultTitle.Parent = resultFrame

	local resultDetail = Instance.new("TextLabel")
	resultDetail.Name = "ResultDetail"
	resultDetail.Size = UDim2.new(1, -20, 0, 52)
	resultDetail.Position = UDim2.new(0, 10, 0, 68)
	resultDetail.BackgroundTransparency = 1
	resultDetail.TextColor3 = Color3.fromRGB(200, 200, 220)
	resultDetail.TextSize = 15
	resultDetail.Font = Enum.Font.Gotham
	resultDetail.TextWrapped = true
	resultDetail.Text = ""
	resultDetail.Parent = resultFrame

	local resultReward = Instance.new("TextLabel")
	resultReward.Name = "ResultReward"
	resultReward.Size = UDim2.new(1, 0, 0, 36)
	resultReward.Position = UDim2.new(0, 0, 0, 122)
	resultReward.BackgroundTransparency = 1
	resultReward.TextColor3 = Color3.fromRGB(80, 220, 100)
	resultReward.TextSize = 20
	resultReward.Font = Enum.Font.GothamBold
	resultReward.Text = ""
	resultReward.Parent = resultFrame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 180, 0, 36)
	closeBtn.Position = UDim2.new(0.5, -90, 0, 163)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "닫기"
	closeBtn.Parent = resultFrame

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		resultGui.Enabled = false
	end)
end

-- ==================== 이벤트 ====================

function AsyncBattleController:_setupEventHandlers()
	local resultConn = RemoteEvents.AsyncBattleResult.OnClientEvent:Connect(function(data)
		self:_showResult(data)
	end)
	table.insert(self._connections, resultConn)
end

function AsyncBattleController:_showResult(data: any)
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
			detailLbl.Text = `{data.targetName}의 기록 {data.targetScore}점을 넘었어요!\n내 점수: {data.myScore}점`
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
			detailLbl.Text = `목표: {data.targetName}의 {data.targetScore}점\n내 점수: {data.myScore}점 — 다시 도전!`
		end
		if rewardLbl then
			rewardLbl.Text = ""
		end
	end

	-- 등장 애니메이션
	local resultFrame2 = resultGui:FindFirstChild("ResultFrame") :: Frame?
	if resultFrame2 then
		resultFrame2.Size = UDim2.new(0, 350, 0, 0)
		resultGui.Enabled = true
		TweenService:Create(
			resultFrame2,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, 350, 0, 210) }
		):Play()
	else
		resultGui.Enabled = true
	end

	-- 자동 닫기 (8초)
	task.delay(8, function()
		if resultGui then
			resultGui.Enabled = false
		end
	end)
end

-- ==================== 공개 API ====================

-- 게임 시작 시 배틀 데이터 설정 (asyncBattle 있는 경우)
function AsyncBattleController:StartBattle(battleData: { targetName: string, targetScore: number })
	self._currentBattle = battleData
	if self._targetScoreLabel then
		self._targetScoreLabel.Text = `목표: {battleData.targetName} ({battleData.targetScore}점)`
	end
	if self._hudGui then
		self._hudGui.Enabled = true
	end
end

-- 게임 종료 시 HUD 숨기기
function AsyncBattleController:EndBattle()
	self._currentBattle = nil
	if self._hudGui then
		self._hudGui.Enabled = false
	end
end

function AsyncBattleController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	if self._hudGui then
		self._hudGui:Destroy()
		self._hudGui = nil
	end
	if self._resultGui then
		self._resultGui:Destroy()
		self._resultGui = nil
	end
end

return AsyncBattleController

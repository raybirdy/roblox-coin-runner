--!strict
-- Progression Controller
-- 진행도 UI 관리 (레벨/XP, 일일 미션, 업적)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local ProgressionController = {}
ProgressionController.__index = ProgressionController

export type ProgressionController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_connections: { RBXScriptConnection },
		_screenGui: ScreenGui?,
		_levelLabel: TextLabel?,
		_xpBar: Frame?,
		_xpFill: Frame?,
		_xpText: TextLabel?,
		_missionGui: ScreenGui?,
		_missionFrame: Frame?,
		_missionSlots: { Frame },
		_achievementSlots: { Frame },
		_achievementContainer: ScrollingFrame?,
		_missionContainer: Frame?,
		_currentTab: string,
		_tabMissions: TextButton?,
		_tabAchievements: TextButton?,
		_titleLabel: TextLabel?,
		_frameStroke: UIStroke?,
		_isMissionOpen: boolean,
		_notificationQueue: { any },
		_isShowingNotification: boolean,
	},
	ProgressionController
))

function ProgressionController.new(player: Player): ProgressionController
	local self = setmetatable({
		_player = player,
		_connections = {},
		_screenGui = nil,
		_levelLabel = nil,
		_xpBar = nil,
		_xpFill = nil,
		_xpText = nil,
		_missionGui = nil,
		_missionFrame = nil,
		_missionSlots = {},
		_achievementSlots = {},
		_achievementContainer = nil,
		_missionContainer = nil,
		_currentTab = "missions",
		_tabMissions = nil,
		_tabAchievements = nil,
		_titleLabel = nil,
		_frameStroke = nil,
		_isMissionOpen = false,
		_notificationQueue = {},
		_isShowingNotification = false,
	}, ProgressionController)

	self:_createLevelDisplay()
	self:_createMissionPopup()
	self:_setupEventHandlers()

	-- 초기 데이터 요청
	task.delay(2, function()
		RemoteEvents.ProgressionDataRequest:FireServer()
	end)

	return self
end

-- ==================== 레벨/XP 디스플레이 (항상 표시) ====================

function ProgressionController:_createLevelDisplay()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ProgressionGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 5
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	-- 레벨 컨테이너 (좌상단, safe area padding 적용)
	local container = Instance.new("Frame")
	container.Name = "LevelContainer"
	container.Size = UDim2.new(0, 160, 0, 40)
	container.Position = UDim2.new(0, 10, 0, 16)
	container.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	container.BackgroundTransparency = 0.3
	container.Parent = screenGui

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 8)
	containerCorner.Parent = container

	-- 레벨 라벨
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0, 50, 0, 20)
	levelLabel.Position = UDim2.new(0, 8, 0, 2)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	levelLabel.TextSize = ResponsiveUtil.scaledTextSize(14, 11)
	levelLabel.Font = Enum.Font.GothamBlack
	levelLabel.Text = "Lv.1"
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.Parent = container
	self._levelLabel = levelLabel

	-- XP 바 배경
	local xpBar = Instance.new("Frame")
	xpBar.Name = "XPBar"
	xpBar.Size = UDim2.new(0, 135, 0, 10)
	xpBar.Position = UDim2.new(0, 12, 0, 25)
	xpBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	xpBar.Parent = container
	self._xpBar = xpBar

	local xpBarCorner = Instance.new("UICorner")
	xpBarCorner.CornerRadius = UDim.new(0, 5)
	xpBarCorner.Parent = xpBar

	-- XP 바 채움
	local xpFill = Instance.new("Frame")
	xpFill.Name = "XPFill"
	xpFill.Size = UDim2.new(0, 0, 1, 0)
	xpFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	xpFill.Parent = xpBar
	self._xpFill = xpFill

	local xpFillCorner = Instance.new("UICorner")
	xpFillCorner.CornerRadius = UDim.new(0, 5)
	xpFillCorner.Parent = xpFill

	-- XP 텍스트 (바 위에)
	local xpText = Instance.new("TextLabel")
	xpText.Name = "XPText"
	xpText.Size = UDim2.new(0, 100, 0, 20)
	xpText.Position = UDim2.new(0, 60, 0, 2)
	xpText.BackgroundTransparency = 1
	xpText.TextColor3 = Color3.fromRGB(180, 180, 200)
	xpText.TextSize = ResponsiveUtil.scaledTextSize(14, 12)
	xpText.Font = Enum.Font.Gotham
	xpText.Text = ""
	xpText.TextXAlignment = Enum.TextXAlignment.Right
	xpText.Parent = container
	self._xpText = xpText

	-- 미션 버튼 (레벨 바 옆)
	local missionBtn = Instance.new("TextButton")
	missionBtn.Name = "MissionButton"
	missionBtn.Size = UDim2.new(0, 48, 0, 48)
	missionBtn.Position = UDim2.new(0, 175, 0, 16)
	missionBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
	missionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	missionBtn.TextSize = ResponsiveUtil.scaledTextSize(20, 14)
	missionBtn.Font = Enum.Font.GothamBold
	missionBtn.Text = "!"
	missionBtn.Parent = screenGui

	local missionBtnCorner = Instance.new("UICorner")
	missionBtnCorner.CornerRadius = UDim.new(0, 8)
	missionBtnCorner.Parent = missionBtn

	missionBtn.MouseButton1Click:Connect(function()
		if self._isMissionOpen then
			self:CloseMissions()
		else
			self:OpenMissions()
		end
	end)
end

-- ==================== 미션 팝업 ====================

function ProgressionController:_createMissionPopup()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local missionGui = Instance.new("ScreenGui")
	missionGui.Name = "MissionPopupGui"
	missionGui.ResetOnSpawn = false
	missionGui.DisplayOrder = 16
	missionGui.Enabled = false
	missionGui.Parent = playerGui
	self._missionGui = missionGui

	-- 딤 배경
	local dimBg = Instance.new("TextButton")
	dimBg.Name = "DimBackground"
	dimBg.Size = UDim2.new(1, 0, 1, 0)
	dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimBg.BackgroundTransparency = 0.5
	dimBg.Text = ""
	dimBg.AutoButtonColor = false
	dimBg.Parent = missionGui

	dimBg.MouseButton1Click:Connect(function()
		self:CloseMissions()
	end)

	-- 팝업 프레임 (높이 360으로 확대: 탭 바 + 콘텐츠)
	local missionFrame = Instance.new("Frame")
	missionFrame.Name = "MissionFrame"
	missionFrame.Size = ResponsiveUtil.clampedSize(360, 360, 0.90, 0.85)
	missionFrame.Position = ResponsiveUtil.clampedPosition(360, 360, 0.90, 0.85)
	missionFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	missionFrame.BorderSizePixel = 0
	missionFrame.Parent = missionGui
	self._missionFrame = missionFrame

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = missionFrame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(100, 200, 100)
	frameStroke.Thickness = 2
	frameStroke.Parent = missionFrame
	self._frameStroke = frameStroke

	-- 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -60, 0, 35)
	titleLabel.Position = UDim2.new(0, 15, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	titleLabel.TextSize = ResponsiveUtil.scaledTextSize(20, 14)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "DAILY MISSIONS"
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = missionFrame
	self._titleLabel = titleLabel

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 44, 0, 44)
	closeBtn.Position = UDim2.new(1, -52, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = ResponsiveUtil.scaledTextSize(16, 12)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "X"
	closeBtn.Parent = missionFrame

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 6)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:CloseMissions()
	end)

	-- 탭 바 (Y=50, 높이=34)
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -20, 0, 32)
	tabBar.Position = UDim2.new(0, 10, 0, 50)
	tabBar.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	tabBar.BorderSizePixel = 0
	tabBar.Parent = missionFrame

	local tabBarCorner = Instance.new("UICorner")
	tabBarCorner.CornerRadius = UDim.new(0, 6)
	tabBarCorner.Parent = tabBar

	-- 미션 탭 버튼
	local tabMissions = Instance.new("TextButton")
	tabMissions.Name = "TabMissions"
	tabMissions.Size = UDim2.new(0.5, 0, 1, 0)
	tabMissions.Position = UDim2.new(0, 0, 0, 0)
	tabMissions.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
	tabMissions.TextColor3 = Color3.fromRGB(255, 255, 255)
	tabMissions.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
	tabMissions.Font = Enum.Font.GothamBold
	tabMissions.Text = "MISSIONS"
	tabMissions.AutoButtonColor = false
	tabMissions.Parent = tabBar

	local tabMissionsCorner = Instance.new("UICorner")
	tabMissionsCorner.CornerRadius = UDim.new(0, 6)
	tabMissionsCorner.Parent = tabMissions

	self._tabMissions = tabMissions

	-- 업적 탭 버튼
	local tabAchievements = Instance.new("TextButton")
	tabAchievements.Name = "TabAchievements"
	tabAchievements.Size = UDim2.new(0.5, 0, 1, 0)
	tabAchievements.Position = UDim2.new(0.5, 0, 0, 0)
	tabAchievements.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
	tabAchievements.TextColor3 = Color3.fromRGB(180, 180, 200)
	tabAchievements.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
	tabAchievements.Font = Enum.Font.GothamBold
	tabAchievements.Text = "ACHIEVEMENTS"
	tabAchievements.AutoButtonColor = false
	tabAchievements.Parent = tabBar

	local tabAchievementsCorner = Instance.new("UICorner")
	tabAchievementsCorner.CornerRadius = UDim.new(0, 6)
	tabAchievementsCorner.Parent = tabAchievements

	self._tabAchievements = tabAchievements

	-- 탭 클릭 핸들러
	tabMissions.MouseButton1Click:Connect(function()
		self:_switchTab("missions")
	end)
	tabAchievements.MouseButton1Click:Connect(function()
		self:_switchTab("achievements")
	end)

	-- 미션 컨테이너 (탭 아래)
	local missionContainer = Instance.new("Frame")
	missionContainer.Name = "MissionContainer"
	missionContainer.Size = UDim2.new(1, 0, 1, -90)
	missionContainer.Position = UDim2.new(0, 0, 0, 90)
	missionContainer.BackgroundTransparency = 1
	missionContainer.Visible = true
	missionContainer.Parent = missionFrame
	self._missionContainer = missionContainer

	-- 미션 슬롯 3개
	for i = 1, 3 do
		local slot = Instance.new("Frame")
		slot.Name = `Mission{i}`
		slot.Size = UDim2.new(1, -30, 0, 70)
		slot.Position = UDim2.new(0, 15, 0, (i - 1) * 78)
		slot.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
		slot.BorderSizePixel = 0
		slot.Parent = missionContainer

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 8)
		slotCorner.Parent = slot

		-- 미션 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "MissionName"
		nameLabel.Size = UDim2.new(0.7, 0, 0, 22)
		nameLabel.Position = UDim2.new(0, 10, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = ResponsiveUtil.scaledTextSize(16, 14)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = "---"
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot

		-- 보상
		local rewardLabel = Instance.new("TextLabel")
		rewardLabel.Name = "RewardLabel"
		rewardLabel.Size = UDim2.new(0.3, -10, 0, 22)
		rewardLabel.Position = UDim2.new(0.7, 0, 0, 5)
		rewardLabel.BackgroundTransparency = 1
		rewardLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		rewardLabel.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
		rewardLabel.Font = Enum.Font.GothamBold
		rewardLabel.Text = ""
		rewardLabel.TextXAlignment = Enum.TextXAlignment.Right
		rewardLabel.Parent = slot

		-- 설명
		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "MissionDesc"
		descLabel.Size = UDim2.new(1, -20, 0, 18)
		descLabel.Position = UDim2.new(0, 10, 0, 25)
		descLabel.BackgroundTransparency = 1
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
		descLabel.TextSize = ResponsiveUtil.scaledTextSize(14, 13)
		descLabel.Font = Enum.Font.Gotham
		descLabel.Text = ""
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = slot

		-- 진행도 바
		local progressBg = Instance.new("Frame")
		progressBg.Name = "ProgressBg"
		progressBg.Size = UDim2.new(1, -20, 0, 10)
		progressBg.Position = UDim2.new(0, 10, 0, 48)
		progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
		progressBg.Parent = slot

		local progressBgCorner = Instance.new("UICorner")
		progressBgCorner.CornerRadius = UDim.new(0, 5)
		progressBgCorner.Parent = progressBg

		local progressFill = Instance.new("Frame")
		progressFill.Name = "ProgressFill"
		progressFill.Size = UDim2.new(0, 0, 1, 0)
		progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
		progressFill.Parent = progressBg

		local progressFillCorner = Instance.new("UICorner")
		progressFillCorner.CornerRadius = UDim.new(0, 5)
		progressFillCorner.Parent = progressFill

		-- 진행도 텍스트
		local progressText = Instance.new("TextLabel")
		progressText.Name = "ProgressText"
		progressText.Size = UDim2.new(1, 0, 1, 0)
		progressText.BackgroundTransparency = 1
		progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
		progressText.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
		progressText.Font = Enum.Font.GothamBold
		progressText.Text = "0/0"
		progressText.Parent = progressBg

		self._missionSlots[i] = slot
	end

	-- 업적 ScrollingFrame (탭 아래, 기본 숨김)
	local achievementContainer = Instance.new("ScrollingFrame")
	achievementContainer.Name = "AchievementContainer"
	achievementContainer.Size = UDim2.new(1, 0, 1, -90)
	achievementContainer.Position = UDim2.new(0, 0, 0, 90)
	achievementContainer.BackgroundTransparency = 1
	achievementContainer.ScrollBarThickness = 4
	achievementContainer.ScrollBarImageColor3 = Color3.fromRGB(100, 200, 100)
	achievementContainer.CanvasSize = UDim2.new(0, 0, 0, 0) -- 동적으로 설정
	achievementContainer.Visible = false
	achievementContainer.Parent = missionFrame
	self._achievementContainer = achievementContainer

	-- 업적 슬롯 생성 (GameConstants 기반)
	local achievements = GameConstants.ACHIEVEMENTS.LIST
	local slotHeight = 62
	local slotGap = 6
	local totalH = #achievements * (slotHeight + slotGap)
	achievementContainer.CanvasSize = UDim2.new(0, 0, 0, totalH + 10)

	for i, ach in achievements do
		local slot = Instance.new("Frame")
		slot.Name = `Achievement_{ach.id}`
		slot.Size = UDim2.new(1, -20, 0, slotHeight)
		slot.Position = UDim2.new(0, 10, 0, (i - 1) * (slotHeight + slotGap))
		slot.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
		slot.BorderSizePixel = 0
		slot.Parent = achievementContainer

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 8)
		slotCorner.Parent = slot

		-- 업적 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "AchName"
		nameLabel.Size = UDim2.new(0.72, 0, 0, 20)
		nameLabel.Position = UDim2.new(0, 10, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = ResponsiveUtil.scaledTextSize(14, 12)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = ach.name
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = slot

		-- 젬 보상
		local rewardLabel = Instance.new("TextLabel")
		rewardLabel.Name = "RewardLabel"
		rewardLabel.Size = UDim2.new(0.28, -10, 0, 20)
		rewardLabel.Position = UDim2.new(0.72, 0, 0, 5)
		rewardLabel.BackgroundTransparency = 1
		rewardLabel.TextColor3 = Color3.fromRGB(180, 230, 255)
		rewardLabel.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
		rewardLabel.Font = Enum.Font.GothamBold
		rewardLabel.Text = `+{ach.rewardGems} 💎`
		rewardLabel.TextXAlignment = Enum.TextXAlignment.Right
		rewardLabel.Parent = slot

		-- 설명
		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "AchDesc"
		descLabel.Size = UDim2.new(1, -20, 0, 16)
		descLabel.Position = UDim2.new(0, 10, 0, 24)
		descLabel.BackgroundTransparency = 1
		descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
		descLabel.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
		descLabel.Font = Enum.Font.Gotham
		descLabel.Text = ach.desc
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = slot

		-- 진행도 바
		local progressBg = Instance.new("Frame")
		progressBg.Name = "ProgressBg"
		progressBg.Size = UDim2.new(1, -20, 0, 8)
		progressBg.Position = UDim2.new(0, 10, 0, 44)
		progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
		progressBg.Parent = slot

		local progressBgCorner = Instance.new("UICorner")
		progressBgCorner.CornerRadius = UDim.new(0, 4)
		progressBgCorner.Parent = progressBg

		local progressFill = Instance.new("Frame")
		progressFill.Name = "ProgressFill"
		progressFill.Size = UDim2.new(0, 0, 1, 0)
		progressFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
		progressFill.Parent = progressBg

		local progressFillCorner = Instance.new("UICorner")
		progressFillCorner.CornerRadius = UDim.new(0, 4)
		progressFillCorner.Parent = progressFill

		-- 진행도 텍스트
		local progressText = Instance.new("TextLabel")
		progressText.Name = "ProgressText"
		progressText.Size = UDim2.new(1, 0, 1, 0)
		progressText.BackgroundTransparency = 1
		progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
		progressText.TextSize = ResponsiveUtil.scaledTextSize(10, 9)
		progressText.Font = Enum.Font.GothamBold
		progressText.Text = `0/{ach.target}`
		progressText.Parent = progressBg

		self._achievementSlots[i] = slot
	end
end

-- ==================== 탭 전환 ====================

function ProgressionController:_switchTab(tabName: string)
	self._currentTab = tabName

	local isMissions = tabName == "missions"

	-- 컨테이너 가시성 전환
	if self._missionContainer then
		self._missionContainer.Visible = isMissions
	end
	if self._achievementContainer then
		self._achievementContainer.Visible = not isMissions
	end

	-- 탭 버튼 색상 업데이트
	if self._tabMissions then
		self._tabMissions.BackgroundColor3 = if isMissions
			then Color3.fromRGB(50, 120, 50)
			else Color3.fromRGB(35, 35, 55)
		self._tabMissions.TextColor3 = if isMissions
			then Color3.fromRGB(255, 255, 255)
			else Color3.fromRGB(180, 180, 200)
	end
	if self._tabAchievements then
		self._tabAchievements.BackgroundColor3 = if not isMissions
			then Color3.fromRGB(60, 80, 180)
			else Color3.fromRGB(35, 35, 55)
		self._tabAchievements.TextColor3 = if not isMissions
			then Color3.fromRGB(255, 255, 255)
			else Color3.fromRGB(180, 180, 200)
	end

	-- 타이틀 및 테두리 색 업데이트
	if self._titleLabel then
		self._titleLabel.Text = if isMissions then "DAILY MISSIONS" else "ACHIEVEMENTS"
		self._titleLabel.TextColor3 = if isMissions
			then Color3.fromRGB(100, 255, 100)
			else Color3.fromRGB(100, 180, 255)
	end
	if self._frameStroke then
		self._frameStroke.Color = if isMissions
			then Color3.fromRGB(100, 200, 100)
			else Color3.fromRGB(100, 150, 255)
	end
end

-- ==================== 이벤트 핸들러 ====================

function ProgressionController:_setupEventHandlers()
	-- XP 획득
	local xpConn = RemoteEvents.XPGained.OnClientEvent:Connect(function(data)
		self:_updateLevelDisplay(data.level, data.totalXP, data.xpToNext)
	end)
	table.insert(self._connections, xpConn)

	-- 레벨업
	local lvlConn = RemoteEvents.LevelUp.OnClientEvent:Connect(function(data)
		self:_showLevelUpNotification(data.newLevel, data.rewards)
	end)
	table.insert(self._connections, lvlConn)

	-- 미션 업데이트
	local missionConn = RemoteEvents.MissionUpdate.OnClientEvent:Connect(function(data)
		self:_updateMissionSlots(data.missions)
	end)
	table.insert(self._connections, missionConn)

	-- 업적 달성
	local achConn = RemoteEvents.AchievementUnlocked.OnClientEvent:Connect(function(data)
		self:_showAchievementNotification(data)
	end)
	table.insert(self._connections, achConn)

	-- 전체 진행도 데이터 (미션 + 업적 동시 업데이트)
	local progConn = RemoteEvents.ProgressionDataResponse.OnClientEvent:Connect(function(data)
		self:_updateLevelDisplay(data.level, data.xp, data.xpToNext)
		self:_updateMissionSlots(data.missions)
		if data.achievements then
			self:_updateAchievementSlots(data.achievements)
		end
	end)
	table.insert(self._connections, progConn)

	print("[ProgressionController] Event handlers set up")
end

-- ==================== UI 업데이트 ====================

function ProgressionController:_updateLevelDisplay(level: number, xp: number, xpToNext: number)
	if self._levelLabel then
		self._levelLabel.Text = `Lv.{level}`
	end

	if self._xpFill and self._xpBar then
		local ratio = if xpToNext > 0 then math.clamp(xp / xpToNext, 0, 1) else 1
		local targetWidth = self._xpBar.AbsoluteSize.X * ratio

		TweenService:Create(self._xpFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Size = UDim2.new(0, targetWidth, 1, 0),
		}):Play()
	end

	if self._xpText then
		if xpToNext > 0 then
			self._xpText.Text = `{xp}/{xpToNext} XP`
		else
			self._xpText.Text = "MAX"
		end
	end
end

function ProgressionController:_updateMissionSlots(missions: { any })
	for i = 1, 3 do
		local slot = self._missionSlots[i]
		if not slot then
			continue
		end

		local nameLabel = slot:FindFirstChild("MissionName") :: TextLabel?
		local descLabel = slot:FindFirstChild("MissionDesc") :: TextLabel?
		local rewardLabel = slot:FindFirstChild("RewardLabel") :: TextLabel?
		local progressBg = slot:FindFirstChild("ProgressBg") :: Frame?

		if missions[i] then
			local mission = missions[i]
			if nameLabel then
				nameLabel.Text = mission.name or "---"
			end
			if descLabel then
				descLabel.Text = mission.desc or ""
			end
			if rewardLabel then
				rewardLabel.Text = `+{mission.reward or 0}`
			end

			-- 진행도 바
			if progressBg then
				local progressFill = progressBg:FindFirstChild("ProgressFill") :: Frame?
				local progressText = progressBg:FindFirstChild("ProgressText") :: TextLabel?

				local progress = mission.progress or 0
				local target = mission.target or 1
				local ratio = math.clamp(progress / target, 0, 1)

				if progressFill then
					TweenService:Create(progressFill, TweenInfo.new(0.3), {
						Size = UDim2.new(ratio, 0, 1, 0),
					}):Play()

					if mission.completed then
						progressFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
					else
						progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
					end
				end

				if progressText then
					if mission.completed then
						progressText.Text = "CLEAR!"
					else
						progressText.Text = `{progress}/{target}`
					end
				end
			end

			-- 완료된 미션 슬롯 배경 변경
			if mission.completed then
				slot.BackgroundColor3 = Color3.fromRGB(30, 28, 10)
			else
				slot.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
			end
		else
			if nameLabel then
				nameLabel.Text = "---"
			end
			if descLabel then
				descLabel.Text = ""
			end
			if rewardLabel then
				rewardLabel.Text = ""
			end
		end
	end
end

function ProgressionController:_updateAchievementSlots(achievements: { any })
	-- Build lookup table by achievement id for O(1) access
	local achMap: { [string]: any } = {}
	for _, ach in achievements do
		achMap[ach.id] = ach
	end

	for i, slot in self._achievementSlots do
		local achDef = GameConstants.ACHIEVEMENTS.LIST[i]
		if not achDef then
			continue
		end

		local serverData = achMap[achDef.id]
		local current = if serverData then serverData.current or 0 else 0
		local completed = if serverData then serverData.completed == true else false

		local progressBg = slot:FindFirstChild("ProgressBg") :: Frame?
		if progressBg then
			local progressFill = progressBg:FindFirstChild("ProgressFill") :: Frame?
			local progressText = progressBg:FindFirstChild("ProgressText") :: TextLabel?

			local ratio = math.clamp(current / achDef.target, 0, 1)

			if progressFill then
				TweenService:Create(progressFill, TweenInfo.new(0.4), {
					Size = UDim2.new(ratio, 0, 1, 0),
				}):Play()

				progressFill.BackgroundColor3 = if completed
					then Color3.fromRGB(255, 200, 50)
					else Color3.fromRGB(80, 160, 255)
			end

			if progressText then
				if completed then
					progressText.Text = "CLEAR!"
				else
					progressText.Text = `{current}/{achDef.target}`
				end
			end
		end

		-- 완료된 업적: 배경 골드 처리
		if completed then
			TweenService:Create(slot, TweenInfo.new(0.3), {
				BackgroundColor3 = Color3.fromRGB(35, 28, 5),
			}):Play()

			local nameLabel = slot:FindFirstChild("AchName") :: TextLabel?
			if nameLabel then
				nameLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			end
		else
			slot.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
		end
	end
end

-- ==================== 알림 ====================

function ProgressionController:_showLevelUpNotification(level: number, rewards: { coins: number, gems: number? })
	self:_queueNotification({
		title = `LEVEL UP! Lv.{level}`,
		desc = if rewards.gems then `+{rewards.coins} coins, +{rewards.gems} gems!` else `+{rewards.coins} coins!`,
		color = Color3.fromRGB(100, 200, 255),
	})
end

function ProgressionController:_showAchievementNotification(data: { name: string, desc: string, rewardGems: number })
	self:_queueNotification({
		title = `ACHIEVEMENT: {data.name}`,
		desc = `{data.desc} (+{data.rewardGems} gems)`,
		color = Color3.fromRGB(255, 200, 50),
	})
end

function ProgressionController:_queueNotification(notification: any)
	table.insert(self._notificationQueue, notification)
	if not self._isShowingNotification then
		self:_showNextNotification()
	end
end

function ProgressionController:_showNextNotification()
	if #self._notificationQueue == 0 then
		self._isShowingNotification = false
		return
	end

	self._isShowingNotification = true
	local notification = table.remove(self._notificationQueue, 1)

	if not self._screenGui then
		self._isShowingNotification = false
		return
	end

	-- 알림 배너
	local banner = Instance.new("Frame")
	banner.Name = "NotificationBanner"
	banner.Size = UDim2.new(0, 300, 0, 60)
	banner.Position = UDim2.new(0.5, -150, 0, -70)
	banner.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	banner.BorderSizePixel = 0
	banner.Parent = self._screenGui

	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 10)
	bannerCorner.Parent = banner

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = notification.color
	bannerStroke.Thickness = 2
	bannerStroke.Parent = banner

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 28)
	titleLabel.Position = UDim2.new(0, 10, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = notification.color
	titleLabel.TextSize = ResponsiveUtil.scaledTextSize(16, 12)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = notification.title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = banner

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -20, 0, 20)
	descLabel.Position = UDim2.new(0, 10, 0, 32)
	descLabel.BackgroundTransparency = 1
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	descLabel.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
	descLabel.Font = Enum.Font.Gotham
	descLabel.Text = notification.desc
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = banner

	-- 슬라이드 인
	TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -150, 0, 10),
	}):Play()

	-- 3초 후 슬라이드 아웃
	task.delay(3, function()
		if banner and banner.Parent then
			local tweenOut =
				TweenService:Create(banner, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, -150, 0, -70),
				})
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				if banner and banner.Parent then
					banner:Destroy()
				end
				self:_showNextNotification()
			end)
		else
			self:_showNextNotification()
		end
	end)
end

-- ==================== 미션 팝업 열기/닫기 ====================

function ProgressionController:OpenMissions()
	if self._isMissionOpen then
		return
	end
	self._isMissionOpen = true

	if self._missionGui then
		self._missionGui.Enabled = true
	end

	-- 현재 탭 상태 적용
	self:_switchTab(self._currentTab)

	-- 팝업 애니메이션
	if self._missionFrame then
		local targetSize = ResponsiveUtil.clampedSize(360, 360, 0.90, 0.85)
		local targetW = targetSize.X.Offset
		self._missionFrame.Size = UDim2.new(0, targetW, 0, 0)
		self._missionFrame.Position = UDim2.new(0.5, -targetW / 2, 0.5, 0)

		TweenService:Create(self._missionFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = targetSize,
			Position = ResponsiveUtil.clampedPosition(360, 360, 0.90, 0.85),
		}):Play()
	end

	-- 최신 데이터 요청
	RemoteEvents.ProgressionDataRequest:FireServer()
end

function ProgressionController:CloseMissions()
	if not self._isMissionOpen then
		return
	end
	self._isMissionOpen = false

	if self._missionFrame then
		local currentW = self._missionFrame.Size.X.Offset
		local tween = TweenService:Create(
			self._missionFrame,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Size = UDim2.new(0, currentW, 0, 0),
				Position = UDim2.new(0.5, -currentW / 2, 0.5, 0),
			}
		)
		tween:Play()
		tween.Completed:Connect(function()
			if self._missionGui then
				self._missionGui.Enabled = false
			end
		end)
	else
		if self._missionGui then
			self._missionGui.Enabled = false
		end
	end
end

-- 게임 시작 시 레벨 디스플레이 숨기기
function ProgressionController:HideForGame()
	if self._screenGui then
		self._screenGui.Enabled = false
	end
	if self._isMissionOpen then
		self:CloseMissions()
	end
end

-- 로비 복귀 시 레벨 디스플레이 표시
function ProgressionController:ShowInLobby()
	if self._screenGui then
		self._screenGui.Enabled = true
	end
	-- 데이터 새로고침
	RemoteEvents.ProgressionDataRequest:FireServer()
end

-- 정리
function ProgressionController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	if self._screenGui then
		self._screenGui:Destroy()
	end
	if self._missionGui then
		self._missionGui:Destroy()
	end
end

return ProgressionController

--!strict
-- ScenarioController
-- 시나리오 UI: 챕터 목록, 퀘스트 진행바, 스킬 탭, 로비 버튼

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ScenarioConstants = require(ReplicatedStorage.Shared.Constants.ScenarioConstants)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local ScenarioController = {}
ScenarioController.__index = ScenarioController

export type ScenarioController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_connections: { RBXScriptConnection },
		-- 루트 GUI
		_gui: ScreenGui?,
		_lobbyButton: TextButton?,
		-- 메인 팝업
		_panelFrame: Frame?,
		_isOpen: boolean,
		-- 탭
		_currentTab: string,
		_tabChapters: TextButton?,
		_tabSkills: TextButton?,
		_chapterScrollFrame: ScrollingFrame?,
		_skillFrame: Frame?,
		-- 챕터 상세 오버레이
		_detailFrame: Frame?,
		_detailTitleLabel: TextLabel?,
		_detailScrollFrame: ScrollingFrame?,
		_currentDetailChapterId: string?,
		-- 퀘스트 진행도 바 캐시 (questId → fill Frame)
		_questFillBars: { [string]: Frame },
		_questProgressTexts: { [string]: TextLabel },
		-- 챕터 카드 캐시 (chapterId → card Frame)
		_chapterCards: { [string]: Frame },
		-- 최신 서버 데이터
		_scenarioData: any?,
		-- 게임 중 퀘스트 힌트 HUD
		_questHudGui: ScreenGui?,
		_questHudItems: { { nameLabel: TextLabel, progressFill: Frame, progressText: TextLabel, frame: Frame } },
		_isGameActive: boolean,
		-- 잠금 챕터 점수 시각화용 캐시
		_playerHighScore: number,
	},
	ScenarioController
))

function ScenarioController.new(player: Player): ScenarioController
	local self = setmetatable({
		_player = player,
		_connections = {},
		_gui = nil,
		_lobbyButton = nil,
		_panelFrame = nil,
		_isOpen = false,
		_currentTab = "chapters",
		_tabChapters = nil,
		_tabSkills = nil,
		_chapterScrollFrame = nil,
		_skillFrame = nil,
		_detailFrame = nil,
		_detailTitleLabel = nil,
		_detailScrollFrame = nil,
		_currentDetailChapterId = nil,
		_questFillBars = {},
		_questProgressTexts = {},
		_chapterCards = {},
		_scenarioData = nil,
		_questHudGui = nil,
		_questHudItems = {},
		_isGameActive = false,
		_playerHighScore = 0,
	}, ScenarioController)

	self:_createGui()
	self:_setupEventHandlers()

	-- 2초 후 초기 데이터 요청
	task.delay(2.5, function()
		RemoteEvents.ScenarioDataRequest:FireServer()
	end)

	return self
end

-- ==================== GUI 생성 ====================

function ScenarioController:_createGui()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "ScenarioGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 17
	gui.Parent = playerGui
	self._gui = gui

	-- 로비 버튼 (ProgressionGui 미션 버튼 오른쪽)
	local lobbyBtn = Instance.new("TextButton")
	lobbyBtn.Name = "ScenarioButton"
	lobbyBtn.Size = UDim2.new(0, 48, 0, 48)
	lobbyBtn.Position = UDim2.new(0, 228, 0, 16)
	lobbyBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 180)
	lobbyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	lobbyBtn.TextSize = ResponsiveUtil.scaledTextSize(20, 14)
	lobbyBtn.Font = Enum.Font.GothamBold
	lobbyBtn.Text = "📖"
	lobbyBtn.Parent = gui
	self._lobbyButton = lobbyBtn

	local lobbyBtnCorner = Instance.new("UICorner")
	lobbyBtnCorner.CornerRadius = UDim.new(0, 8)
	lobbyBtnCorner.Parent = lobbyBtn

	local lobbyBtnStroke = Instance.new("UIStroke")
	lobbyBtnStroke.Color = Color3.fromRGB(100, 140, 255)
	lobbyBtnStroke.Thickness = 2
	lobbyBtnStroke.Parent = lobbyBtn

	lobbyBtn.MouseButton1Click:Connect(function()
		if self._isOpen then
			self:ClosePanel()
		else
			self:OpenPanel()
		end
	end)

	-- 메인 팝업 (딤 배경 포함)
	local popupGui = Instance.new("ScreenGui")
	popupGui.Name = "ScenarioPopupGui"
	popupGui.ResetOnSpawn = false
	popupGui.DisplayOrder = 18
	popupGui.Enabled = false
	popupGui.Parent = playerGui

	-- 딤 배경
	local dimBg = Instance.new("TextButton")
	dimBg.Name = "DimBg"
	dimBg.Size = UDim2.new(1, 0, 1, 0)
	dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimBg.BackgroundTransparency = 0.5
	dimBg.Text = ""
	dimBg.AutoButtonColor = false
	dimBg.Parent = popupGui

	dimBg.MouseButton1Click:Connect(function()
		self:ClosePanel()
	end)

	-- 팝업 프레임
	local frame = Instance.new("Frame")
	frame.Name = "ScenarioFrame"
	frame.Size = ResponsiveUtil.clampedSize(370, 440, 0.92, 0.88)
	frame.Position = ResponsiveUtil.clampedPosition(370, 440, 0.92, 0.88)
	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 38)
	frame.BorderSizePixel = 0
	frame.Parent = popupGui
	self._panelFrame = frame

	-- 프레임 저장 (popupGui는 별도 관리)
	gui:SetAttribute("PopupGuiName", "ScenarioPopupGui")

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = frame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(80, 120, 255)
	frameStroke.Thickness = 2
	frameStroke.Parent = frame

	-- 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -60, 0, 36)
	titleLabel.Position = UDim2.new(0, 16, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
	titleLabel.TextSize = ResponsiveUtil.scaledTextSize(18, 14)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "📖 SCENARIO"
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
	closeBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "✕"
	closeBtn.Parent = frame

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:ClosePanel()
	end)

	-- 탭 바
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -20, 0, 32)
	tabBar.Position = UDim2.new(0, 10, 0, 50)
	tabBar.BackgroundColor3 = Color3.fromRGB(12, 14, 25)
	tabBar.BorderSizePixel = 0
	tabBar.Parent = frame

	local tabBarCorner = Instance.new("UICorner")
	tabBarCorner.CornerRadius = UDim.new(0, 8)
	tabBarCorner.Parent = tabBar

	local tabChapters = Instance.new("TextButton")
	tabChapters.Name = "TabChapters"
	tabChapters.Size = UDim2.new(0.5, 0, 1, 0)
	tabChapters.Position = UDim2.new(0, 0, 0, 0)
	tabChapters.BackgroundColor3 = Color3.fromRGB(60, 80, 180)
	tabChapters.TextColor3 = Color3.fromRGB(255, 255, 255)
	tabChapters.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
	tabChapters.Font = Enum.Font.GothamBold
	tabChapters.Text = "챕터"
	tabChapters.Parent = tabBar
	self._tabChapters = tabChapters

	local tabChaptersCorner = Instance.new("UICorner")
	tabChaptersCorner.CornerRadius = UDim.new(0, 8)
	tabChaptersCorner.Parent = tabChapters

	local tabSkills = Instance.new("TextButton")
	tabSkills.Name = "TabSkills"
	tabSkills.Size = UDim2.new(0.5, 0, 1, 0)
	tabSkills.Position = UDim2.new(0.5, 0, 0, 0)
	tabSkills.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
	tabSkills.TextColor3 = Color3.fromRGB(180, 180, 200)
	tabSkills.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
	tabSkills.Font = Enum.Font.GothamBold
	tabSkills.Text = "스킬"
	tabSkills.Parent = tabBar
	self._tabSkills = tabSkills

	local tabSkillsCorner = Instance.new("UICorner")
	tabSkillsCorner.CornerRadius = UDim.new(0, 8)
	tabSkillsCorner.Parent = tabSkills

	tabChapters.MouseButton1Click:Connect(function()
		self:_switchTab("chapters")
	end)
	tabSkills.MouseButton1Click:Connect(function()
		self:_switchTab("skills")
	end)

	-- 챕터 스크롤 프레임
	local chapterScroll = Instance.new("ScrollingFrame")
	chapterScroll.Name = "ChapterScroll"
	chapterScroll.Size = UDim2.new(1, -10, 1, -92)
	chapterScroll.Position = UDim2.new(0, 5, 0, 88)
	chapterScroll.BackgroundTransparency = 1
	chapterScroll.ScrollBarThickness = 4
	chapterScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
	chapterScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	chapterScroll.Visible = true
	chapterScroll.Parent = frame
	self._chapterScrollFrame = chapterScroll

	-- 챕터 카드를 담을 UIListLayout
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = chapterScroll

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		chapterScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
	end)

	-- 챕터 카드 10개 미리 생성
	self:_buildChapterCards(chapterScroll)

	-- 스킬 프레임
	local skillFrame = Instance.new("Frame")
	skillFrame.Name = "SkillFrame"
	skillFrame.Size = UDim2.new(1, -10, 1, -92)
	skillFrame.Position = UDim2.new(0, 5, 0, 88)
	skillFrame.BackgroundTransparency = 1
	skillFrame.Visible = false
	skillFrame.Parent = frame
	self._skillFrame = skillFrame

	self:_buildSkillCards(skillFrame)

	-- 챕터 상세 오버레이 (챕터 카드 클릭 시)
	self:_buildDetailOverlay(frame)

	-- 게임 중 퀘스트 힌트 HUD
	self:_createQuestHud()
end

-- ==================== 게임 중 퀘스트 힌트 HUD ====================

function ScenarioController:_createQuestHud()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local hudGui = Instance.new("ScreenGui")
	hudGui.Name = "QuestHudGui"
	hudGui.ResetOnSpawn = false
	hudGui.DisplayOrder = 15
	hudGui.Enabled = false
	hudGui.Parent = playerGui
	self._questHudGui = hudGui

	local panel = Instance.new("Frame")
	panel.Name = "QuestHudPanel"
	panel.Size = UDim2.new(0, 205, 0, 88)
	panel.Position = UDim2.new(0, 8, 0, 160)
	panel.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	panel.Parent = hudGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(80, 120, 255)
	panelStroke.Thickness = 1
	panelStroke.Parent = panel

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 0, 18)
	titleLabel.Position = UDim2.new(0, 8, 0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(140, 170, 255)
	titleLabel.TextSize = 11
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "🎯 현재 퀘스트"
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = panel

	self._questHudItems = {}
	for i = 1, 2 do
		local itemFrame = Instance.new("Frame")
		itemFrame.Name = `QuestHudItem{i}`
		itemFrame.Size = UDim2.new(1, -12, 0, 28)
		itemFrame.Position = UDim2.new(0, 6, 0, 24 + (i - 1) * 31)
		itemFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 48)
		itemFrame.BackgroundTransparency = 0.2
		itemFrame.BorderSizePixel = 0
		itemFrame.Parent = panel

		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 6)
		itemCorner.Parent = itemFrame

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(1, -58, 0, 14)
		nameLabel.Position = UDim2.new(0, 6, 0, 2)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(210, 215, 235)
		nameLabel.TextSize = 10
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = ""
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = itemFrame

		local progressText = Instance.new("TextLabel")
		progressText.Name = "ProgressText"
		progressText.Size = UDim2.new(0, 52, 0, 14)
		progressText.Position = UDim2.new(1, -54, 0, 2)
		progressText.BackgroundTransparency = 1
		progressText.TextColor3 = Color3.fromRGB(160, 190, 255)
		progressText.TextSize = 10
		progressText.Font = Enum.Font.Gotham
		progressText.Text = ""
		progressText.TextXAlignment = Enum.TextXAlignment.Right
		progressText.Parent = itemFrame

		local progBg = Instance.new("Frame")
		progBg.Name = "ProgBg"
		progBg.Size = UDim2.new(1, -12, 0, 6)
		progBg.Position = UDim2.new(0, 6, 1, -8)
		progBg.BackgroundColor3 = Color3.fromRGB(30, 35, 60)
		progBg.Parent = itemFrame

		local progBgCorner = Instance.new("UICorner")
		progBgCorner.CornerRadius = UDim.new(0, 3)
		progBgCorner.Parent = progBg

		local progFill = Instance.new("Frame")
		progFill.Name = "ProgFill"
		progFill.Size = UDim2.new(0, 0, 1, 0)
		progFill.BackgroundColor3 = Color3.fromRGB(100, 160, 255)
		progFill.Parent = progBg

		local progFillCorner = Instance.new("UICorner")
		progFillCorner.CornerRadius = UDim.new(0, 3)
		progFillCorner.Parent = progFill

		table.insert(self._questHudItems, {
			frame = itemFrame,
			nameLabel = nameLabel,
			progressText = progressText,
			progressFill = progFill,
		})
	end
end

function ScenarioController:_updateQuestHud()
	local hudGui = self._questHudGui
	if not hudGui or not self._isGameActive or not self._scenarioData then
		if hudGui then
			hudGui.Enabled = false
		end
		return
	end

	-- 현재 진행 중인 챕터 찾기 (해금됨 + 미완료, 가장 낮은 챕터 번호)
	local activeChapter: any? = nil
	local activeChapterNum = math.huge
	local chapters = self._scenarioData.chapters :: { any }
	for _, ch in chapters do
		if ch.isUnlocked and not ch.isCompleted then
			local chDef = ScenarioConstants.CHAPTER_MAP[ch.id]
			local num = chDef and chDef.num or 99
			if num < activeChapterNum then
				activeChapterNum = num
				activeChapter = ch
			end
		end
	end

	if not activeChapter then
		hudGui.Enabled = false
		return
	end

	-- 미완료 퀘스트 중 진행도 높은 순으로 최대 2개 선택
	local inProgress: { { questData: any, progress: number, target: number } } = {}
	for _, q in activeChapter.quests do
		local questDef = ScenarioConstants.QUESTS[q.id]
		if questDef and not q.completed then
			table.insert(inProgress, {
				questData = questDef,
				progress = q.progress or 0,
				target = questDef.target,
			})
		end
	end

	table.sort(inProgress, function(a, b)
		return (a.progress / a.target) > (b.progress / b.target)
	end)

	hudGui.Enabled = #inProgress > 0
	for i, item in self._questHudItems do
		if inProgress[i] then
			local q = inProgress[i]
			item.frame.Visible = true
			item.nameLabel.Text = q.questData.name
			item.progressText.Text = `{q.progress}/{q.target}`
			local ratio = math.clamp(q.progress / q.target, 0, 1)
			TweenService:Create(item.progressFill, TweenInfo.new(0.4), {
				Size = UDim2.new(ratio, 0, 1, 0),
			}):Play()
		else
			item.frame.Visible = false
		end
	end
end

-- ==================== 챕터 카드 빌드 ====================

function ScenarioController:_buildChapterCards(parent: ScrollingFrame)
	for i, chapter in ScenarioConstants.CHAPTERS do
		local card = Instance.new("Frame")
		card.Name = `Chapter_{chapter.id}`
		card.Size = UDim2.new(1, -8, 0, 68)
		card.BackgroundColor3 = Color3.fromRGB(25, 30, 50)
		card.BorderSizePixel = 0
		card.LayoutOrder = i
		card.Parent = parent
		self._chapterCards[chapter.id] = card

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = Color3.fromRGB(50, 60, 100)
		cardStroke.Thickness = 1
		cardStroke.Parent = card

		-- 테마 이모지 + 번호
		local themeLabel = Instance.new("TextLabel")
		themeLabel.Name = "ThemeLabel"
		themeLabel.Size = UDim2.new(0, 44, 0, 44)
		themeLabel.Position = UDim2.new(0, 8, 0, 12)
		themeLabel.BackgroundColor3 = Color3.fromRGB(35, 40, 65)
		themeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		themeLabel.TextSize = 22
		themeLabel.Font = Enum.Font.GothamBold
		themeLabel.Text = chapter.theme
		themeLabel.Parent = card

		local themeCorner = Instance.new("UICorner")
		themeCorner.CornerRadius = UDim.new(0, 8)
		themeCorner.Parent = themeLabel

		-- 챕터 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(1, -130, 0, 22)
		nameLabel.Position = UDim2.new(0, 60, 0, 10)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
		nameLabel.TextSize = ResponsiveUtil.scaledTextSize(14, 12)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = `CH{chapter.num} {chapter.name}`
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		-- 상태 라벨 (잠김/진행중/완료)
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "StatusLabel"
		statusLabel.Size = UDim2.new(0, 60, 0, 20)
		statusLabel.Position = UDim2.new(1, -68, 0, 10)
		statusLabel.BackgroundTransparency = 1
		statusLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
		statusLabel.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.Text = "🔒"
		statusLabel.TextXAlignment = Enum.TextXAlignment.Right
		statusLabel.Parent = card

		-- 퀘스트 진행 바 배경
		local progressBg = Instance.new("Frame")
		progressBg.Name = "ProgressBg"
		progressBg.Size = UDim2.new(1, -68, 0, 8)
		progressBg.Position = UDim2.new(0, 60, 0, 38)
		progressBg.BackgroundColor3 = Color3.fromRGB(30, 35, 55)
		progressBg.Parent = card

		local progressBgCorner = Instance.new("UICorner")
		progressBgCorner.CornerRadius = UDim.new(0, 4)
		progressBgCorner.Parent = progressBg

		local progressFill = Instance.new("Frame")
		progressFill.Name = "ProgressFill"
		progressFill.Size = UDim2.new(0, 0, 1, 0)
		progressFill.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
		progressFill.Parent = progressBg

		local progressFillCorner = Instance.new("UICorner")
		progressFillCorner.CornerRadius = UDim.new(0, 4)
		progressFillCorner.Parent = progressFill

		-- 퀘스트 카운트 텍스트
		local questCount = Instance.new("TextLabel")
		questCount.Name = "QuestCount"
		questCount.Size = UDim2.new(0, 60, 0, 18)
		questCount.Position = UDim2.new(1, -68, 0, 32)
		questCount.BackgroundTransparency = 1
		questCount.TextColor3 = Color3.fromRGB(150, 160, 200)
		questCount.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
		questCount.Font = Enum.Font.Gotham
		questCount.Text = `0/{#chapter.questIds}`
		questCount.TextXAlignment = Enum.TextXAlignment.Right
		questCount.Parent = card

		-- 클릭 → 챕터 상세 열기
		local clickBtn = Instance.new("TextButton")
		clickBtn.Size = UDim2.new(1, 0, 1, 0)
		clickBtn.BackgroundTransparency = 1
		clickBtn.Text = ""
		clickBtn.Parent = card

		clickBtn.MouseButton1Click:Connect(function()
			self:_openChapterDetail(chapter.id)
		end)
	end
end

-- ==================== 스킬 카드 빌드 ====================

function ScenarioController:_buildSkillCards(parent: Frame)
	local yOffset = 8
	for _, skillId in ScenarioConstants.SKILL_ORDER do
		local skill = ScenarioConstants.SKILLS[skillId]
		if not skill then
			continue
		end

		local card = Instance.new("Frame")
		card.Name = `Skill_{skillId}`
		card.Size = UDim2.new(1, -10, 0, 62)
		card.Position = UDim2.new(0, 5, 0, yOffset)
		card.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
		card.BorderSizePixel = 0
		card.Parent = parent

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 10)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Name = "SkillStroke"
		cardStroke.Color = Color3.fromRGB(50, 50, 80)
		cardStroke.Thickness = 1.5
		cardStroke.Parent = card

		-- 아이콘
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(0, 44, 0, 44)
		iconLabel.Position = UDim2.new(0, 8, 0, 9)
		iconLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
		iconLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		iconLabel.TextSize = 22
		iconLabel.Font = Enum.Font.GothamBold
		iconLabel.Text = skill.icon
		iconLabel.Parent = card

		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(0, 8)
		iconCorner.Parent = iconLabel

		-- 스킬 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "SkillName"
		nameLabel.Size = UDim2.new(1, -110, 0, 20)
		nameLabel.Position = UDim2.new(0, 60, 0, 10)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
		nameLabel.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = skill.name
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = card

		-- 설명
		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "SkillDesc"
		descLabel.Size = UDim2.new(1, -110, 0, 28)
		descLabel.Position = UDim2.new(0, 60, 0, 30)
		descLabel.BackgroundTransparency = 1
		descLabel.TextColor3 = Color3.fromRGB(150, 155, 180)
		descLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
		descLabel.Font = Enum.Font.Gotham
		descLabel.Text = skill.desc
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true
		descLabel.Parent = card

		-- 챕터 해금 뱃지
		local chBadge = Instance.new("TextLabel")
		chBadge.Name = "ChBadge"
		chBadge.Size = UDim2.new(0, 80, 0, 24)
		chBadge.Position = UDim2.new(1, -88, 0, 19)
		chBadge.BackgroundColor3 = Color3.fromRGB(40, 50, 90)
		chBadge.TextColor3 = Color3.fromRGB(150, 160, 210)
		chBadge.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
		chBadge.Font = Enum.Font.Gotham
		chBadge.Text = `CH{skill.unlockChapter} 해금`
		chBadge.Parent = card

		local chBadgeCorner = Instance.new("UICorner")
		chBadgeCorner.CornerRadius = UDim.new(0, 6)
		chBadgeCorner.Parent = chBadge

		yOffset += 68
	end
end

-- ==================== 챕터 상세 오버레이 ====================

function ScenarioController:_buildDetailOverlay(parent: Frame)
	local detail = Instance.new("Frame")
	detail.Name = "ChapterDetail"
	detail.Size = UDim2.new(1, 0, 1, 0)
	detail.BackgroundColor3 = Color3.fromRGB(18, 22, 38)
	detail.Visible = false
	detail.ZIndex = 5
	detail.Parent = parent
	self._detailFrame = detail

	local detailCorner = Instance.new("UICorner")
	detailCorner.CornerRadius = UDim.new(0, 12)
	detailCorner.Parent = detail

	-- 뒤로가기 버튼
	local backBtn = Instance.new("TextButton")
	backBtn.Size = UDim2.new(0, 72, 0, 32)
	backBtn.Position = UDim2.new(0, 10, 0, 8)
	backBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 80)
	backBtn.TextColor3 = Color3.fromRGB(180, 200, 255)
	backBtn.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
	backBtn.Font = Enum.Font.GothamBold
	backBtn.Text = "◀ 뒤로"
	backBtn.ZIndex = 6
	backBtn.Parent = detail

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 8)
	backCorner.Parent = backBtn

	backBtn.MouseButton1Click:Connect(function()
		self:_closeChapterDetail()
	end)

	-- 챕터 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "DetailTitle"
	titleLabel.Size = UDim2.new(1, -20, 0, 32)
	titleLabel.Position = UDim2.new(0, 10, 0, 46)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
	titleLabel.TextSize = ResponsiveUtil.scaledTextSize(15, 12)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = ""
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 6
	titleLabel.Parent = detail
	self._detailTitleLabel = titleLabel

	-- 퀘스트 목록 스크롤
	local questScroll = Instance.new("ScrollingFrame")
	questScroll.Name = "QuestScroll"
	questScroll.Size = UDim2.new(1, -10, 1, -84)
	questScroll.Position = UDim2.new(0, 5, 0, 80)
	questScroll.BackgroundTransparency = 1
	questScroll.ScrollBarThickness = 4
	questScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
	questScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	questScroll.ZIndex = 6
	questScroll.Parent = detail
	self._detailScrollFrame = questScroll

	local questListLayout = Instance.new("UIListLayout")
	questListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	questListLayout.Padding = UDim.new(0, 6)
	questListLayout.Parent = questScroll

	questListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		questScroll.CanvasSize = UDim2.new(0, 0, 0, questListLayout.AbsoluteContentSize.Y + 10)
	end)
end

-- ==================== 챕터 상세 열기/닫기 ====================

function ScenarioController:_openChapterDetail(chapterId: string)
	local detail = self._detailFrame
	if not detail then
		return
	end

	self._currentDetailChapterId = chapterId
	self:_populateQuestDetail(chapterId)

	detail.Visible = true
	detail.Position = UDim2.new(1, 0, 0, 0) -- 오른쪽에서 슬라이드 인
	TweenService:Create(detail, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()
end

function ScenarioController:_closeChapterDetail()
	local detail = self._detailFrame
	if not detail then
		return
	end

	TweenService:Create(detail, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(1, 0, 0, 0),
	}):Play()

	task.delay(0.2, function()
		detail.Visible = false
		self._currentDetailChapterId = nil
	end)
end

function ScenarioController:_populateQuestDetail(chapterId: string)
	local questScroll = self._detailScrollFrame
	if not questScroll then
		return
	end

	-- 기존 퀘스트 아이템 제거
	for _, child in questScroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	self._questFillBars = {}
	self._questProgressTexts = {}

	-- 챕터 데이터 찾기
	local chapter = ScenarioConstants.CHAPTER_MAP[chapterId]
	if not chapter then
		return
	end

	-- 타이틀 업데이트
	if self._detailTitleLabel then
		self._detailTitleLabel.Text = `{chapter.theme} CH{chapter.num}: {chapter.name}`
	end

	-- 퀘스트 진행도 가져오기
	local questProgress: { [string]: number } = {}
	if self._scenarioData then
		local chapters = self._scenarioData.chapters :: { any }
		for _, ch in chapters do
			if ch.id == chapterId then
				for _, q in ch.quests do
					questProgress[q.id] = q.progress or 0
				end
				break
			end
		end
	end

	-- 챕터 잠금 여부
	local isUnlocked = false
	local isCompleted = false
	if self._scenarioData then
		local chapters = self._scenarioData.chapters :: { any }
		for _, ch in chapters do
			if ch.id == chapterId then
				isUnlocked = ch.isUnlocked == true
				isCompleted = ch.isCompleted == true
				break
			end
		end
	end

	-- 퀘스트 아이템 생성
	for i, questId in chapter.questIds do
		local quest = ScenarioConstants.QUESTS[questId]
		if not quest then
			continue
		end

		local progress = questProgress[questId] or 0
		local completed = progress >= quest.target

		local item = Instance.new("Frame")
		item.Name = `Quest_{questId}`
		item.Size = UDim2.new(1, -8, 0, 60)
		item.BackgroundColor3 = if completed
			then Color3.fromRGB(28, 32, 18)
			else Color3.fromRGB(22, 26, 44)
		item.BorderSizePixel = 0
		item.LayoutOrder = i
		item.ZIndex = 7
		item.Parent = questScroll

		local itemCorner = Instance.new("UICorner")
		itemCorner.CornerRadius = UDim.new(0, 8)
		itemCorner.Parent = item

		local itemStroke = Instance.new("UIStroke")
		itemStroke.Color = if completed then Color3.fromRGB(80, 140, 60) else Color3.fromRGB(40, 50, 80)
		itemStroke.Thickness = 1
		itemStroke.Parent = item

		-- 퀘스트 이름
		local qNameLabel = Instance.new("TextLabel")
		qNameLabel.Size = UDim2.new(1, -70, 0, 20)
		qNameLabel.Position = UDim2.new(0, 10, 0, 6)
		qNameLabel.BackgroundTransparency = 1
		qNameLabel.TextColor3 = if completed then Color3.fromRGB(140, 220, 100) else Color3.fromRGB(210, 215, 235)
		qNameLabel.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
		qNameLabel.Font = Enum.Font.GothamBold
		qNameLabel.Text = quest.name
		qNameLabel.TextXAlignment = Enum.TextXAlignment.Left
		qNameLabel.ZIndex = 7
		qNameLabel.Parent = item

		-- 보상 라벨
		local rewardLabel = Instance.new("TextLabel")
		rewardLabel.Size = UDim2.new(0, 65, 0, 20)
		rewardLabel.Position = UDim2.new(1, -70, 0, 6)
		rewardLabel.BackgroundTransparency = 1
		rewardLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
		rewardLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
		rewardLabel.Font = Enum.Font.Gotham
		rewardLabel.Text = `+{quest.reward.coins}🪙`
		rewardLabel.TextXAlignment = Enum.TextXAlignment.Right
		rewardLabel.ZIndex = 7
		rewardLabel.Parent = item

		-- 퀘스트 설명
		local qDescLabel = Instance.new("TextLabel")
		qDescLabel.Size = UDim2.new(1, -20, 0, 14)
		qDescLabel.Position = UDim2.new(0, 10, 0, 26)
		qDescLabel.BackgroundTransparency = 1
		qDescLabel.TextColor3 = Color3.fromRGB(140, 145, 170)
		qDescLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
		qDescLabel.Font = Enum.Font.Gotham
		qDescLabel.Text = quest.desc
		qDescLabel.TextXAlignment = Enum.TextXAlignment.Left
		qDescLabel.ZIndex = 7
		qDescLabel.Parent = item

		-- 진행도 바
		local qProgBg = Instance.new("Frame")
		qProgBg.Size = UDim2.new(1, -20, 0, 8)
		qProgBg.Position = UDim2.new(0, 10, 0, 44)
		qProgBg.BackgroundColor3 = Color3.fromRGB(30, 35, 58)
		qProgBg.ZIndex = 7
		qProgBg.Parent = item

		local qProgBgCorner = Instance.new("UICorner")
		qProgBgCorner.CornerRadius = UDim.new(0, 4)
		qProgBgCorner.Parent = qProgBg

		local ratio = math.clamp((progress / quest.target), 0, 1)
		local qProgFill = Instance.new("Frame")
		qProgFill.Name = "QFill"
		qProgFill.Size = UDim2.new(ratio, 0, 1, 0)
		qProgFill.BackgroundColor3 = if completed
			then Color3.fromRGB(100, 200, 80)
			else if isUnlocked then Color3.fromRGB(80, 130, 255) else Color3.fromRGB(60, 65, 90)
		qProgFill.ZIndex = 8
		qProgFill.Parent = qProgBg
		self._questFillBars[questId] = qProgFill

		local qProgFillCorner = Instance.new("UICorner")
		qProgFillCorner.CornerRadius = UDim.new(0, 4)
		qProgFillCorner.Parent = qProgFill

		-- 진행도 텍스트 (바 위)
		local qProgText = Instance.new("TextLabel")
		qProgText.Size = UDim2.new(1, 0, 1, 0)
		qProgText.BackgroundTransparency = 1
		qProgText.TextColor3 = Color3.fromRGB(255, 255, 255)
		qProgText.TextSize = ResponsiveUtil.scaledTextSize(10, 8)
		qProgText.Font = Enum.Font.GothamBold
		qProgText.Text = if completed then "CLEAR!" else `{progress}/{quest.target}`
		qProgText.ZIndex = 9
		qProgText.Parent = qProgBg
		self._questProgressTexts[questId] = qProgText

		-- 잠금 표시
		if not isUnlocked then
			local lockLabel = Instance.new("TextLabel")
			lockLabel.Size = UDim2.new(1, 0, 1, 0)
			lockLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			lockLabel.BackgroundTransparency = 0.6
			lockLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
			lockLabel.TextSize = 16
			lockLabel.Font = Enum.Font.GothamBold
			lockLabel.Text = "🔒"
			lockLabel.ZIndex = 10
			lockLabel.Parent = item

			local lockCorner = Instance.new("UICorner")
			lockCorner.CornerRadius = UDim.new(0, 8)
			lockCorner.Parent = lockLabel
		end
	end
end

-- ==================== 탭 전환 ====================

function ScenarioController:_switchTab(tabName: string)
	self._currentTab = tabName
	local isChapters = tabName == "chapters"

	if self._chapterScrollFrame then
		self._chapterScrollFrame.Visible = isChapters
	end
	if self._skillFrame then
		self._skillFrame.Visible = not isChapters
	end

	if self._tabChapters then
		self._tabChapters.BackgroundColor3 = if isChapters
			then Color3.fromRGB(60, 80, 180)
			else Color3.fromRGB(35, 35, 55)
		self._tabChapters.TextColor3 = if isChapters
			then Color3.fromRGB(255, 255, 255)
			else Color3.fromRGB(180, 180, 200)
	end
	if self._tabSkills then
		self._tabSkills.BackgroundColor3 = if not isChapters
			then Color3.fromRGB(100, 50, 180)
			else Color3.fromRGB(35, 35, 55)
		self._tabSkills.TextColor3 = if not isChapters
			then Color3.fromRGB(255, 255, 255)
			else Color3.fromRGB(180, 180, 200)
	end
end

-- ==================== 데이터로 UI 업데이트 ====================

function ScenarioController:_updateWithData(data: any)
	self._scenarioData = data
	local chapters = data.chapters :: { any }
	local unlockedSkills = data.unlockedSkills :: { string }

	-- 해금 스킬 셋
	local skillSet: { [string]: boolean } = {}
	for _, skillId in unlockedSkills do
		skillSet[skillId] = true
	end

	-- 챕터 카드 업데이트
	for _, chapter in chapters do
		local card = self._chapterCards[chapter.id]
		if not card then
			continue
		end

		local isUnlocked = chapter.isUnlocked == true
		local isCompleted = chapter.isCompleted == true

		-- 완료된 퀘스트 수 계산
		local doneCount = 0
		local totalCount = #chapter.quests
		for _, q in chapter.quests do
			if q.completed then
				doneCount += 1
			end
		end

		-- 카드 배경색
		if isCompleted then
			card.BackgroundColor3 = Color3.fromRGB(28, 35, 20)
		elseif isUnlocked then
			card.BackgroundColor3 = Color3.fromRGB(22, 28, 48)
		else
			card.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
		end

		-- 상태 라벨
		local statusLabel = card:FindFirstChild("StatusLabel") :: TextLabel?
		if statusLabel then
			statusLabel.Text = if isCompleted then "✅" elseif isUnlocked then "▶" else "🔒"
			statusLabel.TextColor3 = if isCompleted
				then Color3.fromRGB(100, 220, 80)
				elseif isUnlocked then Color3.fromRGB(100, 160, 255)
				else Color3.fromRGB(100, 100, 120)
		end

		-- 퀘스트 카운트
		local questCount = card:FindFirstChild("QuestCount") :: TextLabel?
		if questCount then
			if not isUnlocked then
				-- 잠금 챕터: 해금 요구 점수 대비 현재 최고점수 표시
				local chapterDef = ScenarioConstants.CHAPTER_MAP[chapter.id]
				local minScore = chapterDef and chapterDef.unlockConditions and chapterDef.unlockConditions.minScore or 0
				questCount.Text = `🏆{self._playerHighScore}/{minScore}`
				questCount.TextColor3 = Color3.fromRGB(200, 160, 80)
			else
				questCount.Text = `{doneCount}/{totalCount}`
				questCount.TextColor3 = if isCompleted
					then Color3.fromRGB(100, 220, 80)
					else Color3.fromRGB(150, 160, 200)
			end
		end

		-- 진행 바
		local progressBg = card:FindFirstChild("ProgressBg") :: Frame?
		if progressBg then
			local fill = progressBg:FindFirstChild("ProgressFill") :: Frame?
			if fill then
				local ratio: number
				if not isUnlocked then
					-- 잠금 챕터: 점수 진행도 표시
					local chapterDef = ScenarioConstants.CHAPTER_MAP[chapter.id]
					local minScore = chapterDef and chapterDef.unlockConditions and chapterDef.unlockConditions.minScore or 0
					ratio = if minScore > 0 then math.clamp(self._playerHighScore / minScore, 0, 1) else 0
				else
					ratio = if totalCount > 0 then math.clamp(doneCount / totalCount, 0, 1) else 0
				end
				TweenService:Create(fill, TweenInfo.new(0.5), {
					Size = UDim2.new(ratio, 0, 1, 0),
				}):Play()
				fill.BackgroundColor3 = if isCompleted
					then Color3.fromRGB(100, 200, 80)
					elseif isUnlocked then Color3.fromRGB(80, 130, 255)
					else Color3.fromRGB(200, 160, 60) -- 황금색: 점수 진행도
			end
		end

		-- 이름 라벨 색상
		local nameLabel = card:FindFirstChild("NameLabel") :: TextLabel?
		if nameLabel then
			nameLabel.TextColor3 = if isCompleted
				then Color3.fromRGB(160, 230, 120)
				elseif isUnlocked then Color3.fromRGB(220, 225, 245)
				else Color3.fromRGB(100, 105, 130)
		end
	end

	-- 스킬 카드 업데이트
	local skillFrame = self._skillFrame
	if skillFrame then
		for _, skillId in ScenarioConstants.SKILL_ORDER do
			local skillCard = skillFrame:FindFirstChild(`Skill_{skillId}`) :: Frame?
			if not skillCard then
				continue
			end

			local unlocked = skillSet[skillId] == true
			local stroke = skillCard:FindFirstChild("SkillStroke") :: UIStroke?
			if stroke then
				stroke.Color = if unlocked then Color3.fromRGB(150, 80, 240) else Color3.fromRGB(50, 50, 80)
				stroke.Thickness = if unlocked then 2 else 1
			end

			skillCard.BackgroundColor3 = if unlocked
				then Color3.fromRGB(28, 18, 50)
				else Color3.fromRGB(20, 20, 38)

			local iconLabel = skillCard:FindFirstChild("TextLabel") :: TextLabel?
			if iconLabel then
				iconLabel.TextColor3 = if unlocked
					then Color3.fromRGB(210, 150, 255)
					else Color3.fromRGB(80, 80, 100)
			end

			local skillName = skillCard:FindFirstChild("SkillName") :: TextLabel?
			if skillName then
				skillName.TextColor3 = if unlocked
					then Color3.fromRGB(220, 180, 255)
					else Color3.fromRGB(100, 105, 130)
			end

			local chBadge = skillCard:FindFirstChild("ChBadge") :: TextLabel?
			if chBadge then
				chBadge.BackgroundColor3 = if unlocked
					then Color3.fromRGB(70, 30, 120)
					else Color3.fromRGB(35, 38, 65)
				chBadge.TextColor3 = if unlocked
					then Color3.fromRGB(210, 160, 255)
					else Color3.fromRGB(100, 105, 140)
				chBadge.Text = if unlocked then "✅ 해금됨" else `CH{ScenarioConstants.SKILLS[skillId].unlockChapter} 해금`
			end
		end
	end

	-- 현재 상세 페이지가 열려 있으면 갱신
	if self._currentDetailChapterId then
		self:_populateQuestDetail(self._currentDetailChapterId)
	end

	-- 게임 중이면 퀘스트 HUD 갱신
	if self._isGameActive then
		self:_updateQuestHud()
	end
end

-- QuestProgressUpdate 이벤트로 퀘스트 진행바 실시간 갱신
function ScenarioController:_onQuestProgressUpdate(_progressData: any)
	if self._isOpen or self._isGameActive then
		-- 데이터 다시 요청하여 전체 갱신 (HUD 포함)
		RemoteEvents.ScenarioDataRequest:FireServer()
	end
end

-- ==================== 팝업 열기/닫기 ====================

function ScenarioController:OpenPanel()
	local playerGui = self._player:WaitForChild("PlayerGui")
	local popupGui = playerGui:FindFirstChild("ScenarioPopupGui") :: ScreenGui?
	local frame = self._panelFrame
	if not popupGui or not frame then
		return
	end

	self._isOpen = true
	popupGui.Enabled = true
	self:_switchTab(self._currentTab)

	-- 팝업 애니메이션
	local targetSize = ResponsiveUtil.clampedSize(370, 440, 0.92, 0.88)
	local targetW = targetSize.X.Offset
	frame.Size = UDim2.new(0, targetW, 0, 0)
	frame.Position = UDim2.new(0.5, -targetW / 2, 0.5, 0)

	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = targetSize,
		Position = ResponsiveUtil.clampedPosition(370, 440, 0.92, 0.88),
	}):Play()

	-- 최신 데이터 요청
	RemoteEvents.ScenarioDataRequest:FireServer()
end

function ScenarioController:ClosePanel()
	local playerGui = self._player:WaitForChild("PlayerGui")
	local popupGui = playerGui:FindFirstChild("ScenarioPopupGui") :: ScreenGui?
	local frame = self._panelFrame
	if not popupGui or not frame then
		return
	end

	self._isOpen = false
	self:_closeChapterDetail()

	local targetSize = ResponsiveUtil.clampedSize(370, 440, 0.92, 0.88)
	local targetW = targetSize.X.Offset
	TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, targetW, 0, 0),
		Position = UDim2.new(0.5, -targetW / 2, 0.5, 0),
	}):Play()

	task.delay(0.22, function()
		popupGui.Enabled = false
	end)
end

-- 게임 중 숨기기
function ScenarioController:HideForGame()
	if self._lobbyButton then
		self._lobbyButton.Visible = false
	end
	if self._isOpen then
		self:ClosePanel()
	end
	-- 게임 중 퀘스트 HUD 활성화
	self._isGameActive = true
	self:_updateQuestHud()
end

-- 로비에서 표시
function ScenarioController:ShowInLobby()
	if self._lobbyButton then
		self._lobbyButton.Visible = true
	end
	-- 퀘스트 HUD 비활성화
	self._isGameActive = false
	if self._questHudGui then
		self._questHudGui.Enabled = false
	end
end

-- ==================== 이벤트 핸들러 ====================

function ScenarioController:_setupEventHandlers()
	-- 전체 시나리오 데이터 수신
	local dataConn = RemoteEvents.ScenarioDataResponse.OnClientEvent:Connect(function(data)
		self:_updateWithData(data)
	end)
	table.insert(self._connections, dataConn)

	-- 퀘스트 진행도 실시간 업데이트
	local progressConn = RemoteEvents.QuestProgressUpdate.OnClientEvent:Connect(function(data)
		self:_onQuestProgressUpdate(data)
	end)
	table.insert(self._connections, progressConn)

	-- 퀘스트 완료 토스트 알림 (QuestCompleted)
	local questDoneConn = RemoteEvents.QuestCompleted.OnClientEvent:Connect(function(data)
		self:_showQuestCompleteToast(data.questName)
	end)
	table.insert(self._connections, questDoneConn)

	-- 플레이어 데이터 로드 → 최고점수 캐시 (잠금 챕터 점수 시각화용)
	local playerDataConn = RemoteEvents.PlayerDataLoaded.OnClientEvent:Connect(function(data)
		if data and data.highScore then
			self._playerHighScore = data.highScore
			if self._scenarioData then
				self:_updateWithData(self._scenarioData)
			end
		end
	end)
	table.insert(self._connections, playerDataConn)
end

-- 퀘스트 완료 토스트 (화면 상단)
function ScenarioController:_showQuestCompleteToast(questName: string)
	local gui = self._gui
	if not gui then
		return
	end

	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 260, 0, 44)
	toast.Position = UDim2.new(0.5, -130, 0, -50)
	toast.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
	toast.BorderSizePixel = 0
	toast.Parent = gui

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 10)
	toastCorner.Parent = toast

	local toastStroke = Instance.new("UIStroke")
	toastStroke.Color = Color3.fromRGB(80, 200, 80)
	toastStroke.Thickness = 2
	toastStroke.Parent = toast

	local toastLabel = Instance.new("TextLabel")
	toastLabel.Size = UDim2.new(1, -12, 1, 0)
	toastLabel.Position = UDim2.new(0, 8, 0, 0)
	toastLabel.BackgroundTransparency = 1
	toastLabel.TextColor3 = Color3.fromRGB(140, 255, 140)
	toastLabel.TextSize = 14
	toastLabel.Font = Enum.Font.GothamBold
	toastLabel.Text = `✅ 퀘스트 완료: {questName}`
	toastLabel.TextXAlignment = Enum.TextXAlignment.Left
	toastLabel.Parent = toast

	-- 슬라이드 다운 → 대기 → 슬라이드 업
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -130, 0, 60),
	}):Play()

	task.delay(2.5, function()
		TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -130, 0, -50),
		}):Play()
		task.delay(0.3, function()
			toast:Destroy()
		end)
	end)
end

return ScenarioController

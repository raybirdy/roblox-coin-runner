--!strict
-- CutsceneController
-- 챕터 해금 시 컷씬(대화창) 표시 및 타이핑 애니메이션 처리

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(game:GetService("ReplicatedStorage").Shared.RemoteEvents)

local CutsceneController = {}
CutsceneController.__index = CutsceneController

-- 스킬별 첫 획득 튜토리얼 안내 텍스트
local SKILL_TUTORIAL = {
	double_jump = {
		icon = "⬆️",
		name = "2단 점프",
		howto = "공중에서 점프 버튼을 한 번 더 누르세요!",
		tip = "💡 높은 장애물도 거뜬히 넘을 수 있어요",
	},
	dash = {
		icon = "💨",
		name = "대쉬",
		howto = "화면 우측의 대쉬 버튼을 누르세요! (쿨다운 8초)",
		tip = "💡 장애물 직전에 쓰면 그냥 통과해요",
	},
	shield_regen = {
		icon = "🛡️",
		name = "쉴드 재생",
		howto = "60초마다 자동으로 쉴드가 1칸 회복돼요!",
		tip = "💡 오래 살아남을수록 점점 유리해져요",
	},
	magnet_burst = {
		icon = "🧲",
		name = "자석 폭발",
		howto = "장애물에 맞으면 주변 코인이 전부 흡수돼요!",
		tip = "💡 코인이 빽빽한 구간에서 특히 강력해요",
	},
	fever_boost = {
		icon = "🔥",
		name = "피버 부스트",
		howto = "피버 게이지가 30% 더 빠르게 채워져요!",
		tip = "💡 자동 적용! 피버 타임을 자주 노리세요",
	},
}

export type CutsceneController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_connections: { RBXScriptConnection },
		_gui: ScreenGui?,
		_panel: Frame?,
		_speakerLabel: TextLabel?,
		_dialogueLabel: TextLabel?,
		_nextBtn: TextButton?,
		_skipBtn: TextButton?,
		_isPlaying: boolean,
		_currentLineIndex: number,
		_currentLines: { { speaker: string, text: string } },
		_cutsceneQueue: { { lines: { { speaker: string, text: string } }, title: string? } },
		_typingThread: thread?,
		-- 스킬 튜토리얼
		_pendingSkillTutorial: string?,
		_shownSkillTutorials: { [string]: boolean },
	},
	CutsceneController
))

function CutsceneController.new(): CutsceneController
	local self = setmetatable({
		_player = Players.LocalPlayer,
		_connections = {},
		_gui = nil,
		_panel = nil,
		_speakerLabel = nil,
		_dialogueLabel = nil,
		_nextBtn = nil,
		_skipBtn = nil,
		_isPlaying = false,
		_currentLineIndex = 0,
		_currentLines = {},
		_cutsceneQueue = {},
		_typingThread = nil,
		_pendingSkillTutorial = nil,
		_shownSkillTutorials = {},
	}, CutsceneController)

	self:_createGui()
	self:_setupEventHandlers()

	return self
end

-- ==================== GUI 생성 ====================

function CutsceneController:_createGui()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "CutsceneGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20 -- 최상위 레이어
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	-- 하단 패널 (화면 하단 28%)
	local panel = Instance.new("Frame")
	panel.Name = "CutscenePanel"
	panel.Size = UDim2.new(1, 0, 0.28, 0)
	panel.Position = UDim2.new(0, 0, 0.72, 0)
	panel.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui
	self._panel = panel

	-- 상단 테두리 라인
	local topBorder = Instance.new("Frame")
	topBorder.Size = UDim2.new(1, 0, 0, 3)
	topBorder.Position = UDim2.new(0, 0, 0, 0)
	topBorder.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
	topBorder.BorderSizePixel = 0
	topBorder.Parent = panel

	-- 화자 이름 레이블
	local speakerBg = Instance.new("Frame")
	speakerBg.Name = "SpeakerBg"
	speakerBg.Size = UDim2.new(0, 180, 0, 28)
	speakerBg.Position = UDim2.new(0, 16, 0, -14)
	speakerBg.BackgroundColor3 = Color3.fromRGB(40, 80, 160)
	speakerBg.BorderSizePixel = 0
	speakerBg.Parent = panel

	local speakerBgCorner = Instance.new("UICorner")
	speakerBgCorner.CornerRadius = UDim.new(0, 6)
	speakerBgCorner.Parent = speakerBg

	local speakerLabel = Instance.new("TextLabel")
	speakerLabel.Name = "SpeakerLabel"
	speakerLabel.Size = UDim2.new(1, -12, 1, 0)
	speakerLabel.Position = UDim2.new(0, 8, 0, 0)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speakerLabel.TextSize = 14
	speakerLabel.Font = Enum.Font.GothamBold
	speakerLabel.Text = ""
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	speakerLabel.Parent = speakerBg
	self._speakerLabel = speakerLabel

	-- 대화 텍스트
	local dialogueLabel = Instance.new("TextLabel")
	dialogueLabel.Name = "DialogueLabel"
	dialogueLabel.Size = UDim2.new(1, -100, 1, -20)
	dialogueLabel.Position = UDim2.new(0, 16, 0, 24)
	dialogueLabel.BackgroundTransparency = 1
	dialogueLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
	dialogueLabel.TextSize = 16
	dialogueLabel.Font = Enum.Font.Gotham
	dialogueLabel.Text = ""
	dialogueLabel.TextXAlignment = Enum.TextXAlignment.Left
	dialogueLabel.TextYAlignment = Enum.TextYAlignment.Top
	dialogueLabel.TextWrapped = true
	dialogueLabel.Parent = panel
	self._dialogueLabel = dialogueLabel

	-- 다음 버튼
	local nextBtn = Instance.new("TextButton")
	nextBtn.Name = "NextBtn"
	nextBtn.Size = UDim2.new(0, 72, 0, 34)
	nextBtn.Position = UDim2.new(1, -84, 1, -48)
	nextBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
	nextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	nextBtn.TextSize = 14
	nextBtn.Font = Enum.Font.GothamBold
	nextBtn.Text = "다음 ▶"
	nextBtn.Parent = panel
	self._nextBtn = nextBtn

	local nextCorner = Instance.new("UICorner")
	nextCorner.CornerRadius = UDim.new(0, 8)
	nextCorner.Parent = nextBtn

	-- 건너뛰기 버튼
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipBtn"
	skipBtn.Size = UDim2.new(0, 72, 0, 22)
	skipBtn.Position = UDim2.new(1, -84, 0, 8)
	skipBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	skipBtn.TextColor3 = Color3.fromRGB(150, 150, 170)
	skipBtn.TextSize = 12
	skipBtn.Font = Enum.Font.Gotham
	skipBtn.Text = "건너뛰기"
	skipBtn.Parent = panel
	self._skipBtn = skipBtn

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 6)
	skipCorner.Parent = skipBtn

	-- 버튼 연결
	nextBtn.MouseButton1Click:Connect(function()
		self:_onNextPressed()
	end)

	skipBtn.MouseButton1Click:Connect(function()
		self:_skipAll()
	end)
end

-- ==================== 이벤트 핸들러 ====================

function CutsceneController:_setupEventHandlers()
	-- 챕터 해금/완료 이벤트 → 컷씬 큐에 추가
	local conn = RemoteEvents.ChapterUnlocked.OnClientEvent:Connect(function(data)
		if data.cutscene and #data.cutscene > 0 then
			local title = if data.isOpening
				then data.chapterTheme .. " " .. data.chapterName
				else data.chapterTheme .. " " .. data.chapterName .. " 완료!"
			self:QueueCutscene(data.cutscene, title)
		end
		-- 스킬 해금 시 컷씬 이후에 튜토리얼 표시 예약
		if data.skillUnlocked and not self._shownSkillTutorials[data.skillUnlocked] then
			self._pendingSkillTutorial = data.skillUnlocked
		end
	end)
	table.insert(self._connections, conn)
end

-- ==================== 컷씬 재생 ====================

-- 컷씬 큐에 추가 (여러 컷씬이 연속 발생 시 순서대로 재생)
function CutsceneController:QueueCutscene(
	lines: { { speaker: string, text: string } },
	title: string?
)
	table.insert(self._cutsceneQueue, { lines = lines, title = title })
	if not self._isPlaying then
		self:_playNext()
	end
end

function CutsceneController:_playNext()
	if #self._cutsceneQueue == 0 then
		self:_hide()
		-- 컷씬이 모두 끝난 후 스킬 튜토리얼 표시
		local pendingSkill = self._pendingSkillTutorial
		if pendingSkill and not self._shownSkillTutorials[pendingSkill] then
			self._pendingSkillTutorial = nil
			self._shownSkillTutorials[pendingSkill] = true
			task.delay(0.6, function()
				self:_showSkillTutorial(pendingSkill)
			end)
		end
		return
	end

	local cutscene = table.remove(self._cutsceneQueue, 1)
	self._currentLines = cutscene.lines
	self._currentLineIndex = 0
	self._isPlaying = true

	self:_show()
	self:_advanceLine()
end

function CutsceneController:_advanceLine()
	self._currentLineIndex += 1

	if self._currentLineIndex > #self._currentLines then
		-- 컷씬 종료 → 다음 컷씬 또는 숨기기
		task.delay(0.3, function()
			self._isPlaying = false
			self:_playNext()
		end)
		return
	end

	local line = self._currentLines[self._currentLineIndex]
	if self._speakerLabel then
		self._speakerLabel.Text = line.speaker
	end
	if self._dialogueLabel then
		self._dialogueLabel.Text = ""
	end

	-- 타이핑 애니메이션
	self:_typeText(line.text)
end

function CutsceneController:_typeText(text: string)
	-- 이전 타이핑 스레드 취소
	if self._typingThread and coroutine.status(self._typingThread) == "suspended" then
		task.cancel(self._typingThread)
	end

	self._typingThread = task.spawn(function()
		local label = self._dialogueLabel
		if not label then
			return
		end

		local chars = string.len(text)
		for i = 1, chars do
			label.Text = string.sub(text, 1, i)
			task.wait(0.03) -- 타이핑 속도: 30ms per char
		end
		self._typingThread = nil
	end)
end

-- 현재 라인 즉시 완성 or 전체 스킵
function CutsceneController:_onNextPressed()
	-- 타이핑 중이면 즉시 완성
	if self._typingThread then
		if self._typingThread and coroutine.status(self._typingThread) ~= "dead" then
			task.cancel(self._typingThread)
			self._typingThread = nil
		end
		local line = self._currentLines[self._currentLineIndex]
		if self._dialogueLabel and line then
			self._dialogueLabel.Text = line.text
		end
		return
	end
	-- 다음 라인으로
	self:_advanceLine()
end

function CutsceneController:_skipAll()
	if self._typingThread then
		task.cancel(self._typingThread)
		self._typingThread = nil
	end
	self._cutsceneQueue = {}
	self._isPlaying = false
	self:_hide()
	-- 건너뛰기 시에도 스킬 튜토리얼은 표시
	local pendingSkill = self._pendingSkillTutorial
	if pendingSkill and not self._shownSkillTutorials[pendingSkill] then
		self._pendingSkillTutorial = nil
		self._shownSkillTutorials[pendingSkill] = true
		task.delay(0.6, function()
			self:_showSkillTutorial(pendingSkill)
		end)
	end
end

-- ==================== 표시/숨기기 ====================

function CutsceneController:_show()
	local gui = self._gui
	local panel = self._panel
	if not gui or not panel then
		return
	end

	gui.Enabled = true
	panel.Position = UDim2.new(0, 0, 1, 0) -- 화면 아래서 슬라이드 업
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0.72, 0),
	}):Play()
end

function CutsceneController:_hide()
	local gui = self._gui
	local panel = self._panel
	if not gui or not panel then
		return
	end

	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0, 0, 1, 0),
	}):Play()

	task.delay(0.3, function()
		gui.Enabled = false
	end)
end

-- ==================== 스킬 튜토리얼 오버레이 ====================

function CutsceneController:_showSkillTutorial(skillId: string)
	local info = SKILL_TUTORIAL[skillId]
	if not info then
		return
	end

	local playerGui = self._player:WaitForChild("PlayerGui")

	local tutGui = Instance.new("ScreenGui")
	tutGui.Name = "SkillTutorialGui"
	tutGui.ResetOnSpawn = false
	tutGui.DisplayOrder = 22
	tutGui.Parent = playerGui

	-- 배경 (탭해서 닫기 가능)
	local dimBg = Instance.new("TextButton")
	dimBg.Size = UDim2.new(1, 0, 1, 0)
	dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimBg.BackgroundTransparency = 0.5
	dimBg.Text = ""
	dimBg.AutoButtonColor = false
	dimBg.Parent = tutGui

	-- 카드
	local card = Instance.new("Frame")
	card.Name = "SkillCard"
	card.Size = UDim2.new(0, 300, 0, 196)
	card.Position = UDim2.new(0.5, -150, 0.5, -98)
	card.BackgroundColor3 = Color3.fromRGB(14, 18, 36)
	card.BorderSizePixel = 0
	card.Parent = tutGui

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 16)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(160, 100, 255)
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	-- 새 스킬 뱃지
	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(0, 130, 0, 24)
	badge.Position = UDim2.new(0.5, -65, 0, -12)
	badge.BackgroundColor3 = Color3.fromRGB(140, 80, 240)
	badge.BorderSizePixel = 0
	badge.Parent = tutGui

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 12)
	badgeCorner.Parent = badge

	local badgeLabel = Instance.new("TextLabel")
	badgeLabel.Size = UDim2.new(1, 0, 1, 0)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	badgeLabel.TextSize = 12
	badgeLabel.Font = Enum.Font.GothamBold
	badgeLabel.Text = "🌟 새 스킬 획득!"
	badgeLabel.Parent = badge

	-- 아이콘
	local iconBg = Instance.new("Frame")
	iconBg.Size = UDim2.new(0, 64, 0, 64)
	iconBg.Position = UDim2.new(0.5, -32, 0, 18)
	iconBg.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
	iconBg.BorderSizePixel = 0
	iconBg.Parent = card

	local iconBgCorner = Instance.new("UICorner")
	iconBgCorner.CornerRadius = UDim.new(0, 12)
	iconBgCorner.Parent = iconBg

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.fromRGB(160, 100, 255)
	iconStroke.Thickness = 2
	iconStroke.Parent = iconBg

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.TextSize = 32
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.Text = info.icon
	iconLabel.Parent = iconBg

	-- 스킬 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -20, 0, 24)
	nameLabel.Position = UDim2.new(0, 10, 0, 88)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(210, 170, 255)
	nameLabel.TextSize = 18
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Text = info.name
	nameLabel.Parent = card

	-- 사용법
	local howtoLabel = Instance.new("TextLabel")
	howtoLabel.Size = UDim2.new(1, -24, 0, 34)
	howtoLabel.Position = UDim2.new(0, 12, 0, 116)
	howtoLabel.BackgroundTransparency = 1
	howtoLabel.TextColor3 = Color3.fromRGB(220, 225, 240)
	howtoLabel.TextSize = 13
	howtoLabel.Font = Enum.Font.Gotham
	howtoLabel.Text = info.howto
	howtoLabel.TextWrapped = true
	howtoLabel.TextXAlignment = Enum.TextXAlignment.Center
	howtoLabel.Parent = card

	-- 팁
	local tipLabel = Instance.new("TextLabel")
	tipLabel.Size = UDim2.new(1, -24, 0, 22)
	tipLabel.Position = UDim2.new(0, 12, 0, 150)
	tipLabel.BackgroundTransparency = 1
	tipLabel.TextColor3 = Color3.fromRGB(160, 200, 140)
	tipLabel.TextSize = 11
	tipLabel.Font = Enum.Font.Gotham
	tipLabel.Text = info.tip
	tipLabel.Parent = card

	-- 확인 버튼 (카운트다운 포함)
	local dismissBtn = Instance.new("TextButton")
	dismissBtn.Size = UDim2.new(1, -24, 0, 32)
	dismissBtn.Position = UDim2.new(0, 12, 1, -40)
	dismissBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 200)
	dismissBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	dismissBtn.TextSize = 14
	dismissBtn.Font = Enum.Font.GothamBold
	dismissBtn.Text = "확인! (6)"
	dismissBtn.Parent = card

	local dismissCorner = Instance.new("UICorner")
	dismissCorner.CornerRadius = UDim.new(0, 8)
	dismissCorner.Parent = dismissBtn

	-- 등장 애니메이션
	card.Position = UDim2.new(0.5, -150, 0.5, -98 + 40)
	card.BackgroundTransparency = 1
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -150, 0.5, -98),
		BackgroundTransparency = 0,
	}):Play()

	local function closeTutorial()
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -150, 0.5, -98 + 30),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.25, function()
			tutGui:Destroy()
		end)
	end

	dimBg.MouseButton1Click:Connect(closeTutorial)
	dismissBtn.MouseButton1Click:Connect(closeTutorial)

	-- 6초 카운트다운 후 자동 닫기
	task.spawn(function()
		for i = 5, 1, -1 do
			task.wait(1)
			if not dismissBtn.Parent then
				return
			end
			dismissBtn.Text = `확인! ({i})`
		end
		task.wait(1)
		if tutGui.Parent then
			closeTutorial()
		end
	end)
end

return CutsceneController

--!strict
-- CutsceneController
-- 챕터 해금 시 컷씬(대화창) 표시 및 타이핑 애니메이션 처리

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(game:GetService("ReplicatedStorage").Shared.RemoteEvents)

local CutsceneController = {}
CutsceneController.__index = CutsceneController

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

return CutsceneController

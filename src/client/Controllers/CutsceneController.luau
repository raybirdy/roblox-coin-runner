--!strict
-- CutsceneController
-- 챕터 해금 시 컷씬(대화창) 표시 및 타이핑 애니메이션 처리
-- PR #2: 초상화 시스템, 역할별 색상, shake/flash/particle 이펙트 추가

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ScenarioConstants = require(ReplicatedStorage.Shared.Constants.ScenarioConstants)

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

-- 역할별 테두리/강조 색상
local ROLE_COLORS = {
	hero    = Color3.fromRGB(100, 220, 100),
	villain = Color3.fromRGB(220, 50, 50),
	ally    = Color3.fromRGB(100, 180, 255),
	mentor  = Color3.fromRGB(150, 120, 255),
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
		_currentLines: { { speaker: string?, text: string, characterId: string?, effect: string? } },
		_cutsceneQueue: { { lines: { { speaker: string?, text: string, characterId: string?, effect: string? } }, title: string? } },
		_typingThread: thread?,
		_portraitBobThread: thread?,
		_charTintThread: thread?,
		-- 스킬 튜토리얼
		_pendingSkillTutorial: string?,
		_shownSkillTutorials: { [string]: boolean },
		-- 초상화 시스템 (신규)
		_portraitFrame: Frame?,
		_portraitEmoji: TextLabel?,
		_speakerBg: Frame?,
		_topBorder: Frame?,
		_currentChapterId: string?,
		-- 배경 딤 오버레이
		_dimOverlay: Frame?,
		-- 입력 차단 콜백
		_onPlayStart: (() -> ())?,
		_onPlayEnd: (() -> ())?,
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
		_portraitBobThread = nil,
		_charTintThread = nil,
		_pendingSkillTutorial = nil,
		_shownSkillTutorials = {},
		_portraitFrame = nil,
		_portraitEmoji = nil,
		_speakerBg = nil,
		_topBorder = nil,
		_currentChapterId = nil,
		_dimOverlay = nil,
		_onPlayStart = nil,
		_onPlayEnd = nil,
	}, CutsceneController)

	self:_createGui()
	self:_setupEventHandlers()

	return self
end

-- ==================== 입력 차단 콜백 등록 ====================

function CutsceneController:OnPlayStart(callback: () -> ())
	self._onPlayStart = callback
end

function CutsceneController:OnPlayEnd(callback: () -> ())
	self._onPlayEnd = callback
end

-- ==================== GUI 생성 ====================

function CutsceneController:_createGui()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "CutsceneGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.Parent = playerGui
	self._gui = gui

	-- 배경 딤 오버레이 (컷씬 재생 중 배경 어둡게)
	local dimOverlay = Instance.new("Frame")
	dimOverlay.Name = "DimOverlay"
	dimOverlay.Size = UDim2.new(1, 0, 1, 0)
	dimOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimOverlay.BackgroundTransparency = 1
	dimOverlay.BorderSizePixel = 0
	dimOverlay.ZIndex = 1
	dimOverlay.Parent = gui
	self._dimOverlay = dimOverlay

	-- 전체화면 투명 입력 차단 버튼 (모바일 터치 이벤트 차단)
	local inputBlocker = Instance.new("TextButton")
	inputBlocker.Name = "InputBlocker"
	inputBlocker.Size = UDim2.new(1, 0, 1, 0)
	inputBlocker.BackgroundTransparency = 1
	inputBlocker.Text = ""
	inputBlocker.AutoButtonColor = false
	inputBlocker.ZIndex = 0
	inputBlocker.Parent = gui

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

	-- 상단 테두리 라인 (역할별 동적 색상)
	local topBorder = Instance.new("Frame")
	topBorder.Name = "TopBorder"
	topBorder.Size = UDim2.new(1, 0, 0, 3)
	topBorder.Position = UDim2.new(0, 0, 0, 0)
	topBorder.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
	topBorder.BorderSizePixel = 0
	topBorder.Parent = panel
	self._topBorder = topBorder

	-- 캐릭터 초상화 원형 프레임 (패널 좌측 상단, 패널 위로 돌출)
	local portraitFrame = Instance.new("Frame")
	portraitFrame.Name = "PortraitFrame"
	portraitFrame.Size = UDim2.new(0, 60, 0, 60)
	portraitFrame.Position = UDim2.new(0, 12, 0, -36)
	portraitFrame.BackgroundColor3 = Color3.fromRGB(40, 80, 160)
	portraitFrame.BorderSizePixel = 0
	portraitFrame.Parent = panel
	self._portraitFrame = portraitFrame

	local portraitCorner = Instance.new("UICorner")
	portraitCorner.CornerRadius = UDim.new(1, 0)
	portraitCorner.Parent = portraitFrame

	local portraitStroke = Instance.new("UIStroke")
	portraitStroke.Color = Color3.fromRGB(100, 180, 255)
	portraitStroke.Thickness = 3
	portraitStroke.Parent = portraitFrame

	local portraitEmoji = Instance.new("TextLabel")
	portraitEmoji.Name = "PortraitEmoji"
	portraitEmoji.Size = UDim2.new(1, 0, 1, 0)
	portraitEmoji.BackgroundTransparency = 1
	portraitEmoji.Text = "🦉"
	portraitEmoji.TextSize = 28
	portraitEmoji.Font = Enum.Font.GothamBold
	portraitEmoji.Parent = portraitFrame
	self._portraitEmoji = portraitEmoji

	-- 화자 이름 배경 (초상화 오른쪽으로 이동)
	local speakerBg = Instance.new("Frame")
	speakerBg.Name = "SpeakerBg"
	speakerBg.Size = UDim2.new(0, 180, 0, 28)
	speakerBg.Position = UDim2.new(0, 80, 0, -14)
	speakerBg.BackgroundColor3 = Color3.fromRGB(40, 80, 160)
	speakerBg.BorderSizePixel = 0
	speakerBg.Parent = panel
	self._speakerBg = speakerBg

	local speakerBgCorner = Instance.new("UICorner")
	speakerBgCorner.CornerRadius = UDim.new(0, 6)
	speakerBgCorner.Parent = speakerBg

	local speakerLabel = Instance.new("TextLabel")
	speakerLabel.Name = "SpeakerLabel"
	speakerLabel.Size = UDim2.new(1, -12, 1, 0)
	speakerLabel.Position = UDim2.new(0, 8, 0, 0)
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speakerLabel.TextSize = 13
	speakerLabel.Font = Enum.Font.GothamBold
	speakerLabel.Text = ""
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	speakerLabel.Parent = speakerBg
	self._speakerLabel = speakerLabel

	-- 대화 텍스트 (초상화 오른쪽 공간)
	local dialogueLabel = Instance.new("TextLabel")
	dialogueLabel.Name = "DialogueLabel"
	dialogueLabel.Size = UDim2.new(1, -160, 1, -20)
	dialogueLabel.Position = UDim2.new(0, 80, 0, 24)
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
	local conn = RemoteEvents.ChapterUnlocked.OnClientEvent:Connect(function(data)
		if data.cutscene and #data.cutscene > 0 then
			local title = if data.isOpening
				then data.chapterTheme .. " " .. data.chapterName
				else data.chapterTheme .. " " .. data.chapterName .. " 완료!"
			self:QueueCutscene(data.cutscene, title, data.chapterId)
		end

		-- 챕터 완료 시 축하 연출 (컷씬 종료 후)
		if not data.isOpening and not data.bossRunReady then
			local chapter = ScenarioConstants.CHAPTER_MAP[data.chapterId]
			if chapter then
				local cutsceneLen = if data.cutscene then #data.cutscene else 0
				task.delay(cutsceneLen * 3 + 1, function()
					self:ShowChapterClearCelebration(chapter.num, chapter.name)
				end)
			end
		end

		if data.skillUnlocked and not self._shownSkillTutorials[data.skillUnlocked] then
			self._pendingSkillTutorial = data.skillUnlocked
		end
	end)
	table.insert(self._connections, conn)
end

-- ==================== 컷씬 재생 ====================

-- 컷씬 큐에 추가 (chapterId: 테마 색상 참조용)
function CutsceneController:QueueCutscene(
	lines: { { speaker: string?, text: string, characterId: string?, effect: string? } },
	title: string?,
	chapterId: string?
)
	self._currentChapterId = chapterId
	table.insert(self._cutsceneQueue, { lines = lines, title = title })
	if not self._isPlaying then
		self:_playNext()
	end
end

function CutsceneController:_playNext()
	if #self._cutsceneQueue == 0 then
		self:_hide()
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
		task.delay(0.3, function()
			self._isPlaying = false
			self:_playNext()
		end)
		return
	end

	local line = self._currentLines[self._currentLineIndex]

	-- characterId 기반 초상화/색상 업데이트
	local characterId = line.characterId
	local profile = if characterId then ScenarioConstants.CHARACTER_PROFILES[characterId] else nil

	-- 캐릭터 역할별 딤 오버레이 틴트
	local roleColors = {
		villain = Color3.fromRGB(80, 10, 10),
		mentor  = Color3.fromRGB(10, 20, 60),
		ally    = Color3.fromRGB(10, 40, 20),
	}
	local tint = roleColors[profile and profile.role or ""] or Color3.fromRGB(10, 10, 30)
	if self._dimOverlay then
		TweenService:Create(self._dimOverlay, TweenInfo.new(0.4), {
			BackgroundColor3 = tint,
		}):Play()
	end

	if profile then
		self:_updatePortrait(profile)
		if self._speakerLabel then
			self._speakerLabel.Text = profile.emoji .. " " .. profile.name
		end
		if self._speakerBg then
			TweenService:Create(self._speakerBg, TweenInfo.new(0.2), {
				BackgroundColor3 = profile.bgColor,
			}):Play()
			-- 화자 이름 배경 바운스 애니메이션
			local speakerScaleInst = self._speakerBg:FindFirstChildOfClass("UIScale")
			if not speakerScaleInst then
				speakerScaleInst = Instance.new("UIScale")
				speakerScaleInst.Parent = self._speakerBg
			end
			local speakerScale = speakerScaleInst :: UIScale
			speakerScale.Scale = 0.85
			TweenService:Create(speakerScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1.0,
			}):Play()
		end
		self:_updateBorderColor(profile.role)
	elseif line.speaker then
		-- 하위호환: speaker 문자열 그대로 표시
		if self._speakerLabel then
			self._speakerLabel.Text = line.speaker
		end
	end

	-- 이펙트 처리
	local effect = line.effect
	if effect == "shake" then
		self:_shakePanel()
	elseif effect == "flash" then
		self:_flashPanel()
	elseif effect == "particle" then
		self:_showVictoryParticle()
	end

	-- 대화 라인 전환 페이드 (첫 번째 줄이 아닌 경우 fade-out 후 진행)
	if self._currentLineIndex > 1 and self._dialogueLabel then
		local fadeOutTween = TweenService:Create(self._dialogueLabel, TweenInfo.new(0.1), {
			TextTransparency = 1,
		})
		fadeOutTween:Play()
		task.wait(0.12)
	end

	if self._dialogueLabel then
		self._dialogueLabel.TextTransparency = 1
		self._dialogueLabel.Text = ""
	end
	self:_typeText(line.text)
end

function CutsceneController:_typeText(text: string)
	if self._typingThread and coroutine.status(self._typingThread) == "suspended" then
		task.cancel(self._typingThread)
	end

	self._typingThread = task.spawn(function()
		local label = self._dialogueLabel
		if not label then
			return
		end

		-- 텍스트 페이드인 (타이핑 시작 시)
		label.TextTransparency = 1
		TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()

		local bytes = string.len(text)
		for i = 1, bytes do
			label.Text = string.sub(text, 1, i)
			local b = string.byte(text, i)
			-- 구두점 후 자연스러운 호흡감 (ASCII 범위만 체크)
			if b == 33 or b == 63 then        -- ! ?
				task.wait(0.18)
			elseif b == 44 then               -- ,
				task.wait(0.08)
			elseif b == 46 then               -- .
				task.wait(0.12)
			else
				task.wait(0.03)
			end
		end
		self._typingThread = nil
	end)
end

function CutsceneController:_onNextPressed()
	if self._typingThread then
		if coroutine.status(self._typingThread) ~= "dead" then
			task.cancel(self._typingThread)
			self._typingThread = nil
		end
		local line = self._currentLines[self._currentLineIndex]
		if self._dialogueLabel and line then
			self._dialogueLabel.Text = line.text
		end
		return
	end
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
	local pendingSkill = self._pendingSkillTutorial
	if pendingSkill and not self._shownSkillTutorials[pendingSkill] then
		self._pendingSkillTutorial = nil
		self._shownSkillTutorials[pendingSkill] = true
		task.delay(0.6, function()
			self:_showSkillTutorial(pendingSkill)
		end)
	end
end

-- ==================== 초상화 밥 애니메이션 ====================

function CutsceneController:_startPortraitBob()
	if self._portraitBobThread then
		task.cancel(self._portraitBobThread)
		self._portraitBobThread = nil
	end

	local portraitFrame = self._portraitFrame
	if not portraitFrame then
		return
	end

	self._portraitBobThread = task.spawn(function()
		local t = 0
		while self._isPlaying and portraitFrame.Parent do
			t += 1 / 30
			portraitFrame.Position = UDim2.new(0, 12, 0, -36 + math.sin(t * 4) * 3)
			task.wait(1 / 30)
		end
		-- 루프 종료 시 원래 위치로 복원
		if portraitFrame.Parent then
			portraitFrame.Position = UDim2.new(0, 12, 0, -36)
		end
	end)
end

function CutsceneController:_stopPortraitBob()
	if self._portraitBobThread then
		task.cancel(self._portraitBobThread)
		self._portraitBobThread = nil
	end
	if self._portraitFrame then
		self._portraitFrame.Position = UDim2.new(0, 12, 0, -36)
	end
end

-- ==================== 초상화 업데이트 ====================

function CutsceneController:_updatePortrait(profile: { id: string, name: string, emoji: string, role: string, bgColor: Color3, textColor: Color3 })
	local portraitFrame = self._portraitFrame
	local portraitEmoji = self._portraitEmoji
	if not portraitFrame or not portraitEmoji then
		return
	end

	-- 배경색 트윈
	TweenService:Create(portraitFrame, TweenInfo.new(0.2), {
		BackgroundColor3 = profile.bgColor,
	}):Play()

	-- 이모지 변경 + 팝 애니메이션
	portraitEmoji.Text = profile.emoji
	portraitFrame.Size = UDim2.new(0, 50, 0, 50)
	TweenService:Create(portraitFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 60, 0, 60),
	}):Play()

	-- 테두리 색상 (역할별)
	local stroke = portraitFrame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = ROLE_COLORS[profile.role] or Color3.fromRGB(200, 200, 200)
	end
end

function CutsceneController:_updateBorderColor(role: string)
	local topBorder = self._topBorder
	if not topBorder then
		return
	end
	local color = ROLE_COLORS[role] or Color3.fromRGB(100, 180, 255)
	TweenService:Create(topBorder, TweenInfo.new(0.2), {
		BackgroundColor3 = color,
	}):Play()
end

-- ==================== 이펙트 ====================

-- 보스 등장 시 패널 좌우 흔들림
function CutsceneController:_shakePanel()
	local panel = self._panel
	if not panel then
		return
	end

	local originalPos = UDim2.new(0, 0, 0.72, 0)
	if self._topBorder then
		self._topBorder.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
	end

	task.spawn(function()
		for i = 1, 3 do
			local offsetX = if i % 2 == 1 then 6 else -6
			TweenService:Create(panel, TweenInfo.new(0.06), {
				Position = UDim2.new(0, offsetX, 0.72, 0),
			}):Play()
			task.wait(0.06)
		end
		TweenService:Create(panel, TweenInfo.new(0.06), {
			Position = originalPos,
		}):Play()
	end)
end

-- 빨간 플래시 이펙트
function CutsceneController:_flashPanel()
	local panel = self._panel
	if not panel then
		return
	end

	local flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.new(1, 0, 1, 0)
	flashFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	flashFrame.BackgroundTransparency = 0.5
	flashFrame.ZIndex = 10
	flashFrame.BorderSizePixel = 0
	flashFrame.Parent = panel

	TweenService:Create(flashFrame, TweenInfo.new(0.4), {
		BackgroundTransparency = 1,
	}):Play()

	task.delay(0.5, function()
		if flashFrame.Parent then
			flashFrame:Destroy()
		end
	end)
end

-- 승리 황금 파티클 이펙트
function CutsceneController:_showVictoryParticle()
	local gui = self._gui
	if not gui then
		return
	end

	for _ = 1, 8 do
		local particle = Instance.new("Frame")
		particle.Size = UDim2.new(0, math.random(8, 16), 0, math.random(8, 16))
		particle.Position = UDim2.new(0.5, 0, 0.75, 0)
		particle.BackgroundColor3 = Color3.fromRGB(255, math.random(180, 230), math.random(0, 80))
		particle.Rotation = math.random(0, 360)
		particle.ZIndex = 15
		particle.BorderSizePixel = 0
		particle.Parent = gui

		local cornerR = Instance.new("UICorner")
		cornerR.CornerRadius = UDim.new(0, 4)
		cornerR.Parent = particle

		local targetX = 0.5 + (math.random() - 0.5) * 1.2
		local targetY = 0.3 + math.random() * 0.5

		TweenService:Create(particle, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(targetX, 0, targetY, 0),
			BackgroundTransparency = 1,
			Rotation = math.random(180, 720),
		}):Play()

		task.delay(1.3, function()
			if particle.Parent then
				particle:Destroy()
			end
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

	if self._onPlayStart then
		self._onPlayStart()
	end

	gui.Enabled = true

	-- 딤 오버레이 페이드인
	if self._dimOverlay then
		self._dimOverlay.BackgroundTransparency = 1
		TweenService:Create(self._dimOverlay, TweenInfo.new(0.4), {
			BackgroundTransparency = 0.5,
		}):Play()
	end

	panel.Position = UDim2.new(0, 0, 1, 0)
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0.72, 0),
	}):Play()

	self:_startPortraitBob()
end

function CutsceneController:_hide()
	local gui = self._gui
	local panel = self._panel
	if not gui or not panel then
		return
	end

	if self._onPlayEnd then
		self._onPlayEnd()
	end

	self:_stopPortraitBob()

	-- 딤 오버레이 페이드아웃 + 틴트 초기화
	if self._dimOverlay then
		TweenService:Create(self._dimOverlay, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		}):Play()
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
	tutGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	tutGui.Parent = playerGui

	local dimBg = Instance.new("TextButton")
	dimBg.Size = UDim2.new(1, 0, 1, 0)
	dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimBg.BackgroundTransparency = 0.5
	dimBg.Text = ""
	dimBg.AutoButtonColor = false
	dimBg.Parent = tutGui

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

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -20, 0, 24)
	nameLabel.Position = UDim2.new(0, 10, 0, 88)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(210, 170, 255)
	nameLabel.TextSize = 18
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Text = info.name
	nameLabel.Parent = card

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

	local tipLabel = Instance.new("TextLabel")
	tipLabel.Size = UDim2.new(1, -24, 0, 22)
	tipLabel.Position = UDim2.new(0, 12, 0, 150)
	tipLabel.BackgroundTransparency = 1
	tipLabel.TextColor3 = Color3.fromRGB(160, 200, 140)
	tipLabel.TextSize = 11
	tipLabel.Font = Enum.Font.Gotham
	tipLabel.Text = info.tip
	tipLabel.Parent = card

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
	card.Position = UDim2.new(0.5, -150, 0.5, -58)
	card.BackgroundTransparency = 1
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -150, 0.5, -98),
		BackgroundTransparency = 0,
	}):Play()

	local function closeTutorial()
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -150, 0.5, -68),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.25, function()
			if tutGui.Parent then
				tutGui:Destroy()
			end
		end)
	end

	dimBg.MouseButton1Click:Connect(closeTutorial)
	dismissBtn.MouseButton1Click:Connect(closeTutorial)

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

-- ==================== 챕터 클리어 축하 (4단계 강화 연출) ====================

-- 황금 파티클 스폰 헬퍼
local function _spawnGoldParticles(parent: Instance, count: number)
	for i = 1, count do
		task.delay(i * 0.03, function()
			if not (parent :: any).Parent then
				return
			end
			local p = Instance.new("Frame")
			p.Size = UDim2.new(0, math.random(6, 14), 0, math.random(6, 14))
			local startX = math.random()
			p.Position = UDim2.new(startX, 0, -0.05, 0)
			p.BackgroundColor3 = Color3.fromRGB(255, math.random(180, 240), math.random(0, 100))
			p.Rotation = math.random(0, 360)
			p.ZIndex = 5
			p.BorderSizePixel = 0
			p.Parent = parent

			local pCorner = Instance.new("UICorner")
			pCorner.CornerRadius = UDim.new(0, 3)
			pCorner.Parent = p

			TweenService:Create(p, TweenInfo.new(
				1.5 + math.random() * 1.0,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			), {
				Position = UDim2.new(startX + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
				Rotation = math.random(360, 1080),
				BackgroundTransparency = 0.5,
			}):Play()

			task.delay(2.5, function()
				if p.Parent then
					p:Destroy()
				end
			end)
		end)
	end
end

--[[
	ShowChapterClearCelebration
	4단계 챕터 클리어 연출:
	  Stage 1 (0~0.5s)  - 전체화면 골드 플래시
	  Stage 2 (0.5~2.5s) - "CHAPTER N CLEAR!" 대형 텍스트 + 파티클
	  Stage 3 (2.5s~)   - 기존 컷씬 대화창 (clear 컷씬은 QueueCutscene으로 처리됨)
	  Stage 4 (3.5~4.5s) - 다음 챕터 예고 텍스트 fade in/out
--]]
function CutsceneController:ShowChapterClearCelebration(chapterNum: number, chapterName: string)
	local playerGui = self._player:WaitForChild("PlayerGui")

	-- 다음 챕터 정보 조회
	local nextChapterId = "ch" .. tostring(chapterNum + 1)
	local nextChapter = ScenarioConstants.CHAPTER_MAP[nextChapterId]
	local nextChapterName: string? = if nextChapter then nextChapter.name else nil

	local celebGui = Instance.new("ScreenGui")
	celebGui.Name = "ChapterClearCelebration"
	celebGui.ResetOnSpawn = false
	celebGui.DisplayOrder = 25
	celebGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	celebGui.Parent = playerGui

	-- ===== Stage 1: 전체화면 골드 플래시 (0 ~ 0.5초) =====
	local goldFlash = Instance.new("Frame")
	goldFlash.Name = "GoldFlash"
	goldFlash.Size = UDim2.new(1, 0, 1, 0)
	goldFlash.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	goldFlash.BackgroundTransparency = 0
	goldFlash.BorderSizePixel = 0
	goldFlash.ZIndex = 10
	goldFlash.Parent = celebGui

	TweenService:Create(goldFlash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()

	-- ===== Stage 2: 딤 배경 + "CHAPTER N CLEAR!" 대형 텍스트 (0.5초부터) =====
	local dimBg = Instance.new("Frame")
	dimBg.Name = "DimBg"
	dimBg.Size = UDim2.new(1, 0, 1, 0)
	dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimBg.BackgroundTransparency = 1
	dimBg.BorderSizePixel = 0
	dimBg.ZIndex = 1
	dimBg.Parent = celebGui

	task.delay(0.4, function()
		if not celebGui.Parent then
			return
		end

		TweenService:Create(dimBg, TweenInfo.new(0.3), {
			BackgroundTransparency = 0.55,
		}):Play()

		-- CHAPTER N 텍스트 (위에서 솟아오름)
		local chapterLabel = Instance.new("TextLabel")
		chapterLabel.Name = "ChapterLabel"
		chapterLabel.Size = UDim2.new(0, 400, 0, 80)
		chapterLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		chapterLabel.Position = UDim2.new(0.5, 0, 0.32, 0)
		chapterLabel.BackgroundTransparency = 1
		chapterLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		chapterLabel.TextSize = 44
		chapterLabel.Font = Enum.Font.GothamBlack
		chapterLabel.Text = `CHAPTER {chapterNum}`
		chapterLabel.TextStrokeTransparency = 0.4
		chapterLabel.TextStrokeColor3 = Color3.fromRGB(180, 120, 0)
		chapterLabel.TextTransparency = 1
		chapterLabel.ZIndex = 6
		chapterLabel.Parent = celebGui

		local uiScale = Instance.new("UIScale")
		uiScale.Scale = 0.4
		uiScale.Parent = chapterLabel

		-- 스케일 팝 + 페이드인 (위로 솟아오르는 연출)
		chapterLabel.Position = UDim2.new(0.5, 0, 0.40, 0)
		TweenService:Create(chapterLabel, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.32, 0),
			TextTransparency = 0,
		}):Play()
		TweenService:Create(uiScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()

		-- "CLEAR! ✨" 텍스트 (약간 딜레이)
		local clearLabel = Instance.new("TextLabel")
		clearLabel.Name = "ClearLabel"
		clearLabel.Size = UDim2.new(0, 400, 0, 70)
		clearLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		clearLabel.Position = UDim2.new(0.5, 0, 0.46, 0)
		clearLabel.BackgroundTransparency = 1
		clearLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		clearLabel.TextSize = 52
		clearLabel.Font = Enum.Font.GothamBlack
		clearLabel.Text = "CLEAR! ✨"
		clearLabel.TextStrokeTransparency = 0.5
		clearLabel.TextStrokeColor3 = Color3.fromRGB(255, 215, 0)
		clearLabel.TextTransparency = 1
		clearLabel.ZIndex = 6
		clearLabel.Parent = celebGui

		local clearScale = Instance.new("UIScale")
		clearScale.Scale = 0.3
		clearScale.Parent = clearLabel

		task.delay(0.2, function()
			if not celebGui.Parent then
				return
			end
			clearLabel.Position = UDim2.new(0.5, 0, 0.54, 0)
			TweenService:Create(clearLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 0.46, 0),
				TextTransparency = 0,
			}):Play()
			TweenService:Create(clearScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1.0,
			}):Play()
		end)

		-- 챕터 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.new(0, 380, 0, 30)
		nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		nameLabel.Position = UDim2.new(0.5, 0, 0.57, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(220, 235, 255)
		nameLabel.TextSize = 20
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = chapterName
		nameLabel.TextTransparency = 1
		nameLabel.ZIndex = 6
		nameLabel.Parent = celebGui

		task.delay(0.45, function()
			if not celebGui.Parent then
				return
			end
			TweenService:Create(nameLabel, TweenInfo.new(0.3), {
				TextTransparency = 0,
			}):Play()
		end)

		-- 황금 파티클 (화면 위에서 낙하)
		task.delay(0.1, function()
			if celebGui.Parent then
				_spawnGoldParticles(celebGui, 28)
			end
		end)

		-- ===== Stage 4: 다음 챕터 예고 텍스트 (3.2초부터) =====
		if nextChapterName then
			local previewBg = Instance.new("Frame")
			previewBg.Name = "NextChapterPreview"
			previewBg.Size = UDim2.new(0, 340, 0, 40)
			previewBg.AnchorPoint = Vector2.new(0.5, 0.5)
			previewBg.Position = UDim2.new(0.5, 0, 0.82, 0)
			previewBg.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
			previewBg.BackgroundTransparency = 0.3
			previewBg.BorderSizePixel = 0
			previewBg.ZIndex = 6
			previewBg.Parent = celebGui

			local previewCorner = Instance.new("UICorner")
			previewCorner.CornerRadius = UDim.new(0, 10)
			previewCorner.Parent = previewBg

			local previewLabel = Instance.new("TextLabel")
			previewLabel.Name = "NextChapterLabel"
			previewLabel.Size = UDim2.new(1, -16, 1, 0)
			previewLabel.Position = UDim2.new(0, 8, 0, 0)
			previewLabel.BackgroundTransparency = 1
			previewLabel.TextColor3 = Color3.fromRGB(255, 230, 140)
			previewLabel.TextSize = 15
			previewLabel.Font = Enum.Font.GothamBold
			previewLabel.Text = `다음 이야기: {nextChapterName} →`
			previewLabel.TextTransparency = 1
			previewLabel.ZIndex = 7
			previewLabel.Parent = previewBg

			-- Stage 4 시작 (3.2초 후 fade in)
			previewBg.BackgroundTransparency = 1
			task.delay(3.2, function()
				if not celebGui.Parent then
					return
				end
				TweenService:Create(previewBg, TweenInfo.new(0.4), {
					BackgroundTransparency = 0.3,
				}):Play()
				TweenService:Create(previewLabel, TweenInfo.new(0.4), {
					TextTransparency = 0,
				}):Play()
				-- 1초 표시 후 fade out
				task.delay(1.0, function()
					if not celebGui.Parent then
						return
					end
					TweenService:Create(previewBg, TweenInfo.new(0.4), {
						BackgroundTransparency = 1,
					}):Play()
					TweenService:Create(previewLabel, TweenInfo.new(0.4), {
						TextTransparency = 1,
					}):Play()
				end)
			end)
		end

		-- 전체 자동 닫기 (4.8초 후)
		task.delay(4.0, function()
			if not celebGui.Parent then
				return
			end
			TweenService:Create(dimBg, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()

			local function fadeOutLabel(lbl: TextLabel?)
				if lbl and lbl.Parent then
					TweenService:Create(lbl, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
				end
			end
			fadeOutLabel(celebGui:FindFirstChild("ChapterLabel") :: TextLabel?)
			fadeOutLabel(celebGui:FindFirstChild("ClearLabel") :: TextLabel?)
			fadeOutLabel(celebGui:FindFirstChild("NameLabel") :: TextLabel?)

			task.delay(0.6, function()
				if celebGui.Parent then
					celebGui:Destroy()
				end
			end)
		end)
	end)
end

return CutsceneController

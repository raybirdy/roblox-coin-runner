--!strict
-- WorldMapController
-- 10챕터 월드맵 시각화: 노드 상태, 해방 애니메이션, 로비 버튼

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ScenarioConstants = require(ReplicatedStorage.Shared.Constants.ScenarioConstants)

local WorldMapController = {}
WorldMapController.__index = WorldMapController

-- 노드 배치: 지그재그 (CH1 하단 → CH10 상단)
local NODE_POSITIONS = {
	ch1  = Vector2.new(0.5,  0.93),
	ch2  = Vector2.new(0.75, 0.83),
	ch3  = Vector2.new(0.25, 0.73),
	ch4  = Vector2.new(0.75, 0.63),
	ch5  = Vector2.new(0.25, 0.53),
	ch6  = Vector2.new(0.75, 0.43),
	ch7  = Vector2.new(0.25, 0.33),
	ch8  = Vector2.new(0.75, 0.23),
	ch9  = Vector2.new(0.25, 0.13),
	ch10 = Vector2.new(0.5,  0.05),
}

-- 챕터 순서 (연결선 그리기용)
local CHAPTER_ORDER = { "ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "ch8", "ch9", "ch10" }

local NODE_STATES = {
	locked = {
		bgColor     = Color3.fromRGB(40, 40, 50),
		strokeColor = Color3.fromRGB(60, 60, 70),
		textAlpha   = 0.5,
	},
	unlocked = {
		bgColor     = Color3.fromRGB(30, 60, 140),
		strokeColor = Color3.fromRGB(80, 140, 255),
		textAlpha   = 0,
	},
	current = {
		bgColor     = Color3.fromRGB(100, 80, 10),
		strokeColor = Color3.fromRGB(255, 220, 50),
		textAlpha   = 0,
	},
	completed = {
		bgColor     = Color3.fromRGB(30, 100, 50),
		strokeColor = Color3.fromRGB(80, 220, 100),
		textAlpha   = 0,
	},
}

export type WorldMapController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_connections: { RBXScriptConnection },
		_gui: ScreenGui?,
		_popupGui: ScreenGui?,
		_mapFrame: Frame?,
		_nodeFrames: { [string]: Frame },
		_isOpen: boolean,
		_scenarioData: any?,
		_lobbyMapButton: TextButton?,
		_pulseThreads: { [string]: thread },
	},
	WorldMapController
))

function WorldMapController.new(player: Player): WorldMapController
	local self = setmetatable({
		_player = player,
		_connections = {},
		_gui = nil,
		_popupGui = nil,
		_mapFrame = nil,
		_nodeFrames = {},
		_isOpen = false,
		_scenarioData = nil,
		_lobbyMapButton = nil,
		_pulseThreads = {},
	}, WorldMapController)

	self:_createGui()
	self:_setupEventHandlers()

	return self
end

-- ==================== GUI 생성 ====================

function WorldMapController:_createGui()
	local playerGui = self._player:WaitForChild("PlayerGui")

	-- 로비 GUI (버튼만 포함)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WorldMapLobbyGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 17
	gui.Parent = playerGui
	self._gui = gui

	-- 🗺️ 로비 버튼 (📖 버튼 오른쪽)
	local mapBtn = Instance.new("TextButton")
	mapBtn.Name = "WorldMapButton"
	mapBtn.Size = UDim2.new(0, 48, 0, 48)
	mapBtn.Position = UDim2.new(0, 284, 0, 16)
	mapBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 50)
	mapBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	mapBtn.TextSize = 22
	mapBtn.Font = Enum.Font.GothamBold
	mapBtn.Text = "🗺️"
	mapBtn.Parent = gui
	self._lobbyMapButton = mapBtn

	local mapBtnCorner = Instance.new("UICorner")
	mapBtnCorner.CornerRadius = UDim.new(0, 8)
	mapBtnCorner.Parent = mapBtn

	local mapBtnStroke = Instance.new("UIStroke")
	mapBtnStroke.Color = Color3.fromRGB(80, 200, 100)
	mapBtnStroke.Thickness = 2
	mapBtnStroke.Parent = mapBtn

	mapBtn.MouseButton1Click:Connect(function()
		if self._isOpen then
			self:Close()
		else
			self:Open()
		end
	end)

	-- 팝업 GUI (별도)
	local popupGui = Instance.new("ScreenGui")
	popupGui.Name = "WorldMapPopupGui"
	popupGui.ResetOnSpawn = false
	popupGui.DisplayOrder = 19
	popupGui.Enabled = false
	popupGui.Parent = playerGui
	self._popupGui = popupGui

	-- 딤 배경
	local dimBg = Instance.new("TextButton")
	dimBg.Name = "DimBg"
	dimBg.Size = UDim2.new(1, 0, 1, 0)
	dimBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dimBg.BackgroundTransparency = 0.4
	dimBg.Text = ""
	dimBg.AutoButtonColor = false
	dimBg.Parent = popupGui

	dimBg.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- 맵 프레임
	local mapFrame = Instance.new("Frame")
	mapFrame.Name = "MapFrame"
	mapFrame.Size = UDim2.new(0, 360, 0, 480)
	mapFrame.Position = UDim2.new(0.5, -180, 0.5, -240)
	mapFrame.BackgroundColor3 = Color3.fromRGB(12, 18, 30)
	mapFrame.BorderSizePixel = 0
	mapFrame.Parent = popupGui
	self._mapFrame = mapFrame

	local mapCorner = Instance.new("UICorner")
	mapCorner.CornerRadius = UDim.new(0, 14)
	mapCorner.Parent = mapFrame

	local mapStroke = Instance.new("UIStroke")
	mapStroke.Color = Color3.fromRGB(80, 120, 200)
	mapStroke.Thickness = 2
	mapStroke.Parent = mapFrame

	-- 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -50, 0, 36)
	titleLabel.Position = UDim2.new(0, 16, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(120, 200, 130)
	titleLabel.TextSize = 18
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "🗺️ WORLD MAP"
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = mapFrame

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -40, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
	closeBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Text = "✕"
	closeBtn.Parent = mapFrame

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- 맵 캔버스 (노드/연결선 부모)
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.Size = UDim2.new(1, 0, 1, -50)
	canvas.Position = UDim2.new(0, 0, 0, 50)
	canvas.BackgroundTransparency = 1
	canvas.Parent = mapFrame

	-- 연결선 그리기 (노드보다 먼저 생성해서 노드 뒤에 오도록)
	self:_buildConnectionLines(canvas)

	-- 노드 생성
	self:_buildNodes(canvas)
end

function WorldMapController:_buildConnectionLines(canvas: Frame)
	local canvasSize = Vector2.new(360, 430)

	for i = 1, #CHAPTER_ORDER - 1 do
		local fromId = CHAPTER_ORDER[i]
		local toId = CHAPTER_ORDER[i + 1]
		local fromRatio = NODE_POSITIONS[fromId]
		local toRatio = NODE_POSITIONS[toId]

		local fromPx = Vector2.new(fromRatio.X * canvasSize.X, fromRatio.Y * canvasSize.Y)
		local toPx = Vector2.new(toRatio.X * canvasSize.X, toRatio.Y * canvasSize.Y)

		local dx = toPx.X - fromPx.X
		local dy = toPx.Y - fromPx.Y
		local dist = math.sqrt(dx * dx + dy * dy)
		local angle = math.deg(math.atan2(dy, dx))

		local line = Instance.new("Frame")
		line.Name = `Line_{fromId}_{toId}`
		line.Size = UDim2.new(0, dist, 0, 3)
		line.Position = UDim2.new(0, fromPx.X, 0, fromPx.Y)
		line.AnchorPoint = Vector2.new(0, 0.5)
		line.Rotation = angle
		line.BackgroundColor3 = Color3.fromRGB(40, 60, 100)
		line.BorderSizePixel = 0
		line.ZIndex = 1
		line.Parent = canvas
	end
end

function WorldMapController:_buildNodes(canvas: Frame)
	local chapters = ScenarioConstants.CHAPTERS
	-- chapterId → chapter 데이터 맵 구성
	local chapterMap: { [string]: typeof(ScenarioConstants.CHAPTERS[1]) } = {}
	for _, ch in chapters do
		chapterMap[ch.id] = ch
	end

	for _, chId in CHAPTER_ORDER do
		local chapter = chapterMap[chId]
		if not chapter then
			continue
		end

		local ratio = NODE_POSITIONS[chId]
		local nodeFrame = Instance.new("Frame")
		nodeFrame.Name = `Node_{chId}`
		nodeFrame.Size = UDim2.new(0, 52, 0, 52)
		nodeFrame.Position = UDim2.new(ratio.X, -26, ratio.Y, -26)
		nodeFrame.BackgroundColor3 = NODE_STATES.locked.bgColor
		nodeFrame.BorderSizePixel = 0
		nodeFrame.ZIndex = 2
		nodeFrame.Parent = canvas
		self._nodeFrames[chId] = nodeFrame

		local nodeCorner = Instance.new("UICorner")
		nodeCorner.CornerRadius = UDim.new(1, 0)
		nodeCorner.Parent = nodeFrame

		local nodeStroke = Instance.new("UIStroke")
		nodeStroke.Color = NODE_STATES.locked.strokeColor
		nodeStroke.Thickness = 2
		nodeStroke.Parent = nodeFrame

		-- 테마 이모지
		local themeLabel = Instance.new("TextLabel")
		themeLabel.Name = "ThemeEmoji"
		themeLabel.Size = UDim2.new(1, 0, 0.6, 0)
		themeLabel.Position = UDim2.new(0, 0, 0, 0)
		themeLabel.BackgroundTransparency = 1
		themeLabel.Text = chapter.theme
		themeLabel.TextSize = 20
		themeLabel.Font = Enum.Font.GothamBold
		themeLabel.TextTransparency = NODE_STATES.locked.textAlpha
		themeLabel.ZIndex = 3
		themeLabel.Parent = nodeFrame

		-- 챕터 번호
		local numLabel = Instance.new("TextLabel")
		numLabel.Name = "ChapterNum"
		numLabel.Size = UDim2.new(1, 0, 0.4, 0)
		numLabel.Position = UDim2.new(0, 0, 0.6, 0)
		numLabel.BackgroundTransparency = 1
		numLabel.Text = `CH.{chapter.num}`
		numLabel.TextSize = 10
		numLabel.Font = Enum.Font.GothamBold
		numLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
		numLabel.TextTransparency = NODE_STATES.locked.textAlpha
		numLabel.ZIndex = 3
		numLabel.Parent = nodeFrame

		-- 완료 별 뱃지 (기본 숨김)
		local starBadge = Instance.new("TextLabel")
		starBadge.Name = "StarBadge"
		starBadge.Size = UDim2.new(0, 20, 0, 20)
		starBadge.Position = UDim2.new(1, -8, 0, -8)
		starBadge.BackgroundTransparency = 1
		starBadge.Text = "⭐"
		starBadge.TextSize = 14
		starBadge.Font = Enum.Font.GothamBold
		starBadge.Visible = false
		starBadge.ZIndex = 4
		starBadge.Parent = nodeFrame

		-- 챕터 이름 레이블 (노드 아래)
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "NameLabel"
		nameLbl.Size = UDim2.new(0, 80, 0, 18)
		nameLbl.Position = UDim2.new(0.5, -40, 1, 2)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = chapter.name
		nameLbl.TextSize = 9
		nameLbl.Font = Enum.Font.Gotham
		nameLbl.TextColor3 = Color3.fromRGB(160, 180, 210)
		nameLbl.TextWrapped = true
		nameLbl.ZIndex = 3
		nameLbl.Parent = nodeFrame
	end
end

-- ==================== 이벤트 핸들러 ====================

function WorldMapController:_setupEventHandlers()
	-- 퀘스트/챕터 데이터 업데이트 시 맵 갱신
	local conn1 = RemoteEvents.QuestProgressUpdate.OnClientEvent:Connect(function(data)
		if self._scenarioData then
			self._scenarioData.completedChapters = data.completedChapters
			self:_refreshNodeStates()
		end
	end)
	table.insert(self._connections, conn1)

	-- 챕터 완료 시 해방 애니메이션 (보스 런 준비 알림은 제외)
	local conn2 = RemoteEvents.ChapterUnlocked.OnClientEvent:Connect(function(data)
		if data.chapterId and not data.isOpening and not data.bossRunReady then
			self:PlayLiberationAnimation(data.chapterId)
		end
	end)
	table.insert(self._connections, conn2)
end

-- ==================== 데이터 업데이트 ====================

function WorldMapController:UpdateFromScenarioData(data: any)
	self._scenarioData = data
	self:_refreshNodeStates()
end

function WorldMapController:_refreshNodeStates()
	local data = self._scenarioData
	if not data then
		return
	end

	local completedSet: { [string]: boolean } = {}
	for _, chId in data.completedChapters or {} do
		completedSet[chId] = true
	end

	-- 완료/해금 챕터 파악
	local chapters = data.chapters or {}
	local chapterMap: { [string]: any } = {}
	for _, ch in chapters do
		chapterMap[ch.id] = ch
	end

	-- 현재 진행 중 챕터 (해금됐으나 미완료인 첫 번째 챕터)
	local currentChapterId: string? = nil
	for _, chId in CHAPTER_ORDER do
		local ch = chapterMap[chId]
		if ch and ch.isUnlocked and not ch.isCompleted then
			currentChapterId = chId
			break
		end
	end

	for _, chId in CHAPTER_ORDER do
		local nodeFrame = self._nodeFrames[chId]
		if not nodeFrame then
			continue
		end

		local ch = chapterMap[chId]
		local stateName = "locked"
		if ch then
			if ch.isCompleted then
				stateName = "completed"
			elseif chId == currentChapterId then
				stateName = "current"
			elseif ch.isUnlocked then
				stateName = "unlocked"
			end
		end

		local state = NODE_STATES[stateName]

		TweenService:Create(nodeFrame, TweenInfo.new(0.3), {
			BackgroundColor3 = state.bgColor,
		}):Play()

		local stroke = nodeFrame:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.3), {
				Color = state.strokeColor,
			}):Play()
		end

		local themeLabel = nodeFrame:FindFirstChild("ThemeEmoji") :: TextLabel?
		local numLabel = nodeFrame:FindFirstChild("ChapterNum") :: TextLabel?
		if themeLabel then
			themeLabel.TextTransparency = state.textAlpha
		end
		if numLabel then
			numLabel.TextTransparency = state.textAlpha
		end

		local starBadge = nodeFrame:FindFirstChild("StarBadge") :: TextLabel?
		if starBadge then
			starBadge.Visible = stateName == "completed"
		end

		-- 현재 챕터 펄스
		if stateName == "current" then
			self:_pulseNode(chId, nodeFrame)
		else
			local thread = self._pulseThreads[chId]
			if thread then
				task.cancel(thread)
				self._pulseThreads[chId] = nil
			end
		end
	end
end

function WorldMapController:_pulseNode(chId: string, nodeFrame: Frame)
	-- 기존 펄스 스레드 취소
	if self._pulseThreads[chId] then
		task.cancel(self._pulseThreads[chId])
	end

	self._pulseThreads[chId] = task.spawn(function()
		local stroke = nodeFrame:FindFirstChildOfClass("UIStroke")
		if not stroke then
			return
		end
		while nodeFrame.Parent do
			TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Color = Color3.fromRGB(255, 255, 100),
				Thickness = 4,
			}):Play()
			task.wait(0.8)
			if not nodeFrame.Parent then
				break
			end
			TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Color = Color3.fromRGB(200, 180, 50),
				Thickness = 2,
			}):Play()
			task.wait(0.8)
		end
	end)
end

-- ==================== 해방 애니메이션 ====================

function WorldMapController:PlayLiberationAnimation(chapterId: string)
	local nodeFrame = self._nodeFrames[chapterId]
	if not nodeFrame then
		return
	end

	-- 1. 노드 색상 → 완료(초록)
	TweenService:Create(nodeFrame, TweenInfo.new(0.5), {
		BackgroundColor3 = NODE_STATES.completed.bgColor,
	}):Play()

	local stroke = nodeFrame:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.5), {
			Color = NODE_STATES.completed.strokeColor,
		}):Play()
	end

	-- 2. 빛 방사 이펙트 (중앙에서 퍼지는 원)
	local lightRing = Instance.new("Frame")
	lightRing.Size = UDim2.new(0, 10, 0, 10)
	lightRing.Position = UDim2.new(0.5, -5, 0.5, -5)
	lightRing.BackgroundColor3 = Color3.fromRGB(200, 255, 200)
	lightRing.BackgroundTransparency = 0
	lightRing.BorderSizePixel = 0
	lightRing.ZIndex = 5
	lightRing.Parent = nodeFrame

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = lightRing

	TweenService:Create(lightRing, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 120, 0, 120),
		Position = UDim2.new(0.5, -60, 0.5, -60),
		BackgroundTransparency = 1,
	}):Play()

	task.delay(0.9, function()
		if lightRing.Parent then
			lightRing:Destroy()
		end
	end)

	-- 3. 별 뱃지 표시
	local starBadge = nodeFrame:FindFirstChild("StarBadge") :: TextLabel?
	if starBadge then
		starBadge.Visible = true
	end

	-- 4. 펄스 스레드 종료
	local thread = self._pulseThreads[chapterId]
	if thread then
		task.cancel(thread)
		self._pulseThreads[chapterId] = nil
	end
end

-- ==================== 열기/닫기 ====================

function WorldMapController:Open()
	local popupGui = self._popupGui
	local mapFrame = self._mapFrame
	if not popupGui or not mapFrame then
		return
	end

	self._isOpen = true
	popupGui.Enabled = true

	mapFrame.Position = UDim2.new(0.5, -180, 0.5, -240 + 40)
	mapFrame.BackgroundTransparency = 1
	TweenService:Create(mapFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -180, 0.5, -240),
		BackgroundTransparency = 0,
	}):Play()
end

function WorldMapController:Close()
	local popupGui = self._popupGui
	local mapFrame = self._mapFrame
	if not popupGui or not mapFrame then
		return
	end

	self._isOpen = false

	TweenService:Create(mapFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, -180, 0.5, -200),
		BackgroundTransparency = 1,
	}):Play()

	task.delay(0.25, function()
		popupGui.Enabled = false
	end)
end

-- ==================== 로비/게임 전환 ====================

function WorldMapController:ShowInLobby()
	if self._gui then
		self._gui.Enabled = true
	end
end

function WorldMapController:HideForGame()
	if self._gui then
		self._gui.Enabled = false
	end
	if self._isOpen then
		self:Close()
	end
end

return WorldMapController

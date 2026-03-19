--!strict
-- Objective HUD Controller
-- 게임 중 런 목표 3개를 화면 좌측 하단에 표시

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local ObjectiveHudController = {}
ObjectiveHudController.__index = ObjectiveHudController

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

export type ObjectiveHudController = typeof(setmetatable(
	{} :: {
		_screenGui: ScreenGui?,
		_hudFrame: Frame?,
		_iconBtn: TextButton?,
		_rows: { Frame },
		_rerollButtons: { TextButton },
		_targets: { number },
		_connections: { RBXScriptConnection },
		_rerollEnabled: boolean,
		_isTweening: boolean,
		_collapseTask: thread?,
	},
	ObjectiveHudController
))

function ObjectiveHudController.new(): ObjectiveHudController
	local self = setmetatable({
		_screenGui = nil,
		_hudFrame = nil,
		_iconBtn = nil,
		_rows = {},
		_rerollButtons = {},
		_targets = {},
		_connections = {},
		_rerollEnabled = true,
		_isTweening = false,
		_collapseTask = nil,
	}, ObjectiveHudController)

	self:_createUI()
	self:_setupEventHandlers()

	return self
end

function ObjectiveHudController:_createUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ObjectiveHUD"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 7
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.Parent = playerGui
	self._screenGui = screenGui

	-- Main frame (left side, above slide button)
	-- Slide button: size=120, margin=34 → top edge at Y=1,-154 from bottom
	-- We must ensure: hudBottom < -154, i.e., -(yOffset) + hudH < -154 → yOffset > hudH + 154 + gap
	local hudW = math.max(160, ResponsiveUtil.scaledOffset(180))
	local hudH = math.max(100, ResponsiveUtil.scaledOffset(112))
	local SLIDE_BTN_TOP = 154 -- TOUCH_BUTTON_SIZE(120) + btnMargin(34)
	local HUD_GAP = 14
	local minYOffset = hudH + SLIDE_BTN_TOP + HUD_GAP -- e.g. 100+154+14 = 268
	local hudFrame = Instance.new("Frame")
	hudFrame.Name = "HudFrame"
	hudFrame.Size = UDim2.new(0, hudW, 0, hudH)
	hudFrame.Position = UDim2.new(0, ResponsiveUtil.scaledOffset(10), 1, -math.max(minYOffset, ResponsiveUtil.scaledOffset(280)))
	hudFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	hudFrame.BackgroundTransparency = 0.25
	hudFrame.Visible = false
	hudFrame.Parent = screenGui
	self._hudFrame = hudFrame

	local hudCorner = Instance.new("UICorner")
	hudCorner.CornerRadius = UDim.new(0, 8)
	hudCorner.Parent = hudFrame

	local hudStroke = Instance.new("UIStroke")
	hudStroke.Color = Color3.fromRGB(80, 80, 140)
	hudStroke.Thickness = 1
	hudStroke.Parent = hudFrame

	-- Collapsed icon button (48x48, top-right, below HudFrame)
	local iconBtn = Instance.new("TextButton")
	iconBtn.Name = "ObjectiveIconBtn"
	iconBtn.Size = UDim2.new(0, 48, 0, 48)
	iconBtn.AnchorPoint = Vector2.new(1, 1)
	-- Align right edge with hudFrame's right edge; place below it with a small gap
	local iconRightX = ResponsiveUtil.scaledOffset(10) + hudW
	local iconTopY = -(math.max(minYOffset, ResponsiveUtil.scaledOffset(280)) + 8 + 48)
	iconBtn.Position = UDim2.new(0, iconRightX, 1, -iconTopY - 48)
	iconBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	iconBtn.BackgroundTransparency = 0.3
	iconBtn.BorderSizePixel = 0
	iconBtn.Text = "0/3"
	iconBtn.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
	iconBtn.Font = Enum.Font.GothamBold
	iconBtn.TextColor3 = Color3.fromRGB(210, 210, 240)
	iconBtn.Visible = false
	iconBtn.Parent = screenGui
	self._iconBtn = iconBtn

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = iconBtn

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.fromRGB(80, 80, 140)
	iconStroke.Thickness = 1
	iconStroke.Parent = iconBtn

	iconBtn.Activated:Connect(function()
		self:ShowFull()
		-- Auto-collapse back after 1.5 seconds
		if self._collapseTask then
			task.cancel(self._collapseTask)
		end
		self._collapseTask = task.delay(1.5, function()
			self._collapseTask = nil
			self:CollapseToIcon()
		end)
	end)

	-- "런 목표" title label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 18)
	titleLabel.Position = UDim2.new(0, 0, 0, ResponsiveUtil.scaledOffset(4))
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(180, 180, 240)
	titleLabel.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "런 목표"
	titleLabel.Parent = hudFrame

	-- 3 objective rows
	for i = 1, 3 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.Size = UDim2.new(1, -ResponsiveUtil.scaledOffset(12), 0, math.max(20, ResponsiveUtil.scaledOffset(24)))
		row.Position = UDim2.new(0, ResponsiveUtil.scaledOffset(6), 0, math.max(18, ResponsiveUtil.scaledOffset(22)) + (i - 1) * math.max(22, ResponsiveUtil.scaledOffset(28)))
		row.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
		row.BackgroundTransparency = 0.4
		row.Parent = hudFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 4)
		rowCorner.Parent = row

		-- Status indicator (○ / ✓)
		local checkLabel = Instance.new("TextLabel")
		checkLabel.Name = "Check"
		checkLabel.Size = UDim2.new(0, 18, 1, 0)
		checkLabel.Position = UDim2.new(0, 2, 0, 0)
		checkLabel.BackgroundTransparency = 1
		checkLabel.TextColor3 = Color3.fromRGB(140, 140, 200)
		checkLabel.TextSize = 14
		checkLabel.Font = Enum.Font.GothamBold
		checkLabel.Text = "○"
		checkLabel.Parent = row

		-- Description
		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "Desc"
		descLabel.Size = UDim2.new(1, -60, 1, 0)
		descLabel.Position = UDim2.new(0, 22, 0, 0)
		descLabel.BackgroundTransparency = 1
		descLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
		descLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
		descLabel.Font = Enum.Font.Gotham
		descLabel.Text = "..."
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextTruncate = Enum.TextTruncate.AtEnd
		descLabel.Parent = row

		-- Progress counter (X/Y)
		local progressLabel = Instance.new("TextLabel")
		progressLabel.Name = "Progress"
		progressLabel.Size = UDim2.new(0, 36, 1, 0)
		progressLabel.Position = UDim2.new(1, -80, 0, 0)
		progressLabel.BackgroundTransparency = 1
		progressLabel.TextColor3 = Color3.fromRGB(140, 200, 140)
		progressLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
		progressLabel.Font = Enum.Font.Gotham
		progressLabel.Text = ""
		progressLabel.TextXAlignment = Enum.TextXAlignment.Right
		progressLabel.Parent = row

		-- 리롤 버튼 (🔄 30코인)
		local rerollBtn = Instance.new("TextButton")
		rerollBtn.Name = "RerollBtn"
		rerollBtn.Size = UDim2.new(0, 48, 0.8, 0)
		rerollBtn.AnchorPoint = Vector2.new(1, 0.5)
		rerollBtn.Position = UDim2.new(1, -2, 0.5, 0)
		rerollBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 160)
		rerollBtn.BorderSizePixel = 0
		rerollBtn.Text = "🔄"
		rerollBtn.TextSize = 12
		rerollBtn.Font = Enum.Font.GothamBold
		rerollBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		rerollBtn.Parent = row
		Instance.new("UICorner", rerollBtn).CornerRadius = UDim.new(0, 4)

		local capturedIndex = i
		rerollBtn.Activated:Connect(function()
			if not self._rerollEnabled then return end
			RemoteEvents.RerollObjective:FireServer({ index = capturedIndex })
			rerollBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 120)
			rerollBtn.AutoButtonColor = false
		end)

		table.insert(self._rows, row)
		table.insert(self._rerollButtons, rerollBtn)
	end

	print("[ObjectiveHudController] UI created")
end

function ObjectiveHudController:_setupEventHandlers()
	-- Receive initial objectives list from server
	local genConn = RemoteEvents.RunObjectivesGenerated.OnClientEvent:Connect(function(data)
		self:_initObjectives(data.objectives)
	end)
	table.insert(self._connections, genConn)

	-- Receive progress updates
	local progressConn = RemoteEvents.RunObjectiveProgress.OnClientEvent:Connect(function(data)
		self:_applyProgress(data.objectives)
		if data.allCompleted then
			self:_showCompletionFlash(data.bonus)
		end
	end)
	table.insert(self._connections, progressConn)

	-- Reroll 결과 수신
	local rerollConn = RemoteEvents.RerollObjectiveResult.OnClientEvent:Connect(function(data)
		local btn = self._rerollButtons[data.index]
		if not btn then return end

		if data.success and data.objective then
			-- 행 갱신
			local row = self._rows[data.index]
			if row then
				local descLabel = row:FindFirstChild("Desc") :: TextLabel?
				local progressLabel = row:FindFirstChild("Progress") :: TextLabel?
				local checkLabel = row:FindFirstChild("Check") :: TextLabel?
				if descLabel then descLabel.Text = data.objective.desc end
				if progressLabel then progressLabel.Text = `0/{data.objective.target}` end
				if checkLabel then
					checkLabel.Text = "○"
					checkLabel.TextColor3 = Color3.fromRGB(140, 140, 200)
				end
				row.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
				row.BackgroundTransparency = 0.4
				self._targets[data.index] = data.objective.target
			end
			-- 버튼 복구
			btn.BackgroundColor3 = Color3.fromRGB(60, 80, 160)
			btn.AutoButtonColor = true
		else
			-- 실패 시 버튼 복구 + 에러 컬러
			btn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
			btn.AutoButtonColor = true
			task.delay(1, function()
				if btn and btn.Parent then
					btn.BackgroundColor3 = Color3.fromRGB(60, 80, 160)
				end
			end)
		end
	end)
	table.insert(self._connections, rerollConn)
end

-- Initialize rows with objective descriptions and targets
function ObjectiveHudController:_initObjectives(objectives: { any })
	self._targets = {}
	for i, obj in objectives do
		self._targets[i] = obj.target
		local row = self._rows[i]
		if not row then
			continue
		end

		local descLabel = row:FindFirstChild("Desc") :: TextLabel?
		local progressLabel = row:FindFirstChild("Progress") :: TextLabel?
		local checkLabel = row:FindFirstChild("Check") :: TextLabel?

		if descLabel then
			descLabel.Text = obj.desc
		end
		if progressLabel then
			progressLabel.Text = `0/{obj.target}`
		end
		if checkLabel then
			checkLabel.Text = "○"
			checkLabel.TextColor3 = Color3.fromRGB(140, 140, 200)
		end

		row.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
		row.BackgroundTransparency = 0.4
	end
end

-- Apply progress updates to rows (objectives arrive in same order as _initObjectives)
function ObjectiveHudController:_applyProgress(objectives: { any })
	for i, update in objectives do
		local row = self._rows[i]
		if not row then
			continue
		end

		local progressLabel = row:FindFirstChild("Progress") :: TextLabel?
		local checkLabel = row:FindFirstChild("Check") :: TextLabel?
		local target = self._targets[i] or 0

		if progressLabel then
			progressLabel.Text = `{update.progress}/{target}`
		end

		if update.completed then
			if checkLabel then
				checkLabel.Text = "✓"
				checkLabel.TextColor3 = Color3.fromRGB(80, 240, 80)
			end
			row.BackgroundColor3 = Color3.fromRGB(25, 55, 25)
			row.BackgroundTransparency = 0.3
		end
	end
end

-- Brief flash banner when all objectives are done
function ObjectiveHudController:_showCompletionFlash(bonus: number?)
	if not self._hudFrame then
		return
	end

	-- Update HUD border to gold
	local stroke = self._hudFrame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromRGB(255, 215, 0)
		stroke.Thickness = 2
	end

	-- Show "+Xc" banner
	local existing = self._hudFrame:FindFirstChild("CompletionBanner")
	if existing then
		existing:Destroy()
	end

	local banner = Instance.new("TextLabel")
	banner.Name = "CompletionBanner"
	banner.Size = UDim2.new(1, 0, 0, 20)
	banner.Position = UDim2.new(0, 0, 0, -24)
	banner.BackgroundTransparency = 1
	banner.TextColor3 = Color3.fromRGB(255, 220, 50)
	banner.TextSize = 14
	banner.Font = Enum.Font.GothamBold
	banner.Text = bonus and `전체 완료! +{bonus}코인` or "전체 완료!"
	banner.Parent = self._hudFrame

	TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, -28),
	}):Play()

	task.delay(2.5, function()
		if banner and banner.Parent then
			local tweenOut =
				TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(0, 0, 0, -10),
					TextTransparency = 1,
				})
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				if banner and banner.Parent then
					banner:Destroy()
				end
			end)
		end
	end)
end

-- Update icon button label with completed/total count
function ObjectiveHudController:_updateIconLabel()
	if not self._iconBtn then return end
	local completed = 0
	local total = #self._rows
	for _, row in self._rows do
		local checkLabel = row:FindFirstChild("Check") :: TextLabel?
		if checkLabel and checkLabel.Text == "✓" then
			completed += 1
		end
	end
	self._iconBtn.Text = `{completed}/{total}`
end

-- Show the full objectives panel
function ObjectiveHudController:ShowFull()
	if self._isTweening then return end
	if self._iconBtn then self._iconBtn.Visible = false end
	if self._hudFrame then
		self._hudFrame.Visible = true
	end
end

-- Collapse to the 48x48 icon button showing progress
function ObjectiveHudController:CollapseToIcon()
	if self._isTweening then return end
	self._isTweening = true
	if self._hudFrame then
		local tween = TweenService:Create(
			self._hudFrame,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)
		tween.Completed:Connect(function()
			if self._hudFrame then
				self._hudFrame.Visible = false
				self._hudFrame.BackgroundTransparency = 0.25
			end
			self._isTweening = false
			self:_updateIconLabel()
			if self._iconBtn then self._iconBtn.Visible = true end
		end)
		tween:Play()
	else
		self._isTweening = false
		self:_updateIconLabel()
		if self._iconBtn then self._iconBtn.Visible = true end
	end
end

-- Hide the entire objectiveHud GUI
function ObjectiveHudController:Hide()
	if self._collapseTask then
		task.cancel(self._collapseTask)
		self._collapseTask = nil
	end
	if self._hudFrame then self._hudFrame.Visible = false end
	if self._iconBtn then self._iconBtn.Visible = false end
end

-- Return whether the HUD (full panel or icon) is currently visible
function ObjectiveHudController:IsActive(): boolean
	local panelVisible = self._hudFrame ~= nil and self._hudFrame.Visible
	local iconVisible = self._iconBtn ~= nil and self._iconBtn.Visible
	return panelVisible or iconVisible
end

-- Show HUD at game start (리롤 버튼 활성 — 카운트다운 중 리롤 허용)
-- Auto-collapses to icon after 3 seconds per mobile UI spec §5.3
function ObjectiveHudController:StartGame()
	self._rerollEnabled = true
	if self._hudFrame then
		local stroke = self._hudFrame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Color3.fromRGB(80, 80, 140)
			stroke.Thickness = 1
		end
		self._hudFrame.Visible = true
	end
	for _, btn in self._rerollButtons do
		btn.Visible = true
		btn.BackgroundColor3 = Color3.fromRGB(60, 80, 160)
		btn.AutoButtonColor = true
	end

	-- Schedule auto-collapse to icon after 3 seconds
	if self._collapseTask then
		task.cancel(self._collapseTask)
	end
	self._collapseTask = task.delay(3, function()
		self._collapseTask = nil
		self:CollapseToIcon()
	end)
end

-- 실제 게임 진행 중 리롤 비활성화 (카운트다운 끝난 후 호출)
function ObjectiveHudController:DisableReroll()
	self._rerollEnabled = false
	for _, btn in self._rerollButtons do
		btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		btn.TextColor3 = Color3.fromRGB(100, 100, 100)
	end
end

-- Hide HUD on game end or lobby
function ObjectiveHudController:EndGame()
	self._rerollEnabled = true
	self:Hide()
	for _, btn in self._rerollButtons do
		btn.BackgroundColor3 = Color3.fromRGB(60, 80, 160)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.AutoButtonColor = true
	end
end

-- Cleanup
function ObjectiveHudController:Destroy()
	if self._screenGui then
		self._screenGui:Destroy()
	end
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return ObjectiveHudController

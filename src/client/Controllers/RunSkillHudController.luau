--!strict
-- Run Skill Hud Controller
-- 런 내 XP 바 + 스킬 선택 HUD 처리

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local RARITY_COLORS = {
	common = Color3.fromRGB(150, 150, 150),
	rare = Color3.fromRGB(80, 150, 255),
	legendary = Color3.fromRGB(255, 180, 0),
}

local RARITY_NAMES = {
	common = "일반",
	rare = "희귀",
	legendary = "전설",
}

local RunSkillHudController = {}
RunSkillHudController.__index = RunSkillHudController

function RunSkillHudController.new()
	local self = setmetatable({}, RunSkillHudController)

	self._player = Players.LocalPlayer
	self._gui = nil :: ScreenGui?
	self._xpFrame = nil :: Frame?
	self._xpBar = nil :: Frame?
	self._xpLabel = nil :: TextLabel?
	self._selectionFrame = nil :: Frame?
	self._autoSelectTimer = 0
	self._autoSelectThread = nil :: thread?
	self._active = false

	self:_buildGui()
	self:_connectEvents()

	return self
end

function RunSkillHudController:_buildGui()
	local player = self._player
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "RunSkillHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	-- ===== XP 바 (우측 상단 작은 바) =====
	local xpFrame = Instance.new("Frame")
	xpFrame.Name = "XPFrame"
	-- 가독성 개선: 폭 180→220, 높이 28→36
	local xpW = ResponsiveUtil.compactOffset(220)
	xpFrame.Size = UDim2.new(0, xpW, 0, ResponsiveUtil.compactOffset(36))
	xpFrame.Position = UDim2.new(1, -xpW - ResponsiveUtil.compactOffset(10), 0, ResponsiveUtil.compactOffset(10))
	xpFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	xpFrame.BackgroundTransparency = 0.3
	xpFrame.BorderSizePixel = 0
	xpFrame.Parent = gui
	Instance.new("UICorner", xpFrame).CornerRadius = UDim.new(0, 8)
	self._xpFrame = xpFrame

	local xpBg = Instance.new("Frame")
	xpBg.Name = "XPBackground"
	xpBg.Size = UDim2.new(1, -70, 0, 10)
	xpBg.Position = UDim2.new(0, 4, 0.5, 2)
	xpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	xpBg.BorderSizePixel = 0
	xpBg.Parent = xpFrame
	Instance.new("UICorner", xpBg).CornerRadius = UDim.new(1, 0)

	local xpBar = Instance.new("Frame")
	xpBar.Name = "XPBar"
	xpBar.Size = UDim2.new(0, 0, 1, 0)
	xpBar.BackgroundColor3 = Color3.fromRGB(100, 220, 255)
	xpBar.BorderSizePixel = 0
	xpBar.Parent = xpBg
	Instance.new("UICorner", xpBar).CornerRadius = UDim.new(1, 0)
	self._xpBar = xpBar

	local xpLabel = Instance.new("TextLabel")
	xpLabel.Name = "XPLabel"
	xpLabel.Size = UDim2.new(0, 64, 1, 0)
	xpLabel.Position = UDim2.new(1, -66, 0, 0)
	xpLabel.BackgroundTransparency = 1
	xpLabel.Text = "Lv.1"
	xpLabel.TextColor3 = Color3.fromRGB(200, 240, 255)
	xpLabel.TextSize = ResponsiveUtil.compactTextSize(16, 12)
	xpLabel.Font = Enum.Font.GothamBold
	xpLabel.TextXAlignment = Enum.TextXAlignment.Right
	xpLabel.Parent = xpFrame
	self._xpLabel = xpLabel

	-- ===== 스킬 선택 패널 (중앙 상단) =====
	local selFrame = Instance.new("Frame")
	selFrame.Name = "SkillSelection"
	local selW = math.min(ResponsiveUtil.compactOffset(480), ResponsiveUtil.getViewportSize().X - 20)
	local selH = ResponsiveUtil.compactOffset(210)
	selFrame.Size = UDim2.new(0, selW, 0, selH)
	selFrame.AnchorPoint = Vector2.new(0.5, 0)
	selFrame.Position = UDim2.new(0.5, 0, 0, -selH - 20) -- 초기 화면 위 (숨김)
	selFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
	selFrame.BackgroundTransparency = 0.15
	selFrame.BorderSizePixel = 0
	selFrame.Visible = false
	selFrame.Parent = gui
	Instance.new("UICorner", selFrame).CornerRadius = UDim.new(0, 12)

	-- 제목 라벨
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 28)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "⭐ 런 레벨업! 스킬을 선택하세요"
	titleLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	titleLabel.TextSize = ResponsiveUtil.compactTextSize(14, 11)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = selFrame

	-- 타이머 바
	local timerBg = Instance.new("Frame")
	timerBg.Name = "TimerBg"
	timerBg.Size = UDim2.new(1, -20, 0, 4)
	timerBg.Position = UDim2.new(0, 10, 0, 28)
	timerBg.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	timerBg.BorderSizePixel = 0
	timerBg.Parent = selFrame
	Instance.new("UICorner", timerBg).CornerRadius = UDim.new(1, 0)

	local timerBar = Instance.new("Frame")
	timerBar.Name = "TimerBar"
	timerBar.Size = UDim2.new(1, 0, 1, 0)
	timerBar.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
	timerBar.BorderSizePixel = 0
	timerBar.Parent = timerBg
	Instance.new("UICorner", timerBar).CornerRadius = UDim.new(1, 0)

	-- 카드 3개 담는 레이아웃
	local cardsFrame = Instance.new("Frame")
	cardsFrame.Name = "Cards"
	cardsFrame.Size = UDim2.new(1, -16, 1, -44)
	cardsFrame.Position = UDim2.new(0, 8, 0, 38)
	cardsFrame.BackgroundTransparency = 1
	cardsFrame.Parent = selFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = cardsFrame

	self._selectionFrame = selFrame
end

function RunSkillHudController:_connectEvents()
	-- XP 업데이트
	RemoteEvents.RunXPUpdate.OnClientEvent:Connect(function(data)
		self:_updateXPBar(data.runXP, data.runXPMax, data.runLevel)
	end)

	-- 스킬 선택 옵션
	RemoteEvents.RunSkillOptions.OnClientEvent:Connect(function(data)
		self:_showSkillSelection(data.skills, data.autoSelectDelay)
	end)

	-- 스킬 발동 확인
	RemoteEvents.RunSkillActivated.OnClientEvent:Connect(function(data)
		self:_showActivationFeedback(data.emoji, data.name)
	end)
end

function RunSkillHudController:_updateXPBar(xp: number, xpMax: number, level: number)
	if not self._gui or not self._gui.Enabled then
		return
	end

	local ratio = if xpMax > 0 then math.clamp(xp / xpMax, 0, 1) else 0

	local xpBar = self._xpBar
	if xpBar then
		TweenService:Create(xpBar, TweenInfo.new(0.2), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
	end

	if self._xpLabel then
		self._xpLabel.Text = `Lv.{level}`
	end
end

function RunSkillHudController:_showSkillSelection(skills: { any }, autoDelay: number)
	local selFrame = self._selectionFrame
	if not selFrame then
		return
	end

	-- 기존 카드 제거
	local cardsFrame = selFrame:FindFirstChild("Cards") :: Frame?
	if cardsFrame then
		for _, child in cardsFrame:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end

	-- 카드 생성
	for i, skill in skills do
		local rarityColor = RARITY_COLORS[skill.rarity] or RARITY_COLORS.common
		local cardWidth = ResponsiveUtil.compactOffset(140)

		local card = Instance.new("TextButton")
		card.Name = `Card_{i}`
		card.Size = UDim2.new(0, cardWidth, 1, 0)
		card.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
		card.BorderSizePixel = 0
		card.AutoButtonColor = false
		card.Text = ""
		card.Parent = cardsFrame
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

		-- 희귀도 색상 테두리
		local stroke = Instance.new("UIStroke")
		stroke.Color = rarityColor
		stroke.Thickness = 2
		stroke.Parent = card

		-- 이모지
		local emojiLabel = Instance.new("TextLabel")
		emojiLabel.Size = UDim2.new(1, 0, 0, 48)
		emojiLabel.Position = UDim2.new(0, 0, 0, 6)
		emojiLabel.BackgroundTransparency = 1
		emojiLabel.Text = skill.emoji
		emojiLabel.TextSize = ResponsiveUtil.compactTextSize(34, 24)
		emojiLabel.Font = Enum.Font.GothamBold
		emojiLabel.Parent = card

		-- 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -6, 0, 22)
		nameLabel.Position = UDim2.new(0, 3, 0, 58)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = skill.name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = ResponsiveUtil.compactTextSize(14, 11)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextWrapped = true
		nameLabel.Parent = card

		-- 설명
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -6, 0, 56)
		descLabel.Position = UDim2.new(0, 3, 0, 82)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = skill.desc
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
		descLabel.TextSize = ResponsiveUtil.compactTextSize(12, 9)
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextWrapped = true
		descLabel.Parent = card

		-- 희귀도 라벨
		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size = UDim2.new(1, 0, 0, 16)
		rarityLabel.Position = UDim2.new(0, 0, 1, -18)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text = RARITY_NAMES[skill.rarity] or skill.rarity
		rarityLabel.TextColor3 = rarityColor
		rarityLabel.TextSize = ResponsiveUtil.compactTextSize(11, 9)
		rarityLabel.Font = Enum.Font.GothamBold
		rarityLabel.Parent = card

		-- 클릭 처리
		local skillId = skill.id
		card.Activated:Connect(function()
			self:_selectSkill(skillId)
		end)

		-- 호버 효과
		card.MouseEnter:Connect(function()
			TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(40, 40, 60) }):Play()
		end)
		card.MouseLeave:Connect(function()
			TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(25, 25, 40) }):Play()
		end)
	end

	-- 패널 슬라이드 인
	selFrame.Visible = true
	TweenService:Create(selFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0, 10),
	}):Play()

	-- 타이머 바 애니메이션
	local timerBg = selFrame:FindFirstChild("TimerBg") :: Frame?
	local timerBar = timerBg and timerBg:FindFirstChild("TimerBar") :: Frame?
	if timerBar then
		timerBar.Size = UDim2.new(1, 0, 1, 0)
		TweenService:Create(timerBar, TweenInfo.new(autoDelay, Enum.EasingStyle.Linear), {
			Size = UDim2.new(0, 0, 1, 0),
		}):Play()
	end
end

function RunSkillHudController:_selectSkill(skillId: string)
	-- 패널 숨김
	self:_hideSkillSelection()

	-- 서버에 선택 전송
	RemoteEvents.RunSkillSelect:FireServer({ skillId = skillId })
end

function RunSkillHudController:_hideSkillSelection()
	local selFrame = self._selectionFrame
	if not selFrame or not selFrame.Visible then
		return
	end

	local tween = TweenService:Create(selFrame, TweenInfo.new(0.2), {
		Position = UDim2.new(0.5, 0, 0, -160),
	})
	tween:Play()
	tween.Completed:Once(function()
		selFrame.Visible = false
	end)
end

function RunSkillHudController:_showActivationFeedback(emoji: string, name: string)
	local playerGui = self._player:FindFirstChild("PlayerGui") :: PlayerGui?
	if not playerGui then
		return
	end

	-- 간단한 팝업 라벨
	local toast = Instance.new("ScreenGui")
	toast.Name = "RunSkillToast"
	toast.DisplayOrder = 20
	toast.ResetOnSpawn = false
	toast.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, ResponsiveUtil.compactOffset(200), 0, ResponsiveUtil.compactOffset(40))
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.35, 0)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.Text = `{emoji} {name} 발동!`
	label.TextColor3 = Color3.fromRGB(255, 240, 150)
	label.TextSize = ResponsiveUtil.compactTextSize(16, 12)
	label.Font = Enum.Font.GothamBold
	label.Parent = toast
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)

	-- 페이드 인 → 아웃
	label.BackgroundTransparency = 1
	label.TextTransparency = 1
	TweenService:Create(label, TweenInfo.new(0.2), {
		BackgroundTransparency = 0.2,
		TextTransparency = 0,
	}):Play()

	task.delay(1.5, function()
		TweenService:Create(label, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()
		task.delay(0.3, function()
			toast:Destroy()
		end)
	end)
end

-- Show/Hide XP frame GUI
function RunSkillHudController:Show()
	if self._gui then
		self._gui.Enabled = true
	end
end

function RunSkillHudController:Hide()
	if self._gui then
		self._gui.Enabled = false
	end
end

-- 게임 시작 시 HUD 활성화
function RunSkillHudController:StartGame()
	self._active = true
	if self._gui then
		self._gui.Enabled = true
	end
end

-- 게임 종료 시 HUD 비활성화
function RunSkillHudController:EndGame()
	self._active = false
	self:_hideSkillSelection()
	if self._gui then
		self._gui.Enabled = false
	end
	-- XP 바 초기화
	if self._xpBar then
		self._xpBar.Size = UDim2.new(0, 0, 1, 0)
	end
	if self._xpLabel then
		self._xpLabel.Text = "Lv.1"
	end
end

return RunSkillHudController

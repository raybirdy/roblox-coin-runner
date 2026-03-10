--!strict
-- Pre-Run Skill Controller
-- 런 시작 전 스킬 슬롯 2개 선택 UI

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local RARITY_COLORS = {
	common = Color3.fromRGB(150, 150, 150),
	rare = Color3.fromRGB(80, 150, 255),
	legendary = Color3.fromRGB(255, 180, 0),
}

local MAX_SLOTS = 2

local PreRunSkillController = {}
PreRunSkillController.__index = PreRunSkillController

function PreRunSkillController.new()
	local self = setmetatable({}, PreRunSkillController)

	self._player = Players.LocalPlayer
	self._gui = nil :: ScreenGui?
	self._panel = nil :: Frame?

	-- 서버에서 받은 데이터
	self._unlockedSkills: { any } = {}
	self._equippedSkills: { string } = {}

	-- 콜백 (포탈 플로우에서 완료 시 호출)
	self._onConfirmCallback: (( { string }) -> ())? = nil
	self._isOpen = false

	self:_buildGui()
	self:_connectEvents()

	return self
end

function PreRunSkillController:_buildGui()
	local playerGui = self._player:WaitForChild("PlayerGui") :: PlayerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "PreRunSkillGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 18
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	-- 반투명 딤
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.Parent = gui

	-- 메인 패널
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 420, 0, 340)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
	panel.BorderSizePixel = 0
	panel.Parent = dim
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	self._panel = panel

	-- 제목
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 44)
	title.BackgroundTransparency = 1
	title.Text = "🎒 런 시작 스킬 슬롯 (최대 2개)"
	title.TextColor3 = Color3.fromRGB(255, 230, 100)
	title.TextSize = 17
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	-- 설명
	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 20)
	desc.Position = UDim2.new(0, 10, 0, 44)
	desc.BackgroundTransparency = 1
	desc.Text = "보유한 스킬 중 시작 시 즉시 발동할 스킬을 선택하세요"
	desc.TextColor3 = Color3.fromRGB(160, 160, 180)
	desc.TextSize = 12
	desc.Font = Enum.Font.Gotham
	desc.TextWrapped = true
	desc.Parent = panel

	-- 슬롯 표시 (선택된 스킬)
	local slotsFrame = Instance.new("Frame")
	slotsFrame.Name = "SlotsFrame"
	slotsFrame.Size = UDim2.new(1, -20, 0, 60)
	slotsFrame.Position = UDim2.new(0, 10, 0, 70)
	slotsFrame.BackgroundTransparency = 1
	slotsFrame.Parent = panel

	local slotLayout = Instance.new("UIListLayout")
	slotLayout.FillDirection = Enum.FillDirection.Horizontal
	slotLayout.Padding = UDim.new(0, 8)
	slotLayout.Parent = slotsFrame

	for i = 1, MAX_SLOTS do
		local slot = Instance.new("Frame")
		slot.Name = `Slot_{i}`
		slot.Size = UDim2.new(0, 130, 1, 0)
		slot.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
		slot.BorderSizePixel = 0
		slot.Parent = slotsFrame
		Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(60, 60, 100)
		stroke.Thickness = 1
		stroke.Name = "Stroke"
		stroke.Parent = slot

		local slotLabel = Instance.new("TextLabel")
		slotLabel.Name = "Label"
		slotLabel.Size = UDim2.new(1, 0, 1, 0)
		slotLabel.BackgroundTransparency = 1
		slotLabel.Text = `슬롯 {i} (비어있음)`
		slotLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
		slotLabel.TextSize = 12
		slotLabel.Font = Enum.Font.Gotham
		slotLabel.TextWrapped = true
		slotLabel.Parent = slot
	end

	-- 스킬 카드 그리드 (해금된 스킬들)
	local gridScroll = Instance.new("ScrollingFrame")
	gridScroll.Name = "Grid"
	gridScroll.Size = UDim2.new(1, -20, 0, 160)
	gridScroll.Position = UDim2.new(0, 10, 0, 140)
	gridScroll.BackgroundTransparency = 1
	gridScroll.ScrollBarThickness = 4
	gridScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	gridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	gridScroll.Parent = panel

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 118, 0, 68)
	gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	gridLayout.Parent = gridScroll

	-- 미해금 안내
	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "EmptyLabel"
	emptyLabel.Size = UDim2.new(1, 0, 0, 60)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = "아직 해금된 스킬이 없습니다.\n계정 레벨 3에 첫 스킬이 해금됩니다!"
	emptyLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
	emptyLabel.TextSize = 13
	emptyLabel.Font = Enum.Font.Gotham
	emptyLabel.TextWrapped = true
	emptyLabel.Visible = false
	emptyLabel.Parent = gridScroll

	-- 확인 버튼
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Name = "ConfirmBtn"
	confirmBtn.Size = UDim2.new(1, -20, 0, 40)
	confirmBtn.Position = UDim2.new(0, 10, 1, -50)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
	confirmBtn.BorderSizePixel = 0
	confirmBtn.Text = "✅ 선택 완료 — 게임 시작!"
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.TextSize = 15
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.Parent = panel
	Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 8)

	confirmBtn.Activated:Connect(function()
		self:_confirm()
	end)
end

function PreRunSkillController:_connectEvents()
	-- 서버에서 스킬 데이터 수신
	RemoteEvents.PreRunSkillData.OnClientEvent:Connect(function(data)
		self._unlockedSkills = data.unlockedSkills or {}
		self._equippedSkills = data.equippedSkills or {}
		if self._isOpen then
			self:_refresh()
		end
	end)

	-- 스킬 해금 알림
	RemoteEvents.RunSkillUnlocked.OnClientEvent:Connect(function(data)
		-- 서버에 최신 데이터 재요청은 자동으로 오므로 여기서는 토스트만
		local playerGui = self._player:FindFirstChild("PlayerGui") :: PlayerGui?
		if not playerGui then
			return
		end
		local toast = Instance.new("ScreenGui")
		toast.Name = "SkillUnlockToast"
		toast.DisplayOrder = 25
		toast.ResetOnSpawn = false
		toast.Parent = playerGui

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0, 260, 0, 44)
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, 80)
		label.BackgroundColor3 = Color3.fromRGB(20, 120, 50)
		label.BackgroundTransparency = 0.1
		label.BorderSizePixel = 0
		label.Text = `🎉 런 스킬 해금: {data.skillId}!`
		label.TextColor3 = Color3.fromRGB(200, 255, 180)
		label.TextSize = 14
		label.Font = Enum.Font.GothamBold
		label.Parent = toast
		Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)

		task.delay(3, function()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.delay(0.4, function()
				toast:Destroy()
			end)
		end)
	end)
end

-- UI 갱신 (스킬 카드 재생성)
function PreRunSkillController:_refresh()
	local panel = self._panel
	if not panel then
		return
	end

	local gridScroll = panel:FindFirstChild("Grid") :: ScrollingFrame?
	local slotsFrame = panel:FindFirstChild("SlotsFrame") :: Frame?
	local emptyLabel = gridScroll and gridScroll:FindFirstChild("EmptyLabel") :: TextLabel?

	-- 기존 카드 제거
	if gridScroll then
		for _, child in gridScroll:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end

	-- 빈 상태 안내
	if emptyLabel then
		emptyLabel.Visible = #self._unlockedSkills == 0
	end

	-- 슬롯 표시 업데이트
	self:_updateSlotDisplay()

	-- 카드 생성
	for _, skill in self._unlockedSkills do
		local isEquipped = false
		for _, id in self._equippedSkills do
			if id == skill.id then
				isEquipped = true
				break
			end
		end

		local rarityColor = RARITY_COLORS[skill.rarity] or RARITY_COLORS.common

		local card = Instance.new("TextButton")
		card.Name = `Card_{skill.id}`
		card.Size = UDim2.new(0, 118, 0, 68)
		card.BackgroundColor3 = if isEquipped then Color3.fromRGB(30, 60, 30) else Color3.fromRGB(22, 22, 38)
		card.BorderSizePixel = 0
		card.AutoButtonColor = false
		card.Text = ""
		card.Parent = gridScroll
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

		local stroke = Instance.new("UIStroke")
		stroke.Color = if isEquipped then Color3.fromRGB(80, 200, 80) else rarityColor
		stroke.Thickness = if isEquipped then 2 else 1
		stroke.Parent = card

		local emojiLabel = Instance.new("TextLabel")
		emojiLabel.Size = UDim2.new(0, 30, 1, 0)
		emojiLabel.BackgroundTransparency = 1
		emojiLabel.Text = skill.emoji
		emojiLabel.TextSize = 22
		emojiLabel.Font = Enum.Font.GothamBold
		emojiLabel.Parent = card

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -34, 0, 22)
		nameLabel.Position = UDim2.new(0, 32, 0, 4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = skill.name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 12
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextWrapped = true
		nameLabel.Parent = card

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -36, 0, 30)
		descLabel.Position = UDim2.new(0, 34, 0, 26)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = skill.desc
		descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
		descLabel.TextSize = 9
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextWrapped = true
		descLabel.Parent = card

		if isEquipped then
			local checkLabel = Instance.new("TextLabel")
			checkLabel.Size = UDim2.new(0, 16, 0, 16)
			checkLabel.Position = UDim2.new(1, -18, 0, 2)
			checkLabel.BackgroundTransparency = 1
			checkLabel.Text = "✓"
			checkLabel.TextColor3 = Color3.fromRGB(100, 220, 100)
			checkLabel.TextSize = 14
			checkLabel.Font = Enum.Font.GothamBold
			checkLabel.Parent = card
		end

		-- 클릭: 토글 장착
		local skillId = skill.id
		card.Activated:Connect(function()
			self:_toggleEquip(skillId)
		end)
	end
end

-- 슬롯 표시 업데이트
function PreRunSkillController:_updateSlotDisplay()
	local panel = self._panel
	if not panel then
		return
	end
	local slotsFrame = panel:FindFirstChild("SlotsFrame") :: Frame?
	if not slotsFrame then
		return
	end

	-- 스킬 맵
	local skillMap: { [string]: any } = {}
	for _, skill in self._unlockedSkills do
		skillMap[skill.id] = skill
	end

	for i = 1, MAX_SLOTS do
		local slot = slotsFrame:FindFirstChild(`Slot_{i}`) :: Frame?
		if not slot then
			continue
		end
		local label = slot:FindFirstChild("Label") :: TextLabel?
		local stroke = slot:FindFirstChild("Stroke") :: UIStroke?
		local equippedId = self._equippedSkills[i]
		local skill = equippedId and skillMap[equippedId]

		if skill then
			if label then
				label.Text = `{skill.emoji} {skill.name}`
				label.TextColor3 = Color3.fromRGB(220, 220, 255)
			end
			if stroke then
				stroke.Color = RARITY_COLORS[skill.rarity] or RARITY_COLORS.common
				stroke.Thickness = 2
			end
		else
			if label then
				label.Text = `슬롯 {i} (비어있음)`
				label.TextColor3 = Color3.fromRGB(100, 100, 120)
			end
			if stroke then
				stroke.Color = Color3.fromRGB(60, 60, 100)
				stroke.Thickness = 1
			end
		end
	end
end

-- 스킬 장착 토글
function PreRunSkillController:_toggleEquip(skillId: string)
	-- 이미 장착되어 있으면 해제
	local found = false
	local newEquipped: { string } = {}
	for _, id in self._equippedSkills do
		if id == skillId then
			found = true
			-- 제외 (해제)
		else
			table.insert(newEquipped, id)
		end
	end

	if not found then
		-- 장착 (최대 2개)
		if #self._equippedSkills < MAX_SLOTS then
			table.insert(newEquipped, skillId)
		else
			-- 이미 2개 → 첫 슬롯 교체
			newEquipped = { self._equippedSkills[2] or self._equippedSkills[1], skillId }
		end
	end

	self._equippedSkills = newEquipped

	-- 서버에 저장
	RemoteEvents.EquipRunSkills:FireServer({ skillIds = newEquipped })

	-- UI 갱신
	self:_refresh()
end

-- 확인 → 콜백 호출
function PreRunSkillController:_confirm()
	self:Close()
	if self._onConfirmCallback then
		self._onConfirmCallback(self._equippedSkills)
	end
end

-- 패널 열기
function PreRunSkillController:Show(callback: (({ string }) -> ())?)
	self._onConfirmCallback = callback
	self._isOpen = true

	if self._gui then
		self._gui.Enabled = true
	end

	self:_refresh()

	-- 패널 등장 애니메이션
	if self._panel then
		self._panel.Position = UDim2.new(0.5, 0, 1.5, 0)
		TweenService:Create(self._panel, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
			Position = UDim2.new(0.5, 0, 0.5, 0),
		}):Play()
	end
end

-- 패널 닫기
function PreRunSkillController:Close()
	self._isOpen = false
	if self._gui then
		self._gui.Enabled = false
	end
end

function PreRunSkillController:IsOpen(): boolean
	return self._isOpen
end

function PreRunSkillController:HasUnlockedSkills(): boolean
	return #self._unlockedSkills > 0
end

return PreRunSkillController

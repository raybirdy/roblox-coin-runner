--!strict
-- Character Select Controller
-- 캐릭터 선택 + 상점 UI (탭 분리: 내 캐릭터 / 상점)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local CharacterSelectController = {}
CharacterSelectController.__index = CharacterSelectController

export type CharacterSelectController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_playerGui: PlayerGui,
		_screenGui: ScreenGui?,
		_panel: Frame?,
		_ownedCharacters: { string },
		_equippedCharacter: string,
		_coins: number,
		_gems: number,
		_connections: { RBXScriptConnection },
		_isOpen: boolean,
		_activeTab: string, -- "mine" | "shop"
		_confirmFrame: Frame?,
		_pendingBuyId: string?,
	},
	CharacterSelectController
))

-- 캐릭터 ID → 데이터 맵
local characterMap: { [string]: any } = {}
for _, char in GameConstants.CHARACTERS.LIST do
	characterMap[char.id] = char
end

function CharacterSelectController.new(player: Player): CharacterSelectController
	local self = setmetatable({
		_player = player,
		_playerGui = player:WaitForChild("PlayerGui") :: PlayerGui,
		_screenGui = nil,
		_panel = nil,
		_ownedCharacters = { "runner" },
		_equippedCharacter = "runner",
		_coins = 0,
		_gems = 0,
		_connections = {},
		_isOpen = false,
		_activeTab = "mine",
		_confirmFrame = nil,
		_pendingBuyId = nil,
	}, CharacterSelectController)

	self:_createUI()
	self:_setupEvents()

	return self
end

-- ==================== UI 생성 ====================

function CharacterSelectController:_createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CharacterSelectUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 16
	screenGui.Parent = self._playerGui
	self._screenGui = screenGui

	-- 배경 딤
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Visible = false
	dim.Parent = screenGui
	dim.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- 메인 패널
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = ResponsiveUtil.clampedSize(540, 520, 0.95, 0.92)
	panel.Position = ResponsiveUtil.clampedPosition(540, 520, 0.95, 0.92)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 38)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = screenGui
	self._panel = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 150, 255)
	stroke.Thickness = 2
	stroke.Parent = panel

	-- 헤더 영역 (타이틀 + 재화)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 44)
	header.Position = UDim2.new(0, 0, 0, 0)
	header.BackgroundTransparency = 1
	header.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 160, 1, 0)
	title.Position = UDim2.new(0, 14, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "🎭 캐릭터"
	title.TextColor3 = Color3.fromRGB(200, 220, 255)
	title.TextSize = ResponsiveUtil.scaledTextSize(20, 16)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	-- 재화 표시 (코인/젬)
	local currencyFrame = Instance.new("Frame")
	currencyFrame.Name = "Currency"
	currencyFrame.Size = UDim2.new(0, 160, 0, 30)
	currencyFrame.Position = UDim2.new(1, -200, 0, 7)
	currencyFrame.BackgroundTransparency = 1
	currencyFrame.Parent = header

	local coinLabel = Instance.new("TextLabel")
	coinLabel.Name = "CoinLabel"
	coinLabel.Size = UDim2.new(0, 75, 1, 0)
	coinLabel.Position = UDim2.new(0, 0, 0, 0)
	coinLabel.BackgroundColor3 = Color3.fromRGB(40, 35, 10)
	coinLabel.BackgroundTransparency = 0.3
	coinLabel.Text = "🪙 0"
	coinLabel.TextColor3 = Color3.fromRGB(255, 215, 50)
	coinLabel.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
	coinLabel.Font = Enum.Font.GothamBold
	coinLabel.Parent = currencyFrame
	Instance.new("UICorner", coinLabel).CornerRadius = UDim.new(0, 8)

	local gemLabel = Instance.new("TextLabel")
	gemLabel.Name = "GemLabel"
	gemLabel.Size = UDim2.new(0, 75, 1, 0)
	gemLabel.Position = UDim2.new(0, 82, 0, 0)
	gemLabel.BackgroundColor3 = Color3.fromRGB(20, 10, 40)
	gemLabel.BackgroundTransparency = 0.3
	gemLabel.Text = "💎 0"
	gemLabel.TextColor3 = Color3.fromRGB(180, 130, 255)
	gemLabel.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
	gemLabel.Font = Enum.Font.GothamBold
	gemLabel.Parent = currencyFrame
	Instance.new("UICorner", gemLabel).CornerRadius = UDim.new(0, 8)

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 34, 0, 34)
	closeBtn.Position = UDim2.new(1, -42, 0, 5)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 15
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.5, 0)
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- 탭 바
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -16, 0, 36)
	tabBar.Position = UDim2.new(0, 8, 0, 46)
	tabBar.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
	tabBar.BackgroundTransparency = 0.3
	tabBar.Parent = panel
	Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 10)

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.Parent = tabBar

	local tabPadding = Instance.new("UIPadding")
	tabPadding.PaddingLeft = UDim.new(0, 4)
	tabPadding.PaddingTop = UDim.new(0, 4)
	tabPadding.PaddingBottom = UDim.new(0, 4)
	tabPadding.Parent = tabBar

	local tabs = {
		{ key = "mine", label = "내 캐릭터", order = 1 },
		{ key = "shop", label = "🛒 상점", order = 2 },
	}
	for _, tab in tabs do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = tab.key
		tabBtn.Size = UDim2.new(0.5, -6, 1, 0)
		tabBtn.LayoutOrder = tab.order
		tabBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
		tabBtn.BackgroundTransparency = 0.5
		tabBtn.Text = tab.label
		tabBtn.TextColor3 = Color3.fromRGB(160, 170, 200)
		tabBtn.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
		tabBtn.Font = Enum.Font.GothamBold
		tabBtn.Parent = tabBar
		Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 7)
		tabBtn.MouseButton1Click:Connect(function()
			self:_switchTab(tab.key)
		end)
	end

	-- 캐릭터 그리드 (ScrollingFrame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "CharacterGrid"
	scroll.Size = UDim2.new(1, -16, 1, -96)
	scroll.Position = UDim2.new(0, 8, 0, 90)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 148, 0, 172)
	grid.CellPadding = UDim2.new(0, 10, 0, 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll

	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 8)
	gridPadding.Parent = scroll

	-- 캐릭터 카드 생성
	for _, char in GameConstants.CHARACTERS.LIST do
		self:_createCharacterCard(scroll, char)
	end

	-- 구매 확인 팝업 (초기 숨김)
	self:_createConfirmPopup(panel)
end

-- 구매 확인 팝업
function CharacterSelectController:_createConfirmPopup(parent: Frame)
	local confirm = Instance.new("Frame")
	confirm.Name = "ConfirmPopup"
	confirm.Size = UDim2.new(0, 280, 0, 160)
	confirm.Position = UDim2.new(0.5, -140, 0.5, -80)
	confirm.BackgroundColor3 = Color3.fromRGB(25, 25, 50)
	confirm.BackgroundTransparency = 0.05
	confirm.Visible = false
	confirm.ZIndex = 10
	confirm.Parent = parent
	Instance.new("UICorner", confirm).CornerRadius = UDim.new(0, 14)

	local confirmStroke = Instance.new("UIStroke")
	confirmStroke.Color = Color3.fromRGB(150, 180, 255)
	confirmStroke.Thickness = 2
	confirmStroke.Parent = confirm

	local confirmTitle = Instance.new("TextLabel")
	confirmTitle.Name = "Title"
	confirmTitle.Size = UDim2.new(1, -16, 0, 30)
	confirmTitle.Position = UDim2.new(0, 8, 0, 10)
	confirmTitle.BackgroundTransparency = 1
	confirmTitle.Text = "캐릭터 구매"
	confirmTitle.TextColor3 = Color3.fromRGB(220, 230, 255)
	confirmTitle.TextSize = 15
	confirmTitle.Font = Enum.Font.GothamBold
	confirmTitle.ZIndex = 11
	confirmTitle.Parent = confirm

	local confirmDesc = Instance.new("TextLabel")
	confirmDesc.Name = "Desc"
	confirmDesc.Size = UDim2.new(1, -16, 0, 44)
	confirmDesc.Position = UDim2.new(0, 8, 0, 44)
	confirmDesc.BackgroundTransparency = 1
	confirmDesc.Text = ""
	confirmDesc.TextColor3 = Color3.fromRGB(200, 210, 240)
	confirmDesc.TextSize = 13
	confirmDesc.Font = Enum.Font.Gotham
	confirmDesc.TextWrapped = true
	confirmDesc.ZIndex = 11
	confirmDesc.Parent = confirm

	local yesBtn = Instance.new("TextButton")
	yesBtn.Name = "YesBtn"
	yesBtn.Size = UDim2.new(0, 110, 0, 32)
	yesBtn.Position = UDim2.new(0, 16, 1, -44)
	yesBtn.BackgroundColor3 = Color3.fromRGB(50, 140, 60)
	yesBtn.Text = "구매"
	yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	yesBtn.TextSize = 14
	yesBtn.Font = Enum.Font.GothamBold
	yesBtn.ZIndex = 11
	yesBtn.Parent = confirm
	Instance.new("UICorner", yesBtn).CornerRadius = UDim.new(0, 8)
	yesBtn.MouseButton1Click:Connect(function()
		self:_confirmPurchase()
	end)

	local noBtn = Instance.new("TextButton")
	noBtn.Name = "NoBtn"
	noBtn.Size = UDim2.new(0, 110, 0, 32)
	noBtn.Position = UDim2.new(1, -126, 1, -44)
	noBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
	noBtn.Text = "취소"
	noBtn.TextColor3 = Color3.fromRGB(220, 200, 200)
	noBtn.TextSize = 14
	noBtn.Font = Enum.Font.GothamBold
	noBtn.ZIndex = 11
	noBtn.Parent = confirm
	Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 8)
	noBtn.MouseButton1Click:Connect(function()
		self:_hideConfirm()
	end)

	self._confirmFrame = confirm
end

-- 캐릭터 카드 생성
function CharacterSelectController:_createCharacterCard(parent: ScrollingFrame, char: any)
	local card = Instance.new("Frame")
	card.Name = char.id
	card.BackgroundColor3 = Color3.fromRGB(30, 30, 55)
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 12)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "CardStroke"
	cardStroke.Thickness = 2
	cardStroke.Color = Color3.fromRGB(60, 60, 100)
	cardStroke.Parent = card

	-- 이모지
	local emoji = Instance.new("TextLabel")
	emoji.Name = "Emoji"
	emoji.Size = UDim2.new(1, 0, 0, 54)
	emoji.Position = UDim2.new(0, 0, 0, 8)
	emoji.BackgroundTransparency = 1
	emoji.Text = char.emoji
	emoji.TextSize = 38
	emoji.Font = Enum.Font.GothamBold
	emoji.Parent = card

	-- 캐릭터 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -8, 0, 20)
	nameLabel.Position = UDim2.new(0, 4, 0, 64)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = char.name
	nameLabel.TextColor3 = Color3.fromRGB(220, 225, 255)
	nameLabel.TextSize = ResponsiveUtil.scaledTextSize(13, 11)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = card

	-- 패시브 설명
	local passiveText = ""
	if char.passive and char.passive.type ~= "none" then
		if char.passive.type == "magnet_bonus" then
			passiveText = `자석 +{char.passive.value}`
		elseif char.passive.type == "hit_resist" then
			passiveText = `피격 {char.passive.value * 100}% 무효`
		elseif char.passive.type == "fever_extend" then
			passiveText = `피버 +{char.passive.value}초`
		elseif char.passive.type == "start_magnet" then
			passiveText = `시작 자석 {char.passive.value}초`
		elseif char.passive.type == "hitbox_reduction" then
			passiveText = `판정 {char.passive.value * 100}% 완화`
		end
	end

	local passiveLabel = Instance.new("TextLabel")
	passiveLabel.Name = "Passive"
	passiveLabel.Size = UDim2.new(1, -8, 0, 16)
	passiveLabel.Position = UDim2.new(0, 4, 0, 86)
	passiveLabel.BackgroundTransparency = 1
	passiveLabel.Text = passiveText
	passiveLabel.TextColor3 = Color3.fromRGB(140, 220, 140)
	passiveLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 10)
	passiveLabel.Font = Enum.Font.Gotham
	passiveLabel.TextTruncate = Enum.TextTruncate.AtEnd
	passiveLabel.Parent = card

	-- 스킬 이름
	local skillText = char.skill and char.skill.name or "스킬 없음"
	local skillLabel = Instance.new("TextLabel")
	skillLabel.Name = "Skill"
	skillLabel.Size = UDim2.new(1, -8, 0, 16)
	skillLabel.Position = UDim2.new(0, 4, 0, 104)
	skillLabel.BackgroundTransparency = 1
	skillLabel.Text = `⚡ {skillText}`
	skillLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
	skillLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 10)
	skillLabel.Font = Enum.Font.Gotham
	skillLabel.TextTruncate = Enum.TextTruncate.AtEnd
	skillLabel.Parent = card

	-- 액션 버튼
	local btn = Instance.new("TextButton")
	btn.Name = "ActionBtn"
	btn.Size = UDim2.new(1, -12, 0, 30)
	btn.Position = UDim2.new(0, 6, 1, -36)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
	btn.Parent = card
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	btn.MouseButton1Click:Connect(function()
		self:_onCardClick(char.id)
	end)
end

-- ==================== 탭 전환 ====================

function CharacterSelectController:_switchTab(tab: string)
	self._activeTab = tab
	self:_refresh()

	if not self._panel then return end
	local tabBar = self._panel:FindFirstChild("TabBar")
	if not tabBar then return end

	for _, child in tabBar:GetChildren() do
		if child:IsA("TextButton") then
			if child.Name == tab then
				child.BackgroundColor3 = Color3.fromRGB(70, 90, 180)
				child.BackgroundTransparency = 0
				child.TextColor3 = Color3.fromRGB(255, 255, 255)
			else
				child.BackgroundColor3 = Color3.fromRGB(40, 40, 70)
				child.BackgroundTransparency = 0.5
				child.TextColor3 = Color3.fromRGB(160, 170, 200)
			end
		end
	end
end

-- ==================== 상태 갱신 ====================

function CharacterSelectController:_refresh()
	if not self._panel then
		return
	end
	local scroll = self._panel:FindFirstChild("CharacterGrid") :: ScrollingFrame?
	if not scroll then
		return
	end

	-- 재화 표시 업데이트
	local header = self._panel:FindFirstChild("Header")
	if header then
		local currency = header:FindFirstChild("Currency")
		if currency then
			local coinLabel = currency:FindFirstChild("CoinLabel") :: TextLabel?
			local gemLabel = currency:FindFirstChild("GemLabel") :: TextLabel?
			if coinLabel then coinLabel.Text = `🪙 {self._coins}` end
			if gemLabel then gemLabel.Text = `💎 {self._gems}` end
		end
	end

	for _, char in GameConstants.CHARACTERS.LIST do
		local card = scroll:FindFirstChild(char.id) :: Frame?
		if not card then
			continue
		end

		local owned = false
		for _, id in self._ownedCharacters do
			if id == char.id then
				owned = true
				break
			end
		end
		local equipped = (self._equippedCharacter == char.id)

		-- 탭에 따라 카드 표시 여부 결정
		if self._activeTab == "mine" then
			card.Visible = owned
		else
			-- 상점 탭: 미보유만 (default 제외)
			card.Visible = not owned and char.unlockType ~= "default"
		end

		local cardStroke = card:FindFirstChild("CardStroke") :: UIStroke?
		local btn = card:FindFirstChild("ActionBtn") :: TextButton?
		local emojiLabel = card:FindFirstChild("Emoji") :: TextLabel?

		if emojiLabel then
			emojiLabel.TextTransparency = 0
		end

		if owned then
			if equipped then
				if cardStroke then
					cardStroke.Color = Color3.fromRGB(80, 210, 80)
					cardStroke.Thickness = 3
				end
				if btn then
					btn.Text = "✓ 장착 중"
					btn.BackgroundColor3 = Color3.fromRGB(50, 130, 55)
					btn.TextColor3 = Color3.fromRGB(200, 255, 200)
					btn.Active = false
				end
			else
				if cardStroke then
					cardStroke.Color = Color3.fromRGB(80, 120, 200)
					cardStroke.Thickness = 2
				end
				if btn then
					btn.Text = "선택"
					btn.BackgroundColor3 = Color3.fromRGB(55, 95, 200)
					btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					btn.Active = true
				end
			end
		else
			-- 미보유: 구매 가능 여부에 따라 버튼 설정
			if cardStroke then
				cardStroke.Color = Color3.fromRGB(55, 55, 85)
				cardStroke.Thickness = 1
			end
			if emojiLabel then
				emojiLabel.TextTransparency = 0.35
			end

			if btn then
				if char.unlockType == "coins" then
					local canAfford = self._coins >= char.unlockValue
					btn.Text = `🪙 {char.unlockValue} 구매`
					btn.BackgroundColor3 = canAfford and Color3.fromRGB(150, 120, 20) or Color3.fromRGB(60, 50, 20)
					btn.TextColor3 = canAfford and Color3.fromRGB(255, 225, 80) or Color3.fromRGB(140, 120, 60)
					btn.Active = canAfford
				elseif char.unlockType == "gems" then
					local canAfford = self._gems >= char.unlockValue
					btn.Text = `💎 {char.unlockValue} 구매`
					btn.BackgroundColor3 = canAfford and Color3.fromRGB(80, 40, 160) or Color3.fromRGB(40, 25, 70)
					btn.TextColor3 = canAfford and Color3.fromRGB(210, 170, 255) or Color3.fromRGB(120, 100, 160)
					btn.Active = canAfford
				elseif char.unlockType == "level" then
					btn.Text = `Lv.{char.unlockValue} 해금`
					btn.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
					btn.TextColor3 = Color3.fromRGB(140, 150, 180)
					btn.Active = false
				elseif char.unlockType == "quest" then
					btn.Text = "퀘스트 달성"
					btn.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
					btn.TextColor3 = Color3.fromRGB(140, 150, 180)
					btn.Active = false
				elseif char.unlockType == "season" then
					btn.Text = "시즌 패스"
					btn.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
					btn.TextColor3 = Color3.fromRGB(140, 150, 180)
					btn.Active = false
				else
					btn.Text = "🔒 잠금"
					btn.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
					btn.TextColor3 = Color3.fromRGB(130, 130, 160)
					btn.Active = false
				end
			end
		end
	end
end

-- 캐릭터 카드 클릭
function CharacterSelectController:_onCardClick(characterId: string)
	local owned = false
	for _, id in self._ownedCharacters do
		if id == characterId then
			owned = true
			break
		end
	end

	if owned then
		-- 이미 장착 중이면 스킵
		if self._equippedCharacter == characterId then
			return
		end
		self._equippedCharacter = characterId
		RemoteEvents.EquipCharacter:FireServer({ characterId = characterId })
		self:_refresh()
	else
		-- 구매 가능한 경우 확인 팝업
		local char = characterMap[characterId]
		if not char then return end
		if char.unlockType ~= "coins" and char.unlockType ~= "gems" then return end

		self:_showConfirm(characterId)
	end
end

-- ==================== 구매 확인 팝업 ====================

function CharacterSelectController:_showConfirm(characterId: string)
	local char = characterMap[characterId]
	if not char or not self._confirmFrame then return end

	self._pendingBuyId = characterId

	local currencyIcon = char.unlockType == "gems" and "💎" or "🪙"
	local desc = self._confirmFrame:FindFirstChild("Desc") :: TextLabel?
	if desc then
		desc.Text = `{char.emoji} {char.name}\n{currencyIcon} {char.unlockValue}을 사용해 구매할까요?`
	end

	self._confirmFrame.Visible = true

	-- 팝업 페이드인
	self._confirmFrame.BackgroundTransparency = 1
	TweenService:Create(self._confirmFrame, TweenInfo.new(0.15), {
		BackgroundTransparency = 0.05,
	}):Play()
end

function CharacterSelectController:_hideConfirm()
	if self._confirmFrame then
		self._confirmFrame.Visible = false
	end
	self._pendingBuyId = nil
end

function CharacterSelectController:_confirmPurchase()
	local characterId = self._pendingBuyId
	if not characterId then return end

	self:_hideConfirm()
	RemoteEvents.BuyCharacter:FireServer({ characterId = characterId })
end

-- ==================== 이벤트 ====================

function CharacterSelectController:_setupEvents()
	-- 캐릭터 데이터 수신
	local conn1 = RemoteEvents.CharacterData.OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			self._ownedCharacters = data.ownedCharacters or { "runner" }
			self._equippedCharacter = data.equippedCharacter or "runner"
			self:_refresh()
		end
	end)
	table.insert(self._connections, conn1)

	-- 캐릭터 해금 알림
	local conn2 = RemoteEvents.CharacterUnlocked.OnClientEvent:Connect(function(data: any)
		if type(data) == "table" and type(data.characterId) == "string" then
			table.insert(self._ownedCharacters, data.characterId)
			self:_refresh()
		end
	end)
	table.insert(self._connections, conn2)

	-- 플레이어 데이터 로드 (재화 동기화)
	local conn3 = RemoteEvents.PlayerDataLoaded.OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			self._coins = data.coins or 0
			self._gems = data.gems or 0
			if self._isOpen then
				self:_refresh()
			end
		end
	end)
	table.insert(self._connections, conn3)

	-- 구매 결과 수신
	local conn4 = RemoteEvents.BuyCharacterResult.OnClientEvent:Connect(function(data: any)
		if type(data) ~= "table" then return end
		if data.success then
			-- 성공: 카드 상태 갱신 (CharacterData 재수신으로 처리됨)
			self:_switchTab("mine")
		else
			-- 실패 피드백 (간단 토스트)
			self:_showBuyError(data.reason)
		end
	end)
	table.insert(self._connections, conn4)

	-- 젬 업데이트 (구매/획득 시 즉시 반영)
	local conn5 = RemoteEvents.GemsUpdated.OnClientEvent:Connect(function(data: any)
		if type(data) == "table" and data.gems then
			self._gems = data.gems
			if self._isOpen then self:_refresh() end
		end
	end)
	table.insert(self._connections, conn5)
end

function CharacterSelectController:_showBuyError(reason: string?)
	if not self._panel then return end

	local msg = "구매 실패"
	if reason == "insufficient_funds" then
		msg = "재화가 부족합니다"
	elseif reason == "already_owned" then
		msg = "이미 보유한 캐릭터입니다"
	end

	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 220, 0, 36)
	toast.Position = UDim2.new(0.5, -110, 0, -46)
	toast.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	toast.BackgroundTransparency = 0.1
	toast.Text = `❌ {msg}`
	toast.TextColor3 = Color3.fromRGB(255, 220, 220)
	toast.TextSize = 13
	toast.Font = Enum.Font.GothamBold
	toast.ZIndex = 20
	toast.Parent = self._panel
	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)

	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -110, 0, 8),
	}):Play()

	task.delay(2, function()
		TweenService:Create(toast, TweenInfo.new(0.2), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}).Completed:Connect(function() toast:Destroy() end)
		TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	end)
end

-- ==================== 열기/닫기 ====================

function CharacterSelectController:Open()
	if not self._screenGui or not self._panel then
		return
	end
	local dim = self._screenGui:FindFirstChild("Dim")
	if dim then
		dim.Visible = true
	end
	self._panel.Visible = true
	self._panel.Position = UDim2.new(0.5, -self._panel.AbsoluteSize.X / 2, 1.1, 0)
	self._isOpen = true
	self:_switchTab("mine")

	TweenService:Create(self._panel, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		Position = ResponsiveUtil.clampedPosition(540, 520, 0.95, 0.92),
	}):Play()
end

function CharacterSelectController:Close()
	if not self._screenGui or not self._panel then
		return
	end
	self._isOpen = false
	self:_hideConfirm()
	local tween = TweenService:Create(self._panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
		Position = UDim2.new(0.5, -self._panel.AbsoluteSize.X / 2, 1.1, 0),
	})
	tween.Completed:Connect(function()
		if not self._isOpen then
			self._panel.Visible = false
			local dim = self._screenGui and self._screenGui:FindFirstChild("Dim")
			if dim then
				dim.Visible = false
			end
		end
	end)
	tween:Play()
end

function CharacterSelectController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
end

return CharacterSelectController

--!strict
-- Character Select Controller
-- 캐릭터 선택 UI (로비에서 캐릭터 + 펫 선택)

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
		_connections: { RBXScriptConnection },
		_isOpen: boolean,
		_skillCooldowns: { [string]: number },
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
		_connections = {},
		_isOpen = false,
		_skillCooldowns = {},
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
	panel.Size = ResponsiveUtil.clampedSize(520, 480, 0.94, 0.90)
	panel.Position = ResponsiveUtil.clampedPosition(520, 480, 0.94, 0.90)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
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

	-- 타이틀
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "캐릭터 선택"
	title.TextColor3 = Color3.fromRGB(200, 220, 255)
	title.TextSize = ResponsiveUtil.scaledTextSize(20, 16)
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	-- 닫기 버튼
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -44, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.5, 0)
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- 캐릭터 그리드 (ScrollingFrame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "CharacterGrid"
	scroll.Size = UDim2.new(1, -16, 1, -60)
	scroll.Position = UDim2.new(0, 8, 0, 52)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 140, 0, 160)
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
end

-- 캐릭터 카드 생성
function CharacterSelectController:_createCharacterCard(parent: ScrollingFrame, char: any)
	local card = Instance.new("Frame")
	card.Name = char.id
	card.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 10)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "CardStroke"
	cardStroke.Thickness = 2
	cardStroke.Color = Color3.fromRGB(60, 60, 100)
	cardStroke.Parent = card

	-- 이모지
	local emoji = Instance.new("TextLabel")
	emoji.Name = "Emoji"
	emoji.Size = UDim2.new(1, 0, 0, 50)
	emoji.Position = UDim2.new(0, 0, 0, 8)
	emoji.BackgroundTransparency = 1
	emoji.Text = char.emoji
	emoji.TextSize = 36
	emoji.Font = Enum.Font.GothamBold
	emoji.Parent = card

	-- 캐릭터 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -8, 0, 20)
	nameLabel.Position = UDim2.new(0, 4, 0, 60)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = char.name
	nameLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
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
	passiveLabel.Position = UDim2.new(0, 4, 0, 82)
	passiveLabel.BackgroundTransparency = 1
	passiveLabel.Text = passiveText
	passiveLabel.TextColor3 = Color3.fromRGB(150, 220, 150)
	passiveLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 10)
	passiveLabel.Font = Enum.Font.Gotham
	passiveLabel.TextTruncate = Enum.TextTruncate.AtEnd
	passiveLabel.Parent = card

	-- 스킬 이름
	local skillText = char.skill and char.skill.name or "스킬 없음"
	local skillLabel = Instance.new("TextLabel")
	skillLabel.Name = "Skill"
	skillLabel.Size = UDim2.new(1, -8, 0, 16)
	skillLabel.Position = UDim2.new(0, 4, 0, 100)
	skillLabel.BackgroundTransparency = 1
	skillLabel.Text = `⚡ {skillText}`
	skillLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
	skillLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 10)
	skillLabel.Font = Enum.Font.Gotham
	skillLabel.TextTruncate = Enum.TextTruncate.AtEnd
	skillLabel.Parent = card

	-- 선택/잠금 버튼
	local btn = Instance.new("TextButton")
	btn.Name = "SelectBtn"
	btn.Size = UDim2.new(1, -12, 0, 28)
	btn.Position = UDim2.new(0, 6, 1, -34)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
	btn.Parent = card
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	-- 해금 조건 텍스트 업데이트는 _refresh에서 처리
	btn.MouseButton1Click:Connect(function()
		self:_onCardClick(char.id)
	end)
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

		local cardStroke = card:FindFirstChild("CardStroke") :: UIStroke?
		local btn = card:FindFirstChild("SelectBtn") :: TextButton?
		local emojiLabel = card:FindFirstChild("Emoji") :: TextLabel?

		if equipped then
			if cardStroke then
				cardStroke.Color = Color3.fromRGB(100, 200, 100)
				cardStroke.Thickness = 3
			end
			if btn then
				btn.Text = "장착 중"
				btn.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				btn.Active = false
			end
		elseif owned then
			if cardStroke then
				cardStroke.Color = Color3.fromRGB(80, 120, 200)
				cardStroke.Thickness = 2
			end
			if btn then
				btn.Text = "선택"
				btn.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				btn.Active = true
			end
		else
			-- 미해금
			if cardStroke then
				cardStroke.Color = Color3.fromRGB(60, 60, 80)
				cardStroke.Thickness = 1
			end
			if emojiLabel then
				emojiLabel.TextTransparency = 0.6
			end
			-- 해금 조건 표시
			local unlockText = ""
			if char.unlockType == "coins" then
				unlockText = `🪙 {char.unlockValue}`
			elseif char.unlockType == "gems" then
				unlockText = `💎 {char.unlockValue}`
			elseif char.unlockType == "level" then
				unlockText = `Lv.{char.unlockValue}`
			elseif char.unlockType == "quest" then
				unlockText = "퀘스트 달성"
			elseif char.unlockType == "season" then
				unlockText = "시즌 패스"
			end
			if btn then
				btn.Text = `🔒 {unlockText}`
				btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
				btn.TextColor3 = Color3.fromRGB(150, 150, 180)
				btn.Active = false
			end
		end
	end
end

-- 캐릭터 카드 클릭
function CharacterSelectController:_onCardClick(characterId: string)
	-- 이미 장착 중이면 스킵
	if self._equippedCharacter == characterId then
		return
	end
	-- 보유 여부 확인
	local owned = false
	for _, id in self._ownedCharacters do
		if id == characterId then
			owned = true
			break
		end
	end
	if not owned then
		return
	end

	self._equippedCharacter = characterId
	RemoteEvents.EquipCharacter:FireServer({ characterId = characterId })
	self:_refresh()
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
	self:_refresh()

	TweenService:Create(self._panel, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		Position = ResponsiveUtil.clampedPosition(520, 480, 0.94, 0.90),
	}):Play()
end

function CharacterSelectController:Close()
	if not self._screenGui or not self._panel then
		return
	end
	self._isOpen = false
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

--!strict
-- Shop Controller
-- 상점 UI 관리

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local ShopController = {}
ShopController.__index = ShopController

export type ShopController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_playerGui: PlayerGui,
		_screenGui: ScreenGui?,
		_shopFrame: Frame?,
		_currentTab: string,
		_playerData: any?,
		_connections: { RBXScriptConnection },
		_isOpen: boolean,
	},
	ShopController
))

function ShopController.new(player: Player): ShopController
	local self = setmetatable({
		_player = player,
		_playerGui = player:WaitForChild("PlayerGui") :: PlayerGui,
		_screenGui = nil,
		_shopFrame = nil,
		_currentTab = "skins",
		_playerData = nil,
		_connections = {},
		_isOpen = false,
	}, ShopController)

	self:_createUI()
	self:_setupEventHandlers()

	return self
end

-- 상점 UI 생성
function ShopController:_createUI()
	-- ScreenGui 생성
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = self._playerGui
	self._screenGui = screenGui

	-- 상점 프레임 (초기 숨김)
	local shopFrame = Instance.new("Frame")
	shopFrame.Name = "ShopFrame"
	shopFrame.Size = UDim2.new(0, 500, 0, 450)
	shopFrame.Position = UDim2.new(0.5, -250, 0.5, -225)
	shopFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	shopFrame.BackgroundTransparency = 0.1
	shopFrame.Visible = false
	shopFrame.Parent = screenGui
	self._shopFrame = shopFrame

	-- 둥근 모서리
	local shopCorner = Instance.new("UICorner")
	shopCorner.CornerRadius = UDim.new(0, 20)
	shopCorner.Parent = shopFrame

	-- 테두리
	local shopStroke = Instance.new("UIStroke")
	shopStroke.Color = Color3.fromRGB(255, 215, 0)
	shopStroke.Thickness = 3
	shopStroke.Parent = shopFrame

	-- 상점 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 50)
	titleLabel.Position = UDim2.new(0, 0, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = 32
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "SHOP"
	titleLabel.Parent = shopFrame

	-- 보유 코인 표시
	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "CoinsLabel"
	coinsLabel.Size = UDim2.new(0, 200, 0, 30)
	coinsLabel.Position = UDim2.new(0.5, -100, 0, 55)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	coinsLabel.TextSize = 20
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.Text = "Coins: 0"
	coinsLabel.Parent = shopFrame

	-- 탭 버튼 컨테이너
	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.Size = UDim2.new(1, -40, 0, 40)
	tabContainer.Position = UDim2.new(0, 20, 0, 90)
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = shopFrame

	-- 탭 레이아웃
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabContainer

	-- 탭 버튼 생성
	local tabs = {
		{ id = "skins", name = "스킨" },
		{ id = "powerups", name = "파워업" },
		{ id = "revive", name = "부활권" },
	}

	for _, tab in tabs do
		local tabButton = Instance.new("TextButton")
		tabButton.Name = tab.id .. "Tab"
		tabButton.Size = UDim2.new(0, 130, 0, 35)
		tabButton.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
		tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		tabButton.TextSize = 18
		tabButton.Font = Enum.Font.GothamBold
		tabButton.Text = tab.name
		tabButton.Parent = tabContainer

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 8)
		tabCorner.Parent = tabButton

		tabButton.MouseButton1Click:Connect(function()
			self:_switchTab(tab.id)
		end)
	end

	-- 아이템 컨테이너
	local itemContainer = Instance.new("ScrollingFrame")
	itemContainer.Name = "ItemContainer"
	itemContainer.Size = UDim2.new(1, -40, 0, 230)
	itemContainer.Position = UDim2.new(0, 20, 0, 140)
	itemContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	itemContainer.BackgroundTransparency = 0.5
	itemContainer.ScrollBarThickness = 6
	itemContainer.ScrollingDirection = Enum.ScrollingDirection.Y
	itemContainer.Parent = shopFrame

	local itemCorner = Instance.new("UICorner")
	itemCorner.CornerRadius = UDim.new(0, 10)
	itemCorner.Parent = itemContainer

	local itemLayout = Instance.new("UIGridLayout")
	itemLayout.CellSize = UDim2.new(0, 130, 0, 100)
	itemLayout.CellPadding = UDim2.new(0, 15, 0, 15)
	itemLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	itemLayout.Parent = itemContainer

	local itemPadding = Instance.new("UIPadding")
	itemPadding.PaddingTop = UDim.new(0, 15)
	itemPadding.PaddingBottom = UDim.new(0, 15)
	itemPadding.PaddingLeft = UDim.new(0, 15)
	itemPadding.PaddingRight = UDim.new(0, 15)
	itemPadding.Parent = itemContainer

	-- 닫기 버튼
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -50, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 24
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "X"
	closeButton.Parent = shopFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		self:Close()
	end)

	print("[ShopController] UI created")
end

-- 이벤트 핸들러 설정
function ShopController:_setupEventHandlers()
	-- 플레이어 데이터 로드
	local dataConnection = RemoteEvents.PlayerDataLoaded.OnClientEvent:Connect(function(data)
		self._playerData = data
		self:_updateCoinsDisplay()
		if self._isOpen then
			self:_refreshCurrentTab()
		end
	end)
	table.insert(self._connections, dataConnection)

	-- 구매 결과
	local purchaseConnection = RemoteEvents.ShopPurchaseResult.OnClientEvent:Connect(function(data)
		if data.success then
			print(`[ShopController] Purchase successful: {data.itemType}/{data.itemId}`)
			-- 코인 업데이트
			if self._playerData then
				self._playerData.coins = data.newBalance
				self:_updateCoinsDisplay()
			end
		else
			print(`[ShopController] Purchase failed: {data.error}`)
			-- 에러 메시지 표시 (간단한 알림)
			self:_showNotification("Purchase Failed", data.error or "Unknown error")
		end
	end)
	table.insert(self._connections, purchaseConnection)

	print("[ShopController] Event handlers set up")
end

-- 탭 전환
function ShopController:_switchTab(tabId: string)
	self._currentTab = tabId

	-- 탭 버튼 스타일 업데이트
	if self._shopFrame then
		local tabContainer = self._shopFrame:FindFirstChild("TabContainer") :: Frame?
		if tabContainer then
			for _, child in tabContainer:GetChildren() do
				if child:IsA("TextButton") then
					local isActive = child.Name == tabId .. "Tab"
					child.BackgroundColor3 = isActive and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(80, 80, 100)
					child.TextColor3 = isActive and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
				end
			end
		end
	end

	self:_refreshCurrentTab()
end

-- 현재 탭 새로고침
function ShopController:_refreshCurrentTab()
	if not self._shopFrame then
		return
	end

	local itemContainer = self._shopFrame:FindFirstChild("ItemContainer") :: ScrollingFrame?
	if not itemContainer then
		return
	end

	-- 기존 아이템 제거
	for _, child in itemContainer:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if self._currentTab == "skins" then
		self:_populateSkins(itemContainer)
	elseif self._currentTab == "powerups" then
		self:_populatePowerups(itemContainer)
	elseif self._currentTab == "revive" then
		self:_populateReviveTickets(itemContainer)
	end

	-- 캔버스 크기 업데이트
	task.defer(function()
		local layout = itemContainer:FindFirstChild("UIGridLayout") :: UIGridLayout?
		if layout then
			itemContainer.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 30)
		end
	end)
end

-- 스킨 탭 채우기
function ShopController:_populateSkins(container: ScrollingFrame)
	for _, skin in GameConstants.SHOP.SKINS do
		local owned = self._playerData and self:_ownsSkin(skin.id) or skin.id == "default"
		local equipped = self._playerData and self._playerData.equippedSkin == skin.id or skin.id == "default"

		local itemFrame = self:_createItemFrame(container, {
			id = skin.id,
			name = skin.name,
			price = skin.price,
			owned = owned,
			equipped = equipped,
			itemType = "skin",
		})
	end
end

-- 파워업 탭 채우기
function ShopController:_populatePowerups(container: ScrollingFrame)
	for _, powerup in GameConstants.SHOP.START_POWERUPS do
		local count = self._playerData and self._playerData.startPowerups and self._playerData.startPowerups[powerup.id] or 0

		local itemFrame = self:_createItemFrame(container, {
			id = powerup.id,
			name = powerup.name,
			price = powerup.price,
			count = count,
			itemType = "start_powerup",
		})
	end
end

-- 부활권 탭 채우기
function ShopController:_populateReviveTickets(container: ScrollingFrame)
	local count = self._playerData and self._playerData.reviveTickets or 0

	local itemFrame = self:_createItemFrame(container, {
		id = "revive_ticket",
		name = "부활권",
		price = GameConstants.SHOP.REVIVE_TICKET_PRICE,
		count = count,
		itemType = "revive_ticket",
	})
end

-- 아이템 프레임 생성
function ShopController:_createItemFrame(container: ScrollingFrame, item: {
	id: string,
	name: string,
	price: number,
	owned: boolean?,
	equipped: boolean?,
	count: number?,
	itemType: string,
}): Frame
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = item.id
	itemFrame.Size = UDim2.new(0, 130, 0, 100)
	itemFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	itemFrame.Parent = container

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 8)
	frameCorner.Parent = itemFrame

	-- 아이템 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0, 25)
	nameLabel.Position = UDim2.new(0, 0, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = item.name
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = itemFrame

	-- 보유 개수 (파워업/부활권)
	if item.count ~= nil then
		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "Count"
		countLabel.Size = UDim2.new(1, 0, 0, 20)
		countLabel.Position = UDim2.new(0, 0, 0, 28)
		countLabel.BackgroundTransparency = 1
		countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		countLabel.TextSize = 12
		countLabel.Font = Enum.Font.Gotham
		countLabel.Text = `보유: {item.count}개`
		countLabel.Parent = itemFrame
	end

	-- 버튼
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, -20, 0, 30)
	button.Position = UDim2.new(0, 10, 1, -40)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Parent = itemFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

	if item.owned == true then
		if item.equipped == true then
			button.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			button.TextColor3 = Color3.fromRGB(200, 200, 200)
			button.Text = "장착중"
			button.Active = false
		else
			button.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
			button.TextColor3 = Color3.fromRGB(255, 255, 255)
			button.Text = "장착"
			button.MouseButton1Click:Connect(function()
				RemoteEvents.EquipSkin:FireServer({ skinId = item.id })
			end)
		end
	else
		button.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Text = `{item.price}`
		button.MouseButton1Click:Connect(function()
			RemoteEvents.ShopPurchase:FireServer({
				itemType = item.itemType,
				itemId = item.id,
			})
		end)
	end

	return itemFrame
end

-- 스킨 소유 여부 확인
function ShopController:_ownsSkin(skinId: string): boolean
	if not self._playerData or not self._playerData.ownedSkins then
		return skinId == "default"
	end

	for _, owned in self._playerData.ownedSkins do
		if owned == skinId then
			return true
		end
	end

	return false
end

-- 코인 표시 업데이트
function ShopController:_updateCoinsDisplay()
	if not self._shopFrame then
		return
	end

	local coinsLabel = self._shopFrame:FindFirstChild("CoinsLabel") :: TextLabel?
	if coinsLabel then
		local coins = self._playerData and self._playerData.coins or 0
		coinsLabel.Text = `Coins: {coins}`
	end
end

-- 알림 표시
function ShopController:_showNotification(title: string, message: string)
	-- 간단한 알림 (추후 개선 가능)
	print(`[ShopController] {title}: {message}`)
end

-- 상점 열기
function ShopController:Open()
	if not self._shopFrame then
		return
	end

	self._isOpen = true
	self._shopFrame.Visible = true
	self:_switchTab("skins")

	-- 등장 애니메이션
	self._shopFrame.Size = UDim2.new(0, 0, 0, 0)
	self._shopFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

	local tween = TweenService:Create(self._shopFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 500, 0, 450),
		Position = UDim2.new(0.5, -250, 0.5, -225),
	})
	tween:Play()

	print("[ShopController] Shop opened")
end

-- 상점 닫기
function ShopController:Close()
	if not self._shopFrame then
		return
	end

	self._isOpen = false

	-- 사라지는 애니메이션
	local tween = TweenService:Create(self._shopFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
	})
	tween:Play()
	tween.Completed:Connect(function()
		if self._shopFrame then
			self._shopFrame.Visible = false
		end
	end)

	print("[ShopController] Shop closed")
end

-- 상점 열림 상태 확인
function ShopController:IsOpen(): boolean
	return self._isOpen
end

-- 정리
function ShopController:Destroy()
	if self._screenGui then
		self._screenGui:Destroy()
	end

	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return ShopController

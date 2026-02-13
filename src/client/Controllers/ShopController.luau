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
		_hasVIP: boolean,
		_gems: number,
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
		_hasVIP = false,
		_gems = 0,
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
	coinsLabel.Size = UDim2.new(0, 150, 0, 30)
	coinsLabel.Position = UDim2.new(0.5, -155, 0, 55)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	coinsLabel.TextSize = 20
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.Text = "Coins: 0"
	coinsLabel.Parent = shopFrame

	-- 보유 젬 표시
	local gemsLabel = Instance.new("TextLabel")
	gemsLabel.Name = "GemsLabel"
	gemsLabel.Size = UDim2.new(0, 150, 0, 30)
	gemsLabel.Position = UDim2.new(0.5, 5, 0, 55)
	gemsLabel.BackgroundTransparency = 1
	gemsLabel.TextColor3 = Color3.fromRGB(170, 100, 255)
	gemsLabel.TextSize = 20
	gemsLabel.Font = Enum.Font.GothamBold
	gemsLabel.Text = "Gems: 0"
	gemsLabel.Parent = shopFrame

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
		{ id = "gems", name = "젬" },
	}

	for _, tab in tabs do
		local tabButton = Instance.new("TextButton")
		tabButton.Name = tab.id .. "Tab"
		tabButton.Size = UDim2.new(0, 100, 0, 35)
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
		self._gems = data.gems or 0
		self._hasVIP = data.hasVIP or false
		self:_updateCurrencyDisplay()
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
				self:_updateCurrencyDisplay()
			end
		else
			print(`[ShopController] Purchase failed: {data.error}`)
			-- 에러 메시지 표시 (간단한 알림)
			self:_showNotification("Purchase Failed", data.error or "Unknown error")
		end
	end)
	table.insert(self._connections, purchaseConnection)

	-- 젬 구매 결과
	local gemsResultConnection = RemoteEvents.PurchaseGemsResult.OnClientEvent:Connect(function(data)
		if data.success then
			print(`[ShopController] Gem purchase successful: +{data.gems} gems`)
			self._gems = data.gems or self._gems
			self:_updateCurrencyDisplay()
			self:_showNotification("Purchase Complete", `젬 {data.gems}개 획득!`)
		else
			print(`[ShopController] Gem purchase failed: {data.error}`)
			self:_showNotification("Purchase Failed", data.error or "Unknown error")
		end
	end)
	table.insert(self._connections, gemsResultConnection)

	-- 젬 잔액 업데이트
	local gemsUpdatedConnection = RemoteEvents.GemsUpdated.OnClientEvent:Connect(function(data)
		self._gems = data.gems or 0
		self:_updateCurrencyDisplay()
	end)
	table.insert(self._connections, gemsUpdatedConnection)

	-- VIP 상태 변경
	local vipConnection = RemoteEvents.VIPStatusChanged.OnClientEvent:Connect(function(data)
		self._hasVIP = data.hasVIP or false
		print(`[ShopController] VIP status changed: {self._hasVIP}`)
		-- 젬 탭이 열려 있으면 새로고침
		if self._isOpen and self._currentTab == "gems" then
			self:_refreshCurrentTab()
		end
	end)
	table.insert(self._connections, vipConnection)

	-- 상점 데이터 응답
	local shopDataConnection = RemoteEvents.ShopDataResponse.OnClientEvent:Connect(function(data)
		if data.playerCurrency then
			if self._playerData then
				self._playerData.coins = data.playerCurrency.coins
			end
			self._gems = data.playerCurrency.gems or 0
			self._hasVIP = data.playerCurrency.hasVIP or false
			self:_updateCurrencyDisplay()
		end
		if self._isOpen then
			self:_refreshCurrentTab()
		end
	end)
	table.insert(self._connections, shopDataConnection)

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
	elseif self._currentTab == "gems" then
		self:_populateGems(itemContainer)
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
			currency = skin.currency,
			thumbnailId = skin.thumbnailId,
			color = skin.color,
		})
	end
end

-- 파워업 탭 채우기
function ShopController:_populatePowerups(container: ScrollingFrame)
	for _, powerup in GameConstants.SHOP.START_POWERUPS do
		local count = self._playerData and self._playerData.startPowerups and self._playerData.startPowerups[powerup.id]
			or 0

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
function ShopController:_createItemFrame(
	container: ScrollingFrame,
	item: {
		id: string,
		name: string,
		price: number,
		owned: boolean?,
		equipped: boolean?,
		count: number?,
		itemType: string,
		currency: string?,
		thumbnailId: string?,
		color: Color3?,
	}
): Frame
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

	-- 스킨 썸네일 이미지 또는 색상 미리보기
	if item.thumbnailId then
		local thumbnail = Instance.new("ImageLabel")
		thumbnail.Name = "Thumbnail"
		thumbnail.Size = UDim2.new(0, 30, 0, 30)
		thumbnail.Position = UDim2.new(0.5, -15, 0, 28)
		thumbnail.BackgroundTransparency = 1
		thumbnail.Image = item.thumbnailId
		thumbnail.ScaleType = Enum.ScaleType.Fit
		thumbnail.Parent = itemFrame

		local thumbCorner = Instance.new("UICorner")
		thumbCorner.CornerRadius = UDim.new(0, 4)
		thumbCorner.Parent = thumbnail
	elseif item.color then
		local colorPreview = Instance.new("Frame")
		colorPreview.Name = "ColorPreview"
		colorPreview.Size = UDim2.new(0, 30, 0, 30)
		colorPreview.Position = UDim2.new(0.5, -15, 0, 28)
		colorPreview.BackgroundColor3 = item.color
		colorPreview.Parent = itemFrame

		local previewCorner = Instance.new("UICorner")
		previewCorner.CornerRadius = UDim.new(0, 4)
		previewCorner.Parent = colorPreview
	end

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
		local isGemCurrency = item.currency == "gems"
		button.BackgroundColor3 = isGemCurrency and Color3.fromRGB(130, 70, 200) or Color3.fromRGB(0, 180, 0)
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Text = isGemCurrency and `💎 {item.price}` or `{item.price}`
		if isGemCurrency then
			button.MouseButton1Click:Connect(function()
				self:_showConfirmPopup(
					`{item.name}을(를) 💎 {item.price} 젬에\n구매하시겠습니까?`,
					function()
						RemoteEvents.ShopPurchase:FireServer({
							itemType = item.itemType,
							itemId = item.id,
						})
					end
				)
			end)
		else
			button.MouseButton1Click:Connect(function()
				RemoteEvents.ShopPurchase:FireServer({
					itemType = item.itemType,
					itemId = item.id,
				})
			end)
		end
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

-- 재화 표시 통합 업데이트
function ShopController:_updateCurrencyDisplay()
	if not self._shopFrame then
		return
	end

	local coinsLabel = self._shopFrame:FindFirstChild("CoinsLabel") :: TextLabel?
	if coinsLabel then
		local coins = self._playerData and self._playerData.coins or 0
		coinsLabel.Text = `Coins: {coins}`
	end

	local gemsLabel = self._shopFrame:FindFirstChild("GemsLabel") :: TextLabel?
	if gemsLabel then
		gemsLabel.Text = `Gems: {self._gems}`
	end
end

-- 젬 상품 카드 생성
function ShopController:_createGemProductFrame(
	container: ScrollingFrame,
	product: {
		id: string,
		gems: number,
		robux: number,
		bonus: number,
		includesPet: boolean?,
	}
): Frame
	local frame = Instance.new("Frame")
	frame.Name = product.id
	frame.Size = UDim2.new(0, 130, 0, 100)
	frame.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
	frame.Parent = container

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 8)
	frameCorner.Parent = frame

	-- 상품명
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0, 22)
	nameLabel.Position = UDim2.new(0, 0, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(170, 100, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = `💎 {product.gems} 젬`
	nameLabel.Parent = frame

	-- 보너스 또는 펫 포함 텍스트
	local subText = ""
	if product.includesPet then
		subText = "펫 포함!"
	elseif product.bonus > 0 then
		subText = `+{product.bonus} 보너스`
	end

	if subText ~= "" then
		local bonusLabel = Instance.new("TextLabel")
		bonusLabel.Name = "Bonus"
		bonusLabel.Size = UDim2.new(1, 0, 0, 18)
		bonusLabel.Position = UDim2.new(0, 0, 0, 27)
		bonusLabel.BackgroundTransparency = 1
		bonusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		bonusLabel.TextSize = 12
		bonusLabel.Font = Enum.Font.GothamBold
		bonusLabel.Text = subText
		bonusLabel.Parent = frame
	end

	-- 구매 버튼
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, -20, 0, 30)
	button.Position = UDim2.new(0, 10, 1, -40)
	button.BackgroundColor3 = Color3.fromRGB(0, 150, 50)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Font = Enum.Font.GothamBold
	button.Text = `R$ {product.robux}`
	button.Parent = frame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = button

	button.MouseButton1Click:Connect(function()
		self:_showConfirmPopup(`💎 {product.gems} 젬을 R$ {product.robux}에\n구매하시겠습니까?`, function()
			RemoteEvents.PurchaseGems:FireServer({ productId = product.id })
		end)
	end)

	return frame
end

-- 젬 탭 채우기
function ShopController:_populateGems(container: ScrollingFrame)
	-- 젬 상품 카드
	for _, product in GameConstants.MONETIZATION.GEM_PRODUCTS do
		self:_createGemProductFrame(container, product)
	end

	-- VIP GamePass 카드
	local vipFrame = Instance.new("Frame")
	vipFrame.Name = "vip_pass"
	vipFrame.Size = UDim2.new(0, 130, 0, 100)
	vipFrame.BackgroundColor3 = Color3.fromRGB(80, 60, 20)
	vipFrame.Parent = container

	local vipCorner = Instance.new("UICorner")
	vipCorner.CornerRadius = UDim.new(0, 8)
	vipCorner.Parent = vipFrame

	local vipStroke = Instance.new("UIStroke")
	vipStroke.Color = Color3.fromRGB(255, 215, 0)
	vipStroke.Thickness = 2
	vipStroke.Parent = vipFrame

	-- VIP 이름
	local vipName = Instance.new("TextLabel")
	vipName.Name = "Name"
	vipName.Size = UDim2.new(1, 0, 0, 22)
	vipName.Position = UDim2.new(0, 0, 0, 5)
	vipName.BackgroundTransparency = 1
	vipName.TextColor3 = Color3.fromRGB(255, 215, 0)
	vipName.TextSize = 14
	vipName.Font = Enum.Font.GothamBold
	vipName.Text = "VIP PASS"
	vipName.Parent = vipFrame

	-- VIP 설명
	local vipDesc = Instance.new("TextLabel")
	vipDesc.Name = "Description"
	vipDesc.Size = UDim2.new(1, 0, 0, 18)
	vipDesc.Position = UDim2.new(0, 0, 0, 27)
	vipDesc.BackgroundTransparency = 1
	vipDesc.TextColor3 = Color3.fromRGB(255, 230, 150)
	vipDesc.TextSize = 11
	vipDesc.Font = Enum.Font.Gotham
	vipDesc.Text = "코인 2배 획득"
	vipDesc.Parent = vipFrame

	-- VIP 버튼
	local vipButton = Instance.new("TextButton")
	vipButton.Name = "Button"
	vipButton.Size = UDim2.new(1, -20, 0, 30)
	vipButton.Position = UDim2.new(0, 10, 1, -40)
	vipButton.TextSize = 14
	vipButton.Font = Enum.Font.GothamBold
	vipButton.Parent = vipFrame

	local vipBtnCorner = Instance.new("UICorner")
	vipBtnCorner.CornerRadius = UDim.new(0, 6)
	vipBtnCorner.Parent = vipButton

	if self._hasVIP then
		vipButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		vipButton.TextColor3 = Color3.fromRGB(200, 200, 200)
		vipButton.Text = "VIP 보유중"
		vipButton.Active = false
	else
		vipButton.BackgroundColor3 = Color3.fromRGB(200, 170, 0)
		vipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		vipButton.Text = "R$ 99"
		vipButton.MouseButton1Click:Connect(function()
			self:_showConfirmPopup(
				"VIP 패스를 R$ 99에 구매하시겠습니까?\n코인 획득 2배 효과!",
				function()
					RemoteEvents.PurchaseGems:FireServer({ productId = "vip_gamepass" })
				end
			)
		end)
	end
end

-- 알림 표시 (토스트 UI)
function ShopController:_showNotification(title: string, message: string)
	print(`[ShopController] {title}: {message}`)

	if not self._screenGui then
		return
	end

	-- 기존 토스트 제거
	local existing = self._screenGui:FindFirstChild("Toast")
	if existing then
		existing:Destroy()
	end

	-- 토스트 프레임
	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(0, 300, 0, 60)
	toast.Position = UDim2.new(0.5, -150, 0, -70)
	toast.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	toast.BackgroundTransparency = 0.1
	toast.Parent = self._screenGui

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 10)
	toastCorner.Parent = toast

	local toastStroke = Instance.new("UIStroke")
	toastStroke.Color = title == "Purchase Failed" and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 255, 80)
	toastStroke.Thickness = 2
	toastStroke.Parent = toast

	-- 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 25)
	titleLabel.Position = UDim2.new(0, 0, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = toastStroke.Color
	titleLabel.TextSize = 16
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = title
	titleLabel.Parent = toast

	-- 메시지
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Size = UDim2.new(1, 0, 0, 20)
	msgLabel.Position = UDim2.new(0, 0, 0, 30)
	msgLabel.BackgroundTransparency = 1
	msgLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	msgLabel.TextSize = 13
	msgLabel.Font = Enum.Font.Gotham
	msgLabel.Text = message
	msgLabel.TextTruncate = Enum.TextTruncate.AtEnd
	msgLabel.Parent = toast

	-- 슬라이드 인 애니메이션
	local tweenIn = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -150, 0, 20),
	})
	tweenIn:Play()

	-- 2초 후 사라짐
	task.delay(2, function()
		if toast and toast.Parent then
			local tweenOut =
				TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, -150, 0, -70),
				})
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				if toast and toast.Parent then
					toast:Destroy()
				end
			end)
		end
	end)
end

-- 구매 확인 팝업 (아동 보호)
function ShopController:_showConfirmPopup(message: string, onConfirm: () -> ())
	if not self._screenGui then
		return
	end

	-- Remove existing popup
	local existing = self._screenGui:FindFirstChild("ConfirmPopup")
	if existing then
		existing:Destroy()
	end

	-- Dim background
	local dim = Instance.new("Frame")
	dim.Name = "ConfirmPopup"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.Parent = self._screenGui

	-- Popup frame
	local popup = Instance.new("Frame")
	popup.Name = "PopupContent"
	popup.Size = UDim2.new(0, 300, 0, 180)
	popup.Position = UDim2.new(0.5, -150, 0.5, -90)
	popup.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	popup.Parent = dim

	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 16)
	popupCorner.Parent = popup

	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = Color3.fromRGB(255, 200, 0)
	popupStroke.Thickness = 2
	popupStroke.Parent = popup

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 35)
	titleLabel.Position = UDim2.new(0, 0, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
	titleLabel.TextSize = 20
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "구매 확인"
	titleLabel.Parent = popup

	-- Message
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Name = "Message"
	msgLabel.Size = UDim2.new(1, -20, 0, 55)
	msgLabel.Position = UDim2.new(0, 10, 0, 48)
	msgLabel.BackgroundTransparency = 1
	msgLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	msgLabel.TextSize = 16
	msgLabel.Font = Enum.Font.Gotham
	msgLabel.Text = message
	msgLabel.TextWrapped = true
	msgLabel.Parent = popup

	-- Close popup function
	local function closePopup()
		local tweenOut =
			TweenService:Create(popup, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0),
				Position = UDim2.new(0.5, 0, 0.5, 0),
			})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			if dim and dim.Parent then
				dim:Destroy()
			end
		end)
	end

	-- Confirm button
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Name = "ConfirmButton"
	confirmBtn.Size = UDim2.new(0, 120, 0, 40)
	confirmBtn.Position = UDim2.new(0.5, -130, 1, -55)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.TextSize = 18
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.Text = "확인"
	confirmBtn.Parent = popup

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmBtn

	-- Cancel button
	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Name = "CancelButton"
	cancelBtn.Size = UDim2.new(0, 120, 0, 40)
	cancelBtn.Position = UDim2.new(0.5, 10, 1, -55)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.TextSize = 18
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.Text = "취소"
	cancelBtn.Parent = popup

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 8)
	cancelCorner.Parent = cancelBtn

	-- Open animation
	popup.Size = UDim2.new(0, 0, 0, 0)
	popup.Position = UDim2.new(0.5, 0, 0.5, 0)

	local tweenIn = TweenService:Create(popup, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 300, 0, 180),
		Position = UDim2.new(0.5, -150, 0.5, -90),
	})
	tweenIn:Play()

	confirmBtn.MouseButton1Click:Connect(function()
		closePopup()
		onConfirm()
	end)

	cancelBtn.MouseButton1Click:Connect(function()
		closePopup()
	end)
end

-- 상점 열기
function ShopController:Open()
	if not self._shopFrame then
		return
	end

	self._isOpen = true
	self._shopFrame.Visible = true

	-- 서버에서 최신 상점 데이터 요청
	RemoteEvents.ShopDataRequest:FireServer()

	self:_switchTab("skins")

	-- 등장 애니메이션
	self._shopFrame.Size = UDim2.new(0, 0, 0, 0)
	self._shopFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

	local tween =
		TweenService:Create(self._shopFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
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
	local tween =
		TweenService:Create(self._shopFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
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

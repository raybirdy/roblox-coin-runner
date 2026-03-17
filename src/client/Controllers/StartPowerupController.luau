--!strict
-- Start Powerup Controller
-- 게임 시작 전 보유 파워업 선택 UI + 소모형 런 파워업 구매 UI

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local StartPowerupController = {}
StartPowerupController.__index = StartPowerupController

export type StartPowerupController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_playerGui: PlayerGui,
		_screenGui: ScreenGui?,
		_popupFrame: Frame?,
		_selectedPowerups: { string },
		_purchasedConsumables: { [string]: boolean },
		_playerCoins: number,
		_onConfirmCallback: (({ string }) -> ())?,
		_buyResultConn: RBXScriptConnection?,
	},
	StartPowerupController
))

function StartPowerupController.new(player: Player): StartPowerupController
	local self = setmetatable({
		_player = player,
		_playerGui = player:WaitForChild("PlayerGui") :: PlayerGui,
		_screenGui = nil,
		_popupFrame = nil,
		_selectedPowerups = {},
		_purchasedConsumables = {},
		_playerCoins = 0,
		_onConfirmCallback = nil,
		_buyResultConn = nil,
	}, StartPowerupController)

	self:_createUI()
	self:_listenBuyResult()

	return self
end

-- BuyConsumableResult 이벤트 수신 등록
function StartPowerupController:_listenBuyResult()
	self._buyResultConn = RemoteEvents.BuyConsumableResult.OnClientEvent:Connect(function(result: {
		success: boolean,
		powerupId: string,
		remainingCoins: number,
		error: string?,
	})
		self._playerCoins = result.remainingCoins
		if result.success then
			self._purchasedConsumables[result.powerupId] = true
		end
		self:_refreshConsumableSection()
	end)
end

-- UI 생성
function StartPowerupController:_createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StartPowerupUI"
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.DisplayOrder = 10
	screenGui.Parent = self._playerGui
	self._screenGui = screenGui

	-- 배경 딤
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Visible = false
	dim.Parent = screenGui

	dim.MouseButton1Click:Connect(function()
		self._selectedPowerups = {}
		self:_confirm()
	end)

	-- 팝업 프레임 (높이를 늘려서 소모형 섹션 포함)
	local popup = Instance.new("Frame")
	popup.Name = "PopupFrame"
	popup.Size = ResponsiveUtil.clampedSize(440, 480, 0.95, 0.88)
	popup.Position = ResponsiveUtil.clampedPosition(440, 480, 0.95, 0.88)
	popup.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	popup.BackgroundTransparency = 0.1
	popup.Visible = false
	popup.Parent = screenGui
	self._popupFrame = popup

	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, 16)
	popupCorner.Parent = popup

	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = Color3.fromRGB(100, 200, 255)
	popupStroke.Thickness = 2
	popupStroke.Parent = popup

	-- 타이틀
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.Position = UDim2.new(0, 0, 0, 8)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(100, 200, 255)
	title.TextSize = ResponsiveUtil.scaledTextSize(22, 15)
	title.Font = Enum.Font.GothamBold
	title.Text = "런 시작 준비"
	title.Parent = popup

	-- ===== 섹션 1: 시작 파워업 =====
	local sectionLabel1 = Instance.new("TextLabel")
	sectionLabel1.Name = "SectionLabel1"
	sectionLabel1.Size = UDim2.new(1, -20, 0, 22)
	sectionLabel1.Position = UDim2.new(0, 10, 0, 46)
	sectionLabel1.BackgroundTransparency = 1
	sectionLabel1.TextColor3 = Color3.fromRGB(180, 220, 255)
	sectionLabel1.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
	sectionLabel1.Font = Enum.Font.GothamBold
	sectionLabel1.Text = "보유 파워업"
	sectionLabel1.TextXAlignment = Enum.TextXAlignment.Left
	sectionLabel1.Parent = popup

	-- 시작 파워업 카드 컨테이너
	local cardContainer = Instance.new("Frame")
	cardContainer.Name = "CardContainer"
	cardContainer.Size = UDim2.new(1, -20, 0, 130)
	cardContainer.Position = UDim2.new(0, 10, 0, 70)
	cardContainer.BackgroundTransparency = 1
	cardContainer.Parent = popup

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	cardLayout.Padding = UDim.new(0, 10)
	cardLayout.Parent = cardContainer

	-- 구분선
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, -20, 0, 1)
	divider.Position = UDim2.new(0, 10, 0, 208)
	divider.BackgroundColor3 = Color3.fromRGB(80, 100, 140)
	divider.BorderSizePixel = 0
	divider.Parent = popup

	-- ===== 섹션 2: 소모형 파워업 =====
	local sectionLabel2 = Instance.new("TextLabel")
	sectionLabel2.Name = "SectionLabel2"
	sectionLabel2.Size = UDim2.new(1, -20, 0, 22)
	sectionLabel2.Position = UDim2.new(0, 10, 0, 215)
	sectionLabel2.BackgroundTransparency = 1
	sectionLabel2.TextColor3 = Color3.fromRGB(255, 220, 100)
	sectionLabel2.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
	sectionLabel2.Font = Enum.Font.GothamBold
	sectionLabel2.Text = "런 파워업 (코인 소비)"
	sectionLabel2.TextXAlignment = Enum.TextXAlignment.Left
	sectionLabel2.Parent = popup

	-- 코인 잔액 표시
	local coinLabel = Instance.new("TextLabel")
	coinLabel.Name = "CoinLabel"
	coinLabel.Size = UDim2.new(0, 120, 0, 22)
	coinLabel.Position = UDim2.new(1, -130, 0, 215)
	coinLabel.BackgroundTransparency = 1
	coinLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	coinLabel.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
	coinLabel.Font = Enum.Font.Gotham
	coinLabel.Text = "잔액: 0 코인"
	coinLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinLabel.Parent = popup

	-- 소모형 파워업 카드 컨테이너 (스크롤 없이 2x2 그리드)
	local consumableContainer = Instance.new("Frame")
	consumableContainer.Name = "ConsumableContainer"
	consumableContainer.Size = UDim2.new(1, -20, 0, 160)
	consumableContainer.Position = UDim2.new(0, 10, 0, 238)
	consumableContainer.BackgroundTransparency = 1
	consumableContainer.Parent = popup

	local consumableGrid = Instance.new("UIGridLayout")
	consumableGrid.CellSize = UDim2.new(0.5, -6, 0, 72)
	consumableGrid.CellPadding = UDim2.new(0, 8, 0, 8)
	consumableGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	consumableGrid.VerticalAlignment = Enum.VerticalAlignment.Top
	consumableGrid.Parent = consumableContainer

	-- 소모형 파워업 카드 생성
	for _, powerup in GameConstants.CONSUMABLE_POWERUPS do
		self:_createConsumableCard(consumableContainer, powerup)
	end

	-- 시작 버튼
	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.Size = UDim2.new(0, 200, 0, 42)
	startButton.Position = UDim2.new(0.5, -100, 1, -60)
	startButton.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
	startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	startButton.TextSize = ResponsiveUtil.scaledTextSize(18, 13)
	startButton.Font = Enum.Font.GothamBold
	startButton.Text = "게임 시작!"
	startButton.Parent = popup

	local startCorner = Instance.new("UICorner")
	startCorner.CornerRadius = UDim.new(0, 10)
	startCorner.Parent = startButton

	startButton.MouseButton1Click:Connect(function()
		self:_confirm()
	end)

	-- 건너뛰기 버튼
	local skipButton = Instance.new("TextButton")
	skipButton.Name = "SkipButton"
	skipButton.Size = UDim2.new(0, 140, 0, 36)
	skipButton.Position = UDim2.new(0.5, -70, 1, -28)
	skipButton.BackgroundTransparency = 1
	skipButton.TextColor3 = Color3.fromRGB(180, 180, 180)
	skipButton.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
	skipButton.Font = Enum.Font.Gotham
	skipButton.Text = "건너뛰기"
	skipButton.Parent = popup

	skipButton.MouseButton1Click:Connect(function()
		self._selectedPowerups = {}
		self:_confirm()
	end)
end

-- 소모형 파워업 카드 1개 생성
function StartPowerupController:_createConsumableCard(
	parent: Frame,
	powerup: { id: string, name: string, desc: string, coinCost: number }
)
	local card = Instance.new("Frame")
	card.Name = "CCard_" .. powerup.id
	card.BackgroundColor3 = Color3.fromRGB(40, 40, 62)
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 6)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(80, 80, 120)
	cardStroke.Thickness = 1
	cardStroke.Name = "CardStroke"
	cardStroke.Parent = card

	-- 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -4, 0, 18)
	nameLabel.Position = UDim2.new(0, 2, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	nameLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = powerup.name
	nameLabel.TextWrapped = true
	nameLabel.Parent = card

	-- 설명
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Desc"
	descLabel.Size = UDim2.new(1, -4, 0, 22)
	descLabel.Position = UDim2.new(0, 2, 0, 20)
	descLabel.BackgroundTransparency = 1
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.TextSize = ResponsiveUtil.scaledTextSize(10, 8)
	descLabel.Font = Enum.Font.Gotham
	descLabel.Text = powerup.desc
	descLabel.TextWrapped = true
	descLabel.Parent = card

	-- 구매 버튼
	local buyBtn = Instance.new("TextButton")
	buyBtn.Name = "BuyButton"
	buyBtn.Size = UDim2.new(1, -8, 0, 20)
	buyBtn.Position = UDim2.new(0, 4, 1, -24)
	buyBtn.BackgroundColor3 = Color3.fromRGB(200, 160, 30)
	buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyBtn.TextSize = ResponsiveUtil.scaledTextSize(10, 8)
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.Text = `{powerup.coinCost} 코인`
	buyBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 4)
	btnCorner.Parent = buyBtn

	buyBtn.MouseButton1Click:Connect(function()
		-- 이미 구매했으면 무시
		if self._purchasedConsumables[powerup.id] then
			return
		end
		-- 서버에 구매 요청
		RemoteEvents.BuyConsumable:FireServer(powerup.id)
	end)
end

-- 소모형 파워업 섹션 UI 갱신 (구매 결과 반영)
function StartPowerupController:_refreshConsumableSection()
	if not self._popupFrame then
		return
	end

	-- 코인 잔액 갱신
	local coinLabel = self._popupFrame:FindFirstChild("CoinLabel") :: TextLabel?
	if coinLabel then
		coinLabel.Text = `잔액: {self._playerCoins} 코인`
	end

	-- 각 카드 상태 갱신
	local consumableContainer = self._popupFrame:FindFirstChild("ConsumableContainer") :: Frame?
	if not consumableContainer then
		return
	end

	for _, powerup in GameConstants.CONSUMABLE_POWERUPS do
		local card = consumableContainer:FindFirstChild("CCard_" .. powerup.id) :: Frame?
		if not card then
			continue
		end

		local buyBtn = card:FindFirstChild("BuyButton") :: TextButton?
		local cardStroke = card:FindFirstChild("CardStroke") :: UIStroke?

		if self._purchasedConsumables[powerup.id] then
			-- 구매 완료 상태
			card.BackgroundColor3 = Color3.fromRGB(30, 70, 40)
			if cardStroke then
				cardStroke.Color = Color3.fromRGB(50, 200, 80)
			end
			if buyBtn then
				buyBtn.Text = "구매 완료"
				buyBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 50)
				buyBtn.Active = false
			end
		elseif self._playerCoins < powerup.coinCost then
			-- 코인 부족
			if buyBtn then
				buyBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 30)
				buyBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
			end
		else
			-- 구매 가능
			if buyBtn then
				buyBtn.BackgroundColor3 = Color3.fromRGB(200, 160, 30)
				buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end
end

-- 팝업 표시
function StartPowerupController:Show(playerData: any?, callback: ({ string }) -> ())
	self._onConfirmCallback = callback
	self._selectedPowerups = {}
	self._purchasedConsumables = {}

	-- 플레이어 코인 잔액 설정
	self._playerCoins = playerData and playerData.coins or 0

	if not self._popupFrame or not self._screenGui then
		-- UI가 없으면 바로 콜백
		callback({})
		return
	end

	-- 시작 파워업 확인
	local hasPowerups = false
	local startPowerups = playerData and playerData.startPowerups
	if startPowerups then
		for _, count in startPowerups do
			if count > 0 then
				hasPowerups = true
				break
			end
		end
	end

	-- 항상 팝업 표시 (소모형 파워업은 코인만 있으면 구매 가능)
	-- 카드 갱신
	if startPowerups then
		self:_populateCards(startPowerups)
	else
		-- 빈 카드 (보유 파워업 없음 표시)
		self:_populateCards({})
	end

	-- 소모형 섹션 초기 갱신
	self:_refreshConsumableSection()

	-- 표시
	local dim = self._screenGui:FindFirstChild("Dim") :: Frame?
	if dim then
		dim.Visible = true
	end
	self._popupFrame.Visible = true

	-- 등장 애니메이션
	self._popupFrame.Size = UDim2.new(0, 0, 0, 0)
	self._popupFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

	local tween =
		TweenService:Create(self._popupFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = ResponsiveUtil.clampedSize(440, 480, 0.95, 0.88),
			Position = ResponsiveUtil.clampedPosition(440, 480, 0.95, 0.88),
		})
	tween:Play()

	-- 코인 잔액 표시
	local coinLabel = self._popupFrame:FindFirstChild("CoinLabel") :: TextLabel?
	if coinLabel then
		coinLabel.Text = `잔액: {self._playerCoins} 코인`
	end

	-- hasPowerups가 false여도 소모형 파워업 때문에 표시는 유지
	-- (단, 보유 파워업도 소모형도 전혀 의미 없는 경우 = 코인도 없고 파워업도 없으면 바로 시작)
	local hasConsumableBudget = self._playerCoins > 0
	if not hasPowerups and not hasConsumableBudget then
		self._popupFrame.Visible = false
		if dim then
			dim.Visible = false
		end
		callback({})
	end
end

-- 카드 채우기 (시작 파워업)
function StartPowerupController:_populateCards(startPowerups: { [string]: number })
	if not self._popupFrame then
		return
	end

	local cardContainer = self._popupFrame:FindFirstChild("CardContainer") :: Frame?
	if not cardContainer then
		return
	end

	-- 기존 카드 제거
	for _, child in cardContainer:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for _, powerup in GameConstants.SHOP.START_POWERUPS do
		local count = startPowerups[powerup.id] or 0

		local card = Instance.new("Frame")
		card.Name = powerup.id
		card.Size = UDim2.new(0, 95, 0, 120)
		card.BackgroundColor3 = count > 0 and Color3.fromRGB(50, 50, 70) or Color3.fromRGB(40, 40, 50)
		card.Parent = cardContainer

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card

		-- 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(1, 0, 0, 35)
		nameLabel.Position = UDim2.new(0, 0, 0, 5)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = count > 0 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 100, 100)
		nameLabel.TextSize = ResponsiveUtil.scaledTextSize(12, 9)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = powerup.name
		nameLabel.TextWrapped = true
		nameLabel.Parent = card

		-- 보유 수
		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "Count"
		countLabel.Size = UDim2.new(1, 0, 0, 20)
		countLabel.Position = UDim2.new(0, 0, 0, 40)
		countLabel.BackgroundTransparency = 1
		countLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		countLabel.TextSize = ResponsiveUtil.scaledTextSize(11, 9)
		countLabel.Font = Enum.Font.Gotham
		countLabel.Text = `{count}개 보유`
		countLabel.Parent = card

		-- 선택 버튼
		local selectBtn = Instance.new("TextButton")
		selectBtn.Name = "SelectButton"
		selectBtn.Size = UDim2.new(1, -16, 0, 40)
		selectBtn.Position = UDim2.new(0, 8, 1, -48)
		selectBtn.TextSize = ResponsiveUtil.scaledTextSize(12, 9)
		selectBtn.Font = Enum.Font.GothamBold
		selectBtn.Parent = card

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = selectBtn

		if count > 0 then
			selectBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
			selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			selectBtn.Text = "선택"

			selectBtn.MouseButton1Click:Connect(function()
				self:_togglePowerup(powerup.id, card, selectBtn)
			end)
		else
			selectBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
			selectBtn.TextColor3 = Color3.fromRGB(80, 80, 80)
			selectBtn.Text = "미보유"
			selectBtn.Active = false
		end
	end
end

-- 파워업 토글
function StartPowerupController:_togglePowerup(powerupId: string, card: Frame, button: TextButton)
	local isSelected = table.find(self._selectedPowerups, powerupId)

	if isSelected then
		table.remove(self._selectedPowerups, isSelected)
		card.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
		button.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
		button.Text = "선택"
	else
		table.insert(self._selectedPowerups, powerupId)
		card.BackgroundColor3 = Color3.fromRGB(40, 80, 60)
		button.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
		button.Text = "선택됨"
	end
end

-- 확인 및 닫기
function StartPowerupController:_confirm()
	if not self._popupFrame or not self._screenGui then
		return
	end

	-- 닫기 애니메이션
	local tween =
		TweenService:Create(self._popupFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),
		})
	tween:Play()
	tween.Completed:Connect(function()
		if self._popupFrame then
			self._popupFrame.Visible = false
		end
		local dim = self._screenGui and self._screenGui:FindFirstChild("Dim") :: Frame?
		if dim then
			dim.Visible = false
		end
	end)

	-- 콜백 호출
	if self._onConfirmCallback then
		local cb = self._onConfirmCallback
		self._onConfirmCallback = nil
		cb(self._selectedPowerups)
	end
end

-- 정리
function StartPowerupController:Destroy()
	if self._buyResultConn then
		self._buyResultConn:Disconnect()
		self._buyResultConn = nil
	end
	if self._screenGui then
		self._screenGui:Destroy()
	end
end

return StartPowerupController

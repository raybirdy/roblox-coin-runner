--!strict
-- Start Powerup Controller
-- 게임 시작 전 보유 파워업 선택 UI

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
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
		_onConfirmCallback: (({ string }) -> ())?,
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
		_onConfirmCallback = nil,
	}, StartPowerupController)

	self:_createUI()

	return self
end

-- UI 생성
function StartPowerupController:_createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StartPowerupUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	screenGui.Parent = self._playerGui
	self._screenGui = screenGui

	-- 배경 딤
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.Visible = false
	dim.Parent = screenGui

	-- 팝업 프레임
	local popup = Instance.new("Frame")
	popup.Name = "PopupFrame"
	popup.Size = ResponsiveUtil.clampedSize(400, 300, 0.92, 0.75)
	popup.Position = ResponsiveUtil.clampedPosition(400, 300, 0.92, 0.75)
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
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(100, 200, 255)
	title.TextSize = ResponsiveUtil.scaledTextSize(24, 16)
	title.Font = Enum.Font.GothamBold
	title.Text = "시작 파워업 선택"
	title.Parent = popup

	-- 파워업 카드 컨테이너
	local cardContainer = Instance.new("Frame")
	cardContainer.Name = "CardContainer"
	cardContainer.Size = UDim2.new(1, -40, 0, 140)
	cardContainer.Position = UDim2.new(0, 20, 0, 55)
	cardContainer.BackgroundTransparency = 1
	cardContainer.Parent = popup

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.Padding = UDim.new(0, 15)
	cardLayout.Parent = cardContainer

	-- 시작 버튼
	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.Size = UDim2.new(0, 200, 0, 45)
	startButton.Position = UDim2.new(0.5, -100, 1, -65)
	startButton.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
	startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	startButton.TextSize = ResponsiveUtil.scaledTextSize(20, 14)
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
	skipButton.Size = UDim2.new(0, 140, 0, 44)
	skipButton.Position = UDim2.new(0.5, -70, 1, -38)
	skipButton.BackgroundTransparency = 1
	skipButton.TextColor3 = Color3.fromRGB(180, 180, 180)
	skipButton.TextSize = ResponsiveUtil.scaledTextSize(14, 11)
	skipButton.Font = Enum.Font.Gotham
	skipButton.Text = "건너뛰기"
	skipButton.Parent = popup

	skipButton.MouseButton1Click:Connect(function()
		self._selectedPowerups = {}
		self:_confirm()
	end)
end

-- 팝업 표시
function StartPowerupController:Show(playerData: any?, callback: ({ string }) -> ())
	self._onConfirmCallback = callback
	self._selectedPowerups = {}

	if not self._popupFrame or not self._screenGui then
		-- UI가 없으면 바로 콜백
		callback({})
		return
	end

	-- 보유 파워업 확인
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

	-- 보유 파워업이 없으면 바로 시작
	if not hasPowerups then
		callback({})
		return
	end

	-- 카드 갱신
	self:_populateCards(startPowerups)

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
			Size = ResponsiveUtil.clampedSize(400, 300, 0.92, 0.75),
			Position = ResponsiveUtil.clampedPosition(400, 300, 0.92, 0.75),
		})
	tween:Play()
end

-- 카드 채우기
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
		card.Size = UDim2.new(0, 100, 0, 130)
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
		nameLabel.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
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
		countLabel.TextSize = ResponsiveUtil.scaledTextSize(12, 10)
		countLabel.Font = Enum.Font.Gotham
		countLabel.Text = `{count}개 보유`
		countLabel.Parent = card

		-- 선택 버튼
		local selectBtn = Instance.new("TextButton")
		selectBtn.Name = "SelectButton"
		selectBtn.Size = UDim2.new(1, -16, 0, 44)
		selectBtn.Position = UDim2.new(0, 8, 1, -52)
		selectBtn.TextSize = ResponsiveUtil.scaledTextSize(13, 10)
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
	if self._screenGui then
		self._screenGui:Destroy()
	end
end

return StartPowerupController

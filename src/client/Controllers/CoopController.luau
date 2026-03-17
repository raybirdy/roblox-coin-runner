--!strict
-- CoopController
-- Co-op mode: matchmaking queue UI, partner state HUD, shared lives display

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local CoopController = {}
CoopController.__index = CoopController

type CoopState = {
	sessionId: string,
	partnerName: string,
	partnerUserId: number,
	myLane: string,
	partnerLives: number,
	partnerCombo: number,
	partnerIsAlive: boolean,
	sharedLives: number,
}

function CoopController.new()
	local self = setmetatable({}, CoopController)
	self._player = Players.LocalPlayer
	self._playerGui = self._player:WaitForChild("PlayerGui")
	self._state = nil :: CoopState?
	self._screenGui = nil :: ScreenGui?
	self._inQueue = false
	return self
end

function CoopController:Init()
	-- Listen for match found
	RemoteEvents.CoopMatchFound.OnClientEvent:Connect(function(data: { sessionId: string, partnerName: string, partnerUserId: number, myLane: string })
		self._inQueue = false
		self._state = {
			sessionId = data.sessionId,
			partnerName = data.partnerName,
			partnerUserId = data.partnerUserId,
			myLane = data.myLane,
			partnerLives = 5,
			partnerCombo = 0,
			partnerIsAlive = true,
			sharedLives = 5,
		}
		self:_hideQueueUI()
		self:_showMatchFoundBanner(data.partnerName)
		self:_buildHUD()
		print(string.format("[CoopController] Match found — partner: %s, lane: %s", data.partnerName, data.myLane))
	end)

	-- Listen for partner state updates
	RemoteEvents.CoopPartnerState.OnClientEvent:Connect(function(data: { lives: number, combo: number, isAlive: boolean })
		if not self._state then return end
		self._state.partnerLives = data.lives
		self._state.partnerCombo = data.combo
		self._state.partnerIsAlive = data.isAlive
		self:_updateHUD()
	end)

	-- Listen for game over
	RemoteEvents.CoopGameOver.OnClientEvent:Connect(function(data: { reason: string, score: number, partnerScore: number })
		self:_destroyHUD()
		self._state = nil
		if data.reason == "partner_left" then
			self:_showToast("파트너가 게임을 떠났습니다.")
		end
		print(string.format("[CoopController] Co-op game over — reason: %s", data.reason))
	end)

	print("[CoopController] Initialized")
end

-- Join co-op matchmaking queue
function CoopController:JoinQueue()
	if self._inQueue or self._state then return end
	self._inQueue = true
	RemoteEvents.CoopQueue:FireServer()
	self:_showQueueUI()
	print("[CoopController] Joined co-op queue")
end

-- Cancel co-op matchmaking queue
function CoopController:LeaveQueue()
	if not self._inQueue then return end
	self._inQueue = false
	RemoteEvents.CoopQueueCancel:FireServer()
	self:_hideQueueUI()
	print("[CoopController] Left co-op queue")
end

-- Returns current co-op state (nil if not in co-op)
function CoopController:GetState(): CoopState?
	return self._state
end

-- ========================== Private UI Methods ==========================

function CoopController:_showQueueUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CoopQueueGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = self._playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300, 0, 100)
	frame.Position = UDim2.new(0.5, -150, 0.85, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0.6, 0)
	label.Position = UDim2.new(0, 0, 0.05, 0)
	label.BackgroundTransparency = 1
	label.Text = "🤝 파트너 매칭 중..."
	label.TextColor3 = Color3.fromRGB(255, 220, 100)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0.5, 0, 0.35, 0)
	cancelBtn.Position = UDim2.new(0.25, 0, 0.62, 0)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	cancelBtn.Text = "취소"
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.TextScaled = true
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.Parent = frame
	Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 8)
	cancelBtn.MouseButton1Click:Connect(function()
		self:LeaveQueue()
	end)

	self._queueGui = screenGui
end

function CoopController:_hideQueueUI()
	if self._queueGui then
		self._queueGui:Destroy()
		self._queueGui = nil
	end
end

function CoopController:_showMatchFoundBanner(partnerName: string)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CoopMatchFoundGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = self._playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 400, 0, 80)
	frame.Position = UDim2.new(0.5, -200, -0.1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(30, 180, 100)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = string.format("🤝 %s 와 매칭 완료!", partnerName)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	-- Slide in from top
	local tweenIn = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -200, 0.05, 0),
	})
	tweenIn:Play()
	tweenIn.Completed:Connect(function()
		task.delay(2, function()
			local tweenOut = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Position = UDim2.new(0.5, -200, -0.15, 0),
			})
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				screenGui:Destroy()
			end)
		end)
	end)
end

function CoopController:_buildHUD()
	if self._hudGui then
		self._hudGui:Destroy()
	end
	if not self._state then return end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CoopHudGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = self._playerGui
	self._hudGui = screenGui

	-- Partner HUD panel (top-right)
	local panel = Instance.new("Frame")
	panel.Name = "PartnerPanel"
	panel.Size = UDim2.new(0, 200, 0, 80)
	panel.Position = UDim2.new(1, -210, 0, 10)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 50)
	panel.BackgroundTransparency = 0.3
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PartnerName"
	nameLabel.Size = UDim2.new(1, -10, 0.4, 0)
	nameLabel.Position = UDim2.new(0, 5, 0.02, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "🤝 " .. self._state.partnerName
	nameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = panel

	local livesLabel = Instance.new("TextLabel")
	livesLabel.Name = "PartnerLives"
	livesLabel.Size = UDim2.new(0.5, -5, 0.45, 0)
	livesLabel.Position = UDim2.new(0, 5, 0.47, 0)
	livesLabel.BackgroundTransparency = 1
	livesLabel.Text = "❤️ " .. tostring(self._state.partnerLives)
	livesLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	livesLabel.TextScaled = true
	livesLabel.Font = Enum.Font.Gotham
	livesLabel.TextXAlignment = Enum.TextXAlignment.Left
	livesLabel.Parent = panel

	local comboLabel = Instance.new("TextLabel")
	comboLabel.Name = "PartnerCombo"
	comboLabel.Size = UDim2.new(0.5, -5, 0.45, 0)
	comboLabel.Position = UDim2.new(0.5, 0, 0.47, 0)
	comboLabel.BackgroundTransparency = 1
	comboLabel.Text = "🔥 x" .. tostring(self._state.partnerCombo)
	comboLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
	comboLabel.TextScaled = true
	comboLabel.Font = Enum.Font.Gotham
	comboLabel.TextXAlignment = Enum.TextXAlignment.Left
	comboLabel.Parent = panel

	self._partnerPanel = panel
	self._partnerLivesLabel = livesLabel
	self._partnerComboLabel = comboLabel
	self._partnerNameLabel = nameLabel
end

function CoopController:_updateHUD()
	if not self._state or not self._partnerPanel then return end

	if self._partnerLivesLabel then
		self._partnerLivesLabel.Text = "❤️ " .. tostring(self._state.partnerLives)
		if not self._state.partnerIsAlive then
			self._partnerLivesLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
			if self._partnerNameLabel then
				self._partnerNameLabel.Text = "💀 " .. self._state.partnerName
			end
		end
	end
	if self._partnerComboLabel then
		self._partnerComboLabel.Text = "🔥 x" .. tostring(self._state.partnerCombo)
	end
end

function CoopController:_destroyHUD()
	if self._hudGui then
		self._hudGui:Destroy()
		self._hudGui = nil
	end
	self._partnerPanel = nil
	self._partnerLivesLabel = nil
	self._partnerComboLabel = nil
	self._partnerNameLabel = nil
end

function CoopController:_showToast(message: string)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CoopToastGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = self._playerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 320, 0, 56)
	frame.Position = UDim2.new(0.5, -160, 0.88, 0)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.Gotham
	label.Parent = frame

	task.delay(3, function()
		screenGui:Destroy()
	end)
end

return CoopController

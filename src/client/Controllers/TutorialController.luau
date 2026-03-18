--!strict
-- TutorialController (v3)
-- 5-step progressive tutorial with "Coiny" NPC guide

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local TutorialController = {}
TutorialController.__index = TutorialController

function TutorialController.new()
	local self = setmetatable({}, TutorialController)
	self._player = Players.LocalPlayer
	self._currentStep = nil :: number?
	self._stepConfig = nil :: any
	self._isActive = false
	self._connections = {} :: { RBXScriptConnection }
	self._gui = nil :: ScreenGui?
	self._completionCount = 0
	return self
end

function TutorialController:Init()
	-- Listen for lobby tutorial step
	local lobbyConn = RemoteEvents.TutorialLobbyStep.OnClientEvent:Connect(function(stepNumber: number, _stepConfig: any)
		self:StartLobbyStep(stepNumber)
	end)
	table.insert(self._connections, lobbyConn)

	print("[TutorialController] Initialized (v3 5-step)")
end

-- Start a tutorial step during a run (Step 1-4)
function TutorialController:Start(_startPosition: Vector3?, stepNumber: number?)
	if self._isActive then
		return
	end

	local step = stepNumber or 1
	local stepConfig = GameConstants.TUTORIAL.STEPS[step]
	if not stepConfig then
		return
	end

	self._currentStep = step
	self._stepConfig = stepConfig
	self._isActive = true
	self._completionCount = 0

	-- Create tutorial UI
	self:_createUI()
	self:_showCoinyBubble(stepConfig.npcMessage)
	self:_showSkipButton()

	-- Setup completion listener based on type
	self:_setupCompletionListener()

	-- Track analytics
	self:_trackEvent("start")

	print(`[TutorialController] Started step {step}: {stepConfig.id}`)
end

-- Start Step 5 (lobby mode)
function TutorialController:StartLobbyStep(stepNumber: number)
	if self._isActive then
		return
	end

	local stepConfig = GameConstants.TUTORIAL.STEPS[stepNumber]
	if not stepConfig then
		return
	end

	self._currentStep = stepNumber
	self._stepConfig = stepConfig
	self._isActive = true
	self._completionCount = 0

	self:_createUI()
	self:_showCoinyBubble(stepConfig.npcMessage)
	self:_showSkipButton()

	-- Step 5: detect proximity to Co-op portal
	if stepConfig.completionType == "portal_interact" then
		self:_setupPortalListener()
	end

	self:_trackEvent("start")
	print(`[TutorialController] Started lobby step {stepNumber}: {stepConfig.id}`)
end

-- Create the tutorial UI overlay
function TutorialController:_createUI()
	if self._gui then
		self._gui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = self._player.PlayerGui
	self._gui = gui
end

-- Show Coiny NPC speech bubble
function TutorialController:_showCoinyBubble(message: string)
	if not self._gui then
		return
	end

	-- Bubble container (bottom-right)
	local bubbleFrame = Instance.new("Frame")
	bubbleFrame.Name = "CoinyBubble"
	bubbleFrame.Size = UDim2.new(0, 320, 0, 120)
	bubbleFrame.Position = UDim2.new(1, -340, 1, -140)
	bubbleFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 240)
	bubbleFrame.BackgroundTransparency = 0.1
	bubbleFrame.Parent = self._gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = bubbleFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 50)
	stroke.Thickness = 3
	stroke.Parent = bubbleFrame

	-- Coiny icon (left side of bubble)
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "CoinyIcon"
	iconFrame.Size = UDim2.new(0, math.max(GameConstants.TUTORIAL.NPC_TOUCH_SIZE_MIN, 80), 0, math.max(GameConstants.TUTORIAL.NPC_TOUCH_SIZE_MIN, 80))
	iconFrame.Position = UDim2.new(0, -50, 0.5, -50)
	iconFrame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	iconFrame.Parent = bubbleFrame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = iconFrame

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "C"
	iconLabel.TextSize = 36
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.Parent = iconFrame

	-- NPC name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "CoinyName"
	nameLabel.Size = UDim2.new(1, -20, 0, 24)
	nameLabel.Position = UDim2.new(0, 40, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = GameConstants.TUTORIAL.NPC_NAME
	nameLabel.TextSize = 18
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = bubbleFrame

	-- Message text
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.Size = UDim2.new(1, -50, 1, -40)
	messageLabel.Position = UDim2.new(0, 40, 0, 36)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = message
	messageLabel.TextSize = 16
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextColor3 = Color3.fromRGB(60, 60, 60)
	messageLabel.TextWrapped = true
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Top
	messageLabel.Parent = bubbleFrame

	-- Entrance animation
	bubbleFrame.Position = UDim2.new(1, 0, 1, -140)
	TweenService:Create(
		bubbleFrame,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -340, 1, -140) }
	):Play()
end

-- Show skip button after delay
function TutorialController:_showSkipButton()
	if not self._gui then
		return
	end

	task.delay(GameConstants.TUTORIAL.SKIP_BUTTON_DELAY, function()
		if not self._isActive or not self._gui then
			return
		end

		local skipButton = Instance.new("TextButton")
		skipButton.Name = "SkipButton"
		skipButton.Size = UDim2.new(0, 120, 0, 36)
		skipButton.Position = UDim2.new(1, -140, 0, 20)
		skipButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		skipButton.BackgroundTransparency = 0.3
		skipButton.Text = "Skip Tutorial"
		skipButton.TextSize = 14
		skipButton.Font = Enum.Font.GothamBold
		skipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		skipButton.Parent = self._gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = skipButton

		skipButton.Activated:Connect(function()
			self:_onSkip()
		end)

		-- Fade in
		skipButton.BackgroundTransparency = 1
		skipButton.TextTransparency = 1
		TweenService:Create(skipButton, TweenInfo.new(0.3), {
			BackgroundTransparency = 0.3,
			TextTransparency = 0,
		}):Play()
	end)
end

-- Setup completion listener based on step type
function TutorialController:_setupCompletionListener()
	local stepConfig = self._stepConfig
	if not stepConfig then
		return
	end

	if stepConfig.completionType == "coin_collect" then
		local conn = RemoteEvents.CoinCollected.OnClientEvent:Connect(function()
			self._completionCount += 1
			if self._completionCount >= (stepConfig.completionTarget or 5) then
				self:_onComplete()
			end
		end)
		table.insert(self._connections, conn)

	elseif stepConfig.completionType == "action" then
		local actionName = stepConfig.completionAction
		if actionName == "jump" then
			-- Keyboard input
			local UIS = game:GetService("UserInputService")
			local inputConn = UIS.InputBegan:Connect(function(input, processed)
				if processed then return end
				if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
					task.delay(0.3, function()
						if self._isActive then
							self:_onComplete()
						end
					end)
				end
			end)
			table.insert(self._connections, inputConn)

			-- Touch swipe up
			local touchConn = UIS.TouchSwipe:Connect(function(direction)
				if direction == Enum.SwipeDirection.Up and self._isActive then
					task.delay(0.3, function()
						if self._isActive then
							self:_onComplete()
						end
					end)
				end
			end)
			table.insert(self._connections, touchConn)

		elseif actionName == "slide" then
			local UIS = game:GetService("UserInputService")
			local inputConn = UIS.InputBegan:Connect(function(input, processed)
				if processed then return end
				if input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then
					task.delay(0.3, function()
						if self._isActive then
							self:_onComplete()
						end
					end)
				end
			end)
			table.insert(self._connections, inputConn)

			local touchConn = UIS.TouchSwipe:Connect(function(direction)
				if direction == Enum.SwipeDirection.Down and self._isActive then
					task.delay(0.3, function()
						if self._isActive then
							self:_onComplete()
						end
					end)
				end
			end)
			table.insert(self._connections, touchConn)
		end

	elseif stepConfig.completionType == "powerup_collect" then
		local conn = RemoteEvents.PowerupCollected.OnClientEvent:Connect(function()
			self:_onComplete()
		end)
		table.insert(self._connections, conn)
	end
end

-- Setup portal proximity listener (Step 5, lobby)
function TutorialController:_setupPortalListener()
	local RunService = game:GetService("RunService")
	local CollectionService = game:GetService("CollectionService")

	local conn = RunService.Heartbeat:Connect(function()
		if not self._isActive then
			return
		end

		local character = self._player.Character
		if not character then
			return
		end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		-- Find Co-op portal
		local portals = CollectionService:GetTagged("CoopPortal")
		for _, portal in portals do
			if portal:IsA("BasePart") then
				local distance = (hrp.Position - portal.Position).Magnitude
				if distance <= 8 then
					self:_onComplete()
					return
				end
			end
		end
	end)
	table.insert(self._connections, conn)
end

-- Handle step completion
function TutorialController:_onComplete()
	if not self._isActive or not self._currentStep then
		return
	end

	local step = self._currentStep
	self._isActive = false

	-- Fire completion to server
	RemoteEvents.TutorialStepComplete:FireServer(step)

	-- Track analytics
	self:_trackEvent("complete")

	-- Show completion feedback
	self:_showCompletionFeedback()

	-- Cleanup after animation
	task.delay(1.5, function()
		self:_cleanup()
	end)

	print(`[TutorialController] Completed step {step}`)
end

-- Handle skip
function TutorialController:_onSkip()
	if not self._isActive then
		return
	end

	self._isActive = false

	-- Fire skip to server
	RemoteEvents.TutorialSkip:FireServer()

	-- Track analytics
	self:_trackEvent("skip")

	self:_cleanup()
	print("[TutorialController] Tutorial skipped")
end

-- Show completion feedback (checkmark + text)
function TutorialController:_showCompletionFeedback()
	if not self._gui then
		return
	end

	local feedbackLabel = Instance.new("TextLabel")
	feedbackLabel.Name = "CompletionFeedback"
	feedbackLabel.Size = UDim2.new(0, 300, 0, 60)
	feedbackLabel.Position = UDim2.new(0.5, -150, 0.4, 0)
	feedbackLabel.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	feedbackLabel.BackgroundTransparency = 0.2
	feedbackLabel.Text = "Great job!"
	feedbackLabel.TextSize = 28
	feedbackLabel.Font = Enum.Font.FredokaOne
	feedbackLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	feedbackLabel.Parent = self._gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = feedbackLabel

	-- Pop-in animation
	feedbackLabel.Size = UDim2.new(0, 0, 0, 0)
	feedbackLabel.Position = UDim2.new(0.5, 0, 0.4, 30)
	TweenService:Create(feedbackLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 300, 0, 60),
		Position = UDim2.new(0.5, -150, 0.4, 0),
	}):Play()
end

-- Track analytics event
function TutorialController:_trackEvent(action: string)
	pcall(function()
		RemoteEvents.AnalyticsTrack:FireServer("tutorial_step", {
			step = self._currentStep,
			stepId = self._stepConfig and self._stepConfig.id or "unknown",
			action = action,
		})
	end)
end

-- Stop tutorial (external call)
function TutorialController:Stop()
	self._isActive = false
	self:_cleanup()
end

-- Cleanup
function TutorialController:_cleanup()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}

	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end

	self._currentStep = nil
	self._stepConfig = nil
	self._completionCount = 0
end

function TutorialController:Destroy()
	self:_cleanup()
end

return TutorialController

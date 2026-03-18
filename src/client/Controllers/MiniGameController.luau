--!strict
-- MiniGameController (v3)
-- Client-side minigame transition effects and UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local MiniGameController = {}
MiniGameController.__index = MiniGameController

function MiniGameController.new()
	local self = setmetatable({}, MiniGameController)
	self._player = Players.LocalPlayer
	self._gui = nil :: ScreenGui?
	self._isActive = false
	self._connections = {} :: { RBXScriptConnection }
	self._hitsRemaining = 3
	self._timeRemaining = 0
	self._timerThread = nil :: thread?
	return self
end

function MiniGameController:Init()
	-- Listen for minigame start
	local startConn = RemoteEvents.MiniGameStart.OnClientEvent:Connect(function(data: any)
		self:_onMiniGameStart(data)
	end)
	table.insert(self._connections, startConn)

	-- Listen for minigame end
	local endConn = RemoteEvents.MiniGameEnd.OnClientEvent:Connect(function(data: any)
		self:_onMiniGameEnd(data)
	end)
	table.insert(self._connections, endConn)

	-- Listen for obstacle spawn
	local obstConn = RemoteEvents.MiniGameObstacle.OnClientEvent:Connect(function(data: any)
		self:_onObstacleSpawn(data)
	end)
	table.insert(self._connections, obstConn)

	-- Listen for hit notification
	local hitConn = RemoteEvents.MiniGameHit.OnClientEvent:Connect(function(data: any)
		self:_onHit(data)
	end)
	table.insert(self._connections, hitConn)

	print("[MiniGameController] Initialized")
end

-- Minigame start transition
function MiniGameController:_onMiniGameStart(data: any)
	self._isActive = true
	self._hitsRemaining = 3
	self._duration = data.duration or 20
	self._timeRemaining = data.duration or 20

	-- Create minigame UI
	self:_createUI()

	-- Flash "MINI GAME!" text
	self:_showFlashText("MINI GAME!", 0.8)

	-- Start timer countdown
	self._timerThread = task.spawn(function()
		while self._isActive and self._timeRemaining > 0 do
			task.wait(0.1)
			self._timeRemaining -= 0.1
			self:_updateTimerBar()
		end
	end)

	print(`[MiniGameController] Started: {data.gameTypeId}`)
end

-- Minigame end transition
function MiniGameController:_onMiniGameEnd(data: any)
	self._isActive = false

	if self._timerThread then
		task.cancel(self._timerThread)
		self._timerThread = nil
	end

	-- Show result
	if data.success then
		self:_showFlashText("CLEAR! +" .. (data.reward or 0) .. " coins", 1.5)
	else
		self:_showFlashText("FAILED!", 1.5)
	end

	-- Cleanup after result display
	task.delay(2, function()
		self:_cleanup()
	end)

	print(`[MiniGameController] Ended: success={data.success}, reward={data.reward}`)
end

-- Obstacle spawn visual
function MiniGameController:_onObstacleSpawn(data: any)
	if not self._isActive or not self._gui then
		return
	end

	local direction = data.direction or "left"
	local speed = data.speed or 1.0

	-- Create obstacle warning indicator
	local indicator = Instance.new("Frame")
	indicator.Name = "Obstacle_" .. (data.obstacleIndex or 0)
	indicator.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	indicator.BackgroundTransparency = 0.3
	indicator.Parent = self._gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = indicator

	local warningLabel = Instance.new("TextLabel")
	warningLabel.Size = UDim2.fromScale(1, 1)
	warningLabel.BackgroundTransparency = 1
	warningLabel.Text = "!"
	warningLabel.TextSize = 28
	warningLabel.Font = Enum.Font.FredokaOne
	warningLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	warningLabel.Parent = indicator

	-- Position based on direction
	if direction == "left" then
		indicator.Size = UDim2.new(0, 60, 0, 60)
		indicator.Position = UDim2.new(0, -60, 0.5, -30)
		TweenService:Create(indicator, TweenInfo.new(1.5 / speed, Enum.EasingStyle.Linear), {
			Position = UDim2.new(1, 60, 0.5, -30),
		}):Play()
	elseif direction == "right" then
		indicator.Size = UDim2.new(0, 60, 0, 60)
		indicator.Position = UDim2.new(1, 0, 0.5, -30)
		TweenService:Create(indicator, TweenInfo.new(1.5 / speed, Enum.EasingStyle.Linear), {
			Position = UDim2.new(0, -60, 0.5, -30),
		}):Play()
	else -- "top"
		indicator.Size = UDim2.new(0, 60, 0, 60)
		indicator.Position = UDim2.new(0.5, -30, 0, -60)
		TweenService:Create(indicator, TweenInfo.new(1.5 / speed, Enum.EasingStyle.Linear), {
			Position = UDim2.new(0.5, -30, 1, 60),
		}):Play()
	end

	-- Auto-cleanup after crossing screen
	task.delay(2 / speed, function()
		if indicator.Parent then
			indicator:Destroy()
		end
	end)

	-- Dodge button: player taps to dodge this obstacle
	local dodgeButton = Instance.new("TextButton")
	dodgeButton.Size = UDim2.fromScale(1, 1)
	dodgeButton.BackgroundTransparency = 1
	dodgeButton.Text = ""
	dodgeButton.Parent = indicator

	local dodged = false
	dodgeButton.Activated:Connect(function()
		if not dodged and self._isActive then
			dodged = true
			-- Report successful dodge to server
			RemoteEvents.MiniGameHitReport:FireServer({
				obstacleIndex = data.obstacleIndex,
			})
			-- Visual feedback: obstacle fades
			TweenService:Create(indicator, TweenInfo.new(0.2), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end)
end

-- Hit notification
function MiniGameController:_onHit(data: any)
	self._hitsRemaining = data.hitsRemaining or 0
	self:_updateHeartsUI()

	-- Screen shake effect
	local cameraShake = ReplicatedStorage:FindFirstChild("CameraShake")
	if cameraShake and cameraShake:IsA("BindableEvent") then
		(cameraShake :: BindableEvent):Fire(0.5)
	end
end

-- Create minigame overlay UI
function MiniGameController:_createUI()
	if self._gui then
		self._gui:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "MiniGameGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 90
	gui.Parent = self._player.PlayerGui
	self._gui = gui

	-- Timer bar (top)
	local timerBg = Instance.new("Frame")
	timerBg.Name = "TimerBg"
	timerBg.Size = UDim2.new(0.6, 0, 0, 12)
	timerBg.Position = UDim2.new(0.2, 0, 0, 40)
	timerBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	timerBg.BackgroundTransparency = 0.3
	timerBg.Parent = gui

	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = UDim.new(0, 6)
	timerCorner.Parent = timerBg

	local timerFill = Instance.new("Frame")
	timerFill.Name = "TimerFill"
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	timerFill.Parent = timerBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = timerFill

	-- Hearts (top-right)
	local heartsFrame = Instance.new("Frame")
	heartsFrame.Name = "Hearts"
	heartsFrame.Size = UDim2.new(0, 120, 0, 40)
	heartsFrame.Position = UDim2.new(1, -140, 0, 35)
	heartsFrame.BackgroundTransparency = 1
	heartsFrame.Parent = gui

	for i = 1, 3 do
		local heart = Instance.new("TextLabel")
		heart.Name = "Heart_" .. i
		heart.Size = UDim2.new(0, 36, 0, 36)
		heart.Position = UDim2.new(0, (i - 1) * 40, 0, 0)
		heart.BackgroundTransparency = 1
		heart.Text = "❤️"
		heart.TextSize = 28
		heart.Font = Enum.Font.FredokaOne
		heart.Parent = heartsFrame
	end

	-- Border glow (neon red)
	local border = Instance.new("Frame")
	border.Name = "MiniGameBorder"
	border.Size = UDim2.fromScale(1, 1)
	border.BackgroundTransparency = 1
	border.Parent = gui

	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Color3.fromRGB(255, 50, 50)
	borderStroke.Thickness = 4
	borderStroke.Transparency = 0.5
	borderStroke.Parent = border

	-- Pulse animation on border
	local pulseInfo = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(borderStroke, pulseInfo, { Transparency = 0.9 }):Play()
end

-- Update timer bar
function MiniGameController:_updateTimerBar()
	if not self._gui then
		return
	end

	local timerBg = self._gui:FindFirstChild("TimerBg")
	if not timerBg then
		return
	end

	local timerFill = timerBg:FindFirstChild("TimerFill")
	if timerFill then
		local duration = self._duration or 20
		local ratio = math.clamp(self._timeRemaining / duration, 0, 1)
		timerFill.Size = UDim2.fromScale(ratio, 1)

		-- Color change: green → yellow → red
		if ratio > 0.5 then
			timerFill.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
		elseif ratio > 0.25 then
			timerFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
		else
			timerFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		end
	end
end

-- Update hearts display
function MiniGameController:_updateHeartsUI()
	if not self._gui then
		return
	end

	local heartsFrame = self._gui:FindFirstChild("Hearts")
	if not heartsFrame then
		return
	end

	for i = 1, 3 do
		local heart = heartsFrame:FindFirstChild("Heart_" .. i)
		if heart then
			if i <= self._hitsRemaining then
				heart.Text = "❤️"
				heart.TextTransparency = 0
			else
				heart.Text = "🖤"
				heart.TextTransparency = 0.5
			end
		end
	end
end

-- Flash text effect
function MiniGameController:_showFlashText(text: string, duration: number)
	if not self._gui then
		return
	end

	local flash = Instance.new("TextLabel")
	flash.Name = "FlashText"
	flash.Size = UDim2.new(0, 400, 0, 80)
	flash.Position = UDim2.new(0.5, -200, 0.35, 0)
	flash.BackgroundTransparency = 1
	flash.Text = text
	flash.TextSize = 42
	flash.Font = Enum.Font.FredokaOne
	flash.TextColor3 = Color3.fromRGB(255, 255, 255)
	flash.TextStrokeTransparency = 0.3
	flash.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	flash.Parent = self._gui

	-- Scale-in animation
	flash.TextTransparency = 1
	flash.TextStrokeTransparency = 1

	TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		TextTransparency = 0,
		TextStrokeTransparency = 0.3,
	}):Play()

	-- Fade out
	task.delay(duration, function()
		if flash.Parent then
			TweenService:Create(flash, TweenInfo.new(0.3), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			task.delay(0.3, function()
				if flash.Parent then
					flash:Destroy()
				end
			end)
		end
	end)
end

-- Cleanup
function MiniGameController:_cleanup()
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	self._isActive = false
	self._hitsRemaining = 3
end

function MiniGameController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	self:_cleanup()
end

return MiniGameController

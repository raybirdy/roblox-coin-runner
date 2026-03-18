--!strict
-- ActiveSkillController (v3)
-- Client-side active skill button with cooldown overlay

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local ActiveSkillController = {}
ActiveSkillController.__index = ActiveSkillController

function ActiveSkillController.new()
	local self = setmetatable({}, ActiveSkillController)
	self._player = Players.LocalPlayer
	self._gui = nil :: ScreenGui?
	self._connections = {} :: { RBXScriptConnection }
	self._equippedSkill = nil :: string?
	self._unlockedSkills = {} :: { string }
	self._cooldownRemaining = 0
	self._cooldownTotal = 0
	self._isGameActive = false
	return self
end

function ActiveSkillController:Init()
	-- Listen for skill data
	local dataConn = RemoteEvents.ActiveSkillData.OnClientEvent:Connect(function(data: any)
		self._unlockedSkills = data.unlockedSkills or {}
		self._equippedSkill = data.equippedSkill
		self:_updateButtonVisibility()
	end)
	table.insert(self._connections, dataConn)

	-- Listen for skill activation confirmation
	local activatedConn = RemoteEvents.SkillActivated.OnClientEvent:Connect(function(data: any)
		self:_onSkillActivated(data)
	end)
	table.insert(self._connections, activatedConn)

	-- Listen for cooldown updates
	local cdConn = RemoteEvents.ActiveSkillCooldownUpdate.OnClientEvent:Connect(function(data: any)
		self._cooldownRemaining = data.remainingCooldown or 0
		self._cooldownTotal = data.totalCooldown or 0
		self:_startCooldownTimer()
	end)
	table.insert(self._connections, cdConn)

	print("[ActiveSkillController] Initialized")
end

-- Show skill button during game
function ActiveSkillController:OnGameStart()
	self._isGameActive = true
	self:_createUI()
end

-- Hide on game end
function ActiveSkillController:OnGameEnd()
	self._isGameActive = false
	self._cooldownRemaining = 0
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
end

-- Create skill button UI
function ActiveSkillController:_createUI()
	if not self._equippedSkill or not self._isGameActive then
		return
	end

	if self._gui then
		self._gui:Destroy()
	end

	local skillConfig = GameConstants.ACTIVE_SKILLS.SKILLS[self._equippedSkill]
	if not skillConfig then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ActiveSkillGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 80
	gui.Parent = self._player.PlayerGui
	self._gui = gui

	-- Skill button (bottom-right, above MiniGame area)
	local button = Instance.new("TextButton")
	button.Name = "SkillButton"
	button.Size = UDim2.new(0, 80, 0, 80)
	button.Position = UDim2.new(1, -100, 1, -220)
	button.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
	button.Text = skillConfig.emoji or "⚡"
	button.TextSize = 36
	button.Font = Enum.Font.FredokaOne
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 3
	stroke.Parent = button

	-- Cooldown overlay
	local cdOverlay = Instance.new("Frame")
	cdOverlay.Name = "CooldownOverlay"
	cdOverlay.Size = UDim2.fromScale(1, 0)
	cdOverlay.Position = UDim2.fromScale(0, 1)
	cdOverlay.AnchorPoint = Vector2.new(0, 1)
	cdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cdOverlay.BackgroundTransparency = 0.5
	cdOverlay.ZIndex = 2
	cdOverlay.Parent = button

	local cdCorner = Instance.new("UICorner")
	cdCorner.CornerRadius = UDim.new(1, 0)
	cdCorner.Parent = cdOverlay

	-- Cooldown text
	local cdText = Instance.new("TextLabel")
	cdText.Name = "CooldownText"
	cdText.Size = UDim2.fromScale(1, 1)
	cdText.BackgroundTransparency = 1
	cdText.Text = ""
	cdText.TextSize = 18
	cdText.Font = Enum.Font.GothamBold
	cdText.TextColor3 = Color3.fromRGB(255, 255, 255)
	cdText.ZIndex = 3
	cdText.Parent = button

	-- Button action
	button.Activated:Connect(function()
		if self._cooldownRemaining > 0 then
			return
		end
		RemoteEvents.SkillActivate:FireServer({ skillId = self._equippedSkill })
	end)
end

-- Handle skill activation feedback
function ActiveSkillController:_onSkillActivated(data: any)
	if not self._gui then
		return
	end

	local skillId = data.skillId
	local skillConfig = GameConstants.ACTIVE_SKILLS.SKILLS[skillId]
	if not skillConfig then
		return
	end

	-- Visual feedback: button flash
	local button = self._gui:FindFirstChild("SkillButton")
	if button then
		TweenService:Create(button, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(255, 255, 100),
		}):Play()
		task.delay(0.2, function()
			if button.Parent then
				TweenService:Create(button, TweenInfo.new(0.3), {
					BackgroundColor3 = Color3.fromRGB(60, 120, 220),
				}):Play()
			end
		end)
	end

	-- Camera shake for dash
	if skillId == "dash" then
		local cameraShake = ReplicatedStorage:FindFirstChild("CameraShake")
		if cameraShake and cameraShake:IsA("BindableEvent") then
			(cameraShake :: BindableEvent):Fire(0.3)
		end
	end
end

-- Start cooldown timer animation
function ActiveSkillController:_startCooldownTimer()
	if not self._gui then
		return
	end

	task.spawn(function()
		while self._cooldownRemaining > 0 and self._gui do
			task.wait(0.1)
			self._cooldownRemaining -= 0.1

			local button = self._gui and self._gui:FindFirstChild("SkillButton")
			if not button then
				break
			end

			local overlay = button:FindFirstChild("CooldownOverlay")
			local cdText = button:FindFirstChild("CooldownText")

			if overlay and self._cooldownTotal > 0 then
				local ratio = math.clamp(self._cooldownRemaining / self._cooldownTotal, 0, 1)
				overlay.Size = UDim2.fromScale(1, ratio)
			end

			if cdText then
				if self._cooldownRemaining > 0 then
					cdText.Text = tostring(math.ceil(self._cooldownRemaining))
				else
					cdText.Text = ""
				end
			end
		end

		-- Reset overlay when done
		if self._gui then
			local button = self._gui:FindFirstChild("SkillButton")
			if button then
				local overlay = button:FindFirstChild("CooldownOverlay")
				if overlay then
					overlay.Size = UDim2.fromScale(1, 0)
				end
			end
		end
	end)
end

-- Update button visibility
function ActiveSkillController:_updateButtonVisibility()
	if self._gui and not self._equippedSkill then
		self._gui:Destroy()
		self._gui = nil
	elseif self._equippedSkill and self._isGameActive and not self._gui then
		self:_createUI()
	end
end

function ActiveSkillController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
end

return ActiveSkillController

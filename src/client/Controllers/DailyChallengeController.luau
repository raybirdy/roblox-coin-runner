--!strict
-- DailyChallengeController (v3)
-- Client-side daily challenge UI widget

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local DailyChallengeController = {}
DailyChallengeController.__index = DailyChallengeController

function DailyChallengeController.new()
	local self = setmetatable({}, DailyChallengeController)
	self._player = Players.LocalPlayer
	self._connections = {} :: { RBXScriptConnection }
	self._gui = nil :: ScreenGui?
	self._challenges = {} :: { any }
	return self
end

function DailyChallengeController:Init()
	local dataConn = RemoteEvents.DailyChallengeData.OnClientEvent:Connect(function(data: any)
		self._challenges = data.challenges or {}
		self:_createUI()
	end)
	table.insert(self._connections, dataConn)

	local progressConn = RemoteEvents.DailyChallengeProgress.OnClientEvent:Connect(function(data: any)
		self:_updateProgress(data)
	end)
	table.insert(self._connections, progressConn)

	print("[DailyChallengeController] Initialized")
end

function DailyChallengeController:_createUI()
	if self._gui then
		self._gui:Destroy()
	end

	if #self._challenges == 0 then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DailyChallengeGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = self._player.PlayerGui
	self._gui = gui

	-- Challenge widget (top-left)
	local container = Instance.new("Frame")
	container.Name = "ChallengeContainer"
	container.Size = UDim2.new(0, 220, 0, 130)
	container.Position = UDim2.new(0, 10, 0, 120)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	container.BackgroundTransparency = 0.3
	container.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = container

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Text = "Daily Challenges"
	title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 200, 50)
	title.Parent = container

	-- Challenge entries
	for i, challenge in self._challenges do
		local entry = Instance.new("Frame")
		entry.Name = "Challenge_" .. i
		entry.Size = UDim2.new(1, -10, 0, 30)
		entry.Position = UDim2.new(0, 5, 0, 24 + (i - 1) * 32)
		entry.BackgroundTransparency = 1
		entry.Parent = container

		-- Description
		local desc = Instance.new("TextLabel")
		desc.Name = "Desc"
		desc.Size = UDim2.new(0.7, 0, 1, 0)
		desc.BackgroundTransparency = 1
		desc.Text = challenge.desc
		desc.TextSize = 11
		desc.Font = Enum.Font.Gotham
		desc.TextColor3 = challenge.completed and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(200, 200, 200)
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextTruncate = Enum.TextTruncate.AtEnd
		desc.Parent = entry

		-- Progress
		local progress = Instance.new("TextLabel")
		progress.Name = "Progress"
		progress.Size = UDim2.new(0.3, 0, 1, 0)
		progress.Position = UDim2.new(0.7, 0, 0, 0)
		progress.BackgroundTransparency = 1
		progress.Text = challenge.completed and "✓" or `{challenge.progress}/{challenge.target}`
		progress.TextSize = 12
		progress.Font = Enum.Font.GothamBold
		progress.TextColor3 = challenge.completed and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
		progress.TextXAlignment = Enum.TextXAlignment.Right
		progress.Parent = entry
	end
end

function DailyChallengeController:_updateProgress(data: any)
	if not self._gui then
		return
	end

	local index = data.challengeIndex
	local entry = self._gui:FindFirstChild("ChallengeContainer")
	if not entry then return end

	local challengeFrame = entry:FindFirstChild("Challenge_" .. index)
	if not challengeFrame then return end

	local progressLabel = challengeFrame:FindFirstChild("Progress")
	local descLabel = challengeFrame:FindFirstChild("Desc")

	if data.completed then
		if progressLabel then
			progressLabel.Text = "✓"
			progressLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end
		if descLabel then
			descLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end

		-- Flash effect
		if challengeFrame then
			local flash = Instance.new("Frame")
			flash.Size = UDim2.fromScale(1, 1)
			flash.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
			flash.BackgroundTransparency = 0.5
			flash.Parent = challengeFrame
			TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			task.delay(0.5, function()
				if flash.Parent then flash:Destroy() end
			end)
		end
	else
		if progressLabel then
			progressLabel.Text = `{data.progress}/{self._challenges[index] and self._challenges[index].target or "?"}`
		end
	end

	-- Update local state
	if self._challenges[index] then
		self._challenges[index].progress = data.progress
		self._challenges[index].completed = data.completed
	end
end

function DailyChallengeController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
end

return DailyChallengeController

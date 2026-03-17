--!strict
-- TeamController
-- Team creation/joining/leaving UI + weekly ranking display

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local TeamController = {}
TeamController.__index = TeamController

local _localPlayer = Players.LocalPlayer
local _teamData: any = nil
local _gui: ScreenGui? = nil

function TeamController.new()
	local self = setmetatable({}, TeamController)
	return self
end

function TeamController:Init()
	-- Listen for team data updates
	RemoteEvents.TeamData.OnClientEvent:Connect(function(data: any)
		_teamData = data
		self:_refreshUI()
	end)

	-- Listen for create result
	RemoteEvents.TeamCreateResult.OnClientEvent:Connect(function(result: any)
		self:_onCreateResult(result)
	end)

	-- Listen for join result
	RemoteEvents.TeamJoinResult.OnClientEvent:Connect(function(result: any)
		self:_onJoinResult(result)
	end)

	-- Listen for ranking data
	RemoteEvents.TeamRankData.OnClientEvent:Connect(function(rankings: any)
		self:_showRankings(rankings)
	end)
end

function TeamController:Show()
	self:_buildUI()
end

function TeamController:Hide()
	if _gui then
		(_gui :: ScreenGui):Destroy()
		_gui = nil
	end
end

function TeamController:_buildUI()
	if _gui then
		(_gui :: ScreenGui):Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TeamGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = _localPlayer.PlayerGui
	_gui = screenGui

	-- Dimmed overlay
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	-- Main panel
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 700, 0, 500)
	panel.Position = UDim2.new(0.5, -350, 0.5, -250)
	panel.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 50)
	title.Position = UDim2.new(0, 20, 0, 10)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(100, 200, 255)
	title.TextSize = 24
	title.Font = Enum.Font.GothamBold
	title.Text = "Team Weekly Ranking"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -50, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 20
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = panel

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:Hide()
	end)

	-- My team status label
	local myTeamLabel = Instance.new("TextLabel")
	myTeamLabel.Size = UDim2.new(1, -20, 0, 30)
	myTeamLabel.Position = UDim2.new(0, 10, 0, 65)
	myTeamLabel.BackgroundTransparency = 1
	myTeamLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	myTeamLabel.TextSize = 14
	myTeamLabel.Font = Enum.Font.Gotham
	if _teamData and _teamData.teamId ~= "" then
		myTeamLabel.Text = string.format(
			"My Team: %s  |  This week: %d coins",
			tostring(_teamData.teamName or "?"),
			_teamData.weeklyCoins or 0
		)
	else
		myTeamLabel.Text = "No team — create or join one below"
	end
	myTeamLabel.TextXAlignment = Enum.TextXAlignment.Left
	myTeamLabel.Parent = panel

	-- Action buttons row
	local btnY = 100
	if not (_teamData and _teamData.teamId ~= "") then
		-- Create team button
		local createBtn = Instance.new("TextButton")
		createBtn.Size = UDim2.new(0, 200, 0, 36)
		createBtn.Position = UDim2.new(0, 10, 0, btnY)
		createBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
		createBtn.Text = string.format("+ Create Team (%d coins)", GameConstants.TEAM.CREATE_COST)
		createBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		createBtn.TextSize = 13
		createBtn.Font = Enum.Font.GothamBold
		createBtn.BorderSizePixel = 0
		createBtn.Parent = panel

		local createBtnCorner = Instance.new("UICorner")
		createBtnCorner.CornerRadius = UDim.new(0, 8)
		createBtnCorner.Parent = createBtn

		createBtn.MouseButton1Click:Connect(function()
			self:_promptCreateTeam()
		end)

		-- Join team button
		local joinBtn = Instance.new("TextButton")
		joinBtn.Size = UDim2.new(0, 150, 0, 36)
		joinBtn.Position = UDim2.new(0, 220, 0, btnY)
		joinBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
		joinBtn.Text = "Join by Team ID"
		joinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		joinBtn.TextSize = 13
		joinBtn.Font = Enum.Font.GothamBold
		joinBtn.BorderSizePixel = 0
		joinBtn.Parent = panel

		local joinBtnCorner = Instance.new("UICorner")
		joinBtnCorner.CornerRadius = UDim.new(0, 8)
		joinBtnCorner.Parent = joinBtn

		joinBtn.MouseButton1Click:Connect(function()
			self:_promptJoinTeam()
		end)
	else
		-- Leave team button
		local leaveBtn = Instance.new("TextButton")
		leaveBtn.Size = UDim2.new(0, 120, 0, 36)
		leaveBtn.Position = UDim2.new(0, 10, 0, btnY)
		leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		leaveBtn.Text = "Leave Team"
		leaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		leaveBtn.TextSize = 13
		leaveBtn.Font = Enum.Font.GothamBold
		leaveBtn.BorderSizePixel = 0
		leaveBtn.Parent = panel

		local leaveBtnCorner = Instance.new("UICorner")
		leaveBtnCorner.CornerRadius = UDim.new(0, 8)
		leaveBtnCorner.Parent = leaveBtn

		leaveBtn.MouseButton1Click:Connect(function()
			RemoteEvents.TeamLeave:FireServer()
		end)
	end

	-- Refresh ranking button (top-right of action row)
	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size = UDim2.new(0, 150, 0, 36)
	refreshBtn.Position = UDim2.new(1, -170, 0, btnY)
	refreshBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
	refreshBtn.Text = "Refresh Ranking"
	refreshBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
	refreshBtn.TextSize = 12
	refreshBtn.Font = Enum.Font.Gotham
	refreshBtn.BorderSizePixel = 0
	refreshBtn.Parent = panel

	local refreshBtnCorner = Instance.new("UICorner")
	refreshBtnCorner.CornerRadius = UDim.new(0, 8)
	refreshBtnCorner.Parent = refreshBtn

	refreshBtn.MouseButton1Click:Connect(function()
		RemoteEvents.RequestTeamRanking:FireServer()
	end)

	-- Ranking scroll area
	local rankFrame = Instance.new("ScrollingFrame")
	rankFrame.Name = "RankFrame"
	rankFrame.Size = UDim2.new(1, -20, 1, -160)
	rankFrame.Position = UDim2.new(0, 10, 0, 150)
	rankFrame.BackgroundColor3 = Color3.fromRGB(10, 15, 30)
	rankFrame.BorderSizePixel = 0
	rankFrame.ScrollBarThickness = 4
	rankFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	rankFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rankFrame.Parent = panel

	local rankCorner = Instance.new("UICorner")
	rankCorner.CornerRadius = UDim.new(0, 8)
	rankCorner.Parent = rankFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = rankFrame

	-- Request initial ranking data
	RemoteEvents.RequestTeamRanking:FireServer()
end

function TeamController:_showRankings(rankings: any)
	local gui = _localPlayer.PlayerGui:FindFirstChild("TeamGui") :: ScreenGui?
	if not gui then return end

	local panel = gui:FindFirstChildOfClass("Frame")
	if not panel then return end

	local rankFrame = panel:FindFirstChild("RankFrame") :: ScrollingFrame?
	if not rankFrame then return end

	-- Clear previous rows
	for _, child in ipairs(rankFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Render ranking rows
	for _, entry in ipairs(rankings or {}) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundColor3 = entry.rank <= 3
			and Color3.fromRGB(40, 35, 10)
			or Color3.fromRGB(15, 20, 35)
		row.BorderSizePixel = 0
		row.LayoutOrder = entry.rank
		row.Parent = rankFrame

		-- Rank number
		local rankLabel = Instance.new("TextLabel")
		rankLabel.Size = UDim2.new(0, 50, 1, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.TextColor3 = entry.rank == 1
			and Color3.fromRGB(255, 220, 50)
			or Color3.fromRGB(180, 180, 180)
		rankLabel.TextSize = 16
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.Text = "#" .. tostring(entry.rank)
		rankLabel.Parent = row

		-- Team name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
		nameLabel.Position = UDim2.new(0, 55, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.Text = tostring(entry.teamName or entry.teamId)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		-- Coins
		local coinsLabel = Instance.new("TextLabel")
		coinsLabel.Size = UDim2.new(0.3, 0, 1, 0)
		coinsLabel.Position = UDim2.new(0.7, 0, 0, 0)
		coinsLabel.BackgroundTransparency = 1
		coinsLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		coinsLabel.TextSize = 14
		coinsLabel.Font = Enum.Font.GothamBold
		coinsLabel.Text = tostring(entry.weeklyCoins or 0) .. " coins"
		coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
		coinsLabel.Parent = row
	end

	-- Empty state
	if not rankings or #rankings == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(1, 0, 0, 50)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
		emptyLabel.TextSize = 14
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.Text = "No ranking data yet. Play a run to earn coins for your team!"
		emptyLabel.TextWrapped = true
		emptyLabel.Parent = rankFrame
	end
end

function TeamController:_promptCreateTeam()
	local screenGui = _localPlayer.PlayerGui:FindFirstChild("TeamGui") :: ScreenGui?
	if not screenGui then return end

	-- Avoid duplicate prompts
	if screenGui:FindFirstChild("CreatePrompt") then return end

	local promptFrame = Instance.new("Frame")
	promptFrame.Name = "CreatePrompt"
	promptFrame.Size = UDim2.new(0, 400, 0, 180)
	promptFrame.Position = UDim2.new(0.5, -200, 0.5, -90)
	promptFrame.BackgroundColor3 = Color3.fromRGB(25, 35, 60)
	promptFrame.BorderSizePixel = 0
	promptFrame.ZIndex = 10
	promptFrame.Parent = screenGui

	local promptCorner = Instance.new("UICorner")
	promptCorner.CornerRadius = UDim.new(0, 10)
	promptCorner.Parent = promptFrame

	local promptTitle = Instance.new("TextLabel")
	promptTitle.Size = UDim2.new(1, -20, 0, 40)
	promptTitle.Position = UDim2.new(0, 10, 0, 10)
	promptTitle.BackgroundTransparency = 1
	promptTitle.TextColor3 = Color3.fromRGB(200, 220, 255)
	promptTitle.TextSize = 18
	promptTitle.Font = Enum.Font.GothamBold
	promptTitle.Text = "Enter Team Name"
	promptTitle.Parent = promptFrame

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -20, 0, 40)
	textBox.Position = UDim2.new(0, 10, 0, 55)
	textBox.BackgroundColor3 = Color3.fromRGB(15, 20, 40)
	textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	textBox.PlaceholderText = "Team name (2-20 characters)"
	textBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
	textBox.TextSize = 16
	textBox.Font = Enum.Font.Gotham
	textBox.ClearTextOnFocus = false
	textBox.BorderSizePixel = 0
	textBox.Parent = promptFrame

	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(0, 8)
	tbCorner.Parent = textBox

	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(0, 120, 0, 36)
	confirmBtn.Position = UDim2.new(0.5, -130, 0, 110)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
	confirmBtn.Text = "Create"
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.TextSize = 14
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.BorderSizePixel = 0
	confirmBtn.Parent = promptFrame

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmBtn

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0, 100, 0, 36)
	cancelBtn.Position = UDim2.new(0.5, 20, 0, 110)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
	cancelBtn.Text = "Cancel"
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.TextSize = 14
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.BorderSizePixel = 0
	cancelBtn.Parent = promptFrame

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 8)
	cancelCorner.Parent = cancelBtn

	confirmBtn.MouseButton1Click:Connect(function()
		local name = textBox.Text
		if #name >= 2 and #name <= GameConstants.TEAM.MAX_TEAM_NAME_LENGTH then
			RemoteEvents.TeamCreate:FireServer(name)
			promptFrame:Destroy()
		end
	end)

	cancelBtn.MouseButton1Click:Connect(function()
		promptFrame:Destroy()
	end)
end

function TeamController:_promptJoinTeam()
	local screenGui = _localPlayer.PlayerGui:FindFirstChild("TeamGui") :: ScreenGui?
	if not screenGui then return end

	if screenGui:FindFirstChild("JoinPrompt") then return end

	local promptFrame = Instance.new("Frame")
	promptFrame.Name = "JoinPrompt"
	promptFrame.Size = UDim2.new(0, 400, 0, 180)
	promptFrame.Position = UDim2.new(0.5, -200, 0.5, -90)
	promptFrame.BackgroundColor3 = Color3.fromRGB(25, 35, 60)
	promptFrame.BorderSizePixel = 0
	promptFrame.ZIndex = 10
	promptFrame.Parent = screenGui

	local promptCorner = Instance.new("UICorner")
	promptCorner.CornerRadius = UDim.new(0, 10)
	promptCorner.Parent = promptFrame

	local promptTitle = Instance.new("TextLabel")
	promptTitle.Size = UDim2.new(1, -20, 0, 40)
	promptTitle.Position = UDim2.new(0, 10, 0, 10)
	promptTitle.BackgroundTransparency = 1
	promptTitle.TextColor3 = Color3.fromRGB(200, 220, 255)
	promptTitle.TextSize = 18
	promptTitle.Font = Enum.Font.GothamBold
	promptTitle.Text = "Enter Team ID"
	promptTitle.Parent = promptFrame

	local textBox = Instance.new("TextBox")
	textBox.Size = UDim2.new(1, -20, 0, 40)
	textBox.Position = UDim2.new(0, 10, 0, 55)
	textBox.BackgroundColor3 = Color3.fromRGB(15, 20, 40)
	textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	textBox.PlaceholderText = "Paste team ID here"
	textBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
	textBox.TextSize = 14
	textBox.Font = Enum.Font.Gotham
	textBox.ClearTextOnFocus = false
	textBox.BorderSizePixel = 0
	textBox.Parent = promptFrame

	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(0, 8)
	tbCorner.Parent = textBox

	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(0, 120, 0, 36)
	confirmBtn.Position = UDim2.new(0.5, -130, 0, 110)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
	confirmBtn.Text = "Join"
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.TextSize = 14
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.BorderSizePixel = 0
	confirmBtn.Parent = promptFrame

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmBtn

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0, 100, 0, 36)
	cancelBtn.Position = UDim2.new(0.5, 20, 0, 110)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
	cancelBtn.Text = "Cancel"
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.TextSize = 14
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.BorderSizePixel = 0
	cancelBtn.Parent = promptFrame

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 8)
	cancelCorner.Parent = cancelBtn

	confirmBtn.MouseButton1Click:Connect(function()
		local teamId = textBox.Text
		if #teamId > 0 then
			RemoteEvents.TeamJoin:FireServer(teamId)
			promptFrame:Destroy()
		end
	end)

	cancelBtn.MouseButton1Click:Connect(function()
		promptFrame:Destroy()
	end)
end

function TeamController:_onCreateResult(result: any)
	if not result.success then
		self:_showToast("Team creation failed: " .. tostring(result.reason or "unknown"))
	end
end

function TeamController:_onJoinResult(result: any)
	if not result.success then
		self:_showToast("Join failed: " .. tostring(result.reason or "unknown"))
	end
end

function TeamController:_showToast(message: string)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TeamToast"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 20
	screenGui.Parent = _localPlayer.PlayerGui

	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 320, 0, 50)
	toast.Position = UDim2.new(0.5, -160, 0.8, 0)
	toast.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	toast.TextColor3 = Color3.fromRGB(255, 150, 150)
	toast.TextSize = 15
	toast.Font = Enum.Font.Gotham
	toast.Text = message
	toast.TextWrapped = true
	toast.BorderSizePixel = 0
	toast.Parent = screenGui

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 8)
	toastCorner.Parent = toast

	task.delay(2.5, function()
		screenGui:Destroy()
	end)
end

function TeamController:_refreshUI()
	if _gui then
		self:Hide()
		self:Show()
	end
end

return TeamController

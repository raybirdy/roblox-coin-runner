--!strict
-- BattlePassController
-- 배틀패스 UI — 트랙 표시, 보상 수령, 구매

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local BattlePassController = {}
BattlePassController.__index = BattlePassController

local _localPlayer = Players.LocalPlayer
local _battlePassData: any = nil
local _gui: any = nil

function BattlePassController.new()
	local self = setmetatable({}, BattlePassController)
	return self
end

function BattlePassController:Init()
	-- Listen for battle pass data sync
	RemoteEvents.BattlePassData.OnClientEvent:Connect(function(data: any)
		_battlePassData = data
		self:_refreshUI()
	end)

	-- Listen for XP gained notifications
	RemoteEvents.BattlePassXPGained.OnClientEvent:Connect(function(info: any)
		self:_showXPGained(info)
	end)

	-- Listen for claim results
	RemoteEvents.BattlePassClaimResult.OnClientEvent:Connect(function(result: any)
		self:_onClaimResult(result)
	end)

	-- Listen for purchase results
	RemoteEvents.BattlePassPurchaseResult.OnClientEvent:Connect(function(result: any)
		if result.success then
			self:_showPurchaseSuccess()
		end
	end)
end

-- Show battle pass UI
function BattlePassController:Show()
	if not _battlePassData then return end
	self:_buildUI()
end

function BattlePassController:Hide()
	if _gui then
		_gui:Destroy()
		_gui = nil
	end
end

function BattlePassController:IsOpen(): boolean
	return _gui ~= nil
end

-- Build battle pass UI
function BattlePassController:_buildUI()
	if _gui then _gui:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BattlePassGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 20
	screenGui.Parent = _localPlayer.PlayerGui
	_gui = screenGui

	-- Background overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Parent = screenGui

	-- Main panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 920, 0, 520)
	panel.Position = UDim2.new(0.5, -460, 0.5, -260)
	panel.BackgroundColor3 = Color3.fromRGB(15, 15, 35)
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 60, 180)
	stroke.Thickness = 2
	stroke.Parent = panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -200, 0, 50)
	title.Position = UDim2.new(0, 20, 0, 10)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 50)
	title.TextSize = 26
	title.Font = Enum.Font.GothamBold
	title.Text = "BATTLE PASS — Season " .. tostring(_battlePassData and _battlePassData.seasonId or 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	-- Level / XP info
	local bp = _battlePassData or { level = 1, xp = 0, isPremium = false, claimedFree = {}, claimedPremium = {} }
	local xpNeeded = GameConstants.BATTLE_PASS.XP_PER_LEVEL[bp.level] or 1000
	local levelInfo = Instance.new("TextLabel")
	levelInfo.Name = "LevelInfo"
	levelInfo.Size = UDim2.new(0, 300, 0, 26)
	levelInfo.Position = UDim2.new(0, 20, 0, 56)
	levelInfo.BackgroundTransparency = 1
	levelInfo.TextColor3 = Color3.fromRGB(180, 180, 230)
	levelInfo.TextSize = 15
	levelInfo.Font = Enum.Font.Gotham
	levelInfo.Text = string.format("Level %d  |  %d / %d XP", bp.level, bp.xp, xpNeeded)
	levelInfo.TextXAlignment = Enum.TextXAlignment.Left
	levelInfo.Parent = panel

	-- XP progress bar background
	local xpBarBg = Instance.new("Frame")
	xpBarBg.Name = "XPBarBg"
	xpBarBg.Size = UDim2.new(0, 300, 0, 8)
	xpBarBg.Position = UDim2.new(0, 20, 0, 84)
	xpBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	xpBarBg.Parent = panel
	Instance.new("UICorner", xpBarBg).CornerRadius = UDim.new(1, 0)

	local xpBarFill = Instance.new("Frame")
	xpBarFill.Name = "XPBarFill"
	local fillRatio = if xpNeeded > 0 then math.clamp(bp.xp / xpNeeded, 0, 1) else 1
	xpBarFill.Size = UDim2.new(fillRatio, 0, 1, 0)
	xpBarFill.BackgroundColor3 = Color3.fromRGB(100, 80, 220)
	xpBarFill.Parent = xpBarBg
	Instance.new("UICorner", xpBarFill).CornerRadius = UDim.new(1, 0)

	-- Premium status / buy button
	local premiumBtn = Instance.new("TextButton")
	premiumBtn.Name = "PremiumBtn"
	premiumBtn.Size = UDim2.new(0, 170, 0, 44)
	premiumBtn.Position = UDim2.new(1, -220, 0, 15)
	premiumBtn.BackgroundColor3 = (bp.isPremium) and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(190, 140, 20)
	premiumBtn.Text = (bp.isPremium) and "PREMIUM 보유중" or "149 R$ 구매"
	premiumBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	premiumBtn.TextSize = 15
	premiumBtn.Font = Enum.Font.GothamBold
	premiumBtn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = premiumBtn

	if not bp.isPremium then
		premiumBtn.MouseButton1Click:Connect(function()
			self:_promptPurchase()
		end)
	end

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -52, 0, 12)
	closeBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:Hide()
	end)

	-- Track labels row
	local freeLabel = Instance.new("TextLabel")
	freeLabel.Size = UDim2.new(0, 100, 0, 20)
	freeLabel.Position = UDim2.new(0, 20, 0, 97)
	freeLabel.BackgroundTransparency = 1
	freeLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
	freeLabel.TextSize = 13
	freeLabel.Font = Enum.Font.GothamBold
	freeLabel.Text = "FREE TRACK"
	freeLabel.TextXAlignment = Enum.TextXAlignment.Left
	freeLabel.Parent = panel

	local premLabel = Instance.new("TextLabel")
	premLabel.Size = UDim2.new(0, 120, 0, 20)
	premLabel.Position = UDim2.new(0, 20, 0, 98)
	premLabel.BackgroundTransparency = 1
	premLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	premLabel.TextSize = 13
	premLabel.Font = Enum.Font.GothamBold
	premLabel.Text = "PREMIUM TRACK"
	premLabel.Position = UDim2.new(0, 20, 0, 390)
	premLabel.TextXAlignment = Enum.TextXAlignment.Left
	premLabel.Parent = panel

	-- Scroll frame for reward track
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "RewardTrack"
	scrollFrame.Size = UDim2.new(1, -20, 1, -120)
	scrollFrame.Position = UDim2.new(0, 10, 0, 110)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 80, 200)
	scrollFrame.CanvasSize = UDim2.new(0, GameConstants.BATTLE_PASS.MAX_LEVEL * 118 + 20, 0, 0)
	scrollFrame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = scrollFrame

	-- Render each level node
	for lvl = 1, GameConstants.BATTLE_PASS.MAX_LEVEL do
		self:_createLevelNode(scrollFrame, lvl, bp)
	end
end

function BattlePassController:_createLevelNode(parent: any, level: number, bp: any)
	local freeReward = GameConstants.BATTLE_PASS.FREE_REWARDS[level]
	local premiumReward = GameConstants.BATTLE_PASS.PREMIUM_REWARDS[level]
	local isUnlocked = bp.level >= level
	local claimedFree = bp.claimedFree[tostring(level)]
	local claimedPremium = bp.claimedPremium[tostring(level)]

	local node = Instance.new("Frame")
	node.Name = "Level" .. level
	node.Size = UDim2.new(0, 112, 1, -10)
	node.BackgroundColor3 = isUnlocked and Color3.fromRGB(28, 36, 65) or Color3.fromRGB(18, 18, 28)
	node.LayoutOrder = level
	node.Parent = parent

	local nodeCorner = Instance.new("UICorner")
	nodeCorner.CornerRadius = UDim.new(0, 8)
	nodeCorner.Parent = node

	-- Current level indicator
	if bp.level == level then
		local nodeStroke = Instance.new("UIStroke")
		nodeStroke.Color = Color3.fromRGB(120, 100, 255)
		nodeStroke.Thickness = 2
		nodeStroke.Parent = node
	end

	-- Level number label
	local lvlLabel = Instance.new("TextLabel")
	lvlLabel.Size = UDim2.new(1, 0, 0, 22)
	lvlLabel.Position = UDim2.new(0, 0, 0, 4)
	lvlLabel.BackgroundTransparency = 1
	lvlLabel.TextColor3 = isUnlocked and Color3.fromRGB(200, 200, 255) or Color3.fromRGB(100, 100, 130)
	lvlLabel.TextSize = 13
	lvlLabel.Font = Enum.Font.GothamBold
	lvlLabel.Text = "Lv." .. level
	lvlLabel.Parent = node

	-- Free reward button
	if freeReward then
		local freeBtn = Instance.new("TextButton")
		freeBtn.Size = UDim2.new(1, -8, 0, 58)
		freeBtn.Position = UDim2.new(0, 4, 0, 30)

		if claimedFree then
			freeBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 55)
			freeBtn.Text = "Claimed"
		elseif isUnlocked then
			freeBtn.BackgroundColor3 = Color3.fromRGB(35, 80, 150)
			freeBtn.Text = self:_rewardLabel(freeReward)
		else
			freeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
			freeBtn.Text = self:_rewardLabel(freeReward)
		end

		freeBtn.TextColor3 = Color3.fromRGB(220, 220, 255)
		freeBtn.TextSize = 11
		freeBtn.Font = Enum.Font.Gotham
		freeBtn.TextWrapped = true
		freeBtn.Parent = node

		local freeBtnCorner = Instance.new("UICorner")
		freeBtnCorner.CornerRadius = UDim.new(0, 6)
		freeBtnCorner.Parent = freeBtn

		if isUnlocked and not claimedFree then
			freeBtn.MouseButton1Click:Connect(function()
				RemoteEvents.BattlePassClaim:FireServer(level, false)
			end)
		end
	end

	-- Premium reward button
	if premiumReward then
		local premBtn = Instance.new("TextButton")
		premBtn.Size = UDim2.new(1, -8, 0, 58)
		premBtn.Position = UDim2.new(0, 4, 0, 95)

		local isPrem = bp.isPremium
		if claimedPremium then
			premBtn.BackgroundColor3 = Color3.fromRGB(100, 75, 15)
			premBtn.Text = "Claimed"
			premBtn.TextColor3 = Color3.fromRGB(255, 210, 80)
		elseif not isPrem then
			premBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
			premBtn.Text = "PREMIUM"
			premBtn.TextColor3 = Color3.fromRGB(100, 100, 100)
		elseif isUnlocked then
			premBtn.BackgroundColor3 = Color3.fromRGB(150, 110, 15)
			premBtn.Text = self:_rewardLabel(premiumReward)
			premBtn.TextColor3 = Color3.fromRGB(255, 220, 60)
		else
			premBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 18)
			premBtn.Text = self:_rewardLabel(premiumReward)
			premBtn.TextColor3 = Color3.fromRGB(160, 140, 60)
		end

		premBtn.TextSize = 11
		premBtn.Font = Enum.Font.Gotham
		premBtn.TextWrapped = true
		premBtn.Parent = node

		local premBtnCorner = Instance.new("UICorner")
		premBtnCorner.CornerRadius = UDim.new(0, 6)
		premBtnCorner.Parent = premBtn

		if isUnlocked and isPrem and not claimedPremium then
			premBtn.MouseButton1Click:Connect(function()
				RemoteEvents.BattlePassClaim:FireServer(level, true)
			end)
		end
	end
end

function BattlePassController:_rewardLabel(reward: any): string
	local t = reward.type
	if t == "coins" then
		return tostring(reward.amount) .. " Coins"
	elseif t == "gems" then
		return tostring(reward.amount) .. " Gems"
	elseif t == "skin" then
		return reward.id .. " Skin"
	elseif t == "pet" then
		return reward.id .. " Pet"
	elseif t == "character" then
		return reward.id
	elseif t == "nametag" then
		return reward.id
	else
		return tostring(reward.type)
	end
end

function BattlePassController:_showXPGained(info: any)
	-- Destroy existing notification if any
	local existing = _localPlayer.PlayerGui:FindFirstChild("BattlePassXPGui")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BattlePassXPGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25
	gui.Parent = _localPlayer.PlayerGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 220, 0, 44)
	label.Position = UDim2.new(0.5, -110, 0.15, 0)
	label.BackgroundColor3 = Color3.fromRGB(40, 40, 130)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Color3.fromRGB(180, 200, 255)
	label.TextSize = 17
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("+%d BP XP", info.xpGained or 0)
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	if info.leveled then
		label.Text = label.Text .. string.format("  Lv.%d!", info.newLevel or 1)
		label.TextColor3 = Color3.fromRGB(255, 220, 50)
	end

	task.delay(2.5, function()
		if gui and gui.Parent then
			gui:Destroy()
		end
	end)
end

function BattlePassController:_onClaimResult(result: any)
	if result.success then
		-- Refresh UI if open
		if _battlePassData then
			-- Update local claimed state optimistically
			self:_refreshUI()
		end
	end
end

function BattlePassController:_promptPurchase()
	local MarketplaceService = game:GetService("MarketplaceService")
	local passId = GameConstants.BATTLE_PASS.GAME_PASS_ID
	if passId and passId > 0 then
		MarketplaceService:PromptGamePassPurchase(_localPlayer, passId)
	else
		-- Studio: request via server
		RemoteEvents.PurchaseGems:FireServer({ productId = "battle_pass" })
	end
end

function BattlePassController:_showPurchaseSuccess()
	self:_refreshUI()
end

function BattlePassController:_refreshUI()
	if _gui then
		self:Hide()
		self:Show()
	end
end

return BattlePassController

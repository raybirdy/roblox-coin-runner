--!strict
-- Referral Controller
-- 친구 초대 버튼 및 보상 알림 처리

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local ReferralController = {}
ReferralController.__index = ReferralController

export type ReferralController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_connections: { RBXScriptConnection },
		_rewardPopup: ScreenGui?,
	},
	ReferralController
))

function ReferralController.new(player: Player): ReferralController
	local self = setmetatable({
		_player = player,
		_connections = {},
		_rewardPopup = nil,
	}, ReferralController)

	self:_createRewardPopup()
	self:_setupEvents()

	return self
end

-- 보상 알림 팝업 생성
function ReferralController:_createRewardPopup()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ReferralRewardGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 30
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	self._rewardPopup = screenGui

	local popup = Instance.new("Frame")
	popup.Name = "Popup"
	popup.Size = UDim2.new(0, ResponsiveUtil.scaledOffset(300), 0, ResponsiveUtil.scaledOffset(130))
	popup.Position = UDim2.new(0.5, -ResponsiveUtil.scaledOffset(150), 0.5, -ResponsiveUtil.scaledOffset(65))
	popup.BackgroundColor3 = Color3.fromRGB(20, 30, 60)
	popup.BorderSizePixel = 0
	popup.Parent = screenGui

	Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 14)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 2
	stroke.Parent = popup

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, ResponsiveUtil.scaledOffset(40))
	titleLabel.Position = UDim2.new(0, 0, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = ResponsiveUtil.scaledTextSize(20, 15)
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "🎉 초대 보상!"
	titleLabel.Parent = popup

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Body"
	bodyLabel.Size = UDim2.new(1, -20, 0, ResponsiveUtil.scaledOffset(50))
	bodyLabel.Position = UDim2.new(0, 10, 0, ResponsiveUtil.scaledOffset(48))
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	bodyLabel.TextSize = ResponsiveUtil.scaledTextSize(15, 12)
	bodyLabel.Font = Enum.Font.GothamBold
	bodyLabel.Text = ""
	bodyLabel.TextWrapped = true
	bodyLabel.Parent = popup
end

-- 보상 팝업 표시
function ReferralController:ShowRewardPopup(data: { type: string, coins: number, referrerName: string? })
	local popup = self._rewardPopup
	if not popup then
		return
	end

	local frame = popup:FindFirstChild("Popup") :: Frame?
	if not frame then
		return
	end

	local bodyLabel = frame:FindFirstChild("Body") :: TextLabel?
	if not bodyLabel then
		return
	end

	if data.type == "referee" then
		bodyLabel.Text = `{data.referrerName or "친구"}의 초대로 참가!\n💰 +{data.coins} 코인 지급!`
	else
		bodyLabel.Text = `{data.referrerName or "친구"}님이 합류했어요!\n💰 +{data.coins} 코인 보상!`
	end

	popup.Enabled = true
	frame.Position = UDim2.new(0.5, -frame.Size.X.Offset / 2, 0.5, -frame.Size.Y.Offset / 2 - 30)

	-- 위로 올라오는 애니메이션
	TweenService:Create(
		frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -frame.Size.X.Offset / 2, 0.5, -frame.Size.Y.Offset / 2) }
	):Play()

	-- 3초 후 자동 닫기
	task.delay(3, function()
		if not popup or not popup.Parent then
			return
		end
		local tween = TweenService:Create(
			frame,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, -frame.Size.X.Offset / 2, 0.5, frame.Size.Y.Offset) }
		)
		tween:Play()
		tween.Completed:Connect(function()
			popup.Enabled = false
		end)
	end)
end

-- 친구 초대 요청 (서버에 전달)
function ReferralController:PromptInvite()
	RemoteEvents.InviteFriend:FireServer()
end

-- 이벤트 설정
function ReferralController:_setupEvents()
	local conn = RemoteEvents.ReferralReward.OnClientEvent:Connect(function(data)
		self:ShowRewardPopup(data)
	end)
	table.insert(self._connections, conn)
end

function ReferralController:Destroy()
	for _, c in self._connections do
		c:Disconnect()
	end
	if self._rewardPopup then
		self._rewardPopup:Destroy()
	end
end

return ReferralController

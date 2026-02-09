--!strict
-- NPC Controller
-- NPC 말풍선 및 애니메이션 표시 (클라이언트)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local NPCController = {}
NPCController.__index = NPCController

export type NPCController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_playerGui: PlayerGui,
		_tutorialGui: ScreenGui?,
		_connections: { RBXScriptConnection },
	},
	NPCController
))

function NPCController.new(): NPCController
	local player = Players.LocalPlayer
	local self = setmetatable({
		_player = player,
		_playerGui = player:WaitForChild("PlayerGui") :: PlayerGui,
		_tutorialGui = nil,
		_connections = {},
	}, NPCController)

	self:_setupEventHandlers()
	self:_createTutorialGui()

	return self
end

-- 이벤트 핸들러 설정
function NPCController:_setupEventHandlers()
	-- NPC 등장 이벤트 수신
	local npcAppearedConnection = RemoteEvents.NPCAppeared.OnClientEvent:Connect(function(data)
		self:OnNPCAppeared(data.npcType, data.position, data.npcInstance, data.messageIndex)
	end)
	table.insert(self._connections, npcAppearedConnection)

	print("[NPCController] Event handlers set up")
end

-- NPC 등장 처리
function NPCController:OnNPCAppeared(
	npcType: string,
	position: Vector3,
	npcInstance: Model,
	messageIndex: number?
)
	print(`[NPCController] NPC appeared: {npcType} at {position}`)

	-- 말풍선 표시
	self:ShowSpeechBubble(npcInstance, npcType, messageIndex)
end

-- 말풍선 표시
function NPCController:ShowSpeechBubble(npcModel: Model, npcType: string, messageIndex: number?)
	local TweenService = game:GetService("TweenService")
	local npcConfig = GameConstants.NPC.TYPES[npcType]
	if not npcConfig then
		return
	end

	-- 랜덤 메시지 선택 (또는 지정된 인덱스 사용)
	local message
	if messageIndex and npcConfig.messages[messageIndex] then
		message = npcConfig.messages[messageIndex]
	else
		message = npcConfig.messages[math.random(1, #npcConfig.messages)]
	end

	-- 말풍선 생성
	local head = npcModel:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	-- BillboardGui 생성
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "SpeechBubble"
	billboardGui.Size = UDim2.new(0, 250, 0, 80) -- 더 크게
	billboardGui.StudsOffset = Vector3.new(0, 4, 0) -- 더 높이
	billboardGui.Adornee = head
	billboardGui.AlwaysOnTop = true
	billboardGui.Parent = head

	-- 말풍선 배경 (프레임)
	local frame = Instance.new("Frame")
	frame.Name = "BubbleFrame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 0.1
	frame.Parent = billboardGui

	-- 둥근 모서리
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	-- NPC 색상 테두리
	local stroke = Instance.new("UIStroke")
	stroke.Color = npcConfig.color
	stroke.Thickness = 4
	stroke.Parent = frame

	-- 이모지 (NPC 종류에 따라)
	local emoji = npcType == "Rabbit" and "🐰" or (npcType == "Bear" and "🐻" or "🦉")

	-- 텍스트
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -20, 1, -10)
	textLabel.Position = UDim2.new(0, 10, 0, 5)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = `{emoji} {message}`
	textLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
	textLabel.TextSize = 22
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextWrapped = true
	textLabel.Parent = frame

	-- 등장 애니메이션
	billboardGui.Size = UDim2.new(0, 0, 0, 0)
	local appearTween = TweenService:Create(billboardGui, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 250, 0, 80),
	})
	appearTween:Play()

	-- 일정 시간 후 말풍선 제거 (사라지는 애니메이션)
	task.delay(GameConstants.NPC.SPEECH_BUBBLE_DURATION - 0.3, function()
		if billboardGui and billboardGui.Parent then
			local disappearTween = TweenService:Create(billboardGui, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(0, 0, 0, 0),
			})
			disappearTween:Play()
			disappearTween.Completed:Connect(function()
				if billboardGui and billboardGui.Parent then
					billboardGui:Destroy()
				end
			end)
		end
	end)

	print(`[NPCController] Displayed speech bubble: "{emoji} {message}"`)
end

-- 튜토리얼 GUI 생성
function NPCController:_createTutorialGui()
	local tutorialGui = Instance.new("ScreenGui")
	tutorialGui.Name = "TutorialGui"
	tutorialGui.ResetOnSpawn = false
	tutorialGui.Enabled = false
	tutorialGui.Parent = self._playerGui
	self._tutorialGui = tutorialGui

	-- 부엉이 아이콘 (왼쪽 상단)
	local owlIcon = Instance.new("Frame")
	owlIcon.Name = "OwlIcon"
	owlIcon.Size = UDim2.new(0, 80, 0, 80)
	owlIcon.Position = UDim2.new(0, 20, 0, 120)
	owlIcon.BackgroundColor3 = GameConstants.NPC.TYPES.Owl.color
	owlIcon.BackgroundTransparency = 0.2
	owlIcon.Parent = tutorialGui

	local owlCorner = Instance.new("UICorner")
	owlCorner.CornerRadius = UDim.new(1, 0) -- 원형
	owlCorner.Parent = owlIcon

	-- 부엉이 이모지
	local owlEmoji = Instance.new("TextLabel")
	owlEmoji.Size = UDim2.new(1, 0, 1, 0)
	owlEmoji.BackgroundTransparency = 1
	owlEmoji.Text = "🦉"
	owlEmoji.TextSize = 48
	owlEmoji.Parent = owlIcon

	-- 메시지 프레임
	local messageFrame = Instance.new("Frame")
	messageFrame.Name = "MessageFrame"
	messageFrame.Size = UDim2.new(0, 300, 0, 80)
	messageFrame.Position = UDim2.new(0, 110, 0, 130)
	messageFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	messageFrame.BackgroundTransparency = 0.1
	messageFrame.Parent = tutorialGui

	local messageCorner = Instance.new("UICorner")
	messageCorner.CornerRadius = UDim.new(0, 12)
	messageCorner.Parent = messageFrame

	local messageStroke = Instance.new("UIStroke")
	messageStroke.Color = Color3.fromRGB(160, 82, 45)
	messageStroke.Thickness = 3
	messageStroke.Parent = messageFrame

	-- 메시지 텍스트
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "MessageLabel"
	messageLabel.Size = UDim2.new(1, -20, 1, -20)
	messageLabel.Position = UDim2.new(0, 10, 0, 10)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = ""
	messageLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	messageLabel.TextSize = 20
	messageLabel.Font = Enum.Font.GothamBold
	messageLabel.TextWrapped = true
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Center
	messageLabel.Parent = messageFrame

	print("[NPCController] Tutorial GUI created")
end

-- 부엉이 메시지 표시 (튜토리얼용)
function NPCController:ShowOwlMessage(message: string)
	if not self._tutorialGui then
		return
	end

	-- GUI 활성화
	self._tutorialGui.Enabled = true

	-- 메시지 업데이트
	local messageLabel = self._tutorialGui.MessageFrame:FindFirstChild("MessageLabel") :: TextLabel?
	if messageLabel then
		messageLabel.Text = message
	end

	-- 3초 후 숨김
	task.delay(3, function()
		if self._tutorialGui then
			self._tutorialGui.Enabled = false
		end
	end)

	print(`[NPCController] Showed owl message: "{message}"`)
end

-- 정리
function NPCController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

print("[NPCController] Initialized")

return NPCController

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
		_connections: { RBXScriptConnection },
	},
	NPCController
))

function NPCController.new(): NPCController
	local self = setmetatable({
		_player = Players.LocalPlayer,
		_connections = {},
	}, NPCController)

	self:_setupEventHandlers()

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
	billboardGui.Size = UDim2.new(0, 200, 0, 60)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.Adornee = head
	billboardGui.AlwaysOnTop = true
	billboardGui.Parent = head

	-- 말풍선 배경 (프레임)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 2
	frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	frame.Parent = billboardGui

	-- 둥근 모서리
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	-- 텍스트
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -10, 1, -10)
	textLabel.Position = UDim2.new(0, 5, 0, 5)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = message
	textLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.TextSize = 16
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextWrapped = true
	textLabel.TextScaled = true
	textLabel.Parent = frame

	-- 일정 시간 후 말풍선 제거
	task.delay(GameConstants.NPC.SPEECH_BUBBLE_DURATION, function()
		if billboardGui and billboardGui.Parent then
			billboardGui:Destroy()
		end
	end)

	print(`[NPCController] Displayed speech bubble: "{message}"`)
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

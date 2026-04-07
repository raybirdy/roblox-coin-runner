--!strict
-- LobbyNpcService
-- 로비 NPC 생성 및 상호작용 처리 (퀘스트 도우미 등)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local LobbyNpcService = {}

-- NPC 설정
local NPC_DEFS = {
	{
		id = "quest_npc",
		name = "📜 퀘스트 도우미",
		desc = "퀘스트 확인하기",
		-- Sprint 20: Spawn Plaza 안쪽 좌측에 배치 (스폰 근처에서 즉시 발견 가능)
		position = Vector3.new(-38, 3, -8),
		bodyColor = Color3.fromRGB(255, 200, 100),
		headColor = Color3.fromRGB(255, 220, 150),
		accentColor = Color3.fromRGB(255, 160, 40),
	},
}

-- ==================== NPC 모델 생성 ====================

local function createNpcModel(def: any): Model
	local model = Instance.new("Model")
	model.Name = def.id

	-- 몸통
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.2, 2.8, 1.2)
	torso.Position = def.position
	torso.Anchored = true
	torso.CanCollide = false
	torso.Color = def.bodyColor
	torso.Material = Enum.Material.SmoothPlastic
	torso.Parent = model

	-- 머리
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2, 2, 2)
	head.Position = def.position + Vector3.new(0, 2.8, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Color = def.headColor
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model

	-- 모자 테두리
	local hat = Instance.new("Part")
	hat.Name = "Hat"
	hat.Size = Vector3.new(2.4, 0.5, 2.4)
	hat.Position = def.position + Vector3.new(0, 4, 0)
	hat.Anchored = true
	hat.CanCollide = false
	hat.Color = def.accentColor
	hat.Material = Enum.Material.SmoothPlastic
	hat.Parent = model

	-- 모자 윗부분
	local hatTop = Instance.new("Part")
	hatTop.Name = "HatTop"
	hatTop.Size = Vector3.new(1.4, 1.2, 1.4)
	hatTop.Position = def.position + Vector3.new(0, 4.85, 0)
	hatTop.Anchored = true
	hatTop.CanCollide = false
	hatTop.Color = def.accentColor
	hatTop.Material = Enum.Material.SmoothPlastic
	hatTop.Parent = model

	-- 눈 (왼쪽)
	local eyeL = Instance.new("Part")
	eyeL.Name = "EyeL"
	eyeL.Shape = Enum.PartType.Ball
	eyeL.Size = Vector3.new(0.4, 0.4, 0.4)
	eyeL.Position = def.position + Vector3.new(-0.45, 3.1, -0.9)
	eyeL.Anchored = true
	eyeL.CanCollide = false
	eyeL.Color = Color3.fromRGB(30, 30, 30)
	eyeL.Material = Enum.Material.Neon
	eyeL.Parent = model

	-- 눈 (오른쪽)
	local eyeR = Instance.new("Part")
	eyeR.Name = "EyeR"
	eyeR.Shape = Enum.PartType.Ball
	eyeR.Size = Vector3.new(0.4, 0.4, 0.4)
	eyeR.Position = def.position + Vector3.new(0.45, 3.1, -0.9)
	eyeR.Anchored = true
	eyeR.CanCollide = false
	eyeR.Color = Color3.fromRGB(30, 30, 30)
	eyeR.Material = Enum.Material.Neon
	eyeR.Parent = model

	model.PrimaryPart = torso

	-- 이름 BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameBillboard"
	billboard.Size = UDim2.new(0, 180, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 240, 180)
	nameLabel.TextSize = 15
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Parent = billboard

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.new(1, 0, 0.4, 0)
	hintLabel.Position = UDim2.new(0, 0, 0.6, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "[ E ] 대화하기"
	hintLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
	hintLabel.TextSize = 12
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextStrokeTransparency = 0.5
	hintLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	hintLabel.Parent = billboard

	-- ProximityPrompt (가까이 가면 E키 아이콘 자동 표시)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "QuestPrompt"
	prompt.ActionText = def.desc
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso

	prompt.Triggered:Connect(function(player: Player)
		RemoteEvents.NpcInteract:FireClient(player, { npcId = def.id })
		print(`[LobbyNpcService] {player.Name} interacted with {def.id}`)
	end)

	return model
end

-- ==================== 초기화 ====================

function LobbyNpcService:Init()
	for _, def in NPC_DEFS do
		local model = createNpcModel(def)
		model.Parent = workspace
		print(`[LobbyNpcService] Spawned NPC: {def.id} at {def.position}`)
	end
	print("[LobbyNpcService] All lobby NPCs initialized")
end

print("[LobbyNpcService] Loaded")

return LobbyNpcService

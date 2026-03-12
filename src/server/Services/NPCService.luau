--!strict
-- NPC Service
-- NPC 생성 및 관리 (응원 NPC, 가이드 NPC)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local NPCService = {}
NPCService.__index = NPCService

export type NPCService = typeof(setmetatable(
	{} :: {
		_player: Player,
		_npcs: { Model },
	},
	NPCService
))

function NPCService.new(player: Player): NPCService
	local self = setmetatable({
		_player = player,
		_npcs = {},
	}, NPCService)

	return self
end

-- NPC 모델 생성
function NPCService:_createNPCModel(npcType: string, position: Vector3): Model?
	local npcConfig = GameConstants.NPC.TYPES[npcType]
	if not npcConfig then
		warn(`[NPCService] Unknown NPC type: {npcType}`)
		return nil
	end

	-- NPC 모델 생성 (간단한 블록 형태)
	local npcModel = Instance.new("Model")
	npcModel.Name = `NPC_{npcType}`

	-- 몸통
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 4, 2)
	body.Position = position
	body.Anchored = true
	body.CanCollide = false -- NPC는 충돌하지 않음
	body.Color = npcConfig.color
	body.Parent = npcModel

	-- 머리 (몸보다 큰 귀여운 비율)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(4, 4, 2.5)
	head.Position = position + Vector3.new(0, 4.5, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Color = npcConfig.color
	head.Shape = Enum.PartType.Ball -- 둥근 머리
	head.Parent = npcModel

	-- 얼굴 (간단한 텍스처)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png" -- 기본 웃는 얼굴
	face.Parent = head

	-- PrimaryPart 설정
	npcModel.PrimaryPart = body

	-- 위치 설정
	npcModel:MoveTo(position)

	return npcModel
end

-- NPC를 청크에 스폰
function NPCService:SpawnNPCInChunk(chunk: Model, difficulty: string): Model?
	-- NPC는 NPC 청크에만 등장
	if difficulty ~= "NPC" then
		return nil
	end

	-- 랜덤 NPC 선택 (Rabbit 50%, Bear 50%)
	local npcType = math.random() < 0.5 and "Rabbit" or "Bear"

	-- 청크 내 랜덤 위치
	local chunkPosition = chunk:GetPivot().Position
	local spawnX = chunkPosition.X + math.random(10, 70) -- 청크 내 랜덤 X 위치
	local spawnY = GameConstants.NPC.SPAWN_HEIGHT
	local spawnZ = chunkPosition.Z + GameConstants.NPC.Z_POSITION -- 배경 레이어

	local spawnPosition = Vector3.new(spawnX, spawnY, spawnZ)

	-- NPC 모델 생성
	local npcModel = self:_createNPCModel(npcType, spawnPosition)
	if not npcModel then
		return nil
	end

	-- 청크의 자식으로 추가
	npcModel.Parent = chunk

	-- NPC 목록에 추가
	table.insert(self._npcs, npcModel)

	-- 클라이언트에 NPC 등장 알림
	RemoteEvents.NPCAppeared:FireClient(self._player, {
		npcType = npcType,
		position = spawnPosition,
		npcInstance = npcModel,
	})

	print(`[NPCService] Spawned {npcType} NPC at {spawnPosition}`)

	-- NPC 손흔들기 애니메이션 (간단한 회전)
	self:_playWaveAnimation(npcModel)

	return npcModel
end

-- 손흔들기 애니메이션 (간단한 회전)
function NPCService:_playWaveAnimation(npcModel: Model)
	local head = npcModel:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	-- TweenService로 좌우 회전 애니메이션
	local TweenService = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(
		0.5, -- 지속 시간
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- 무한 반복
		true, -- 역방향 재생
		0
	)

	local goal = { CFrame = head.CFrame * CFrame.Angles(0, math.rad(15), 0) }
	local tween = TweenService:Create(head, tweenInfo, goal)
	tween:Play()

	-- 일정 시간 후 애니메이션 정지
	task.delay(GameConstants.NPC.WAVE_ANIMATION_DURATION, function()
		tween:Cancel()
		if head and head.Parent then
			head.CFrame = npcModel:GetPivot() * CFrame.new(0, 4.5, 0)
		end
	end)
end

-- 튜토리얼용 부엉이 NPC 생성
function NPCService:SpawnTutorialOwl(position: Vector3, messageIndex: number): Model?
	local npcModel = self:_createNPCModel("Owl", position)
	if not npcModel then
		return nil
	end

	-- 워크스페이스에 직접 추가 (청크가 아닌)
	npcModel.Parent = workspace

	-- NPC 목록에 추가
	table.insert(self._npcs, npcModel)

	-- 클라이언트에 NPC 등장 알림 (튜토리얼용 메시지 인덱스 포함)
	RemoteEvents.NPCAppeared:FireClient(self._player, {
		npcType = "Owl",
		position = position,
		npcInstance = npcModel,
		messageIndex = messageIndex,
	})

	print(`[NPCService] Spawned tutorial Owl NPC with message #{messageIndex}`)

	return npcModel
end

-- 정리
function NPCService:Destroy()
	for _, npc in self._npcs do
		if npc and npc.Parent then
			npc:Destroy()
		end
	end
	self._npcs = {}
end

print("[NPCService] Initialized")

return NPCService

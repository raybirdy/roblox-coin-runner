--!strict
-- Background Service
-- 게임 중 배경 요소 관리 (관중, 나무, 스피드 라인)
-- 프레임 저하 방지: 파티클 없음, 간단한 Tween만 사용

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local BackgroundService = {}
BackgroundService.__index = BackgroundService

export type BackgroundService = typeof(setmetatable(
	{} :: {
		_backgroundFolder: Folder?,
		_crowdNPCs: { Model },
		_scenery: { Model },
		_speedLines: { Part },
		_floorParts: { Part }, -- 게임 바닥 파트들
		_isRunning: boolean,
		_playerPosition: Vector3,
	},
	BackgroundService
))

function BackgroundService.new(): BackgroundService
	local self = setmetatable({
		_backgroundFolder = nil,
		_crowdNPCs = {},
		_scenery = {},
		_speedLines = {},
		_floorParts = {},
		_isRunning = false,
		_playerPosition = Vector3.zero,
	}, BackgroundService)

	return self
end

-- 게임 시작 시 초기화
function BackgroundService:StartGame()
	self:Cleanup()

	-- 배경 폴더 생성
	self._backgroundFolder = Instance.new("Folder")
	self._backgroundFolder.Name = "GameBackground"
	self._backgroundFolder.Parent = workspace

	self._isRunning = true

	print("[BackgroundService] Game background started")
end

-- 청크에 배경 요소 추가
function BackgroundService:AddBackgroundForChunk(chunkPosition: Vector3, chunkLength: number)
	if not self._backgroundFolder then
		return
	end

	local bgConfig = GameConstants.BACKGROUND

	-- 게임 바닥 생성
	self:_spawnFloorForChunk(chunkPosition, chunkLength)

	-- 관중석 NPC 생성 (양쪽)
	self:_spawnCrowdForChunk(chunkPosition, chunkLength)

	-- 배경 나무 생성
	self:_spawnSceneryForChunk(chunkPosition, chunkLength)

	-- 배경 언덕 생성
	if bgConfig.HILLS_ENABLED then
		self:_spawnHillForChunk(chunkPosition, chunkLength)
	end
end

-- 게임 바닥 생성 (청크별)
function BackgroundService:_spawnFloorForChunk(chunkPosition: Vector3, chunkLength: number)
	if not self._backgroundFolder then
		return
	end

	-- 바닥 생성 (플레이어 Z 위치 중심으로)
	local floor = Instance.new("Part")
	floor.Name = "GameFloor"
	floor.Size = Vector3.new(chunkLength + 5, 1, 40) -- 청크 길이 + 여유, 넓이 40
	floor.Position = Vector3.new(
		chunkPosition.X + chunkLength / 2,
		0.5, -- Y = 0.5 (바닥)
		GameConstants.PLAYER.Z_POSITION
	)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Color = Color3.fromRGB(80, 80, 90) -- 진한 회색 (도로 느낌)
	floor.Material = Enum.Material.Concrete
	floor.Parent = self._backgroundFolder

	-- 도로 중앙선 (장식)
	local centerLine = Instance.new("Part")
	centerLine.Name = "CenterLine"
	centerLine.Size = Vector3.new(chunkLength, 0.1, 0.5)
	centerLine.Position = Vector3.new(chunkPosition.X + chunkLength / 2, 1.05, GameConstants.PLAYER.Z_POSITION)
	centerLine.Anchored = true
	centerLine.CanCollide = false
	centerLine.Color = Color3.fromRGB(255, 200, 50) -- 노란색 중앙선
	centerLine.Material = Enum.Material.Neon
	centerLine.Parent = self._backgroundFolder

	table.insert(self._floorParts, floor)
	table.insert(self._floorParts, centerLine)
end

-- 관중석 NPC 생성
function BackgroundService:_spawnCrowdForChunk(chunkPosition: Vector3, chunkLength: number)
	if not self._backgroundFolder then
		return
	end

	local bgConfig = GameConstants.BACKGROUND
	local crowdTypes = bgConfig.CROWD_TYPES

	-- 청크당 관중 수
	local crowdCount = bgConfig.CROWD_PER_CHUNK

	for i = 1, crowdCount do
		-- 랜덤 관중 타입
		local crowdType = crowdTypes[math.random(1, #crowdTypes)]

		-- 위치 계산 (앞쪽 또는 뒤쪽 랜덤)
		local xOffset = (i - 1) * bgConfig.CROWD_SPACING + math.random(5, 15)
		local zPosition = (i % 2 == 0) and bgConfig.CROWD_Z_FRONT or bgConfig.CROWD_Z_BACK

		local position = Vector3.new(chunkPosition.X + xOffset, bgConfig.CROWD_Y, zPosition)

		-- 관중 NPC 생성
		local crowdNPC = self:_createCrowdNPC(crowdType, position)
		if crowdNPC then
			table.insert(self._crowdNPCs, crowdNPC)
		end
	end
end

-- 관중 NPC 생성 (개별)
function BackgroundService:_createCrowdNPC(
	crowdType: {
		name: string,
		color: Color3,
		animation: string,
	},
	position: Vector3
): Model?
	if not self._backgroundFolder then
		return nil
	end

	local npcModel = Instance.new("Model")
	npcModel.Name = "CrowdNPC_" .. crowdType.name
	npcModel.Parent = self._backgroundFolder

	-- 몸통 (간단하게)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2.5, 1.5)
	body.Position = position + Vector3.new(0, 1.25, 0)
	body.Anchored = true
	body.CanCollide = false
	body.Color = crowdType.color
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = npcModel

	-- 머리
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Position = position + Vector3.new(0, 3, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Color = crowdType.color
	head.Material = Enum.Material.SmoothPlastic
	head.Shape = Enum.PartType.Ball
	head.Parent = npcModel

	-- 눈 (간단하게 2개)
	for _, xOffset in { -0.3, 0.3 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.25, 0.25, 0.1)
		eye.Position = position + Vector3.new(xOffset, 3.1, 0.7)
		eye.Anchored = true
		eye.CanCollide = false
		eye.Color = Color3.fromRGB(0, 0, 0)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Shape = Enum.PartType.Ball
		eye.Parent = npcModel
	end

	-- 동물별 귀 추가
	if crowdType.name == "Rabbit" then
		for _, xOffset in { -0.4, 0.4 } do
			local ear = Instance.new("Part")
			ear.Name = "Ear"
			ear.Size = Vector3.new(0.3, 1.2, 0.2)
			ear.Position = position + Vector3.new(xOffset, 4, 0)
			ear.Anchored = true
			ear.CanCollide = false
			ear.Color = crowdType.color
			ear.Material = Enum.Material.SmoothPlastic
			ear.Parent = npcModel
		end
	elseif crowdType.name == "Bear" or crowdType.name == "Cat" then
		for _, xOffset in { -0.5, 0.5 } do
			local ear = Instance.new("Part")
			ear.Name = "Ear"
			ear.Size = Vector3.new(0.4, 0.4, 0.2)
			ear.Position = position + Vector3.new(xOffset, 3.7, 0)
			ear.Anchored = true
			ear.CanCollide = false
			ear.Color = crowdType.color
			ear.Material = Enum.Material.SmoothPlastic
			ear.Shape = (crowdType.name == "Bear") and Enum.PartType.Ball or Enum.PartType.Block
			ear.Parent = npcModel
		end
	elseif crowdType.name == "Penguin" then
		-- 펭귄 배 (흰색)
		local belly = Instance.new("Part")
		belly.Name = "Belly"
		belly.Size = Vector3.new(1.4, 1.8, 0.4)
		belly.Position = position + Vector3.new(0, 1.25, 0.6)
		belly.Anchored = true
		belly.CanCollide = false
		belly.Color = Color3.fromRGB(255, 255, 255)
		belly.Material = Enum.Material.SmoothPlastic
		belly.Parent = npcModel
	end

	-- 응원 애니메이션 (간단한 위아래 움직임)
	self:_playCrowdAnimation(npcModel, crowdType.animation)

	return npcModel
end

-- 관중 애니메이션 (파티클 없이, Tween만)
function BackgroundService:_playCrowdAnimation(npcModel: Model, animationType: string)
	local body = npcModel:FindFirstChild("Body") :: BasePart?
	local head = npcModel:FindFirstChild("Head") :: BasePart?

	if not body or not head then
		return
	end

	local originalBodyY = body.Position.Y
	local originalHeadY = head.Position.Y

	-- 랜덤 오프셋으로 동기화 방지
	local delay = math.random() * 2

	task.delay(delay, function()
		if animationType == "jump" then
			-- 점프 애니메이션 (위아래)
			task.spawn(function()
				while body and body.Parent do
					local jumpTween =
						TweenService:Create(body, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Position = body.Position + Vector3.new(0, 1, 0),
						})
					local headJumpTween =
						TweenService:Create(head, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Position = head.Position + Vector3.new(0, 1, 0),
						})
					jumpTween:Play()
					headJumpTween:Play()
					jumpTween.Completed:Wait()

					if not body or not body.Parent then
						break
					end

					local downTween =
						TweenService:Create(body, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							Position = Vector3.new(body.Position.X, originalBodyY, body.Position.Z),
						})
					local headDownTween =
						TweenService:Create(head, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							Position = Vector3.new(head.Position.X, originalHeadY, head.Position.Z),
						})
					downTween:Play()
					headDownTween:Play()
					downTween.Completed:Wait()

					task.wait(1 + math.random() * 2) -- 랜덤 간격
				end
			end)
		elseif animationType == "wave" then
			-- 좌우 흔들기
			task.spawn(function()
				while head and head.Parent do
					local waveTween = TweenService:Create(
						head,
						TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{
							Orientation = Vector3.new(0, 20, 10),
						}
					)
					waveTween:Play()
					waveTween.Completed:Wait()

					if not head or not head.Parent then
						break
					end

					local waveBackTween = TweenService:Create(
						head,
						TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{
							Orientation = Vector3.new(0, -20, -10),
						}
					)
					waveBackTween:Play()
					waveBackTween.Completed:Wait()

					task.wait(0.5 + math.random() * 1)
				end
			end)
		elseif animationType == "waddle" then
			-- 뒤뚱뒤뚱
			task.spawn(function()
				while body and body.Parent do
					local waddleTween = TweenService:Create(
						body,
						TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{
							Orientation = Vector3.new(0, 0, 8),
						}
					)
					waddleTween:Play()
					waddleTween.Completed:Wait()

					if not body or not body.Parent then
						break
					end

					local waddleBackTween = TweenService:Create(
						body,
						TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{
							Orientation = Vector3.new(0, 0, -8),
						}
					)
					waddleBackTween:Play()
					waddleBackTween.Completed:Wait()
				end
			end)
		else
			-- 기본: 가벼운 위아래
			task.spawn(function()
				while body and body.Parent do
					local bobTween = TweenService:Create(
						body,
						TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{
							Position = body.Position + Vector3.new(0, 0.3, 0),
						}
					)
					local headBobTween = TweenService:Create(
						head,
						TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{
							Position = head.Position + Vector3.new(0, 0.3, 0),
						}
					)
					bobTween:Play()
					headBobTween:Play()
					bobTween.Completed:Wait()

					if not body or not body.Parent then
						break
					end

					local bobDownTween = TweenService:Create(
						body,
						TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{
							Position = Vector3.new(body.Position.X, originalBodyY, body.Position.Z),
						}
					)
					local headBobDownTween = TweenService:Create(
						head,
						TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
						{
							Position = Vector3.new(head.Position.X, originalHeadY, head.Position.Z),
						}
					)
					bobDownTween:Play()
					headBobDownTween:Play()
					bobDownTween.Completed:Wait()

					task.wait(0.5 + math.random() * 1.5)
				end
			end)
		end
	end)
end

-- 배경 나무 생성
function BackgroundService:_spawnSceneryForChunk(chunkPosition: Vector3, chunkLength: number)
	if not self._backgroundFolder then
		return
	end

	local bgConfig = GameConstants.BACKGROUND

	for i = 1, bgConfig.TREES_PER_CHUNK do
		local xOffset = (i - 1) * (chunkLength / bgConfig.TREES_PER_CHUNK) + math.random(10, 30)
		local zOffset = (i % 2 == 0) and 5 or -5 -- 약간 좌우로

		local position = Vector3.new(chunkPosition.X + xOffset, 0, bgConfig.SCENERY_Z + zOffset)

		local tree = self:_createBackgroundTree(position)
		if tree then
			table.insert(self._scenery, tree)
		end
	end
end

-- 배경 나무 생성 (개별)
function BackgroundService:_createBackgroundTree(position: Vector3): Model?
	if not self._backgroundFolder then
		return nil
	end

	local treeModel = Instance.new("Model")
	treeModel.Name = "BackgroundTree"
	treeModel.Parent = self._backgroundFolder

	-- 줄기 (큰 배경용)
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(3, 12, 3)
	trunk.Position = position + Vector3.new(0, 6, 0)
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.Color = Color3.fromRGB(101, 67, 33)
	trunk.Material = Enum.Material.Wood
	trunk.Parent = treeModel

	-- 잎 (큰 구)
	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Size = Vector3.new(10, 10, 10)
	leaves.Position = position + Vector3.new(0, 15, 0)
	leaves.Anchored = true
	leaves.CanCollide = false
	leaves.Color = Color3.fromRGB(34, 139, 34)
	leaves.Material = Enum.Material.Grass
	leaves.Shape = Enum.PartType.Ball
	leaves.Parent = treeModel

	return treeModel
end

-- 배경 언덕 생성
function BackgroundService:_spawnHillForChunk(chunkPosition: Vector3, chunkLength: number)
	if not self._backgroundFolder then
		return
	end

	local bgConfig = GameConstants.BACKGROUND

	-- 언덕 (큰 반원형 파트)
	local hill = Instance.new("Part")
	hill.Name = "BackgroundHill"
	hill.Size = Vector3.new(chunkLength, 15, 30)
	hill.Position = Vector3.new(chunkPosition.X + chunkLength / 2, -5, bgConfig.SCENERY_Z - 15)
	hill.Anchored = true
	hill.CanCollide = false
	hill.Color = Color3.fromRGB(80, 150, 80) -- 연한 초록
	hill.Material = Enum.Material.Grass
	hill.Parent = self._backgroundFolder

	table.insert(self._scenery, hill)
end

-- 플레이어 위치 업데이트 (청크 정리용)
function BackgroundService:UpdatePlayerPosition(playerPosition: Vector3)
	self._playerPosition = playerPosition

	-- 플레이어 뒤쪽 배경 요소 정리
	self:_cleanupOldBackground()
end

-- 오래된 배경 요소 정리
function BackgroundService:_cleanupOldBackground()
	local deleteDistance = GameConstants.CHUNK.DELETE_DISTANCE + 20

	-- 관중 정리
	local crowdToRemove = {}
	for i, npc in self._crowdNPCs do
		local body = npc:FindFirstChild("Body") :: BasePart?
		if body then
			local distance = self._playerPosition.X - body.Position.X
			if distance > deleteDistance then
				table.insert(crowdToRemove, i)
			end
		end
	end

	for i = #crowdToRemove, 1, -1 do
		local index = crowdToRemove[i]
		local npc = self._crowdNPCs[index]
		npc:Destroy()
		table.remove(self._crowdNPCs, index)
	end

	-- 배경 요소 정리
	local sceneryToRemove = {}
	for i, item in self._scenery do
		if item:IsA("Model") then
			local primaryPart = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				local distance = self._playerPosition.X - primaryPart.Position.X
				if distance > deleteDistance then
					table.insert(sceneryToRemove, i)
				end
			end
		elseif item:IsA("BasePart") then
			local distance = self._playerPosition.X - item.Position.X
			if distance > deleteDistance then
				table.insert(sceneryToRemove, i)
			end
		end
	end

	for i = #sceneryToRemove, 1, -1 do
		local index = sceneryToRemove[i]
		local item = self._scenery[index]
		item:Destroy()
		table.remove(self._scenery, index)
	end

	-- 바닥 정리
	local floorToRemove = {}
	for i, floor in self._floorParts do
		local distance = self._playerPosition.X - floor.Position.X
		if distance > deleteDistance then
			table.insert(floorToRemove, i)
		end
	end

	for i = #floorToRemove, 1, -1 do
		local index = floorToRemove[i]
		local floor = self._floorParts[index]
		floor:Destroy()
		table.remove(self._floorParts, index)
	end
end

-- 게임 종료 시 정리
function BackgroundService:Cleanup()
	self._isRunning = false

	-- 관중 정리
	for _, npc in self._crowdNPCs do
		if npc and npc.Parent then
			npc:Destroy()
		end
	end
	self._crowdNPCs = {}

	-- 배경 요소 정리
	for _, item in self._scenery do
		if item and item.Parent then
			item:Destroy()
		end
	end
	self._scenery = {}

	-- 바닥 정리
	for _, floor in self._floorParts do
		if floor and floor.Parent then
			floor:Destroy()
		end
	end
	self._floorParts = {}

	-- 폴더 정리
	if self._backgroundFolder then
		self._backgroundFolder:Destroy()
		self._backgroundFolder = nil
	end

	print("[BackgroundService] Cleaned up")
end

print("[BackgroundService] Module loaded")

return BackgroundService

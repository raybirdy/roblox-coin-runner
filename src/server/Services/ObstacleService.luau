--!strict
-- Obstacle Service
-- 장애물 생성 및 충돌 처리

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local ObstacleService = {}
ObstacleService.__index = ObstacleService

type ObstacleData = {
	part: BasePart,
	obstacleType: string,
	spawnTime: number,
}

export type ObstacleService = typeof(setmetatable(
	{} :: {
		_activeObstacles: { ObstacleData },
		_player: Player,
		_lastHitTime: number,
		_isInvincible: boolean,
	},
	ObstacleService
))

function ObstacleService.new(player: Player): ObstacleService
	local self = setmetatable({
		_activeObstacles = {},
		_player = player,
		_lastHitTime = 0,
		_isInvincible = false,
	}, ObstacleService)

	return self
end

-- 청크 내 장애물 생성
function ObstacleService:SpawnObstaclesInChunk(chunk: Model, difficulty: string)
	-- 난이도별 장애물 개수 결정
	local obstacleCount = self:_getObstacleCountForDifficulty(difficulty)

	-- 청크 경계 계산
	local chunkCFrame = chunk:GetPrimaryPartCFrame()
	local chunkSize = chunk:GetExtentsSize()

	-- 장애물 배치 (간격 확보)
	local minSpacing = GameConstants.OBSTACLE.MIN_SPACING
	local availableLength = chunkSize.X - 10 -- 양끝 여유 공간

	for i = 1, obstacleCount do
		-- 장애물 위치 계산 (균등 배치 + 약간의 랜덤)
		local segmentLength = availableLength / obstacleCount
		local baseX = -chunkSize.X / 2 + 5 + (i - 1) * segmentLength + segmentLength / 2
		local randomOffset = (math.random() - 0.5) * (segmentLength * 0.3)
		local obstacleX = baseX + randomOffset

		local obstaclePosition = chunkCFrame.Position + Vector3.new(obstacleX, 0, 0)

		-- 장애물 타입 선택
		local obstacleType = self:_selectObstacleType(difficulty)

		-- 장애물 생성
		self:_spawnObstacle(obstaclePosition, obstacleType)
	end
end

-- 난이도별 장애물 개수 결정
function ObstacleService:_getObstacleCountForDifficulty(difficulty: string): number
	if difficulty == "Easy" then
		return math.random(0, 1) -- 쉬운 청크: 장애물 거의 없음 (0-1개)
	elseif difficulty == "Normal" then
		return math.random(1, 2) -- 보통: 1-2개
	elseif difficulty == "Hard" then
		return math.random(2, 4) -- 어려운 청크: 장애물 많음
	elseif difficulty == "Bonus" then
		return 0 -- 보너스는 장애물 없음
	elseif difficulty == "NPC" then
		return math.random(0, 1) -- NPC 청크도 장애물 적게
	end

	return 1 -- 기본값
end

-- 장애물 타입 선택
function ObstacleService:_selectObstacleType(difficulty: string): string
	local rand = math.random()

	if difficulty == "Easy" then
		-- Easy는 Low Wall만 (점프만 연습)
		return "LowWall"
	elseif difficulty == "Normal" then
		-- Normal은 Low Wall + Tunnel + SpikeTrap
		if rand < 0.50 then
			return "LowWall"
		elseif rand < 0.80 then
			return "Tunnel"
		elseif rand < 0.95 then
			return "SpikeTrap"
		else
			return "Gap"
		end
	elseif difficulty == "Hard" then
		-- Hard는 모든 타입 (DoubleWall 포함)
		if rand < 0.25 then
			return "LowWall"
		elseif rand < 0.45 then
			return "Tunnel"
		elseif rand < 0.60 then
			return "SpikeTrap"
		elseif rand < 0.80 then
			return "DoubleWall"
		else
			return "Gap"
		end
	else
		return "LowWall"
	end
end

-- 장애물 생성 (BasePart)
function ObstacleService:_spawnObstacle(position: Vector3, obstacleType: string)
	local obstacle: BasePart

	if obstacleType == "LowWall" then
		-- 낮은 벽 (점프로 회피)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_LowWall"
		obstacle.Size = Vector3.new(2, GameConstants.OBSTACLE.LOW_WALL_HEIGHT, 10) -- 폭×높이×깊이
		obstacle.Position = position + Vector3.new(0, GameConstants.OBSTACLE.LOW_WALL_HEIGHT / 2, 0)
		obstacle.Color = Color3.fromRGB(255, 80, 80) -- 빨간색 (점프 = 빨간색)
		obstacle.Material = Enum.Material.Neon
		obstacle.Transparency = 0.1

		-- 점프 안내 화살표 (↑)
		for i = 1, 2 do
			local arrow = Instance.new("Part")
			arrow.Name = `JumpArrow_{i}`
			arrow.Size = Vector3.new(0.3, 1.2, 1.2)
			arrow.Position = position + Vector3.new(-3 - i * 1.5, 2 + i * 1.2, 0)
			arrow.Color = Color3.fromRGB(255, 150, 150)
			arrow.Material = Enum.Material.Neon
			arrow.Transparency = 0.3
			arrow.CanCollide = false
			arrow.Anchored = true
			arrow.CFrame = CFrame.new(arrow.Position) * CFrame.Angles(0, 0, math.rad(-45))
			arrow.Parent = workspace
		end

		-- "JUMP!" 텍스트 (SurfaceGui로 3D 공간에 표시)
		local signPart = Instance.new("Part")
		signPart.Name = "JumpSign"
		signPart.Size = Vector3.new(0.3, 2.5, 5)
		signPart.Position = position + Vector3.new(-6, 5.5, 0)
		signPart.Color = Color3.fromRGB(30, 30, 40)
		signPart.Material = Enum.Material.SmoothPlastic
		signPart.CanCollide = false
		signPart.Anchored = true
		signPart.Parent = workspace

		-- 간판 테두리 (빨간 네온)
		local signBorder = Instance.new("Part")
		signBorder.Name = "JumpSignBorder"
		signBorder.Size = Vector3.new(0.1, 2.7, 5.2)
		signBorder.Position = position + Vector3.new(-6.15, 5.5, 0)
		signBorder.Color = Color3.fromRGB(255, 80, 80)
		signBorder.Material = Enum.Material.Neon
		signBorder.CanCollide = false
		signBorder.Anchored = true
		signBorder.Parent = workspace

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "JumpGui"
		surfaceGui.Face = Enum.NormalId.Left -- 플레이어 방향(-X)을 향함
		surfaceGui.CanvasSize = Vector2.new(200, 100)
		surfaceGui.Parent = signPart

		local jumpText = Instance.new("TextLabel")
		jumpText.Size = UDim2.new(1, 0, 1, 0)
		jumpText.BackgroundTransparency = 1
		jumpText.Text = "JUMP!"
		jumpText.TextColor3 = Color3.fromRGB(255, 255, 255)
		jumpText.TextScaled = true
		jumpText.Font = Enum.Font.GothamBlack
		jumpText.TextStrokeTransparency = 0
		jumpText.TextStrokeColor3 = Color3.fromRGB(200, 0, 0)
		jumpText.Parent = surfaceGui
	elseif obstacleType == "Tunnel" then
		-- 공중 장애물 (슬라이드로 통과)
		-- 아래 공간은 비워두고 위쪽만 장애물로 생성
		local tunnelHeight = GameConstants.OBSTACLE.TUNNEL_HEIGHT -- 통과 가능한 높이 (3)
		local obstacleHeight = 6 -- 장애물 높이

		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_Tunnel"
		obstacle.Size = Vector3.new(4, obstacleHeight, 12)
		-- Y 위치: 터널 높이 위에 장애물 배치
		obstacle.Position = position + Vector3.new(0, tunnelHeight + obstacleHeight / 2, 0)
		obstacle.Color = Color3.fromRGB(0, 150, 255) -- 파란색 (슬라이드 = 파란색)
		obstacle.Material = Enum.Material.Neon
		obstacle.Transparency = 0.2

		-- ↓↓↓ 아래로 화살표 표시 (슬라이드 안내)
		for i = 1, 3 do
			local arrow = Instance.new("Part")
			arrow.Name = `SlideArrow_{i}`
			arrow.Size = Vector3.new(0.3, 1.5, 1.5)
			arrow.Position = position + Vector3.new(-6 - i * 2, 4 - i * 0.5, 0)
			arrow.Color = Color3.fromRGB(0, 200, 255)
			arrow.Material = Enum.Material.Neon
			arrow.Transparency = 0.3
			arrow.CanCollide = false
			arrow.Anchored = true
			-- 아래를 가리키는 화살표 모양
			arrow.CFrame = CFrame.new(arrow.Position) * CFrame.Angles(0, 0, math.rad(45))
			arrow.Parent = workspace
		end

		-- "SLIDE!" 텍스트 (SurfaceGui로 3D 공간에 표시)
		local signPart = Instance.new("Part")
		signPart.Name = "SlideSign"
		signPart.Size = Vector3.new(0.3, 2.5, 5)
		signPart.Position = position + Vector3.new(-10, 5, 0)
		signPart.Color = Color3.fromRGB(30, 30, 40)
		signPart.Material = Enum.Material.SmoothPlastic
		signPart.CanCollide = false
		signPart.Anchored = true
		signPart.Parent = workspace

		-- 간판 테두리 (파란 네온)
		local signBorder = Instance.new("Part")
		signBorder.Name = "SlideSignBorder"
		signBorder.Size = Vector3.new(0.1, 2.7, 5.2)
		signBorder.Position = position + Vector3.new(-10.15, 5, 0)
		signBorder.Color = Color3.fromRGB(0, 150, 255)
		signBorder.Material = Enum.Material.Neon
		signBorder.CanCollide = false
		signBorder.Anchored = true
		signBorder.Parent = workspace

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "SlideGui"
		surfaceGui.Face = Enum.NormalId.Left -- 플레이어 방향(-X)을 향함
		surfaceGui.CanvasSize = Vector2.new(200, 100)
		surfaceGui.Parent = signPart

		local slideText = Instance.new("TextLabel")
		slideText.Size = UDim2.new(1, 0, 1, 0)
		slideText.BackgroundTransparency = 1
		slideText.Text = "SLIDE!"
		slideText.TextColor3 = Color3.fromRGB(255, 255, 255)
		slideText.TextScaled = true
		slideText.Font = Enum.Font.GothamBlack
		slideText.TextStrokeTransparency = 0
		slideText.TextStrokeColor3 = Color3.fromRGB(0, 100, 200)
		slideText.Parent = surfaceGui

		-- 터널 통과 영역 표시 (초록색 바닥 라인)
		local passZone = Instance.new("Part")
		passZone.Name = "TunnelPassZone"
		passZone.Size = Vector3.new(6, 0.2, 12)
		passZone.Position = position + Vector3.new(0, 0.1, 0)
		passZone.Color = Color3.fromRGB(0, 255, 100)
		passZone.Material = Enum.Material.Neon
		passZone.Transparency = 0.5
		passZone.CanCollide = false
		passZone.Anchored = true
		passZone.Parent = workspace
	elseif obstacleType == "SpikeTrap" then
		-- 가시 함정 (바닥에 설치, 점프로 회피)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_SpikeTrap"
		obstacle.Size = Vector3.new(5, 2, 10)
		obstacle.Position = position + Vector3.new(0, 1, 0)
		obstacle.Color = Color3.fromRGB(255, 50, 50)
		obstacle.Material = Enum.Material.DiamondPlate

		-- 가시 시각 효과 (상단에 뾰족한 파트들)
		for i = 1, 5 do
			local spike = Instance.new("Part")
			spike.Name = `Spike{i}`
			spike.Size = Vector3.new(0.6, 2, 0.6)
			spike.Position = position + Vector3.new(-2 + (i - 1) * 1, 3, (i % 2 - 0.5) * 3)
			spike.Color = Color3.fromRGB(200, 0, 0)
			spike.Material = Enum.Material.Metal
			spike.Anchored = true
			spike.CanCollide = false
			spike.Parent = workspace
		end

		-- 경고 라인 (노란색)
		local warningLine = Instance.new("Part")
		warningLine.Name = "SpikeWarning"
		warningLine.Size = Vector3.new(0.5, 0.3, 12)
		warningLine.Position = position + Vector3.new(-4, 0.2, 0)
		warningLine.Color = Color3.fromRGB(255, 200, 0)
		warningLine.Material = Enum.Material.Neon
		warningLine.CanCollide = false
		warningLine.Anchored = true
		warningLine.Parent = workspace

	elseif obstacleType == "DoubleWall" then
		-- 이중 벽 (두 번 점프 필요)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_DoubleWall"
		obstacle.Size = Vector3.new(2, GameConstants.OBSTACLE.LOW_WALL_HEIGHT, 8)
		obstacle.Position = position + Vector3.new(0, GameConstants.OBSTACLE.LOW_WALL_HEIGHT / 2, 0)
		obstacle.BrickColor = BrickColor.new("Bright red")

		-- 두 번째 벽 (첫 번째 벽 뒤에)
		local secondWall = Instance.new("Part")
		secondWall.Name = "Obstacle_DoubleWall_2"
		secondWall.Size = Vector3.new(2, GameConstants.OBSTACLE.LOW_WALL_HEIGHT + 1, 8)
		secondWall.Position = position + Vector3.new(5, (GameConstants.OBSTACLE.LOW_WALL_HEIGHT + 1) / 2, 0)
		secondWall.BrickColor = BrickColor.new("Bright red")
		secondWall.Anchored = true
		secondWall.CanCollide = false -- 저연령층 게임: 장애물 통과 가능
		secondWall.Material = Enum.Material.SmoothPlastic
		secondWall:SetAttribute("ObstacleType", "DoubleWall")
		secondWall.Parent = workspace

		-- 두 번째 벽도 장애물 데이터에 추가
		local secondWallData: ObstacleData = {
			part = secondWall,
			obstacleType = "DoubleWall",
			spawnTime = tick(),
		}
		table.insert(self._activeObstacles, secondWallData)

	elseif obstacleType == "Gap" then
		-- 구덩이 (점프로 건너기)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_Gap"
		local gapWidth = math.random(
			GameConstants.OBSTACLE.GAP_WIDTH_MIN,
			GameConstants.OBSTACLE.GAP_WIDTH_MAX
		)
		obstacle.Size = Vector3.new(gapWidth, 1, 12) -- 바닥 구멍
		obstacle.Position = position + Vector3.new(0, -5, 0) -- 아래로 내림 (낙사 판정용)
		obstacle.Color = Color3.fromRGB(30, 30, 30)
		obstacle.Transparency = 0.3

		-- 구덩이 테두리 (빨간색 경고)
		for _, xOffset in { -gapWidth / 2 - 0.3, gapWidth / 2 + 0.3 } do
			local edge = Instance.new("Part")
			edge.Name = "GapEdge"
			edge.Size = Vector3.new(0.5, 1, 12)
			edge.Position = position + Vector3.new(xOffset, 0.5, 0)
			edge.Color = Color3.fromRGB(255, 100, 0)
			edge.Material = Enum.Material.Neon
			edge.CanCollide = false
			edge.Anchored = true
			edge.Parent = workspace
		end

		-- "DANGER!" 경고 (SurfaceGui로 3D 공간에 표시)
		local dangerSign = Instance.new("Part")
		dangerSign.Name = "GapDanger"
		dangerSign.Size = Vector3.new(0.3, 2.5, 5)
		dangerSign.Position = position + Vector3.new(-gapWidth / 2 - 4, 4, 0)
		dangerSign.Color = Color3.fromRGB(30, 30, 40)
		dangerSign.Material = Enum.Material.SmoothPlastic
		dangerSign.CanCollide = false
		dangerSign.Anchored = true
		dangerSign.Parent = workspace

		-- 간판 테두리 (주황 네온)
		local signBorder = Instance.new("Part")
		signBorder.Name = "DangerSignBorder"
		signBorder.Size = Vector3.new(0.1, 2.7, 5.2)
		signBorder.Position = position + Vector3.new(-gapWidth / 2 - 4.15, 4, 0)
		signBorder.Color = Color3.fromRGB(255, 150, 0)
		signBorder.Material = Enum.Material.Neon
		signBorder.CanCollide = false
		signBorder.Anchored = true
		signBorder.Parent = workspace

		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "DangerGui"
		surfaceGui.Face = Enum.NormalId.Left -- 플레이어 방향(-X)을 향함
		surfaceGui.CanvasSize = Vector2.new(200, 100)
		surfaceGui.Parent = dangerSign

		local dangerText = Instance.new("TextLabel")
		dangerText.Size = UDim2.new(1, 0, 1, 0)
		dangerText.BackgroundTransparency = 1
		dangerText.Text = "DANGER!"
		dangerText.TextColor3 = Color3.fromRGB(255, 255, 255)
		dangerText.TextScaled = true
		dangerText.Font = Enum.Font.GothamBlack
		dangerText.TextStrokeTransparency = 0
		dangerText.TextStrokeColor3 = Color3.fromRGB(255, 100, 0)
		dangerText.Parent = surfaceGui
	else
		obstacle = Instance.new("Part")
		obstacle.Size = Vector3.new(2, 4, 8)
		obstacle.Position = position
	end

	obstacle.Anchored = true
	obstacle.CanCollide = false -- 저연령층 게임: 장애물 통과 가능 (에너지만 감소)
	obstacle.Material = Enum.Material.SmoothPlastic
	obstacle:SetAttribute("ObstacleType", obstacleType)

	obstacle.Parent = workspace

	-- 장애물 데이터 저장
	local obstacleData: ObstacleData = {
		part = obstacle,
		obstacleType = obstacleType,
		spawnTime = tick(),
	}
	table.insert(self._activeObstacles, obstacleData)
end

-- 충돌 체크 (GameManager에서 호출)
function ObstacleService:CheckObstacleCollision(playerPosition: Vector3, isSliding: boolean): boolean
	-- 무적 상태 확인
	if self._isInvincible then
		local elapsed = tick() - self._lastHitTime
		if elapsed >= GameConstants.LIFE.INVINCIBLE_DURATION then
			self._isInvincible = false
			print(`[ObstacleService] Invincibility ended for {self._player.Name}`)
		else
			return false -- 무적 중에는 충돌 무시
		end
	end

	for _, obstacleData in self._activeObstacles do
		local obstaclePart = obstacleData.part
		local obstacleType = obstacleData.obstacleType

		-- 거리 체크
		local distance = (obstaclePart.Position - playerPosition).Magnitude

		-- 충돌 반경 (캐릭터 크기 + 장애물 크기 고려)
		local collisionRadius = 5

		if distance < collisionRadius then
			-- 장애물 타입별 회피 조건 확인
			if obstacleType == "LowWall" then
				-- LowWall: 점프 중이면 회피 성공
				-- 현재 간단하게 Y 좌표로 판단 (향후 개선)
				if playerPosition.Y > GameConstants.OBSTACLE.LOW_WALL_HEIGHT then
					-- 점프로 회피 성공
					print(`[ObstacleService] {self._player.Name} jumped over LowWall!`)
					continue
				else
					-- 충돌
					return true
				end
			elseif obstacleType == "Tunnel" then
				-- Tunnel: 슬라이드 중이고 높이가 낮으면 회피 성공
				local tunnelHeight = GameConstants.OBSTACLE.TUNNEL_HEIGHT
				local playerHeight = playerPosition.Y

				if isSliding and playerHeight < tunnelHeight then
					-- 슬라이드로 통과 성공
					print(`[ObstacleService] {self._player.Name} slid through Tunnel! (Y: {playerHeight})`)
					continue
				elseif playerHeight < tunnelHeight then
					-- 슬라이드 안하고 낮은 위치 - 통과 (달리다가 우연히 통과)
					print(`[ObstacleService] {self._player.Name} passed under Tunnel (Y: {playerHeight})`)
					continue
				else
					-- 충돌 (서 있거나 점프 중인데 터널 높이 이상)
					print(`[ObstacleService] {self._player.Name} hit Tunnel! (Y: {playerHeight}, sliding: {isSliding})`)
					return true
				end
			elseif obstacleType == "SpikeTrap" then
				-- SpikeTrap: 점프로 회피 (가시 함정 높이 3.5 이상)
				if playerPosition.Y > 3.5 then
					print(`[ObstacleService] {self._player.Name} jumped over SpikeTrap!`)
					continue
				else
					-- 충돌
					return true
				end
			elseif obstacleType == "DoubleWall" then
				-- DoubleWall: 점프로 회피 (연속 점프 필요)
				if playerPosition.Y > GameConstants.OBSTACLE.LOW_WALL_HEIGHT then
					print(`[ObstacleService] {self._player.Name} jumped over DoubleWall!`)
					continue
				else
					-- 충돌
					return true
				end
			elseif obstacleType == "Gap" then
				-- Gap: 점프 중이면 회피 성공
				if playerPosition.Y > 2 then
					print(`[ObstacleService] {self._player.Name} jumped over Gap!`)
					continue
				else
					-- 낙사
					return true
				end
			end
		end
	end

	return false -- 충돌 없음
end

-- 충돌 처리 (라이프 감소 및 무적 설정)
function ObstacleService:OnObstacleHit()
	self._isInvincible = true
	self._lastHitTime = tick()
	print(`[ObstacleService] {self._player.Name} hit obstacle! Invincible for {GameConstants.LIFE.INVINCIBLE_DURATION}s`)
end

-- 무적 상태 확인
function ObstacleService:IsInvincible(): boolean
	return self._isInvincible
end

-- 청크 삭제 시 관련 장애물 정리
function ObstacleService:CleanupObstaclesInChunk(chunkPosition: Vector3, chunkSize: Vector3)
	for i = #self._activeObstacles, 1, -1 do
		local obstacleData = self._activeObstacles[i]
		local obstaclePos = obstacleData.part.Position

		-- 장애물이 청크 영역 내에 있는지 확인
		local isInChunk = math.abs(obstaclePos.X - chunkPosition.X) < chunkSize.X / 2
			and math.abs(obstaclePos.Y - chunkPosition.Y) < chunkSize.Y / 2
			and math.abs(obstaclePos.Z - chunkPosition.Z) < chunkSize.Z / 2

		if isInChunk then
			obstacleData.part:Destroy()
			table.remove(self._activeObstacles, i)
		end
	end
end

-- 모든 장애물 정리 (게임 종료 시)
function ObstacleService:Destroy()
	for _, obstacleData in self._activeObstacles do
		if obstacleData.part then
			obstacleData.part:Destroy()
		end
	end
	self._activeObstacles = {}
end

return ObstacleService

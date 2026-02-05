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
		return math.random(1, 2) -- 쉬운 청크: 장애물 적음
	elseif difficulty == "Normal" then
		return math.random(2, 3)
	elseif difficulty == "Hard" then
		return math.random(3, 5) -- 어려운 청크: 장애물 많음
	elseif difficulty == "Bonus" then
		return math.random(0, 1) -- 보너스는 장애물 거의 없음
	elseif difficulty == "NPC" then
		return math.random(1, 2)
	end

	return 2 -- 기본값
end

-- 장애물 타입 선택
function ObstacleService:_selectObstacleType(difficulty: string): string
	local rand = math.random()

	if difficulty == "Easy" then
		-- Easy는 Low Wall만 (점프만 연습)
		return "LowWall"
	elseif difficulty == "Normal" then
		-- Normal은 Low Wall + Tunnel
		if rand < 0.60 then
			return "LowWall"
		elseif rand < 0.90 then
			return "Tunnel"
		else
			return "Gap"
		end
	elseif difficulty == "Hard" then
		-- Hard는 모든 타입
		if rand < 0.40 then
			return "LowWall"
		elseif rand < 0.70 then
			return "Tunnel"
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
		obstacle.Size = Vector3.new(2, GameConstants.OBSTACLE.LOW_WALL_HEIGHT, 8) -- 폭×높이×깊이
		obstacle.Position = position + Vector3.new(0, GameConstants.OBSTACLE.LOW_WALL_HEIGHT / 2, 0)
		obstacle.BrickColor = BrickColor.new("Bright red")
	elseif obstacleType == "Tunnel" then
		-- 높은 벽 + 터널 (슬라이드로 회피)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_Tunnel"
		obstacle.Size = Vector3.new(2, 10, 8) -- 높은 벽
		obstacle.Position = position + Vector3.new(0, 5, 0)
		obstacle.BrickColor = BrickColor.new("Bright red")

		-- 터널 공간 표시 (투명한 Part, 시각적 가이드)
		local tunnelGuide = Instance.new("Part")
		tunnelGuide.Name = "TunnelGuide"
		tunnelGuide.Size = Vector3.new(2, GameConstants.OBSTACLE.TUNNEL_HEIGHT, 8)
		tunnelGuide.Position = position + Vector3.new(0, GameConstants.OBSTACLE.TUNNEL_HEIGHT / 2, 0)
		tunnelGuide.Transparency = 0.7
		tunnelGuide.BrickColor = BrickColor.new("Bright green")
		tunnelGuide.CanCollide = false
		tunnelGuide.Anchored = true
		tunnelGuide.Parent = workspace
	elseif obstacleType == "Gap" then
		-- 구덩이 (점프로 건너기)
		obstacle = Instance.new("Part")
		obstacle.Name = "Obstacle_Gap"
		local gapWidth = math.random(
			GameConstants.OBSTACLE.GAP_WIDTH_MIN,
			GameConstants.OBSTACLE.GAP_WIDTH_MAX
		)
		obstacle.Size = Vector3.new(gapWidth, 1, 8) -- 바닥 구멍
		obstacle.Position = position + Vector3.new(0, -5, 0) -- 아래로 내림 (낙사 판정용)
		obstacle.BrickColor = BrickColor.new("Really black")
		obstacle.Transparency = 0.5
	else
		obstacle = Instance.new("Part")
		obstacle.Size = Vector3.new(2, 4, 8)
		obstacle.Position = position
	end

	obstacle.Anchored = true
	obstacle.CanCollide = true
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
				-- Tunnel: 슬라이드 중이면 회피 성공
				if isSliding then
					print(`[ObstacleService] {self._player.Name} slid through Tunnel!`)
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

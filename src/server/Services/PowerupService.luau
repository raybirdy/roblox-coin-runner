--!strict
-- Powerup Service
-- 파워업 생성 및 효과 관리 (자석, 쉴드)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local PowerupService = {}
PowerupService.__index = PowerupService

type PowerupData = {
	part: BasePart,
	powerupType: string,
	spawnTime: number,
}

export type PowerupService = typeof(setmetatable(
	{} :: {
		_activePowerups: { PowerupData },
		_player: Player,
		_gameStartTime: number,
		_lastSpawnTime: number,
		-- 활성 효과
		_magnetActive: boolean,
		_magnetEndTime: number,
		_shieldActive: boolean,
		_shieldUses: number,
	},
	PowerupService
))

function PowerupService.new(player: Player): PowerupService
	local self = setmetatable({
		_activePowerups = {},
		_player = player,
		_gameStartTime = 0,
		_lastSpawnTime = 0,
		_magnetActive = false,
		_magnetEndTime = 0,
		_shieldActive = false,
		_shieldUses = 0,
	}, PowerupService)

	return self
end

-- 게임 시작 시 호출
function PowerupService:StartGame()
	self._gameStartTime = tick()
	self._lastSpawnTime = 0
end

-- 청크 내 파워업 생성 (확률적)
function PowerupService:TrySpawnPowerupInChunk(chunk: Model, difficulty: string): boolean
	local elapsedTime = tick() - self._gameStartTime

	-- 첫 파워업은 20초 후부터
	if elapsedTime < GameConstants.POWERUP.MIN_SPAWN_TIME then
		return false
	end

	-- 마지막 스폰 이후 15초 미만이면 스폰 안 함
	local timeSinceLastSpawn = tick() - self._lastSpawnTime
	if timeSinceLastSpawn < GameConstants.POWERUP.MIN_INTERVAL then
		return false
	end

	-- 30% 확률로 파워업 스폰
	if math.random() > 0.30 then
		return false
	end

	-- 파워업 타입 선택
	local powerupType = self:_selectPowerupType()

	-- 청크 중앙에 스폰
	local chunkCFrame = chunk:GetPrimaryPartCFrame()
	local spawnPosition = chunkCFrame.Position + Vector3.new(0, 3, 0) -- 약간 위에

	self:_spawnPowerup(spawnPosition, powerupType)
	self._lastSpawnTime = tick()

	return true
end

-- 파워업 타입 선택 (가중 랜덤)
function PowerupService:_selectPowerupType(): string
	local rand = math.random()

	-- MVP: 자석 60%, 쉴드 40%
	if rand < GameConstants.POWERUP.MAGNET_RATE then
		return "Magnet"
	else
		return "Shield"
	end
end

-- 파워업 생성 (BasePart)
function PowerupService:_spawnPowerup(position: Vector3, powerupType: string)
	local powerup = Instance.new("Part")
	powerup.Name = "Powerup_" .. powerupType
	powerup.Shape = Enum.PartType.Ball
	powerup.Size = Vector3.new(3, 3, 3)
	powerup.Position = position
	powerup.Anchored = true
	powerup.CanCollide = false
	powerup.Material = Enum.Material.Neon
	powerup.Transparency = 0.2

	-- 타입별 색상
	if powerupType == "Magnet" then
		powerup.BrickColor = BrickColor.new("Bright blue")
	elseif powerupType == "Shield" then
		powerup.BrickColor = BrickColor.new("Bright green")
	end

	powerup:SetAttribute("PowerupType", powerupType)
	powerup.Parent = workspace

	-- 파워업 데이터 저장
	local powerupData: PowerupData = {
		part = powerup,
		powerupType = powerupType,
		spawnTime = tick(),
	}
	table.insert(self._activePowerups, powerupData)

	print(`[PowerupService] Spawned {powerupType} powerup at {position}`)
end

-- 파워업 수집 체크 (GameManager에서 호출)
function PowerupService:CheckPowerupCollection(playerPosition: Vector3): { PowerupData }
	local collectedPowerups = {}

	for i = #self._activePowerups, 1, -1 do
		local powerupData = self._activePowerups[i]
		local distance = (powerupData.part.Position - playerPosition).Magnitude

		-- 수집 반경
		local collectionRadius = 4

		if distance < collectionRadius then
			table.insert(collectedPowerups, powerupData)

			-- 파워업 제거
			powerupData.part:Destroy()
			table.remove(self._activePowerups, i)
		end
	end

	return collectedPowerups
end

-- 파워업 효과 활성화
function PowerupService:ActivatePowerup(powerupType: string)
	if powerupType == "Magnet" then
		self._magnetActive = true
		self._magnetEndTime = tick() + GameConstants.POWERUP.MAGNET_DURATION
		print(`[PowerupService] Magnet activated for {GameConstants.POWERUP.MAGNET_DURATION}s`)
	elseif powerupType == "Shield" then
		self._shieldActive = true
		self._shieldUses = GameConstants.POWERUP.SHIELD_USES
		print(`[PowerupService] Shield activated ({self._shieldUses} uses)`)
	end
end

-- 자석 효과 체크 (코인 자동 수집)
function PowerupService:IsMagnetActive(): boolean
	if self._magnetActive then
		if tick() >= self._magnetEndTime then
			self._magnetActive = false
			print("[PowerupService] Magnet expired")
			return false
		end
		return true
	end
	return false
end

-- 자석 반경 반환
function PowerupService:GetMagnetRadius(): number
	if self:IsMagnetActive() then
		return GameConstants.POWERUP.MAGNET_RADIUS
	end
	return 0
end

-- 쉴드 효과 체크 (장애물 방어)
function PowerupService:TryUseShield(): boolean
	if self._shieldActive and self._shieldUses > 0 then
		self._shieldUses -= 1
		print(`[PowerupService] Shield used! Remaining uses: {self._shieldUses}`)

		if self._shieldUses <= 0 then
			self._shieldActive = false
			print("[PowerupService] Shield depleted")
		end

		return true
	end
	return false
end

-- 쉴드 활성 여부
function PowerupService:HasShield(): boolean
	return self._shieldActive and self._shieldUses > 0
end

-- 청크 삭제 시 관련 파워업 정리
function PowerupService:CleanupPowerupsInChunk(chunkPosition: Vector3, chunkSize: Vector3)
	for i = #self._activePowerups, 1, -1 do
		local powerupData = self._activePowerups[i]
		local powerupPos = powerupData.part.Position

		local isInChunk = math.abs(powerupPos.X - chunkPosition.X) < chunkSize.X / 2
			and math.abs(powerupPos.Y - chunkPosition.Y) < chunkSize.Y / 2
			and math.abs(powerupPos.Z - chunkPosition.Z) < chunkSize.Z / 2

		if isInChunk then
			powerupData.part:Destroy()
			table.remove(self._activePowerups, i)
		end
	end
end

-- 정리
function PowerupService:Destroy()
	for _, powerupData in self._activePowerups do
		if powerupData.part then
			powerupData.part:Destroy()
		end
	end
	self._activePowerups = {}
end

return PowerupService

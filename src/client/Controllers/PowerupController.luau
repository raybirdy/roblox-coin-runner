--!strict
-- Powerup Controller
-- 파워업 수집 피드백 처리

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local PowerupController = {}
PowerupController.__index = PowerupController

export type PowerupController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_activePowerups: { [string]: boolean },
	},
	PowerupController
))

function PowerupController.new(): PowerupController
	local self = setmetatable({
		_connections = {},
		_activePowerups = {},
	}, PowerupController)

	self:_setupEventHandlers()

	return self
end

-- 파워업 수집 이벤트 처리
function PowerupController:_setupEventHandlers()
	local connection = RemoteEvents.PowerupCollected.OnClientEvent:Connect(function(data)
		self:OnPowerupCollected(data)
	end)

	table.insert(self._connections, connection)
end

-- 파워업 수집 시 호출
function PowerupController:OnPowerupCollected(data: { powerupType: string })
	local powerupType = data.powerupType

	if powerupType == "Magnet" then
		print(`[PowerupController] Magnet activated! (Duration: {GameConstants.POWERUP.MAGNET_DURATION}s)`)
		self._activePowerups["Magnet"] = true

		-- 5초 후 비활성화
		task.delay(GameConstants.POWERUP.MAGNET_DURATION, function()
			self._activePowerups["Magnet"] = false
			print("[PowerupController] Magnet expired")
		end)

		-- TODO MVP 이후:
		-- 1. 자석 아이콘 표시 (UI)
		-- 2. 자석 사운드 재생
		-- 3. 캐릭터 주변 자기장 파티클 효과
	elseif powerupType == "Shield" then
		print(`[PowerupController] Shield activated! (Uses: {GameConstants.POWERUP.SHIELD_USES})`)
		self._activePowerups["Shield"] = true

		-- TODO MVP 이후:
		-- 1. 쉴드 아이콘 표시 (UI)
		-- 2. 쉴드 사운드 재생
		-- 3. 캐릭터 주변 쉴드 이펙트 (반투명 구체)
	elseif powerupType == "ShieldUsed" then
		print("[PowerupController] Shield blocked an obstacle!")

		-- TODO MVP 이후:
		-- 1. 쉴드 파괴 이펙트
		-- 2. 쉴드 방어 사운드
		-- 3. 화면 효과 (플래시)
	end
end

-- 파워업 활성 여부 확인
function PowerupController:IsPowerupActive(powerupType: string): boolean
	return self._activePowerups[powerupType] == true
end

-- 정리
function PowerupController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
	self._activePowerups = {}
end

return PowerupController

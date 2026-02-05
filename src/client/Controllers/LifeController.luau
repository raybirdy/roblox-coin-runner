--!strict
-- Life Controller
-- 라이프 업데이트 및 피드백 처리

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local LifeController = {}
LifeController.__index = LifeController

export type LifeController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_currentLives: number,
	},
	LifeController
))

function LifeController.new(): LifeController
	local self = setmetatable({
		_connections = {},
		_currentLives = GameConstants.LIFE.STARTING_LIVES,
	}, LifeController)

	self:_setupEventHandlers()

	return self
end

-- 라이프 업데이트 이벤트 처리
function LifeController:_setupEventHandlers()
	local connection = RemoteEvents.LifeUpdate.OnClientEvent:Connect(function(data)
		self:OnLifeUpdate(data)
	end)

	table.insert(self._connections, connection)
end

-- 라이프 변경 시 호출
function LifeController:OnLifeUpdate(data: { lives: number })
	local previousLives = self._currentLives
	self._currentLives = data.lives

	-- 라이프 감소 피드백
	if data.lives < previousLives then
		print(`[LifeController] Lost a life! Remaining lives: {data.lives}`)

		-- 화면 흔들림 트리거 (CameraController에 알림)
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local cameraShakeEvent = ReplicatedStorage:FindFirstChild("CameraShake")
		if cameraShakeEvent and cameraShakeEvent:IsA("BindableEvent") then
			cameraShakeEvent:Fire(0.5) -- 중간 강도
		end

		-- TODO MVP 이후:
		-- 1. 빨간 비네트 효과
		-- 2. 사운드 효과
		-- 3. UI 하트 애니메이션
	end

	-- 라이프 0 경고
	if data.lives == 0 then
		print("[LifeController] No lives left! Game Over imminent...")
	end
end

-- 현재 라이프 반환
function LifeController:GetCurrentLives(): number
	return self._currentLives
end

-- 정리
function LifeController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return LifeController

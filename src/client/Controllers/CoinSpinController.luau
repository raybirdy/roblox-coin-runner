--!strict
-- Coin Spin Controller
-- 클라이언트 측 코인 스핀 시각 효과
-- 워크스페이스에 "Coin_" 접두어를 가진 Model들을 매 프레임 회전

local RunService = game:GetService("RunService")

local CoinSpinController = {}
CoinSpinController.__index = CoinSpinController

-- 캐시 갱신 간격 (초): 매 프레임마다 workspace를 순회하지 않도록 주기적으로만 갱신
local CACHE_REFRESH_INTERVAL = 0.5
local SPIN_SPEED = 3 -- radians/second

export type CoinSpinController = typeof(setmetatable(
	{} :: {
		_connection: RBXScriptConnection?,
		_coinCache: { Model },
		_lastCacheTime: number,
	},
	CoinSpinController
))

function CoinSpinController.new(): CoinSpinController
	local self = setmetatable({
		_connection = nil,
		_coinCache = {},
		_lastCacheTime = 0,
	}, CoinSpinController)

	self:_start()

	return self
end

-- 워크스페이스에서 "Coin_" 접두어 Model을 찾아 캐시 갱신
function CoinSpinController:_refreshCache()
	local fresh: { Model } = {}
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and child.Name:sub(1, 5) == "Coin_" then
			table.insert(fresh, child)
		end
	end
	self._coinCache = fresh
end

-- Heartbeat 루프 시작
function CoinSpinController:_start()
	self._connection = RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()

		-- 주기적으로 캐시 갱신
		if now - self._lastCacheTime >= CACHE_REFRESH_INTERVAL then
			self:_refreshCache()
			self._lastCacheTime = now
		end

		-- 캐시된 코인 모델 회전 적용
		for i = #self._coinCache, 1, -1 do
			local coinModel = self._coinCache[i]
			-- 코인이 수집되거나 제거된 경우 캐시에서 삭제
			if not coinModel.Parent then
				table.remove(self._coinCache, i)
				continue
			end

			local primaryPart = coinModel.PrimaryPart
			if primaryPart and primaryPart.Parent then
				-- 현재 CFrame에 Y축 회전 추가 (dt * SPIN_SPEED rad/frame)
				coinModel:SetPrimaryPartCFrame(primaryPart.CFrame * CFrame.Angles(0, dt * SPIN_SPEED, 0))
			end
		end
	end)

	print("[CoinSpinController] Coin spin started")
end

-- 정리
function CoinSpinController:Destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
	self._coinCache = {}
	print("[CoinSpinController] Destroyed")
end

return CoinSpinController

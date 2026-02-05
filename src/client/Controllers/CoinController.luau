--!strict
-- Coin Controller
-- 코인 수집 피드백 처리 (시각/청각 효과)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local CoinController = {}
CoinController.__index = CoinController

export type CoinController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_totalCoins: number,
	},
	CoinController
))

function CoinController.new(): CoinController
	local self = setmetatable({
		_connections = {},
		_totalCoins = 0,
	}, CoinController)

	self:_setupEventHandlers()

	return self
end

-- 코인 수집 이벤트 처리
function CoinController:_setupEventHandlers()
	local connection = RemoteEvents.CoinCollected.OnClientEvent:Connect(function(data)
		self:OnCoinCollected(data)
	end)

	table.insert(self._connections, connection)
end

-- 코인 수집 시 호출
function CoinController:OnCoinCollected(data: { coinType: string, coinValue: number, totalCoins: number })
	self._totalCoins = data.totalCoins

	-- 시각 효과 (MVP: 콘솔 로그만)
	print(`[CoinController] Collected {data.coinType} coin! +{data.coinValue} (Total: {data.totalCoins})`)

	-- TODO MVP 이후:
	-- 1. 코인 수집 사운드 재생
	-- 2. UI에 "+1" 또는 "+5" 팝업 표시
	-- 3. 코인 카운터 UI 업데이트
	-- 4. 파티클 효과
end

-- 현재 총 코인 수 반환
function CoinController:GetTotalCoins(): number
	return self._totalCoins
end

-- 정리
function CoinController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return CoinController

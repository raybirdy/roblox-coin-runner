--!strict
-- Leaderboard Controller
-- 리더보드 관련 클라이언트 로직 (로비에 물리적 간판으로 표시됨)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local LeaderboardController = {}
LeaderboardController.__index = LeaderboardController

export type LeaderboardController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_playerRank: number?,
		_connections: { RBXScriptConnection },
	},
	LeaderboardController
))

function LeaderboardController.new(player: Player): LeaderboardController
	local self = setmetatable({
		_player = player,
		_playerRank = nil,
		_connections = {},
	}, LeaderboardController)

	self:_setupEventHandlers()

	return self
end

-- 이벤트 핸들러 설정
function LeaderboardController:_setupEventHandlers()
	-- 리더보드 데이터 수신 (내 순위 저장)
	local dataConnection = RemoteEvents.LeaderboardData.OnClientEvent:Connect(function(data)
		self._playerRank = data.playerRank
		print(`[LeaderboardController] My rank: {data.playerRank or "Not ranked"}`)
	end)
	table.insert(self._connections, dataConnection)

	print("[LeaderboardController] Event handlers set up (lobby display mode)")
end

-- 리더보드 데이터 요청 (서버에서 로비 간판 업데이트)
function LeaderboardController:RequestUpdate()
	RemoteEvents.LeaderboardRequest:FireServer()
end

-- 내 순위 가져오기
function LeaderboardController:GetPlayerRank(): number?
	return self._playerRank
end

-- 로비 진입 시 호출 (리더보드 요청)
function LeaderboardController:Show()
	-- 서버에 리더보드 데이터 요청 (로비 간판 업데이트 트리거)
	self:RequestUpdate()
	print("[LeaderboardController] Requested leaderboard update")
end

-- 게임 시작 시 호출 (아무 작업 없음 - 로비 간판은 항상 표시)
function LeaderboardController:Hide()
	-- 로비 간판은 물리적이므로 숨길 필요 없음
	print("[LeaderboardController] Game started (lobby board remains)")
end

-- 표시 여부 (항상 false - UI 없음)
function LeaderboardController:IsVisible(): boolean
	return false
end

-- 정리
function LeaderboardController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return LeaderboardController

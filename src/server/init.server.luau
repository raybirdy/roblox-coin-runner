--!strict
-- Server Entry Point
-- 서버 측 진입점 - 모든 서버 서비스 초기화

print("[Server] Coin Runner Server Starting...")

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 기본 Baseplate 제거 (우리만의 바닥 사용)
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
	print("[Server] Removed default Baseplate")
end

-- 공유 모듈 로드
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

-- 서버 서비스 로드
local GameManager = require(ServerScriptService.Server.Services.GameManager)
local PlayerDataService = require(ServerScriptService.Server.Services.PlayerDataService)
local LobbyService = require(ServerScriptService.Server.Services.LobbyService)
local ShopService = require(ServerScriptService.Server.Services.ShopService)
local MonetizationService = require(ServerScriptService.Server.Services.MonetizationService)
local ProgressionService = require(ServerScriptService.Server.Services.ProgressionService)
local LuckySpinService = require(ServerScriptService.Server.Services.LuckySpinService)

print("[Server] Game Constants Loaded")
print("[Server] Remote Events Initialized")
print("[Server] GameManager Loaded")
print("[Server] PlayerDataService Loaded")
print("[Server] LobbyService Loaded")
print("[Server] ShopService Loaded")
print("[Server] MonetizationService Loaded")
print("[Server] ProgressionService Loaded")
print("[Server] LuckySpinService Loaded")

-- 플레이어 참가 처리
game.Players.PlayerAdded:Connect(function(player: Player)
	print(`[Server] Player {player.Name} joined`)

	-- 플레이어 데이터 로드
	local playerData = PlayerDataService:LoadPlayerData(player)

	if playerData then
		-- 일일 미션 초기화
		ProgressionService:InitDailyMissions(player)

		-- 클라이언트에 데이터 전송
		RemoteEvents.PlayerDataLoaded:FireClient(player, playerData)
		print(`[Server] Sent player data to {player.Name}`)
	end

	-- 플레이어 캐릭터 설정 대기
	player.CharacterAdded:Connect(function(character: Model)
		print(`[Server] Character spawned for {player.Name}`)
	end)
end)

-- 클라이언트 초기화 후 데이터 요청 처리
RemoteEvents.PlayerDataRequest.OnServerEvent:Connect(function(player: Player)
	if not RateLimiter.Check(player, "PlayerDataRequest", 1) then
		return
	end

	local playerData = PlayerDataService:GetPlayerData(player)
	if playerData then
		RemoteEvents.PlayerDataLoaded:FireClient(player, playerData)
		print(`[Server] Re-sent player data to {player.Name} (client request)`)
	end
end)

-- 플레이어 퇴장 처리
game.Players.PlayerRemoving:Connect(function(player: Player)
	print(`[Server] Player {player.Name} leaving`)

	-- 플레이어 데이터 저장
	PlayerDataService:OnPlayerRemoving(player)
end)

-- 서버 종료 시 모든 플레이어 데이터 저장
game:BindToClose(function()
	print("[Server] Server shutting down, saving all player data...")

	-- 모든 플레이어 데이터 저장
	PlayerDataService:SaveAllPlayers()

	task.wait(3) -- DataStore 저장 완료 대기
end)

print("[Server] Coin Runner Server Ready")

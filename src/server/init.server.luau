--!strict
-- Server Entry Point
-- 서버 측 진입점 - 모든 서버 서비스 초기화

print("[Server] Coin Runner Server Starting...")

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 공유 모듈 로드
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- 서버 서비스 로드
local GameManager = require(ServerScriptService.Server.Services.GameManager)
-- local PlayerDataService = require(ServerScriptService.Server.Services.PlayerDataService)

print("[Server] Game Constants Loaded")
print("[Server] Remote Events Initialized")
print("[Server] GameManager Loaded")

-- 플레이어 참가 처리
game.Players.PlayerAdded:Connect(function(player: Player)
	print(`[Server] Player {player.Name} joined`)

	-- 플레이어 데이터 로드 (향후 구현)
	-- PlayerDataService:LoadPlayerData(player)

	-- 플레이어 캐릭터 설정 대기
	player.CharacterAdded:Connect(function(character: Model)
		print(`[Server] Character spawned for {player.Name}`)

		-- 캐릭터 초기 설정 (향후 구현)
		-- GameManager:SetupPlayerCharacter(player, character)
	end)
end)

-- 플레이어 퇴장 처리
game.Players.PlayerRemoving:Connect(function(player: Player)
	print(`[Server] Player {player.Name} leaving`)

	-- 플레이어 데이터 저장 (향후 구현)
	-- PlayerDataService:SavePlayerData(player)
end)

-- 서버 종료 시 모든 플레이어 데이터 저장
game:BindToClose(function()
	print("[Server] Server shutting down, saving all player data...")

	-- 모든 플레이어 데이터 저장 (향후 구현)
	-- PlayerDataService:SaveAllPlayers()

	wait(3) -- DataStore 저장 완료 대기
end)

print("[Server] Coin Runner Server Ready")

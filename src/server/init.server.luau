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
local _GameManager = require(ServerScriptService.Server.Services.GameManager)
local PlayerDataService = require(ServerScriptService.Server.Services.PlayerDataService)
local _LobbyService = require(ServerScriptService.Server.Services.LobbyService)
local _ShopService = require(ServerScriptService.Server.Services.ShopService)
local _MonetizationService = require(ServerScriptService.Server.Services.MonetizationService)
local ProgressionService = require(ServerScriptService.Server.Services.ProgressionService)
local LoginRewardService = require(ServerScriptService.Server.Services.LoginRewardService)
local _LuckySpinService = require(ServerScriptService.Server.Services.LuckySpinService)
local _ScenarioService = require(ServerScriptService.Server.Services.ScenarioService)
local BossRunService = require(ServerScriptService.Server.Services.BossRunService)
local WeeklyRankingService = require(ServerScriptService.Server.Services.WeeklyRankingService)
local AsyncBattleService = require(ServerScriptService.Server.Services.AsyncBattleService)
local RealtimeBattleService = require(ServerScriptService.Server.Services.RealtimeBattleService)
local DailyEventService = require(ServerScriptService.Server.Services.DailyEventService)
local UpgradeService = require(ServerScriptService.Server.Services.UpgradeService)
local PetService = require(ServerScriptService.Server.Services.PetService)
local NametagService = require(ServerScriptService.Server.Services.NametagService)
local CharacterService = require(ServerScriptService.Server.Services.CharacterService)
local RunSkillService = require(ServerScriptService.Server.Services.RunSkillService)
local ReferralService = require(ServerScriptService.Server.Services.ReferralService)
local LobbyNpcService = require(ServerScriptService.Server.Services.LobbyNpcService)
-- BattlePassService is required here to call OnPlayerJoined; Init is handled by GameManager
local BattlePassService = require(ServerScriptService.Server.Services.BattlePassService)
-- GhostService is required and initialised inside GameManager (requires PlayerDataService dep)
local _GhostService = require(ServerScriptService.Server.Services.GhostService)
-- TeamService is required here to call CheckWeeklyReset; Init is handled by GameManager
local TeamService = require(ServerScriptService.Server.Services.TeamService)
local CoopMatchService = require(ServerScriptService.Server.Services.CoopMatchService)

print("[Server] Game Constants Loaded")
print("[Server] Remote Events Initialized")
print("[Server] GameManager Loaded")
print("[Server] PlayerDataService Loaded")
print("[Server] LobbyService Loaded")
print("[Server] ShopService Loaded")
print("[Server] MonetizationService Loaded")
print("[Server] ProgressionService Loaded")
print("[Server] LoginRewardService Loaded")
print("[Server] LuckySpinService Loaded")

-- ScenarioService RemoteEvent 연결
_ScenarioService:SetupRemoteEvents()
print("[Server] ScenarioService Loaded")

-- BossRunService RemoteEvent 연결
BossRunService:SetupRemoteEvents()
print("[Server] BossRunService Loaded")

-- WeeklyRankingService RemoteEvent 연결
WeeklyRankingService:SetupRemoteEvents()
print("[Server] WeeklyRankingService Loaded")

-- AsyncBattleService RemoteEvent 연결
AsyncBattleService:SetupRemoteEvents()
print("[Server] AsyncBattleService Loaded")

-- RealtimeBattleService RemoteEvent 연결
RealtimeBattleService:SetupRemoteEvents()
print("[Server] RealtimeBattleService Loaded")
print("[Server] DailyEventService Loaded")

-- UpgradeService RemoteEvent 연결
UpgradeService:SetupRemoteEvents(PlayerDataService)
print("[Server] UpgradeService Loaded")

-- PetService RemoteEvent 연결
PetService:SetupRemoteEvents(PlayerDataService)
print("[Server] PetService Loaded")

-- NametagService RemoteEvent 연결
NametagService:SetupRemoteEvents(PlayerDataService)
print("[Server] NametagService Loaded")

-- CharacterService RemoteEvent 연결
CharacterService:SetupRemoteEvents(PlayerDataService)
print("[Server] CharacterService Loaded")

-- RunSkillService RemoteEvent 연결
RunSkillService:SetupRemoteEvents(PlayerDataService)
print("[Server] RunSkillService Loaded")

-- 로비 NPC 초기화
LobbyNpcService:Init()
print("[Server] LobbyNpcService Loaded")

print("[Server] CoopMatchService Loaded")

print("[Server] BattlePassService Loaded")

-- 플레이어 참가 처리
game.Players.PlayerAdded:Connect(function(player: Player)
	print(`[Server] Player {player.Name} joined`)

	-- 플레이어 데이터 로드
	local playerData = PlayerDataService:LoadPlayerData(player)

	if playerData then
		-- 일일 미션 초기화
		ProgressionService:InitDailyMissions(player)

		-- 출석 보상 체크
		LoginRewardService:OnPlayerJoined(player)

		-- 클라이언트에 데이터 전송
		RemoteEvents.PlayerDataLoaded:FireClient(player, playerData)

		-- 데일리 이벤트 데이터 전송
		DailyEventService:SendEventData(player, playerData)

		-- 업그레이드 데이터 전송
		UpgradeService:SendUpgradeData(player, PlayerDataService)

		-- 펫 데이터 전송
		PetService:SendPetData(player, PlayerDataService)

		-- 이름표 데이터 전송
		NametagService:SendNametagData(player, PlayerDataService)


		-- 캐릭터 데이터 전송
		CharacterService:SendCharacterData(player, PlayerDataService)

		-- 캐릭터 비주얼 즉시 적용 (데이터 로드 완료 후)
		local equippedChar = playerData.equippedCharacter or "runner"
		if equippedChar ~= "runner" and player.Character then
			CharacterService:ApplyCharacterModel(player, equippedChar)
		end

		-- 런 스킬 슬롯 데이터 전송
		RunSkillService:SendPreRunSkillData(player, PlayerDataService)

		-- 초대 보상 체크
		ReferralService:OnPlayerJoin(player)

		-- 배틀패스 일일 XP 지급 및 데이터 전송
		BattlePassService:OnPlayerJoined(player)

		-- 팀 주간 리셋 체크 (매주 리셋 + 팀 데이터 클라이언트 전송)
		TeamService:CheckWeeklyReset(player)

		print(`[Server] Sent player data to {player.Name}`)
	end

	-- 플레이어 캐릭터 설정 대기
	player.CharacterAdded:Connect(function(_character: Model)
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

-- 서버 종료 시 모든 플레이어 데이터 저장 (병렬, 완료까지 대기)
game:BindToClose(function()
	print("[Server] Server shutting down, saving all player data...")

	-- SaveAllPlayers는 내부적으로 병렬 저장 후 전체 완료 시까지 대기
	-- 순차 저장(10명 × 3초 = 30초) → 병렬 저장(max 3초)
	PlayerDataService:SaveAllPlayers()

	print("[Server] All player data saved. Shutdown complete.")
end)

-- 주기적 자동 저장 (서버 크래시/모바일 강제 종료 대비)
task.spawn(function()
	while true do
		task.wait(GameConstants.DATA.AUTO_SAVE_INTERVAL)
		for _, player in game.Players:GetPlayers() do
			task.spawn(function()
				PlayerDataService:SavePlayerData(player)
			end)
		end
	end
end)

print("[Server] Coin Runner Server Ready")

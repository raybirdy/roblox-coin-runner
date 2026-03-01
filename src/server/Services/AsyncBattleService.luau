--!strict
-- AsyncBattleService
-- 비동기 배틀: 타인의 기록에 도전하는 기록 비교 모드

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local AsyncBattleService = {}

type BattleTarget = {
	targetName: string,
	targetScore: number,
}

-- 플레이어별 도전 타겟 (게임 시작 전 로비에서 설정됨)
local _battleTargets: { [Player]: BattleTarget } = {}

local WIN_REWARD_GEMS = 50

-- ==================== 타겟 관리 ====================

function AsyncBattleService:SetBattleTarget(player: Player, targetName: string, targetScore: number)
	_battleTargets[player] = { targetName = targetName, targetScore = targetScore }
	print(`[AsyncBattleService] {player.Name} → 도전 타겟: {targetName} ({targetScore}점)`)
end

function AsyncBattleService:GetBattleTarget(player: Player): BattleTarget?
	return _battleTargets[player]
end

function AsyncBattleService:ClearBattleTarget(player: Player)
	_battleTargets[player] = nil
end

-- ==================== 게임 종료 처리 ====================

-- GameManager.EndGame에서 호출됨
function AsyncBattleService:ProcessGameEnd(
	player: Player,
	finalScore: number,
	battleTarget: BattleTarget?
)
	if not battleTarget then
		return
	end

	local won = finalScore >= battleTarget.targetScore
	local reward = 0

	if won then
		reward = WIN_REWARD_GEMS
		PlayerDataService:AddGems(player, reward)
		local newGems = PlayerDataService:GetGems(player)
		RemoteEvents.GemsUpdated:FireClient(player, { gems = newGems })
		print(`[AsyncBattleService] {player.Name} 승리! {finalScore} >= {battleTarget.targetScore} (+{reward} 💎)`)
	else
		print(`[AsyncBattleService] {player.Name} 패배. {finalScore} < {battleTarget.targetScore}`)
	end

	RemoteEvents.AsyncBattleResult:FireClient(player, {
		won = won,
		myScore = finalScore,
		targetScore = battleTarget.targetScore,
		targetName = battleTarget.targetName,
		reward = won and reward or nil,
	})
end

-- ==================== 이벤트 연결 ====================

function AsyncBattleService:SetupRemoteEvents()
	RemoteEvents.AsyncBattleChallenge.OnServerEvent:Connect(function(player: Player, data: any)
		if not RateLimiter.Check(player, "AsyncBattleChallenge", 5) then
			return
		end
		if type(data) ~= "table" then
			return
		end
		local targetName = data.targetName
		local targetScore = data.targetScore
		if type(targetName) ~= "string" or type(targetScore) ~= "number" then
			return
		end
		-- 자기 자신 도전 방지
		if targetName == player.Name then
			return
		end
		local safeScore = math.clamp(math.floor(targetScore), 1, 9999999)
		self:SetBattleTarget(player, targetName, safeScore)
	end)

	print("[AsyncBattleService] Remote events connected")
end

-- 플레이어 퇴장 시 정리
game.Players.PlayerRemoving:Connect(function(player: Player)
	_battleTargets[player] = nil
end)

print("[AsyncBattleService] Initialized")

return AsyncBattleService

--!strict
-- Login Reward Service
-- 일일 출석 보상 관리

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LoginRewardService = {}

-- 오늘 날짜 키 (UTC)
function LoginRewardService:_getTodayKey(): string
	return os.date("!%Y-%m-%d") :: string
end

-- 어제 날짜 키 (UTC)
function LoginRewardService:_getYesterdayKey(): string
	return os.date("!%Y-%m-%d", os.time() - 86400) :: string
end

-- 주차별 배율 계산
function LoginRewardService:_getStreakMultiplier(loginStreak: number): number
	local weekNumber = math.ceil(loginStreak / 7)
	local multiplier = 1.0

	for _, entry in GameConstants.LOGIN_REWARDS.STREAK_MULTIPLIERS do
		if weekNumber >= entry.week then
			multiplier = entry.multiplier
		end
	end

	return multiplier
end

-- 플레이어 로그인 시 출석 체크
function LoginRewardService:OnPlayerJoined(player: Player)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	local today = self:_getTodayKey()
	local yesterday = self:_getYesterdayKey()
	local alreadyClaimed = (playerData.lastLoginDate == today)

	-- 출석 스트릭 업데이트 (아직 오늘 출석 안 했을 때만)
	if not alreadyClaimed then
		if playerData.lastLoginDate == yesterday then
			-- 어제 출석함 → 스트릭 +1
			playerData.loginStreak = (playerData.loginStreak or 0) + 1
		else
			-- 연속 출석 끊김 → 1일차부터
			playerData.loginStreak = 1
		end
	end

	-- 보상일 계산 (7일 사이클)
	local rewardDay = ((playerData.loginStreak - 1) % GameConstants.LOGIN_REWARDS.CYCLE_DAYS) + 1
	local reward = GameConstants.LOGIN_REWARDS.REWARDS[rewardDay]
	local multiplier = self:_getStreakMultiplier(playerData.loginStreak)

	-- 클라이언트에 출석 데이터 전송
	RemoteEvents.LoginRewardData:FireClient(player, {
		loginStreak = playerData.loginStreak,
		rewardDay = rewardDay,
		reward = reward,
		multiplier = multiplier,
		alreadyClaimed = alreadyClaimed,
	})
end

-- 보상 수령 처리
function LoginRewardService:_onClaimReward(player: Player)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	local today = self:_getTodayKey()

	-- 이미 오늘 수령함 → 중복 방지
	if playerData.lastLoginDate == today then
		warn(`[LoginRewardService] {player.Name} already claimed today`)
		return
	end

	-- 보상일 계산
	local rewardDay = ((playerData.loginStreak - 1) % GameConstants.LOGIN_REWARDS.CYCLE_DAYS) + 1
	local reward = GameConstants.LOGIN_REWARDS.REWARDS[rewardDay]
	local multiplier = self:_getStreakMultiplier(playerData.loginStreak)
	local finalAmount = math.floor(reward.amount * multiplier)

	-- 보상 지급
	if reward.type == "coins" then
		PlayerDataService:AddCoins(player, finalAmount)
	elseif reward.type == "gems" then
		PlayerDataService:AddGems(player, finalAmount)
	end

	-- 날짜 기록
	playerData.lastLoginDate = today

	-- 저장
	PlayerDataService:SavePlayerData(player)

	-- 클라이언트에 결과 전송 (업데이트된 데이터 포함)
	RemoteEvents.LoginRewardData:FireClient(player, {
		loginStreak = playerData.loginStreak,
		rewardDay = rewardDay,
		reward = { type = reward.type, amount = finalAmount },
		multiplier = multiplier,
		alreadyClaimed = true,
		justClaimed = true,
	})

	-- 업데이트된 플레이어 데이터 전송
	RemoteEvents.PlayerDataLoaded:FireClient(player, playerData)

	print(
		`[LoginRewardService] {player.Name} claimed day {rewardDay} reward: {finalAmount} {reward.type} (x{multiplier})`
	)
end

-- 이벤트 연결
RemoteEvents.LoginRewardClaim.OnServerEvent:Connect(function(player: Player)
	if not RateLimiter.Check(player, "LoginRewardClaim", 2) then
		return
	end
	LoginRewardService:_onClaimReward(player)
end)

print("[LoginRewardService] Initialized")

return LoginRewardService

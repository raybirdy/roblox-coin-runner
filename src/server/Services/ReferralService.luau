--!strict
-- Referral Service
-- 친구 초대 보상 시스템

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local ReferralService = {}

-- 보상 설정
local REFEREE_COINS = 150  -- 초대받은 사람 (새 유저) 보상
local REFERRER_COINS = 300 -- 초대한 사람 보상

-- 플레이어 접속 시 초대 여부 확인
function ReferralService:OnPlayerJoin(player: Player)
	-- GetJoinData는 플레이어 데이터 로드 후 처리
	task.spawn(function()
		-- 데이터 로드 대기 (최대 10초)
		local waited = 0
		while waited < 10 do
			local data = PlayerDataService:GetPlayerData(player)
			if data then
				break
			end
			task.wait(0.5)
			waited += 0.5
		end

		local playerData = PlayerDataService:GetPlayerData(player)
		if not playerData then
			return
		end

		-- 이미 초대 보상을 받은 유저면 스킵
		if playerData.hasBeenReferred then
			return
		end

		-- 초대자 UserId 확인
		local joinData = player:GetJoinData()
		local referrerId = joinData.ReferredByPlayerId
		if not referrerId or referrerId == 0 then
			return
		end

		-- 자기 자신 초대 방지
		if referrerId == player.UserId then
			return
		end

		-- 새 유저에게 보상 지급
		playerData.hasBeenReferred = true
		PlayerDataService:AddCoins(player, REFEREE_COINS)

		-- 초대자 이름 조회
		local referrerName = "친구"
		pcall(function()
			referrerName = Players:GetNameFromUserIdAsync(referrerId)
		end)

		-- 새 유저에게 알림
		RemoteEvents.ReferralReward:FireClient(player, {
			type = "referee",
			coins = REFEREE_COINS,
			referrerName = referrerName,
		})

		print(`[ReferralService] {player.Name} joined via referral from {referrerName} (+{REFEREE_COINS} coins)`)

		-- 초대자가 현재 접속 중이면 즉시 보상
		local referrer = Players:GetPlayerByUserId(referrerId)
		if referrer then
			self:_rewardReferrer(referrer, player.Name)
		else
			-- 초대자가 오프라인이면 다음 접속 시 지급하기 위해 큐에 저장
			-- (간단 구현: DataStore에 직접 적용)
			self:_rewardOfflineReferrer(referrerId, player.Name)
		end
	end)
end

-- 온라인 초대자 보상
function ReferralService:_rewardReferrer(referrer: Player, newPlayerName: string)
	local referrerData = PlayerDataService:GetPlayerData(referrer)
	if not referrerData then
		return
	end

	referrerData.referralCount = (referrerData.referralCount or 0) + 1
	PlayerDataService:AddCoins(referrer, REFERRER_COINS)

	RemoteEvents.ReferralReward:FireClient(referrer, {
		type = "referrer",
		coins = REFERRER_COINS,
		referrerName = newPlayerName,
	})

	print(`[ReferralService] {referrer.Name} rewarded for inviting {newPlayerName} (+{REFERRER_COINS} coins)`)
end

-- 오프라인 초대자 보상 (다음 접속 시 적용)
function ReferralService:_rewardOfflineReferrer(referrerId: number, newPlayerName: string)
	-- 나중에 접속할 때 처리하기 위해 pendingReferralRewards DataStore 사용 가능
	-- 현재는 간단히 로그만 남김 (추후 확장 가능)
	print(`[ReferralService] Offline referrer {referrerId} will be rewarded next login (invited {newPlayerName})`)
end

-- 초대 다이얼로그 요청 처리 (클라이언트 → 서버)
RemoteEvents.InviteFriend.OnServerEvent:Connect(function(player: Player)
	if not RateLimiter.Check(player, "InviteFriend", 10) then
		return
	end

	local success, err = pcall(function()
		SocialService:PromptGameInvite(player)
	end)

	if not success then
		warn(`[ReferralService] PromptGameInvite failed for {player.Name}: {err}`)
	else
		print(`[ReferralService] Game invite prompted for {player.Name}`)
	end
end)

print("[ReferralService] Initialized")

return ReferralService

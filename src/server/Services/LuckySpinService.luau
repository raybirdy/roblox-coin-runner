--!strict
-- Lucky Spin Service
-- 럭키 스핀 (룰렛) 보상 관리

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LuckySpinService = {}

-- 오늘 날짜 키 (UTC)
function LuckySpinService:_getTodayKey(): string
	return os.date("!%Y-%m-%d") :: string
end

-- 가중치 랜덤 선택
function LuckySpinService:_pickWeightedReward(): any
	local rewards = GameConstants.LUCKY_SPIN.REWARDS
	local totalWeight = 0
	for _, reward in rewards do
		totalWeight += reward.weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, reward in rewards do
		cumulative += reward.weight
		if roll <= cumulative then
			return reward
		end
	end

	-- fallback
	return rewards[1]
end

-- 스핀 요청 처리
function LuckySpinService:_onSpinRequest(player: Player, data: any)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	local today = self:_getTodayKey()
	local useGems = data and data.useGems or false

	-- 무료 스핀 확인
	local hasFreeSpinToday = (playerData.lastSpinDate ~= today)

	if hasFreeSpinToday and not useGems then
		-- 무료 스핀 사용
		playerData.lastSpinDate = today
	elseif useGems then
		-- 젬으로 추가 스핀
		local cost = GameConstants.LUCKY_SPIN.EXTRA_SPIN_GEM_COST
		if not PlayerDataService:SpendGems(player, cost) then
			-- 젬 부족
			RemoteEvents.SpinResult:FireClient(player, {
				error = "not_enough_gems",
			})
			return
		end
	else
		-- 무료 스핀 이미 사용함
		RemoteEvents.SpinResult:FireClient(player, {
			error = "no_free_spin",
		})
		return
	end

	-- 보상 결정 (서버 가중치 랜덤)
	local reward = self:_pickWeightedReward()

	-- 보상 지급
	if reward.type == "coins" then
		PlayerDataService:AddCoins(player, reward.amount)
	elseif reward.type == "gems" then
		PlayerDataService:AddGems(player, reward.amount)
	elseif reward.type == "skin_piece" then
		-- 활성 시즌 스킨 중 미보유 스킨에 조각 지급
		local targetSkinId = self:_getRandomSeasonSkinId(player)
		if targetSkinId then
			PlayerDataService:AddSkinPieces(player, targetSkinId, reward.amount)
		else
			-- 모든 시즌 스킨 보유 시 젬 5개로 대체
			PlayerDataService:AddGems(player, 5)
		end
	end

	-- 저장
	PlayerDataService:SavePlayerData(player)

	-- 남은 무료 스핀
	local freeSpinsLeft = if playerData.lastSpinDate == today then 0 else 1

	-- 결과 전송
	RemoteEvents.SpinResult:FireClient(player, {
		rewardId = reward.id,
		rewardName = reward.name,
		type = reward.type,
		amount = reward.amount,
		freeSpinsLeft = freeSpinsLeft,
	})

	-- 업데이트된 데이터 전송
	RemoteEvents.PlayerDataLoaded:FireClient(player, playerData)

	print(`[LuckySpinService] {player.Name} spin result: {reward.name} ({reward.amount} {reward.type})`)
end

-- 활성 시즌 스킨 중 미보유 스킨 랜덤 선택
function LuckySpinService:_getRandomSeasonSkinId(player: Player): string?
	local candidates = {}
	for _, skin in GameConstants.SHOP.SKINS do
		if skin.availableUntil and os.time() <= skin.availableUntil then
			if not PlayerDataService:OwnsSkin(player, skin.id) then
				table.insert(candidates, skin.id)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

-- 이벤트 연결
RemoteEvents.SpinRequest.OnServerEvent:Connect(function(player: Player, data: any)
	if not RateLimiter.Check(player, "SpinRequest", 2) then
		return
	end
	LuckySpinService:_onSpinRequest(player, data)
end)

print("[LuckySpinService] Initialized")

return LuckySpinService

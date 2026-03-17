--!strict
-- BattlePassService
-- 배틀패스 시즌 관리, XP 적립, 보상 수령

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

-- Singleton service table
local BattlePassService = {}

-- Dependencies (injected via Init)
local _playerDataService: any = nil
local _initialized = false

-- SEASON_ID는 현재 하드코딩 (추후 DataStore에서 관리)
local CURRENT_SEASON_ID = 1

type BattlePassData = {
	seasonId: number,
	level: number,
	xp: number,
	isPremium: boolean,
	claimedFree: { [string]: boolean },
	claimedPremium: { [string]: boolean },
	lastLoginDate: number,
}

local function getDefaultBattlePassData(): BattlePassData
	return {
		seasonId = CURRENT_SEASON_ID,
		level = 1,
		xp = 0,
		isPremium = false,
		claimedFree = {},
		claimedPremium = {},
		lastLoginDate = 0,
	}
end

-- Initialize the service (call once from init.server.luau or GameManager)
function BattlePassService:Init(playerDataService: any)
	if _initialized then return end
	_initialized = true
	_playerDataService = playerDataService

	-- Handle battle pass reward claims from client
	RemoteEvents.BattlePassClaim.OnServerEvent:Connect(function(player: Player, level: any, isPremium: any)
		if type(level) ~= "number" or type(isPremium) ~= "boolean" then
			return
		end
		self:_handleClaim(player, level, isPremium)
	end)
end

-- Get player's battle pass data (ensures season is current and field exists)
function BattlePassService:GetData(player: Player): BattlePassData?
	if not _playerDataService then return nil end
	local data = _playerDataService:GetPlayerData(player)
	if not data then return nil end

	-- Initialize if missing
	if not data.battlePass then
		data.battlePass = getDefaultBattlePassData()
	end

	-- Reset if season changed
	if data.battlePass.seasonId ~= CURRENT_SEASON_ID then
		data.battlePass = getDefaultBattlePassData()
	end

	return data.battlePass
end

-- Add XP to player (called by GameManager on run end)
function BattlePassService:AddXP(player: Player, xpAmount: number)
	if xpAmount <= 0 then return end

	local bp = self:GetData(player)
	if not bp then return end

	local MAX_LEVEL = GameConstants.BATTLE_PASS.MAX_LEVEL
	if bp.level >= MAX_LEVEL then return end

	bp.xp = bp.xp + xpAmount

	-- Level up loop
	local leveled = false
	while bp.level < MAX_LEVEL do
		local xpNeeded = GameConstants.BATTLE_PASS.XP_PER_LEVEL[bp.level] or 500
		if bp.xp >= xpNeeded then
			bp.xp = bp.xp - xpNeeded
			bp.level = bp.level + 1
			leveled = true
		else
			break
		end
	end

	-- Cap XP at max level
	if bp.level >= MAX_LEVEL then
		bp.xp = 0
	end

	-- Sync to client
	RemoteEvents.BattlePassXPGained:FireClient(player, {
		xpGained = xpAmount,
		newLevel = bp.level,
		newXp = bp.xp,
		leveled = leveled,
	})
end

-- Grant daily login XP (call once per day on join)
function BattlePassService:TryGrantDailyLoginXP(player: Player)
	local bp = self:GetData(player)
	if not bp then return end

	local today = math.floor(os.time() / 86400)

	if bp.lastLoginDate ~= today then
		bp.lastLoginDate = today
		self:AddXP(player, GameConstants.BATTLE_PASS.XP_SOURCES.DAILY_LOGIN)
	end
end

-- Unlock premium track (called by MonetizationService after GamePass purchase)
function BattlePassService:UnlockPremium(player: Player)
	local bp = self:GetData(player)
	if not bp then return end

	bp.isPremium = true

	-- Notify client
	RemoteEvents.BattlePassPurchaseResult:FireClient(player, { success = true })
	self:_syncToClient(player)
end

-- Claim a reward (internal handler for BattlePassClaim RemoteEvent)
function BattlePassService:_handleClaim(player: Player, level: number, isPremium: boolean)
	if not _playerDataService then return end
	local data = _playerDataService:GetPlayerData(player)
	if not data then return end

	local bp = self:GetData(player)
	if not bp then return end

	local MAX_LEVEL = GameConstants.BATTLE_PASS.MAX_LEVEL

	-- Validate level range
	if level < 1 or level > MAX_LEVEL then
		RemoteEvents.BattlePassClaimResult:FireClient(player, { success = false, reason = "invalid_level" })
		return
	end
	-- Player must have reached the level
	if bp.level < level then
		RemoteEvents.BattlePassClaimResult:FireClient(player, { success = false, reason = "not_reached" })
		return
	end
	-- Premium track requires premium
	if isPremium and not bp.isPremium then
		RemoteEvents.BattlePassClaimResult:FireClient(player, { success = false, reason = "not_premium" })
		return
	end

	local claimedTable = isPremium and bp.claimedPremium or bp.claimedFree
	local levelKey = tostring(level)
	if claimedTable[levelKey] then
		RemoteEvents.BattlePassClaimResult:FireClient(player, { success = false, reason = "already_claimed" })
		return
	end

	-- Get reward definition
	local rewardTable = isPremium and GameConstants.BATTLE_PASS.PREMIUM_REWARDS or GameConstants.BATTLE_PASS.FREE_REWARDS
	local reward = rewardTable[level]
	if not reward then
		RemoteEvents.BattlePassClaimResult:FireClient(player, { success = false, reason = "no_reward" })
		return
	end

	-- Grant reward
	local success = self:_grantReward(player, reward, data)
	if success then
		claimedTable[levelKey] = true
		_playerDataService:SavePlayerData(player)
		RemoteEvents.BattlePassClaimResult:FireClient(player, { success = true, reward = reward })
		self:_syncToClient(player)
	else
		RemoteEvents.BattlePassClaimResult:FireClient(player, { success = false, reason = "grant_failed" })
	end
end

-- Grant reward to player data table
function BattlePassService:_grantReward(player: Player, reward: any, data: any): boolean
	local rewardType = reward.type

	if rewardType == "coins" then
		data.coins = (data.coins or 0) + reward.amount
		return true

	elseif rewardType == "gems" then
		data.gems = (data.gems or 0) + reward.amount
		return true

	elseif rewardType == "skin" then
		if not data.ownedSkins then data.ownedSkins = {} end
		local alreadyOwned = false
		for _, skinId in ipairs(data.ownedSkins) do
			if skinId == reward.id then
				alreadyOwned = true
				break
			end
		end
		if not alreadyOwned then
			table.insert(data.ownedSkins, reward.id)
		end
		return true

	elseif rewardType == "pet" then
		if not data.ownedPets then data.ownedPets = {} end
		local alreadyOwned = false
		for _, petId in ipairs(data.ownedPets) do
			if petId == reward.id then
				alreadyOwned = true
				break
			end
		end
		if alreadyOwned then
			-- Give gems instead of duplicate pet
			data.gems = (data.gems or 0) + 20
		else
			table.insert(data.ownedPets, reward.id)
		end
		return true

	elseif rewardType == "character" then
		if not data.ownedCharacters then data.ownedCharacters = {} end
		local alreadyOwned = false
		for _, charId in ipairs(data.ownedCharacters) do
			if charId == reward.id then
				alreadyOwned = true
				break
			end
		end
		if not alreadyOwned then
			table.insert(data.ownedCharacters, reward.id)
		end
		return true

	elseif rewardType == "nametag" then
		if not data.ownedNametagItems then data.ownedNametagItems = {} end
		data.ownedNametagItems[reward.id] = true
		return true
	end

	warn("[BattlePassService] Unknown reward type: " .. tostring(rewardType))
	return false
end

-- Sync battle pass data to client
function BattlePassService:_syncToClient(player: Player)
	local bp = self:GetData(player)
	if not bp then return end
	RemoteEvents.BattlePassData:FireClient(player, bp)
end

-- Send initial data and daily XP when player joins
function BattlePassService:OnPlayerJoined(player: Player)
	task.delay(1, function()
		if not player.Parent then return end
		self:TryGrantDailyLoginXP(player)
		self:_syncToClient(player)
	end)
end

print("[BattlePassService] Loaded")

return BattlePassService

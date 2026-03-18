--!strict
-- Upgrade Service
-- 영구 스탯 업그레이드 구매, 보너스 계산

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local UpgradeService = {}

export type UpgradeBonuses = {
	magnetBonus: number, -- extra studs added to magnet radius
	coinValueBonus: number, -- fraction e.g. 0.10 = +10%
	easyStartTime: number, -- safe zone seconds (default 30s if no upgrade)
	feverExtend: number, -- extra seconds added to fever duration
	luckyCoinsBonus: number, -- fraction e.g. 0.05 = +5% silver chance
	comboBufferSeconds: number, -- extra seconds added to COMBO_TIMEOUT
	startBoostSeconds: number, -- speed boost duration at game start (seconds)
	baseSpeedBonus: number,
	baseJumpBonus: number,
	baseLivesBonus: number,
	skillCooldownReduction: number,
	miniGameBonus: number,
}

-- Get upgrade definition by id
local function getUpgradeDef(upgradeId: string): any?
	for _, def in GameConstants.UPGRADES.LIST do
		if def.id == upgradeId then
			return def
		end
	end
	return nil
end

-- Purchase an upgrade for a player
-- Returns { success: boolean, error: string? }
function UpgradeService:PurchaseUpgrade(player: Player, upgradeId: string, PlayerDataService: any): { success: boolean, error: string? }
	local def = getUpgradeDef(upgradeId)
	if not def then
		return { success = false, error = "unknown_upgrade" }
	end

	local currentLevel = PlayerDataService:GetUpgradeLevel(player, upgradeId)

	-- Already maxed?
	if currentLevel >= def.maxLevel then
		return { success = false, error = "already_maxed" }
	end

	-- Cost for next level
	local nextLevel = currentLevel + 1
	local cost = def.costs[nextLevel]
	if not cost then
		return { success = false, error = "invalid_level" }
	end

	-- Deduct coins
	local success = PlayerDataService:SpendCoins(player, cost)
	if not success then
		return { success = false, error = "insufficient_coins" }
	end

	-- Set new level
	PlayerDataService:SetUpgradeLevel(player, upgradeId, nextLevel)

	print(`[UpgradeService] {player.Name} purchased {upgradeId} → level {nextLevel} for {cost} coins`)

	return { success = true, error = nil }
end

-- Get computed upgrade bonuses for a player
function UpgradeService:GetUpgradeBonuses(player: Player, PlayerDataService: any): UpgradeBonuses
	local bonuses: UpgradeBonuses = {
		magnetBonus = 0,
		coinValueBonus = 0,
		easyStartTime = 30, -- default safe zone seconds
		feverExtend = 0,
		luckyCoinsBonus = 0,
		comboBufferSeconds = 0,
		startBoostSeconds = 0,
		baseSpeedBonus = 0,
		baseJumpBonus = 0,
		baseLivesBonus = 0,
		skillCooldownReduction = 0,
		miniGameBonus = 0,
	}

	for _, def in GameConstants.UPGRADES.LIST do
		local level = PlayerDataService:GetUpgradeLevel(player, def.id)
		if level > 0 then
			local value = def.values[level] or 0
			if def.id == "magnet_range" then
				bonuses.magnetBonus = value
			elseif def.id == "coin_value" then
				bonuses.coinValueBonus = value / 100 -- convert % to fraction
			elseif def.id == "easy_start" then
				bonuses.easyStartTime = value
			elseif def.id == "fever_extend" then
				bonuses.feverExtend = value
			elseif def.id == "lucky_coins" then
				bonuses.luckyCoinsBonus = value / 100
			elseif def.id == "combo_buffer" then
				bonuses.comboBufferSeconds = value
			elseif def.id == "start_boost" then
				bonuses.startBoostSeconds = value
			elseif def.id == "base_speed" then
				bonuses.baseSpeedBonus = value / 100
			elseif def.id == "base_jump" then
				bonuses.baseJumpBonus = value / 100
			elseif def.id == "base_lives" then
				bonuses.baseLivesBonus = value
			elseif def.id == "skill_cooldown" then
				bonuses.skillCooldownReduction = value / 100
			elseif def.id == "mini_game_bonus" then
				bonuses.miniGameBonus = value / 100
			end
		end
	end

	return bonuses
end

-- Send upgrade state to client
function UpgradeService:SendUpgradeData(player: Player, PlayerDataService: any)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	RemoteEvents.UpgradeData:FireClient(player, {
		upgrades = playerData.upgrades or {},
		coins = playerData.coins or 0,
	})
end

-- Setup RemoteEvent handlers
function UpgradeService:SetupRemoteEvents(PlayerDataService: any)
	RemoteEvents.UpgradePurchase.OnServerEvent:Connect(function(player: Player, data: any)
		if type(data) ~= "table" or type(data.upgradeId) ~= "string" then
			return
		end

		local result = self:PurchaseUpgrade(player, data.upgradeId, PlayerDataService)
		local playerData = PlayerDataService:GetPlayerData(player)
		local newLevel = PlayerDataService:GetUpgradeLevel(player, data.upgradeId)

		RemoteEvents.UpgradePurchaseResult:FireClient(player, {
			success = result.success,
			upgradeId = data.upgradeId,
			newLevel = newLevel,
			newBalance = playerData and playerData.coins or 0,
			error = result.error,
		})

		if result.success then
			-- Refresh full upgrade data
			self:SendUpgradeData(player, PlayerDataService)
			-- Update displayed coin balance
			RemoteEvents.PlayerDataLoaded:FireClient(player, PlayerDataService:GetPlayerData(player))
		end
	end)
end

print("[UpgradeService] Initialized")

return UpgradeService

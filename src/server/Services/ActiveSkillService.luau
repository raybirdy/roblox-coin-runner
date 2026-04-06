--!strict
-- ActiveSkillService (v3)
-- Manages active skills: dash, shield, magnet_burst
-- Cooldown-based, server-authoritative

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)
local DailyChallengeService = require(script.Parent.DailyChallengeService)

local ActiveSkillService = {}

-- Per-player cooldown tracking: { [Player]: { [skillId]: lastUseTime } }
local _cooldowns: { [Player]: { [string]: number } } = {}

-- Check if player has unlocked a skill based on upgrade levels
function ActiveSkillService:IsSkillUnlocked(playerData: any, skillId: string): boolean
	local skillConfig = GameConstants.ACTIVE_SKILLS.SKILLS[skillId]
	if not skillConfig then
		return false
	end

	local upgrades = playerData.upgrades or {}
	local requiredUpgrade = skillConfig.unlockUpgrade
	local requiredLevel = skillConfig.unlockLevel
	local currentLevel = upgrades[requiredUpgrade] or 0

	return currentLevel >= requiredLevel
end

-- Get effective cooldown with skill_cooldown reduction
function ActiveSkillService:GetEffectiveCooldown(skillId: string, skillCooldownReduction: number): number
	local skillConfig = GameConstants.ACTIVE_SKILLS.SKILLS[skillId]
	if not skillConfig then
		return 999
	end

	-- Apply half of skill_cooldown reduction to active skills (balance)
	local reduction = skillCooldownReduction * 0.5
	return math.max(skillConfig.cooldown * (1 - reduction), skillConfig.cooldown * 0.5)
end

-- Check if skill is on cooldown
function ActiveSkillService:IsOnCooldown(player: Player, skillId: string, skillCooldownReduction: number): (boolean, number)
	local playerCooldowns = _cooldowns[player]
	if not playerCooldowns or not playerCooldowns[skillId] then
		return false, 0
	end

	local lastUse = playerCooldowns[skillId]
	local effectiveCooldown = self:GetEffectiveCooldown(skillId, skillCooldownReduction)
	local elapsed = os.clock() - lastUse
	local remaining = effectiveCooldown - elapsed

	if remaining <= 0 then
		return false, 0
	end

	return true, remaining
end

-- Activate a skill (server-authoritative)
function ActiveSkillService:ActivateSkill(player: Player, skillId: string, session: any, PlayerDataService: any, AnalyticsService: any?)
	-- Validate session
	if not session or not session.isPlaying then
		return false, "not_playing"
	end

	-- Validate equipped
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return false, "no_data"
	end

	local equippedSkill = playerData.equippedActiveSkill
	if equippedSkill ~= skillId then
		return false, "not_equipped"
	end

	-- Validate unlocked (AC-5-3)
	if not self:IsSkillUnlocked(playerData, skillId) then
		return false, "not_unlocked"
	end

	-- Check cooldown (AC-5-2)
	local skillCooldownReduction = session.upgradeBonuses and session.upgradeBonuses.skillCooldownReduction or 0
	local onCooldown, remaining = self:IsOnCooldown(player, skillId, skillCooldownReduction)
	if onCooldown then
		return false, "on_cooldown"
	end

	-- Record cooldown
	if not _cooldowns[player] then
		_cooldowns[player] = {}
	end
	_cooldowns[player][skillId] = os.clock()

	local skillConfig = GameConstants.ACTIVE_SKILLS.SKILLS[skillId]
	local effectiveCooldown = self:GetEffectiveCooldown(skillId, skillCooldownReduction)

	-- Apply skill effect
	self:_applyEffect(player, skillId, skillConfig, session)

	-- 일일 도전 과제: 액티브 스킬 사용
	DailyChallengeService:UpdateProgress(player, "use_skill", 1)

	-- Notify client
	RemoteEvents.SkillActivated:FireClient(player, {
		skillId = skillId,
		duration = skillConfig.duration,
		cooldown = effectiveCooldown,
	})

	-- Send cooldown update
	RemoteEvents.ActiveSkillCooldownUpdate:FireClient(player, {
		skillId = skillId,
		remainingCooldown = effectiveCooldown,
		totalCooldown = effectiveCooldown,
	})

	-- Analytics
	if AnalyticsService then
		AnalyticsService:Track(player, "tutorial_step", {
			action = "active_skill_use",
			skillId = skillId,
		})
	end

	print(`[ActiveSkillService] {player.Name} activated {skillId} (cd={effectiveCooldown}s)`)
	return true, "ok"
end

-- Apply skill effect on the session
function ActiveSkillService:_applyEffect(player: Player, skillId: string, config: any, session: any)
	if skillId == "dash" then
		-- Dash: temporary speed boost
		session._dashActive = true
		session._dashSpeedMultiplier = config.speedMultiplier or 3.0
		task.delay(config.duration or 0.5, function()
			session._dashActive = false
			session._dashSpeedMultiplier = 1.0
		end)

	elseif skillId == "shield" then
		-- Shield: absorb hits
		session.activeShieldHits = config.shieldHits or 2
		task.delay(config.duration or 5, function()
			session.activeShieldHits = 0
		end)

	elseif skillId == "active_magnet_burst" then
		-- Magnet burst: collect nearby coins
		session._magnetBurstActive = true
		session._magnetBurstRadius = config.radius or 35
		-- Effect is consumed immediately by GameManager on next Heartbeat
		task.defer(function()
			session._magnetBurstActive = false
		end)
	end
end

-- Check and consume active shield hit
function ActiveSkillService:ConsumeShieldHit(session: any): boolean
	if session.activeShieldHits and session.activeShieldHits > 0 then
		session.activeShieldHits -= 1
		return true
	end
	return false
end

-- Get dash speed multiplier
function ActiveSkillService:GetDashMultiplier(session: any): number
	if session._dashActive then
		return session._dashSpeedMultiplier or 3.0
	end
	return 1.0
end

-- Check and consume magnet burst
function ActiveSkillService:ConsumeMagnetBurst(session: any): (boolean, number)
	if session._magnetBurstActive then
		session._magnetBurstActive = false
		return true, session._magnetBurstRadius or 35
	end
	return false, 0
end

-- Setup RemoteEvent handlers
function ActiveSkillService:SetupRemoteEvents(PlayerDataService: any, AnalyticsService: any?)
	-- Skill activation request
	RemoteEvents.SkillActivate.OnServerEvent:Connect(function(player: Player, data: any)
		if not RateLimiter.Check(player, "ActiveSkillActivate", 2) then
			return
		end

		local skillId = data and data.skillId
		if type(skillId) ~= "string" then
			return
		end

		-- Find session (need access to GameManager's activeSessions)
		-- For now, store session reference per player
		local session = self._activeSessions and self._activeSessions[player]
		if session then
			self:ActivateSkill(player, skillId, session, PlayerDataService, AnalyticsService)
		end
	end)

	-- Skill equip request
	RemoteEvents.ActiveSkillEquip.OnServerEvent:Connect(function(player: Player, data: any)
		if not RateLimiter.Check(player, "ActiveSkillEquip", 2) then
			return
		end

		local skillId = data and data.skillId
		if type(skillId) ~= "string" then
			return
		end

		local playerData = PlayerDataService:GetPlayerData(player)
		if not playerData then
			return
		end

		-- Validate unlock
		if not self:IsSkillUnlocked(playerData, skillId) then
			return
		end

		playerData.equippedActiveSkill = skillId
		PlayerDataService:SavePlayerData(player)

		-- Send updated data
		self:SendSkillData(player, PlayerDataService)
	end)

	print("[ActiveSkillService] RemoteEvents initialized")
end

-- Send skill data to client
function ActiveSkillService:SendSkillData(player: Player, PlayerDataService: any)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	-- Calculate unlocked skills
	local unlockedSkills = {}
	for skillId, _ in GameConstants.ACTIVE_SKILLS.SKILLS do
		if self:IsSkillUnlocked(playerData, skillId) then
			table.insert(unlockedSkills, skillId)
		end
	end

	RemoteEvents.ActiveSkillData:FireClient(player, {
		unlockedSkills = unlockedSkills,
		equippedSkill = playerData.equippedActiveSkill,
	})
end

-- Set active sessions reference (called by GameManager)
function ActiveSkillService:SetActiveSessions(sessions: any)
	self._activeSessions = sessions
end

-- Cleanup on player leave
function ActiveSkillService:OnPlayerRemoving(player: Player)
	_cooldowns[player] = nil
end

function ActiveSkillService:Init()
	print("[ActiveSkillService] Initialized")
end

return ActiveSkillService

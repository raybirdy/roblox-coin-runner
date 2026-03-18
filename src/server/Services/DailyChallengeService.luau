--!strict
-- DailyChallengeService (v3)
-- Daily challenge generation, tracking, and rewards

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local DailyChallengeService = {}

-- Per-player challenge state (today only, no history)
local _playerChallenges: { [Player]: {
	date: string,
	challenges: { { id: string, desc: string, target: number, progress: number, completed: boolean, claimed: boolean, difficulty: string } },
} } = {}

-- Get today's date string (UTC)
local function getTodayString(): string
	return os.date("!%Y-%m-%d", os.time())
end

-- Generate 3 random challenges for today
local function generateChallenges(): { any }
	local pool = GameConstants.DAILY_CHALLENGES.CHALLENGE_POOL
	local selected = {}
	local usedIds = {}

	-- Select 3 unique challenges
	local attempts = 0
	while #selected < GameConstants.DAILY_CHALLENGES.CHALLENGES_PER_DAY and attempts < 50 do
		attempts += 1
		local template = pool[math.random(1, #pool)]
		if not usedIds[template.id] then
			usedIds[template.id] = true
			local target = template.targets[math.random(1, #template.targets)]
			table.insert(selected, {
				id = template.id,
				desc = string.format(template.desc, target),
				target = target,
				progress = 0,
				completed = false,
				claimed = false,
				difficulty = template.difficulty,
			})
		end
	end

	return selected
end

-- Get or create today's challenges for a player
function DailyChallengeService:GetChallenges(player: Player): { any }
	local today = getTodayString()
	local state = _playerChallenges[player]

	if not state or state.date ~= today then
		-- New day: generate fresh challenges
		_playerChallenges[player] = {
			date = today,
			challenges = generateChallenges(),
		}
	end

	return _playerChallenges[player].challenges
end

-- Update progress for a specific challenge type (additive)
function DailyChallengeService:UpdateProgress(player: Player, challengeId: string, amount: number)
	local challenges = self:GetChallenges(player)

	for i, challenge in challenges do
		if challenge.id == challengeId and not challenge.completed then
			challenge.progress = math.min(challenge.progress + amount, challenge.target)
			if challenge.progress >= challenge.target then
				challenge.completed = true
			end

			-- Notify client
			RemoteEvents.DailyChallengeProgress:FireClient(player, {
				challengeIndex = i,
				progress = challenge.progress,
				completed = challenge.completed,
			})
		end
	end
end

-- Set progress to value if it exceeds current (for max-based challenges like reach_combo)
function DailyChallengeService:SetProgressIfHigher(player: Player, challengeId: string, value: number)
	local challenges = self:GetChallenges(player)

	for i, challenge in challenges do
		if challenge.id == challengeId and not challenge.completed then
			if value > challenge.progress then
				challenge.progress = math.min(value, challenge.target)
				if challenge.progress >= challenge.target then
					challenge.completed = true
				end

				-- Notify client
				RemoteEvents.DailyChallengeProgress:FireClient(player, {
					challengeIndex = i,
					progress = challenge.progress,
					completed = challenge.completed,
				})
			end
		end
	end
end

-- Claim reward for completed challenge
function DailyChallengeService:ClaimReward(player: Player, challengeIndex: number, PlayerDataService: any, BattlePassService: any?)
	local challenges = self:GetChallenges(player)
	local challenge = challenges[challengeIndex]

	if not challenge or not challenge.completed or challenge.claimed then
		return false
	end

	challenge.claimed = true

	-- Award Battle Pass XP
	local xpReward = GameConstants.DAILY_CHALLENGES.XP_REWARDS[challenge.difficulty] or 20
	if BattlePassService then
		BattlePassService:AddXP(player, xpReward, "daily_challenge")
	end

	print(`[DailyChallengeService] {player.Name} claimed {challenge.id} reward: {xpReward} BP XP`)
	return true
end

-- Send challenge data to client
function DailyChallengeService:SendChallengeData(player: Player)
	local challenges = self:GetChallenges(player)
	RemoteEvents.DailyChallengeData:FireClient(player, {
		challenges = challenges,
		resetTime = os.time() + (86400 - (os.time() % 86400)),
	})
end

-- Setup RemoteEvent handlers
function DailyChallengeService:SetupRemoteEvents(PlayerDataService: any, BattlePassService: any?)
	RemoteEvents.DailyChallengeClaim.OnServerEvent:Connect(function(player: Player, data: any)
		if not RateLimiter.Check(player, "DailyChallengeClaim", 2) then
			return
		end
		local index = data and data.challengeIndex
		if type(index) == "number" then
			self:ClaimReward(player, index, PlayerDataService, BattlePassService)
		end
	end)

	print("[DailyChallengeService] RemoteEvents initialized")
end

-- Cleanup
function DailyChallengeService:OnPlayerRemoving(player: Player)
	_playerChallenges[player] = nil
end

function DailyChallengeService:Init()
	print("[DailyChallengeService] Initialized")
end

return DailyChallengeService

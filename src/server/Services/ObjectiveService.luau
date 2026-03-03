--!strict
-- Objective Service
-- 런마다 3개 목표 생성, 진행도 추적, 완료 시 보너스 코인 지급

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local ObjectiveService = {}

type Objective = {
	id: string,
	desc: string,
	condition: string,
	target: number,
	progress: number,
	completed: boolean,
	tier: string,
}

local activeObjectives: { [Player]: { Objective } } = {}
local completionBonus: { [Player]: number? } = {}

-- Weighted random pick from a list
local function pickWeighted(list: { any }): any?
	local total = 0
	for _, def in list do
		total += def.weight
	end
	if total <= 0 then
		return nil
	end

	local r = math.random() * total
	local cum = 0
	for _, def in list do
		cum += def.weight
		if r <= cum then
			return def
		end
	end
	return list[#list] -- fallback for floating-point edge case
end

-- Select COUNT objectives with tier constraints (MIN_EASY easy, MAX_HARD hard)
local function selectObjectives(): { Objective }
	local pool = GameConstants.RUN_OBJECTIVES.POOL
	local count = GameConstants.RUN_OBJECTIVES.COUNT
	local minEasy = GameConstants.RUN_OBJECTIVES.SELECTION.MIN_EASY
	local maxHard = GameConstants.RUN_OBJECTIVES.SELECTION.MAX_HARD

	local selected: { Objective } = {}
	local used: { [string]: boolean } = {}
	local hardCount = 0

	-- Phase 1: guarantee minEasy easy-tier objectives
	for _ = 1, minEasy do
		if #selected >= count then
			break
		end
		local easyPool = {}
		for _, def in pool do
			if def.tier == "easy" and not used[def.id] then
				table.insert(easyPool, def)
			end
		end
		local pick = pickWeighted(easyPool)
		if pick then
			used[pick.id] = true
			table.insert(selected, {
				id = pick.id,
				desc = pick.desc,
				condition = pick.condition,
				target = pick.target,
				progress = 0,
				completed = false,
				tier = pick.tier,
			})
		end
	end

	-- Phase 2: fill remaining slots respecting maxHard
	while #selected < count do
		local candidates = {}
		for _, def in pool do
			if not used[def.id] then
				if def.tier == "hard" and hardCount >= maxHard then
					continue
				end
				table.insert(candidates, def)
			end
		end
		if #candidates == 0 then
			break
		end

		local pick = pickWeighted(candidates)
		if pick then
			used[pick.id] = true
			if pick.tier == "hard" then
				hardCount += 1
			end
			table.insert(selected, {
				id = pick.id,
				desc = pick.desc,
				condition = pick.condition,
				target = pick.target,
				progress = 0,
				completed = false,
				tier = pick.tier,
			})
		else
			break
		end
	end

	return selected
end

-- Get current progress value from session for a given condition
local function getProgressValue(condition: string, session: any, distanceTraveled: number): number
	if condition == "coins_collected" then
		return session.coinsCollectedCount
	elseif condition == "distance" then
		return math.floor(distanceTraveled)
	elseif condition == "max_combo" then
		return session.maxCombo
	elseif condition == "fever_count" then
		return session.feverCount
	elseif condition == "near_miss_count" then
		return session.nearMissCount
	elseif condition == "score" then
		return math.floor(session.score)
	elseif condition == "powerups_collected" then
		return session.powerupsCollected
	elseif condition == "survive_time" then
		return math.floor(tick() - session.startTime)
	elseif condition == "no_hit_distance" then
		return math.max(0, math.floor(distanceTraveled) - session.lastHitDistance)
	end
	return 0
end

-- Generate objectives for a player at the start of a run
function ObjectiveService:GenerateObjectives(player: Player)
	local objectives = selectObjectives()
	activeObjectives[player] = objectives
	completionBonus[player] = nil
end

-- Get generated objectives (for sending to client)
function ObjectiveService:GetObjectives(player: Player): { Objective }?
	return activeObjectives[player]
end

-- Update progress and fire client update if anything changed
function ObjectiveService:UpdateProgress(player: Player, session: any, distanceTraveled: number)
	local objectives = activeObjectives[player]
	if not objectives then
		return
	end

	local anyChanged = false
	for _, obj in objectives do
		if not obj.completed then
			local val = getProgressValue(obj.condition, session, distanceTraveled)
			local prev = obj.progress
			obj.progress = math.min(val, obj.target)
			if obj.progress >= obj.target then
				obj.completed = true
			end
			if obj.progress ~= prev then
				anyChanged = true
			end
		end
	end

	if not anyChanged then
		return
	end

	local allCompleted = true
	for _, obj in objectives do
		if not obj.completed then
			allCompleted = false
			break
		end
	end

	-- Compute bonus when all objectives first complete
	if allCompleted and completionBonus[player] == nil then
		local min = GameConstants.RUN_OBJECTIVES.COMPLETION_BONUS_MIN
		local max = GameConstants.RUN_OBJECTIVES.COMPLETION_BONUS_MAX
		completionBonus[player] = math.random(min, max)
	end

	local payload = {}
	for _, obj in objectives do
		table.insert(payload, {
			id = obj.id,
			progress = obj.progress,
			completed = obj.completed,
		})
	end

	RemoteEvents.RunObjectiveProgress:FireClient(player, {
		objectives = payload,
		allCompleted = allCompleted,
		bonus = completionBonus[player],
	})
end

-- Returns bonus coins for completing all objectives (0 if not all done)
-- Call once in EndGame; stores result so repeat calls return same value
function ObjectiveService:GetCompletionBonus(player: Player): number
	return completionBonus[player] or 0
end

-- Clean up player data on leave or game end
function ObjectiveService:ClearObjectives(player: Player)
	activeObjectives[player] = nil
	completionBonus[player] = nil
end

print("[ObjectiveService] Initialized")

return ObjectiveService

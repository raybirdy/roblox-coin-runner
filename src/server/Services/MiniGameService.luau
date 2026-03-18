--!strict
-- MiniGameService (v3)
-- Minigame dispatcher: trigger, start, end, co-op sync

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local MiniGameService = {}

-- Lazy-loaded minigame modules
local _gameModules: { [string]: any } = {}

local function getGameModule(gameTypeId: string): any?
	if not _gameModules[gameTypeId] then
		local ok, mod = pcall(function()
			return require(ServerScriptService.Server.Services.MiniGames.ObstacleRush)
		end)
		if ok and gameTypeId == "obstacle_rush" then
			_gameModules[gameTypeId] = mod
		end
	end
	return _gameModules[gameTypeId]
end

-- Track co-op minigame results for synchronization
local _coopResults: { [string]: { [Player]: { success: boolean, score: number } } } = {}

-- Select a game type (for now just obstacle_rush, coin_storm in Sprint 4)
local _lastGameType: string? = nil

local function selectGameType(): any
	local types = GameConstants.MINI_GAME.GAME_TYPES
	-- For MVP with 1 type, just return the first
	if #types == 1 then
		return types[1]
	end
	-- Avoid repeating same type 3 times
	for _, gt in types do
		if gt.id ~= _lastGameType then
			_lastGameType = gt.id
			return gt
		end
	end
	return types[1]
end

-- Check if minigame should trigger
function MiniGameService:ShouldTrigger(session: any): boolean
	if session.sessionState ~= GameConstants.MINI_GAME.STATE.RUNNING then
		return false
	end

	local minInterval = GameConstants.MINI_GAME.TRIGGER_INTERVAL.MIN
	local maxInterval = GameConstants.MINI_GAME.TRIGGER_INTERVAL.MAX

	if session.chunksSinceLastMiniGame < minInterval then
		return false
	end

	local range = maxInterval - minInterval
	if range <= 0 then
		return true
	end

	local chance = (session.chunksSinceLastMiniGame - minInterval) / range
	return math.random() < chance
end

-- Start a minigame for a player
function MiniGameService:StartForPlayer(player: Player, session: any, gameType: any?)
	local selectedType = gameType or selectGameType()

	-- Update session state
	session.sessionState = GameConstants.MINI_GAME.STATE.MINIGAME
	session.pauseStartTime = os.clock()
	session.activeMiniGameId = selectedType.id

	-- Unload rear chunks for memory management
	if session.chunkService then
		session.chunkService:UnloadRearChunks(GameConstants.MINI_GAME.CHUNKS_TO_UNLOAD)
	end

	-- Get difficulty based on zone
	local zoneIndex = session.currentZoneIndex or 1
	local difficulty = nil
	for _, scale in GameConstants.MINI_GAME.DIFFICULTY_SCALE do
		if scale.zone == zoneIndex then
			difficulty = scale
			break
		end
	end
	if not difficulty then
		difficulty = GameConstants.MINI_GAME.DIFFICULTY_SCALE[1]
	end

	-- Start the minigame module
	local mod = getGameModule(selectedType.id)
	if mod then
		mod:Start(player, session, difficulty, selectedType)
	end

	-- Notify client
	RemoteEvents.MiniGameStart:FireClient(player, {
		gameTypeId = selectedType.id,
		duration = selectedType.duration,
		difficulty = difficulty,
	})

	-- Analytics
	local AnalyticsService = session._analyticsService
	if AnalyticsService then
		AnalyticsService:Track(player, "minigame_start", {
			gameTypeId = selectedType.id,
			zone = zoneIndex,
		})
	end

	print(`[MiniGameService] Started {selectedType.id} for {player.Name}`)
end

-- Start minigame (handles co-op synchronization)
function MiniGameService:Start(player: Player, session: any, activeSessions: any?, CoopMatchService: any?)
	local selectedType = selectGameType()

	-- Check if co-op
	if session.coopSessionId and CoopMatchService and activeSessions then
		local coopSession = CoopMatchService:GetSession(session.coopSessionId)
		if coopSession then
			_coopResults[session.coopSessionId] = {}
			for _, p in coopSession.players do
				local s = activeSessions[p]
				if s and s.isPlaying then
					self:StartForPlayer(p, s, selectedType)
				end
			end
			return
		end
	end

	-- Solo
	self:StartForPlayer(player, session, selectedType)
end

-- Called when a player finishes their minigame
function MiniGameService:OnPlayerFinish(player: Player, session: any, result: { success: boolean, score: number }, activeSessions: any?, CoopMatchService: any?)
	if session.coopSessionId and CoopMatchService and activeSessions then
		-- Co-op: wait for both players
		if not _coopResults[session.coopSessionId] then
			_coopResults[session.coopSessionId] = {}
		end
		_coopResults[session.coopSessionId][player] = result

		local coopSession = CoopMatchService:GetSession(session.coopSessionId)
		if coopSession then
			local allDone = true
			for _, p in coopSession.players do
				if not _coopResults[session.coopSessionId][p] then
					allDone = false
					break
				end
			end

			if allDone then
				for _, p in coopSession.players do
					local s = activeSessions[p]
					if s then
						self:EndForPlayer(p, s, _coopResults[session.coopSessionId][p])
					end
				end
				_coopResults[session.coopSessionId] = nil
			end
		end
	else
		-- Solo
		self:EndForPlayer(player, session, result)
	end
end

-- End minigame for a single player and restore runner state
function MiniGameService:EndForPlayer(player: Player, session: any, result: { success: boolean, score: number })
	if session.sessionState ~= GameConstants.MINI_GAME.STATE.MINIGAME then
		return
	end

	-- Calculate pause delta
	local pauseDelta = os.clock() - session.pauseStartTime

	-- Update paused duration
	session.pausedDuration += pauseDelta

	-- Shift all time-based fields to protect them
	self:_shiftTimeFields(session, pauseDelta)

	-- Calculate reward
	local reward = 0
	if result.success then
		local gameType = nil
		for _, gt in GameConstants.MINI_GAME.GAME_TYPES do
			if gt.id == session.activeMiniGameId then
				gameType = gt
				break
			end
		end
		if gameType then
			reward = gameType.rewardCoins
				* GameConstants.MINI_GAME.REWARDS.CLEAR_BONUS_MULTIPLIER
				* (1 + (session.upgradeBonuses and session.upgradeBonuses.miniGameBonus or 0))
			reward = math.floor(reward)
			session.coins += reward
		end
	end
	-- AC-3-5: No life penalty on failure (NO_LIFE_PENALTY = true)

	-- Save gameTypeId BEFORE clearing it
	local gameTypeId = session.activeMiniGameId or "unknown"

	-- Restore session state
	session.sessionState = GameConstants.MINI_GAME.STATE.RUNNING
	session.pauseStartTime = 0
	session.activeMiniGameId = nil
	session.chunksSinceLastMiniGame = 0

	-- Cleanup minigame module
	local mod = getGameModule(gameTypeId)
	if mod then
		mod:Cleanup(player)
	end

	-- Notify client
	RemoteEvents.MiniGameEnd:FireClient(player, {
		success = result.success,
		reward = reward,
		gameTypeId = gameTypeId,
	})

	-- Analytics
	local AnalyticsService = session._analyticsService
	if AnalyticsService then
		AnalyticsService:Track(player, "minigame_end", {
			gameTypeId = gameTypeId,
			success = result.success,
			reward = reward,
		})
	end

	print(`[MiniGameService] Ended for {player.Name}: success={result.success}, reward={reward}`)
end

-- Shift all time-based fields by pauseDelta to protect from minigame pause
function MiniGameService:_shiftTimeFields(session: any, pauseDelta: number)
	-- Base timestamps
	if session.startTime and session.startTime > 0 then
		session.startTime += pauseDelta
	end

	-- Future timestamps (endTime pattern)
	if session.feverEndTime and session.feverEndTime > 0 then
		session.feverEndTime += pauseDelta
	end
	if session.feverCooldownEnd and session.feverCooldownEnd > 0 then
		session.feverCooldownEnd += pauseDelta
	end
	if session.hitRushEndTime and session.hitRushEndTime > 0 then
		session.hitRushEndTime += pauseDelta
	end
	if session.miniFeverEndTime and session.miniFeverEndTime > 0 then
		session.miniFeverEndTime += pauseDelta
	end
	if session.headStartEnd and session.headStartEnd > 0 then
		session.headStartEnd += pauseDelta
	end
	if session.slowStartEnd and session.slowStartEnd > 0 then
		session.slowStartEnd += pauseDelta
	end

	-- Past timestamps (lastXxxTime pattern)
	if session.lastCoinTime and session.lastCoinTime > 0 then
		session.lastCoinTime += pauseDelta
	end
	if session.lastNearMissTime and session.lastNearMissTime > 0 then
		session.lastNearMissTime += pauseDelta
	end
	if session.lastEventTime and session.lastEventTime > 0 then
		session.lastEventTime += pauseDelta
	end
	if session.lastShieldRegenTime and session.lastShieldRegenTime > 0 then
		session.lastShieldRegenTime += pauseDelta
	end
	if session.lastFeverEndTime and session.lastFeverEndTime > 0 then
		session.lastFeverEndTime += pauseDelta
	end
	if session.survivalStartTime and session.survivalStartTime > 0 then
		session.survivalStartTime += pauseDelta
	end
	if session.lastEventProgressTime and session.lastEventProgressTime > 0 then
		session.lastEventProgressTime += pauseDelta
	end
end

-- Handle player disconnect during minigame
function MiniGameService:OnPlayerDisconnect(player: Player, session: any, activeSessions: any?, CoopMatchService: any?)
	if not session or session.sessionState ~= GameConstants.MINI_GAME.STATE.MINIGAME then
		return
	end

	-- Force-finish for this player
	local result = { success = false, score = 0 }

	-- Clean up active minigame module
	local mod = getGameModule(session.activeMiniGameId or "obstacle_rush")
	if mod then
		mod:Cleanup(player)
	end

	-- Handle co-op: force-complete for remaining players
	if session.coopSessionId and CoopMatchService and activeSessions then
		self:OnPlayerFinish(player, session, result, activeSessions, CoopMatchService)
	end

	-- Clean up co-op results
	if session.coopSessionId then
		_coopResults[session.coopSessionId] = nil
	end
end

-- Setup RemoteEvent handlers
function MiniGameService:SetupRemoteEvents()
	-- Client hit report
	RemoteEvents.MiniGameHitReport.OnServerEvent:Connect(function(player: Player, data: any)
		if not RateLimiter.Check(player, "MiniGameHitReport", 5) then
			return
		end
		-- Forward to active minigame module
		local mod = getGameModule("obstacle_rush")
		if mod and mod.OnHitReport then
			mod:OnHitReport(player, data)
		end
	end)

	print("[MiniGameService] RemoteEvents initialized")
end

function MiniGameService:Init()
	self:SetupRemoteEvents()
	print("[MiniGameService] Initialized")
end

return MiniGameService

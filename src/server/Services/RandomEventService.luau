--!strict
-- RandomEventService (v3)
-- Environmental random events during runs

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local RandomEventService = {}

-- Per-player event state
local _activeEvents: { [Player]: {
	eventId: string,
	endTime: number,
	effectData: any,
} } = {}

local _nextEventTime: { [Player]: number } = {}

-- Calculate next event trigger time
local function getNextTriggerTime(isSolo: boolean?): number
	local re = GameConstants.RANDOM_EVENTS
	local interval = (isSolo and re.SOLO_TRIGGER_INTERVAL) or re.TRIGGER_INTERVAL
	local variance = re.TRIGGER_VARIANCE
	return os.clock() + interval + (math.random() * 2 - 1) * variance
end

-- Select a random event
local function selectEvent(): any
	local events = GameConstants.RANDOM_EVENTS.EVENTS
	return events[math.random(1, #events)]
end

-- Check if an event should trigger (called from GameManager Heartbeat)
function RandomEventService:Update(player: Player, session: any, _deltaTime: number)
	-- Skip if in minigame
	if session.sessionState ~= "running" then
		return
	end

	-- Skip if event already active
	if _activeEvents[player] then
		-- Check if current event expired
		if os.clock() >= _activeEvents[player].endTime then
			self:EndEvent(player, session)
		end
		return
	end

	-- Initialize next event time
	if not _nextEventTime[player] then
		local isSolo = not session.coopSessionId
		_nextEventTime[player] = getNextTriggerTime(isSolo)
	end

	-- Check trigger
	if os.clock() >= _nextEventTime[player] then
		self:StartEvent(player, session)
	end
end

-- Start a random event
function RandomEventService:StartEvent(player: Player, session: any)
	local eventConfig = selectEvent()

	-- Solo: cap event duration
	local duration = eventConfig.duration
	if not session.coopSessionId then
		local maxDuration = GameConstants.RANDOM_EVENTS.SOLO_EVENT_MAX_DURATION or 10
		if duration > maxDuration then
			duration = maxDuration
		end
	end

	_activeEvents[player] = {
		eventId = eventConfig.id,
		endTime = os.clock() + duration,
		effectData = eventConfig,
	}
	_nextEventTime[player] = nil

	-- Apply server-side effects
	self:_applyEffect(session, eventConfig)

	-- Notify client
	RemoteEvents.RandomEventStart:FireClient(player, {
		eventId = eventConfig.id,
		duration = duration,
		eventConfig = eventConfig,
	})

	print(`[RandomEventService] {eventConfig.id} started for {player.Name} ({duration}s)`)
end

-- End current event
function RandomEventService:EndEvent(player: Player, session: any)
	local activeEvent = _activeEvents[player]
	if not activeEvent then
		return
	end

	-- Revert server-side effects
	self:_revertEffect(session, activeEvent.effectData)

	-- Notify client
	RemoteEvents.RandomEventEnd:FireClient(player, {
		eventId = activeEvent.eventId,
	})

	print(`[RandomEventService] {activeEvent.eventId} ended for {player.Name}`)

	_activeEvents[player] = nil
	local isSolo = not session.coopSessionId
	_nextEventTime[player] = getNextTriggerTime(isSolo)
end

-- Apply effect to session
function RandomEventService:_applyEffect(session: any, config: any)
	if config.id == "coin_rain" then
		session._coinRainActive = true
	elseif config.id == "speed_shift" then
		session._speedShiftMultiplier = config.speedMultiplier or 1.5
	elseif config.id == "giant_mode" then
		session._giantScaleFactor = config.scaleFactor or 1.8
	elseif config.id == "gravity_flip" then
		session._gravityMultiplier = config.gravityMultiplier or 0.4
	elseif config.id == "fog" then
		session._fogActive = true
	elseif config.id == "bonus_time" then
		session._bonusTimeActive = true
		session._bonusTimeCoinMult = config.coinMultiplier or 3
		session._bonusTimeSpeedMult = config.speedReduction or 0.75
	end
end

-- Revert effect from session
function RandomEventService:_revertEffect(session: any, config: any)
	if config.id == "coin_rain" then
		session._coinRainActive = false
	elseif config.id == "speed_shift" then
		session._speedShiftMultiplier = 1.0
	elseif config.id == "giant_mode" then
		session._giantScaleFactor = 1.0
	elseif config.id == "gravity_flip" then
		session._gravityMultiplier = 1.0
	elseif config.id == "fog" then
		session._fogActive = false
	elseif config.id == "bonus_time" then
		session._bonusTimeActive = false
		session._bonusTimeCoinMult = 1
		session._bonusTimeSpeedMult = 1
	end
end

-- Force end event (e.g., game over, minigame start)
function RandomEventService:ForceEnd(player: Player, session: any)
	if _activeEvents[player] then
		self:EndEvent(player, session)
	end
end

-- Get active event for player
function RandomEventService:GetActiveEvent(player: Player): string?
	local active = _activeEvents[player]
	return active and active.eventId or nil
end

-- Cleanup on player leave
function RandomEventService:OnPlayerRemoving(player: Player)
	_activeEvents[player] = nil
	_nextEventTime[player] = nil
end

-- Shift event times on minigame pause
function RandomEventService:ShiftTimes(player: Player, pauseDelta: number)
	if _activeEvents[player] then
		_activeEvents[player].endTime += pauseDelta
	end
	if _nextEventTime[player] then
		_nextEventTime[player] += pauseDelta
	end
end

function RandomEventService:Init()
	print("[RandomEventService] Initialized")
end

return RandomEventService

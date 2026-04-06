--!strict
-- CoopMatchService
-- Co-op matchmaking queue and session management

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local AnalyticsService = require(ServerScriptService.Server.Services.AnalyticsService)

local CoopMatchService = {}

type CoopSession = {
	sessionId: string,
	players: { Player },
	lanes: { [Player]: string }, -- "left" or "right"
	sharedLives: number,
	startTime: number,
	isActive: boolean,
}

-- Matchmaking queue (players waiting for a partner)
local _queue: { Player } = {}

-- Active co-op sessions keyed by sessionId
local _sessions: { [string]: CoopSession } = {}

-- Player → sessionId reverse lookup
local _playerSession: { [Player]: string } = {}

-- Bot insertion timer handles
local _botTimers: { [Player]: thread } = {}

-- Queue entry times for wait duration tracking
local _queueEnterTimes: { [Player]: number } = {}

-- Generate a session ID
local function makeSessionId(p1: Player, p2: Player?): string
	local suffix = p2 and tostring(p2.UserId) or "bot"
	return GameConstants.COOP.SESSION_ID_PREFIX .. tostring(p1.UserId) .. "_" .. suffix .. "_" .. tostring(os.time())
end

-- Remove a player from queue
local function removeFromQueue(player: Player)
	for i, p in _queue do
		if p == player then
			table.remove(_queue, i)
			break
		end
	end
	-- cancel bot timer if any
	if _botTimers[player] then
		task.cancel(_botTimers[player])
		_botTimers[player] = nil
	end
end

-- Create a co-op session between two players (p2 may be nil for bot session)
local function createSession(p1: Player, p2: Player?): CoopSession
	local sessionId = makeSessionId(p1, p2)
	local session: CoopSession = {
		sessionId = sessionId,
		players = if p2 then { p1, p2 } else { p1 },
		lanes = {
			[p1] = "left",
		},
		sharedLives = GameConstants.COOP.SHARED_LIVES,
		startTime = os.time(),
		isActive = true,
	}
	if p2 then
		session.lanes[p2] = "right"
	end
	_sessions[sessionId] = session
	_playerSession[p1] = sessionId
	if p2 then
		_playerSession[p2] = sessionId
	end
	return session
end

-- Notify players that a match was found
local function notifyMatch(session: CoopSession)
	local players = session.players
	if #players == 2 then
		local p1, p2 = players[1], players[2]
		RemoteEvents.CoopMatchFound:FireClient(p1, {
			sessionId = session.sessionId,
			partnerName = p2.Name,
			partnerUserId = p2.UserId,
			myLane = session.lanes[p1],
		})
		RemoteEvents.CoopMatchFound:FireClient(p2, {
			sessionId = session.sessionId,
			partnerName = p1.Name,
			partnerUserId = p1.UserId,
			myLane = session.lanes[p2],
		})
	elseif #players == 1 then
		-- Bot match
		local p1 = players[1]
		RemoteEvents.CoopMatchFound:FireClient(p1, {
			sessionId = session.sessionId,
			partnerName = GameConstants.COOP.BOT_NAME,
			partnerUserId = 0,
			myLane = session.lanes[p1],
		})
	end
end

-- Try to pair two queued players
local function tryMatch()
	if #_queue >= 2 then
		local p1 = table.remove(_queue, 1)
		local p2 = table.remove(_queue, 1)
		removeFromQueue(p1) -- cancel any bot timers
		removeFromQueue(p2)
		local session = createSession(p1, p2)
		notifyMatch(session)
		-- Analytics: coop_match found (per player)
		local now = os.clock()
		AnalyticsService:Track(p1, "coop_match", {
			matchResult = "found",
			waitSeconds = math.floor(now - (_queueEnterTimes[p1] or now)),
		})
		AnalyticsService:Track(p2, "coop_match", {
			matchResult = "found",
			waitSeconds = math.floor(now - (_queueEnterTimes[p2] or now)),
		})
		_queueEnterTimes[p1] = nil
		_queueEnterTimes[p2] = nil
		print(string.format("[CoopMatchService] Matched %s and %s — session %s", p1.Name, p2.Name, session.sessionId))
	end
end

-- Insert a bot partner after timeout
local function scheduleBotMatch(player: Player)
	_botTimers[player] = task.delay(GameConstants.COOP.MATCHMAKING_TIMEOUT, function()
		-- Check the player is still in queue
		local inQueue = false
		for _, p in _queue do
			if p == player then
				inQueue = true
				break
			end
		end
		if not inQueue then return end
		removeFromQueue(player)
		local session = createSession(player, nil)
		notifyMatch(session)
		-- Analytics: coop_match timeout (bot assigned)
		local nowBot = os.clock()
		AnalyticsService:Track(player, "coop_match", {
			matchResult = "timeout",
			waitSeconds = math.floor(nowBot - (_queueEnterTimes[player] or nowBot)),
		})
		_queueEnterTimes[player] = nil
		print(string.format("[CoopMatchService] Bot match for %s — session %s", player.Name, session.sessionId))
	end)
end

-- Public API --

function CoopMatchService:Init()
	-- Handle queue join
	RemoteEvents.CoopQueue.OnServerEvent:Connect(function(player: Player)
		-- Already in queue or session?
		if _playerSession[player] then return end
		for _, p in _queue do
			if p == player then return end
		end
		_queueEnterTimes[player] = os.clock()
		table.insert(_queue, player)
		print(string.format("[CoopMatchService] %s joined coop queue (queue size: %d)", player.Name, #_queue))
		tryMatch()
		if not _playerSession[player] then
			-- Still unmatched — schedule bot
			scheduleBotMatch(player)
		end
	end)

	-- Handle queue cancel
	RemoteEvents.CoopQueueCancel.OnServerEvent:Connect(function(player: Player)
		-- Analytics: coop_match cancel
		local nowCancel = os.clock()
		AnalyticsService:Track(player, "coop_match", {
			matchResult = "cancel",
			waitSeconds = math.floor(nowCancel - (_queueEnterTimes[player] or nowCancel)),
		})
		_queueEnterTimes[player] = nil
		removeFromQueue(player)
		print(string.format("[CoopMatchService] %s cancelled coop queue", player.Name))
	end)

	print("[CoopMatchService] Initialized")
end

-- Called by GameManager when a player's co-op run ends
function CoopMatchService:EndSession(player: Player, finalScore: number)
	local sessionId = _playerSession[player]
	if not sessionId then return end
	local session = _sessions[sessionId]
	if not session then return end
	session.isActive = false
	-- Notify all session members
	for _, p in session.players do
		RemoteEvents.CoopGameOver:FireClient(p, {
			reason = "run_ended",
			score = finalScore,
			partnerScore = 0, -- simplified; GameManager can pass actual scores
		})
		_playerSession[p] = nil
	end
	_sessions[sessionId] = nil
	print(string.format("[CoopMatchService] Session %s ended", sessionId))
end

-- Called by GameManager to broadcast partner state updates
function CoopMatchService:BroadcastPartnerState(player: Player, lives: number, combo: number, isAlive: boolean)
	local sessionId = _playerSession[player]
	if not sessionId then return end
	local session = _sessions[sessionId]
	if not session or not session.isActive then return end
	-- Send to all OTHER players in session
	for _, p in session.players do
		if p ~= player then
			RemoteEvents.CoopPartnerState:FireClient(p, {
				lives = lives,
				combo = combo,
				isAlive = isAlive,
			})
		end
	end
end

-- Returns the co-op session for a player (nil if not in a session)
function CoopMatchService:GetSession(player: Player): CoopSession?
	local sessionId = _playerSession[player]
	return sessionId and _sessions[sessionId] or nil
end

-- Returns the Z-axis offset for the player's lane
function CoopMatchService:GetLaneZ(player: Player): number
	local session = self:GetSession(player)
	if not session then return 0 end
	local lane = session.lanes[player]
	if lane == "left" then
		return GameConstants.COOP.LANES.Z_LEFT
	elseif lane == "right" then
		return GameConstants.COOP.LANES.Z_RIGHT
	end
	return 0
end

-- Cleanup on player leaving
function CoopMatchService:OnPlayerRemoving(player: Player)
	_queueEnterTimes[player] = nil
	removeFromQueue(player)
	local sessionId = _playerSession[player]
	if sessionId then
		local session = _sessions[sessionId]
		if session then
			-- Notify partner
			for _, p in session.players do
				if p ~= player then
					RemoteEvents.CoopGameOver:FireClient(p, {
						reason = "partner_left",
						score = 0,
						partnerScore = 0,
					})
					_playerSession[p] = nil
				end
			end
			_sessions[sessionId] = nil
		end
		_playerSession[player] = nil
	end
end

return CoopMatchService

--!strict
-- ObstacleRush MiniGame (v3)
-- Dodge obstacles at high speed for 20 seconds
-- Success: survive with < 3 hits
-- Failure: 3 hits

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local ObstacleRush = {}

-- Active games per player
local _activeGames: { [Player]: {
	isActive: boolean,
	hitCount: number,
	maxHits: number,
	totalObstacles: number,
	spawnedCount: number,
	endTimer: thread?,
	session: any,
	onFinish: ((Player, { success: boolean, score: number }) -> ())?,
} } = {}

-- Start obstacle rush for a player
function ObstacleRush:Start(player: Player, session: any, difficulty: any, gameType: any)
	local duration = gameType.duration or 20
	local obstacleCount = difficulty and difficulty.obstacleCount or 8
	local speedMult = difficulty and difficulty.speedMultiplier or 1.0

	local game = {
		isActive = true,
		hitCount = 0,
		maxHits = 3,
		totalObstacles = obstacleCount,
		spawnedCount = 0,
		endTimer = nil,
		session = session,
		onFinish = nil,
	}
	_activeGames[player] = game

	-- Spawn obstacles over time
	local interval = duration / obstacleCount
	for i = 1, obstacleCount do
		task.delay(interval * (i - 1), function()
			if not game.isActive then
				return
			end
			game.spawnedCount += 1

			-- Determine obstacle direction (left, right, top)
			local directions = { "left", "right", "top" }
			local dir = directions[(i % #directions) + 1]

			-- Notify client to spawn visual obstacle
			RemoteEvents.MiniGameObstacle:FireClient(player, {
				obstacleIndex = i,
				direction = dir,
				speed = speedMult,
			})
		end)
	end

	-- Auto-end on timeout (survival = success)
	game.endTimer = task.delay(duration, function()
		if game.isActive then
			self:_finish(player, true)
		end
	end)

	print(`[ObstacleRush] Started for {player.Name}: {obstacleCount} obstacles, {duration}s`)
end

-- Handle hit report from client
function ObstacleRush:OnHitReport(player: Player, _data: any)
	local game = _activeGames[player]
	if not game or not game.isActive then
		return
	end

	game.hitCount += 1

	-- Notify client of remaining hits
	RemoteEvents.MiniGameHit:FireClient(player, {
		hitsRemaining = game.maxHits - game.hitCount,
	})

	-- Check failure
	if game.hitCount >= game.maxHits then
		self:_finish(player, false)
	end
end

-- Finish the minigame
function ObstacleRush:_finish(player: Player, success: boolean)
	local game = _activeGames[player]
	if not game or not game.isActive then
		return
	end

	game.isActive = false

	-- Cancel auto-end timer
	if game.endTimer then
		task.cancel(game.endTimer)
		game.endTimer = nil
	end

	local result = {
		success = success,
		score = success and (game.totalObstacles - game.hitCount) or 0,
	}

	-- Notify MiniGameService via callback or direct require
	local MiniGameService = require(script.Parent.Parent.MiniGameService)
	MiniGameService:OnPlayerFinish(player, game.session, result)

	print(`[ObstacleRush] Finished for {player.Name}: success={success}, hits={game.hitCount}`)
end

-- Cleanup
function ObstacleRush:Cleanup(player: Player)
	local game = _activeGames[player]
	if game then
		game.isActive = false
		if game.endTimer then
			task.cancel(game.endTimer)
		end
	end
	_activeGames[player] = nil
end

return ObstacleRush

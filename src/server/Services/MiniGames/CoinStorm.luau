--!strict
-- CoinStorm MiniGame (v3)
-- Collect as many falling coins as possible in 20 seconds
-- Reward scales with coins collected

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local CoinStorm = {}

local _activeGames: { [Player]: {
	isActive: boolean,
	totalCoins: number,
	collectedCount: number,
	spawnedCount: number,
	endTimer: thread?,
	session: any,
} } = {}

function CoinStorm:Start(player: Player, session: any, difficulty: any, gameType: any)
	local duration = gameType.duration or 20
	local coinCount = difficulty and (difficulty.obstacleCount * 3) or 24
	local speedMult = difficulty and difficulty.speedMultiplier or 1.0

	local game = {
		isActive = true,
		totalCoins = coinCount,
		collectedCount = 0,
		spawnedCount = 0,
		endTimer = nil,
		session = session,
	}
	_activeGames[player] = game

	-- Spawn coins over duration
	local interval = duration / coinCount
	for i = 1, coinCount do
		task.delay(interval * (i - 1), function()
			if not game.isActive then
				return
			end
			game.spawnedCount += 1

			-- Random position across screen
			local positions = { "left", "center", "right" }
			local pos = positions[(i % #positions) + 1]

			RemoteEvents.MiniGameObstacle:FireClient(player, {
				obstacleIndex = i,
				direction = pos,
				speed = speedMult,
				isCoin = true,
			})
		end)
	end

	-- Auto-end on timeout
	game.endTimer = task.delay(duration, function()
		if game.isActive then
			self:_finish(player)
		end
	end)

	print(`[CoinStorm] Started for {player.Name}: {coinCount} coins, {duration}s`)
end

-- Client reports coin collection (dodge = collect in this context)
function CoinStorm:OnHitReport(player: Player, data: any)
	local game = _activeGames[player]
	if not game or not game.isActive then
		return
	end

	local coinIndex = data and data.obstacleIndex
	if type(coinIndex) ~= "number" or coinIndex < 1 or coinIndex > game.totalCoins then
		return
	end

	game.collectedCount += 1

	-- Notify client of collection count
	RemoteEvents.MiniGameHit:FireClient(player, {
		hitsRemaining = game.collectedCount,
		isCollection = true,
	})
end

function CoinStorm:_finish(player: Player)
	local game = _activeGames[player]
	if not game or not game.isActive then
		return
	end

	game.isActive = false

	if game.endTimer then
		task.cancel(game.endTimer)
		game.endTimer = nil
	end

	-- Always "success" but reward scales with collection ratio
	local ratio = game.spawnedCount > 0 and (game.collectedCount / game.spawnedCount) or 0
	local result = {
		success = true,
		score = game.collectedCount,
		ratio = ratio,
	}

	local MiniGameService = require(script.Parent.Parent.MiniGameService)
	MiniGameService:OnPlayerFinish(player, game.session, result)

	_activeGames[player] = nil

	print(`[CoinStorm] Finished for {player.Name}: collected {game.collectedCount}/{game.spawnedCount}`)
end

function CoinStorm:Cleanup(player: Player)
	local game = _activeGames[player]
	if game then
		game.isActive = false
		if game.endTimer then
			task.cancel(game.endTimer)
		end
	end
	_activeGames[player] = nil
end

return CoinStorm

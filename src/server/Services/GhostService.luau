--!strict
-- GhostService
-- Ghost Racing: records player action sequences and serves friend ghost data

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local GhostService = {}
GhostService.__index = GhostService

-- Injected dependency
local _playerDataService: any = nil

-- In-memory buffer for current run action recording
-- key: player.UserId → { startTime, actions, sessionScore }
local _activeRecordings: {
	[number]: { startTime: number, actions: { { time: number, action: string } }, sessionScore: number },
} = {}

function GhostService.new()
	local self = setmetatable({}, GhostService)
	return self
end

-- Init: wire up RemoteEvent handlers and store PlayerDataService reference
function GhostService:Init(playerDataService: any)
	_playerDataService = playerDataService

	-- Client requests ghost data for a friend at run start
	RemoteEvents.RequestGhostData.OnServerEvent:Connect(function(player: Player)
		self:_sendGhostData(player)
	end)

	-- Client records an action (jump/slide) during the run
	RemoteEvents.RecordGhostAction.OnServerEvent:Connect(function(player: Player, action: unknown, runTime: unknown)
		if type(action) ~= "string" or type(runTime) ~= "number" then
			return
		end
		self:_recordAction(player, action, runTime)
	end)
end

-- Start recording a new run for a player (called by GameManager on run start)
function GhostService:StartRecording(player: Player)
	_activeRecordings[player.UserId] = {
		startTime = os.clock(),
		actions = {},
		sessionScore = 0,
	}
end

-- Update the in-progress score for the recording (called periodically by GameManager)
function GhostService:UpdateScore(player: Player, score: number)
	local rec = _activeRecordings[player.UserId]
	if rec then
		rec.sessionScore = score
	end
end

-- Finish recording and persist if this run beat the previous ghost best score
function GhostService:FinishRecording(player: Player, finalScore: number)
	local rec = _activeRecordings[player.UserId]
	if not rec then
		return
	end

	local data = _playerDataService:GetPlayerData(player)
	if not data then
		_activeRecordings[player.UserId] = nil
		return
	end

	-- Initialise ghostData field if absent (old save files)
	if not data.ghostData then
		data.ghostData = { bestRunScore = 0, actions = {}, runDuration = 0 }
	end

	-- Only save if this run produced a new best
	local previousBest = data.ghostData.bestRunScore or 0
	if finalScore > previousBest then
		local duration = os.clock() - rec.startTime
		data.ghostData = {
			bestRunScore = finalScore,
			actions = rec.actions,
			runDuration = math.min(duration, GameConstants.GHOST.RUN_DURATION_LIMIT),
		}
		print(`[GhostService] New ghost saved for {player.Name}: score={finalScore}, actions={#rec.actions}`)
	end

	_activeRecordings[player.UserId] = nil
end

-- Clean up recording on player leaving (no-op if not recording)
function GhostService:OnPlayerRemoving(player: Player)
	_activeRecordings[player.UserId] = nil
end

-- Internal: record a single action event sent from the client
function GhostService:_recordAction(player: Player, action: string, runTime: number)
	local rec = _activeRecordings[player.UserId]
	if not rec then
		return
	end

	-- Validate action string
	if action ~= "jump" and action ~= "double_jump" and action ~= "slide" then
		return
	end

	-- Cap total actions per run
	if #rec.actions >= GameConstants.GHOST.MAX_ACTIONS then
		return
	end

	-- Cap run time
	if runTime > GameConstants.GHOST.RUN_DURATION_LIMIT then
		return
	end

	table.insert(rec.actions, { time = runTime, action = action })
end

-- Internal: look up the best friend ghost and fire it to the requesting player
function GhostService:_sendGhostData(player: Player)
	local ghostInfo: any = nil

	-- Try to find a friend currently in this server with ghost data
	local ok, err = pcall(function()
		local friendPages = Players:GetFriendsAsync(player.UserId)
		local checked = 0
		local bestScore = 0

		while true do
			local friends = friendPages:GetCurrentPage()
			for _, friendInfo in ipairs(friends) do
				if checked >= 20 then
					break
				end
				checked += 1

				-- Only check friends who are in this server right now
				local friendPlayer = Players:GetPlayerByUserId(friendInfo.Id)
				if friendPlayer then
					local friendData = _playerDataService:GetPlayerData(friendPlayer)
					if friendData and friendData.ghostData then
						local friendScore = friendData.ghostData.bestRunScore or 0
						if friendScore > bestScore then
							bestScore = friendScore
							ghostInfo = {
								name = friendPlayer.DisplayName,
								score = friendScore,
								actions = friendData.ghostData.actions or {},
								runDuration = friendData.ghostData.runDuration or 0,
							}
						end
					end
				end
			end

			if friendPages.IsFinished or checked >= 20 then
				break
			end
			friendPages:AdvanceToNextPageAsync()
		end
	end)

	if not ok then
		-- Friends API is unavailable in Studio or on error — suppress and send nil
		warn("[GhostService] Friends API error (expected in Studio): " .. tostring(err))
		ghostInfo = nil
	end

	-- Fire ghost data (nil means no ghost to display)
	RemoteEvents.GhostData:FireClient(player, ghostInfo)
end

return GhostService

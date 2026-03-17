--!strict
-- TeamService
-- Team creation/joining/leaving, weekly coin aggregation, reward distribution

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local TeamService = {}

local _playerDataService: any = nil

-- DataStore for team metadata (teamId → { name, ownerId, members, weeklyCoins, createdAt })
local _teamStore: DataStore? = nil
local teamStoreOk, teamStoreErr = pcall(function()
	_teamStore = DataStoreService:GetDataStore("TeamData_v1")
end)
if not teamStoreOk then
	warn("[TeamService] TeamData DataStore unavailable: " .. tostring(teamStoreErr))
end

-- OrderedDataStore for weekly ranking
local _rankingStore: OrderedDataStore? = nil
local rankingStoreOk, rankingStoreErr = pcall(function()
	_rankingStore = DataStoreService:GetOrderedDataStore("TeamWeeklyRanking_v1")
end)
if not rankingStoreOk then
	warn("[TeamService] TeamWeeklyRanking DataStore unavailable: " .. tostring(rankingStoreErr))
end

-- In-memory team cache: teamId → teamEntry
type TeamEntry = {
	name: string,
	ownerId: number,
	members: { number },
	weeklyCoins: number,
	createdAt: number,
}
local _teamCache: { [string]: TeamEntry } = {}

-- Init: register RemoteEvent handlers and store PlayerDataService dependency
function TeamService:Init(playerDataService: any)
	_playerDataService = playerDataService

	-- Team create
	RemoteEvents.TeamCreate.OnServerEvent:Connect(function(player: Player, teamName: any)
		self:_handleCreate(player, teamName)
	end)

	-- Team join
	RemoteEvents.TeamJoin.OnServerEvent:Connect(function(player: Player, teamId: any)
		self:_handleJoin(player, teamId)
	end)

	-- Team leave
	RemoteEvents.TeamLeave.OnServerEvent:Connect(function(player: Player)
		self:_handleLeave(player)
	end)

	-- Request ranking
	RemoteEvents.RequestTeamRanking.OnServerEvent:Connect(function(player: Player)
		self:_sendRanking(player)
	end)

	print("[TeamService] Initialized")
end

-- Add coins to the player's team weekly total (called by GameManager on run end)
function TeamService:AddWeeklyCoins(player: Player, coins: number)
	if not _playerDataService then return end
	local data = _playerDataService:GetPlayerData(player)
	if not data then return end
	if not data.team or data.team.teamId == "" then return end

	data.team.weeklyCoins = (data.team.weeklyCoins or 0) + coins

	-- Increment the OrderedDataStore entry for this team
	local teamId = data.team.teamId
	if _rankingStore then
		pcall(function()
			(_rankingStore :: OrderedDataStore):IncrementAsync(teamId, coins)
		end)
	end
end

-- Check and reset weekly coins for a player if a new week has started (called on player join)
function TeamService:CheckWeeklyReset(player: Player)
	if not _playerDataService then return end
	local data = _playerDataService:GetPlayerData(player)
	if not data or not data.team then return end

	local now = os.time()
	local lastReset = data.team.lastWeekReset or 0
	local weekSeconds = 7 * 24 * 3600

	if now - lastReset >= weekSeconds then
		data.team.weeklyCoins = 0
		data.team.lastWeekReset = now
	end

	-- Send current team data to client
	if data.team.teamId ~= "" then
		RemoteEvents.TeamData:FireClient(player, data.team)
	end
end

-- Get gem reward for a given rank
function TeamService:GetRankReward(rank: number): number
	for _, tier in ipairs(GameConstants.TEAM.WEEKLY_REWARD_TIERS) do
		if rank <= tier.maxRank then
			return tier.gems
		end
	end
	return 0
end

-- Create a new team
function TeamService:_handleCreate(player: Player, teamName: any)
	local data = _playerDataService:GetPlayerData(player)
	if not data then return end

	-- Validate name
	if type(teamName) ~= "string" or #teamName < 2 or #teamName > GameConstants.TEAM.MAX_TEAM_NAME_LENGTH then
		RemoteEvents.TeamCreateResult:FireClient(player, { success = false, reason = "invalid_name" })
		return
	end

	-- Check if already in a team
	if data.team and data.team.teamId ~= "" then
		RemoteEvents.TeamCreateResult:FireClient(player, { success = false, reason = "already_in_team" })
		return
	end

	-- Check coins
	if (data.coins or 0) < GameConstants.TEAM.CREATE_COST then
		RemoteEvents.TeamCreateResult:FireClient(player, { success = false, reason = "insufficient_coins" })
		return
	end

	-- Deduct coins
	data.coins = data.coins - GameConstants.TEAM.CREATE_COST

	-- Generate unique team ID
	local teamId = tostring(player.UserId) .. "_" .. tostring(os.time())

	-- Build team entry
	local teamEntry: TeamEntry = {
		name = teamName,
		ownerId = player.UserId,
		members = { player.UserId },
		weeklyCoins = 0,
		createdAt = os.time(),
	}
	_teamCache[teamId] = teamEntry

	-- Persist to DataStore
	if _teamStore then
		pcall(function()
			(_teamStore :: DataStore):SetAsync(teamId, teamEntry)
		end)
	end

	-- Update player's team data
	data.team = {
		teamId = teamId,
		teamName = teamName,
		joinedAt = os.time(),
		weeklyCoins = 0,
		lastWeekReset = os.time(),
	}

	RemoteEvents.TeamCreateResult:FireClient(player, { success = true, teamId = teamId, teamName = teamName })
	RemoteEvents.TeamData:FireClient(player, data.team)
	print(`[TeamService] {player.Name} created team "{teamName}" (id={teamId})`)
end

-- Join an existing team
function TeamService:_handleJoin(player: Player, teamId: any)
	local data = _playerDataService:GetPlayerData(player)
	if not data then return end

	-- Validate teamId
	if type(teamId) ~= "string" or #teamId == 0 then
		RemoteEvents.TeamJoinResult:FireClient(player, { success = false, reason = "invalid_id" })
		return
	end

	-- Check if already in a team
	if data.team and data.team.teamId ~= "" then
		RemoteEvents.TeamJoinResult:FireClient(player, { success = false, reason = "already_in_team" })
		return
	end

	-- Load team entry (cache first, then DataStore)
	local teamEntry: TeamEntry? = _teamCache[teamId]
	if not teamEntry and _teamStore then
		local ok, result = pcall(function()
			return (_teamStore :: DataStore):GetAsync(teamId)
		end)
		if ok and result then
			teamEntry = result :: TeamEntry
			_teamCache[teamId] = teamEntry :: TeamEntry
		end
	end

	if not teamEntry then
		RemoteEvents.TeamJoinResult:FireClient(player, { success = false, reason = "team_not_found" })
		return
	end

	-- Check member limit
	if #(teamEntry :: TeamEntry).members >= GameConstants.TEAM.MAX_MEMBERS then
		RemoteEvents.TeamJoinResult:FireClient(player, { success = false, reason = "team_full" })
		return
	end

	-- Add member
	table.insert((teamEntry :: TeamEntry).members, player.UserId)

	-- Update DataStore
	if _teamStore then
		pcall(function()
			(_teamStore :: DataStore):SetAsync(teamId, teamEntry)
		end)
	end

	-- Update player data
	data.team = {
		teamId = teamId,
		teamName = (teamEntry :: TeamEntry).name,
		joinedAt = os.time(),
		weeklyCoins = 0,
		lastWeekReset = os.time(),
	}

	RemoteEvents.TeamJoinResult:FireClient(player, {
		success = true,
		teamId = teamId,
		teamName = (teamEntry :: TeamEntry).name,
	})
	RemoteEvents.TeamData:FireClient(player, data.team)
	print(`[TeamService] {player.Name} joined team "{(teamEntry :: TeamEntry).name}" (id={teamId})`)
end

-- Leave current team
function TeamService:_handleLeave(player: Player)
	local data = _playerDataService:GetPlayerData(player)
	if not data or not data.team or data.team.teamId == "" then return end

	local teamId = data.team.teamId

	-- Remove from in-memory cache
	local teamEntry: TeamEntry? = _teamCache[teamId]
	if teamEntry then
		for i, memberId in ipairs((teamEntry :: TeamEntry).members) do
			if memberId == player.UserId then
				table.remove((teamEntry :: TeamEntry).members, i)
				break
			end
		end
		if _teamStore then
			pcall(function()
				(_teamStore :: DataStore):SetAsync(teamId, teamEntry)
			end)
		end
	end

	-- Clear player's team data
	data.team = {
		teamId = "",
		teamName = "",
		joinedAt = 0,
		weeklyCoins = 0,
		lastWeekReset = 0,
	}

	RemoteEvents.TeamData:FireClient(player, data.team)
	print(`[TeamService] {player.Name} left team (id={teamId})`)
end

-- Send TOP 50 ranking to requesting client
function TeamService:_sendRanking(player: Player)
	local rankings: { { rank: number, teamId: string, teamName: string, weeklyCoins: number } } = {}

	if _rankingStore then
		local ok, pages = pcall(function()
			return (_rankingStore :: OrderedDataStore):GetSortedAsync(false, 50)
		end)

		if ok and pages then
			local rank = 1
			local pageData = (pages :: DataStorePages):GetCurrentPage()
			for _, entry in ipairs(pageData) do
				local tid = entry.key
				local coins = entry.value
				local tName = tid -- fallback to ID
				local cached = _teamCache[tid]
				if cached then
					tName = cached.name
				end
				table.insert(rankings, {
					rank = rank,
					teamId = tid,
					teamName = tName,
					weeklyCoins = coins,
				})
				rank += 1
			end
		end
	end

	RemoteEvents.TeamRankData:FireClient(player, rankings)
end

return TeamService

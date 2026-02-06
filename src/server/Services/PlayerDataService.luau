--!strict
-- Player Data Service
-- 플레이어 데이터 로드/저장 관리 (DataStore)

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local PlayerDataService = {}

-- DataStore (Studio에서는 사용 불가, 에러 무시)
local playerDataStore = nil
local success, err = pcall(function()
	playerDataStore = DataStoreService:GetDataStore(GameConstants.DATA.DATASTORE_NAME)
end)

if not success then
	warn("[PlayerDataService] DataStore unavailable (Studio mode): " .. tostring(err))
	warn("[PlayerDataService] Player data will not be saved")
end

-- 기본 플레이어 데이터 구조
type PlayerData = {
	coins: number,
	highScore: number,
	gamesPlayed: number,
	totalDistance: number,
	totalCoinsCollected: number,
	tutorialCompleted: boolean,
	-- 향후 추가: 스킨, 펫, 레벨 등
}

local DEFAULT_DATA: PlayerData = {
	coins = 0,
	highScore = 0,
	gamesPlayed = 0,
	totalDistance = 0,
	totalCoinsCollected = 0,
	tutorialCompleted = false,
}

-- 메모리 캐시 (활성 플레이어)
local playerDataCache: { [Player]: PlayerData } = {}

-- 플레이어 데이터 로드
function PlayerDataService:LoadPlayerData(player: Player): PlayerData?
	-- DataStore 사용 불가 시 기본값 사용 (Studio 모드)
	if not playerDataStore then
		print(`[PlayerDataService] Studio mode - using default data for {player.Name}`)
		local newData = self:_copyTable(DEFAULT_DATA)
		playerDataCache[player] = newData
		return newData
	end

	local userId = player.UserId
	local success, data = pcall(function()
		return playerDataStore:GetAsync("Player_" .. userId)
	end)

	if success and data then
		print(`[PlayerDataService] Loaded data for {player.Name}`)
		-- 데이터 검증 및 기본값 병합
		local playerData = self:_mergeWithDefaults(data)
		playerDataCache[player] = playerData
		return playerData
	elseif success then
		-- 신규 플레이어
		print(`[PlayerDataService] New player {player.Name}, creating default data`)
		local newData = self:_copyTable(DEFAULT_DATA)
		playerDataCache[player] = newData
		return newData
	else
		warn(`[PlayerDataService] Failed to load data for {player.Name}: {data}`)
		-- 로드 실패 시 기본값 사용
		local fallbackData = self:_copyTable(DEFAULT_DATA)
		playerDataCache[player] = fallbackData
		return fallbackData
	end
end

-- 플레이어 데이터 저장
function PlayerDataService:SavePlayerData(player: Player): boolean
	local playerData = playerDataCache[player]
	if not playerData then
		warn(`[PlayerDataService] No data to save for {player.Name}`)
		return false
	end

	-- DataStore 사용 불가 시 저장 스킵 (Studio 모드)
	if not playerDataStore then
		print(`[PlayerDataService] Studio mode - skipping save for {player.Name}`)
		return true
	end

	local userId = player.UserId
	local retryCount = GameConstants.DATA.SAVE_RETRY_COUNT

	for attempt = 1, retryCount do
		local success, error = pcall(function()
			playerDataStore:SetAsync("Player_" .. userId, playerData)
		end)

		if success then
			print(`[PlayerDataService] Saved data for {player.Name}`)
			return true
		else
			warn(`[PlayerDataService] Save attempt {attempt}/{retryCount} failed for {player.Name}: {error}`)
			if attempt < retryCount then
				task.wait(1) -- 재시도 전 대기
			end
		end
	end

	warn(`[PlayerDataService] Failed to save data for {player.Name} after {retryCount} attempts`)
	return false
end

-- 모든 플레이어 데이터 저장 (서버 종료 시)
function PlayerDataService:SaveAllPlayers()
	print("[PlayerDataService] Saving all player data...")
	local savedCount = 0

	for player, _ in playerDataCache do
		if self:SavePlayerData(player) then
			savedCount += 1
		end
	end

	print(`[PlayerDataService] Saved {savedCount}/{#playerDataCache} players`)
end

-- 플레이어 데이터 가져오기 (캐시에서)
function PlayerDataService:GetPlayerData(player: Player): PlayerData?
	return playerDataCache[player]
end

-- 플레이어 데이터 업데이트
function PlayerDataService:UpdatePlayerData(player: Player, updates: { [string]: any })
	local playerData = playerDataCache[player]
	if not playerData then
		warn(`[PlayerDataService] Cannot update data for {player.Name}, not loaded`)
		return
	end

	-- 업데이트 적용
	for key, value in updates do
		if playerData[key] ~= nil then
			playerData[key] = value
		end
	end
end

-- 게임 종료 후 데이터 업데이트
function PlayerDataService:OnGameEnd(player: Player, finalScore: number, earnedCoins: number, distance: number)
	local playerData = playerDataCache[player]
	if not playerData then
		return
	end

	-- 통계 업데이트
	playerData.coins += earnedCoins
	playerData.gamesPlayed += 1
	playerData.totalCoinsCollected += earnedCoins
	playerData.totalDistance += distance

	-- 최고 점수 갱신
	if finalScore > playerData.highScore then
		playerData.highScore = finalScore
		print(`[PlayerDataService] New high score for {player.Name}: {finalScore}`)
	end

	-- 즉시 저장
	self:SavePlayerData(player)

	-- 클라이언트에 업데이트된 데이터 전송
	RemoteEvents.PlayerDataLoaded:FireClient(player, playerData)
end

-- 튜토리얼 완료 상태 설정
function PlayerDataService:SetTutorialCompleted(player: Player, completed: boolean)
	local playerData = playerDataCache[player]
	if not playerData then
		return
	end

	playerData.tutorialCompleted = completed

	-- 즉시 저장
	self:SavePlayerData(player)

	print(`[PlayerDataService] Tutorial completed for {player.Name}: {completed}`)
end

-- 플레이어 퇴장 시 정리
function PlayerDataService:OnPlayerRemoving(player: Player)
	self:SavePlayerData(player)
	playerDataCache[player] = nil
end

-- 유틸리티: 테이블 복사
function PlayerDataService:_copyTable(original: any): any
	local copy = {}
	for key, value in original do
		copy[key] = value
	end
	return copy
end

-- 유틸리티: 기본값 병합
function PlayerDataService:_mergeWithDefaults(data: any): PlayerData
	local merged = self:_copyTable(DEFAULT_DATA)

	for key, value in data do
		if merged[key] ~= nil then
			merged[key] = value
		end
	end

	return merged
end

print("[PlayerDataService] Initialized")

return PlayerDataService

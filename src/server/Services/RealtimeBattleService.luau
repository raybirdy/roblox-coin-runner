--!strict
-- RealtimeBattleService
-- 실시간 배틀: 같은 서버 플레이어 매칭 + 봇 폴백 (점수 비교 모드)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local RealtimeBattleService = {}

local WIN_REWARD_GEMS = 80
local QUEUE_TIMEOUT = 12 -- 12초 내 상대 없으면 봇 매칭
local SCORE_SYNC_INTERVAL = 2.5 -- 2.5초마다 상대 점수 공유

-- ==================== 타입 ====================

type QueueEntry = {
	player: Player,
	joinTime: number,
}

type MatchInfo = {
	opponentPlayer: Player?, -- 봇이면 nil
	opponentName: string,
	isBot: boolean,
	botTargetScore: number?, -- 봇 대전 시 최종 목표 점수
	matchStartTime: number,
	myFinalScore: number?,
	opponentFinalScore: number?,
}

-- ==================== 상태 ====================

local _queue: { QueueEntry } = {}
local _matches: { [Player]: MatchInfo } = {}

-- GameManager.GetCurrentScore를 외부에서 설정 (순환 의존 방지)
local _getScoreFn: ((Player) -> number?)? = nil

function RealtimeBattleService:SetScoreGetter(fn: (Player) -> number?)
	_getScoreFn = fn
end

local function getCurrentScore(player: Player): number
	if _getScoreFn then
		return _getScoreFn(player) or 0
	end
	return 0
end

-- ==================== 큐 관리 ====================

local function removeFromQueue(player: Player)
	for i = #_queue, 1, -1 do
		if _queue[i].player == player then
			table.remove(_queue, i)
			break
		end
	end
end

local function isInQueue(player: Player): boolean
	for _, entry in _queue do
		if entry.player == player then
			return true
		end
	end
	return false
end

-- 봇 목표 점수 결정 (플레이어 highScore 기준)
local function getBotTargetScore(player: Player): number
	local playerData = PlayerDataService:GetPlayerData(player)
	local highScore = playerData and playerData.highScore or 0

	if highScore > 0 then
		-- highScore의 75%~125% 범위에서 봇 점수 설정 (경쟁적 느낌)
		local minScore = math.floor(highScore * 0.75)
		local maxScore = math.floor(highScore * 1.25)
		return minScore + math.random(0, maxScore - minScore)
	else
		-- 신규 플레이어: 적당한 기준값
		return math.random(400, 900)
	end
end

local function createBotMatch(player: Player)
	if _matches[player] then
		return
	end -- 이미 매칭됨

	local botScore = getBotTargetScore(player)
	local botNames = { "SpeedBot", "RunnerBot", "QuickBot", "DashBot", "ZoomBot" }
	local botName = botNames[math.random(1, #botNames)]

	_matches[player] = {
		opponentPlayer = nil,
		opponentName = botName,
		isBot = true,
		botTargetScore = botScore,
		matchStartTime = tick(),
		myFinalScore = nil,
		opponentFinalScore = nil,
	}

	RemoteEvents.BattleMatchFound:FireClient(player, {
		opponentName = botName,
		isBot = true,
	})

	print(`[RealtimeBattleService] {player.Name} ↔ BOT({botName}, target:{botScore})`)
end

local function createHumanMatch(player1: Player, player2: Player)
	local now = tick()
	_matches[player1] = {
		opponentPlayer = player2,
		opponentName = player2.Name,
		isBot = false,
		botTargetScore = nil,
		matchStartTime = now,
		myFinalScore = nil,
		opponentFinalScore = nil,
	}
	_matches[player2] = {
		opponentPlayer = player1,
		opponentName = player1.Name,
		isBot = false,
		botTargetScore = nil,
		matchStartTime = now,
		myFinalScore = nil,
		opponentFinalScore = nil,
	}

	RemoteEvents.BattleMatchFound:FireClient(player1, { opponentName = player2.Name, isBot = false })
	RemoteEvents.BattleMatchFound:FireClient(player2, { opponentName = player1.Name, isBot = false })

	print(`[RealtimeBattleService] Match: {player1.Name} ↔ {player2.Name}`)
end

-- ==================== 큐 진입 ====================

function RealtimeBattleService:EnterQueue(player: Player)
	if _matches[player] then
		warn(`[RealtimeBattleService] {player.Name} already in match`)
		return
	end
	if isInQueue(player) then
		return
	end

	-- 기존 큐에 다른 플레이어가 있으면 즉시 매칭
	if #_queue > 0 then
		local entry = _queue[1]
		if entry.player ~= player and entry.player.Parent then
			table.remove(_queue, 1)
			createHumanMatch(entry.player, player)
			return
		end
	end

	-- 큐에 추가 + 타임아웃 대기
	table.insert(_queue, { player = player, joinTime = tick() })
	print(`[RealtimeBattleService] {player.Name} queued (queue size: {#_queue})`)

	task.delay(QUEUE_TIMEOUT, function()
		-- 아직 큐에 있으면 봇 매칭
		if isInQueue(player) and not _matches[player] then
			removeFromQueue(player)
			createBotMatch(player)
		end
	end)
end

-- ==================== 큐 취소 ====================

function RealtimeBattleService:LeaveQueue(player: Player)
	removeFromQueue(player)
	print(`[RealtimeBattleService] {player.Name} left queue`)
end

-- ==================== 게임 종료 처리 ====================

function RealtimeBattleService:OnGameEnd(player: Player, finalScore: number)
	local match = _matches[player]
	if not match then
		return
	end

	match.myFinalScore = finalScore

	if match.isBot then
		-- 봇 대전: 게임 경과 시간 기반으로 봇 점수 시뮬레이션
		local elapsed = math.min(tick() - match.matchStartTime, 180)
		local botScore = math.min(
			match.botTargetScore or 800,
			math.floor(elapsed * 13 * (0.8 + math.random() * 0.4))
		)
		match.opponentFinalScore = botScore

		local won = finalScore >= botScore
		local reward = 0
		if won then
			reward = WIN_REWARD_GEMS
			PlayerDataService:AddGems(player, reward)
			local newGems = PlayerDataService:GetGems(player)
			RemoteEvents.GemsUpdated:FireClient(player, { gems = newGems })
		end

		RemoteEvents.BattleResult:FireClient(player, {
			won = won,
			myScore = finalScore,
			opponentScore = botScore,
			opponentName = match.opponentName,
			reward = won and reward or nil,
		})

		_matches[player] = nil
		print(
			`[RealtimeBattleService] BOT result: {player.Name} {won and "WIN" or "LOSE"} ({finalScore} vs {botScore})`
		)
	else
		-- 인간 대전: 상대도 끝났는지 확인
		local opponentPlayer = match.opponentPlayer
		if not opponentPlayer or not opponentPlayer.Parent then
			-- 상대가 게임을 떠남 → 승리 처리
			local reward = WIN_REWARD_GEMS
			PlayerDataService:AddGems(player, reward)
			local newGems = PlayerDataService:GetGems(player)
			RemoteEvents.GemsUpdated:FireClient(player, { gems = newGems })
			RemoteEvents.BattleResult:FireClient(player, {
				won = true,
				myScore = finalScore,
				opponentScore = 0,
				opponentName = match.opponentName,
				reward = reward,
			})
			_matches[player] = nil
			return
		end

		local opponentMatch = _matches[opponentPlayer]
		if opponentMatch and opponentMatch.myFinalScore then
			-- 둘 다 완료 → 결과 판정
			local opponentScore = opponentMatch.myFinalScore
			local p1Won = finalScore >= opponentScore
			local p2Won = not p1Won

			local p1Reward = 0
			local p2Reward = 0
			if p1Won then
				p1Reward = WIN_REWARD_GEMS
				PlayerDataService:AddGems(player, p1Reward)
				RemoteEvents.GemsUpdated:FireClient(player, { gems = PlayerDataService:GetGems(player) })
			else
				p2Reward = WIN_REWARD_GEMS
				PlayerDataService:AddGems(opponentPlayer, p2Reward)
				RemoteEvents.GemsUpdated:FireClient(
					opponentPlayer,
					{ gems = PlayerDataService:GetGems(opponentPlayer) }
				)
			end

			RemoteEvents.BattleResult:FireClient(player, {
				won = p1Won,
				myScore = finalScore,
				opponentScore = opponentScore,
				opponentName = match.opponentName,
				reward = p1Won and p1Reward or nil,
			})
			RemoteEvents.BattleResult:FireClient(opponentPlayer, {
				won = p2Won,
				myScore = opponentScore,
				opponentScore = finalScore,
				opponentName = opponentMatch.opponentName,
				reward = p2Won and p2Reward or nil,
			})

			_matches[player] = nil
			_matches[opponentPlayer] = nil

			print(
				`[RealtimeBattleService] Human result: {player.Name}({finalScore}) vs {opponentPlayer.Name}({opponentScore})`
			)
		end
		-- 상대가 아직 게임 중이면 내 점수만 저장하고 대기 (opponentMatch.myFinalScore가 없는 상태)
	end
end

-- ==================== 실시간 점수 동기화 ====================

-- 2.5초마다 매칭된 플레이어 간 점수 공유
local lastSyncTime = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastSyncTime < SCORE_SYNC_INTERVAL then
		return
	end
	lastSyncTime = now

	for player, match in _matches do
		if not player.Parent then
			continue
		end
		if match.myFinalScore then
			continue
		end -- 이미 게임 끝남

		local myScore = getCurrentScore(player)

		if not match.isBot then
			-- 인간 상대에게 내 점수 전송
			local opponentPlayer = match.opponentPlayer
			if opponentPlayer and opponentPlayer.Parent then
				RemoteEvents.BattleOpponentScore:FireClient(opponentPlayer, {
					score = myScore,
					opponentName = player.Name,
				})
			end
		else
			-- 봇 점수 시뮬레이션
			local elapsed = math.min(now - match.matchStartTime, 180)
			local botScore = math.min(
				match.botTargetScore or 800,
				math.floor(elapsed * 11)
			)
			RemoteEvents.BattleOpponentScore:FireClient(player, {
				score = botScore,
				opponentName = match.opponentName,
			})
		end
	end
end)

-- ==================== 이벤트 연결 ====================

function RealtimeBattleService:SetupRemoteEvents()
	RemoteEvents.BattleQueueEnter.OnServerEvent:Connect(function(player: Player)
		if not RateLimiter.Check(player, "BattleQueueEnter", 5) then
			return
		end
		self:EnterQueue(player)
	end)

	RemoteEvents.BattleQueueLeave.OnServerEvent:Connect(function(player: Player)
		if not RateLimiter.Check(player, "BattleQueueLeave", 5) then
			return
		end
		self:LeaveQueue(player)
	end)

	print("[RealtimeBattleService] Remote events connected")
end

-- 플레이어 퇴장 정리
Players.PlayerRemoving:Connect(function(player: Player)
	removeFromQueue(player)
	local match = _matches[player]
	if match and not match.isBot and match.opponentPlayer then
		-- 상대에게 승리 처리
		local opponent = match.opponentPlayer
		if opponent.Parent then
			local opponentMatch = _matches[opponent]
			if opponentMatch and not opponentMatch.myFinalScore then
				local reward = WIN_REWARD_GEMS
				PlayerDataService:AddGems(opponent, reward)
				RemoteEvents.GemsUpdated:FireClient(opponent, { gems = PlayerDataService:GetGems(opponent) })
				RemoteEvents.BattleResult:FireClient(opponent, {
					won = true,
					myScore = getCurrentScore(opponent),
					opponentScore = 0,
					opponentName = player.Name,
					reward = reward,
				})
				_matches[opponent] = nil
			end
		end
	end
	_matches[player] = nil
end)

print("[RealtimeBattleService] Initialized")

return RealtimeBattleService

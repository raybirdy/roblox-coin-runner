--!strict
-- ScenarioService
-- 시나리오 시스템 서버 로직: 퀘스트 추적, 챕터 해금, 스탯 보너스 계산

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScenarioConstants = require(ReplicatedStorage.Shared.Constants.ScenarioConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local BossRunService = require(script.Parent.BossRunService)

local ScenarioService = {}

-- ==================== 타입 ====================

type StatBonuses = {
	speed: number,
	jump: number,
	coinValue: number,
	magnetRadius: number,
	maxLives: number,
	feverGauge: number,
}

-- ==================== 퀘스트 진행 업데이트 ====================

-- 퀘스트 진행 업데이트 (GameManager에서 게임 종료 시 호출)
-- questType: "play_games" | "score_reach" | "collect_coins" | "near_miss" |
--            "combo_ch" | "distance_ch" | "survive_ch" | "powerup_ch" | "no_hit_run_ch"
-- amount: 해당 값 (점수, 개수, 거리 등)
function ScenarioService:UpdateQuestProgress(player: Player, questType: string, amount: number)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	local questProgress = playerData.scenarioQuestProgress :: { [string]: number }
	local completedChapters = playerData.completedChapters :: { string }
	local trackingMode = ScenarioConstants.QUEST_TRACKING_MODE[questType]
	if not trackingMode then
		return
	end

	-- 완료된 챕터 셋 (O(1) 조회용)
	local completedSet: { [string]: boolean } = {}
	for _, chId in completedChapters do
		completedSet[chId] = true
	end

	local changed = false
	local newlyCompletedQuests: { string } = {}

	-- 현재 진행 가능한 챕터의 해당 타입 퀘스트만 업데이트
	for _, chapter in ScenarioConstants.CHAPTERS do
		-- 이미 완료된 챕터는 건너뜀
		if completedSet[chapter.id] then
			continue
		end

		-- 챕터가 해금되지 않았으면 건너뜀
		if not self:_isChapterUnlocked(chapter, completedSet, playerData.highScore) then
			continue
		end

		for _, questId in chapter.questIds do
			local quest = ScenarioConstants.QUESTS[questId]
			if not quest or quest.type ~= questType then
				continue
			end

			local current = questProgress[questId] or 0
			if current >= quest.target then
				continue -- 이미 완료된 퀘스트
			end

			local newProgress = current
			if trackingMode == "accumulate" then
				newProgress = current + amount
			elseif trackingMode == "highwater" then
				newProgress = math.max(current, amount)
			end
			newProgress = math.min(newProgress, quest.target)

			if newProgress ~= current then
				questProgress[questId] = newProgress
				changed = true

				if newProgress >= quest.target then
					table.insert(newlyCompletedQuests, questId)
					print(`[ScenarioService] {player.Name} completed quest: {questId}`)
				end
			end
		end
	end

	-- 점수 등 조건 충족으로 새로 해금된 챕터 오프닝 체크
	-- changed 여부와 무관하게 실행 (highScore는 외부에서 갱신되므로)
	self:_checkAndNotifyUnlockedChapters(player, playerData)

	-- 챕터 완료 체크: 퀘스트 변경 없어도 매번 실행
	-- (퀘스트가 이미 완료된 상태에서 보스런 미완료 → 재트리거 필요)
	self:_checkChapterCompletion(player, playerData)

	if not changed then
		return
	end

	-- 퀘스트 완료 보상 지급
	for _, questId in newlyCompletedQuests do
		self:_grantQuestReward(player, questId, playerData)

		-- 퀘스트 완료 알림
		RemoteEvents.QuestCompleted:FireClient(player, {
			questId = questId,
			questName = ScenarioConstants.QUESTS[questId].name,
		})
	end

	-- 챕터 완료 체크
	self:_checkChapterCompletion(player, playerData)

	-- 클라이언트에 최신 데이터 전송
	self:_fireScenarioUpdate(player, playerData)
end

-- ==================== 내부 함수 ====================

-- 챕터 해금 조건 확인
function ScenarioService:_isChapterUnlocked(
	chapter: typeof(ScenarioConstants.CHAPTERS[1]),
	completedSet: { [string]: boolean },
	highScore: number
): boolean
	local cond = chapter.unlockConditions

	-- 점수 조건
	if highScore < cond.minScore then
		return false
	end

	-- 이전 챕터 완료 조건
	for _, requiredChId in cond.requiredCompletedChapters do
		if not completedSet[requiredChId] then
			return false
		end
	end

	return true
end

-- 챕터 완료 여부 확인 및 처리
function ScenarioService:_checkChapterCompletion(player: Player, playerData: any)
	local questProgress = playerData.scenarioQuestProgress :: { [string]: number }
	local completedChapters = playerData.completedChapters :: { string }

	local completedSet: { [string]: boolean } = {}
	for _, chId in completedChapters do
		completedSet[chId] = true
	end

	for _, chapter in ScenarioConstants.CHAPTERS do
		if completedSet[chapter.id] then
			continue
		end
		if not self:_isChapterUnlocked(chapter, completedSet, playerData.highScore) then
			continue
		end

		-- 챕터 내 모든 퀘스트 완료 여부 확인
		local allDone = true
		for _, questId in chapter.questIds do
			local quest = ScenarioConstants.QUESTS[questId]
			if not quest then
				continue
			end
			local progress = questProgress[questId] or 0
			if progress < quest.target then
				allDone = false
				break
			end
		end

		if allDone then
			-- 보스 런 클리어 여부 확인
			local bossRunCompleted = playerData.bossRunCompleted :: { [string]: boolean }?
			local bossCleared = bossRunCompleted and bossRunCompleted[chapter.id]

			if bossCleared then
				-- 보스 런 이미 완료 → 챕터 완료 처리
				self:_completeChapter(player, chapter, playerData, completedChapters, completedSet)
			else
				-- 보스 런 아직 미완료: 이미 활성화된 세션이 없을 때만 시작
				if not BossRunService:IsBossRunActive(player) then
					RemoteEvents.ChapterUnlocked:FireClient(player, {
						chapterId = chapter.id,
						chapterName = chapter.name,
						chapterTheme = chapter.theme,
						cutscene = ScenarioConstants.CUTSCENES[chapter.id]
							and ScenarioConstants.CUTSCENES[chapter.id].clear,
						bossRunReady = true,
					})
					task.delay(0.5, function()
						BossRunService:StartBossRun(player, chapter.id)
					end)
				end
			end
		end
	end
end

-- 챕터 완료 처리 (보스 런 클리어 후 or 보스 런 없는 챕터)
function ScenarioService:_completeChapter(
	player: Player,
	chapter: typeof(ScenarioConstants.CHAPTERS[1]),
	playerData: any,
	completedChapters: { string },
	completedSet: { [string]: boolean }
)
	table.insert(completedChapters, chapter.id)
	completedSet[chapter.id] = true
	print(`[ScenarioService] {player.Name} completed chapter: {chapter.id}`)

	-- 스킬 해금
	if chapter.skill then
		local unlockedSkills = playerData.unlockedSkills :: { string }
		local alreadyHas = false
		for _, skillId in unlockedSkills do
			if skillId == chapter.skill then
				alreadyHas = true
				break
			end
		end
		if not alreadyHas then
			table.insert(unlockedSkills, chapter.skill)
			print(`[ScenarioService] {player.Name} unlocked skill: {chapter.skill}`)
		end
	end

	-- 챕터 클리어 보상 (젬, XP)
	self:_grantChapterReward(player, chapter, playerData)

	-- 챕터 해금 알림 (컷씬 포함)
	RemoteEvents.ChapterUnlocked:FireClient(player, {
		chapterId = chapter.id,
		chapterName = chapter.name,
		chapterTheme = chapter.theme,
		skillUnlocked = chapter.skill,
		statBonus = chapter.statBonus,
		cutscene = ScenarioConstants.CUTSCENES[chapter.id] and ScenarioConstants.CUTSCENES[chapter.id].clear,
		chapterReward = chapter.chapterReward,
	})

	-- 다음 챕터 해금 알림 — _checkAndNotifyUnlockedChapters가 중복 방지 포함하여 처리
	self:_checkAndNotifyUnlockedChapters(player, playerData)

	-- 클라이언트에 최신 데이터 전송
	self:_fireScenarioUpdate(player, playerData)
end

-- 보스 런 클리어 후 챕터 완료 트리거 (BossRunService에서 호출)
function ScenarioService:TriggerChapterCompletion(player: Player, chapterId: string)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	local completedChapters = playerData.completedChapters :: { string }
	local completedSet: { [string]: boolean } = {}
	for _, chId in completedChapters do
		completedSet[chId] = true
	end

	-- 이미 완료된 챕터면 스킵
	if completedSet[chapterId] then
		return
	end

	-- 챕터 찾기
	for _, chapter in ScenarioConstants.CHAPTERS do
		if chapter.id == chapterId then
			self:_completeChapter(player, chapter, playerData, completedChapters, completedSet)
			break
		end
	end
end

-- 새로 해금된 챕터 오프닝 알림 (중복 방지 포함)
-- UpdateQuestProgress, _completeChapter, OnScenarioDataRequest에서 호출
function ScenarioService:_checkAndNotifyUnlockedChapters(player: Player, playerData: any)
	-- 레거시 데이터 마이그레이션: chapterOpeningsSent 필드가 없는 기존 유저 대응
	if not playerData.chapterOpeningsSent then
		playerData.chapterOpeningsSent = {}
		-- 이미 완료된 챕터는 오프닝을 봤다고 처리
		local existing = playerData.completedChapters :: { string }
		for _, chId in existing do
			playerData.chapterOpeningsSent[chId] = true
		end
		-- ch1은 hasSeenCh1Opening으로 관리
		if playerData.hasSeenCh1Opening then
			playerData.chapterOpeningsSent["ch1"] = true
		end
	end

	local completedChapters = playerData.completedChapters :: { string }
	local completedSet: { [string]: boolean } = {}
	for _, chId in completedChapters do
		completedSet[chId] = true
	end

	local sent = playerData.chapterOpeningsSent :: { [string]: boolean }

	for _, chapter in ScenarioConstants.CHAPTERS do
		if chapter.num == 1 then
			continue -- ch1은 hasSeenCh1Opening으로 별도 관리
		end
		if completedSet[chapter.id] then
			continue -- 완료된 챕터 스킵
		end
		if sent[chapter.id] then
			continue -- 이미 오프닝 발송됨
		end
		if self:_isChapterUnlocked(chapter, completedSet, playerData.highScore) then
			sent[chapter.id] = true
			local opening = ScenarioConstants.CUTSCENES[chapter.id] and ScenarioConstants.CUTSCENES[chapter.id].opening
			RemoteEvents.ChapterUnlocked:FireClient(player, {
				chapterId = chapter.id,
				chapterName = chapter.name,
				chapterTheme = chapter.theme,
				cutscene = opening,
				isOpening = true,
			})
			print(`[ScenarioService] {player.Name} unlocked chapter opening: {chapter.id}`)
		end
	end
end

-- 퀘스트 완료 보상 지급
function ScenarioService:_grantQuestReward(player: Player, questId: string, playerData: any)
	local quest = ScenarioConstants.QUESTS[questId]
	if not quest then
		return
	end
	local reward = quest.reward
	if reward.xp and reward.xp > 0 then
		playerData.xp = (playerData.xp or 0) + reward.xp
	end
	if reward.coins and reward.coins > 0 then
		playerData.coins = (playerData.coins or 0) + reward.coins
	end
end

-- 챕터 완료 보상 지급
function ScenarioService:_grantChapterReward(
	player: Player,
	chapter: typeof(ScenarioConstants.CHAPTERS[1]),
	playerData: any
)
	local reward = chapter.chapterReward
	if reward.gems and reward.gems > 0 then
		playerData.gems = (playerData.gems or 0) + reward.gems
		RemoteEvents.GemsUpdated:FireClient(player, { gems = playerData.gems })
	end
	if reward.xp and reward.xp > 0 then
		playerData.xp = (playerData.xp or 0) + reward.xp
	end
end

-- 클라이언트에 시나리오 업데이트 전송 (퀘스트 진행도 변경 시)
function ScenarioService:_fireScenarioUpdate(player: Player, playerData: any)
	RemoteEvents.QuestProgressUpdate:FireClient(player, {
		questProgress = playerData.scenarioQuestProgress,
		completedChapters = playerData.completedChapters,
		unlockedSkills = playerData.unlockedSkills,
	})
end

-- ==================== 스탯 보너스 계산 ====================

-- 완료된 챕터 기반으로 누적 스탯 보너스 계산
function ScenarioService:GetStatBonuses(player: Player): StatBonuses
	local bonuses: StatBonuses = {
		speed = 0,
		jump = 0,
		coinValue = 0,
		magnetRadius = 0,
		maxLives = 0,
		feverGauge = 0,
	}

	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return bonuses
	end

	local completedChapters = playerData.completedChapters :: { string }
	local completedSet: { [string]: boolean } = {}
	for _, chId in completedChapters do
		completedSet[chId] = true
	end

	for _, chapter in ScenarioConstants.CHAPTERS do
		if not completedSet[chapter.id] then
			continue
		end
		local stat = chapter.statBonus
		bonuses.speed += stat.speed or 0
		bonuses.jump += stat.jump or 0
		bonuses.coinValue += stat.coinValue or 0
		bonuses.magnetRadius += stat.magnetRadius or 0
		bonuses.maxLives += stat.maxLives or 0
		bonuses.feverGauge += stat.feverGauge or 0
	end

	-- 상한선 적용
	local caps = ScenarioConstants.STAT_BONUS_CAPS
	bonuses.speed = math.min(bonuses.speed, caps.speed)
	bonuses.jump = math.min(bonuses.jump, caps.jump)
	bonuses.coinValue = math.min(bonuses.coinValue, caps.coinValue)
	bonuses.magnetRadius = math.min(bonuses.magnetRadius, caps.magnetRadius)
	bonuses.maxLives = math.min(bonuses.maxLives, caps.maxLives)
	bonuses.feverGauge = math.min(bonuses.feverGauge, caps.feverGauge)

	return bonuses
end

-- 해금된 스킬 목록 반환
function ScenarioService:GetUnlockedSkills(player: Player): { string }
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return {}
	end
	return playerData.unlockedSkills :: { string }
end

-- 플레이어의 현재 활성 챕터 ID 반환 (완료하지 않은 첫 번째 해금된 챕터)
function ScenarioService:GetActiveChapterId(player: Player): string?
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return nil
	end

	local completedChapters = playerData.completedChapters :: { string }
	local completedSet: { [string]: boolean } = {}
	for _, chId in completedChapters do
		completedSet[chId] = true
	end

	for _, chapter in ScenarioConstants.CHAPTERS do
		if completedSet[chapter.id] then
			continue
		end
		if self:_isChapterUnlocked(chapter, completedSet, playerData.highScore) then
			return chapter.id
		end
	end

	return nil
end

-- ==================== 클라이언트 데이터 요청 처리 ====================

-- 클라이언트가 ScenarioDataRequest 이벤트를 보냈을 때 전체 데이터 반환
function ScenarioService:OnScenarioDataRequest(player: Player)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	-- 챕터별 퀘스트 진행 상황 정리
	local questProgress = playerData.scenarioQuestProgress :: { [string]: number }
	local completedChapters = playerData.completedChapters :: { string }
	local unlockedSkills = playerData.unlockedSkills :: { string }

	local completedSet: { [string]: boolean } = {}
	for _, chId in completedChapters do
		completedSet[chId] = true
	end

	-- 각 챕터의 해금 여부 포함
	local chapterData = {}
	for _, chapter in ScenarioConstants.CHAPTERS do
		local isUnlocked = self:_isChapterUnlocked(chapter, completedSet, playerData.highScore)
		local isCompleted = completedSet[chapter.id] == true

		local quests = {}
		for _, questId in chapter.questIds do
			local quest = ScenarioConstants.QUESTS[questId]
			if quest then
				table.insert(quests, {
					id = questId,
					name = quest.name,
					desc = quest.desc,
					type = quest.type,
					target = quest.target,
					progress = questProgress[questId] or 0,
					completed = (questProgress[questId] or 0) >= quest.target,
					reward = quest.reward,
				})
			end
		end

		table.insert(chapterData, {
			id = chapter.id,
			num = chapter.num,
			name = chapter.name,
			theme = chapter.theme,
			description = chapter.description,
			isUnlocked = isUnlocked,
			isCompleted = isCompleted,
			skill = chapter.skill,
			statBonus = chapter.statBonus,
			chapterReward = chapter.chapterReward,
			quests = quests,
		})
	end

	RemoteEvents.ScenarioDataResponse:FireClient(player, {
		chapters = chapterData,
		completedChapters = completedChapters,
		unlockedSkills = unlockedSkills,
		statBonuses = self:GetStatBonuses(player),
	})

	-- 로그인 시 캐치업: 오프닝 컷씬을 아직 못 본 챕터가 있으면 발송
	task.delay(3, function()
		self:_checkAndNotifyUnlockedChapters(player, playerData)
	end)

	-- 기존 유저 중 ch1 오프닝을 못 본 경우:
	-- hasSeenScenarioIntro=true (인트로 팝업을 이미 봤으므로 ScenarioIntroSeen 경로 불가)
	-- hasSeenCh1Opening=false (아직 ch1 오프닝 컷씬 미시청)
	-- → 최초 데이터 요청 시 1회 발송 (이후 flag=true로 방지)
	if playerData.hasSeenScenarioIntro == true and not playerData.hasSeenCh1Opening then
		playerData.hasSeenCh1Opening = true
		local ch1 = ScenarioConstants.CHAPTERS[1]
		local ch1Opening = ScenarioConstants.CUTSCENES["ch1"] and ScenarioConstants.CUTSCENES["ch1"].opening
		if ch1 and ch1Opening then
			task.delay(3, function()
				RemoteEvents.ChapterUnlocked:FireClient(player, {
					chapterId = ch1.id,
					chapterName = ch1.name,
					chapterTheme = ch1.theme,
					cutscene = ch1Opening,
					isOpening = true,
				})
			end)
		end
	end
end

-- ==================== 원격 이벤트 연결 ====================

function ScenarioService:SetupRemoteEvents()
	RemoteEvents.ScenarioDataRequest.OnServerEvent:Connect(function(player: Player)
		self:OnScenarioDataRequest(player)
	end)

	RemoteEvents.ScenarioIntroSeen.OnServerEvent:Connect(function(player: Player)
		PlayerDataService:MarkScenarioIntroSeen(player)

		-- 인트로 팝업 확인 직후 ch1 오프닝 컷씬 발송 (신규 유저 경로, 최초 1회)
		local playerData = PlayerDataService:GetPlayerData(player)
		if playerData and not playerData.hasSeenCh1Opening then
			playerData.hasSeenCh1Opening = true
			local ch1 = ScenarioConstants.CHAPTERS[1]
			local ch1Opening = ScenarioConstants.CUTSCENES["ch1"] and ScenarioConstants.CUTSCENES["ch1"].opening
			if ch1 and ch1Opening then
				RemoteEvents.ChapterUnlocked:FireClient(player, {
					chapterId = ch1.id,
					chapterName = ch1.name,
					chapterTheme = ch1.theme,
					cutscene = ch1Opening,
					isOpening = true,
				})
			end
		end
	end)

	print("[ScenarioService] Remote events connected")
end

return ScenarioService

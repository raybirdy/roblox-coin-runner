--!strict
-- RemoteEvents
-- 클라이언트-서버 통신을 위한 RemoteEvent/RemoteFunction 정의

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = {}

-- RemoteEvents 폴더 생성
local remoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage
end

-- 함수: RemoteEvent 생성 또는 가져오기
local function getOrCreateRemoteEvent(name: string): RemoteEvent
	local remote = remoteFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remoteFolder
	end
	return remote :: RemoteEvent
end

-- 코인 수집
RemoteEvents.CoinCollected = getOrCreateRemoteEvent("CoinCollected")
-- 클라이언트 → 서버: 코인 수집 요청
-- 파라미터: (coinInstance: BasePart)

-- 장애물 충돌
RemoteEvents.ObstacleHit = getOrCreateRemoteEvent("ObstacleHit")
-- 클라이언트 → 서버: 장애물 충돌 알림
-- 파라미터: (obstacleInstance: BasePart)

-- 파워업 획득
RemoteEvents.PowerupCollected = getOrCreateRemoteEvent("PowerupCollected")
-- 클라이언트 → 서버: 파워업 획득 요청
-- 파라미터: (powerupType: string, powerupInstance: BasePart)

-- 게임 시작
RemoteEvents.GameStart = getOrCreateRemoteEvent("GameStart")
-- 클라이언트 → 서버: 게임 시작 요청
-- 서버 → 클라이언트: 게임 시작 승인 및 초기 데이터

-- 게임 오버
RemoteEvents.GameOver = getOrCreateRemoteEvent("GameOver")
-- 클라이언트 → 서버: 게임 오버 알림
-- 서버 → 클라이언트: 최종 점수, 획득 코인 등

-- 부활
RemoteEvents.Revive = getOrCreateRemoteEvent("Revive")
-- 클라이언트 → 서버: 부활 요청
-- 서버 → 클라이언트: 부활 승인/거부

-- 점수 업데이트
RemoteEvents.ScoreUpdate = getOrCreateRemoteEvent("ScoreUpdate")
-- 서버 → 클라이언트: 점수 변경 알림
-- 파라미터: (totalScore: number, reason: string)

-- 라이프 업데이트
RemoteEvents.LifeUpdate = getOrCreateRemoteEvent("LifeUpdate")
-- 서버 → 클라이언트: 라이프 변경 알림
-- 파라미터: (currentLives: number)

-- 플레이어 데이터 로드
RemoteEvents.PlayerDataLoaded = getOrCreateRemoteEvent("PlayerDataLoaded")
-- 서버 → 클라이언트: 플레이어 데이터 로드 완료
-- 파라미터: (playerData: table)

-- 플레이어 데이터 요청 (클라이언트 초기화 완료 후)
RemoteEvents.PlayerDataRequest = getOrCreateRemoteEvent("PlayerDataRequest")
-- 클라이언트 → 서버: 초기 데이터 요청

-- 튜토리얼 시작
RemoteEvents.TutorialStart = getOrCreateRemoteEvent("TutorialStart")
-- 클라이언트 → 서버: 튜토리얼 시작 알림

-- 튜토리얼 종료
RemoteEvents.TutorialEnd = getOrCreateRemoteEvent("TutorialEnd")
-- 클라이언트 → 서버: 튜토리얼 종료 알림

-- 튜토리얼 모드
RemoteEvents.TutorialMode = getOrCreateRemoteEvent("TutorialMode")
-- 서버 → 클라이언트: 튜토리얼 모드 전환 (슬로모션)
-- 파라미터: { active: boolean, speedMultiplier: number }

-- 튜토리얼 완료
RemoteEvents.TutorialCompleted = getOrCreateRemoteEvent("TutorialCompleted")
-- 클라이언트 → 서버: 튜토리얼 완료 알림

-- 청크 생성 (디버깅/테스트용)
RemoteEvents.ChunkSpawned = getOrCreateRemoteEvent("ChunkSpawned")
-- 서버 → 클라이언트: 새 청크 생성 알림 (필요 시)

-- NPC 등장
RemoteEvents.NPCAppeared = getOrCreateRemoteEvent("NPCAppeared")
-- 서버 → 클라이언트: NPC 등장 알림
-- 파라미터: (npcType: string, npcPosition: Vector3, npcInstance: Model)

-- NPC 상호작용
RemoteEvents.NPCInteraction = getOrCreateRemoteEvent("NPCInteraction")
-- 클라이언트 → 서버: NPC 상호작용 요청 (향후 확장용)

-- 로비 포탈 진입
RemoteEvents.PortalEnter = getOrCreateRemoteEvent("PortalEnter")
-- 클라이언트 → 서버: 포탈 진입 요청 (게임 시작)

-- 상점 열기
RemoteEvents.ShopOpen = getOrCreateRemoteEvent("ShopOpen")
-- 클라이언트 → 서버: 상점 UI 열기 요청

-- 상점 구매
RemoteEvents.ShopPurchase = getOrCreateRemoteEvent("ShopPurchase")
-- 클라이언트 → 서버: 아이템 구매 요청
-- 파라미터: { itemType: string, itemId: string }

-- 상점 구매 결과
RemoteEvents.ShopPurchaseResult = getOrCreateRemoteEvent("ShopPurchaseResult")
-- 서버 → 클라이언트: 구매 결과 알림
-- 파라미터: { success: boolean, itemType: string, itemId: string, newBalance: number, error: string? }

-- 스킨 장착
RemoteEvents.EquipSkin = getOrCreateRemoteEvent("EquipSkin")
-- 클라이언트 → 서버: 스킨 장착 요청
-- 파라미터: { skinId: string }

-- 시작 파워업 사용
RemoteEvents.UseStartPowerup = getOrCreateRemoteEvent("UseStartPowerup")
-- 클라이언트 → 서버: 시작 파워업 사용 요청
-- 파라미터: { powerupId: string }

-- 로비 복귀
RemoteEvents.ReturnToLobby = getOrCreateRemoteEvent("ReturnToLobby")
-- 서버 → 클라이언트: 로비로 복귀 알림

-- 리더보드 요청
RemoteEvents.LeaderboardRequest = getOrCreateRemoteEvent("LeaderboardRequest")
-- 클라이언트 → 서버: 리더보드 데이터 요청

-- 리더보드 데이터
RemoteEvents.LeaderboardData = getOrCreateRemoteEvent("LeaderboardData")
-- 서버 → 클라이언트: 리더보드 데이터 전송
-- 파라미터: { leaderboard: {{rank, name, score}}, playerRank: number? }

-- ==================== 수익화 시스템 ====================

-- 젬 구매 요청 (Robux → 젬)
RemoteEvents.PurchaseGems = getOrCreateRemoteEvent("PurchaseGems")
-- 클라이언트 → 서버: 젬 패키지 구매 요청
-- 파라미터: { productId: string } (e.g., "gems_50", "gems_200")

-- 젬 구매 결과
RemoteEvents.PurchaseGemsResult = getOrCreateRemoteEvent("PurchaseGemsResult")
-- 서버 → 클라이언트: 젬 구매 결과 알림
-- 파라미터: { success: boolean, gems: number?, error: string? }

-- VIP 상태 변경
RemoteEvents.VIPStatusChanged = getOrCreateRemoteEvent("VIPStatusChanged")
-- 서버 → 클라이언트: VIP 상태 변경 알림
-- 파라미터: { hasVIP: boolean }

-- 젬 잔액 업데이트
RemoteEvents.GemsUpdated = getOrCreateRemoteEvent("GemsUpdated")
-- 서버 → 클라이언트: 젬 잔액 변경 알림
-- 파라미터: { gems: number }

-- 상점 데이터 요청
RemoteEvents.ShopDataRequest = getOrCreateRemoteEvent("ShopDataRequest")
-- 클라이언트 → 서버: 상점 전체 데이터 요청

-- 상점 데이터 응답
RemoteEvents.ShopDataResponse = getOrCreateRemoteEvent("ShopDataResponse")
-- 서버 → 클라이언트: 상점 전체 데이터 전송
-- 파라미터: { skins, startPowerups, reviveTickets, gemProducts }

-- ==================== 게임플레이 피드백 ====================

-- 니어미스 (장애물 근접 회피)
RemoteEvents.NearMiss = getOrCreateRemoteEvent("NearMiss")
-- 서버 → 클라이언트: 니어미스 알림
-- 파라미터: { bonus: number }

-- 콤보 업데이트
RemoteEvents.ComboUpdate = getOrCreateRemoteEvent("ComboUpdate")
-- 서버 → 클라이언트: 콤보 상태 알림
-- 파라미터: { combo: number, bonus: number? }

-- 위로 보상
RemoteEvents.ConsolationReward = getOrCreateRemoteEvent("ConsolationReward")
-- 서버 → 클라이언트: 위로 보상 알림
-- 파라미터: { coins: number }

-- ==================== 진행도 시스템 ====================

-- 레벨업 알림
RemoteEvents.LevelUp = getOrCreateRemoteEvent("LevelUp")
-- 서버 → 클라이언트: 레벨업 알림
-- 파라미터: { newLevel: number, rewards: { coins: number, gems: number? } }

-- XP 획득 알림
RemoteEvents.XPGained = getOrCreateRemoteEvent("XPGained")
-- 서버 → 클라이언트: XP 획득 알림
-- 파라미터: { xp: number, totalXP: number, level: number, xpToNext: number }

-- 일일 미션 업데이트
RemoteEvents.MissionUpdate = getOrCreateRemoteEvent("MissionUpdate")
-- 서버 → 클라이언트: 미션 진행도/완료 알림
-- 파라미터: { missions: { { id, name, desc, target, progress, completed, reward } } }

-- 업적 달성 알림
RemoteEvents.AchievementUnlocked = getOrCreateRemoteEvent("AchievementUnlocked")
-- 서버 → 클라이언트: 업적 달성 알림
-- 파라미터: { id: string, name: string, desc: string, rewardGems: number, rewardXP: number }

-- 진행도 데이터 요청
RemoteEvents.ProgressionDataRequest = getOrCreateRemoteEvent("ProgressionDataRequest")
-- 클라이언트 → 서버: 전체 진행도 데이터 요청

-- 진행도 데이터 응답
RemoteEvents.ProgressionDataResponse = getOrCreateRemoteEvent("ProgressionDataResponse")
-- 서버 → 클라이언트: 전체 진행도 데이터 전송
-- 파라미터: { level, xp, xpToNext, missions, achievements }

-- ==================== Phase 2: 리텐션 시스템 ====================

-- 일일 출석 보상
RemoteEvents.LoginRewardClaim = getOrCreateRemoteEvent("LoginRewardClaim")
-- 클라이언트 → 서버: 출석 보상 수령 요청

RemoteEvents.LoginRewardData = getOrCreateRemoteEvent("LoginRewardData")
-- 서버 → 클라이언트: 출석 보상 정보 전송
-- 파라미터: { loginStreak, rewardDay, reward, multiplier, alreadyClaimed }

-- 럭키 스핀
RemoteEvents.SpinRequest = getOrCreateRemoteEvent("SpinRequest")
-- 클라이언트 → 서버: 스핀 요청
-- 파라미터: { useGems: boolean }

RemoteEvents.SpinResult = getOrCreateRemoteEvent("SpinResult")
-- 서버 → 클라이언트: 스핀 결과
-- 파라미터: { rewardId, rewardName, type, amount, freeSpinsLeft }

-- 신기록 임박 알림
RemoteEvents.NearRecordAlert = getOrCreateRemoteEvent("NearRecordAlert")
-- 서버 → 클라이언트: 신기록 임박 알림
-- 파라미터: { currentScore, highScore }

RemoteEvents.NewRecordCelebration = getOrCreateRemoteEvent("NewRecordCelebration")
-- 서버 → 클라이언트: 신기록 달성 축하
-- 파라미터: { newRecord: number }

-- ==================== Phase 2: 게임성 개선 ====================

-- 피버 모드 시작
RemoteEvents.FeverStart = getOrCreateRemoteEvent("FeverStart")
-- 서버 → 클라이언트: 피버 모드 발동 알림
-- 파라미터: { duration: number, speedBoost: number }

-- 피버 모드 종료
RemoteEvents.FeverEnd = getOrCreateRemoteEvent("FeverEnd")
-- 서버 → 클라이언트: 피버 모드 종료 알림

-- 피버 게이지 업데이트
RemoteEvents.FeverGaugeUpdate = getOrCreateRemoteEvent("FeverGaugeUpdate")
-- 서버 → 클라이언트: 피버 게이지 진행도 알림
-- 파라미터: { combo: number, threshold: number, onCooldown: boolean }

-- 니어미스 체인 (강화된 니어미스)
RemoteEvents.NearMissChain = getOrCreateRemoteEvent("NearMissChain")
-- 서버 → 클라이언트: 니어미스 체인 알림
-- 파라미터: { chain: number, bonus: number, text: string }

-- 퍼펙트 런 보너스
RemoteEvents.PerfectRunBonus = getOrCreateRemoteEvent("PerfectRunBonus")
-- 서버 → 클라이언트: 무피격 보너스 알림
-- 파라미터: { distance: number, bonus: number, title: string }

-- ==================== Phase B: 게임성 다양화 ====================

-- Zone 전환
RemoteEvents.ZoneTransition = getOrCreateRemoteEvent("ZoneTransition")
-- 서버 → 클라이언트: 구간 전환 알림
-- 파라미터: { zoneIndex: number, zoneName: string, displayName: string }

-- 이벤트 청크 알림
RemoteEvents.EventChunkAlert = getOrCreateRemoteEvent("EventChunkAlert")
-- 서버 → 클라이언트: 이벤트 청크 등장 알림
-- 파라미터: { eventType: string } ("CoinRush" | "GiantCoin")

-- 거인 코인 수집
RemoteEvents.GiantCoinCollected = getOrCreateRemoteEvent("GiantCoinCollected")
-- 서버 → 클라이언트: 거인 코인 수집 알림
-- 파라미터: { reward: number }

-- ==================== 시나리오 시스템 ====================

-- 시나리오 데이터 요청
RemoteEvents.ScenarioDataRequest = getOrCreateRemoteEvent("ScenarioDataRequest")
-- 클라이언트 → 서버: 전체 시나리오 데이터 요청

-- 시나리오 데이터 응답
RemoteEvents.ScenarioDataResponse = getOrCreateRemoteEvent("ScenarioDataResponse")
-- 서버 → 클라이언트: 챕터/퀘스트/스킬/스탯보너스 전체 데이터 전송
-- 파라미터: { chapters, completedChapters, unlockedSkills, statBonuses }

-- 퀘스트 진행도 실시간 업데이트
RemoteEvents.QuestProgressUpdate = getOrCreateRemoteEvent("QuestProgressUpdate")
-- 서버 → 클라이언트: 퀘스트 진행도 변경 알림
-- 파라미터: { questProgress: { [questId]: number }, completedChapters, unlockedSkills }

-- 퀘스트 완료 알림
RemoteEvents.QuestCompleted = getOrCreateRemoteEvent("QuestCompleted")
-- 서버 → 클라이언트: 퀘스트 완료 알림 (토스트 알림용)
-- 파라미터: { questId: string, questName: string }

-- 챕터 해금 알림
RemoteEvents.ChapterUnlocked = getOrCreateRemoteEvent("ChapterUnlocked")
-- 서버 → 클라이언트: 챕터 완료/해금 알림 (컷씬 포함)
-- 파라미터: { chapterId, chapterName, chapterTheme, skillUnlocked?, statBonus?, cutscene?, chapterReward?, isOpening? }

-- 시나리오 인트로 확인 (클라이언트 → 서버)
RemoteEvents.ScenarioIntroSeen = getOrCreateRemoteEvent("ScenarioIntroSeen")
-- 파라미터: 없음. 인트로 팝업을 닫을 때 1회 전송

-- ==================== 보스 런 ====================

-- 보스 런 시작 (서버 → 클라이언트)
RemoteEvents.BossRunStart = getOrCreateRemoteEvent("BossRunStart")
-- 파라미터: { chapterId, bossName, targetScore, timeLimit, speedMultiplier, lives, cutscene? }

-- 보스 런 점수 업데이트 (서버 → 클라이언트)
RemoteEvents.BossRunScoreUpdate = getOrCreateRemoteEvent("BossRunScoreUpdate")
-- 파라미터: { playerScore, bossScore, timeRemaining }

-- 보스 런 결과 (서버 → 클라이언트)
RemoteEvents.BossRunResult = getOrCreateRemoteEvent("BossRunResult")
-- 파라미터: { success, playerScore, targetScore, chapterId, rewards?, cutscene? }

-- 보스 런 재도전 요청 (클라이언트 → 서버)
RemoteEvents.BossRunRetry = getOrCreateRemoteEvent("BossRunRetry")
-- 파라미터: { chapterId }

-- 보스 런 포기 (클라이언트 → 서버)
RemoteEvents.BossRunGiveUp = getOrCreateRemoteEvent("BossRunGiveUp")

-- ==================== 주간 랭킹 ====================

-- 주간 랭크 업데이트 (서버 → 클라이언트)
RemoteEvents.WeeklyRankUpdate = getOrCreateRemoteEvent("WeeklyRankUpdate")
-- 파라미터: { weeklyRank: number?, topPlayers: {{rank,name,score}}, rewardTiers: {{maxRank,gems}} }

-- ==================== 스킬 시스템 ====================

-- 스킬 발동 요청 (클라이언트 → 서버)
RemoteEvents.SkillActivate = getOrCreateRemoteEvent("SkillActivate")
-- 파라미터: { skillId: string }

-- 스킬 발동 확인 (서버 → 클라이언트)
RemoteEvents.SkillActivated = getOrCreateRemoteEvent("SkillActivated")
-- 파라미터: { skillId: string, value: number? }

-- 쉴드 자동 재생 알림 (서버 → 클라이언트)
RemoteEvents.ShieldRegenerated = getOrCreateRemoteEvent("ShieldRegenerated")
-- 파라미터: (없음)

-- ==================== 비동기 배틀 ====================

-- 도전 요청 (클라이언트 → 서버)
RemoteEvents.AsyncBattleChallenge = getOrCreateRemoteEvent("AsyncBattleChallenge")
-- 파라미터: { targetName: string, targetScore: number }

-- 배틀 결과 (서버 → 클라이언트)
RemoteEvents.AsyncBattleResult = getOrCreateRemoteEvent("AsyncBattleResult")
-- 파라미터: { won: boolean, myScore: number, targetScore: number, targetName: string, reward: number? }

-- ==================== 실시간 배틀 ====================

-- 배틀 매칭 대기 (클라이언트 → 서버)
RemoteEvents.BattleQueueEnter = getOrCreateRemoteEvent("BattleQueueEnter")

-- 배틀 대기 취소 (클라이언트 → 서버)
RemoteEvents.BattleQueueLeave = getOrCreateRemoteEvent("BattleQueueLeave")

-- 매칭 완료 (서버 → 클라이언트)
RemoteEvents.BattleMatchFound = getOrCreateRemoteEvent("BattleMatchFound")
-- 파라미터: { opponentName: string, isBot: boolean }

-- 상대방 현재 점수 (서버 → 클라이언트, 2.5초마다)
RemoteEvents.BattleOpponentScore = getOrCreateRemoteEvent("BattleOpponentScore")
-- 파라미터: { score: number, opponentName: string }

-- 배틀 결과 (서버 → 클라이언트)
RemoteEvents.BattleResult = getOrCreateRemoteEvent("BattleResult")
-- 파라미터: { won: boolean, myScore: number, opponentScore: number, opponentName: string, reward: number? }

-- ==================== 재미 요소 강화 ====================

-- 생존 배율 업데이트 (서버 → 클라이언트)
RemoteEvents.SurvivalMultiplierUpdate = getOrCreateRemoteEvent("SurvivalMultiplierUpdate")
-- 파라미터: { tier: number, multiplier: number, label: string? }

-- 피격 코인 러시 (서버 → 클라이언트)
RemoteEvents.HitRushStart = getOrCreateRemoteEvent("HitRushStart")
-- 파라미터: { duration: number }

-- 슈퍼 피버 시작 (서버 → 클라이언트)
RemoteEvents.SuperFeverStart = getOrCreateRemoteEvent("SuperFeverStart")
-- 파라미터: { duration: number, speedBoost: number }

-- 미니 피버 시작 (서버 → 클라이언트) - 15콤보 달성 시
RemoteEvents.MiniFeverStart = getOrCreateRemoteEvent("MiniFeverStart")
-- 파라미터: { duration: number }

-- 미니 피버 종료 (서버 → 클라이언트)
RemoteEvents.MiniFeverEnd = getOrCreateRemoteEvent("MiniFeverEnd")

-- ==================== 데일리 이벤트 ====================

-- 데일리 이벤트 데이터 (서버 → 클라이언트)
RemoteEvents.DailyEventData = getOrCreateRemoteEvent("DailyEventData")
-- 파라미터: { themeId, displayName, coinName, coinColor, goal, goalTarget, goalDesc,
--            rewardType, rewardAmount, bonusGems, speedModifier, coinValueBonus, progress, completed }

-- 데일리 이벤트 진행도 (서버 → 클라이언트)
RemoteEvents.DailyEventProgress = getOrCreateRemoteEvent("DailyEventProgress")
-- 파라미터: { progress: number, goalTarget: number, goalType: string, completed: boolean }

-- ==================== 업그레이드 상점 ====================

-- 업그레이드 구매 요청 (클라이언트 → 서버)
RemoteEvents.UpgradePurchase = getOrCreateRemoteEvent("UpgradePurchase")
-- 파라미터: { upgradeId: string }

-- 업그레이드 구매 결과 (서버 → 클라이언트)
RemoteEvents.UpgradePurchaseResult = getOrCreateRemoteEvent("UpgradePurchaseResult")
-- 파라미터: { success: boolean, upgradeId: string, newLevel: number, newBalance: number, error: string? }

-- 업그레이드 데이터 (서버 → 클라이언트)
RemoteEvents.UpgradeData = getOrCreateRemoteEvent("UpgradeData")
-- 파라미터: { upgrades: { [upgradeId]: level }, coins: number }

-- ==================== 런 목표 ====================

-- 런 목표 생성 (서버 → 클라이언트)
RemoteEvents.RunObjectivesGenerated = getOrCreateRemoteEvent("RunObjectivesGenerated")
-- 파라미터: { objectives: { { id, desc, target, progress, completed } } }

-- 런 목표 진행도 (서버 → 클라이언트)
RemoteEvents.RunObjectiveProgress = getOrCreateRemoteEvent("RunObjectiveProgress")
-- 파라미터: { objectives: { { id, progress, completed } }, allCompleted: boolean, bonus: number? }

-- 런 목표 리롤 요청 (클라이언트 → 서버)
RemoteEvents.RerollObjective = getOrCreateRemoteEvent("RerollObjective")
-- 파라미터: { index: number }

-- 런 목표 리롤 결과 (서버 → 클라이언트)
RemoteEvents.RerollObjectiveResult = getOrCreateRemoteEvent("RerollObjectiveResult")
-- 파라미터: { success: boolean, index: number, objective: {id, desc, target}?, error: string? }

-- ==================== 펫 시스템 ====================

-- 펫 데이터 (서버 → 클라이언트)
RemoteEvents.PetData = getOrCreateRemoteEvent("PetData")
-- 파라미터: { ownedPets: {string}, equippedPet: string }

-- 펫 구매 요청 (클라이언트 → 서버)
RemoteEvents.PetPurchase = getOrCreateRemoteEvent("PetPurchase")
-- 파라미터: { petId: string }

-- 펫 구매 결과 (서버 → 클라이언트)
RemoteEvents.PetPurchaseResult = getOrCreateRemoteEvent("PetPurchaseResult")
-- 파라미터: { success: boolean, petId: string?, newBalance: number?, error: string? }

-- 펫 장착 (클라이언트 → 서버)
RemoteEvents.EquipPet = getOrCreateRemoteEvent("EquipPet")
-- 파라미터: { petId: string }

-- 펫 레벨업 요청 (클라이언트 → 서버)
RemoteEvents.PetLevelUp = getOrCreateRemoteEvent("PetLevelUp")
-- 파라미터: { petId: string }

-- 펫 레벨업 결과 (서버 → 클라이언트)
RemoteEvents.PetLevelUpResult = getOrCreateRemoteEvent("PetLevelUpResult")
-- 파라미터: { success: boolean, petId: string?, newLevel: number?, newBalance: number?, error: string? }

-- ==================== 이름표 ====================

-- 이름표 아이템 구매 (클라이언트 → 서버)
RemoteEvents.NametagPurchase = getOrCreateRemoteEvent("NametagPurchase")
-- 파라미터: { itemId: string }

-- 이름표 구매 결과 (서버 → 클라이언트)
RemoteEvents.NametagPurchaseResult = getOrCreateRemoteEvent("NametagPurchaseResult")
-- 파라미터: { success: boolean, itemId: string?, newBalance: number?, error: string? }

-- 이름표 데이터 (서버 → 클라이언트)
RemoteEvents.NametagData = getOrCreateRemoteEvent("NametagData")
-- 파라미터: { color: string?, font: string?, frame: string? }

-- ==================== 스토리 자막 ====================

-- 런 중 NPC 스토리 자막 표시 (서버 → 클라이언트)
RemoteEvents.StorySubtitle = getOrCreateRemoteEvent("StorySubtitle")
-- 파라미터: { speaker: string, emoji: string, text: string }

-- ==================== 보스 조우 ====================
-- 런 중 보스 등장 연출 (서버 → 클라이언트)
RemoteEvents.BossDialogue = getOrCreateRemoteEvent("BossDialogue")
-- 파라미터: { characterId: string, text: string, isVillain: boolean }

-- ==================== 추격자 ====================

-- 추격자 등장 경고 (서버 → 클라이언트)
RemoteEvents.ChaseMobWarning = getOrCreateRemoteEvent("ChaseMobWarning")
-- 파라미터: (없음) - 등장 시 경고음/화면 플래시 재생

-- ==================== 캐릭터 시스템 ====================

-- 캐릭터 데이터 (서버 → 클라이언트)
RemoteEvents.CharacterData = getOrCreateRemoteEvent("CharacterData")
-- 파라미터: { ownedCharacters: {string}, equippedCharacter: string }

-- 캐릭터 장착 요청 (클라이언트 → 서버)
RemoteEvents.EquipCharacter = getOrCreateRemoteEvent("EquipCharacter")
-- 파라미터: { characterId: string }

-- 캐릭터 해금 알림 (서버 → 클라이언트)
RemoteEvents.CharacterUnlocked = getOrCreateRemoteEvent("CharacterUnlocked")
-- 파라미터: { characterId: string, characterName: string }

-- 캐릭터 스킬 사용 요청 (클라이언트 → 서버)
RemoteEvents.CharacterSkillUse = getOrCreateRemoteEvent("CharacterSkillUse")
-- 파라미터: (없음)

-- 캐릭터 스킬 발동 결과 (서버 → 클라이언트)
RemoteEvents.CharacterSkillActivated = getOrCreateRemoteEvent("CharacterSkillActivated")
-- 파라미터: { skillId: string, duration: number, cooldown: number }

-- 캐릭터 구매 요청 (클라이언트 → 서버)
RemoteEvents.BuyCharacter = getOrCreateRemoteEvent("BuyCharacter")
-- 파라미터: { characterId: string }

-- 캐릭터 구매 결과 (서버 → 클라이언트)
RemoteEvents.BuyCharacterResult = getOrCreateRemoteEvent("BuyCharacterResult")
-- 파라미터: { success: boolean, characterId: string, reason: string? }

-- NPC 상호작용 (서버 → 클라이언트)
RemoteEvents.NpcInteract = getOrCreateRemoteEvent("NpcInteract")
-- 파라미터: { npcId: string }

-- ==================== 런 내 성장 시스템 ====================

-- 런 내 XP 업데이트 (서버 → 클라이언트)
RemoteEvents.RunXPUpdate = getOrCreateRemoteEvent("RunXPUpdate")
-- 파라미터: { runXP: number, runXPMax: number, runLevel: number }

-- 런 레벨업 스킬 선택 (서버 → 클라이언트)
RemoteEvents.RunSkillOptions = getOrCreateRemoteEvent("RunSkillOptions")
-- 파라미터: { skills: { { id, name, emoji, desc, rarity } }, autoSelectDelay: number }

-- 스킬 선택 (클라이언트 → 서버)
RemoteEvents.RunSkillSelect = getOrCreateRemoteEvent("RunSkillSelect")
-- 파라미터: { skillId: string }

-- 스킬 발동 확인 (서버 → 클라이언트)
RemoteEvents.RunSkillActivated = getOrCreateRemoteEvent("RunSkillActivated")
-- 파라미터: { skillId: string, name: string, emoji: string }

-- 런 스킬 영구 해금 알림 (서버 → 클라이언트)
RemoteEvents.RunSkillUnlocked = getOrCreateRemoteEvent("RunSkillUnlocked")
-- 파라미터: { skillId: string }

-- 런 스킬 슬롯 데이터 (서버 → 클라이언트)
RemoteEvents.PreRunSkillData = getOrCreateRemoteEvent("PreRunSkillData")
-- 파라미터: { unlockedSkills: { { id, name, emoji, desc, rarity } }, equippedSkills: { string } }

-- 런 스킬 슬롯 장착 요청 (클라이언트 → 서버)
RemoteEvents.EquipRunSkills = getOrCreateRemoteEvent("EquipRunSkills")
-- 파라미터: { skillIds: { string } } (최대 2개)

-- ==================== 초대 보상 시스템 ====================

-- ==================== Zone 고유 메커닉 ====================

-- 버섯 트램폴린 밟기 (서버 → 클라이언트): 점프력 일시 증폭
RemoteEvents.MushroomBounce = getOrCreateRemoteEvent("MushroomBounce")
-- 파라미터: 없음 (클라이언트는 수신 즉시 점프력 배율 적용)

-- 저중력 구간 진입/퇴장 (서버 → 클라이언트)
RemoteEvents.GravityZoneEnter = getOrCreateRemoteEvent("GravityZoneEnter")
RemoteEvents.GravityZoneExit = getOrCreateRemoteEvent("GravityZoneExit")
-- 파라미터: 없음

-- 초대 다이얼로그 열기 요청 (클라이언트 → 서버)
RemoteEvents.InviteFriend = getOrCreateRemoteEvent("InviteFriend")

-- 초대 보상 알림 (서버 → 클라이언트)
RemoteEvents.ReferralReward = getOrCreateRemoteEvent("ReferralReward")
-- 파라미터: { type: "referrer"|"referee", coins: number, referrerName: string? }

return RemoteEvents

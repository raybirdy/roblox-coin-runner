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

-- 함수: RemoteFunction 생성 또는 가져오기
local function getOrCreateRemoteFunction(name: string): RemoteFunction
	local remote = remoteFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = remoteFolder
	end
	return remote :: RemoteFunction
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

return RemoteEvents

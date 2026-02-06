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

return RemoteEvents

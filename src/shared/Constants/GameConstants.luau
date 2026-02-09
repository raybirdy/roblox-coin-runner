--!strict
-- Game Constants
-- 게임 전반에 사용되는 상수 정의

local GameConstants = {}

-- 물리 파라미터
GameConstants.PLAYER = {
	SIZE = Vector3.new(4, 5, 4), -- 캐릭터 크기 (폭×높이×깊이)
	SLIDE_SIZE = Vector3.new(4, 2.5, 4), -- 슬라이드 시 히트박스
	Z_POSITION = 0, -- Z축 고정 위치 (2D 평면 유지)
}

GameConstants.PHYSICS = {
	-- 점프
	JUMP_HEIGHT_FIRST = 8, -- 1단 점프 높이 (studs)
	JUMP_HEIGHT_SECOND = 5, -- 2단 점프 추가 높이 (studs)
	JUMP_AIRTIME_FIRST = 0.7, -- 1단 점프 체공 시간 (초)
	JUMP_AIRTIME_SECOND = 1.1, -- 2단 점프 총 체공 시간 (초)
	JUMP_POWER = 50, -- Roblox AssemblyLinearVelocity 점프력
	GRAVITY = workspace.Gravity, -- Roblox 기본 중력 (196.2)

	-- 슬라이드
	SLIDE_DURATION = 0.6, -- 슬라이드 지속 시간 (초)
	SLIDE_COOLDOWN = 0.2, -- 슬라이드 후 쿨다운 (초)

	-- 이동 속도 (저연령층 6~12세 기준)
	SPEED_MIN = 35, -- 최소 속도 (studs/s) - 느리고 편안함
	SPEED_MAX = 55, -- 최대 속도 (studs/s) - 적당한 속도
	SPEED_RAMP_TIME = 90, -- 최대 속도 도달 시간 (초) - 1분 30초
}

-- 청크 시스템
GameConstants.CHUNK = {
	LENGTH = 80, -- 청크 길이 (studs)
	HEIGHT = 40, -- 청크 높이 (studs)
	MAX_LOADED = 6, -- 동시 로드 최대 청크 수 (더 많이 미리 로드)
	MIN_AHEAD_DISTANCE = 200, -- 플레이어 앞에 최소 이 거리만큼 청크 유지 (studs)
	DELETE_DISTANCE = 100, -- 캐릭터 뒤 이 거리 초과 시 청크 삭제

	-- 높이 태그
	HEIGHT_LOW = 0,
	HEIGHT_MID = 6,
	HEIGHT_HIGH = 12,
}

-- 난이도별 청크 출현 확률 (시간대별)
GameConstants.CHUNK_SPAWN_RATES = {
	-- 0~30초
	{
		maxTime = 30,
		Easy = 0.70,
		Normal = 0.10,
		Hard = 0.00,
		Bonus = 0.15,
		NPC = 0.05,
	},
	-- 30~60초
	{
		maxTime = 60,
		Easy = 0.40,
		Normal = 0.35,
		Hard = 0.05,
		Bonus = 0.10,
		NPC = 0.10,
	},
	-- 60~120초
	{
		maxTime = 120,
		Easy = 0.20,
		Normal = 0.40,
		Hard = 0.20,
		Bonus = 0.10,
		NPC = 0.10,
	},
	-- 120~180초
	{
		maxTime = 180,
		Easy = 0.10,
		Normal = 0.35,
		Hard = 0.35,
		Bonus = 0.10,
		NPC = 0.10,
	},
	-- 180초+
	{
		maxTime = math.huge,
		Easy = 0.05,
		Normal = 0.30,
		Hard = 0.45,
		Bonus = 0.10,
		NPC = 0.10,
	},
}

-- 코인
GameConstants.COIN = {
	BRONZE_VALUE = 1,
	SILVER_VALUE = 5,
	GOLD_VALUE = 10,
	DIAMOND_VALUE = 50,
}

-- 장애물
GameConstants.OBSTACLE = {
	LOW_WALL_HEIGHT = 4, -- 낮은 벽 높이
	TUNNEL_HEIGHT = 3, -- 높은 벽 터널 통로 높이
	GAP_WIDTH_MIN = 6, -- 구덩이 최소 폭
	GAP_WIDTH_MAX = 10, -- 구덩이 최대 폭
	MIN_SPACING = 12, -- 장애물 간 최소 간격 (studs) - 최고 속도 기준
}

-- 라이프 시스템
GameConstants.LIFE = {
	STARTING_LIVES = 3,
	INVINCIBLE_DURATION = 3, -- 피격 후 무적 시간 (초)
	MERCY_CHUNK_THRESHOLD = 2, -- 연속 피격 2회 시 자비 청크
}

-- 점수 시스템
GameConstants.SCORE = {
	DISTANCE_MULTIPLIER = 1, -- 1 stud = 1 점
	NEAR_MISS_BONUS = 5,
	COMBO_10_BONUS = 10,
	COMBO_30_BONUS = 30,
	COMBO_50_BONUS = 50,
	COMBO_TIMEOUT = 2, -- 콤보 리셋 시간 (초)
}

-- 파워업 (자석, 쉴드, 무적, 2배코인)
GameConstants.POWERUP = {
	MAGNET_DURATION = 5, -- 자석 지속 시간 (초)
	MAGNET_RADIUS = 15, -- 자석 흡수 반경 (studs)
	SHIELD_USES = 1, -- 쉴드 사용 횟수
	INVINCIBLE_DURATION = 5, -- 무적 지속 시간 (초)
	DOUBLE_COIN_DURATION = 8, -- 2배 코인 지속 시간 (초)
	MIN_SPAWN_TIME = 20, -- 첫 파워업 등장 시간 (초)
	MIN_INTERVAL = 15, -- 파워업 간 최소 간격 (초)

	-- 출현 확률 (합계 1.0)
	MAGNET_RATE = 0.35,
	SHIELD_RATE = 0.25,
	INVINCIBLE_RATE = 0.20,
	DOUBLE_COIN_RATE = 0.20,
}

-- 부활
GameConstants.REVIVE = {
	MAX_REVIVES = 1, -- 1판당 최대 부활 횟수
	GEM_COST = 0, -- MVP에서는 무료 부활
	INVINCIBLE_DURATION = 3, -- 부활 후 무적 시간 (초)
	SPEED_REDUCTION = 0.80, -- 부활 후 속도 80%로 감소
	SPEED_RECOVERY_TIME = 5, -- 원래 속도로 복귀하는 시간 (초)
}

-- 튜토리얼
GameConstants.TUTORIAL = {
	SLOWMO_SPEED_MULTIPLIER = 0.60, -- 슬로모션 속도 (60%) - 너무 느리지 않게
	SLOWMO_TRANSITION_TIME = 0.3, -- 슬로모션 전환 시간 (초)
	SKIP_AFTER_DISTANCE = 150, -- 150 studs 이동 시 자동 종료 (빠르게)
}

-- UI
GameConstants.UI = {
	TOUCH_BUTTON_SIZE = 80, -- 모바일 버튼 최소 크기 (px)
}

-- DataStore
GameConstants.DATA = {
	DATASTORE_NAME = "PlayerData_v1",
	AUTO_SAVE_INTERVAL = 60, -- 자동 저장 주기 (초)
	SAVE_RETRY_COUNT = 3, -- 저장 실패 시 재시도 횟수
}

-- NPC (MVP: 토끼, 곰돌이, 부엉이)
GameConstants.NPC = {
	SPEECH_BUBBLE_DURATION = 3, -- 말풍선 표시 시간 (초) - 더 오래 표시
	WAVE_ANIMATION_DURATION = 4, -- 손흔들기 애니메이션 지속 시간 (초)
	SPAWN_HEIGHT = 0, -- NPC 스폰 Y 위치 (바닥 기준)
	Z_POSITION = -10, -- NPC Z 위치 (배경 레이어)

	-- NPC 종류별 설정
	TYPES = {
		Rabbit = {
			name = "Rabbit",
			messages = {
				"화이팅!",
				"멋져!",
				"최고야!",
				"잘하고 있어!",
				"파이팅!",
				"너무 잘해!",
			},
			color = Color3.fromRGB(255, 192, 203), -- 분홍
			spawnChance = 0.50, -- NPC 청크 내 50% 확률
		},
		Bear = {
			name = "Bear",
			messages = {
				"잘하고 있어!",
				"대단해!",
				"굿잡!",
				"계속 가자!",
				"힘내!",
				"코인 많이 모아!",
			},
			color = Color3.fromRGB(139, 69, 19), -- 갈색
			spawnChance = 0.50, -- NPC 청크 내 50% 확률
		},
		Owl = {
			name = "Owl",
			messages = {
				"자동으로 달려! 코인을 모아봐!",
				"점프! ↑",
				"슬라이드! ↓",
				"공중에서 한 번 더 점프!",
			},
			color = Color3.fromRGB(160, 82, 45), -- 갈색 부엉이
			spawnChance = 1.0, -- 튜토리얼 전용, 확정 등장
		},
	},
}

return GameConstants

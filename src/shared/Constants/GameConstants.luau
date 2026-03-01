--!strict
-- Game Constants
-- 게임 전반에 사용되는 상수 정의

local GameConstants = {}

-- 물리 파라미터
GameConstants.PLAYER = {
	SIZE = Vector3.new(4, 5, 4), -- 캐릭터 크기 (폭×높이×깊이)
	SLIDE_SIZE = Vector3.new(4, 2.5, 4), -- 슬라이드 시 히트박스
	MINI_SIZE = Vector3.new(2, 2.5, 2), -- 미니 사이즈 파워업 시 히트박스
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
	SPEED_MIN = 22, -- 최소 속도 (studs/s) - 느리고 편안함
	SPEED_MAX = 52, -- 최대 속도 (studs/s) - 적당한 속도
	SPEED_RAMP_TIME = 120, -- 최대 속도 도달 시간 (초) - 2분
}

-- 청크 시스템
GameConstants.CHUNK = {
	LENGTH = 80, -- 청크 길이 (studs)
	HEIGHT = 40, -- 청크 높이 (studs)
	MAX_LOADED = 6, -- 동시 로드 최대 청크 수 (더 많이 미리 로드)
	MIN_AHEAD_DISTANCE = 200, -- 플레이어 앞에 최소 이 거리만큼 청크 유지 (studs)
	DELETE_DISTANCE = 100, -- 캐릭터 뒤 이 거리 초과 시 청크 삭제
	SAFE_ZONE_CHUNKS = 4, -- 시작 안전 구역 (처음 4개 청크는 장애물 없음)

	-- 높이 태그
	HEIGHT_LOW = 0,
	HEIGHT_MID = 6,
	HEIGHT_HIGH = 12,
}

-- 난이도별 청크 출현 확률 (시간대별)
GameConstants.CHUNK_SPAWN_RATES = {
	-- 0~30초 (초반 - 매우 쉬움)
	{
		maxTime = 30,
		Easy = 0.80, -- Easy 80%
		Normal = 0.00,
		Hard = 0.00,
		Bonus = 0.15,
		NPC = 0.05,
	},
	-- 30~60초 (점진적 난이도 상승)
	{
		maxTime = 60,
		Easy = 0.55, -- Easy 55%
		Normal = 0.25,
		Hard = 0.00, -- Hard 아직 없음
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

-- 코인 패턴 (난이도별 사용 가능한 배치 패턴 목록)
GameConstants.COIN_PATTERNS = {
	EASY = { "line", "arc", "spread" },
	NORMAL = { "line", "arc", "zigzag", "step_up", "step_down" },
	HARD = { "zigzag", "step_up", "step_down", "corridor" },
	BONUS = { "line", "arc", "double_line", "spread" },
	NPC = { "line", "spread" },
}

-- 코인 개수 (난이도별, 패턴 완성을 위한 적정 수로 조정)
GameConstants.COIN_COUNTS = {
	EASY = { min = 6, max = 8 },
	NORMAL = { min = 5, max = 7 },
	HARD = { min = 4, max = 6 },
	BONUS = { min = 12, max = 18 },
	NPC = { min = 3, max = 4 },
}

-- 장애물
GameConstants.OBSTACLE = {
	LOW_WALL_HEIGHT = 4, -- 낮은 벽 높이
	TUNNEL_HEIGHT = 4.5, -- 높은 벽 터널 통로 높이 (슬라이드로 통과 가능)
	GAP_WIDTH_MIN = 6, -- 구덩이 최소 폭
	GAP_WIDTH_MAX = 10, -- 구덩이 최대 폭
	MIN_SPACING = 12, -- 장애물 간 최소 간격 (studs) - 최고 속도 기준
	NEAR_MISS_X_RANGE = 4, -- 니어미스 X거리 범위 (studs)
	NEAR_MISS_Y_MARGIN = 3, -- 니어미스 Y방향 여유 범위 (studs)
	-- 움직이는 벽 (Hard 전용, 상하 왕복)
	MOVING_WALL_HEIGHT = 5, -- 벽 높이 (studs)
	MOVING_WALL_WIDTH = 3, -- 벽 두께 (studs)
	MOVING_WALL_Y_MIN = 0, -- 최저 위치 (ground level)
	MOVING_WALL_Y_MAX = 8, -- 최고 위치 (studs)
	MOVING_WALL_CYCLE_TIME = 2, -- 상하 왕복 주기 (초)
}

-- 라이프 시스템
GameConstants.LIFE = {
	STARTING_LIVES = 3,
	INVINCIBLE_DURATION = 3, -- 피격 후 무적 시간 (초)
	MERCY_CHUNK_THRESHOLD = 2, -- 연속 피격 2회 시 자비 청크
	MERCY_CHUNK_COUNT = 2, -- 자비 모드 시 연속 쉬운 청크 수
}

-- 위로 보상
GameConstants.CONSOLATION = {
	THRESHOLD = 3, -- 3회 연속 빠른 게임오버 시 위로 보상
	REWARD_COINS = 20, -- 보상 코인
	QUICK_DEATH_SCORE = 100, -- 이 점수 미만이면 "빠른 게임오버"
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

-- 파워업 (자석, 쉴드, 무적, 2배코인, 미니사이즈)
GameConstants.POWERUP = {
	MAGNET_DURATION = 5, -- 자석 지속 시간 (초)
	MAGNET_RADIUS = 15, -- 자석 흡수 반경 (studs)
	SHIELD_USES = 1, -- 쉴드 사용 횟수
	INVINCIBLE_DURATION = 5, -- 무적 지속 시간 (초)
	DOUBLE_COIN_DURATION = 8, -- 2배 코인 지속 시간 (초)
	MINI_SIZE_DURATION = 5, -- 미니 사이즈 지속 시간 (초)
	MIN_SPAWN_TIME = 20, -- 첫 파워업 등장 시간 (초)
	MIN_INTERVAL = 15, -- 파워업 간 최소 간격 (초)

	-- 출현 확률 (합계 1.0)
	MAGNET_RATE = 0.30,
	SHIELD_RATE = 0.22,
	INVINCIBLE_RATE = 0.18,
	DOUBLE_COIN_RATE = 0.18,
	MINI_SIZE_RATE = 0.12,
}

-- 부활
GameConstants.REVIVE = {
	MAX_REVIVES = 1, -- 1판당 최대 부활 횟수
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
	TOUCH_BUTTON_SIZE = 120, -- 모바일 버튼 크기 (px) - 6~12세 대상 큰 버튼
	SWIPE_THRESHOLD = 50, -- 스와이프 인식 최소 거리 (px) - 고DPI 대응 증가
	SWIPE_MAX_TIME = 0.4, -- 스와이프 최대 시간 (초)
}

-- DataStore
GameConstants.DATA = {
	DATASTORE_NAME = "PlayerData_v1",
	AUTO_SAVE_INTERVAL = 60, -- 자동 저장 주기 (초)
	SAVE_RETRY_COUNT = 3, -- 저장 실패 시 재시도 횟수
}

-- 로비 시스템 (확장)
GameConstants.LOBBY = {
	-- 크기 확장: 200 x 80 studs (더 넓은 로비)
	FLOOR_SIZE = Vector3.new(200, 1, 80),
	FLOOR_POSITION = Vector3.new(-110, 0.5, 0),

	-- 주요 위치
	SPAWN_POSITION = Vector3.new(-38, 2.5, 0),
	PORTAL_POSITION = Vector3.new(-25, 3, 0),
	PORTAL_SIZE = Vector3.new(6, 10, 18), -- 더 큰 포탈 (진입 용이)
	SHOP_POSITION = Vector3.new(-100, 5, 28), -- 더 바깥쪽 배치
	LEADERBOARD_POSITION = Vector3.new(-100, 5, -28), -- 상점 반대편
	TITLE_POSITION = Vector3.new(-110, 20, -35),

	-- 장식물 위치
	DECORATIONS = {
		-- 나무
		TREES = {
			Vector3.new(-180, 0, -30),
			Vector3.new(-180, 0, 30),
			Vector3.new(-140, 0, -32),
			Vector3.new(-140, 0, 32),
			Vector3.new(-70, 0, -32),
			Vector3.new(-70, 0, 32),
			Vector3.new(-50, 0, -28),
			Vector3.new(-50, 0, 28),
		},
		-- 꽃밭
		FLOWERS = {
			Vector3.new(-170, 0, 0),
			Vector3.new(-120, 0, 20),
			Vector3.new(-80, 0, -20),
			Vector3.new(-60, 0, 15),
		},
		-- 벤치
		BENCHES = {
			Vector3.new(-150, 0, -20),
			Vector3.new(-110, 0, 24),
			Vector3.new(-60, 0, -20),
		},
		-- 가로등
		LAMPS = {
			Vector3.new(-170, 0, -28),
			Vector3.new(-170, 0, 28),
			Vector3.new(-130, 0, -28),
			Vector3.new(-130, 0, 28),
			Vector3.new(-50, 0, -25),
		},
		-- 분수대
		FOUNTAIN = Vector3.new(-110, 0, 0),
		-- 풍선
		BALLOONS = {
			Vector3.new(-40, 8, 20),
			Vector3.new(-35, 10, -15),
		},
	},
}

-- 로비 NPC (동물 캐릭터)
GameConstants.LOBBY_NPC = {
	TYPES = {
		Rabbit = {
			name = "토끼",
			position = Vector3.new(-155, 0, 5),
			color = Color3.fromRGB(255, 200, 200), -- 분홍
			message = "안녕! 포탈로 들어가면 게임이 시작돼!",
			animation = "jump", -- 점프하며 인사
		},
		Dog = {
			name = "강아지",
			position = Vector3.new(-102, 0, 20),
			color = Color3.fromRGB(210, 180, 140), -- 베이지
			message = "멍! 상점에서 아이템을 구경해봐!",
			animation = "wag", -- 꼬리 흔들기
		},
		Cat = {
			name = "고양이",
			position = Vector3.new(-145, 0, -18),
			color = Color3.fromRGB(255, 165, 0), -- 주황
			message = "냥~ 점프는 2번까지 할 수 있어",
			animation = "sit", -- 앉아서 기지개
		},
		Penguin = {
			name = "펭귄",
			position = Vector3.new(-130, 0, 8),
			color = Color3.fromRGB(50, 50, 60), -- 검정
			message = "코인을 많이 모아봐!",
			animation = "waddle", -- 뒤뚱뒤뚱
		},
		Bear = {
			name = "곰돌이",
			position = Vector3.new(-35, 0, 5),
			color = Color3.fromRGB(139, 90, 43), -- 갈색
			message = "화이팅! 넌 할 수 있어!",
			animation = "wave", -- 손 흔들기
		},
	},
	SPEECH_DURATION = 3, -- 말풍선 표시 시간 (초)
}

-- 상점 시스템
GameConstants.SHOP = {
	-- 스킨 (코인으로 구매)
	SKINS = {
		-- 기본 (무료)
		{
			id = "default",
			name = "기본",
			price = 0,
			currency = "coins",
			color = Color3.fromRGB(0, 170, 255),
			thumbnailId = "rbxassetid://3535928381",
		},
		-- 코인 스킨 (누구나 접근 가능)
		{
			id = "red_hat",
			name = "빨간 모자",
			price = 100,
			currency = "coins",
			color = Color3.fromRGB(220, 50, 50),
			thumbnailId = "rbxassetid://3535928917",
		},
		{
			id = "ninja",
			name = "닌자",
			price = 150,
			currency = "coins",
			color = Color3.fromRGB(30, 30, 50),
			thumbnailId = "rbxassetid://3535929309",
		},
		{
			id = "blue_cape",
			name = "파란 망토",
			price = 200,
			currency = "coins",
			color = Color3.fromRGB(50, 100, 220),
			thumbnailId = "rbxassetid://3535929635",
		},
		{
			id = "pirate",
			name = "해적",
			price = 300,
			currency = "coins",
			color = Color3.fromRGB(100, 60, 30),
			thumbnailId = "rbxassetid://3535929876",
		},
		{
			id = "robot",
			name = "로봇",
			price = 400,
			currency = "coins",
			color = Color3.fromRGB(160, 170, 180),
			thumbnailId = "rbxassetid://3535930077",
		},
		{
			id = "golden",
			name = "골든",
			price = 500,
			currency = "coins",
			color = Color3.fromRGB(255, 215, 0),
			thumbnailId = "rbxassetid://3535930233",
		},
		-- 프리미엄 스킨 (젬으로 구매 - 희소성 높음)
		{
			id = "galaxy",
			name = "갤럭시",
			price = 80,
			currency = "gems",
			color = Color3.fromRGB(60, 20, 120),
			thumbnailId = "rbxassetid://3535936432",
		},
		{
			id = "unicorn",
			name = "유니콘",
			price = 100,
			currency = "gems",
			color = Color3.fromRGB(255, 180, 255),
			thumbnailId = "rbxassetid://3535936633",
		},
		{
			id = "ice_king",
			name = "아이스킹",
			price = 150,
			currency = "gems",
			color = Color3.fromRGB(150, 220, 255),
			thumbnailId = "rbxassetid://3535936812",
		},
		{
			id = "dragon",
			name = "드래곤",
			price = 200,
			currency = "gems",
			color = Color3.fromRGB(200, 50, 0),
			thumbnailId = "rbxassetid://3535937071",
		},
		{
			id = "rainbow",
			name = "레인보우",
			price = 300,
			currency = "gems",
			color = Color3.fromRGB(255, 100, 200),
			thumbnailId = "rbxassetid://3535937245",
		},
		{
			id = "shadow",
			name = "쉐도우",
			price = 400,
			currency = "gems",
			color = Color3.fromRGB(20, 20, 30),
			thumbnailId = "rbxassetid://3535937404",
		},
		-- 시즌 한정 스킨 (TODO: 스킨 콘텐츠 준비 후 활성화)
		-- {
		-- 	id = "cherry_blossom",
		-- 	name = "벚꽃",
		-- 	price = 150,
		-- 	currency = "gems",
		-- 	color = Color3.fromRGB(255, 183, 197),
		-- 	thumbnailId = "rbxassetid://3535936633",
		-- 	availableUntil = 0, -- 배포 시 실제 날짜로 교체
		-- },
		-- {
		-- 	id = "spring_fairy",
		-- 	name = "봄 요정",
		-- 	price = 0,
		-- 	currency = "pieces",
		-- 	color = Color3.fromRGB(144, 238, 144),
		-- 	thumbnailId = "rbxassetid://3535936812",
		-- 	availableUntil = 0, -- 배포 시 실제 날짜로 교체
		-- },
	},
	-- 시작 파워업 (코인)
	START_POWERUPS = {
		{ id = "start_magnet", name = "시작 자석", price = 50, duration = 5 },
		{ id = "start_shield", name = "시작 쉴드", price = 50, uses = 1 },
		{ id = "start_double", name = "시작 2배코인", price = 80, duration = 10 },
	},
	-- 부활권 (코인)
	REVIVE_TICKET_PRICE = 100,
	-- 젬으로 부활 (게임 중)
	REVIVE_GEM_COST = 5,
	-- 시즌 한정 스킨
	SEASON = {
		SKIN_PIECES_REQUIRED = 10, -- 스킨 조각 10개 → 스킨 1개 교환
	},
}

-- 수익화 시스템 (Robux 상품)
-- 주의: 실제 Product/GamePass ID는 Roblox Creator Hub에서 생성 후 교체 필요
GameConstants.MONETIZATION = {
	-- DevProducts (젬 구매)
	GEM_PRODUCTS = {
		{ id = "gems_50", productId = 3540343000, gems = 50, robux = 25, bonus = 0 },
		{ id = "gems_200", productId = 3540343177, gems = 200, robux = 75, bonus = 50 },
		{ id = "gems_500", productId = 3540343329, gems = 500, robux = 149, bonus = 150 },
		{ id = "starter_pack", productId = 3540343511, gems = 100, robux = 49, bonus = 0 },
	},
	-- GamePass (VIP)
	VIP_GAMEPASS_ID = 1720352633,
	VIP_BENEFITS = {
		coinMultiplier = 2, -- 코인 획득 2배
		badge = "VIP",
	},
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

-- 게임 배경 시스템
GameConstants.BACKGROUND = {
	-- 관중석 위치 (사이드뷰: 카메라 반대편에 배치)
	CROWD_Z_FRONT = -15, -- 가까운 관중석 (카메라 뒤쪽)
	CROWD_Z_BACK = -25, -- 먼 관중석 (배경)
	CROWD_Y = 0, -- 관중 높이

	-- 관중 NPC 설정
	CROWD_SPACING = 15, -- 관중 간격 (studs)
	CROWD_PER_CHUNK = 4, -- 청크당 관중 수 (양쪽 합)

	-- 관중 타입
	CROWD_TYPES = {
		{
			name = "Rabbit",
			color = Color3.fromRGB(255, 200, 200),
			animation = "jump",
		},
		{
			name = "Bear",
			color = Color3.fromRGB(180, 130, 80),
			animation = "wave",
		},
		{
			name = "Cat",
			color = Color3.fromRGB(255, 180, 100),
			animation = "sit",
		},
		{
			name = "Penguin",
			color = Color3.fromRGB(60, 60, 70),
			animation = "waddle",
		},
		{
			name = "Dog",
			color = Color3.fromRGB(210, 180, 140),
			animation = "wag",
		},
	},

	-- 배경 나무/언덕
	SCENERY_Z = -35, -- 먼 배경 위치
	TREES_PER_CHUNK = 2, -- 청크당 나무 수
	HILLS_ENABLED = true, -- 언덕 배경

	-- 스피드 라인
	SPEED_LINES = {
		ENABLED = true,
		Z_RANGE = { -12, -2 }, -- Z 위치 범위 (사이드뷰: 카메라 뒤쪽에 배치)
		Y_RANGE = { 2, 12 }, -- Y 위치 범위
		COUNT = 6, -- 동시 표시 개수
		LENGTH = 8, -- 라인 길이
		SPEED_MULTIPLIER = 2.0, -- 플레이어 속도 대비 배율
	},

	-- 캐릭터 Trail
	TRAIL = {
		ENABLED = true,
		LIFETIME = 0.3, -- 잔상 지속 시간
		MIN_LENGTH = 0.5, -- 최소 길이
		WIDTH = { 1.5, 0.5 }, -- 시작/끝 너비
		COLOR = Color3.fromRGB(255, 255, 200), -- 색상
		TRANSPARENCY = { 0.3, 1 }, -- 시작/끝 투명도
	},
}

-- ==================== 진행도 시스템 ====================

-- 레벨 시스템
GameConstants.LEVEL = {
	-- 레벨별 필요 XP (레벨 1부터 시작, 인덱스 = 다음 레벨로 가기 위한 XP)
	XP_TABLE = {
		100, -- Lv1 → Lv2
		200, -- Lv2 → Lv3
		350, -- Lv3 → Lv4
		500, -- Lv4 → Lv5
		700, -- Lv5 → Lv6
		1000, -- Lv6 → Lv7
		1300, -- Lv7 → Lv8
		1700, -- Lv8 → Lv9
		2200, -- Lv9 → Lv10
		3000, -- Lv10 → Lv11
		4000, -- Lv11 → Lv12
		5000, -- Lv12 → Lv13
		6500, -- Lv13 → Lv14
		8000, -- Lv14 → Lv15
		10000, -- Lv15 → Lv16
		12000, -- Lv16 → Lv17
		15000, -- Lv17 → Lv18
		18000, -- Lv18 → Lv19
		22000, -- Lv19 → Lv20
		30000, -- Lv20 → Lv21+
	},
	MAX_LEVEL = 20,
	-- XP 획득량
	XP_PER_GAME = 10, -- 게임 1회 참여
	XP_PER_SCORE_100 = 5, -- 점수 100점당 XP
	XP_PER_MISSION = 30, -- 미션 완료 시 XP
	XP_PER_ACHIEVEMENT = 50, -- 업적 완료 시 XP
	-- 레벨업 보상 (레벨당 코인)
	LEVEL_UP_COIN_REWARD = 50,
	-- 특별 레벨 보상 (5레벨마다 젬)
	MILESTONE_LEVELS = { 5, 10, 15, 20 },
	MILESTONE_GEM_REWARD = 10,
}

-- 일일 미션 시스템
GameConstants.MISSIONS = {
	DAILY_COUNT = 3, -- 하루 3개 미션
	-- 미션 템플릿
	TEMPLATES = {
		{
			id = "play_games",
			name = "게임 플레이",
			desc = "게임 {target}회 플레이",
			targets = { 3, 5 },
			reward = 30,
		},
		{
			id = "collect_coins",
			name = "코인 수집",
			desc = "코인 {target}개 수집",
			targets = { 30, 50, 100 },
			reward = 40,
		},
		{
			id = "score_reach",
			name = "목표 점수",
			desc = "점수 {target}점 달성",
			targets = { 500, 1000, 2000 },
			reward = 50,
		},
		{
			id = "near_miss",
			name = "니어미스",
			desc = "니어미스 {target}회 달성",
			targets = { 3, 5 },
			reward = 35,
		},
		{
			id = "combo_reach",
			name = "콤보 달성",
			desc = "{target}콤보 달성",
			targets = { 10, 20 },
			reward = 40,
		},
		{ id = "distance_run", name = "달리기", desc = "{target}m 달리기", targets = { 500, 1000 }, reward = 35 },
	},
}

-- 업적 시스템
GameConstants.ACHIEVEMENTS = {
	-- { id, name, desc, condition, target, rewardGems, rewardXP }
	LIST = {
		-- 게임 시작
		{
			id = "first_game",
			name = "첫 발걸음",
			desc = "첫 게임 플레이!",
			target = 1,
			condition = "games_played",
			rewardGems = 5,
			rewardXP = 50,
		},
		{
			id = "play_10",
			name = "단골 러너",
			desc = "10회 게임 플레이",
			target = 10,
			condition = "games_played",
			rewardGems = 10,
			rewardXP = 100,
		},
		{
			id = "play_50",
			name = "마라톤 러너",
			desc = "50회 게임 플레이",
			target = 50,
			condition = "games_played",
			rewardGems = 20,
			rewardXP = 200,
		},
		{
			id = "play_100",
			name = "전설의 러너",
			desc = "100회 게임 플레이",
			target = 100,
			condition = "games_played",
			rewardGems = 50,
			rewardXP = 500,
		},
		-- 점수
		{
			id = "score_500",
			name = "워밍업",
			desc = "500점 달성",
			target = 500,
			condition = "high_score",
			rewardGems = 5,
			rewardXP = 50,
		},
		{
			id = "score_1000",
			name = "실력자",
			desc = "1000점 달성",
			target = 1000,
			condition = "high_score",
			rewardGems = 10,
			rewardXP = 100,
		},
		{
			id = "score_5000",
			name = "고수",
			desc = "5000점 달성",
			target = 5000,
			condition = "high_score",
			rewardGems = 25,
			rewardXP = 250,
		},
		{
			id = "score_10000",
			name = "챔피언",
			desc = "10000점 달성",
			target = 10000,
			condition = "high_score",
			rewardGems = 50,
			rewardXP = 500,
		},
		-- 코인
		{
			id = "coins_100",
			name = "동전 모으기",
			desc = "누적 100코인 수집",
			target = 100,
			condition = "total_coins",
			rewardGems = 5,
			rewardXP = 50,
		},
		{
			id = "coins_1000",
			name = "부자 러너",
			desc = "누적 1000코인 수집",
			target = 1000,
			condition = "total_coins",
			rewardGems = 15,
			rewardXP = 150,
		},
		{
			id = "coins_5000",
			name = "코인 왕",
			desc = "누적 5000코인 수집",
			target = 5000,
			condition = "total_coins",
			rewardGems = 30,
			rewardXP = 300,
		},
		-- 거리
		{
			id = "dist_1000",
			name = "1km 러너",
			desc = "누적 1000m 달리기",
			target = 1000,
			condition = "total_distance",
			rewardGems = 5,
			rewardXP = 50,
		},
		{
			id = "dist_10000",
			name = "10km 러너",
			desc = "누적 10000m 달리기",
			target = 10000,
			condition = "total_distance",
			rewardGems = 20,
			rewardXP = 200,
		},
		-- 레벨
		{
			id = "level_5",
			name = "성장중",
			desc = "레벨 5 달성",
			target = 5,
			condition = "level",
			rewardGems = 10,
			rewardXP = 0,
		},
		{
			id = "level_10",
			name = "중급 러너",
			desc = "레벨 10 달성",
			target = 10,
			condition = "level",
			rewardGems = 25,
			rewardXP = 0,
		},
		{
			id = "level_20",
			name = "만렙 러너",
			desc = "레벨 20 달성",
			target = 20,
			condition = "level",
			rewardGems = 100,
			rewardXP = 0,
		},
	},
}

-- ==================== Phase 2: 리텐션 시스템 ====================

-- 일일 출석 보상
GameConstants.LOGIN_REWARDS = {
	CYCLE_DAYS = 7,
	REWARDS = {
		{ day = 1, type = "coins", amount = 50 },
		{ day = 2, type = "coins", amount = 100 },
		{ day = 3, type = "gems", amount = 5 },
		{ day = 4, type = "coins", amount = 200 },
		{ day = 5, type = "gems", amount = 10 },
		{ day = 6, type = "coins", amount = 300 },
		{ day = 7, type = "gems", amount = 20 },
	},
	STREAK_MULTIPLIERS = {
		{ week = 2, multiplier = 1.5 },
		{ week = 3, multiplier = 2.0 },
	},
}

-- 럭키 스핀
GameConstants.LUCKY_SPIN = {
	FREE_SPINS_PER_DAY = 1,
	EXTRA_SPIN_GEM_COST = 5,
	REWARDS = {
		{ id = "coins_50", name = "50 코인", type = "coins", amount = 50, weight = 40 },
		{ id = "coins_100", name = "100 코인", type = "coins", amount = 100, weight = 25 },
		{ id = "coins_200", name = "200 코인", type = "coins", amount = 200, weight = 15 },
		{ id = "gems_5", name = "5 젬", type = "gems", amount = 5, weight = 10 },
		{ id = "gems_10", name = "10 젬", type = "gems", amount = 10, weight = 5 },
		{ id = "gems_20", name = "20 젬", type = "gems", amount = 20, weight = 3 },
		{ id = "skin_piece", name = "스킨 조각", type = "skin_piece", amount = 1, weight = 2 },
	},
}

-- 신기록 임박 알림
GameConstants.NEAR_RECORD = {
	THRESHOLD_RATIO = 0.80,
	PULSE_INTERVAL = 2.0,
}

-- ==================== Phase 2: 게임성 개선 ====================

-- 피버 모드
GameConstants.FEVER = {
	COMBO_THRESHOLD = 50, -- 피버 발동 콤보 수
	DURATION = 5, -- 지속 시간 (초)
	COIN_MULTIPLIER = 3, -- 코인 가치 배율
	SPEED_BOOST = 1.5, -- 속도 배율
	MAGNET_RADIUS = 30, -- 초강력 자석 반경 (studs)
	COOLDOWN = 10, -- 피버 종료 후 재발동 쿨타임 (초)
	INVINCIBLE = true, -- 무적 여부
}

-- 퍼펙트 런 (무피격 보너스)
GameConstants.PERFECT_RUN = {
	MILESTONES = {
		{ distance = 500, bonus = 100, title = "무피격 500m!" },
		{ distance = 1000, bonus = 300, title = "불사신!" },
	},
}

-- 니어미스 연속 체인 보너스
GameConstants.NEAR_MISS_CHAIN = {
	CHAIN_TIMEOUT = 3, -- 체인 리셋 시간 (초)
	GRADES = {
		{ count = 1, bonus = 5, text = "Close!" },
		{ count = 2, bonus = 10, text = "NICE!" },
		{ count = 3, bonus = 20, text = "PERFECT!" },
		{ count = 4, bonus = 30, text = "INSANE!" },
		{ count = 5, bonus = 50, text = "GODLIKE!" },
	},
}

-- ==================== Phase B: 게임성 다양화 ====================

-- Zone 테마 (시간 기반 전환)
GameConstants.ZONE_THEMES = {
	{
		name = "Meadow",
		displayName = "초원",
		startTime = 0,
		floorColor = Color3.fromRGB(80, 80, 90),
		railColor = Color3.fromRGB(150, 150, 160),
		treeLeafColor = Color3.fromRGB(34, 139, 34),
		treeTrunkColor = Color3.fromRGB(101, 67, 33),
		hillColor = Color3.fromRGB(80, 150, 80),
		skyAmbient = Color3.fromRGB(135, 206, 235),
		clockTime = 14,
	},
	{
		name = "FlowerPath",
		displayName = "꽃길",
		startTime = 60,
		floorColor = Color3.fromRGB(180, 140, 160),
		railColor = Color3.fromRGB(220, 180, 200),
		treeLeafColor = Color3.fromRGB(255, 150, 200),
		treeTrunkColor = Color3.fromRGB(120, 80, 60),
		hillColor = Color3.fromRGB(200, 160, 180),
		skyAmbient = Color3.fromRGB(255, 200, 220),
		clockTime = 15,
	},
	{
		name = "MushroomWood",
		displayName = "버섯숲",
		startTime = 120,
		floorColor = Color3.fromRGB(70, 60, 50),
		railColor = Color3.fromRGB(120, 100, 80),
		treeLeafColor = Color3.fromRGB(180, 80, 180),
		treeTrunkColor = Color3.fromRGB(80, 50, 30),
		hillColor = Color3.fromRGB(100, 80, 60),
		skyAmbient = Color3.fromRGB(160, 140, 180),
		clockTime = 17,
	},
	{
		name = "Sunset",
		displayName = "석양",
		startTime = 180,
		floorColor = Color3.fromRGB(120, 80, 50),
		railColor = Color3.fromRGB(180, 120, 60),
		treeLeafColor = Color3.fromRGB(200, 100, 30),
		treeTrunkColor = Color3.fromRGB(60, 30, 10),
		hillColor = Color3.fromRGB(150, 90, 40),
		skyAmbient = Color3.fromRGB(255, 140, 50),
		clockTime = 18.5,
	},
	{
		name = "Starlight",
		displayName = "별빛",
		startTime = 240,
		floorColor = Color3.fromRGB(30, 30, 50),
		railColor = Color3.fromRGB(80, 80, 120),
		treeLeafColor = Color3.fromRGB(40, 60, 100),
		treeTrunkColor = Color3.fromRGB(30, 20, 40),
		hillColor = Color3.fromRGB(20, 20, 40),
		skyAmbient = Color3.fromRGB(20, 20, 50),
		clockTime = 22,
	},
}

-- 이벤트 청크
GameConstants.EVENT_CHUNKS = {
	COIN_RUSH = {
		MIN_TIME = 90, -- 90초 이후 출현 가능
		CHANCE = 0.05, -- 청크당 5% 확률
		COIN_COUNT = 30, -- 코인 대량 배치
	},
	GIANT_COIN = {
		MIN_TIME = 120, -- 120초 이후
		CHANCE = 0.03, -- 3% 확률
		REWARD = 100, -- 획득 시 100점
		HEIGHT = 12, -- 높은 위치 (2단 점프 필요)
		SIZE = 8, -- 일반 코인의 ~4배 크기
	},
	COOLDOWN = 30, -- 이벤트 간 최소 간격 (초)
}

-- ==================== 재미 요소 강화 ====================

-- 생존 배율 시스템 (무피격 지속 시 거리 점수 배율 증가)
GameConstants.SURVIVAL_MULTIPLIER = {
	-- 무피격 지속 시간별 배율 단계 (오름차순)
	TIERS = {
		{ minTime = 30,  multiplier = 1.5, label = "🔥 x1.5!" },
		{ minTime = 60,  multiplier = 2.0, label = "⚡ x2.0!" },
		{ minTime = 120, multiplier = 3.0, label = "💎 x3.0!" },
	},
}

-- 피격 후 코인 러시 (피격 직후 무적 구간 코인 5배)
GameConstants.HIT_RECOVERY = {
	RUSH_DURATION = 3,    -- 지속 시간 (초, 무적 시간과 동일)
	COIN_MULTIPLIER = 5,  -- 코인 배율
}

-- 슈퍼 피버 (피버 2연속 시 강화 피버)
GameConstants.SUPER_FEVER = {
	CHAIN_WINDOW = 15,   -- 피버 종료 후 이 시간 내 재발동 시 슈퍼 피버 (초)
	DURATION = 8,        -- 지속 시간 (초)
	COIN_MULTIPLIER = 5, -- 코인 배율
	SPEED_BOOST = 1.8,   -- 속도 배율
	MAGNET_RADIUS = 40,  -- 자석 반경 (studs)
}

return GameConstants

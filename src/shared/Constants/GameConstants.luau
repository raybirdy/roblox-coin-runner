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
	SPEED_RAMP_TIME = 150, -- 최대 속도 도달 시간 (초) - 2.5분 (더 긴 진행감)
}

-- 청크 시스템
GameConstants.CHUNK = {
	LENGTH = 80, -- 청크 길이 (studs)
	HEIGHT = 40, -- 청크 높이 (studs)
	MAX_LOADED = 6, -- 동시 로드 최대 청크 수 (더 많이 미리 로드)
	MIN_AHEAD_DISTANCE = 200, -- 플레이어 앞에 최소 이 거리만큼 청크 유지 (studs)
	DELETE_DISTANCE = 100, -- 캐릭터 뒤 이 거리 초과 시 청크 삭제
	SAFE_ZONE_CHUNKS = 2, -- 시작 안전 구역 (처음 4개 청크는 장애물 없음)

	-- 높이 태그
	HEIGHT_LOW = 0,
	HEIGHT_MID = 6,
	HEIGHT_HIGH = 12,
}

-- 2층 분기 맵 (IDEA-003)
GameConstants.DUAL_FLOOR = {
	FLOOR2_Y = 8, -- 2층 바닥 높이 (studs, 1층 기준) — 기존 10 → 8 (ISSUE-030)
	RAMP_LENGTH = 18, -- 진입 경사로 길이 (studs) — 기존 8 → 18, 경사각 51° → 24° (ISSUE-030)
	PLATFORM_LENGTH = 60, -- 2층 플랫폼 유지 길이 (studs, 총 80 중)
	SPAWN_CHANCE = 0.10, -- 출현 확률 (10%)
	MIN_ELAPSED_TIME = 30, -- 최소 경과 시간 (초)
	COIN_Y_OFFSET = 4, -- 2층 코인 높이 오프셋 (바닥 위 studs)
	COIN_COUNT = 15, -- 2층 코인 개수
}

-- 다중 높이 플랫폼 (IDEA-013)
GameConstants.MULTI_LANE = {
	HIGH_LANE_Y = 12,       -- HIGH 레인 높이 (studs, HEIGHT_HIGH와 일치)
	RAMP_LENGTH = 20,        -- 진입 경사로 길이 (WedgePart, DualFloor보다 약간 길게)
	PLATFORM_LENGTH = 55,    -- HIGH 레인 플랫폼 유지 길이 (studs, 총 80 중)
	PLATFORM_WIDTH = 12,     -- HIGH 레인 너비 (일반 바닥 20보다 좁게 — 고위험/고보상)
	SPAWN_CHANCE = 0.07,     -- 출현 확률 (7%, DualFloor보다 낮음)
	MIN_ELAPSED_TIME = 45,   -- 최소 경과 시간(초, DualFloor보다 늦게)
	COIN_Y_OFFSET = 4,       -- HIGH 레인 코인 높이 오프셋
	COIN_COUNT = 20,         -- HIGH 레인 코인 개수 (DualFloor 15보다 많음 — 위험 보상)
}

-- 청크 전환 연출 (IDEA-012)
GameConstants.CHUNK_TRANSITION = {
	BEZIER_SEGMENTS = 3, -- 경사로 분할 파트 수
	GATE_HEIGHT = 4,     -- 전환 게이트 높이 (studs)
	RAMP_COLLIDE = false, -- 경사로 CanCollide (시각 전용)
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
	-- 60~90초 (Zone 2 초반 — Normal 중심, Hard 도입 시작)
	{
		maxTime = 90,
		Easy = 0.25,
		Normal = 0.40,
		Hard = 0.15,
		Bonus = 0.10,
		NPC = 0.10,
	},
	-- 90~120초 (Zone 2 후반 — Hard 비율 상승)
	{
		maxTime = 120,
		Easy = 0.15,
		Normal = 0.40,
		Hard = 0.25,
		Bonus = 0.10,
		NPC = 0.10,
	},
	-- 120~180초 (Zone 3 — 신규 장애물 등장, Hard 균형)
	{
		maxTime = 180,
		Easy = 0.10,
		Normal = 0.35,
		Hard = 0.35,
		Bonus = 0.10,
		NPC = 0.10,
	},
	-- 180~240초 (Zone 4 — LaserBeam 등장, Hard 강화)
	{
		maxTime = 240,
		Easy = 0.05,
		Normal = 0.28,
		Hard = 0.42,
		Bonus = 0.12,
		NPC = 0.13,
	},
	-- 240초+ (Zone 5 — 최고 난이도)
	{
		maxTime = math.huge,
		Easy = 0.03,
		Normal = 0.25,
		Hard = 0.47,
		Bonus = 0.12,
		NPC = 0.13,
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
-- ActionHint 패턴(action_*)은 장애물 타입 감지 시 _selectPattern에서 직접 주입되며 여기서는 제외
GameConstants.COIN_PATTERNS = {
	EASY = { "line", "arc", "spread", "shape_diamond", "shape_heart" },
	NORMAL = { "line", "arc", "zigzag", "step_up", "step_down", "wave", "shape_arrow_up", "shape_diamond" },
	HARD = { "zigzag", "step_up", "step_down", "corridor", "wave", "swoop", "shape_arrow_up", "shape_arrow_down" },
	BONUS = { "line", "arc", "double_line", "spread", "shape_heart", "shape_star" },
	NPC = { "line", "spread", "shape_diamond" },
}

-- 코인 개수 (난이도별, ActionHint + Leading Coins + 스킬루트 코인 추가분 반영 후 조정)
-- Phase 4 밸런스 패스: 기본 패턴 소폭 감소, 총 코인량은 이전 대비 +5~15% 유지
GameConstants.COIN_COUNTS = {
	EASY   = { min = 7, max = 10 }, -- 8~12 → 7~10 (Easy에는 힌트코인 없으므로 소폭만 감소)
	NORMAL = { min = 4, max = 6 },  -- 5~7  → 4~6  (ActionHint 3~5개 + 리딩코인 2개 추가)
	HARD   = { min = 3, max = 5 },  -- 4~6  → 3~5  (ActionHint + 스킬루트 + 리딩코인 포함)
	BONUS  = { min = 12, max = 18 }, -- 변경 없음
	NPC    = { min = 3, max = 4 },   -- 변경 없음
}

-- 코인 밀도 리듬 (긴장-이완 구조: N번째 청크마다 코인 폭발)
GameConstants.COIN_RHYTHM = {
	DENSE_EVERY = 4, -- 4번째 Normal/Hard 청크마다 밀집 구간
	DENSE_MULTIPLIER = 2.0, -- 밀집 구간 코인 2배
	DENSE_MAX = 14, -- 최대 코인 수 (너무 많으면 렉)
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

-- 코인 시각 강조 (ISSUE-032, Sprint 14)
GameConstants.COIN_GLOW = {
	OUTLINE_COLOR       = Color3.fromRGB(255, 220, 80),  -- Highlight 외곽선
	OUTLINE_TRANSPARENCY = 0,
	FILL_TRANSPARENCY   = 1,                              -- Fill 없음 (외곽선만)
	LIGHT_BRIGHTNESS    = 0.5,
	LIGHT_RANGE         = 8,
	LIGHT_COLOR         = Color3.fromRGB(255, 220, 100),
	BURST_CHANCE        = 0.1,                            -- 수집 시 파티클 버스트 확률
	BURST_PARTICLES     = 8,                              -- 버스트 당 파티클 수
}

-- 특수 효과 코인 (ISSUE-033, Sprint 15) — Star/Magnet/Rainbow 3종
GameConstants.SPECIAL_COINS = {
	-- 스폰 확률 (일반 코인 88% : Star 5% : Magnet 4% : Rainbow 3%) — momus 조정 (콤보 시스템 보호)
	SPAWN_CHANCES = {
		Star    = 0.05,
		Magnet  = 0.04,
		Rainbow = 0.03,
	},
	-- Star ⭐ — 콤보 +5 즉시 (피버 촉진)
	STAR = {
		COLOR       = Color3.fromRGB(255, 240, 100),
		GLOW_COLOR  = Color3.fromRGB(255, 255, 180),
		EMOJI       = "⭐",
		COMBO_BONUS = 5,
		VALUE       = 5,
	},
	-- Magnet 🧲 — 3초간 자동수집 범위 2×
	MAGNET = {
		COLOR         = Color3.fromRGB(255, 90, 90),
		GLOW_COLOR    = Color3.fromRGB(255, 140, 140),
		EMOJI         = "🧲",
		DURATION      = 3,
		MULTIPLIER    = 2,
		VALUE         = 5,
	},
	-- Rainbow 🌈 — 2초간 수집 코인 점수 2×
	RAINBOW = {
		COLOR         = Color3.fromRGB(150, 220, 255),
		GLOW_COLOR    = Color3.fromRGB(255, 200, 255),
		EMOJI         = "🌈",
		DURATION      = 2,
		SCORE_MULTIPLIER = 2,
		VALUE         = 5,
	},
}

-- 장애물 경고 연출 (ISSUE-032, Sprint 14)
GameConstants.OBSTACLE_WARNING = {
	OUTLINE_COLOR        = Color3.fromRGB(255, 80, 40),   -- 주황/빨강 경고 외곽선
	OUTLINE_TRANSPARENCY = 0.2,
	FILL_TRANSPARENCY    = 1,
	MOVING_LIGHT_COLOR   = Color3.fromRGB(255, 60, 60),   -- 이동 장애물 경고등
	MOVING_LIGHT_BRIGHTNESS = 1.5,
	MOVING_LIGHT_RANGE   = 10,
	MOVING_BLINK_CYCLE   = 0.6,                           -- 깜빡임 주기 (초)
}

-- 추격 NPC (Chase Mob) — 60초 이후 Hard 청크에서 등장
-- 플레이어 뒤에서 따라오며, 피버 속도로 따돌릴 수 있음
GameConstants.CHASE_MOB = {
	SPAWN_CHANCE = 0.25, -- Hard 청크에서 25% 확률 (0.15→0.25, 더 자주 등장)
	MIN_TIME = 40, -- 40초 이후부터 등장 가능 (60→40, 일찍 등장)
	SPAWN_OFFSET_X = -20, -- 플레이어 뒤 20 studs에서 스폰
	SPEED_OFFSET = -6, -- 플레이어 추정 속도보다 6 studs/s 느림 (-8→-6, 조금 더 위협적)
	CATCH_DISTANCE = 3, -- 이 거리 이하 접근 시 피격
	ESCAPE_DISTANCE = 40, -- 이 거리 이상 벌어지면 사라짐 (피버 탈출)
	DURATION = 8, -- 최대 8초 후 자동 사라짐
	COLOR = Color3.fromRGB(220, 60, 60), -- 빨간 미니언 색상
	SIZE = Vector3.new(3, 4, 3), -- 몸통 크기 (2,2,2→3,4,3, 더 위협적인 외형)
	UPDATE_INTERVAL = 0.1, -- 위치 업데이트 간격 (초)
}

-- 폭발 배럴 (Exploding Barrel) — Normal/Hard 청크에서 등장
-- 닿으면 범위 피해 (반경 4 studs 내 플레이어 피격)
GameConstants.EXPLODING_BARREL = {
	NORMAL_CHANCE = 0.20, -- Normal 청크에서 20% 확률로 배럴 타입 선택
	HARD_CHANCE = 0.30, -- Hard 청크에서 30% 확률로 배럴 타입 선택
	EXPLOSION_RADIUS = 4, -- 폭발 반경 (studs)
	COLOR = Color3.fromRGB(200, 50, 50), -- 빨간 배럴 색상
	SIZE = Vector3.new(2, 3, 2), -- 원통형(Part) 크기
	WARNING_DURATION = 0.5, -- 경고 이펙트 지속 시간 (초)
	LIGHT_BRIGHTNESS = 2, -- PointLight 밝기
	LIGHT_RANGE = 8, -- PointLight 범위 (studs)
}

-- 라이프 시스템
GameConstants.LIFE = {
	STARTING_LIVES = 3,
	MAX_TOTAL = 8, -- maximum total lives including all bonuses
	INVINCIBLE_DURATION = 3, -- 피격 후 무적 시간 (초)
	MERCY_CHUNK_THRESHOLD = 2, -- 연속 피격 2회 시 자비 청크
	MERCY_CHUNK_COUNT = 2, -- 자비 모드 시 연속 쉬운 청크 수
}

-- 위로 보상
GameConstants.CONSOLATION = {
	THRESHOLD = 2, -- 2회 연속 빠른 게임오버 시 위로 보상 (3→2, 더 빠른 위로)
	REWARD_COINS = 50, -- 보상 코인 (20→50, 더 의미 있는 보상)
	QUICK_DEATH_SCORE = 100, -- 이 점수 미만이면 "빠른 게임오버"
	REWARD_SHIELD = true, -- 위로 보상 시 다음 런 시작에 쉴드 파워업 1개 지급
}

-- 점수 시스템
GameConstants.SCORE = {
	DISTANCE_MULTIPLIER = 1, -- 1 stud = 1 점
	NEAR_MISS_BONUS = 5,
	COMBO_10_BONUS = 10, -- (레거시, 하위호환용)
	COMBO_30_BONUS = 30,
	COMBO_50_BONUS = 50,
	COMBO_TIMEOUT = 3, -- 콤보 리셋 시간 (초) - 6~8세 반응속도 고려
}

-- 콤보 실시간 배율 시스템 (마일스톤 보너스를 대체/보강)
-- 코인 수집 시 comboCount에 따라 배율 적용
GameConstants.COMBO_MULTIPLIER = {
	TIERS = {
		{ threshold = 5,  multiplier = 1.5 },
		{ threshold = 15, multiplier = 2.0 },
		{ threshold = 30, multiplier = 3.0 },
		{ threshold = 50, multiplier = 5.0 },
	},
	DEFAULT_MULTIPLIER = 1.0,
	RESET_ON_HIT = true, -- 피격 시 콤보 리셋 + 배율 초기화
}

-- 파워업 (자석, 쉴드, 무적, 2배코인, 미니사이즈)
GameConstants.POWERUP = {
	MAGNET_DURATION = 5, -- 자석 지속 시간 (초)
	MAGNET_RADIUS = 15, -- 자석 흡수 반경 (studs)
	SHIELD_USES = 1, -- 쉴드 사용 횟수
	INVINCIBLE_DURATION = 5, -- 무적 지속 시간 (초)
	DOUBLE_COIN_DURATION = 8, -- 2배 코인 지속 시간 (초)
	MINI_SIZE_DURATION = 5, -- 미니 사이즈 지속 시간 (초)
	MIN_SPAWN_TIME = 20, -- 첫 파워업 등장 시간 (초) - 더 빠르게 (20→12)
	MIN_INTERVAL = 15, -- 파워업 간 최소 간격 (초) - 더 자주 (15→10)

	-- 출현 확률 (합계 1.0)
	MAGNET_RATE = 0.35,
	SHIELD_RATE = 0.22,
	INVINCIBLE_RATE = 0.18,
	DOUBLE_COIN_RATE = 0.16,
	MINI_SIZE_RATE = 0.09,
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
	TOTAL_STEPS = 5,
	STEPS = {
		[1] = {
			id = "move_and_collect",
			triggerRun = 1,
			completionType = "coin_collect",
			completionTarget = 5,
			npcMessage = "Hi! I'm Coiny! Run and collect coins!",
			highlightTarget = "coins",
		},
		[2] = {
			id = "jump_obstacle",
			triggerRun = 2,
			completionType = "action",
			completionAction = "jump",
			npcMessage = "Obstacle ahead! Jump to dodge! Tap or Swipe Up!",
			highlightTarget = "jump_button",
		},
		[3] = {
			id = "slide_obstacle",
			triggerRun = 3,
			completionType = "action",
			completionAction = "slide",
			npcMessage = "Low obstacle! Slide under it! Swipe Down!",
			highlightTarget = "slide_button",
		},
		[4] = {
			id = "powerup_magnet",
			triggerRun = 4,
			completionType = "powerup_collect",
			completionTarget = "magnet",
			npcMessage = "Shiny item! Grab it and coins fly to you!",
			highlightTarget = "powerup",
		},
		[5] = {
			id = "coop_portal",
			triggerRun = 5,
			completionType = "portal_interact",
			npcMessage = "Run with friends! Find the Co-op Portal!",
			highlightTarget = "coop_portal",
		},
	},
	NPC_NAME = "Coiny",
	NPC_TOUCH_SIZE_MIN = 100,
	SKIP_BUTTON_DELAY = 2,
}

-- UI
GameConstants.UI = {
	TOUCH_BUTTON_SIZE = 130, -- 모바일 버튼 크기 (px) - 6~12세 대상 큰 버튼
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
			material = "SmoothPlastic",
			trail = false,
		},
		-- 코인 스킨 (누구나 접근 가능)
		{
			id = "red_hat",
			name = "레드",
			price = 100,
			currency = "coins",
			color = Color3.fromRGB(220, 50, 50),
			thumbnailId = "rbxassetid://3535928917",
			material = "SmoothPlastic",
			trail = false,
		},
		{
			id = "ninja",
			name = "미드나잇",
			price = 150,
			currency = "coins",
			color = Color3.fromRGB(30, 30, 50),
			thumbnailId = "rbxassetid://3535929309",
			material = "Metal",
			trail = false,
		},
		{
			id = "blue_cape",
			name = "로얄블루",
			price = 200,
			currency = "coins",
			color = Color3.fromRGB(50, 100, 220),
			thumbnailId = "rbxassetid://3535929635",
			material = "SmoothPlastic",
			trail = false,
		},
		{
			id = "pirate",
			name = "브라운",
			price = 300,
			currency = "coins",
			color = Color3.fromRGB(100, 60, 30),
			thumbnailId = "rbxassetid://3535929876",
			material = "Wood",
			trail = false,
		},
		{
			id = "robot",
			name = "스틸",
			price = 400,
			currency = "coins",
			color = Color3.fromRGB(160, 170, 180),
			thumbnailId = "rbxassetid://3535930077",
			material = "Metal",
			trail = false,
		},
		{
			id = "golden",
			name = "골든",
			price = 500,
			currency = "coins",
			color = Color3.fromRGB(255, 215, 0),
			thumbnailId = "rbxassetid://3535930233",
			material = "Neon",
			trail = false,
		},
		-- 프리미엄 스킨 (젬으로 구매 - Neon 재질 + 트레일 효과)
		{
			id = "galaxy",
			name = "갤럭시",
			price = 80,
			currency = "gems",
			color = Color3.fromRGB(60, 20, 120),
			thumbnailId = "rbxassetid://3535936432",
			material = "Neon",
			trail = true,
			trailColor = Color3.fromRGB(100, 50, 200),
		},
		{
			id = "unicorn",
			name = "유니콘",
			price = 100,
			currency = "gems",
			color = Color3.fromRGB(255, 180, 255),
			thumbnailId = "rbxassetid://3535936633",
			material = "Neon",
			trail = true,
			trailColor = Color3.fromRGB(255, 100, 255),
		},
		{
			id = "ice_king",
			name = "아이스",
			price = 150,
			currency = "gems",
			color = Color3.fromRGB(150, 220, 255),
			thumbnailId = "rbxassetid://3535936812",
			material = "Neon",
			trail = true,
			trailColor = Color3.fromRGB(100, 200, 255),
		},
		{
			id = "dragon",
			name = "파이어",
			price = 200,
			currency = "gems",
			color = Color3.fromRGB(200, 50, 0),
			thumbnailId = "rbxassetid://3535937071",
			material = "Neon",
			trail = true,
			trailColor = Color3.fromRGB(255, 80, 0),
		},
		{
			id = "rainbow",
			name = "레인보우",
			price = 300,
			currency = "gems",
			color = Color3.fromRGB(255, 100, 200),
			thumbnailId = "rbxassetid://3535937245",
			material = "Neon",
			trail = true,
			trailColor = Color3.fromRGB(255, 100, 200),
		},
		{
			id = "shadow",
			name = "쉐도우",
			price = 400,
			currency = "gems",
			color = Color3.fromRGB(20, 20, 30),
			thumbnailId = "rbxassetid://3535937404",
			material = "Metal",
			trail = false,
		},
		-- 번들 전용 스킨 (MEGA/ULTRA BUNDLE에서만 획득 가능)
		{
			id = "galaxy_runner",
			name = "갤럭시 러너",
			price = 0,
			currency = "bundle", -- bundle-only: obtainable via mega_bundle purchase
			color = Color3.fromRGB(80, 0, 180),
			thumbnailId = "rbxassetid://3535936432",
			material = "Neon",
			trail = true,
			trailColor = Color3.fromRGB(150, 0, 255),
		},
		{
			id = "cosmic_king",
			name = "코스믹 킹",
			price = 0,
			currency = "bundle", -- bundle-only: obtainable via ultra_bundle purchase
			color = Color3.fromRGB(10, 10, 40),
			thumbnailId = "rbxassetid://3535937245",
			material = "Neon",
			trail = true,
			trailColor = Color3.fromRGB(200, 50, 255),
		},
		-- 시즌 한정 스킨 (봄 2026 시즌, ~2026-04-30)
		{
			id = "cherry_blossom",
			name = "벚꽃",
			price = 150,
			currency = "gems",
			color = Color3.fromRGB(255, 183, 197),
			thumbnailId = "rbxassetid://3535936633",
			material = "SmoothPlastic",
			trail = true,
			trailColor = Color3.fromRGB(255, 160, 200),
			availableUntil = os.time({ year = 2026, month = 4, day = 30, hour = 23, min = 59, sec = 59 }),
		},
		{
			id = "spring_fairy",
			name = "봄 요정",
			price = 0,
			currency = "pieces",
			color = Color3.fromRGB(144, 238, 144),
			thumbnailId = "rbxassetid://3535936812",
			material = "Neon",
			trail = true,
			trailColor = Color3.fromRGB(100, 255, 150),
			availableUntil = os.time({ year = 2026, month = 4, day = 30, hour = 23, min = 59, sec = 59 }),
		},
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
		{ id = "starter_pack", productId = 3540343511, gems = 150, robux = 49, bonus = 0, bundlePet = "hamster" },
		{
			id = "mega_bundle",
			productId = 3559214777,
			gems = 1500,
			robux = 499,
			bonus = 500, -- display: "2000 gems = 1500 + 500 bonus"
			bundlePet = "phoenix",
			bundleSkin = "galaxy_runner",
			bundleNametag = "frame_diamond",
			label = "MEGA BUNDLE",
			highlight = "BEST VALUE",
		},
		{
			id = "ultra_bundle",
			productId = 3559214994,
			gems = 4000,
			robux = 999,
			bonus = 1500, -- display: "5500 gems = 4000 + 1500 bonus"
			bundlePet = "dragon",
			bundleSkin = "cosmic_king",
			bundleNametag = "frame_rainbow",
			bundleCharacter = "robot",
			label = "ULTRA BUNDLE",
			highlight = "ULTIMATE",
		},
	},
	-- GamePass (VIP)
	VIP_GAMEPASS_ID = 1720352633,
	VIP_BENEFITS = {
		coinMultiplier = 2, -- 코인 획득 2배
		badge = "VIP",
		extraLife = 1, -- 런 시작 시 추가 라이프 1개
		freeRevive = true, -- 런당 무료 부활 1회
		dailyGems = 15, -- 매일 로그인 시 젬 15개 지급
		exclusiveSkin = "vip_crown", -- VIP 전용 스킨 ID
		spinDiscount = 0.5, -- 럭키 스핀 추가 구매 50% 할인
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
	-- 레벨별 필요 XP (Lv1~20: 하드코딩, Lv21+: 동적 공식 math.floor(100 * level^1.4))
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
		30000, -- Lv20 → Lv21
	},
	MAX_LEVEL = 50,
	-- XP 획득량
	XP_PER_GAME = 10, -- 게임 1회 참여
	XP_PER_SCORE_100 = 5, -- 점수 100점당 XP
	XP_PER_MISSION = 30, -- 미션 완료 시 XP
	XP_PER_ACHIEVEMENT = 50, -- 업적 완료 시 XP
	XP_PER_FEVER = 20, -- 피버 달성 시 XP (신규)
	-- 레벨업 기본 보상 (레벨당 코인)
	LEVEL_UP_COIN_REWARD = 50,
	-- 마일스톤 레벨 (5 단위마다 젬 보상)
	MILESTONE_LEVELS = { 5, 10, 15, 20, 25, 30, 35, 40, 45, 50 },
	MILESTONE_GEM_REWARD = 10,
	-- 특별 보상 레벨 (마일스톤 젬 외 추가 보상)
	SPECIAL_REWARDS = {
		[15] = { gems = 30 }, -- 마법사 캐릭터 해금 조건 (CharacterService가 처리)
		[20] = { coins = 500, gems = 30 },
		[30] = { coins = 1000, gems = 50 },
		[40] = { coins = 2000, gems = 80 },
		[50] = { coins = 5000, gems = 100 },
	},
	-- 칭호 (레벨 구간별, minLevel 이상이면 해당 칭호 적용)
	TITLES = {
		{ minLevel = 1,  title = "초보 달리기꾼" },
		{ minLevel = 10, title = "코인 사냥꾼" },
		{ minLevel = 20, title = "피버 마스터" },
		{ minLevel = 30, title = "존 탐험가" },
		{ minLevel = 40, title = "코인 킹" },
		{ minLevel = 50, title = "전설의 러너" },
	},
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
		-- 캐릭터 해금 퀘스트
		{
			id = "obstacles_dodged_500",
			name = "용맹한 기사",
			desc = "장애물 500개 회피",
			target = 500,
			condition = "obstacles_dodged",
			rewardGems = 0,
			rewardXP = 0,
			unlocksCharacter = "knight",
		},
	},
}

-- ==================== v3: 캐릭터 시스템 ====================

GameConstants.CHARACTERS = {
	-- { id, name, desc, unlockType, unlockRef? }
	-- unlockType: "default" | "achievement" | "season_pass"
	LIST = {
		{
			id = "default",
			name = "코인 러너",
			desc = "기본 캐릭터",
			unlockType = "default",
		},
		{
			id = "knight",
			name = "용맹한 기사",
			desc = "장애물 500개 회피 달성 시 해금",
			unlockType = "achievement",
			unlockRef = "obstacles_dodged_500",
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
	COMBO_THRESHOLD = 40, -- 피버 발동 콤보 수 (30→40: 희귀성 회복, ISSUE-031)
	DURATION = 6, -- 지속 시간 (초)
	COIN_MULTIPLIER = 3, -- 코인 가치 배율
	SPEED_BOOST = 1.5, -- 속도 배율
	MAGNET_RADIUS = 30, -- 초강력 자석 반경 (studs)
	COOLDOWN = 0, -- 피버 쿨타임 제거 — 순수 콤보 달성 기반 (피버 종료 후 콤보 리셋, 다시 N개 연속 수집해야 재발동)
	INVINCIBLE = true, -- 무적 여부
}

-- 미니 피버 (워밍업 → 피버 흐름의 중간 단계)
GameConstants.MINI_FEVER = {
	COMBO_THRESHOLD = 20, -- 미니 피버 발동 콤보 수 (15→20: ISSUE-031)
	DURATION = 3, -- 지속 시간 (초)
	COIN_MULTIPLIER = 2, -- 코인 가치 2배
	MAGNET = true, -- 자석 효과 (기본 반경)
	MAGNET_RADIUS = 20, -- 자석 반경 (studs)
	COOLDOWN = 0, -- 쿨타임 제거 — 피버와 동일하게 콤보 리셋 후 재달성 방식
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
		fogColor = Color3.fromRGB(180, 220, 240),
		fogStart = 800,
		fogEnd = 1000,
		decoration = "grass",
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
		fogColor = Color3.fromRGB(255, 200, 220),
		fogStart = 200,
		fogEnd = 420,
		decoration = "none",
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
		fogColor = Color3.fromRGB(100, 60, 130),
		fogStart = 80,
		fogEnd = 260,
		decoration = "none",
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
		fogColor = Color3.fromRGB(220, 100, 30),
		fogStart = 150,
		fogEnd = 380,
		decoration = "none",
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
		fogColor = Color3.fromRGB(10, 10, 40),
		fogStart = 60,
		fogEnd = 200,
		decoration = "stars",
	},
}

-- Zone-specific decorative prop palettes (IDEA-009)
-- 각 prop: type(string), color(Color3), weight(number)
-- type에 따라 ProceduralChunkGenerator._addZoneProps()에서 생성 방법 결정
GameConstants.ZONE_PROP_PALETTES = {
	Meadow = {
		{ propType = "flower",    color = Color3.fromRGB(255, 100, 150), weight = 4 },
		{ propType = "flower",    color = Color3.fromRGB(255, 220, 60),  weight = 3 },
		{ propType = "grassTuft", color = Color3.fromRGB(80, 180, 60),   weight = 3 },
		{ propType = "woodPost",  color = Color3.fromRGB(160, 110, 60),  weight = 1 },
	},
	FlowerPath = {
		{ propType = "flower",    color = Color3.fromRGB(255, 120, 200), weight = 4 },
		{ propType = "flower",    color = Color3.fromRGB(200, 100, 255), weight = 3 },
		{ propType = "grassTuft", color = Color3.fromRGB(100, 200, 80),  weight = 2 },
		{ propType = "stone",     color = Color3.fromRGB(180, 170, 160), weight = 1 },
	},
	MushroomWood = {
		{ propType = "mushroom",  color = Color3.fromRGB(220, 60, 40),   weight = 4 },
		{ propType = "mushroom",  color = Color3.fromRGB(200, 160, 50),  weight = 3 },
		{ propType = "log",       color = Color3.fromRGB(130, 90, 50),   weight = 2 },
		{ propType = "stone",     color = Color3.fromRGB(150, 140, 130), weight = 1 },
	},
	Sunset = {
		{ propType = "lantern",   color = Color3.fromRGB(255, 160, 60),  weight = 3 },
		{ propType = "pillar",    color = Color3.fromRGB(200, 180, 140), weight = 2 },
		{ propType = "stone",     color = Color3.fromRGB(180, 160, 130), weight = 2 },
		{ propType = "woodPost",  color = Color3.fromRGB(140, 100, 60),  weight = 1 },
	},
	Starlight = {
		{ propType = "crystal",   color = Color3.fromRGB(140, 180, 255), weight = 4 },
		{ propType = "crystal",   color = Color3.fromRGB(200, 140, 255), weight = 3 },
		{ propType = "glowOrb",   color = Color3.fromRGB(180, 220, 255), weight = 2 },
		{ propType = "stone",     color = Color3.fromRGB(100, 110, 140), weight = 1 },
	},
}

-- Zone Skip Start (챕터 진행 반영)
GameConstants.ZONE_SKIP = {
	MIN_ZONE_TO_UNLOCK = 2, -- maxZoneReached >= 2 이상이어야 스킵 옵션 활성화
	-- skipToZone = math.max(1, maxZoneReached - 1) 로 계산
}

-- 이벤트 청크
GameConstants.EVENT_CHUNKS = {
	COIN_RUSH = {
		MIN_TIME = 45, -- 45초 이후 출현 가능 (90→45, 초보 유저도 경험)
		CHANCE = 0.10, -- 청크당 10% 확률 (5%→10%)
		COIN_COUNT = 30, -- 코인 대량 배치
	},
	GIANT_COIN = {
		MIN_TIME = 60, -- 60초 이후 (120→60)
		CHANCE = 0.06, -- 6% 확률 (3%→6%)
		REWARD = 100, -- 획득 시 100점
		HEIGHT = 12, -- 높은 위치 (2단 점프 필요)
		SIZE = 8, -- 일반 코인의 ~4배 크기
	},
	COOLDOWN = 20, -- 이벤트 간 최소 간격 (초) (30→20)
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
	CHAIN_WINDOW = 10,   -- 피버 종료 후 이 시간 내 재발동 시 슈퍼 피버 (초)
	DURATION = 8,        -- 지속 시간 (초)
	COIN_MULTIPLIER = 5, -- 코인 배율
	SPEED_BOOST = 1.8,   -- 속도 배율
	MAGNET_RADIUS = 40,  -- 자석 반경 (studs)
}

-- ==================== 데일리 이벤트 ====================

GameConstants.DAILY_EVENT = {
	-- os.date("!*t").wday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
	THEMES = {
		[1] = { -- Sunday
			id = "golden",
			displayName = "황금의 날",
			coinName = "황금 코인",
			coinColor = Color3.fromRGB(255, 200, 50),
			goal = "collect_themed_coins",
			goalTarget = 25,
			goalDesc = "황금 코인 25개 수집",
			rewardType = "coins",
			rewardAmount = 200,
			bonusGems = 8,
			speedModifier = 1.0,
			coinValueBonus = 1.0, -- 2배 가치
		},
		[2] = { -- Monday
			id = "cherry",
			displayName = "체리의 날",
			coinName = "체리 코인",
			coinColor = Color3.fromRGB(220, 30, 60),
			goal = "collect_themed_coins",
			goalTarget = 30,
			goalDesc = "체리 코인 30개 수집",
			rewardType = "coins",
			rewardAmount = 80,
			bonusGems = 3,
			speedModifier = 1.0,
			coinValueBonus = 0,
		},
		[3] = { -- Tuesday
			id = "star",
			displayName = "별의 날",
			coinName = "별 코인",
			coinColor = Color3.fromRGB(255, 215, 80),
			goal = "collect_themed_coins",
			goalTarget = 25,
			goalDesc = "별 코인 25개 수집",
			rewardType = "coins",
			rewardAmount = 100,
			bonusGems = 3,
			speedModifier = 1.0,
			coinValueBonus = 0.2,
		},
		[4] = { -- Wednesday
			id = "speed",
			displayName = "스피드의 날",
			coinName = "번개 코인",
			coinColor = Color3.fromRGB(0, 200, 255),
			goal = "distance_run",
			goalTarget = 800,
			goalDesc = "800m 달리기",
			rewardType = "coins",
			rewardAmount = 80,
			bonusGems = 5,
			speedModifier = 1.15,
			coinValueBonus = 0,
		},
		[5] = { -- Thursday
			id = "heart",
			displayName = "하트의 날",
			coinName = "하트 코인",
			coinColor = Color3.fromRGB(255, 100, 150),
			goal = "collect_themed_coins",
			goalTarget = 35,
			goalDesc = "하트 코인 35개 수집",
			rewardType = "coins",
			rewardAmount = 80,
			bonusGems = 3,
			speedModifier = 1.0,
			coinValueBonus = 0,
		},
		[6] = { -- Friday
			id = "diamond",
			displayName = "다이아의 날",
			coinName = "다이아 코인",
			coinColor = Color3.fromRGB(100, 200, 255),
			goal = "collect_themed_coins",
			goalTarget = 20,
			goalDesc = "다이아 코인 20개 수집",
			rewardType = "gems",
			rewardAmount = 5,
			bonusGems = 5,
			speedModifier = 1.0,
			coinValueBonus = 0.5,
		},
		[7] = { -- Saturday
			id = "rainbow",
			displayName = "무지개의 날",
			coinName = "무지개 코인",
			coinColor = Color3.fromRGB(180, 100, 255),
			goal = "score_reach",
			goalTarget = 2000,
			goalDesc = "2000점 달성",
			rewardType = "coins",
			rewardAmount = 150,
			bonusGems = 5,
			speedModifier = 1.0,
			coinValueBonus = 0.1,
		},
	},
}

-- ==================== 업그레이드 ====================

GameConstants.UPGRADES = {
	BASE_SPEED_CAP = 1.3, -- max speed multiplier from base_speed upgrade (AC-2-8)
	LIST = {
		{
			id = "magnet_range",
			displayName = "자석 범위",
			desc = "자석 흡수 범위가 넓어집니다",
			maxLevel = 8,
			costs = { 100, 200, 400, 800, 1600, 3200, 6400, 12800 },
			values = { 2, 4, 6, 8, 10, 12, 14, 16 }, -- 누적 보너스 studs
		},
		{
			id = "coin_value",
			displayName = "코인 가치",
			desc = "코인 획득 점수가 올라갑니다",
			maxLevel = 8,
			costs = { 200, 500, 1200, 2500, 5000, 10000, 20000, 40000 },
			values = { 5, 10, 15, 22, 30, 40, 50, 60 }, -- 누적 % 증가
		},
		{
			id = "easy_start",
			displayName = "편한 시작",
			desc = "게임 시작 시 쉬운 구간이 늘어납니다",
			maxLevel = 2,
			costs = { 150, 400 },
			values = { 35, 45 }, -- 안전 구간 초
		},
		{
			id = "fever_extend",
			displayName = "피버 연장",
			desc = "피버 지속 시간이 늘어납니다",
			maxLevel = 3,
			costs = { 300, 700, 1500 },
			values = { 0.5, 1.0, 1.5 }, -- 누적 초
		},
		{
			id = "lucky_coins",
			displayName = "행운 코인",
			desc = "실버 코인이 더 자주 등장합니다",
			maxLevel = 8,
			costs = { 250, 600, 1400, 3000, 6000, 12000, 24000, 48000 },
			values = { 5, 10, 15, 22, 30, 38, 46, 54 }, -- 누적 % 확률 증가
		},
		{
			id = "combo_buffer",
			displayName = "콤보 버퍼",
			desc = "코인 콤보 유지 시간이 길어집니다",
			maxLevel = 3,
			costs = { 400, 1000, 2400 },
			values = { 1, 2, 2 }, -- COMBO_TIMEOUT에 추가되는 초 (Lv3: 3→2, 최대 5초로 상한)
		},
		{
			id = "start_boost",
			displayName = "스타트 대시",
			desc = "게임 시작 시 일시적으로 빠르게 달립니다",
			maxLevel = 3,
			costs = { 180, 450, 1100 },
			values = { 3, 5, 8 }, -- 부스트 지속 시간 (초)
		},
		{
			id = "base_speed",
			displayName = "Base Speed",
			emoji = "💨",
			desc = "Increase base running speed",
			maxLevel = 10,
			costs = { 200, 400, 800, 1500, 2800, 5000, 9000, 15000, 22000, 30000 },
			values = { 2, 4, 6, 8, 10, 13, 16, 19, 23, 27 }, -- % increase
		},
		{
			id = "base_jump",
			displayName = "Base Jump",
			emoji = "⬆️",
			desc = "Increase jump height",
			maxLevel = 10,
			costs = { 150, 300, 600, 1200, 2200, 4000, 7000, 12000, 18000, 25000 },
			values = { 2, 4, 6, 8, 10, 12, 14, 16, 18, 20 }, -- % increase
		},
		{
			id = "base_lives",
			displayName = "Base Lives",
			emoji = "❤️",
			desc = "Start with extra lives",
			maxLevel = 10,
			costs = { 500, 1000, 2000, 4000, 7500, 13000, 20000, 30000, 42000, 55000 },
			values = { 1, 1, 1, 2, 2, 2, 3, 3, 3, 4 }, -- absolute extra lives
		},
		{
			id = "skill_cooldown",
			displayName = "Fever Recovery",
			emoji = "🔥",
			desc = "Reduce fever cooldown time",
			maxLevel = 10,
			costs = { 300, 600, 1200, 2200, 4000, 7000, 12000, 18000, 26000, 35000 },
			values = { 3, 6, 9, 12, 15, 18, 21, 24, 27, 30 }, -- % cooldown reduction
		},
		{
			id = "mini_game_bonus",
			displayName = "Mini Game Bonus",
			emoji = "🎮",
			desc = "Increase mini game rewards",
			maxLevel = 10,
			costs = { 200, 400, 800, 1500, 2800, 5000, 8500, 14000, 20000, 28000 },
			values = { 5, 10, 15, 20, 25, 30, 35, 40, 45, 50 }, -- % bonus
		},
	},
}

-- ==================== 런 목표 ====================

GameConstants.RUN_OBJECTIVES = {
	COUNT = 3,
	COMPLETION_BONUS_MIN = 50,
	COMPLETION_BONUS_MAX = 80,
	REROLL_COST = 30, -- 목표 리롤 비용 (코인)
	POOL = {
		{ id = "collect_coins_15",  desc = "코인 15개 수집",   condition = "coins_collected",  target = 15,   weight = 20, tier = "easy" },
		{ id = "collect_coins_30",  desc = "코인 30개 수집",   condition = "coins_collected",  target = 30,   weight = 15, tier = "normal" },
		{ id = "collect_coins_50",  desc = "코인 50개 수집",   condition = "coins_collected",  target = 50,   weight = 8,  tier = "hard" },
		{ id = "run_200m",          desc = "200m 달리기",      condition = "distance",          target = 200,  weight = 18, tier = "easy" },
		{ id = "run_500m",          desc = "500m 달리기",      condition = "distance",          target = 500,  weight = 12, tier = "normal" },
		{ id = "run_1000m",         desc = "1000m 달리기",     condition = "distance",          target = 1000, weight = 5,  tier = "hard" },
		{ id = "combo_5",           desc = "5콤보 달성",       condition = "max_combo",         target = 5,    weight = 18, tier = "easy" },
		{ id = "combo_15",          desc = "15콤보 달성",      condition = "max_combo",         target = 15,   weight = 10, tier = "normal" },
		{ id = "combo_30",          desc = "30콤보 달성",      condition = "max_combo",         target = 30,   weight = 5,  tier = "hard" },
		{ id = "fever_1",           desc = "피버 1회 발동",    condition = "fever_count",       target = 1,    weight = 14, tier = "normal" },
		{ id = "fever_2",           desc = "피버 2회 발동",    condition = "fever_count",       target = 2,    weight = 5,  tier = "hard" },
		{ id = "nearmiss_3",        desc = "니어미스 3회",     condition = "near_miss_count",   target = 3,    weight = 16, tier = "easy" },
		{ id = "nearmiss_7",        desc = "니어미스 7회",     condition = "near_miss_count",   target = 7,    weight = 8,  tier = "normal" },
		{ id = "score_500",         desc = "500점 달성",       condition = "score",             target = 500,  weight = 15, tier = "easy" },
		{ id = "score_1500",        desc = "1500점 달성",      condition = "score",             target = 1500, weight = 8,  tier = "normal" },
		{ id = "powerup_2",         desc = "파워업 2개 획득",  condition = "powerups_collected", target = 2,   weight = 14, tier = "easy" },
		{ id = "survive_30",        desc = "30초 생존",        condition = "survive_time",      target = 30,   weight = 16, tier = "easy" },
		{ id = "survive_60",        desc = "60초 생존",        condition = "survive_time",      target = 60,   weight = 8,  tier = "normal" },
		{ id = "nohit_200m",        desc = "200m 무피격",      condition = "no_hit_distance",   target = 200,  weight = 8,  tier = "normal" },
		{ id = "powerup_5",         desc = "파워업 5개 획득",  condition = "powerups_collected", target = 5,   weight = 7,  tier = "normal" },
		{ id = "survive_90",        desc = "90초 생존",        condition = "survive_time",      target = 90,   weight = 5,  tier = "hard" },
		{ id = "score_3000",        desc = "3000점 달성",      condition = "score",             target = 3000, weight = 4,  tier = "hard" },
		{ id = "nearmiss_12",       desc = "니어미스 12회",    condition = "near_miss_count",   target = 12,   weight = 4,  tier = "hard" },
		{ id = "run_1500m",         desc = "1500m 달리기",     condition = "distance",          target = 1500, weight = 3,  tier = "hard" },
		{ id = "zone_reach_3",      desc = "3구역 도달",       condition = "zone_reached",      target = 3,    weight = 6,  tier = "normal" },
		{ id = "zone_reach_4",      desc = "4구역 도달",       condition = "zone_reached",      target = 4,    weight = 4,  tier = "hard" },
		{ id = "nearmiss_chain_5",  desc = "니어미스 5연속",   condition = "near_miss_chain_max", target = 5,  weight = 4,  tier = "hard" },
	},
	SELECTION = { MIN_EASY = 1, MAX_HARD = 1 },
}

-- 장애물 콤보 패턴 (청크 내 복합 배치)
GameConstants.OBSTACLE_COMBOS = {
	-- Normal 난이도 콤보 (20% 확률로 선택)
	normal = {
		{ name = "low_double",   obstacles = { { type = "LowWall",   xOffset = 0 }, { type = "LowWall",   xOffset = 20 } } },
		{ name = "spike_gap",    obstacles = { { type = "SpikeTrap", xOffset = 0 }, { type = "Gap",       xOffset = 22 } } },
		{ name = "tunnel_spike", obstacles = { { type = "Tunnel",    xOffset = 0 }, { type = "SpikeTrap", xOffset = 22 } } },
		-- 신규: 낙석-터널 (경고 읽기 + 슬라이드)
		{ name = "rock_tunnel",  obstacles = { { type = "FallingRock", xOffset = 0 }, { type = "Tunnel", xOffset = 22 } } },
	},
	-- Hard 난이도 콤보 (35% 확률로 선택)
	hard = {
		{ name = "wall_barrel",     obstacles = { { type = "LowWall",    xOffset = 0 }, { type = "ExplodingBarrel", xOffset = 18 } } },
		{ name = "moving_spike",    obstacles = { { type = "MovingWall", xOffset = 0 }, { type = "SpikeTrap",       xOffset = 20 } } },
		{ name = "double_gap",      obstacles = { { type = "DoubleWall", xOffset = 0 }, { type = "Gap",             xOffset = 22 } } },
		{ name = "triple_gauntlet", obstacles = { { type = "LowWall",    xOffset = 0 }, { type = "SpikeTrap",       xOffset = 18 }, { type = "Gap", xOffset = 36 } } },
		-- 신규: 타이밍 콤보
		{ name = "pendulum_barrel", obstacles = { { type = "PendulumLog", xOffset = 0 }, { type = "ExplodingBarrel", xOffset = 22 } } },
		{ name = "laser_wall",      obstacles = { { type = "LaserBeam",   xOffset = 0 }, { type = "LowWall",         xOffset = 20 } } },
		{ name = "rock_spike",      obstacles = { { type = "FallingRock", xOffset = 0 }, { type = "SpikeTrap",       xOffset = 22 } } },
	},
}

-- 장애물 리듬 패턴 (박자 기반 시퀀스 — OBSTACLE_COMBOS보다 체계적)
-- 각 beat의 xOffset 단위: studs (청크 진입점 기준 상대값)
-- minSpeed 기준 반응 시간: PHYSICS.SPEED_MAX(52) * 0.35s = 18.2 studs 최소 간격 보장
GameConstants.OBSTACLE_RHYTHMS = {
	-- ===================== Normal 리듬 =====================
	normal = {
		-- 뛰뛰뛰 (3연속 점프, 균등 20studs 간격)
		{ name = "triple_jump",
		  beats = { { type = "LowWall", xOffset = 0 }, { type = "LowWall", xOffset = 20 }, { type = "LowWall", xOffset = 40 } } },
		-- 뛰-숙-뛰 (점프-슬라이드-점프)
		{ name = "jump_slide_jump",
		  beats = { { type = "LowWall", xOffset = 0 }, { type = "Tunnel", xOffset = 22 }, { type = "LowWall", xOffset = 46 } } },
		-- 숙-뛰-숙 (슬라이드-점프-슬라이드)
		{ name = "slide_jump_slide",
		  beats = { { type = "Tunnel", xOffset = 0 }, { type = "LowWall", xOffset = 22 }, { type = "Tunnel", xOffset = 46 } } },
		-- 스파이크-점프-스파이크
		{ name = "spike_jump_spike",
		  beats = { { type = "SpikeTrap", xOffset = 0 }, { type = "LowWall", xOffset = 22 }, { type = "SpikeTrap", xOffset = 44 } } },
		-- 2연속 슬라이드 (터널 2개)
		{ name = "double_slide",
		  beats = { { type = "Tunnel", xOffset = 0 }, { type = "Tunnel", xOffset = 24 } } },
		-- 점프-갭 (낮은 벽 넘고 구덩이 점프)
		{ name = "wall_then_gap",
		  beats = { { type = "LowWall", xOffset = 0 }, { type = "Gap", xOffset = 22 } } },
		-- 신규: 낙석-점프 (경고 읽고 점프)
		{ name = "rock_then_jump",
		  beats = { { type = "FallingRock", xOffset = 0 }, { type = "LowWall", xOffset = 24 } } },
	},
	-- ===================== Hard 리듬 =====================
	hard = {
		-- 가속 리듬 (간격이 좁아지는 3연속: 24→20→16)
		{ name = "accelerating",
		  beats = { { type = "LowWall", xOffset = 0 }, { type = "SpikeTrap", xOffset = 24 }, { type = "Gap", xOffset = 44 } } },
		-- 배럴-슬라이드-배럴 (폭발 사이 슬라이드)
		{ name = "barrel_slide_barrel",
		  beats = { { type = "ExplodingBarrel", xOffset = 0 }, { type = "Tunnel", xOffset = 20 }, { type = "ExplodingBarrel", xOffset = 40 } } },
		-- 더블점프 + 배럴 (2단 점프 후 폭발 회피)
		{ name = "double_barrel",
		  beats = { { type = "DoubleWall", xOffset = 0 }, { type = "ExplodingBarrel", xOffset = 22 } } },
		-- 움직이는 벽 + 스파이크 (타이밍 후 점프)
		{ name = "moving_spike",
		  beats = { { type = "MovingWall", xOffset = 0 }, { type = "SpikeTrap", xOffset = 22 } } },
		-- 점프-슬라이드-배럴 (3액션 콤비)
		{ name = "jump_slide_barrel",
		  beats = { { type = "LowWall", xOffset = 0 }, { type = "Tunnel", xOffset = 20 }, { type = "ExplodingBarrel", xOffset = 40 } } },
		-- 갭-더블점프-갭 (연속 공중 이동)
		{ name = "gap_double_gap",
		  beats = { { type = "Gap", xOffset = 0 }, { type = "DoubleWall", xOffset = 22 }, { type = "Gap", xOffset = 44 } } },
		-- 신규: 통나무-갭-벽 (타이밍 후 점프 연속)
		{ name = "pendulum_gap_wall",
		  beats = { { type = "PendulumLog", xOffset = 0 }, { type = "Gap", xOffset = 24 }, { type = "LowWall", xOffset = 46 } } },
		-- 신규: 레이저-슬라이드-낙석 (타이밍 복합)
		{ name = "laser_slide_rock",
		  beats = { { type = "LaserBeam", xOffset = 0 }, { type = "Tunnel", xOffset = 22 }, { type = "FallingRock", xOffset = 44 } } },
		-- 신규: 낙석-배럴 (연속 위치 회피)
		{ name = "rock_barrel",
		  beats = { { type = "FallingRock", xOffset = 0 }, { type = "ExplodingBarrel", xOffset = 22 } } },
	},
}

-- 리듬 패턴 선택 확률 (일반 랜덤 배치 대신 리듬을 선택할 확률)
-- OBSTACLE_COMBOS는 하위호환 유지, RHYTHMS가 우선 적용
GameConstants.RHYTHM_CHANCE = {
	Normal = 0.40, -- Normal 청크 40% 확률로 리듬 패턴
	Hard   = 0.60, -- Hard 청크 60% 확률로 리듬 패턴
}

-- 반응 시간 검증 최소 간격 (SPEED_MAX * 반응시간)
GameConstants.RHYTHM_MIN_GAP = GameConstants.PHYSICS.SPEED_MAX * 0.35 -- ~18.2 studs

-- 스킬 루트 (Risk-Reward Path)
-- 장애물 타입별로 "위험하지만 고보상" 코인 위치를 정의
-- xOffset: 장애물 월드X 기준 상대 오프셋 (studs)
-- y: 월드 Y 절대 높이 (studs, 지면=0)
-- coinType: "Silver" | "Gold" | "Diamond"
GameConstants.SKILL_ROUTES = {
	-- LowWall 꼭대기 — 벽을 아슬아슬하게 스치며 점프 (니어미스 위치)
	LowWall = { { xOffset = 0, y = 5.5, coinType = "Gold" } },
	-- SpikeTrap 위 — 스파이크 정점을 아슬하게 점프
	SpikeTrap = { { xOffset = 0, y = 5.0, coinType = "Gold" } },
	-- Gap 공중 — 구덩이 중앙 공중, 2단 점프로만 도달
	Gap = { { xOffset = 0, y = 9.0, coinType = "Diamond" } },
	-- Tunnel 통과 직후 즉시 점프해야 닿는 위치
	Tunnel = { { xOffset = 8, y = 7.0, coinType = "Gold" } },
	-- DoubleWall 위 — 2단 점프 정점
	DoubleWall = { { xOffset = 0, y = 8.0, coinType = "Silver" }, { xOffset = 4, y = 9.5, coinType = "Gold" } },
	-- ExplodingBarrel 폭발 직전 순간 이동 — 배럴 옆을 스치면 Silver 코인
	ExplodingBarrel = { { xOffset = -6, y = 6.0, coinType = "Silver" }, { xOffset = 6, y = 6.0, coinType = "Silver" } },
	-- PendulumLog 통과 직후 — 타이밍 맞추면 Gold
	PendulumLog = { { xOffset = 4, y = 6.0, coinType = "Gold" } },
	-- LaserBeam Off 구간 — 레이저 위치 바로 위 Gold
	LaserBeam = { { xOffset = 0, y = 5.5, coinType = "Gold" } },
	-- FallingRock 낙하 지점 — 바위 직전 위치에 Diamond (고위험 고보상)
	FallingRock = { { xOffset = 0, y = 7.0, coinType = "Diamond" } },
}

-- 스킬 루트 코인 출현 확률 (난이도별)
GameConstants.SKILL_ROUTE_CHANCE = {
	Normal = 0.30,
	Hard   = 0.50,
}

-- Zone별 고유 메커닉 정의
GameConstants.ZONE_MECHANICS = {
	[1] = { -- Meadow (0~60s): 튜토리얼 존 — 고유 장애물 없음
		specialObstacle = nil,
		coinPattern     = nil,    -- nil = 기존 패턴 사용
	},
	[2] = { -- FlowerPath (60~120s): 꽃잎 바람
		specialObstacle = "FlowerWind", -- LowWall 변형: 좌우로 흔들리는 꽃잎 장애물
		specialChance   = 0.35,   -- FlowerWind 등장 확률 (Normal/Hard 청크에서)
		coinPattern     = nil,
	},
	[3] = { -- MushroomWood (120~180s): 버섯 트램폴린
		specialObstacle = "MushroomPad", -- 밟으면 점프력 2배 (유익 오브젝트)
		specialChance   = 0.40,   -- MushroomPad 등장 확률
		coinPattern     = "high_float", -- 버섯 위 높은 위치에 코인 배치
	},
	[4] = { -- Sunset (180~240s): 그림자 장애물
		specialObstacle = "ShadowWall", -- 서서히 나타나는 반투명 장애물
		specialChance   = 0.30,   -- ShadowWall 등장 확률
		coinPattern     = nil,
	},
	[5] = { -- Starlight (240s+): 저중력 구간
		specialObstacle = "GravityZone", -- 저중력 마커 (청크 단위 적용)
		specialChance   = 0.40,   -- 저중력 청크 비율 (Hard 청크)
		coinPattern     = "constellation", -- 별자리 형태 높은 코인
	},
}

-- FlowerWind 상수
GameConstants.FLOWER_WIND = {
	SWAY_AMPLITUDE = 2.5,  -- 좌우 흔들림 폭 (studs)
	SWAY_CYCLE     = 1.8,  -- 흔들림 주기 (초)
	COLOR          = Color3.fromRGB(255, 160, 200), -- 분홍색
	SIZE           = Vector3.new(2, 4, 10), -- LowWall과 동일한 높이
}

-- ShadowWall 상수
GameConstants.SHADOW_WALL = {
	FADE_TIME      = 1.2,  -- 투명도 0.9→0.2 전환 시간 (초)
	ALPHA_START    = 0.9,  -- 초기 투명도 (거의 안 보임)
	ALPHA_END      = 0.2,  -- 최종 투명도 (선명히 보임)
	COLOR          = Color3.fromRGB(20, 20, 30), -- 어두운 검정
	SIZE           = Vector3.new(2, 4, 10), -- LowWall과 동일
}

-- MushroomPad 상수 (Zone 3 전용, 유익 오브젝트)
GameConstants.MUSHROOM_PAD = {
	SIZE              = Vector3.new(6, 2, 6),          -- 버섯 패드 크기
	COLOR             = Color3.fromRGB(160, 80, 200),  -- 보라색 버섯
	BOUNCE_MULTIPLIER = 2.0,                           -- 점프력 배율
	EFFECT_DURATION   = 0.8,                           -- 배율 적용 시간 (초)
	DETECT_RADIUS     = 4,                             -- 밟기 판정 반경 (studs)
	COOLDOWN          = 2.0,                           -- 동일 패드 재사용 쿨다운
}

-- GravityZone 상수 (Zone 5 전용)
GameConstants.GRAVITY_ZONE = {
	AIRTIME_MULTIPLIER = 1.5, -- 체공 시간 1.5배
	JUMP_MULTIPLIER    = 1.4, -- 점프력 1.4배
	EFFECT_DURATION    = 8.0, -- 저중력 지속 시간 (초, 청크 통과 시간보다 길게)
	MARKER_COLOR       = Color3.fromRGB(80, 120, 255), -- 파란 네온 마커
	MARKER_SIZE        = Vector3.new(80, 0.5, 12),     -- 청크 폭 전체 얇은 바닥 마커
}

-- PendulumLog 상수 (Zone 3+, Hard 전용 — 상하 스윙 통나무)
-- 타이밍에 맞춰 통과: 통나무가 올라간 틈에 지나감
GameConstants.PENDULUM_LOG = {
	SIZE           = Vector3.new(3, 3, 10),            -- 통나무 크기
	COLOR          = Color3.fromRGB(120, 70, 30),      -- 갈색 나무
	SWING_Y_MIN    = 0,                                -- 최저 위치 (지면)
	SWING_Y_MAX    = 9,                                -- 최고 위치 (높이 올라감)
	SWING_CYCLE    = 2.4,                              -- 상하 왕복 주기 (초)
	CLEAR_Y        = 4,                                -- 이 높이 이상이면 아래로 통과 가능
	NORMAL_CHANCE  = 0.0,                              -- Normal: 비등장
	HARD_CHANCE    = 0.10,                             -- Hard: 10%
}

-- LaserBeam 상수 (Zone 4+, Hard 전용 — On/Off 토글 레이저)
-- 레이저 Off 타이밍에 맞춰 통과
GameConstants.LASER_BEAM = {
	SIZE           = Vector3.new(1, 0.4, 12),          -- 얇은 수평 빔
	COLOR_ON       = Color3.fromRGB(255, 30, 30),      -- 활성 시 빨간 네온
	COLOR_OFF      = Color3.fromRGB(80, 80, 80),       -- 비활성 시 회색
	HEIGHT         = 3,                                -- 빔 높이 (점프로 회피)
	ON_DURATION    = 1.2,                              -- On 지속 시간 (초)
	OFF_DURATION   = 0.8,                              -- Off 지속 시간 (초, 통과 가능 구간)
	HARD_CHANCE    = 0.08,                             -- Hard: 8%
}

-- FallingRock 상수 (Zone 3+, Normal/Hard — 경고 그림자 후 낙석)
-- 바닥 경고 표시 → 일정 시간 후 바위 낙하, 위치 회피
GameConstants.FALLING_ROCK = {
	SIZE           = Vector3.new(4, 4, 10),            -- 바위 크기
	COLOR          = Color3.fromRGB(100, 90, 80),      -- 회갈색 바위
	WARNING_SIZE   = Vector3.new(5, 0.2, 10),          -- 바닥 경고 그림자
	WARNING_COLOR  = Color3.fromRGB(255, 60, 60),      -- 빨간 경고 그림자
	DROP_HEIGHT    = 25,                               -- 낙하 시작 높이 (studs)
	WARNING_TIME   = 0.8,                              -- 경고 표시 → 낙하까지 (초)
	DROP_SPEED     = 0.4,                              -- 낙하 시간 (초)
	NORMAL_CHANCE  = 0.10,                             -- Normal: 10%
	HARD_CHANCE    = 0.15,                             -- Hard: 15%
}

-- 회전 장애물 (Rotating Bar) — Hard 전용, 타이밍 점프/슬라이드 회피 (IDEA-004)
GameConstants.ROTATING_BAR = {
	SIZE          = Vector3.new(1, 8, 12),             -- 얇은 벽 (높이×폭)
	COLOR         = Color3.fromRGB(255, 180, 0),       -- 밝은 주황/노란색 (경고색)
	CYCLE_TIME    = 1.5,                               -- 1사이클 시간 (초)
	PIVOT_Y       = 4,                                 -- 회전 중심 높이 (studs)
}

-- 낙하 잔해 (Falling Debris) — Hard 전용, 경고 후 3연속 파편 낙하 (IDEA-004)
GameConstants.FALLING_DEBRIS = {
	PIECE_SIZE    = Vector3.new(3, 3, 8),              -- 파편 크기
	COLOR         = Color3.fromRGB(200, 130, 50),      -- 갈색 파편
	DROP_HEIGHT   = 22,                                -- 낙하 시작 높이 (studs)
	WARNING_TIME  = 0.6,                               -- 경고 → 낙하 지연 (초)
	DROP_SPEED    = 0.35,                              -- 낙하 시간 (초)
	STAGGER_TIME  = 0.25,                              -- 파편 간 딜레이 (초)
	COUNT         = 3,                                 -- 파편 개수
	SPACING       = 4,                                 -- X 간격 (studs)
	WARNING_COLOR = Color3.fromRGB(255, 130, 0),       -- 주황 경고 그림자
}

-- =====================================================================
-- Phase 4: 피크 모먼트 + 밸런스 패스
-- =====================================================================

-- Coin Waterfall 이벤트
GameConstants.COIN_WATERFALL = {
	MIN_TIME     = 120,  -- 120초 이후부터 등장 가능
	CHANCE       = 0.05, -- 청크당 5% 확률
	COIN_COUNT   = 24,   -- 대각선 폭포 코인 수
	START_Y      = 12,   -- 폭포 시작 높이
	END_Y        = 2.5,  -- 폭포 끝 높이
}

-- Zone Climax: Zone 마지막 15초 고밀도 구간
GameConstants.ZONE_CLIMAX = {
	PRE_TRANSITION_TIME = 15, -- Zone 전환 X초 전
	DENSITY_MULTIPLIER  = 2.0, -- 코인/장애물 밀도 2배
	SPECIAL_CHANCE_MULT = 2.0, -- Zone 고유 요소 확률도 2배
}

-- Zone 전환 시간 임계값 (초): [zoneIndex] = 해당 zone이 끝나는 시각
-- ZONE_THEMES[i+1].startTime 에서 파생
GameConstants.ZONE_THRESHOLDS = {
	[1] = 60,        -- Meadow     → FlowerPath  at 60s
	[2] = 120,       -- FlowerPath → MushroomWood at 120s
	[3] = 180,       -- MushroomWood → Sunset    at 180s
	[4] = 240,       -- Sunset     → Starlight   at 240s
	[5] = math.huge, -- Starlight: 마지막 Zone, 전환 없음
}

-- Zone별 ActionHint 발동 확률: Zone 1(100%) → Zone 5(35%)
-- Zone 1은 신규 유저 온보딩 구간이므로 항상 힌트 제공
GameConstants.ACTION_HINT_RATES = {
	[1] = 1.00, -- Meadow: 100% — 신규 유저 온보딩, 모든 장애물에 힌트
	[2] = 0.85, -- FlowerPath: 85%
	[3] = 0.70, -- MushroomWood: 70% (기존 기본값)
	[4] = 0.50, -- Sunset: 50%
	[5] = 0.35, -- Starlight: 35% — 숙련 유저, 도전감 유지
}

-- 구역별 장애물 색상 (ObstacleService에서 참조)
GameConstants.ZONE_OBSTACLE_COLORS = {
	[1] = Color3.fromRGB(110, 75,  40),  -- Meadow: 나무색
	[2] = Color3.fromRGB(190, 80, 140),  -- FlowerPath: 보라/분홍
	[3] = Color3.fromRGB(90,  45, 110),  -- MushroomWood: 짙은 보라
	[4] = Color3.fromRGB(200, 100, 35),  -- Sunset: 오렌지
	[5] = Color3.fromRGB(45,  65, 150),  -- Starlight: 짙은 파랑
}

-- 펫 시스템
GameConstants.PETS = {
	LIST = {
		{
			id = "chick",
			name = "병아리",
			emoji = "🐤",
			price = 0,
			currency = "coins",
			coinBonus = 0,
			magnetBonus = 0,
			feverBonus = 0,
			color = Color3.fromRGB(255, 220, 0),
		},
		{
			id = "rabbit",
			name = "토끼",
			emoji = "🐰",
			price = 150,
			currency = "coins",
			coinBonus = 0.05,
			magnetBonus = 0,
			feverBonus = 0,
			color = Color3.fromRGB(255, 200, 200),
		},
		{
			id = "cat",
			name = "고양이",
			emoji = "🐱",
			price = 300,
			currency = "coins",
			coinBonus = 0.08,
			magnetBonus = 1.0,
			feverBonus = 0,
			color = Color3.fromRGB(255, 165, 0),
		},
		{
			id = "dog",
			name = "강아지",
			emoji = "🐶",
			price = 500,
			currency = "coins",
			coinBonus = 0.10,
			magnetBonus = 1.5,
			feverBonus = 0,
			color = Color3.fromRGB(210, 180, 140),
		},
		{
			id = "penguin",
			name = "펭귄",
			emoji = "🐧",
			price = 800,
			currency = "coins",
			coinBonus = 0.05,
			magnetBonus = 2.0,
			feverBonus = 0.05,
			color = Color3.fromRGB(50, 50, 60),
		},
		{
			id = "fox",
			name = "여우",
			emoji = "🦊",
			price = 1500,
			currency = "coins",
			coinBonus = 0.15,
			magnetBonus = 2.5,
			feverBonus = 0.10,
			color = Color3.fromRGB(255, 130, 30),
		},
	},
}

-- 이름표 시스템
GameConstants.NAMETAG = {
	ITEMS = {
		-- ── 색상 (10종) ──────────────────────────────────────────────────────────
		{ id = "color_pink",     category = "color", name = "핑크",    price = 500, color = Color3.fromRGB(255, 150, 200) },
		{ id = "color_gold",     category = "color", name = "골드",    price = 500, color = Color3.fromRGB(255, 215, 0) },
		{ id = "color_cyan",     category = "color", name = "하늘",    price = 500, color = Color3.fromRGB(0, 200, 255) },
		{ id = "color_lavender", category = "color", name = "라벤더",  price = 600, color = Color3.fromRGB(180, 140, 255) },
		{ id = "color_mint",     category = "color", name = "민트",    price = 600, color = Color3.fromRGB(100, 230, 180) },
		{ id = "color_coral",    category = "color", name = "코랄",    price = 600, color = Color3.fromRGB(255, 120, 100) },
		{ id = "color_sky",      category = "color", name = "스카이",  price = 700, color = Color3.fromRGB(135, 206, 250) },
		{ id = "color_lime",     category = "color", name = "라임",    price = 700, color = Color3.fromRGB(160, 240, 60) },
		{ id = "color_peach",    category = "color", name = "피치",    price = 700, color = Color3.fromRGB(255, 200, 150) },
		{ id = "color_violet",   category = "color", name = "바이올렛", price = 800, color = Color3.fromRGB(138, 43, 226) },

		-- ── 폰트 (5종) ──────────────────────────────────────────────────────────
		{ id = "font_bold",      category = "font", name = "볼드",     price = 800 },
		{ id = "font_retro",     category = "font", name = "레트로",   price = 800 },
		{ id = "font_pixel",     category = "font", name = "픽셀",     price = 900 },
		{ id = "font_bubble",    category = "font", name = "버블",     price = 900 },
		{ id = "font_elegant",   category = "font", name = "엘레강스", price = 1000 },

		-- ── 프레임 (10종) ────────────────────────────────────────────────────────
		{ id = "frame_star",     category = "frame", name = "별 프레임",   price = 1200 },
		{ id = "frame_heart",    category = "frame", name = "하트 프레임", price = 1200 },
		{ id = "frame_crown",    category = "frame", name = "왕관 프레임", price = 1400 },
		{ id = "frame_cloud",    category = "frame", name = "구름 프레임", price = 1400 },
		{ id = "frame_lightning",category = "frame", name = "번개 프레임", price = 1500 },
		{ id = "frame_diamond",  category = "frame", name = "다이아 프레임", price = 1600 },
		{ id = "frame_fire",     category = "frame", name = "불꽃 프레임", price = 1800 },
		{ id = "frame_galaxy",   category = "frame", name = "우주 프레임", price = 2000 },
		{ id = "frame_sakura",   category = "frame", name = "벚꽃 프레임", price = 1600 },
		{ id = "frame_rainbow",  category = "frame", name = "무지개 프레임", price = 2000 },

		-- ── 뱃지 (5종) — 업적 조건 달성 시 구매 가능 ──────────────────────────
		-- unlockStat: PlayerData 필드명, unlockValue: 요구 수치
		{ id = "badge_speedstar",   category = "badge", name = "스피드 스타",  price = 1200, unlockStat = "highScore",            unlockValue = 5000,  unlockDesc = "최고 점수 5,000 달성" },
		{ id = "badge_coinmaster",  category = "badge", name = "코인 마스터",  price = 1500, unlockStat = "totalCoinsCollected",  unlockValue = 10000, unlockDesc = "코인 10,000개 수집" },
		{ id = "badge_feverking",   category = "badge", name = "피버 킹",      price = 2000, unlockStat = "gamesPlayed",          unlockValue = 50,    unlockDesc = "게임 50회 플레이" },
		{ id = "badge_coinhunter",  category = "badge", name = "코인 헌터",    price = 2500, unlockStat = "totalCoinsCollected",  unlockValue = 50000, unlockDesc = "코인 50,000개 수집" },
		{ id = "badge_survivor",    category = "badge", name = "서바이버",     price = 3000, unlockStat = "gamesPlayed",          unlockValue = 100,   unlockDesc = "게임 100회 플레이" },
	},
}

-- 펫 레벨업 시스템 (레벨 1~5, 기본 레벨 1)
GameConstants.PETS.LEVEL_COSTS = { 200, 500, 1200, 3000, 7000 } -- Lv1->2, 2->3, ... 4->5
GameConstants.PETS.MAX_PET_LEVEL = 5
GameConstants.PETS.LEVEL_COIN_BONUS = 0.02 -- 레벨당 coinBonus +0.02 (누적)
GameConstants.PETS.LEVEL_MAGNET_BONUS = 0.5 -- 레벨당 magnetBonus +0.5 studs (누적)

-- 펫 액티브 스킬 (하이브리드: 기존 패시브 유지 + 자동 발동 액티브 추가)
-- 자동 발동: 쿨다운마다 자동으로 효과 적용 (플레이어 입력 불필요)
GameConstants.PET_SKILLS = {
	chick    = nil, -- 병아리: 스킬 없음 (기본 펫)
	rabbit   = { id = "auto_jump_boost", interval = 20, duration = 3, desc = "3초간 점프력 1.3배" },
	cat      = { id = "auto_magnet",     interval = 18, duration = 2, desc = "2초간 자석 자동 발동" },
	dog      = { id = "auto_shield",     interval = 30, duration = 0, desc = "피격 1회 자동 방어" },
	penguin  = { id = "auto_slow",       interval = 25, duration = 3, desc = "3초간 속도 감소 (코인 수집 기회)" },
	fox      = { id = "auto_coin_burst", interval = 15, duration = 0, desc = "주변 코인 즉시 흡수" },
}

-- ==================== 캐릭터 시스템 ====================
GameConstants.CHARACTERS = {
	LIST = {
		{
			id = "runner",
			name = "달리기꾼",
			emoji = "🏃",
			-- 실루엣: 기본형
			color = Color3.fromRGB(0, 170, 255),
			material = "SmoothPlastic",
			bodySize = Vector3.new(4, 5, 4),
			headSize = Vector3.new(3, 3, 3),
			-- 패시브
			passive = { type = "none", value = 0 },
			-- 액티브 스킬 없음
			skill = nil,
			-- 해금 조건
			unlockType = "default",
			unlockValue = 0,
		},
		{
			id = "ninja",
			name = "닌자",
			emoji = "🥷",
			color = Color3.fromRGB(30, 30, 30),
			material = "SmoothPlastic",
			bodySize = Vector3.new(3, 5, 3),
			headSize = Vector3.new(2.5, 2.5, 2.5),
			passive = { type = "hitbox_reduction", value = 0.10 }, -- 장애물 판정 10% 완화
			skill = {
				id = "dash",
				name = "대시",
				desc = "전방 돌진, 장애물 1개 통과",
				cooldown = 8,
				duration = 0.4,
			},
			unlockType = "coins",
			unlockValue = 800,
		},
		{
			id = "mage",
			name = "마법사",
			emoji = "🧙",
			color = Color3.fromRGB(120, 60, 200),
			material = "Neon",
			bodySize = Vector3.new(5, 4, 4),
			headSize = Vector3.new(3.5, 3.5, 3.5),
			passive = { type = "magnet_bonus", value = 3 }, -- 수집 반경 +3 studs
			skill = {
				id = "vortex",
				name = "마법 소용돌이",
				desc = "4초간 주변 코인 전부 흡수",
				cooldown = 15,
				duration = 4,
			},
			unlockType = "level",
			unlockValue = 15,
		},
		{
			id = "knight",
			name = "기사",
			emoji = "🛡️",
			color = Color3.fromRGB(160, 160, 180),
			material = "Metal",
			bodySize = Vector3.new(6, 5, 4),
			headSize = Vector3.new(3, 3.5, 3),
			passive = { type = "hit_resist", value = 0.50 }, -- 피격 50% 확률로 무효
			skill = {
				id = "shield",
				name = "방패",
				desc = "3초 무적",
				cooldown = 20,
				duration = 3,
			},
			unlockType = "quest",
			unlockValue = "obstacles_dodged_500",
		},
		{
			id = "fairy",
			name = "요정",
			emoji = "🧚",
			color = Color3.fromRGB(200, 255, 200),
			material = "Neon",
			bodySize = Vector3.new(2.5, 3.5, 2.5),
			headSize = Vector3.new(2, 2, 2),
			passive = { type = "fever_extend", value = 2 }, -- 피버 지속 +2초
			skill = {
				id = "sparkle",
				name = "반짝임",
				desc = "즉시 미니 피버 발동",
				cooldown = 25,
				duration = 0,
			},
			unlockType = "season",
			unlockValue = 20, -- 시즌 패스 Lv20 (배틀패스 출시 후 활성화)
			tempUnlockType = "level", -- 임시 해금 경로: 계정 레벨
			tempUnlockValue = 25, -- Lv25 달성 시 임시 해금
		},
		{
			id = "robot",
			name = "로봇",
			emoji = "🤖",
			color = Color3.fromRGB(100, 180, 220),
			material = "Metal",
			bodySize = Vector3.new(4.5, 5.5, 4.5),
			headSize = Vector3.new(3.5, 3.5, 3.5),
			passive = { type = "start_magnet", value = 5 }, -- 런 시작 자석 5초 자동 활성화
			skill = {
				id = "magnet_field",
				name = "자기장",
				desc = "10초간 자석 반경 2배",
				cooldown = 18,
				duration = 10,
			},
			unlockType = "gems",
			unlockValue = 150,
		},
	},
	-- 스킬 쿨다운 상한
	MAX_SKILL_COOLDOWN = 30,
	-- 캐릭터 패시브 보너스 상한 (밸런스 보호)
	MAX_MAGNET_BONUS = 25, -- studs
	MAX_FEVER_EXTEND = 4, -- 초
}

-- ==================== 런 내 성장 시스템 ====================

-- 런 내 XP 획득 조건
GameConstants.RUN_PROGRESSION = {
	XP_PER_COIN = 1, -- 코인 1개당 런 XP
	XP_PER_NEAR_MISS = 5, -- 니어미스 1회당 런 XP
	XP_PER_FEVER = 20, -- 피버 돌입 1회당 런 XP
	MAX_RUN_LEVEL = 10, -- 런 내 최대 레벨
	SKILL_CHOICES = 3, -- 스킬 선택 카드 수
	AUTO_SELECT_DELAY = 5, -- 자동 선택 대기 시간 (초)
}

-- 계정 레벨업 시 런 스킬 영구 해금 테이블 (런 시작 전 슬롯에 장착 가능)
GameConstants.RUN_SKILL_UNLOCK_LEVELS = {
	[3] = "coin_magnet", -- Lv3: 코인 자석
	[6] = "speed_boost", -- Lv6: 질주
	[10] = "double_coins", -- Lv10: 코인 2배
	[15] = "shield", -- Lv15: 방어막
	[20] = "fever_charge", -- Lv20: 피버 충전
	[25] = "lucky_drop", -- Lv25: 럭키 드롭
	[30] = "coin_shower", -- Lv30: 코인 소나기
	[40] = "time_slow", -- Lv40: 시간 지연
	[50] = "super_magnet", -- Lv50: 슈퍼 자석 (만렙 보상)
}

-- 런 내 XP 요구량 공식: 50 * level^1.2
-- Lv1→2: 50, Lv2→3: 95, Lv3→4: 147, Lv5→6: 261

-- 런 내 스킬 풀 (10종)
GameConstants.RUN_SKILLS = {
	-- { id, name, emoji, desc, rarity, effect }
	-- rarity: "common"=일반(50%), "rare"=희귀(35%), "legendary"=전설(15%)
	{
		id = "coin_magnet",
		name = "코인 자석",
		emoji = "🧲",
		desc = "자석 반경 +5 studs (런 종료까지)",
		rarity = "common",
		effectType = "magnet_bonus",
		effectValue = 5,
		duration = -1, -- -1 = 런 종료까지
	},
	{
		id = "speed_boost",
		name = "질주",
		emoji = "⚡",
		desc = "이동 속도 +15% (런 종료까지)",
		rarity = "common",
		effectType = "speed_multiplier",
		effectValue = 0.15,
		duration = -1,
	},
	{
		id = "double_coins",
		name = "코인 2배",
		emoji = "💰",
		desc = "코인 가치 2배 (30초)",
		rarity = "common",
		effectType = "coin_multiplier",
		effectValue = 2,
		duration = 30,
	},
	{
		id = "shield",
		name = "방어막",
		emoji = "🛡️",
		desc = "피격 1회 무효",
		rarity = "rare",
		effectType = "shield",
		effectValue = 1,
		duration = -1,
	},
	{
		id = "fever_charge",
		name = "피버 충전",
		emoji = "🔥",
		desc = "콤보 즉시 +10",
		rarity = "rare",
		effectType = "combo_boost",
		effectValue = 10,
		duration = 0, -- 즉시 발동
	},
	{
		id = "coin_shower",
		name = "코인 소나기",
		emoji = "🌧️",
		desc = "5초간 코인 밀도 3배",
		rarity = "rare",
		effectType = "coin_density",
		effectValue = 3,
		duration = 5,
	},
	{
		id = "invincible",
		name = "무적",
		emoji = "✨",
		desc = "5초 무적",
		rarity = "legendary",
		effectType = "invincible",
		effectValue = 1,
		duration = 5,
	},
	{
		id = "super_magnet",
		name = "슈퍼 자석",
		emoji = "💫",
		desc = "화면 전체 코인 즉시 흡수",
		rarity = "legendary",
		effectType = "vacuum",
		effectValue = 1,
		duration = 0,
	},
	{
		id = "time_slow",
		name = "시간 지연",
		emoji = "⏳",
		desc = "5초간 장애물 속도 절반",
		rarity = "legendary",
		effectType = "time_slow",
		effectValue = 0.5,
		duration = 5,
	},
	{
		id = "lucky_drop",
		name = "럭키 드롭",
		emoji = "🍀",
		desc = "다음 5개 코인이 골드 코인",
		rarity = "rare",
		effectType = "lucky_coins",
		effectValue = 5,
		duration = -1,
	},
}

-- ==================== 소모형 런 파워업 (코인 소비) ====================
-- 런 시작 전 로비에서 코인을 소모하여 1회성 효과를 구매
-- 영속적 코인 싱크 역할 (loot box 규제 회피: 코인으로만 구매)
GameConstants.CONSUMABLE_POWERUPS = {
	{ id = "head_start",  name = "헤드스타트",   desc = "시작 10초 무적+자석",    coinCost = 50 },
	{ id = "coin_boost",  name = "코인 부스트",  desc = "런 전체 코인 수집 1.5배", coinCost = 80 },
	{ id = "extra_life",  name = "추가 라이프",  desc = "시작 라이프 +1",          coinCost = 60 },
	{ id = "slow_start",  name = "슬로우 스타트", desc = "시작 15초 속도 70%",     coinCost = 40 },
}

GameConstants.BATTLE_PASS = {
	SEASON_DURATION_DAYS = 28,
	PRICE_ROBUX = 149,
	GAME_PASS_ID = 1761124660,
	MAX_LEVEL = 30,
	-- 레벨별 필요 XP (레벨 1→2에 100XP, 레벨 2→3에 150XP, ...)
	XP_PER_LEVEL = {
		[1] = 100, [2] = 150, [3] = 200, [4] = 200, [5] = 250,
		[6] = 250, [7] = 300, [8] = 300, [9] = 350, [10] = 350,
		[11] = 400, [12] = 400, [13] = 450, [14] = 450, [15] = 500,
		[16] = 500, [17] = 550, [18] = 550, [19] = 600, [20] = 600,
		[21] = 650, [22] = 650, [23] = 700, [24] = 700, [25] = 750,
		[26] = 750, [27] = 800, [28] = 800, [29] = 900, [30] = 1000,
	},
	-- 레벨별 무료 보상 (모든 플레이어)
	FREE_REWARDS = {
		[1]  = { type = "coins",   amount = 100 },
		[3]  = { type = "coins",   amount = 200 },
		[5]  = { type = "nametag", id = "color_gold" },
		[7]  = { type = "coins",   amount = 300 },
		[10] = { type = "gems",    amount = 10 },
		[12] = { type = "coins",   amount = 500 },
		[15] = { type = "nametag", id = "frame_star" },
		[17] = { type = "coins",   amount = 500 },
		[20] = { type = "gems",    amount = 20 },
		[22] = { type = "coins",   amount = 800 },
		[25] = { type = "character", id = "fairy" },
		[27] = { type = "coins",   amount = 800 },
		[30] = { type = "gems",    amount = 50 },
	},
	-- 레벨별 프리미엄 보상 (149R$ 구매자)
	PREMIUM_REWARDS = {
		[1]  = { type = "gems",    amount = 10 },
		[2]  = { type = "coins",   amount = 200 },
		[3]  = { type = "gems",    amount = 15 },
		[5]  = { type = "skin",    id = "season_spring" },
		[7]  = { type = "gems",    amount = 20 },
		[10] = { type = "pet",     id = "cat" },
		[12] = { type = "gems",    amount = 25 },
		[15] = { type = "nametag", id = "frame_crown" },
		[17] = { type = "gems",    amount = 30 },
		[20] = { type = "skin",    id = "season_summer" },
		[22] = { type = "gems",    amount = 35 },
		[25] = { type = "nametag", id = "badge_combo_master" },
		[27] = { type = "gems",    amount = 40 },
		[30] = { type = "skin",    id = "season_finale" },
	},
	-- XP 획득 소스
	XP_SOURCES = {
		COIN_COLLECTED_PER_10 = 1,   -- 코인 10개당 1 XP
		COMBO_10 = 5,                 -- 콤보 10회 달성 시 5 XP
		FEVER = 20,                   -- 피버 발동 시 20 XP
		MISSION_COMPLETE = 50,        -- 미션 완료 시 50 XP
		DAILY_LOGIN = 30,             -- 일일 로그인 시 30 XP
		RUN_COMPLETE = 10,            -- 런 완료 시 10 XP (거리 무관)
	},
}

-- Ghost Racing
GameConstants.GHOST = {
	MAX_ACTIONS = 500,        -- maximum stored actions (jump/slide events) per run
	TRANSPARENCY = 0.5,       -- ghost body transparency
	SYNC_DELAY = 0.1,         -- client interpolation delay (seconds)
	FRIEND_LIMIT = 1,         -- max simultaneous ghost display count
	RUN_DURATION_LIMIT = 300, -- max run duration to record (seconds)
}

-- Team Weekly Ranking
GameConstants.TEAM = {
	MAX_MEMBERS = 5,
	CREATE_COST = 500,
	MIN_MEMBERSHIP_HOURS = 24,
	WEEKLY_REWARD_TIERS = {
		{ maxRank = 1,  gems = 100 },
		{ maxRank = 3,  gems = 50 },
		{ maxRank = 10, gems = 25 },
		{ maxRank = 50, gems = 10 },
	},
	MAX_TEAM_NAME_LENGTH = 20,
	RANKING_STORE_KEY = "TeamWeeklyRanking",
}

-- Co-op Mode
GameConstants.COOP = {
	MAX_PLAYERS = 2,
	LANES = { Z_LEFT = -4, Z_RIGHT = 4 }, -- Z-axis lane positions
	SHARED_LIVES = 5,          -- shared life pool
	COMBO_SHARE = true,        -- combos are aggregated across both players
	REVIVE_PARTNER = true,     -- downed partner can be revived
	MATCHMAKING_TIMEOUT = 30,  -- seconds before bot partner is inserted
	BOT_NAME = "CoopBot",
	SESSION_ID_PREFIX = "coop_",
}

-- Active Skill System (v3)
GameConstants.ACTIVE_SKILLS = {
	MAX_EQUIPPED = 1,
	SKILLS = {
		dash = {
			id = "dash",
			displayName = "Dash",
			emoji = "💨",
			desc = "Burst forward at 3x speed for 0.5s",
			cooldown = 12,
			duration = 0.5,
			speedMultiplier = 3.0,
			unlockUpgrade = "base_speed",
			unlockLevel = 3,
		},
		shield = {
			id = "shield",
			displayName = "Shield",
			emoji = "🛡️",
			desc = "Block 2 hits for 5 seconds",
			cooldown = 20,
			duration = 5,
			shieldHits = 2,
			unlockUpgrade = "base_lives",
			unlockLevel = 3,
		},
		active_magnet_burst = {
			id = "active_magnet_burst",
			displayName = "Magnet Burst",
			emoji = "🧲",
			desc = "Pull all nearby coins instantly",
			cooldown = 15,
			duration = 0,
			radius = 35,
			unlockUpgrade = "skill_cooldown",
			unlockLevel = 5,
		},
	},
}

-- Random Event System (v3)
GameConstants.RANDOM_EVENTS = {
	TRIGGER_INTERVAL = 8,  -- average seconds between events (줄임: 첫 이벤트 체감 개선)
	TRIGGER_VARIANCE = 3,  -- +/- seconds randomness

	-- Solo mode adjustments
	SOLO_TRIGGER_INTERVAL = 12, -- less frequent in solo (more breathing room)
	SOLO_EVENT_MAX_DURATION = 10, -- cap event duration in solo
	EVENTS = {
		{
			id = "coin_rain",
			displayName = "Coin Rain",
			emoji = "🌧️",
			duration = 10,
			effect = "double_coin_spawn",
		},
		{
			id = "speed_shift",
			displayName = "Speed Shift",
			emoji = "⚡",
			duration = 8,
			effect = "speed_change",
			speedMultiplier = 1.5,
		},
		{
			id = "giant_mode",
			displayName = "Giant Mode",
			emoji = "🦖",
			duration = 10,
			effect = "scale_change",
			scaleFactor = 1.8,
		},
		{
			id = "gravity_flip",
			displayName = "Low Gravity",
			emoji = "🌙",
			duration = 8,
			effect = "gravity_change",
			gravityMultiplier = 0.4,
		},
		{
			id = "fog",
			displayName = "Fog",
			emoji = "🌫️",
			duration = 12,
			effect = "visibility_change",
			fogEnd = 80,
		},
		{
			id = "bonus_time",
			displayName = "BONUS TIME!",
			emoji = "🎉",
			duration = 12,
			effect = "bonus_time",
			coinMultiplier = 3,     -- 코인 3배
			speedReduction = 0.75,  -- 속도 75%로 감소
		},
	},
}

-- 보너스 타임 상수 (미니게임 대체, 러너 흐름 유지)
GameConstants.BONUS_TIME = {
	COIN_MULTIPLIER = 3,      -- 코인 가치 3배
	SPEED_REDUCTION = 0.75,   -- 이동 속도 75%
	OBSTACLE_REDUCE = true,   -- 장애물 밀도 감소 (Bonus 청크와 유사)
}

-- Daily Challenge System (v3)
GameConstants.DAILY_CHALLENGES = {
	CHALLENGES_PER_DAY = 3,
	RESET_HOUR_UTC = 0,
	XP_REWARDS = { easy = 20, normal = 40, hard = 80 },
	CHALLENGE_POOL = {
		{ id = "collect_coins", desc = "Collect %d coins", difficulty = "easy", targets = { 100, 200, 300 } },
		{ id = "dodge_obstacles", desc = "Dodge %d obstacles", difficulty = "easy", targets = { 20, 30, 50 } },
		{ id = "reach_combo", desc = "Reach %dx combo", difficulty = "normal", targets = { 10, 15, 20 } },
		{ id = "play_runs", desc = "Complete %d runs", difficulty = "easy", targets = { 3, 5, 7 } },
		{ id = "fever_count", desc = "Activate fever %d times", difficulty = "normal", targets = { 2, 3, 5 } },
		{ id = "score_total", desc = "Score %d total points", difficulty = "hard", targets = { 500, 1000, 2000 } },
		{ id = "coop_runs", desc = "Play %d Co-op runs", difficulty = "hard", targets = { 1, 2, 3 } },
		{ id = "use_skill", desc = "Use active skill %d times", difficulty = "normal", targets = { 2, 3, 5 } },
	},
}

-- Soft Launch Verification (v3)
GameConstants.V3_VERSION = "3.0.0"
GameConstants.V3_FEATURES = {
	"tutorial_5step",
	"permanent_growth",
	"active_skills",
	"random_events",
	"daily_challenges",
}

return GameConstants

--!strict
-- ScenarioConstants
-- 시나리오 시스템: 챕터, 퀘스트, 스킬, 컷씬 데이터 정의

local ScenarioConstants = {}

-- ==================== 캐릭터 프로필 ====================

ScenarioConstants.CHARACTER_PROFILES = {
	owl      = { id = "owl",       name = "부엉이 박사",         emoji = "🦉", role = "mentor",  bgColor = Color3.fromRGB(40, 80, 180),   textColor = Color3.fromRGB(200, 220, 255) },
	coin_king = { id = "coin_king", name = "코인 킹",             emoji = "🦊", role = "villain", bgColor = Color3.fromRGB(180, 30, 30),   textColor = Color3.fromRGB(255, 200, 200) },
	player   = { id = "player",    name = "너",                   emoji = "🏃", role = "hero",    bgColor = Color3.fromRGB(40, 160, 80),   textColor = Color3.fromRGB(200, 255, 200) },
	chichi   = { id = "chichi",    name = "다람쥐 치치",           emoji = "🐿️", role = "ally",    bgColor = Color3.fromRGB(60, 140, 60),   textColor = Color3.fromRGB(220, 255, 220) },
	cyberbot = { id = "cyberbot",  name = "사이버봇",             emoji = "🤖", role = "ally",    bgColor = Color3.fromRGB(60, 100, 180),  textColor = Color3.fromRGB(200, 220, 255) },
	hamam    = { id = "hamam",     name = "사막 상인 하맘",       emoji = "🐪", role = "ally",    bgColor = Color3.fromRGB(160, 110, 40),  textColor = Color3.fromRGB(255, 240, 200) },
	luna     = { id = "luna",      name = "눈의 정령 루나",       emoji = "❄️", role = "ally",    bgColor = Color3.fromRGB(60, 100, 160),  textColor = Color3.fromRGB(200, 230, 255) },
	marina   = { id = "marina",    name = "바다 요정 마리나",     emoji = "🐠", role = "ally",    bgColor = Color3.fromRGB(20, 80, 160),   textColor = Color3.fromRGB(180, 220, 255) },
	bulmu    = { id = "bulmu",     name = "화산 수호자 불무",     emoji = "🌋", role = "ally",    bgColor = Color3.fromRGB(140, 40, 10),   textColor = Color3.fromRGB(255, 200, 180) },
	areum    = { id = "areum",     name = "구름 왕자 아름",       emoji = "☁️", role = "ally",    bgColor = Color3.fromRGB(100, 80, 160),  textColor = Color3.fromRGB(220, 210, 255) },
	alexander = { id = "alexander", name = "고대 수호자 알렉산더", emoji = "🏛️", role = "ally",    bgColor = Color3.fromRGB(100, 80, 40),   textColor = Color3.fromRGB(240, 220, 180) },
	omega    = { id = "omega",     name = "우주 AI 오메가",       emoji = "🛸", role = "ally",    bgColor = Color3.fromRGB(20, 20, 80),    textColor = Color3.fromRGB(180, 200, 255) },
}

-- ==================== 챕터 테마 ====================

ScenarioConstants.CHAPTER_THEMES = {
	ch1  = { bgColor = Color3.fromRGB(20, 60, 20),   accentColor = Color3.fromRGB(80, 180, 80)   },
	ch2  = { bgColor = Color3.fromRGB(30, 40, 80),   accentColor = Color3.fromRGB(120, 160, 255) },
	ch3  = { bgColor = Color3.fromRGB(100, 70, 20),  accentColor = Color3.fromRGB(220, 170, 60)  },
	ch4  = { bgColor = Color3.fromRGB(40, 60, 100),  accentColor = Color3.fromRGB(160, 210, 255) },
	ch5  = { bgColor = Color3.fromRGB(10, 40, 80),   accentColor = Color3.fromRGB(60, 180, 240)  },
	ch6  = { bgColor = Color3.fromRGB(80, 20, 5),    accentColor = Color3.fromRGB(240, 80, 30)   },
	ch7  = { bgColor = Color3.fromRGB(60, 55, 100),  accentColor = Color3.fromRGB(180, 170, 255) },
	ch8  = { bgColor = Color3.fromRGB(60, 50, 30),   accentColor = Color3.fromRGB(210, 185, 120) },
	ch9  = { bgColor = Color3.fromRGB(8, 8, 25),     accentColor = Color3.fromRGB(80, 130, 255)  },
	ch10 = { bgColor = Color3.fromRGB(50, 5, 5),     accentColor = Color3.fromRGB(255, 40, 40)   },
}

-- ==================== 보스 런 상수 ====================

ScenarioConstants.BOSS_RUN = {
	TIME_LIMIT       = 90,
	SPEED_MULTIPLIER = 1.3,
	LIVES            = 3,
	TARGET_SCORES = {
		ch1 = 500,  ch2 = 800,   ch3 = 1200, ch4 = 1800, ch5 = 2500,
		ch6 = 3500, ch7 = 4500,  ch8 = 6000, ch9 = 8000, ch10 = 12000,
	},
	BOSS_NAMES = {
		ch1  = "숲의 도둑",          ch2  = "도시의 파괴자",       ch3  = "사막의 도적",
		ch4  = "설원의 얼음마녀",    ch5  = "해저의 대형 오징어",  ch6  = "화산의 용",
		ch7  = "폭풍 정령",          ch8  = "유적의 석상 병사",    ch9  = "우주 해적선",
		ch10 = "코인 킹",
	},
	CLEAR_REWARDS = {
		ch1  = { coins = 100,  gems = 3   },
		ch2  = { coins = 150,  gems = 5   },
		ch3  = { coins = 200,  gems = 7   },
		ch4  = { coins = 300,  gems = 10  },
		ch5  = { coins = 400,  gems = 12  },
		ch6  = { coins = 500,  gems = 15  },
		ch7  = { coins = 600,  gems = 20  },
		ch8  = { coins = 800,  gems = 25  },
		ch9  = { coins = 1000, gems = 30  },
		ch10 = { coins = 2000, gems = 100 },
	},
}

-- ==================== 스킬 정의 ====================

ScenarioConstants.SKILLS = {
	double_jump = {
		id = "double_jump",
		name = "2단 점프",
		desc = "공중에서 한 번 더 점프할 수 있어요!",
		icon = "⬆️",
		unlockChapter = 2,
	},
	dash = {
		id = "dash",
		name = "대쉬",
		desc = "앞으로 순간 이동! (쿨다운 8초)",
		icon = "💨",
		unlockChapter = 4,
		cooldown = 8,
	},
	shield_regen = {
		id = "shield_regen",
		name = "쉴드 재생",
		desc = "60초마다 쉴드가 자동으로 채워져요!",
		icon = "🛡️",
		unlockChapter = 6,
		regenInterval = 60,
	},
	magnet_burst = {
		id = "magnet_burst",
		name = "자석 폭발",
		desc = "장애물에 맞으면 주변 코인을 전부 흡수해요!",
		icon = "🧲",
		unlockChapter = 8,
		burstRadius = 30,
	},
	fever_boost = {
		id = "fever_boost",
		name = "피버 부스트",
		desc = "피버 게이지가 30% 더 빠르게 채워져요!",
		icon = "🔥",
		unlockChapter = 10,
		gaugeMultiplier = 1.3,
	},
}

-- 스킬 순서 (UI 표시용)
ScenarioConstants.SKILL_ORDER = {
	"double_jump",
	"dash",
	"shield_regen",
	"magnet_burst",
	"fever_boost",
}

-- ==================== 퀘스트 정의 ====================
-- 퀘스트 타입:
--   play_games   : 게임 플레이 횟수 (누적)
--   score_reach  : 단판 점수 달성 (최고값)
--   collect_coins: 코인 수집 (누적)
--   near_miss    : 니어미스 횟수 (누적)
--   combo_ch     : 단판 최대 콤보 (최고값)
--   distance_ch  : 누적 달린 거리 m (누적)
--   survive_ch   : 장애물 회피 횟수 (누적)
--   powerup_ch   : 파워업 수집 횟수 (누적)
--   no_hit_run_ch: 피격 없이 게임 완주 횟수 (누적)

ScenarioConstants.QUESTS = {
	-- ===== 챕터 1: 숲의 시작 =====
	c1_play = { id = "c1_play", chapter = 1, type = "play_games", name = "첫 달리기", desc = "게임 5회 플레이", target = 5, reward = { xp = 20, coins = 30 } },
	c1_coin = { id = "c1_coin", chapter = 1, type = "collect_coins", name = "코인 수집가", desc = "코인 50개 수집", target = 50, reward = { xp = 20, coins = 40 } },
	c1_score = { id = "c1_score", chapter = 1, type = "score_reach", name = "점수 달성", desc = "300점 달성", target = 300, reward = { xp = 25, coins = 50 } },
	c1_nmiss = { id = "c1_nmiss", chapter = 1, type = "near_miss", name = "아슬아슬", desc = "니어미스 3회 달성", target = 3, reward = { xp = 25, coins = 40 } },

	-- ===== 챕터 2: 도시의 도전 =====
	c2_play = { id = "c2_play", chapter = 2, type = "play_games", name = "단골 러너", desc = "게임 10회 플레이", target = 10, reward = { xp = 30, coins = 50 } },
	c2_coin = { id = "c2_coin", chapter = 2, type = "collect_coins", name = "도시의 보물", desc = "코인 150개 수집", target = 150, reward = { xp = 30, coins = 60 } },
	c2_score = { id = "c2_score", chapter = 2, type = "score_reach", name = "500점 돌파", desc = "500점 달성", target = 500, reward = { xp = 35, coins = 70 } },
	c2_combo = { id = "c2_combo", chapter = 2, type = "combo_ch", name = "연속 콤보", desc = "10콤보 달성", target = 10, reward = { xp = 35, coins = 60 } },
	c2_dist = { id = "c2_dist", chapter = 2, type = "distance_ch", name = "도시 횡단", desc = "1000m 달리기", target = 1000, reward = { xp = 40, coins = 80 } },

	-- ===== 챕터 3: 사막 탐험 =====
	c3_play = { id = "c3_play", chapter = 3, type = "play_games", name = "탐험가", desc = "게임 20회 플레이", target = 20, reward = { xp = 40, coins = 60 } },
	c3_score = { id = "c3_score", chapter = 3, type = "score_reach", name = "1000점 달성", desc = "1000점 달성", target = 1000, reward = { xp = 45, coins = 80 } },
	c3_coin = { id = "c3_coin", chapter = 3, type = "collect_coins", name = "사막의 보물", desc = "코인 400개 수집", target = 400, reward = { xp = 40, coins = 70 } },
	c3_nmiss = { id = "c3_nmiss", chapter = 3, type = "near_miss", name = "모래 폭풍 회피", desc = "니어미스 15회 달성", target = 15, reward = { xp = 45, coins = 80 } },
	c3_surv = { id = "c3_surv", chapter = 3, type = "survive_ch", name = "장애물 극복", desc = "장애물 30개 회피", target = 30, reward = { xp = 50, coins = 90 } },
	c3_dist = { id = "c3_dist", chapter = 3, type = "distance_ch", name = "사막 종단", desc = "3000m 달리기", target = 3000, reward = { xp = 50, coins = 100 } },

	-- ===== 챕터 4: 설원의 시련 =====
	c4_play = { id = "c4_play", chapter = 4, type = "play_games", name = "눈 속의 러너", desc = "게임 35회 플레이", target = 35, reward = { xp = 50, coins = 80 } },
	c4_score = { id = "c4_score", chapter = 4, type = "score_reach", name = "2000점 돌파", desc = "2000점 달성", target = 2000, reward = { xp = 60, coins = 100 } },
	c4_coin = { id = "c4_coin", chapter = 4, type = "collect_coins", name = "설원 탐색", desc = "코인 800개 수집", target = 800, reward = { xp = 55, coins = 90 } },
	c4_nohit = { id = "c4_nohit", chapter = 4, type = "no_hit_run_ch", name = "완벽한 런", desc = "피격 없이 3회 완주", target = 3, reward = { xp = 70, coins = 120 } },
	c4_combo = { id = "c4_combo", chapter = 4, type = "combo_ch", name = "슈퍼 콤보", desc = "20콤보 달성", target = 20, reward = { xp = 65, coins = 110 } },
	c4_pwup = { id = "c4_pwup", chapter = 4, type = "powerup_ch", name = "파워업 수집", desc = "파워업 15개 수집", target = 15, reward = { xp = 55, coins = 90 } },
	c4_dist = { id = "c4_dist", chapter = 4, type = "distance_ch", name = "설원 횡단", desc = "6000m 달리기", target = 6000, reward = { xp = 65, coins = 110 } },

	-- ===== 챕터 5: 해저 세계 =====
	c5_score = { id = "c5_score", chapter = 5, type = "score_reach", name = "3500점 달성", desc = "3500점 달성", target = 3500, reward = { xp = 70, coins = 120 } },
	c5_play = { id = "c5_play", chapter = 5, type = "play_games", name = "바닷속 러너", desc = "게임 50회 플레이", target = 50, reward = { xp = 65, coins = 100 } },
	c5_coin = { id = "c5_coin", chapter = 5, type = "collect_coins", name = "해저 보물", desc = "코인 1500개 수집", target = 1500, reward = { xp = 70, coins = 120 } },
	c5_nmiss = { id = "c5_nmiss", chapter = 5, type = "near_miss", name = "물결 피하기", desc = "니어미스 30회 달성", target = 30, reward = { xp = 75, coins = 130 } },
	c5_surv = { id = "c5_surv", chapter = 5, type = "survive_ch", name = "산호초 미로", desc = "장애물 80개 회피", target = 80, reward = { xp = 80, coins = 140 } },
	c5_nohit = { id = "c5_nohit", chapter = 5, type = "no_hit_run_ch", name = "무결점 수영", desc = "피격 없이 5회 완주", target = 5, reward = { xp = 90, coins = 160 } },

	-- ===== 챕터 6: 화산 지대 =====
	c6_score = { id = "c6_score", chapter = 6, type = "score_reach", name = "5000점 돌파", desc = "5000점 달성", target = 5000, reward = { xp = 90, coins = 150 } },
	c6_play = { id = "c6_play", chapter = 6, type = "play_games", name = "화산 탐험가", desc = "게임 70회 플레이", target = 70, reward = { xp = 80, coins = 130 } },
	c6_coin = { id = "c6_coin", chapter = 6, type = "collect_coins", name = "용암 속 코인", desc = "코인 2500개 수집", target = 2500, reward = { xp = 90, coins = 150 } },
	c6_combo = { id = "c6_combo", chapter = 6, type = "combo_ch", name = "폭발 콤보", desc = "30콤보 달성", target = 30, reward = { xp = 100, coins = 170 } },
	c6_nmiss = { id = "c6_nmiss", chapter = 6, type = "near_miss", name = "용암 피하기", desc = "니어미스 50회 달성", target = 50, reward = { xp = 95, coins = 160 } },
	c6_dist = { id = "c6_dist", chapter = 6, type = "distance_ch", name = "화산 지대 종단", desc = "15000m 달리기", target = 15000, reward = { xp = 100, coins = 170 } },
	c6_pwup = { id = "c6_pwup", chapter = 6, type = "powerup_ch", name = "파워 수집가", desc = "파워업 40개 수집", target = 40, reward = { xp = 90, coins = 150 } },

	-- ===== 챕터 7: 구름 왕국 =====
	c7_score = { id = "c7_score", chapter = 7, type = "score_reach", name = "7000점 달성", desc = "7000점 달성", target = 7000, reward = { xp = 110, coins = 180 } },
	c7_play = { id = "c7_play", chapter = 7, type = "play_games", name = "하늘의 러너", desc = "게임 100회 플레이", target = 100, reward = { xp = 100, coins = 160 } },
	c7_coin = { id = "c7_coin", chapter = 7, type = "collect_coins", name = "구름 코인", desc = "코인 4000개 수집", target = 4000, reward = { xp = 110, coins = 180 } },
	c7_nohit = { id = "c7_nohit", chapter = 7, type = "no_hit_run_ch", name = "완벽한 비행", desc = "피격 없이 8회 완주", target = 8, reward = { xp = 130, coins = 220 } },
	c7_surv = { id = "c7_surv", chapter = 7, type = "survive_ch", name = "구름 장애물", desc = "장애물 150개 회피", target = 150, reward = { xp = 120, coins = 200 } },
	c7_combo = { id = "c7_combo", chapter = 7, type = "combo_ch", name = "구름 콤보", desc = "40콤보 달성", target = 40, reward = { xp = 125, coins = 210 } },
	c7_dist = { id = "c7_dist", chapter = 7, type = "distance_ch", name = "구름 왕국 횡단", desc = "25000m 달리기", target = 25000, reward = { xp = 130, coins = 220 } },

	-- ===== 챕터 8: 고대 유적 =====
	c8_score = { id = "c8_score", chapter = 8, type = "score_reach", name = "9000점 달성", desc = "9000점 달성", target = 9000, reward = { xp = 140, coins = 240 } },
	c8_play = { id = "c8_play", chapter = 8, type = "play_games", name = "고대 탐험가", desc = "게임 130회 플레이", target = 130, reward = { xp = 130, coins = 220 } },
	c8_coin = { id = "c8_coin", chapter = 8, type = "collect_coins", name = "유적 보물", desc = "코인 6000개 수집", target = 6000, reward = { xp = 140, coins = 240 } },
	c8_nmiss = { id = "c8_nmiss", chapter = 8, type = "near_miss", name = "함정 피하기", desc = "니어미스 80회 달성", target = 80, reward = { xp = 150, coins = 260 } },
	c8_combo = { id = "c8_combo", chapter = 8, type = "combo_ch", name = "유적 콤보", desc = "50콤보 달성", target = 50, reward = { xp = 160, coins = 280 } },
	c8_nohit = { id = "c8_nohit", chapter = 8, type = "no_hit_run_ch", name = "무결점 탐험", desc = "피격 없이 10회 완주", target = 10, reward = { xp = 180, coins = 320 } },
	c8_pwup = { id = "c8_pwup", chapter = 8, type = "powerup_ch", name = "유물 수집", desc = "파워업 70개 수집", target = 70, reward = { xp = 150, coins = 260 } },
	c8_dist = { id = "c8_dist", chapter = 8, type = "distance_ch", name = "유적 탐사", desc = "40000m 달리기", target = 40000, reward = { xp = 165, coins = 290 } },

	-- ===== 챕터 9: 우주 여행 =====
	c9_score = { id = "c9_score", chapter = 9, type = "score_reach", name = "12000점 달성", desc = "12000점 달성", target = 12000, reward = { xp = 200, coins = 350 } },
	c9_play = { id = "c9_play", chapter = 9, type = "play_games", name = "우주 비행사", desc = "게임 160회 플레이", target = 160, reward = { xp = 180, coins = 320 } },
	c9_coin = { id = "c9_coin", chapter = 9, type = "collect_coins", name = "별 코인", desc = "코인 9000개 수집", target = 9000, reward = { xp = 200, coins = 350 } },
	c9_surv = { id = "c9_surv", chapter = 9, type = "survive_ch", name = "유성우 회피", desc = "장애물 250개 회피", target = 250, reward = { xp = 220, coins = 380 } },
	c9_nmiss = { id = "c9_nmiss", chapter = 9, type = "near_miss", name = "소행성 회피", desc = "니어미스 110회 달성", target = 110, reward = { xp = 220, coins = 380 } },
	c9_combo = { id = "c9_combo", chapter = 9, type = "combo_ch", name = "우주 콤보", desc = "60콤보 달성", target = 60, reward = { xp = 240, coins = 420 } },
	c9_dist = { id = "c9_dist", chapter = 9, type = "distance_ch", name = "은하 횡단", desc = "60000m 달리기", target = 60000, reward = { xp = 250, coins = 440 } },
	c9_nohit = { id = "c9_nohit", chapter = 9, type = "no_hit_run_ch", name = "무중력 런", desc = "피격 없이 15회 완주", target = 15, reward = { xp = 280, coins = 500 } },

	-- ===== 챕터 10: 전설의 정점 =====
	c10_score = { id = "c10_score", chapter = 10, type = "score_reach", name = "15000점 달성", desc = "15000점 달성", target = 15000, reward = { xp = 300, coins = 500 } },
	c10_play = { id = "c10_play", chapter = 10, type = "play_games", name = "전설의 러너", desc = "게임 200회 플레이", target = 200, reward = { xp = 280, coins = 480 } },
	c10_coin = { id = "c10_coin", chapter = 10, type = "collect_coins", name = "전설의 보물", desc = "코인 15000개 수집", target = 15000, reward = { xp = 300, coins = 500 } },
	c10_dist = { id = "c10_dist", chapter = 10, type = "distance_ch", name = "세계 일주", desc = "100000m 달리기", target = 100000, reward = { xp = 350, coins = 600 } },
	c10_nohit = { id = "c10_nohit", chapter = 10, type = "no_hit_run_ch", name = "무적 런", desc = "피격 없이 20회 완주", target = 20, reward = { xp = 400, coins = 700 } },
	c10_combo = { id = "c10_combo", chapter = 10, type = "combo_ch", name = "전설 콤보", desc = "80콤보 달성", target = 80, reward = { xp = 380, coins = 650 } },
	c10_nmiss = { id = "c10_nmiss", chapter = 10, type = "near_miss", name = "전설의 회피", desc = "니어미스 150회 달성", target = 150, reward = { xp = 350, coins = 600 } },
	c10_pwup = { id = "c10_pwup", chapter = 10, type = "powerup_ch", name = "파워 마스터", desc = "파워업 120개 수집", target = 120, reward = { xp = 320, coins = 550 } },
}

-- ==================== 챕터 정의 ====================
-- statBonus: 챕터 완료 시 영구 적용되는 스탯 보너스 (ratio)
--   speed      : 기본 속도 배율 보너스 (0.03 = +3%)
--   jump       : 점프 높이 배율 보너스
--   coinValue  : 코인 가치 배율 보너스
--   magnetRadius: 자석 범위 배율 보너스
--   maxLives   : 시작 라이프 추가 (정수)
--   feverGauge : 피버 게이지 충전 속도 배율 보너스

ScenarioConstants.CHAPTERS = {
	{
		id = "ch1",
		num = 1,
		name = "숲의 시작",
		theme = "🌲",
		description = "코인 킹이 숲의 코인을 훔쳐갔어! 다람쥐 치치와 함께 되찾자!",
		allyId = "chichi",
		questIds = { "c1_play", "c1_coin", "c1_score", "c1_nmiss" },
		unlockConditions = { minScore = 0, requiredCompletedChapters = {} },
		skill = nil,
		statBonus = { coinValue = 0.05 },
		chapterReward = { gems = 5, xp = 100 },
	},
	{
		id = "ch2",
		num = 2,
		name = "도시의 도전",
		theme = "🏙️",
		description = "도시에도 코인 킹의 그림자가! 사이버봇과 함께 2단 점프로 도약하자!",
		allyId = "cyberbot",
		questIds = { "c2_play", "c2_coin", "c2_score", "c2_combo", "c2_dist" },
		unlockConditions = { minScore = 500, requiredCompletedChapters = { "ch1" } },
		skill = "double_jump",
		statBonus = { speed = 0.03 },
		chapterReward = { gems = 10, xp = 200 },
	},
	{
		id = "ch3",
		num = 3,
		name = "사막 탐험",
		theme = "🏜️",
		description = "사막 상인 하맘의 코인이 위험해! 대쉬로 빠르게 되찾자!",
		allyId = "hamam",
		questIds = { "c3_play", "c3_score", "c3_coin", "c3_nmiss", "c3_surv", "c3_dist" },
		unlockConditions = { minScore = 1000, requiredCompletedChapters = { "ch1", "ch2" } },
		skill = nil,
		statBonus = { magnetRadius = 0.10 },
		chapterReward = { gems = 15, xp = 300 },
	},
	{
		id = "ch4",
		num = 4,
		name = "설원의 시련",
		theme = "❄️",
		description = "설원의 정령 루나를 도와 코인 킹의 얼음 부하를 물리쳐!",
		allyId = "luna",
		questIds = { "c4_play", "c4_score", "c4_coin", "c4_nohit", "c4_combo", "c4_pwup", "c4_dist" },
		unlockConditions = { minScore = 2000, requiredCompletedChapters = { "ch1", "ch2", "ch3" } },
		skill = "dash",
		statBonus = { jump = 0.05 },
		chapterReward = { gems = 20, xp = 400 },
	},
	{
		id = "ch5",
		num = 5,
		name = "해저 세계",
		theme = "🌊",
		description = "바다 요정 마리나와 함께 해저의 코인을 지켜라!",
		allyId = "marina",
		questIds = { "c5_score", "c5_play", "c5_coin", "c5_nmiss", "c5_surv", "c5_nohit" },
		unlockConditions = { minScore = 3500, requiredCompletedChapters = { "ch1", "ch2", "ch3", "ch4" } },
		skill = nil,
		statBonus = { coinValue = 0.10 },
		chapterReward = { gems = 25, xp = 500 },
	},
	{
		id = "ch6",
		num = 6,
		name = "화산 지대",
		theme = "🌋",
		description = "화산 수호자 불무와 코인 킹의 용을 무찔러라!",
		allyId = "bulmu",
		questIds = { "c6_score", "c6_play", "c6_coin", "c6_combo", "c6_nmiss", "c6_dist", "c6_pwup" },
		unlockConditions = { minScore = 5000, requiredCompletedChapters = { "ch1", "ch2", "ch3", "ch4", "ch5" } },
		skill = "shield_regen",
		statBonus = { speed = 0.05 },
		chapterReward = { gems = 30, xp = 600 },
	},
	{
		id = "ch7",
		num = 7,
		name = "구름 왕국",
		theme = "☁️",
		description = "구름 왕자 아름과 하늘의 코인을 되찾아라!",
		allyId = "areum",
		questIds = { "c7_score", "c7_play", "c7_coin", "c7_nohit", "c7_surv", "c7_combo", "c7_dist" },
		unlockConditions = { minScore = 7000, requiredCompletedChapters = { "ch1", "ch2", "ch3", "ch4", "ch5", "ch6" } },
		skill = nil,
		statBonus = { maxLives = 1 },
		chapterReward = { gems = 40, xp = 800 },
	},
	{
		id = "ch8",
		num = 8,
		name = "고대 유적",
		theme = "🏛️",
		description = "고대 수호자 알렉산더와 유적의 비밀을 밝혀라!",
		allyId = "alexander",
		questIds = { "c8_score", "c8_play", "c8_coin", "c8_nmiss", "c8_combo", "c8_nohit", "c8_pwup", "c8_dist" },
		unlockConditions = { minScore = 9000, requiredCompletedChapters = { "ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7" } },
		skill = "magnet_burst",
		statBonus = { magnetRadius = 0.15 },
		chapterReward = { gems = 50, xp = 1000 },
	},
	{
		id = "ch9",
		num = 9,
		name = "우주 여행",
		theme = "🚀",
		description = "우주 AI 오메가와 함께 코인 킹의 우주 해적선을 막아라!",
		allyId = "omega",
		questIds = { "c9_score", "c9_play", "c9_coin", "c9_surv", "c9_nmiss", "c9_combo", "c9_dist", "c9_nohit" },
		unlockConditions = { minScore = 12000, requiredCompletedChapters = { "ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "ch8" } },
		skill = nil,
		statBonus = { feverGauge = 0.20 },
		chapterReward = { gems = 60, xp = 1200 },
	},
	{
		id = "ch10",
		num = 10,
		name = "전설의 정점",
		theme = "👑",
		description = "드디어 코인 킹 본인과 최후의 대결! 모든 세계를 구하자!",
		allyId = "owl",
		questIds = { "c10_score", "c10_play", "c10_coin", "c10_dist", "c10_nohit", "c10_combo", "c10_nmiss", "c10_pwup" },
		unlockConditions = {
			minScore = 15000,
			requiredCompletedChapters = { "ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "ch8", "ch9" },
		},
		skill = "fever_boost",
		statBonus = { speed = 0.05, jump = 0.05, coinValue = 0.05, magnetRadius = 0.05, feverGauge = 0.05 },
		chapterReward = { gems = 100, xp = 2000 },
	},
}

-- 챕터 ID → 챕터 데이터 빠른 조회 맵
ScenarioConstants.CHAPTER_MAP = {} :: { [string]: typeof(ScenarioConstants.CHAPTERS[1]) }
for _, chapter in ScenarioConstants.CHAPTERS do
	ScenarioConstants.CHAPTER_MAP[chapter.id] = chapter
end

-- ==================== 컷씬 데이터 ====================

ScenarioConstants.CUTSCENES = {
	ch1 = {
		opening = {
			{ characterId = "owl",    text = "큰일이야! 코인 킹이 숲의 코인을 전부 훔쳐갔어!" },
			{ characterId = "chichi", text = "안녕! 나는 다람쥐 치치야. 이 숲을 구해줄 수 있어?" },
			{ characterId = "player", text = "맡겨봐! 코인을 반드시 되찾아 줄게!" },
			{ characterId = "owl",    text = "조심해, 코인 킹이 부하를 보냈을 거야." },
		},
		clear = {
			{ characterId = "player", text = "숲의 퀘스트를 모두 완료했어!" },
			{ characterId = "chichi", text = "고마워! 근데 아직 보스 부하가 남아있어..." },
			{ characterId = "owl",    text = "코인 킹의 부하를 물리쳐야 완전히 자유로워져!" },
		},
		bossIntro = {
			{ characterId = "coin_king", text = "크크크... 이 숲은 이제 내 거다!", effect = "shake" },
			{ characterId = "player",    text = "코인 킹의 부하! 여기서 끝내주겠어!" },
		},
		bossWin = {
			{ characterId = "player", text = "해냈다! 숲이 자유로워졌어!", effect = "particle" },
			{ characterId = "chichi", text = "정말 고마워! 도시에도 코인 킹의 부하가 있대!" },
			{ characterId = "owl",    text = "잘했어! 다음은 도시로 출발하자." },
		},
		bossLose = {
			{ characterId = "coin_king", text = "하하! 아직 멀었어, 꼬마!", effect = "shake" },
			{ characterId = "owl",       text = "괜찮아! 다시 도전해 보자!" },
		},
	},
	ch2 = {
		opening = {
			{ characterId = "owl",      text = "도시에도 코인 킹의 부하가 나타났어!" },
			{ characterId = "cyberbot", text = "저는 사이버봇이에요! 도시 코인을 지켜야 해요!" },
			{ characterId = "player",   text = "같이 싸우자! 2단 점프도 생겼으니 무적이야!" },
		},
		clear = {
			{ characterId = "cyberbot", text = "퀘스트 클리어! 하지만 보스가 남아있어요..." },
			{ characterId = "player",   text = "상관없어! 바로 물리쳐 주겠어!" },
		},
		bossIntro = {
			{ characterId = "coin_king", text = "도시의 코인도 모두 내 것이다!", effect = "shake" },
			{ characterId = "player",    text = "절대 허락 못 해!" },
		},
		bossWin = {
			{ characterId = "player",   text = "도시 해방!", effect = "particle" },
			{ characterId = "cyberbot", text = "감사합니다! 사막에도 코인 킹의 소식이 들려요." },
			{ characterId = "owl",      text = "예상대로야. 사막으로 가자!" },
		},
		bossLose = {
			{ characterId = "coin_king", text = "크크! 도시는 내 거야!", effect = "shake" },
			{ characterId = "cyberbot",  text = "포기하지 마세요! 다시 도전!" },
		},
	},
	ch3 = {
		opening = {
			{ characterId = "owl",    text = "사막의 코인도 모두 사라지고 있어!" },
			{ characterId = "hamam",  text = "나는 하맘이야. 이 사막을 코인 킹에게 뺏길 순 없어!" },
			{ characterId = "player", text = "걱정 마! 대쉬도 얻었으니 빠르게 처리할게!" },
		},
		clear = {
			{ characterId = "hamam",  text = "퀘스트 완료! 보스만 남았어." },
			{ characterId = "player", text = "바로 가자!" },
		},
		bossIntro = {
			{ characterId = "coin_king", text = "사막의 모든 보물은 내 거다!", effect = "shake" },
			{ characterId = "player",    text = "두고 보자!" },
		},
		bossWin = {
			{ characterId = "player", text = "사막 해방 완료!", effect = "particle" },
			{ characterId = "hamam",  text = "고마워! 설원에서도 이상한 소식이 들려." },
			{ characterId = "owl",    text = "서둘러야겠어. 코인 킹의 계획이 빨라지고 있어." },
		},
		bossLose = {
			{ characterId = "coin_king", text = "사막은 내 거야, 꼬마!", effect = "shake" },
			{ characterId = "hamam",     text = "힘내! 다시 도전해봐!" },
		},
	},
	ch4 = {
		opening = {
			{ characterId = "owl",    text = "설원에도 코인 킹의 얼음 부하가 나타났대!" },
			{ characterId = "luna",   text = "저는 루나예요. 이 눈 속을 함께 달려줄래요?" },
			{ characterId = "player", text = "물론이죠! 설원도 해방시켜 드릴게요!" },
		},
		clear = {
			{ characterId = "luna",   text = "퀘스트 완료! 하지만 보스가 더 강해요..." },
			{ characterId = "player", text = "걱정 마세요. 제가 해낼게요!" },
		},
		bossIntro = {
			{ characterId = "coin_king", text = "설원의 코인은 영원히 내 것!", effect = "shake" },
			{ characterId = "player",    text = "절대 안 돼!" },
		},
		bossWin = {
			{ characterId = "player", text = "설원 해방!", effect = "particle" },
			{ characterId = "luna",   text = "감사해요! 해저에도 코인 킹의 그림자가 드리워요..." },
			{ characterId = "owl",    text = "코인 킹이 점점 대담해지고 있어. 서두르자." },
		},
		bossLose = {
			{ characterId = "coin_king", text = "설원은 내 왕국이야!", effect = "shake" },
			{ characterId = "luna",      text = "포기하지 마요! 다시 일어서요!" },
		},
	},
	ch5 = {
		opening = {
			{ characterId = "owl",    text = "해저 세계까지 코인 킹의 손이 뻗쳤어!" },
			{ characterId = "marina", text = "안녕! 나는 마리나야. 바닷속 코인을 지켜줄 수 있어?" },
			{ characterId = "player", text = "바다도 해방시켜 줄게! 같이 싸우자!" },
		},
		clear = {
			{ characterId = "marina", text = "퀘스트 완료! 이제 보스를 물리쳐야 해." },
			{ characterId = "player", text = "알았어, 바로 가자!" },
		},
		bossIntro = {
			{ characterId = "coin_king", text = "바닷속 코인도 내 것이다!", effect = "shake" },
			{ characterId = "player",    text = "그건 못 줘!" },
		},
		bossWin = {
			{ characterId = "player", text = "바다 해방!", effect = "particle" },
			{ characterId = "marina", text = "고마워! 화산 지대가 위험해 보여..." },
			{ characterId = "owl",    text = "코인 킹의 계획 중반이야. 절반만 더 가자!" },
		},
		bossLose = {
			{ characterId = "coin_king", text = "바다는 나의 것!", effect = "shake" },
			{ characterId = "marina",    text = "괜찮아! 한 번 더 도전해봐!" },
		},
	},
	ch6 = {
		opening = {
			{ characterId = "owl",    text = "화산 지대에 코인 킹의 용 부하가 나타났어!" },
			{ characterId = "bulmu",  text = "나는 화산의 수호자 불무야! 함께 싸워줘!" },
			{ characterId = "player", text = "쉴드 재생도 생겼어! 이제 더 오래 버틸 수 있어!" },
		},
		clear = {
			{ characterId = "bulmu",  text = "퀘스트 완료! 하지만 보스가 엄청 강해..." },
			{ characterId = "player", text = "상관없어! 내가 막을게!" },
		},
		bossIntro = {
			{ characterId = "coin_king", text = "화산의 열기도, 코인도 모두 내 거야!", effect = "shake" },
			{ characterId = "player",    text = "두고 봐라!" },
		},
		bossWin = {
			{ characterId = "player", text = "화산 해방!", effect = "particle" },
			{ characterId = "bulmu",  text = "대단해! 구름 왕국도 코인 킹에게 위협받고 있어." },
			{ characterId = "owl",    text = "이제 4개 세계만 남았어. 포기하지 말자!" },
		},
		bossLose = {
			{ characterId = "coin_king", text = "화산도 내 왕국이야!", effect = "shake" },
			{ characterId = "bulmu",     text = "힘내! 불처럼 다시 타올라!" },
		},
	},
	ch7 = {
		opening = {
			{ characterId = "owl",    text = "구름 왕국에도 코인 킹의 폭풍 부하가 나타났대!" },
			{ characterId = "areum",  text = "나는 구름 왕자 아름이야! 하늘을 지켜줘!" },
			{ characterId = "player", text = "하늘도 지킬게! 최대 라이프가 늘었으니 거뜬해!" },
		},
		clear = {
			{ characterId = "areum",  text = "퀘스트 완료! 폭풍 정령 보스가 남아있어." },
			{ characterId = "player", text = "바로 해치워 줄게!" },
		},
		bossIntro = {
			{ characterId = "coin_king", text = "하늘의 코인도 내 것이다!", effect = "shake" },
			{ characterId = "player",    text = "네 야망은 여기서 끝이야!" },
		},
		bossWin = {
			{ characterId = "player", text = "구름 왕국 해방!", effect = "particle" },
			{ characterId = "areum",  text = "정말 고마워! 이제 고대 유적이 위험해." },
			{ characterId = "owl",    text = "코인 킹의 어둠의 기계... 거의 완성 단계야. 서둘러야 해!" },
		},
		bossLose = {
			{ characterId = "coin_king", text = "하늘은 내 왕좌야!", effect = "shake" },
			{ characterId = "areum",     text = "포기하지 마! 구름처럼 가볍게 다시 도전해!" },
		},
	},
	ch8 = {
		opening = {
			{ characterId = "owl",       text = "고대 유적에 코인 킹의 석상 병사들이 깨어났어!" },
			{ characterId = "alexander", text = "나는 알렉산더. 이 유적은 수천 년의 역사야. 지켜줘!" },
			{ characterId = "player",    text = "자석 폭발도 생겼어! 코인도 싹 쓸어담겠어!" },
		},
		clear = {
			{ characterId = "alexander", text = "퀘스트 완료! 석상 보스가 마지막 남았어." },
			{ characterId = "player",    text = "이번에야말로 끝내줄게!" },
		},
		bossIntro = {
			{ characterId = "coin_king", text = "고대의 코인도 내 컬렉션에 추가되겠군!", effect = "shake" },
			{ characterId = "player",    text = "오늘은 절대 안 돼!" },
		},
		bossWin = {
			{ characterId = "player",    text = "유적 해방!", effect = "particle" },
			{ characterId = "alexander", text = "감사하네! 우주까지 코인 킹의 손이 닿았다고 들었어." },
			{ characterId = "owl",       text = "이제 2개만 남았어. 코인 킹을 막을 수 있어!" },
		},
		bossLose = {
			{ characterId = "coin_king", text = "역사도 내 손 안에 있어!", effect = "shake" },
			{ characterId = "alexander", text = "힘내게! 역사는 용기 있는 자의 것이야!" },
		},
	},
	ch9 = {
		opening = {
			{ characterId = "owl",    text = "드디어 우주까지! 코인 킹의 우주 해적선이 나타났어!" },
			{ characterId = "omega",  text = "나는 우주 AI 오메가. 코인 킹이 은하계 코인을 노리고 있어!" },
			{ characterId = "player", text = "피버 부스트도 생겼어! 이제 최강이야!" },
		},
		clear = {
			{ characterId = "omega",  text = "퀘스트 완료! 우주 해적선과 최후 결전이야." },
			{ characterId = "player", text = "이제 진짜 끝내자!" },
		},
		bossIntro = {
			{ characterId = "coin_king", text = "우주의 코인도 내 어둠의 기계 연료가 될 거야!", effect = "shake" },
			{ characterId = "player",    text = "그 기계, 절대 완성 못 시켜!" },
		},
		bossWin = {
			{ characterId = "player", text = "우주 해방!", effect = "particle" },
			{ characterId = "omega",  text = "오직 코인 킹 본인만 남았어. 드디어 최후의 결전이야!" },
			{ characterId = "owl",    text = "마지막이야! 너라면 반드시 이길 수 있어!" },
		},
		bossLose = {
			{ characterId = "coin_king", text = "우주도 내 제국이야!", effect = "shake" },
			{ characterId = "omega",     text = "분석 결과: 재도전 확률 100%! 포기 금지!" },
		},
	},
	ch10 = {
		opening = {
			{ characterId = "owl",       text = "드디어 코인 킹의 성에 도달했어! 이게 마지막이야!" },
			{ characterId = "coin_king", text = "흥! 이 꼬마가 여기까지 오다니... 대단하군.", effect = "shake" },
			{ characterId = "player",    text = "모든 세계의 코인을 돌려놔! 이제 끝이야!" },
			{ characterId = "owl",       text = "조심해! 코인 킹 본인은 지금까지 부하들과 차원이 달라!" },
		},
		clear = {
			{ characterId = "player",    text = "드디어 모든 퀘스트 완료! 이제 코인 킹과 최후의 대결!" },
			{ characterId = "coin_king", text = "재미있군... 직접 상대해 주지!", effect = "shake" },
			{ characterId = "owl",       text = "지금까지 얻은 모든 스킬을 써! 이길 수 있어!" },
		},
		bossIntro = {
			{ characterId = "coin_king", text = "모든 세계의 코인을 가진 내가 최강이다!", effect = "shake" },
			{ characterId = "coin_king", text = "어둠의 기계가 완성되면 모든 세계가 내 것이 될 거야!", effect = "shake" },
			{ characterId = "player",    text = "절대 허락 못 해! 지금까지 만난 모든 친구들을 위해 싸울 거야!" },
		},
		bossWin = {
			{ characterId = "player",    text = "해냈다! 코인 킹을 무찔렀어!", effect = "particle" },
			{ characterId = "coin_king", text = "...이럴 수가. 내가 졌다고?", effect = "shake" },
			{ characterId = "owl",       text = "모든 세계의 코인이 돌아오고 있어! 네가 진정한 전설이야!" },
			{ characterId = "player",    text = "치치, 사이버봇, 하맘, 루나, 마리나, 불무, 아름, 알렉산더, 오메가... 모두의 도움이 있었어!", effect = "particle" },
		},
		bossLose = {
			{ characterId = "coin_king", text = "하하하! 내가 이겼다! 어둠의 기계가 완성된다!", effect = "shake" },
			{ characterId = "owl",       text = "괜찮아! 우리는 아직 포기하지 않아. 다시 도전하자!" },
			{ characterId = "player",    text = "반드시 이겨낼 거야!" },
		},
	},
}

-- ==================== 퀘스트 타입 설정 ====================
-- highwater: 단판 최고값 (초기화 안 됨, 진행 시 최대값 유지)
-- accumulate: 누적 합산

ScenarioConstants.QUEST_TRACKING_MODE = {
	play_games = "accumulate",
	score_reach = "highwater",
	collect_coins = "accumulate",
	near_miss = "accumulate",
	combo_ch = "highwater",
	distance_ch = "accumulate",
	survive_ch = "accumulate",
	powerup_ch = "accumulate",
	no_hit_run_ch = "accumulate",
}

-- 스탯 보너스 최대값 (상한선, 밸런스 유지)
ScenarioConstants.STAT_BONUS_CAPS = {
	speed = 0.15, -- 최대 +15%
	jump = 0.20, -- 최대 +20%
	coinValue = 0.25, -- 최대 +25%
	magnetRadius = 0.30, -- 최대 +30%
	maxLives = 1, -- 최대 +1 라이프
	feverGauge = 0.25, -- 최대 +25%
}

return ScenarioConstants

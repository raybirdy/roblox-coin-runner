--!strict
-- ScenarioConstants
-- 시나리오 시스템: 챕터, 퀘스트, 스킬, 컷씬 데이터 정의

local ScenarioConstants = {}

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
		description = "코인 도둑이 숲의 코인을 훔쳐갔어! 모험을 시작하자!",
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
		description = "도시에 숨겨진 코인을 찾아라! 새로운 스킬을 얻을 수 있어!",
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
		description = "끝없는 사막을 건너라! 자석 범위가 넓어져!",
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
		description = "눈보라 속을 헤쳐나가자! 대쉬 스킬을 얻어!",
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
		description = "바다 속에도 코인이 있어! 코인 가치가 올라가!",
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
		description = "불꽃 속을 달려라! 쉴드가 자동으로 재생돼!",
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
		description = "하늘 위 왕국에 코인이 가득해! 라이프가 하나 더 생겨!",
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
		description = "고대의 비밀을 밝혀라! 자석 폭발 스킬을 얻어!",
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
		description = "우주로 날아가자! 피버가 더 빠르게 차오른다!",
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
		description = "마침내 전설이 될 시간! 최강 스킬과 모든 스탯 보너스!",
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
			{ speaker = "🦉 부엉이 박사", text = "아이고! 코인 도둑이 나타났어!" },
			{ speaker = "🦉 부엉이 박사", text = "숲의 코인을 모두 훔쳐갔다고!" },
			{ speaker = "🏃 너", text = "내가 꼭 되찾아올게요!" },
		},
		clear = {
			{ speaker = "🏃 너", text = "숲의 코인을 모두 모았어!" },
			{ speaker = "🦉 부엉이 박사", text = "대단해! 다음은 도시야!" },
		},
	},
	ch2 = {
		opening = {
			{ speaker = "🦉 부엉이 박사", text = "도시에도 코인 도둑이 갔어!" },
			{ speaker = "🏃 너", text = "이번엔 2단 점프로 도약하자!" },
		},
		clear = {
			{ speaker = "🏃 너", text = "도시 코인 탈환 완료!" },
			{ speaker = "🦉 부엉이 박사", text = "점점 강해지고 있어! 사막으로 가자!" },
		},
	},
	ch3 = {
		opening = {
			{ speaker = "🏜️ 사막 정령", text = "이 사막은 내가 지킨다!" },
			{ speaker = "🏃 너", text = "비켜! 코인을 찾아야 해!" },
		},
		clear = {
			{ speaker = "🏃 너", text = "사막도 내 것이야!" },
			{ speaker = "🦉 부엉이 박사", text = "자석 범위가 넓어졌어! 설원이 기다려!" },
		},
	},
	ch4 = {
		opening = {
			{ speaker = "❄️ 눈의 요정", text = "여기서 멈추면 얼어버릴 텐데..." },
			{ speaker = "🏃 너", text = "대쉬로 뚫고 나가겠어!" },
		},
		clear = {
			{ speaker = "🏃 너", text = "눈보라도 날 막을 수 없어!" },
			{ speaker = "🦉 부엉이 박사", text = "점프력도 올라갔어! 바다로 가자!" },
		},
	},
	ch5 = {
		opening = {
			{ speaker = "🐟 물고기", text = "이 바다에 코인이 있긴 한데..." },
			{ speaker = "🏃 너", text = "헤엄쳐서 찾아볼게!" },
		},
		clear = {
			{ speaker = "🏃 너", text = "바다 코인도 내 거야!" },
			{ speaker = "🦉 부엉이 박사", text = "코인 가치가 올라갔어! 화산이 남았어!" },
		},
	},
	ch6 = {
		opening = {
			{ speaker = "🌋 화산 정령", text = "펄펄 끓는 용암 속에 코인이 있다!" },
			{ speaker = "🏃 너", text = "쉴드가 있으면 괜찮아!" },
		},
		clear = {
			{ speaker = "🏃 너", text = "화산도 통과했어!" },
			{ speaker = "🦉 부엉이 박사", text = "쉴드가 자동 재생돼! 구름 위로 가자!" },
		},
	},
	ch7 = {
		opening = {
			{ speaker = "👸 구름 여왕", text = "하늘 왕국에 오신 걸 환영해!" },
			{ speaker = "🏃 너", text = "코인 도둑이 여기도 왔나요?" },
			{ speaker = "👸 구름 여왕", text = "맞아! 함께 찾아보자!" },
		},
		clear = {
			{ speaker = "🏃 너", text = "구름 위의 코인도 모았어!" },
			{ speaker = "👸 구름 여왕", text = "라이프가 하나 더 생겼어! 용감한 러너!" },
		},
	},
	ch8 = {
		opening = {
			{ speaker = "👴 유적 수호자", text = "고대 유적에 전설의 코인이 잠들어 있다." },
			{ speaker = "🏃 너", text = "자석 폭발로 한번에 모을 수 있어!" },
		},
		clear = {
			{ speaker = "🏃 너", text = "고대의 보물을 되찾았어!" },
			{ speaker = "👴 유적 수호자", text = "자석 폭발 스킬을 받아라! 우주로 가거라." },
		},
	},
	ch9 = {
		opening = {
			{ speaker = "🤖 우주 로봇", text = "위험! 우주에 코인 도둑 신호 감지!" },
			{ speaker = "🏃 너", text = "피버로 날아서 가겠어!" },
		},
		clear = {
			{ speaker = "🏃 너", text = "우주 코인까지 모았다!" },
			{ speaker = "🤖 우주 로봇", text = "피버 게이지 업그레이드! 이제 마지막이야!" },
		},
	},
	ch10 = {
		opening = {
			{ speaker = "👿 코인 도둑", text = "어디서 온 꼬마야! 여기까지 왔어?!" },
			{ speaker = "🏃 너", text = "코인을 모두 돌려줘!" },
			{ speaker = "👿 코인 도둑", text = "절대 안 돼! 막아봐라!" },
		},
		clear = {
			{ speaker = "🏃 너", text = "해냈다! 모든 코인을 되찾았어!" },
			{ speaker = "🦉 부엉이 박사", text = "네가 진정한 전설의 러너야!" },
			{ speaker = "👑 왕관", text = "전설의 러너 칭호를 수여합니다!" },
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

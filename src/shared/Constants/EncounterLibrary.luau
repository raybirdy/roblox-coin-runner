--!strict
-- EncounterLibrary (IDEA-010)
-- 장애물-코인 동시 설계 Encounter 템플릿 모음
-- 각 encounter: 장애물 목록 + 유도 코인 위치 + 보상 코인 위치

local EncounterLibrary = {}

-- Encounter 타입 정의
export type ObstacleEntry = {
	obstacleType: string, -- ObstacleService에서 지원하는 타입
	relX: number, -- 청크 시작 기준 상대 X (0 = 청크 시작, 80 = 청크 끝)
	relY: number, -- 높이 오프셋 (0 = 기본)
}

export type CoinEntry = {
	relX: number,
	relY: number,
}

export type Encounter = {
	id: string,
	difficulty: string, -- "Normal" | "Hard"
	obstacles: { ObstacleEntry },
	guidCoins: { CoinEntry }, -- 장애물 전 유도 코인 (action hint)
	rewardCoins: { CoinEntry }, -- 장애물 후 보상 코인
}

-- ── Normal 난이도 Encounters ───────────────────────────────────────────────

EncounterLibrary.ENCOUNTERS = {
	-- 1. 낮은 벽 + 점프 유도 아치 + 착지 보상
	{
		id = "low_wall_jump",
		difficulty = "Normal",
		obstacles = {
			{ obstacleType = "LowWall", relX = 45, relY = 0 },
		},
		guidCoins = {
			{ relX = 25, relY = 2 },
			{ relX = 30, relY = 3 },
			{ relX = 35, relY = 4 },
			{ relX = 38, relY = 5 },
			{ relX = 41, relY = 5.5 },
		},
		rewardCoins = {
			{ relX = 50, relY = 2 },
			{ relX = 54, relY = 2 },
			{ relX = 58, relY = 2 },
			{ relX = 62, relY = 2 },
			{ relX = 66, relY = 2 },
		},
	},

	-- 2. 터널(낮은 천장) + 슬라이드 유도 하강 + 통과 보상
	{
		id = "tunnel_slide",
		difficulty = "Normal",
		obstacles = {
			{ obstacleType = "Tunnel", relX = 40, relY = 0 },
		},
		guidCoins = {
			{ relX = 22, relY = 5 },
			{ relX = 27, relY = 4 },
			{ relX = 32, relY = 3 },
			{ relX = 37, relY = 2 },
		},
		rewardCoins = {
			{ relX = 52, relY = 2 },
			{ relX = 56, relY = 2 },
			{ relX = 60, relY = 3 },
			{ relX = 64, relY = 3.5 },
		},
	},

	-- 3. 갭 + 점프 아치 + 공중 코인 + 착지 보상
	{
		id = "gap_arch",
		difficulty = "Normal",
		obstacles = {
			{ obstacleType = "Gap", relX = 42, relY = 0 },
		},
		guidCoins = {
			{ relX = 28, relY = 3 },
			{ relX = 33, relY = 4.5 },
			{ relX = 38, relY = 6 },
			{ relX = 42, relY = 6.5 },
			{ relX = 47, relY = 5 },
		},
		rewardCoins = {
			{ relX = 55, relY = 2 },
			{ relX = 59, relY = 2 },
			{ relX = 63, relY = 2 },
		},
	},

	-- 4. Hard: 이중 벽 + 이중 점프 유도 + 큰 보상
	{
		id = "double_wall_hard",
		difficulty = "Hard",
		obstacles = {
			{ obstacleType = "LowWall", relX = 30, relY = 0 },
			{ obstacleType = "LowWall", relX = 50, relY = 0 },
		},
		guidCoins = {
			{ relX = 18, relY = 2 },
			{ relX = 22, relY = 3.5 },
			{ relX = 26, relY = 5 },
		},
		rewardCoins = {
			{ relX = 38, relY = 4 },
			{ relX = 42, relY = 5 },
			{ relX = 46, relY = 4 },
			{ relX = 58, relY = 2 },
			{ relX = 62, relY = 2 },
			{ relX = 66, relY = 2 },
			{ relX = 70, relY = 2 },
		},
	},

	-- 5. 폭발 통 + 회피 유도 + 안전지대 보상
	{
		id = "barrel_dodge",
		difficulty = "Hard",
		obstacles = {
			{ obstacleType = "ExplodingBarrel", relX = 40, relY = 0 },
		},
		guidCoins = {
			{ relX = 20, relY = 2 },
			{ relX = 25, relY = 2 },
			{ relX = 30, relY = 6 }, -- 위쪽 피하기 유도
			{ relX = 35, relY = 6 },
		},
		rewardCoins = {
			{ relX = 52, relY = 2 },
			{ relX = 56, relY = 2 },
			{ relX = 60, relY = 2 },
			{ relX = 64, relY = 2 },
			{ relX = 68, relY = 2 },
		},
	},
} :: { Encounter }

-- difficulty 별 필터링 헬퍼
function EncounterLibrary.getByDifficulty(difficulty: string): { Encounter }
	local result: { Encounter } = {}
	for _, enc in EncounterLibrary.ENCOUNTERS do
		if enc.difficulty == difficulty then
			table.insert(result, enc)
		end
	end
	return result
end

return EncounterLibrary

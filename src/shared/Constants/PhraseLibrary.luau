--!strict
-- PhraseLibrary (IDEA-011)
-- Phrase: 연속 청크 난이도 시퀀스 + 높이 궤적
-- 매 청크 독립 선택 대신 Phrase 단위로 2~5청크를 한 번에 계획

local PhraseLibrary = {}

export type ChunkSpec = {
	difficulty: string, -- "Easy" | "Normal" | "Hard" | "Bonus" | "NPC"
	heightTag: string, -- "LOW" | "MID" | "HIGH" (다음 청크 높이 힌트)
}

export type Phrase = {
	id: string,
	label: string, -- 디버그용 이름
	minTime: number, -- 이 Phrase가 등장하는 최소 게임 경과 시간(초)
	weight: number, -- 선택 가중치
	sequence: { ChunkSpec }, -- 청크 사양 순서
}

PhraseLibrary.PHRASES = {
	-- ── 초반 (0~60초) ─────────────────────────────────────────────────────
	{
		id = "intro_gentle",
		label = "부드러운 시작",
		minTime = 0,
		weight = 5,
		sequence = {
			{ difficulty = "Easy", heightTag = "LOW" },
			{ difficulty = "Easy", heightTag = "LOW" },
			{ difficulty = "Normal", heightTag = "MID" },
		},
	},
	{
		id = "easy_rise",
		label = "점진 상승",
		minTime = 10,
		weight = 4,
		sequence = {
			{ difficulty = "Easy", heightTag = "LOW" },
			{ difficulty = "Normal", heightTag = "MID" },
			{ difficulty = "Normal", heightTag = "MID" },
			{ difficulty = "Bonus", heightTag = "LOW" },
		},
	},

	-- ── 중반 (30~120초) ──────────────────────────────────────────────────
	{
		id = "normal_rhythm",
		label = "안정 리듬",
		minTime = 30,
		weight = 5,
		sequence = {
			{ difficulty = "Normal", heightTag = "MID" },
			{ difficulty = "Normal", heightTag = "MID" },
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Normal", heightTag = "MID" },
			{ difficulty = "Bonus", heightTag = "LOW" },
		},
	},
	{
		id = "push_hard",
		label = "압박 후 보상",
		minTime = 60,
		weight = 4,
		sequence = {
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Normal", heightTag = "MID" },
			{ difficulty = "Bonus", heightTag = "LOW" },
		},
	},
	{
		id = "double_peak",
		label = "이중 절정",
		minTime = 60,
		weight = 3,
		sequence = {
			{ difficulty = "Normal", heightTag = "MID" },
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Easy", heightTag = "LOW" },
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Bonus", heightTag = "LOW" },
		},
	},

	-- ── 후반 (120초+) ─────────────────────────────────────────────────────
	{
		id = "endurance_sprint",
		label = "지구력 질주",
		minTime = 120,
		weight = 4,
		sequence = {
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Normal", heightTag = "MID" },
			{ difficulty = "Bonus", heightTag = "LOW" },
		},
	},
	{
		id = "grand_finale",
		label = "클라이막스",
		minTime = 180,
		weight = 3,
		sequence = {
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Easy", heightTag = "LOW" }, -- 숨 고르기
			{ difficulty = "Hard", heightTag = "HIGH" },
			{ difficulty = "Bonus", heightTag = "LOW" },
		},
	},
}

-- elapsed 시간에 맞는 Phrase 풀을 가중치 기반으로 선택
function PhraseLibrary.pick(elapsed: number): Phrase
	local pool: { Phrase } = {}
	local totalWeight = 0
	for _, phrase in PhraseLibrary.PHRASES do
		if elapsed >= phrase.minTime then
			table.insert(pool, phrase)
			totalWeight += phrase.weight
		end
	end
	if #pool == 0 then
		return PhraseLibrary.PHRASES[1]
	end
	local r = math.random() * totalWeight
	local cumul = 0
	for _, phrase in pool do
		cumul += phrase.weight
		if r <= cumul then
			return phrase
		end
	end
	return pool[#pool]
end

return PhraseLibrary

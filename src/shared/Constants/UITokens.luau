--!strict
-- UITokens — 디자인 토큰 단일 소스
-- docs/design/mobile-ui-spec.md 섹션 2 참조

local UITokens = {}

-- ===== 색상 =====
UITokens.Colors = {
	-- HUD 배경
	HudBackground = Color3.fromRGB(0, 0, 0),
	HudBackgroundTransparency = 0.45,

	-- 패널 배경 (ObjectiveHUD, DailyChallenge 등)
	PanelBackground = Color3.fromRGB(15, 15, 30),
	PanelBackgroundTransparency = 0.25,

	-- 텍스트
	TextPrimary = Color3.fromRGB(255, 255, 255),
	TextSecondary = Color3.fromRGB(180, 180, 200),
	TextMuted = Color3.fromRGB(130, 130, 150),

	-- 강조 색상
	AccentGold = Color3.fromRGB(255, 215, 0),
	AccentBlue = Color3.fromRGB(100, 200, 255),
	AccentGreen = Color3.fromRGB(100, 255, 100),
	AccentRed = Color3.fromRGB(255, 50, 50),
	AccentOrange = Color3.fromRGB(255, 150, 0),

	-- 버튼
	ButtonJump = Color3.fromRGB(0, 150, 255),
	ButtonSlide = Color3.fromRGB(255, 150, 0),
	ButtonSkill = Color3.fromRGB(60, 120, 220),
	ButtonStroke = Color3.fromRGB(255, 255, 255),
	ButtonStrokeTransparency = 0.3,

	-- 오버레이
	DimOverlay = Color3.fromRGB(0, 0, 0),
	DimOverlayTransparency = 0.55,

	-- ObjectiveHUD 아이콘 모드
	ObjectiveIconBg = Color3.fromRGB(30, 30, 50),
	ObjectiveIconBorder = Color3.fromRGB(80, 80, 140),
	ObjectiveIconBorderComplete = Color3.fromRGB(255, 215, 0),
}

-- ===== 폰트 크기 =====
-- 형식: { base, min } — ResponsiveUtil.scaledTextSize(base, min)으로 사용
UITokens.FontSizes = {
	HeadingLarge = { 32, 20 }, -- 게임오버 제목
	HeadingMedium = { 20, 14 }, -- 팝업 제목
	HeadingSmall = { 16, 12 }, -- 알림 제목
	Body = { 14, 11 }, -- 일반 본문
	BodySmall = { 12, 10 }, -- 설명문
	Caption = { 11, 9 }, -- 보조 텍스트, 진행도
	CaptionSmall = { 10, 8 }, -- 힌트 텍스트
	HudScore = { 18, 14 }, -- HUD 점수
	HudStat = { 16, 13 }, -- HUD 거리/코인
	ButtonLabel = { 36, 24 }, -- 터치 버튼 라벨
	SkillEmoji = { 28, 20 }, -- 스킬 버튼 이모지
}

-- ===== 간격 =====
UITokens.Spacing = {
	xxs = 2,
	xs = 4,
	sm = 8,
	md = 12,
	lg = 16,
	xl = 24,
	xxl = 34, -- 홈 인디케이터 안전 영역 마진
}

-- ===== 둥근 모서리 =====
UITokens.Radius = {
	sm = UDim.new(0, 4),
	md = UDim.new(0, 8),
	lg = UDim.new(0, 12),
	xl = UDim.new(0, 16),
	full = UDim.new(1, 0), -- 원형
}

-- ===== 모션/트윈 =====
UITokens.Motion = {
	-- 지속 시간 (초)
	instant = 0.08,
	fast = 0.15,
	normal = 0.25,
	slow = 0.40,
	emphasis = 0.60,

	-- 이징 프리셋 (EasingStyle, EasingDirection)
	easeOut = { Enum.EasingStyle.Quad, Enum.EasingDirection.Out },
	easeIn = { Enum.EasingStyle.Quad, Enum.EasingDirection.In },
	bounceOut = { Enum.EasingStyle.Back, Enum.EasingDirection.Out },
	spring = { Enum.EasingStyle.Elastic, Enum.EasingDirection.Out },

	-- 자동 접기 딜레이
	autoCollapseDelay = 3.0, -- ObjectiveHUD 자동 접기
	toastDuration = 3.0, -- 알림 토스트 표시 시간
	levelUpToastDuration = 2.5, -- 레벨업 토스트
}

-- ===== 터치 =====
UITokens.Touch = {
	MIN_TARGET_SIZE = 48, -- Apple HIG 최소 터치 대상 크기 (pt)
	GAME_BUTTON_SIZE = 120, -- 게임 조작 버튼 (큰 버튼, 저연령)
	SKILL_BUTTON_SIZE = 64, -- 스킬 버튼 (80 -> 64로 축소, 간격 확보)
	OBJECTIVE_ICON_SIZE = 48, -- 접힌 ObjectiveHUD 아이콘 (momus 리뷰 반영: 44 -> 48)
	BUTTON_MARGIN = 34, -- 홈 인디케이터 안전 마진
	BUTTON_GAP = 16, -- 버튼 간 최소 간격
}

-- ===== DisplayOrder =====
UITokens.DisplayOrder = {
	Background = 1,
	ObjectiveHUD = 7,
	RunSkillHud = 8,
	GameUI = 9,
	DailyChallenge = 10, -- 60 -> 10 (로비 전용이므로 낮춤)
	MissionPopup = 16,
	Toast = 20,
	DailyEvent = 30,
	ActiveSkill = 40, -- 80 -> 40
	Modal = 50,
	Tutorial = 100,
}

table.freeze(UITokens.Colors)
table.freeze(UITokens.FontSizes)
table.freeze(UITokens.Spacing)
table.freeze(UITokens.Radius)
table.freeze(UITokens.Motion)
table.freeze(UITokens.Touch)
table.freeze(UITokens.DisplayOrder)
table.freeze(UITokens)

return UITokens

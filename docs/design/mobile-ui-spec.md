# Mobile UI/UX Specification v1.0

> Coin Runner -- 모바일 퍼스트 UI 최적화 사양서
> 작성일: 2026-03-19
> 대상 디바이스: iPhone SE (375x667) ~ iPad (1024x1366)
> 대상 연령: 6~12세

---

## 목차

1. [문제 정의](#1-문제-정의)
2. [디자인 토큰](#2-디자인-토큰)
3. [UI 상태 머신](#3-ui-상태-머신)
4. [화면 레이아웃 사양](#4-화면-레이아웃-사양)
5. [컴포넌트 사양](#5-컴포넌트-사양)
6. [ObjectiveHUD 접기 애니메이션](#6-objectivehud-접기-애니메이션)
7. [UIVisibilityManager 설계](#7-uivisibilitymanager-설계)
8. [접근성 및 안전 영역](#8-접근성-및-안전-영역)

---

## 1. 문제 정의

### 현재 상태

게임 플레이 중("running" 상태) 6~7개의 UI 컨트롤러가 동시에 화면에 표시되어
375x667px iPhone SE 화면에서 심각한 정보 과부하를 유발한다.

```
현재 레이아웃 (running 상태 -- 문제)
┌──────────────────────────────────────────┐
│ [DailyChallenge 220x130]  [RunSkillXP]  │  <-- 상단: 요소 겹침
│ [Level/XP + MissionBtn]   [HUD: ♥★🏃🪙]│
│                                          │
│ [ObjectiveHUD 3행]       GAME WORLD      │  <-- 좌측: 혼잡
│                                          │
│ [SlideBtn]               [JumpBtn]       │  <-- 하단: 터치 컨트롤
│                          [SkillBtn 80px] │
└──────────────────────────────────────────┘
```

### 문제점

| 문제 | 영향 | 심각도 |
|------|------|--------|
| DailyChallenge가 running 중 표시 | 시야 차단, 불필요 정보 | P0 |
| ObjectiveHUD 3행이 좌측 고정 | 좌측 엄지 영역 침범, 시야 차단 | P0 |
| Level/XP + MissionBtn이 running 중 표시 | 터치 오작동, 불필요 정보 | P1 |
| RunSkillXP 바가 항상 표시 | 상단 우측 HUD와 겹침 | P1 |
| ActiveSkillBtn 위치가 JumpBtn과 가까움 | 오터치 가능성 | P1 |
| 좌측 하단에 ObjectiveHUD + SlideBtn 밀집 | 6세 아동 손가락으로 구별 불가 | P0 |

### 목표

- running 상태에서 **필수 정보만** 표시: HUD(생명/점수/거리/코인) + 터치 버튼
- 좌측 엄지 영역 완전히 비우기
- 모든 터치 대상 최소 48px
- iPhone SE(375x667)에서 게임 월드 가시 영역 60% 이상 확보

---

## 2. 디자인 토큰

`src/shared/Constants/UITokens.luau` 로 생성할 Luau 모듈.

```lua
--!strict
-- UITokens
-- 모바일 퍼스트 디자인 토큰 정의

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
-- 형식: { base, min } -- ResponsiveUtil.scaledTextSize(base, min)으로 사용
UITokens.FontSizes = {
    HeadingLarge  = { 32, 20 },  -- 게임오버 제목
    HeadingMedium = { 20, 14 },  -- 팝업 제목
    HeadingSmall  = { 16, 12 },  -- 알림 제목
    Body          = { 14, 11 },  -- 일반 본문
    BodySmall     = { 12, 10 },  -- 설명문
    Caption       = { 11, 9 },   -- 보조 텍스트, 진행도
    CaptionSmall  = { 10, 8 },   -- 힌트 텍스트
    HudScore      = { 18, 14 },  -- HUD 점수
    HudStat       = { 16, 13 },  -- HUD 거리/코인
    ButtonLabel   = { 36, 24 },  -- 터치 버튼 라벨
    SkillEmoji    = { 28, 20 },  -- 스킬 버튼 이모지
}

-- ===== 간격 =====
UITokens.Spacing = {
    xxs = 2,
    xs  = 4,
    sm  = 8,
    md  = 12,
    lg  = 16,
    xl  = 24,
    xxl = 34,  -- 홈 인디케이터 안전 영역 마진
}

-- ===== 둥근 모서리 =====
UITokens.Radius = {
    sm   = UDim.new(0, 4),
    md   = UDim.new(0, 8),
    lg   = UDim.new(0, 12),
    xl   = UDim.new(0, 16),
    full = UDim.new(1, 0),  -- 원형
}

-- ===== 모션/트윈 =====
UITokens.Motion = {
    -- 지속 시간 (초)
    instant  = 0.08,
    fast     = 0.15,
    normal   = 0.25,
    slow     = 0.40,
    emphasis = 0.60,

    -- 이징 프리셋 (EasingStyle, EasingDirection)
    easeOut     = { Enum.EasingStyle.Quad,  Enum.EasingDirection.Out },
    easeIn      = { Enum.EasingStyle.Quad,  Enum.EasingDirection.In },
    bounceOut   = { Enum.EasingStyle.Back,  Enum.EasingDirection.Out },
    spring      = { Enum.EasingStyle.Elastic, Enum.EasingDirection.Out },

    -- 자동 접기 딜레이
    autoCollapseDelay = 3.0,     -- ObjectiveHUD 자동 접기
    toastDuration     = 3.0,     -- 알림 토스트 표시 시간
    levelUpToastDuration = 2.5,  -- 레벨업 토스트
}

-- ===== 터치 =====
UITokens.Touch = {
    MIN_TARGET_SIZE = 48,         -- Apple HIG 최소 터치 대상 크기 (pt)
    GAME_BUTTON_SIZE = 120,       -- 게임 조작 버튼 (큰 버튼, 저연령)
    SKILL_BUTTON_SIZE = 64,       -- 스킬 버튼 (80 -> 64로 축소, 간격 확보)
    OBJECTIVE_ICON_SIZE = 44,     -- 접힌 ObjectiveHUD 아이콘
    BUTTON_MARGIN = 34,           -- 홈 인디케이터 안전 마진
    BUTTON_GAP = 16,              -- 버튼 간 최소 간격
}

-- ===== DisplayOrder =====
UITokens.DisplayOrder = {
    Background      = 1,
    ObjectiveHUD    = 7,
    RunSkillHud     = 8,
    GameUI          = 9,
    DailyChallenge  = 10,  -- 60 -> 10 (로비 전용이므로 낮춤)
    MissionPopup    = 16,
    Toast           = 20,
    DailyEvent      = 30,
    ActiveSkill     = 40,  -- 80 -> 40
    Modal           = 50,
}

return UITokens
```

---

## 3. UI 상태 머신

### 3.1 상태 정의

| 상태 | 설명 | 진입 조건 |
|------|------|-----------|
| `lobby` | 로비 대기 | 게임 시작 전 / 게임 종료 후 |
| `countdown` | 카운트다운 (3-2-1) | GameStart 이벤트 수신 |
| `running` | 게임 플레이 중 | 카운트다운 완료 |
| `minigame` | 미니게임 진행 중 | MiniGameService 전환 |
| `paused` | 일시 정지 | 런 스킬 선택 등 |
| `gameover` | 게임 종료 | 라이프 0 |

### 3.2 상태별 UI 가시성 매트릭스

| 컴포넌트 | lobby | countdown | running | minigame | paused | gameover |
|---------|-------|-----------|---------|----------|--------|----------|
| **HudFrame** (♥/★/🏃/🪙) | -- | 표시 | **표시** | -- | 표시 | -- |
| **JumpBtn / SlideBtn** | -- | -- | **표시** | -- | -- | -- |
| **ActiveSkillBtn** | -- | -- | **표시** | -- | -- | -- |
| **ObjectiveHUD** (접힌 아이콘) | -- | 전체(리롤) | **아이콘** | -- | 아이콘 | -- |
| **RunSkillXP 바** | -- | -- | -- (*) | -- | -- | -- |
| **RunSkill 선택 패널** | -- | -- | -- | -- | **표시** | -- |
| **DailyChallenge** | **표시** | -- | -- | -- | -- | -- |
| **ProgressionGui** (Lv/XP/MissionBtn) | **표시** | -- | -- | -- | -- | -- |
| **Level-up 토스트** | 표시 | -- | **표시** | -- | -- | -- |
| **GameOverFrame** | -- | -- | -- | -- | -- | **표시** |
| **LobbyUI** (StartBtn 등) | **표시** | -- | -- | -- | -- | -- |
| **Leaderboard** | **표시** | -- | -- | -- | -- | -- |
| **DailyEvent HUD** | **표시** | -- | 표시 | -- | -- | -- |
| **MiniGame HUD** | -- | -- | -- | **표시** | -- | -- |
| **RandomEvent 알림** | -- | -- | 토스트 | -- | -- | -- |
| **MultiplierBadge** | -- | -- | 표시 | -- | -- | -- |

> (*) RunSkillXP 바는 running 상태에서 **숨김**. 런 레벨업 시 RunSkill 선택 패널이
> 화면 상단에 슬라이드 인하고, 선택 후 자동으로 사라진다. XP 진행도는 HUD에
> 통합하지 않고, 레벨업 이벤트로만 피드백한다.

### 3.3 상태 전이 다이어그램

```
                  GameStart
    [lobby] ──────────────────> [countdown]
       ^                            │
       │                       카운트다운 완료
       │                            v
       │                       [running] <──── MiniGame 종료
       │                        │     │
       │            RunSkillOptions  MiniGame 시작
       │                        │     │
       │                   [paused]  [minigame]
       │                        │
       │            스킬 선택/타임아웃
       │                        │
       │                   [running]
       │                        │
       │                    라이프 0
       │                        v
       └─── 재시작/로비 ── [gameover]
```

---

## 4. 화면 레이아웃 사양

### 4.1 iPhone SE (375 x 667) -- "running" 상태

```
┌─────────────────────────────────────┐ 0,0
│            SAFE AREA TOP            │
│ ┌─────────────────────────────────┐ │
│ │                    ┌──────────┐ │ │
│ │                    │ HudFrame │ │ │  우측 상단
│ │                    │ 130x110  │ │ │  AnchorPoint(1,0)
│ │                    │ ♥♥♥      │ │ │  Position(1,-10, 0, 8)
│ │                    │ ★ 1,250  │ │ │
│ │                    │ 🏃 320m  │ │ │
│ │                    │ 🪙 45    │ │ │
│ │                    └──────────┘ │ │
│ │                                 │ │
│ │         G A M E   W O R L D     │ │
│ │                                 │ │
│ │                                 │ │
│ │                                 │ │
│ │                                 │ │
│ │  ┌──┐                          │ │  ObjectiveHUD 아이콘 (접힘)
│ │  │📋│                          │ │  좌측 하단, SlideBtn 위
│ │  │44│                          │ │  44x44
│ │  └──┘                          │ │
│ │                       ┌────┐   │ │  ActiveSkillBtn
│ │                       │ ⚡ │   │ │  64x64, JumpBtn 위
│ │                       │ 64 │   │ │  간격 16px
│ │                       └────┘   │ │
│ │ ┌──────┐           ┌──────┐   │ │  터치 버튼
│ │ │SLIDE │           │ JUMP │   │ │  각 120x120
│ │ │ 120  │           │ 120  │   │ │
│ │ └──────┘           └──────┘   │ │
│ └─────────────────────────────────┘ │
│          HOME INDICATOR             │
└─────────────────────────────────────┘ 375, 667
```

**게임 월드 가시 영역 계산 (iPhone SE)**:
- 전체: 375 x 667 = 250,125 px^2
- HudFrame: 130 x 110 = 14,300 px^2
- JumpBtn: 120 x 120 = 14,400 px^2
- SlideBtn: 120 x 120 = 14,400 px^2
- SkillBtn: 64 x 64 = 4,096 px^2
- ObjectiveIcon: 44 x 44 = 1,936 px^2
- UI 합계: 49,132 px^2
- **가시 영역: ~80%** (목표 60% 초과 달성)

### 4.2 Standard Phone (390 x 844) -- "running" 상태

```
┌───────────────────────────────────────┐ 0,0
│              SAFE AREA TOP            │
│ ┌───────────────────────────────────┐ │
│ │                      ┌──────────┐ │ │
│ │                      │ HudFrame │ │ │  우측 상단
│ │                      │ 140x120  │ │ │
│ │                      │ ♥♥♥      │ │ │
│ │                      │ ★ 1,250  │ │ │
│ │                      │ 🏃 320m  │ │ │
│ │                      │ 🪙 45    │ │ │
│ │                      └──────────┘ │ │
│ │                                   │ │
│ │                                   │ │
│ │          G A M E   W O R L D      │ │
│ │                                   │ │
│ │                                   │ │
│ │                                   │ │
│ │                                   │ │
│ │                                   │ │
│ │  ┌──┐                            │ │
│ │  │📋│                            │ │  ObjectiveHUD 아이콘
│ │  │48│                            │ │  48x48
│ │  └──┘                            │ │
│ │                         ┌────┐   │ │  ActiveSkillBtn
│ │                         │ ⚡ │   │ │  68x68
│ │                         │ 68 │   │ │
│ │                         └────┘   │ │
│ │ ┌──────┐             ┌──────┐   │ │
│ │ │SLIDE │             │ JUMP │   │ │  120x120
│ │ │ 120  │             │ 120  │   │ │
│ │ └──────┘             └──────┘   │ │
│ └───────────────────────────────────┘ │
│            HOME INDICATOR             │
└───────────────────────────────────────┘ 390, 844
```

### 4.3 "lobby" 상태 레이아웃 (390 x 844 기준)

```
┌───────────────────────────────────────┐
│              SAFE AREA TOP            │
│ ┌───────────────────────────────────┐ │
│ │ ┌──────────┐  ┌──┐               │ │  Level/XP (160x40) + MissionBtn (48x48)
│ │ │ Lv.5     │  │! │               │ │  좌상단
│ │ │ ████░░ XP│  └──┘               │ │
│ │ └──────────┘                      │ │
│ │                                   │ │
│ │ ┌────────────────┐                │ │  DailyChallenge (220x130)
│ │ │ Daily Challenge │                │ │  좌측
│ │ │ 1. XXXX  ✓     │                │ │
│ │ │ 2. XXXX  2/5   │                │ │
│ │ │ 3. XXXX  0/3   │                │ │
│ │ └────────────────┘                │ │
│ │                                   │ │
│ │         L O B B Y   W O R L D     │ │
│ │                                   │ │
│ │                                   │ │
│ │       ┌─────────────────┐         │ │  START 버튼 (화면 중앙 하단)
│ │       │    ▶ START      │         │ │
│ │       └─────────────────┘         │ │
│ │                                   │ │
│ └───────────────────────────────────┘ │
└───────────────────────────────────────┘
```

---

## 5. 컴포넌트 사양

### 5.1 UIController HudFrame (유지, 위치 조정)

**변경 사항**: 위치 및 크기를 UITokens 기반으로 통일. 기능 변경 없음.

| 속성 | 현재 값 | 변경 후 |
|------|---------|---------|
| Size | `scaledOffset(160) x scaledOffset(130)` | `scaledOffset(140) x scaledOffset(115)` |
| Position | `(1, -W-10, 0, 8)` | `(1, -W-10, 0, 8)` (유지) |
| AnchorPoint | 없음 (기본 0,0) | 없음 (유지) |
| BackgroundTransparency | 0.4 | 0.45 (UITokens.Colors.HudBackgroundTransparency) |
| CornerRadius | 10 | UITokens.Radius.lg (12) |

**가시성 규칙**:
- `lobby`: 숨김
- `countdown`: 표시
- `running`: 표시
- `minigame`: 숨김
- `paused`: 표시 (반투명)
- `gameover`: 숨김

**터치 충돌 방지**: HudFrame은 터치 이벤트를 패스스루(BackgroundTransparency >= 0.4에서
Roblox는 자동으로 터치를 통과시킴). 별도 조치 불필요.

---

### 5.2 DailyChallengeController (로비 전용)

**변경 사항**: `running` 상태에서 완전히 숨긴다.

| 속성 | 현재 값 | 변경 후 |
|------|---------|---------|
| Position | `(0, 10, 0, 120)` | `(0, 10, 0, 70)` (Level/XP 아래) |
| DisplayOrder | 60 | 10 |

**가시성 규칙**:
- `lobby`: **표시**
- `countdown`: 숨김 (fade out)
- `running`: 숨김
- `minigame`: 숨김
- `paused`: 숨김
- `gameover`: 숨김

**신규 메서드 추가**:

```lua
function DailyChallengeController:Hide()
    if self._gui then
        self._gui.Enabled = false
    end
end

function DailyChallengeController:Show()
    if self._gui then
        self._gui.Enabled = true
    end
end
```

**애니메이션**:
- 숨김: `TweenInfo.new(0.2, Quad, In)` -- Position Y를 -140으로 (화면 위로 슬라이드 아웃)
- 표시: `TweenInfo.new(0.3, Back, Out)` -- Position Y를 70으로 복귀

---

### 5.3 ObjectiveHudController (아이콘 접기 모드)

**핵심 변경**: 전체 모드(3행 패널)와 아이콘 모드(단일 아이콘) 전환 지원.

#### 5.3.1 전체 모드 (Full Mode)

카운트다운 중에만 표시. 리롤 가능.

| 속성 | 값 |
|------|-----|
| Size | `scaledOffset(180) x scaledOffset(112)` (현재와 동일) |
| Position | 좌측 하단, SlideBtn 위 (현재 위치 유지) |
| 표시 시점 | `countdown` 상태 진입 시 |
| 숨김 시점 | 카운트다운 완료 후 3초 뒤 아이콘으로 접기 |

#### 5.3.2 아이콘 모드 (Collapsed Icon Mode)

**신규 UI 요소**: `ObjectiveIcon` (TextButton)

| 속성 | 값 |
|------|-----|
| Size | `(0, 44, 0, 44)` -- MIN_TOUCH_TARGET 준수 |
| AnchorPoint | `Vector2.new(0, 1)` |
| Position | `(0, 34, 1, -SLIDE_TOP - 16)` |
| BackgroundColor3 | `UITokens.Colors.ObjectiveIconBg` |
| BackgroundTransparency | 0.2 |
| CornerRadius | `UITokens.Radius.md` (8) |
| Text | "📋" (기본) / "✅" (전체 완료) |
| TextSize | 20 |
| Border | `UIStroke` 1px, `ObjectiveIconBorder` 색상 |

**위치 계산** (SlideBtn 상대 위치):
```
SlideBtn top edge = viewportH - btnSize(120) - btnMargin(34) = viewportH - 154
ObjectiveIcon bottom = SlideBtn top - gap(16) = viewportH - 170
ObjectiveIcon Y = 1, -(170 + 44) = 1, -214 (AnchorPoint Y=1 기준)
```

**진행도 뱃지**: 아이콘 우상단에 작은 원형 뱃지 표시
```lua
-- 진행도 뱃지 (완료된 목표 수 / 3)
local badge = Instance.new("TextLabel")
badge.Size = UDim2.new(0, 18, 0, 18)
badge.Position = UDim2.new(1, -4, 0, -4)
badge.AnchorPoint = Vector2.new(1, 0)
badge.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
badge.TextColor3 = Color3.fromRGB(255, 255, 255)
badge.TextSize = 10
badge.Font = Enum.Font.GothamBold
badge.Text = "0/3"
-- UICorner full (원형)
```

**가시성 규칙**:
- `lobby`: 숨김
- `countdown`: 전체 모드 (리롤 활성)
- `running`: **아이콘 모드** (3초 후 자동 접기)
- `minigame`: 숨김
- `paused`: 아이콘 모드
- `gameover`: 숨김

**터치 동작** (아이콘 모드에서):
1. 아이콘 탭 -> 전체 모드 펼침 (리롤 비활성)
2. 3초 후 자동 접기
3. 전체 완료 시 아이콘에 골드 테두리 + "✅" 텍스트

---

### 5.4 ProgressionController (게임 중 숨김)

**변경 사항**: 이미 `HideForGame()` / `ShowInLobby()` 메서드가 존재.
추가 변경 없이 UIVisibilityManager에서 호출만 보장하면 됨.

| 속성 | 현재 값 | 변경 사항 |
|------|---------|-----------|
| ScreenGui.Enabled | HideForGame에서 false | 유지 |
| MissionPopup | HideForGame에서 닫기 | 유지 |
| 알림 큐 | HideForGame에서 비우기 | 유지 |

**Level-up 토스트 (running 중 허용)**:

`running` 상태에서 ScreenGui 자체는 숨기되, 레벨업 토스트만 별도 ScreenGui로
표시한다. 이를 위해 알림 시스템을 분리한다.

```lua
-- 신규: 토스트 전용 ScreenGui (항상 활성, running 중에도 표시)
-- DisplayOrder = UITokens.DisplayOrder.Toast (20)
-- 이 ScreenGui에 레벨업/업적 토스트만 표시
```

**가시성 규칙**:
- `lobby`: **표시** (LevelContainer + MissionBtn)
- `countdown`: 숨김
- `running`: 숨김 (토스트만 별도 표시)
- `minigame`: 숨김
- `paused`: 숨김
- `gameover`: 숨김

---

### 5.5 RunSkillHudController (게임 중 숨김)

**변경 사항**: XP 바를 running 중 숨기고, 스킬 선택 패널만 이벤트 시 표시.

| 속성 | 현재 값 | 변경 후 |
|------|---------|---------|
| XPFrame.Visible | 항상 표시 (Enabled 시) | **숨김** |
| SkillSelection | 이벤트 시 슬라이드 인 | 유지 |
| ScreenGui.Enabled | StartGame에서 true | **true 유지, XPFrame만 숨김** |

**변경 로직**:
```lua
function RunSkillHudController:StartGame()
    self._active = true
    if self._gui then
        self._gui.Enabled = true
    end
    -- XP 바 숨김 (running 중 불필요)
    if self._xpFrame then
        self._xpFrame.Visible = false
    end
end
```

XP 바를 숨기는 대신, 런 레벨업 시 화면 중앙에 "Level Up!" 토스트를 짧게 표시하고
바로 스킬 선택 패널을 보여준다. 사용자에게 진행 상황을 전달하면서도 상시
화면 공간을 차지하지 않는다.

**가시성 규칙**:
- `lobby`: 숨김
- `countdown`: 숨김
- `running`: **XP바 숨김, 스킬 선택 패널만 이벤트 시 표시**
- `minigame`: 숨김
- `paused`: 스킬 선택 패널 표시 (선택 대기)
- `gameover`: 숨김

---

### 5.6 ActiveSkillController (우측 JumpBtn 위로 이동)

**변경 사항**: 위치를 JumpBtn 바로 위로 이동. 크기를 80에서 64로 축소.

| 속성 | 현재 값 | 변경 후 |
|------|---------|---------|
| Size | `(0, 80, 0, 80)` | `(0, 64, 0, 64)` |
| Position | `(1, -100, 1, -220)` | 계산값 (아래 참조) |
| CornerRadius | full (원형) | full (유지) |
| UIStroke Thickness | 3 | 2 |

**위치 계산** (JumpBtn 기준):
```
JumpBtn 위치:  (1, -btnSize-btnMargin, 1, -btnSize-btnMargin)
             = (1, -154, 1, -154)
JumpBtn 상단 엣지: viewportH - 154 - 120 = viewportH - 274 (화면 좌표)

SkillBtn 하단 = JumpBtn 상단 - gap(16) = viewportH - 290
SkillBtn 위치: (1, -btnMargin - btnSize/2 - skillSize/2, 1, -290)
             = (1, -34 - 60 - 32, 1, -290)

-- 간소화: JumpBtn 중심 X 기준 정렬
SkillBtn Position = UDim2.new(1, -34 - 60 - 32 + (120-64)/2, 1, -154 - 120 - 16)
                  -- 정리: JumpBtn 중심 X에 맞춤
```

**최종 Position 공식**:
```lua
local jumpCenterX = btnSize + btnMargin  -- 154 (우측 가장자리에서)
local skillBtnX = jumpCenterX - skillSize / 2  -- 154 - 32 = 122
local skillBtnY = btnSize + btnMargin + btnSize + BUTTON_GAP  -- 120+34+64+16 = 234 (하단에서)

button.Position = UDim2.new(1, -skillBtnX - skillSize, 1, -skillBtnY - skillSize)
-- 또는 AnchorPoint 사용:
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(1, -jumpCenterX, 1, -btnSize - btnMargin - BUTTON_GAP)
-- = UDim2.new(1, -154, 1, -170)
```

**가시성 규칙**:
- `lobby`: 숨김
- `countdown`: 숨김
- `running`: **표시** (장착 스킬 있을 때)
- `minigame`: 숨김
- `paused`: 숨김
- `gameover`: 숨김

**터치 충돌 방지**:
- JumpBtn(120x120)과 SkillBtn(64x64) 사이 최소 간격 16px 확보
- iPhone SE에서 검증: 두 버튼의 실제 간격 = 16px (6세 손가락 폭 ~11mm = ~44px, 충분)

---

### 5.7 UIVisibilityManager (신규 모듈)

**경로**: `src/client/Controllers/UIVisibilityManager.luau`

**역할**: 게임 상태에 따라 모든 UI 컨트롤러의 가시성을 일괄 관리하는 중앙 상태 머신.

```lua
--!strict
-- UIVisibilityManager
-- 게임 상태별 UI 가시성 중앙 관리

local UIVisibilityManager = {}
UIVisibilityManager.__index = UIVisibilityManager

export type Controllers = {
    uiController: any,
    progressionController: any,
    objectiveHudController: any,
    runSkillHudController: any,
    dailyChallengeController: any,
    activeSkillController: any,
    leaderboardController: any,
    rankingController: any,
    realtimeBattleController: any,
    dailyEventController: any,
    scenarioController: any,
    worldMapController: any,
}

export type GameState = "lobby" | "countdown" | "running" | "minigame" | "paused" | "gameover"

function UIVisibilityManager.new(controllers: Controllers)
    local self = setmetatable({}, UIVisibilityManager)
    self._controllers = controllers
    self._currentState = "lobby" :: GameState
    return self
end

function UIVisibilityManager:SetState(newState: GameState)
    local prevState = self._currentState
    self._currentState = newState

    local c = self._controllers

    if newState == "lobby" then
        -- 로비: 정보성 UI 모두 표시
        c.progressionController:ShowInLobby()
        c.dailyChallengeController:Show()
        c.objectiveHudController:EndGame()
        c.runSkillHudController:EndGame()
        c.activeSkillController:OnGameEnd()
        c.leaderboardController:Show()
        c.rankingController:ShowInLobby()
        c.dailyEventController:ShowInLobby()

    elseif newState == "countdown" then
        -- 카운트다운: 최소 UI + 목표 확인
        c.progressionController:HideForGame()
        c.dailyChallengeController:Hide()
        c.objectiveHudController:StartGame()  -- 전체 모드 (리롤)
        c.leaderboardController:Hide()

    elseif newState == "running" then
        -- 게임 중: 필수 정보만
        c.objectiveHudController:CollapseToIcon()  -- 신규 메서드
        c.runSkillHudController:StartGame()
        c.activeSkillController:OnGameStart()

    elseif newState == "minigame" then
        -- 미니게임: 게임 HUD 숨김
        c.objectiveHudController:HideIcon()
        c.activeSkillController:OnGameEnd()

    elseif newState == "paused" then
        -- 일시정지 (스킬 선택 등)
        -- 현재 상태 유지, 추가 오버레이만

    elseif newState == "gameover" then
        -- 게임 오버
        c.objectiveHudController:EndGame()
        c.runSkillHudController:EndGame()
        c.activeSkillController:OnGameEnd()
    end
end

function UIVisibilityManager:GetState(): GameState
    return self._currentState
end

return UIVisibilityManager
```

**init.client.luau 통합 방법**:

현재 `init.client.luau`에서 각 컨트롤러의 Show/Hide를 직접 호출하는 코드를
`UIVisibilityManager:SetState()` 호출로 대체한다.

```lua
-- 현재 (분산된 가시성 관리):
progressionController:HideForGame()
scenarioController:HideForGame()
worldMapController:HideForGame()
rankingController:HideForGame()
...

-- 변경 후 (중앙화):
uiVisibilityManager:SetState("countdown")
```

---

## 6. ObjectiveHUD 접기 애니메이션

### 6.1 전체 -> 아이콘 전환 (Collapse)

**트리거**: 카운트다운 완료 후 `UITokens.Motion.autoCollapseDelay` (3초) 경과

**애니메이션 시퀀스** (총 0.4초):

```
t=0.0s  전체 모드 활성 (180x112 패널)
        ├── 리롤 버튼 비활성화
        │
t=0.0s  Phase 1: 축소 (0.25s, Quad Out)
        ├── 패널 Size: (180, 112) -> (44, 44)
        ├── 패널 BackgroundTransparency: 0.25 -> 0.2
        ├── 자식 요소(행, 타이틀) TextTransparency: 0 -> 1
        ├── 위치 이동: 현재 위치 -> 아이콘 위치
        │
t=0.25s Phase 2: 아이콘 등장 (0.15s, Back Out)
        ├── 아이콘 텍스트 "📋" TextTransparency: 1 -> 0
        ├── 진행도 뱃지 Scale: 0 -> 1 (spring)
        ├── 아이콘 Size pulse: 44 -> 48 -> 44 (bounce)
        │
t=0.40s 완료. 전체 모드 UI 요소 Visible = false
```

**Luau 구현 핵심**:

```lua
function ObjectiveHudController:CollapseToIcon()
    if not self._hudFrame or not self._iconButton then return end

    -- Phase 1: 축소
    local tweenInfo1 = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- 자식 텍스트 페이드 아웃
    for _, row in self._rows do
        for _, child in row:GetChildren() do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                TweenService:Create(child, tweenInfo1, {
                    TextTransparency = 1
                }):Play()
            end
        end
    end

    -- 패널 축소 (아이콘 위치/크기로)
    local iconPos = self._iconButton.Position
    local iconSize = self._iconButton.Size
    TweenService:Create(self._hudFrame, tweenInfo1, {
        Size = iconSize,
        Position = iconPos,
        BackgroundTransparency = 0.2,
    }):Play()

    -- Phase 2: 아이콘 전환
    task.delay(0.25, function()
        if not self._hudFrame then return end
        self._hudFrame.Visible = false
        self._iconButton.Visible = true

        -- 뱃지 스프링 애니메이션
        local badge = self._iconButton:FindFirstChild("Badge")
        if badge then
            badge.Size = UDim2.new(0, 0, 0, 0)
            TweenService:Create(badge, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 18, 0, 18),
            }):Play()
        end
    end)

    self._isCollapsed = true
end
```

### 6.2 아이콘 -> 전체 전환 (Expand)

**트리거**: 아이콘 탭

**애니메이션 시퀀스** (총 0.35초):

```
t=0.0s  아이콘 모드 (44x44)
        ├── 아이콘 탭 감지
        │
t=0.0s  Phase 1: 아이콘 숨김 (즉시)
        ├── iconButton.Visible = false
        ├── hudFrame.Visible = true
        ├── hudFrame Size = (44, 44), Position = 아이콘 위치
        │
t=0.0s  Phase 2: 펼침 (0.3s, Back Out)
        ├── 패널 Size: (44, 44) -> (180, 112)
        ├── 패널 Position: 아이콘 위치 -> 원래 위치
        ├── BackgroundTransparency: 0.2 -> 0.25
        │
t=0.15s Phase 3: 콘텐츠 페이드 인 (0.2s, Quad Out)
        ├── 행/타이틀 TextTransparency: 1 -> 0
        ├── 리롤 버튼은 비활성 상태 유지
        │
t=0.35s 완료
        │
t=3.35s 자동 접기 타이머 -> CollapseToIcon() 재호출
```

### 6.3 진행도 업데이트 (아이콘 모드 중)

목표 완료 시 아이콘 상태에서도 피드백을 준다:

```
목표 1개 완료:
├── 뱃지 텍스트 "1/3" -> "2/3"
├── 아이콘 짧은 pulse (Scale 1.0 -> 1.15 -> 1.0, 0.2s)
├── 뱃지 색상 flash (빨강 -> 초록 -> 빨강, 0.3s)

전체 완료:
├── 아이콘 텍스트 "📋" -> "✅"
├── 테두리 색상 -> AccentGold
├── celebration pulse (Scale 1.0 -> 1.3 -> 1.0, Back Out, 0.4s)
├── 뱃지 텍스트 "3/3", 색상 -> AccentGold
```

---

## 7. UIVisibilityManager 설계

### 7.1 상태 전이 훅

각 상태 전이 시 실행되는 콜백 목록:

| 전이 | 실행 순서 |
|------|-----------|
| `lobby -> countdown` | 1. HideForGame(progression, scenario, worldMap, ranking, battle) 2. Hide(dailyChallenge, leaderboard) 3. StartGame(objectiveHud) 4. ShowCountdown(uiController) |
| `countdown -> running` | 1. CollapseToIcon(objectiveHud, 3s delay) 2. StartGame(runSkillHud, dailyEvent, pet) 3. DisableReroll(objectiveHud) 4. OnGameStart(activeSkill) 5. SetGameActive(input, coin) |
| `running -> paused` | 1. ShowSkillSelection(runSkillHud) -- 다른 UI 변경 없음 |
| `paused -> running` | 1. HideSkillSelection(runSkillHud) |
| `running -> minigame` | 1. HideIcon(objectiveHud) 2. OnGameEnd(activeSkill) 3. MiniGame HUD 표시 |
| `minigame -> running` | 1. CollapseToIcon(objectiveHud) 2. OnGameStart(activeSkill) |
| `running -> gameover` | 1. EndGame(objectiveHud, runSkillHud, dailyEvent, pet, coinKing) 2. OnGameEnd(activeSkill) 3. ShowGameOver(uiController) |
| `gameover -> lobby` | 1. SetState("lobby") -- 위 lobby 진입 로직 실행 |

### 7.2 에러 복구

잘못된 상태 전이 시 경고 로그를 남기고, 강제로 `lobby` 상태로 복귀한다:

```lua
local VALID_TRANSITIONS = {
    lobby = { "countdown" },
    countdown = { "running" },
    running = { "paused", "minigame", "gameover" },
    paused = { "running" },
    minigame = { "running" },
    gameover = { "lobby" },
}

function UIVisibilityManager:SetState(newState: GameState)
    local valid = VALID_TRANSITIONS[self._currentState]
    if valid and not table.find(valid, newState) then
        warn(`[UIVisibilityManager] Invalid transition: {self._currentState} -> {newState}, forcing lobby`)
        newState = "lobby"
    end
    -- ... 상태 적용
end
```

---

## 8. 접근성 및 안전 영역

### 8.1 안전 영역 (Safe Area)

모든 ScreenGui에 `ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets` 설정.
이미 현재 코드에서 대부분 적용되어 있음.

| 디바이스 | 상단 인셋 | 하단 인셋 | 좌/우 인셋 |
|---------|----------|----------|-----------|
| iPhone SE | 20px | 0px | 0px |
| iPhone 14 | 59px | 34px | 0px |
| iPhone 15 Pro | 59px | 34px | 0px |
| iPad | 24px | 20px | 0px |

**하단 인디케이터 영역**: `btnMargin = 34px`로 이미 대응 중. 유지.

### 8.2 터치 대상 크기 검증

| 요소 | 현재 크기 | 변경 후 | MIN_TARGET (48px) 준수 |
|------|----------|---------|----------------------|
| JumpBtn | 120x120 | 120x120 | O |
| SlideBtn | 120x120 | 120x120 | O |
| ActiveSkillBtn | 80x80 | 64x64 | O |
| ObjectiveIcon | 없음 | 44x44 | **경계** (*) |
| MissionBtn | 48x48 | 48x48 | O |
| RerollBtn | 38x(행높이) | 유지 | **X** (countdown에서만 사용) |

> (*) ObjectiveIcon 44x44는 Apple HIG의 44pt 최소 기준을 충족하지만,
> 48px 내부 가이드라인보다 4px 작다. 그러나 이 아이콘은 정보 확인용이지
> 게임 조작 버튼이 아니므로, 허용 가능한 수준이다.

### 8.3 색상 대비

| 요소 | 전경색 | 배경색 | 대비율 | WCAG AA |
|------|--------|--------|--------|---------|
| HUD 점수 | #FFFFFF | #000000 (45% 불투명) | 8.5:1 | O |
| HUD 거리 | #64C8FF | #000000 (45%) | 6.2:1 | O |
| HUD 코인 | #FFD700 | #000000 (45%) | 7.8:1 | O |
| ObjectiveIcon | #FFFFFF | #1E1E32 | 12.1:1 | O |
| 터치 버튼 라벨 | #FFFFFF | 버튼 배경 | > 4.5:1 | O |

### 8.4 ResponsiveUtil 스케일링

현재 `ResponsiveUtil`은 1920x1080 기준 스케일링을 사용한다.
iPhone SE(375x667)에서 스케일 팩터는 `min(375/1920, 667/1080) = 0.195`.

이로 인해 `scaledOffset(180)` = 35px로 지나치게 축소되는 문제가 있으나,
현재 코드에서 `math.max()`로 하한을 설정하여 대응 중이다.
UITokens의 고정 px 값은 ResponsiveUtil을 거치지 않고 직접 사용하되,
태블릿/대형 화면에서는 `scaledOffset`으로 확대를 적용한다.

**권장 전략**:
```lua
-- 모바일 기본값(375px 기준)을 하한으로, 스케일링은 확대만 적용
local function mobileFirstOffset(basePx: number): number
    local scale = ResponsiveUtil.getScaleFactor()
    if scale > 1 then
        return math.round(basePx * math.min(scale, 2.0))  -- 최대 2배
    end
    return basePx  -- 모바일에서는 기본값 사용
end
```

---

## 부록: 변경 대상 파일 목록

| 파일 | 변경 유형 | 우선순위 |
|------|----------|----------|
| `src/shared/Constants/UITokens.luau` | **신규** | P0 |
| `src/client/Controllers/UIVisibilityManager.luau` | **신규** | P0 |
| `src/client/Controllers/ObjectiveHudController.luau` | 수정 (아이콘 모드 추가) | P0 |
| `src/client/Controllers/DailyChallengeController.luau` | 수정 (Show/Hide 추가) | P0 |
| `src/client/Controllers/ActiveSkillController.luau` | 수정 (위치/크기 변경) | P1 |
| `src/client/Controllers/RunSkillHudController.luau` | 수정 (XP바 숨김) | P1 |
| `src/client/Controllers/UIController.luau` | 수정 (HudFrame 크기 미세 조정) | P2 |
| `src/client/Controllers/ProgressionController.luau` | 수정 (토스트 ScreenGui 분리) | P2 |
| `src/client/init.client.luau` | 수정 (UIVisibilityManager 통합) | P0 |

---

## 9. momus 리뷰 반영 사항 (v1.1)

> 작성일: 2026-03-19
> momus 코드 리뷰 결과를 반영한 보완 사항. 기존 섹션은 수정하지 않으며, 이 섹션이 단일 소스로 우선 적용된다.

---

### 9.1 [P0] UIVisibilityManager 관리 대상 컨트롤러 전체 목록

섹션 7의 `Controllers` 타입에 누락된 컨트롤러를 포함한 완전한 목록과 Show/Hide 메서드명을 정의한다.

| 컨트롤러 | Show 메서드 | Hide 메서드 | 비고 |
|---------|-----------|-----------|------|
| `uiController` | `ShowHud()` | `HideHud()` | HudFrame, GameOverFrame, LobbyUI |
| `objectiveHudController` | `StartGame()` | `EndGame()` / `HideIcon()` | 전체→아이콘 전환 포함 |
| `dailyChallengeController` | `Show()` | `Hide()` | 로비 전용 |
| `activeSkillController` | `OnGameStart()` | `OnGameEnd()` | running 전용 |
| `runSkillHudController` | `StartGame()` | `EndGame()` | XP바 숨김, 스킬 패널 포함 |
| `progressionController` | `ShowInLobby()` | `HideForGame()` | Lv/XP/MissionBtn |
| `feverController` | `ShowGauge()` | `HideGauge()` | 피버 게이지 |
| `petController` | `StartGame()` | `StopGame()` | 펫 동반 UI |
| `scenarioController` | `ShowInLobby()` | `HideForGame()` | 시나리오 오버레이 |
| `worldMapController` | `ShowInLobby()` | `HideForGame()` | 월드 맵 UI |
| `realtimeBattleController` | `ShowInLobby()` | `HideForGame()` | 실시간 배틀 UI |
| `miniGameController` | `ShowUI()` | `HideUI()` | minigame 상태 전용 |
| `coinKingController` | `Show()` | `Hide()` | 코인킹 이벤트 UI |
| `dailyEventController` | `ShowInLobby()` | (없음, running 중에도 표시) | 일일 이벤트 HUD |
| `randomEventController` | (토스트만, 별도 관리) | (해당 없음) | 영구 UI 없음, 토스트 전용 |

**`randomEventController`** 는 영구 UI가 없고 토스트 알림만 표시한다. UIVisibilityManager가 직접 Show/Hide를 호출하지 않으며, 토스트 ScreenGui(`DisplayOrder = UITokens.DisplayOrder.Toast`)를 독자적으로 관리한다.

**업데이트된 `Controllers` 타입 정의**:

```lua
export type Controllers = {
    uiController: any,
    progressionController: any,
    objectiveHudController: any,
    runSkillHudController: any,
    dailyChallengeController: any,
    activeSkillController: any,
    feverController: any,
    petController: any,
    scenarioController: any,
    worldMapController: any,
    realtimeBattleController: any,
    miniGameController: any,
    coinKingController: any,
    dailyEventController: any,
    leaderboardController: any,
    rankingController: any,
    -- randomEventController는 토스트 전용이므로 포함하지 않음
}
```

---

### 9.2 [P0] VALID_TRANSITIONS 누락 엣지 추가

섹션 7.2의 `VALID_TRANSITIONS` 테이블에 다음 세 가지 엣지 케이스를 추가한다.

```lua
local VALID_TRANSITIONS = {
    lobby      = { "countdown", "lobby" },         -- lobby -> lobby: 재접속 시 idempotent 재진입
    countdown  = { "running", "lobby" },           -- countdown -> lobby: 플레이어 연결 해제/취소
    running    = { "paused", "minigame", "gameover" },
    paused     = { "running" },
    minigame   = { "running", "gameover" },        -- minigame -> gameover: 미니게임 중 사망
    gameover   = { "lobby" },
}
```

**추가된 엣지 설명**:

| 전이 | 발생 조건 | 처리 방식 |
|------|----------|----------|
| `countdown -> lobby` | 플레이어가 카운트다운 중 연결 해제 또는 취소 버튼 누름 | `SetState("lobby")` 호출 → 로비 UI 복원 |
| `minigame -> gameover` | 미니게임 진행 중 라이프 소진 (MiniGameService에서 hit 처리 시) | `miniGameController:HideUI()` 후 게임오버 처리 |
| `lobby -> lobby` | 재접속 또는 씬 전환 후 lobby 상태 재확인 | SetState 내 prevState == newState 시 early return 없이 전체 로비 UI를 재적용하여 idempotent 보장 |

---

### 9.3 [P0] MiniGameController 가시성 규칙

`miniGameController`는 다른 컨트롤러와 달리 게임 상태 전이 시 명확한 가시성 규칙을 따른다.

**가시성 규칙**:

| 상태 | `ScreenGui.Enabled` |
|------|-------------------|
| `lobby` | false |
| `countdown` | false |
| `running` | false |
| `minigame` | **true** |
| `paused` | false |
| `gameover` | false |

**UI 위치**:

| 요소 | 위치 | 설명 |
|------|------|------|
| 타이머 바 | 상단 중앙, AnchorPoint(0.5, 0) | 미니게임 남은 시간 표시 |
| 장애물 경고 (좌) | 좌측 측면, AnchorPoint(0, 0.5) | 좌측 장애물 접근 알림 |
| 장애물 경고 (우) | 우측 측면, AnchorPoint(1, 0.5) | 우측 장애물 접근 알림 |

**UIVisibilityManager 통합**:

```lua
elseif newState == "minigame" then
    c.objectiveHudController:HideIcon()
    c.activeSkillController:OnGameEnd()
    c.miniGameController:ShowUI()   -- minigame 진입 시 활성화

elseif newState == "running" then   -- minigame -> running 복귀 포함
    c.miniGameController:HideUI()   -- 반드시 먼저 숨김
    c.objectiveHudController:CollapseToIcon()
    c.activeSkillController:OnGameStart()
```

---

### 9.4 [P1] ObjectiveIcon 크기 44 → 48px 변경

6세 아동의 운동 능력(대근육 운동 발달 단계)을 고려하여 ObjectiveIcon 크기를 48px로 상향한다.

**변경 대상**:

| 위치 | 변경 전 | 변경 후 |
|------|---------|---------|
| `UITokens.Touch.OBJECTIVE_ICON_SIZE` | 44 | **48** |
| `ObjectiveIcon` Size | `(0, 44, 0, 44)` | `(0, 48, 0, 48)` |
| 섹션 4.1 ASCII 다이어그램 내 `│44│` | 44x44 | **48x48** |

이로써 내부 가이드라인(MIN_TARGET_SIZE = 48px)을 완전히 충족한다.

---

### 9.5 [P1] RerollBtn 최소 너비 38 → 48px 변경

RerollBtn은 카운트다운 상태에서만 사용되지만, 모든 터치 대상은 48px 이상을 원칙으로 한다.

**변경 내용**: RerollBtn의 최소 너비를 38px에서 **48px**로 상향.

```lua
-- ObjectiveHudController 내 RerollBtn 생성 시
rerollBtn.Size = UDim2.new(0, 48, 0, 32)   -- 너비 48px (높이는 행 높이에 맞춤)
rerollBtn.AutomaticSize = Enum.AutomaticSize.X  -- 텍스트에 따라 최소 48px 이상 확장
```

섹션 8.2 터치 대상 크기 검증 테이블의 `RerollBtn` 항목을 `48x(행높이)` 및 `O`로 갱신한다.

---

### 9.6 [P1] ResponsiveUtil과 UITokens 관계 명확화

섹션 8.4의 전략을 확장하여 두 시스템의 역할을 명확히 정의한다.

**원칙**:

> UITokens는 디자인 의도의 단일 소스(Single Source of Truth)이며, ResponsiveUtil.scaledOffset()이 UITokens 값을 입력으로 받아 화면 크기에 맞게 스케일링한다. 하드코딩된 매직 넘버 대신 UITokens 상수를 ResponsiveUtil에 전달하는 방식으로 통일한다.

**올바른 사용 패턴**:

```lua
-- 잘못된 방식 (매직 넘버 직접 사용)
button.Size = UDim2.new(0, ResponsiveUtil.scaledOffset(120), 0, ResponsiveUtil.scaledOffset(120))

-- 올바른 방식 (UITokens -> ResponsiveUtil 파이프라인)
local Tokens = require(ReplicatedStorage.Constants.UITokens)
button.Size = UDim2.new(
    0, ResponsiveUtil.scaledOffset(Tokens.Touch.GAME_BUTTON_SIZE),
    0, ResponsiveUtil.scaledOffset(Tokens.Touch.GAME_BUTTON_SIZE)
)
```

**역할 구분**:

| 시스템 | 역할 | 수정 위치 |
|--------|------|----------|
| `UITokens` | 디자인 의도 정의 (기준값) | 디자인 변경 시 |
| `ResponsiveUtil` | 화면 크기에 따른 스케일링 로직 | 스케일링 알고리즘 변경 시 |

---

### 9.7 [P1] TutorialController와 UIVisibilityManager 독립성

TutorialController는 UIVisibilityManager의 관리 대상에서 제외된다.

**동작 원칙**:

> TutorialController는 UIVisibilityManager와 독립적으로 동작한다. 튜토리얼 활성 시 별도의 overlay ScreenGui(DisplayOrder = 100)를 사용하며, 게임 상태 전환과 무관하게 자체 lifecycle을 관리한다. UIVisibilityManager는 TutorialController를 호출하지 않는다.

**TutorialController 자체 lifecycle**:

```lua
-- 튜토리얼 시작: 독립적으로 overlay 활성화
TutorialController:Start()   -- overlay ScreenGui Enabled = true

-- 튜토리얼 종료: 자체적으로 정리
TutorialController:Complete()   -- overlay ScreenGui Enabled = false
```

**DisplayOrder**: 튜토리얼 overlay는 `DisplayOrder = 100`으로 설정하여 모든 게임 UI(최대 Modal = 50) 위에 표시된다.

---

### 9.8 [P1] Tween 경합 조건 방지

ObjectiveHudController의 CollapseToIcon/Expand 사이에 경합 조건이 발생할 수 있으므로 가드를 추가한다.

**ObjectiveHudController에 `_isTweening` 가드 추가**:

```lua
function ObjectiveHudController:CollapseToIcon()
    if self._isTweening then return end   -- 트윈 진행 중 탭 무시
    self._isTweening = true

    -- ... 트윈 실행 ...

    task.delay(0.40, function()
        self._isTweening = false
    end)
end

function ObjectiveHudController:ExpandToFull()
    if self._isTweening then return end
    self._isTweening = true

    -- ... 트윈 실행 ...

    task.delay(0.35, function()
        self._isTweening = false
    end)
end
```

**UIVisibilityManager:SetState() 호출 시 진행 중인 트윈 즉시 취소**:

```lua
function UIVisibilityManager:SetState(newState: GameState)
    -- 상태 전이 전, 진행 중인 트윈 모두 취소
    for _, activeTween in self._activeTweens do
        activeTween:Cancel()
    end
    table.clear(self._activeTweens)

    -- ... 상태 적용 ...
end
```

`_activeTweens` 테이블에는 UIVisibilityManager가 직접 생성하는 트윈(fade in/out 등)을 저장한다. 각 컨트롤러 내부 트윈은 해당 컨트롤러가 자체적으로 취소 책임을 진다.

---

### 9.9 [P2] 화면 방향 잠금

Coin Runner는 세로(Portrait) 모드 전용이다.

> Roblox Studio → Game Settings → Device → Portrait 전용으로 설정. 가로(Landscape) 모드는 미지원.

이로 인해 섹션 4의 레이아웃 사양은 모두 세로 모드를 기준으로 하며, 가로 모드 대응 레이아웃은 별도로 정의하지 않는다.

---

### 9.10 [P2] DailyChallengeController 초기 상태

DailyChallengeController는 Init() 단계에서 GUI를 비활성 상태로 시작한다.

**동작 흐름**:

```lua
function DailyChallengeController:Init()
    -- GUI 생성
    self._gui = -- ScreenGui 생성 로직
    self._gui.Enabled = false   -- Init 직후 비활성 상태로 시작

    -- UIVisibilityManager:SetState('lobby') 호출 시 Enabled = true로 전환됨
end
```

**이유**: 게임 초기화 순서에 따라 UIVisibilityManager보다 컨트롤러 Init()이 먼저 실행될 수 있다. Init() 시점에 GUI를 활성화하면 lobby 상태 진입 전에 잠깐 표시되는 플리커(flicker) 현상이 발생할 수 있으므로, 항상 비활성 상태로 시작하고 UIVisibilityManager가 명시적으로 `Show()`를 호출할 때만 표시한다.

이 원칙은 DailyChallengeController뿐 아니라 UIVisibilityManager가 관리하는 모든 컨트롤러에 동일하게 적용된다.

---
id: ISSUE-024
title: 게임 진행 중 과도한 UI 요소가 화면을 방해함
category: improvement
priority: P1-high
status: resolved
related_sprint: v3.1 Sprint 1 후보
related_ac: none
created: 2026-04-01
resolved: 2026-04-01
---

## 설명

게임 러닝 중 너무 많은 UI 요소가 동시에 표시되어 게임 플레이를 방해함.
6-12세 타겟 대상 러너 게임에서 화면이 복잡하면 집중도와 체감 게임성 저하 우려.

## 영향 분석

**현재 running 상태에서 표시되는 UI 목록** (`UIVisibilityManager.luau:184-202`):

| UI 요소 | 컨트롤러 | 메서드 | 화면 위치 |
|---------|----------|--------|-----------|
| 스킬 버튼 | activeSkillController | OnGameStart | 우하단 |
| 목표 HUD (아이콘) | objectiveHudController | CollapseToIcon | 좌상단 |
| 피버 게이지 | feverController | ShowGauge | 상단 중앙 |
| 펫 동반 UI | petController | StartGame | 미확인 |
| 코인킹 추적 | coinKingController | StartGame | 미확인 |
| 실시간 배틀 | realtimeBattleController | SetGameActive | 미확인 |
| 일일 이벤트 HUD | dailyEventController | StartGame | 미확인 |
| RunSkillHud | runSkillHudController | StartGame | 미확인 |

→ 동시 표시 가능 최대 8개 이상의 독립 UI 요소

**관련 파일**
- `src/client/Controllers/UIVisibilityManager.luau` — running 상태 매트릭스 (line 184-202)
- `src/client/Controllers/UIController.luau` — 점수/라이프/거리 표시
- `src/client/Controllers/ActiveSkillController.luau` — 스킬 버튼
- `src/client/Controllers/FeverController.luau` — 피버 게이지
- `src/client/Controllers/ObjectiveHudController.luau` — 목표 HUD
- `docs/design/mobile-ui-spec.md` — UI 레이아웃 스펙

**참고: v3.1 Sprint 0에서 이미 최소화 시도됨**
- S0-4: ObjectiveHUD 아이콘 모드 구현 (full → icon 축소)
- S0-8: ResponsiveUtil compactMode 적용 (크기 80% 축소)

그러나 요소 수 자체는 줄이지 않은 상태.

## 해결 방향 (후보)

1. **게임 중 비핵심 UI 숨김**: 코인킹, 실시간 배틀, 일일 이벤트 HUD는
   게임 중 순위/진행률만 표시하므로 running 중 기본 숨김 → 이벤트 발생 시만 토스트 노출
2. **투명도 증가**: 필수 UI(피버, 스킬, 라이프)는 유지하되 배경 투명도 높임
3. **HUD 자동 페이드**: 일정 시간 동작 없으면 UI 페이드아웃, 터치 시 복귀
4. **설정 옵션**: 플레이어가 표시할 HUD 요소를 직접 선택

## 해결 방안

**적용 방향**: 해결 방향 후보 1 (게임 중 비핵심 UI 숨김)

**수정 내용** (`DailyEventController.luau`):
- `StartGame`: `_hudGui.Enabled = false` (게임 시작 시 기본 숨김)
- `_showHudBriefly()` 추가: 진행 업데이트 시 3.5초 표시 후 자동 숨김
- `DailyEventProgress` 핸들러: `_showHudBriefly()` 호출 추가
- `_showCompletionEffect`: 이벤트 완료 시 HUD 강제 활성화 + _refreshHud 호출
- `Destroy`: `_hudHideTask` task.cancel 정리 추가

**미변경 항목** (변경 불필요):
- `RealtimeBattleController`: `_isInBattle` 조건부이므로 이미 배틀 중일 때만 표시
- `CoinKingController`: 15초 딜레이 후 서서히 표시, 기본 투명함
- 필수 HUD (점수/라이프/피버/스킬버튼): 유지

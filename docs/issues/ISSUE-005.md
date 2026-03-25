---
id: ISSUE-005
title: 모바일 UI 정보 과부하 — HUD/다이얼로그 최적화 필요
category: improvement
priority: P1-high
status: resolved
related_sprint: none (v3.1 후보)
related_ac: none
created: 2026-03-19
resolved: 2026-03-25
---

## 설명
게임 중 노출되는 UI 다이얼로그와 HUD가 모바일 최적화되어 있지 않음.
일일 도전, 런 목표, 레벨/미션, 점수 등 너무 많은 정보가 동시에 노출되어
6~12세 모바일 유저에게 정보 과부하 발생.

## 영향 분석

### 동시 노출 UI 목록 (게임 중)
| UI | 컨트롤러 | 위치 | 크기 |
|----|----------|------|------|
| 일일 도전 3개 | DailyChallengeController | 좌상단 | 220x130px |
| 런 목표 3개 | ObjectiveHudController | 좌측 | ~180x120px |
| 레벨/XP + 미션 버튼 | ProgressionController | 좌상단 | ~180x60px |
| 점수/거리/코인/라이프 | UIController (HudFrame) | 우측 | ~160x120px |
| 액티브 스킬 | ActiveSkillController | 우하단 | 80x80px |
| 런스킬 HUD | RunSkillHudController | 우상단 | 180x28px |
| 점프/슬라이드 버튼 | UIController (모바일) | 하단 | 터치 영역 |

### 관련 파일 (7개)
- `src/client/Controllers/DailyChallengeController.luau` (174줄)
- `src/client/Controllers/ObjectiveHudController.luau` (395줄)
- `src/client/Controllers/ProgressionController.luau` (1204줄)
- `src/client/Controllers/UIController.luau` (~1500줄)
- `src/client/Controllers/ActiveSkillController.luau` (~200줄)
- `src/client/Controllers/RunSkillHudController.luau` (~300줄)
- `src/client/Controllers/MiniGameController.luau` (~200줄)

### 권장 개선 방향
1. **게임 중 HUD 최소화**: 점수/라이프만 상시 노출, 나머지는 축소/숨김
2. **일일 도전**: 로비에서만 표시, 게임 중 숨김
3. **런 목표**: 아이콘 모드로 축소 (탭하면 확장)
4. **레벨/XP**: 게임 중 숨김 (레벨업 시에만 토스트 표시)
5. **모바일 터치 영역 확보**: 좌측 UI 축소로 손가락 터치 영역 확보
6. **/design 선행 필수**: 7개 컨트롤러 변경 → UX 스펙 확정 후 구현

## 해결 방안
v3.1 Sprint 0 (S0-1~S0-9)에서 해결:
- UIVisibilityManager: 6상태 머신으로 게임 상태별 UI 가시성 자동 제어
- UITokens: 디자인 토큰 단일 소스
- DailyChallengeController: 로비 전용, 게임 중 Hide
- ObjectiveHudController: 축소 모드 (48px 아이콘)
- RunSkillHudController/ActiveSkillController: Show/Hide 통합
- ResponsiveUtil: compactMode로 모바일 대응

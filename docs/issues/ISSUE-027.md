---
id: ISSUE-027
title: COIN RUSH / bonus_time 이벤트 발생 시 게임 진행 정지
category: bug
priority: P1-high
status: resolved
resolved: 2026-04-03
related_sprint: none
related_ac: none
created: 2026-04-03
---

## 설명
COIN RUSH 랜덤 이벤트 발생 후 게임 진행이 정지되는 현상.
스크린샷 기준: "COIN RUSH!" 텍스트 표시 + "이벤트 CLEAR!" 알림이 동시에 보이며
플레이어 캐릭터가 멈춘 상태 유지.

## 영향 분석

**관련 이벤트:** `bonus_time` 랜덤 이벤트 (GameConstants:2472~2521)
- UI에 "COIN RUSH!" 텍스트 표시 (`RandomEventController`)
- `_startCoinRainEffect()` 호출 → 코인 파티클 루프 시작
- 서버: `session._bonusTimeActive = true` + 속도 0.75x 감속 적용

**추정 원인 (2가지):**

1. **이벤트 종료 후 속도 미복원**
   - `bonus_time` 종료 시 `_bonusTimeActive = false` 설정
   - 그러나 서버 Heartbeat에서 `_speedShiftMultiplier`, `_bonusTimeActive` 조건 체크 순서 또는
     리셋 타이밍 문제로 속도가 0으로 수렴할 가능성
   - `GameManager.luau` 1719~1720 라인 부근 확인 필요

2. **`_startCoinRainEffect()` 루프가 character nil 시 무한 대기**
   - `RandomEventController.luau` 282~320 라인: 캐릭터 nil이면 루프 지속
   - `task.defer` 기반 루프가 끊기지 않고 남아 있을 경우 별도 문제는 없으나
     다음 이벤트 발동 시 중복 실행 가능

**영향 범위:**
- `src/server/Services/RandomEventService.luau` — 이벤트 종료 처리
- `src/client/Controllers/RandomEventController.luau` — 클라이언트 효과 적용/해제
- `src/server/Services/GameManager.luau` — Heartbeat 속도 연산

## 해결 방안

**Fix 1**: `GameManager.EndGame()`에 `RandomEventService:ForceEnd()` 추가 (line 1033 직후)
- 게임 종료 시 활성 랜덤 이벤트를 강제 종료
- `ForceEnd` → `EndEvent` → `RandomEventEnd:FireClient()` → 클라이언트 코인 레인 루프 중단

**Fix 2**: `RandomEventController._startCoinRainEffect()`에서 코인 파트를 `Folder`로 관리
- `CoinRainEffects` Folder에 파트 담기
- `_stopCoinRainEffect()`: `workspace:GetChildren()` 전체 순회 → `folder:Destroy()` 1호출로 대체
- 루프 중 `folder.Parent == nil` 감지 시 즉시 `coinRainActive = false`로 안전 종료

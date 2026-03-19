---
id: ISSUE-006
title: 게임 중 맵 생성 중단 — CoinStorm task.cancel 에러 + sessionState 미복귀
category: bug
priority: P0-critical
status: resolved
related_sprint: v3.0 Sprint 4 (M1 후반)
related_ac: AC-4-1, AC-4-3
created: 2026-03-19
resolved: 2026-03-19
---

## 설명
게임 플레이 중 맵(청크)이 중간에서 생성이 멈추고 낭떨어지가 됨.
로그: `CoinStorm:99: cannot cancel thread`

## 영향 분석

### 근본 원인 (2단계)

**1단계 — CoinStorm:99 task.cancel 에러**
- `_finish()` 내부에서 `task.cancel(game.endTimer)` 호출
- endTimer 콜백이 `_finish()`를 호출한 경우, 자기 자신(실행 중인 thread)을 취소하려 해서 에러
- 이 에러로 `_finish()`가 중단되면 `MiniGameService:OnPlayerFinish()` (112행)가 호출되지 않음

**2단계 — sessionState "minigame"에서 미복귀**
- `MiniGameService:OnPlayerFinish()`가 호출되지 않으면 sessionState가 "running"으로 복귀하지 않음
- GameManager 메인 루프(1264행)에서 `sessionState == "minigame"`이면 `continue`로 청크 생성 포함 모든 러너 로직 건너뜀
- 결과: 청크 생성 영구 중단 → 맵 끝 → 낙사

### 영향 범위
- **심각도**: P0 — 게임 진행 불가
- **재현 조건**: CoinStorm 미니게임의 endTimer 타임아웃으로 `_finish()` 진입 시
- **관련 파일**:
  - `src/server/Services/MiniGames/CoinStorm.luau:98-101` — task.cancel 에러
  - `src/server/Services/MiniGameService.luau` — OnPlayerFinish (sessionState 복귀)
  - `src/server/Services/GameManager.luau:1264` — minigame 상태에서 continue

### 해결 방향
1. CoinStorm._finish()에서 endTimer가 현재 실행 중인 스레드인지 확인 후 pcall로 보호
2. MiniGameService에 타임아웃 안전장치 추가 — sessionState가 "minigame"에서 N초 이상 머무르면 강제 복귀

## 해결 방안
CoinStorm.luau + ObstacleRush.luau의 모든 `task.cancel()` 호출을 `pcall(task.cancel, ...)` 로 보호.
endTimer 콜백이 `_finish()`를 호출한 경우 자기 스레드를 취소하려 해도 에러가 무시되어
`MiniGameService:OnPlayerFinish()`가 정상 호출됨 → sessionState "running" 복귀 → 청크 생성 재개.

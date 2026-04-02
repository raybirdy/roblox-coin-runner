---
id: ISSUE-026
title: 포탈 진입 후 게임 시작 안 됨 — gameover→countdown 전이 누락
category: bug
priority: P1-high
status: resolved
related_sprint: none
related_ac: none
created: 2026-04-02
resolved: 2026-04-02
---

## 설명
게임 종료 후 포탈로 재진입하면 게임이 시작되지 않는 현상.
코드를 수정할 때마다 재발하는 반복 버그.

## 영향 분석

**근본 원인: Roblox RemoteEvent 도착 순서 비보장 + VALID_TRANSITIONS 누락**

1. 서버 흐름:
   - `EndGame()` → `GameOver:FireClient()` → (플레이어가 포탈 Touched) → `ReturnToLobby:FireClient()` + `PortalEnter:FireClient()` 거의 동시 발생

2. 클라이언트 수신 순서가 역전될 경우:
   - `PortalEnter:FireClient()` 먼저 도착 → `GameStart:FireClient()` → `SetState("countdown")` 시도
   - 이 시점 클라이언트는 아직 `gameover` 상태
   - `VALID_TRANSITIONS.gameover = { "lobby" }` — `"countdown"` 없음
   - `SetState` 내부에서 `newState = "lobby"` 강제 폴백 + warn
   - 이후 `ReturnToLobby:FireClient()` 도착 → `SetState("lobby")` (이미 lobby → idempotent 통과)
   - 카운트다운 콜백의 `lobby → running` 전이도 VALID_TRANSITIONS에 없어 다시 폴백
   - 결과: 게임 UI가 작동하지 않고 로비 화면이 표시됨

3. 영향 범위:
   - `src/client/Controllers/UIVisibilityManager.luau` — `VALID_TRANSITIONS` 테이블

## 해결 방안
`VALID_TRANSITIONS.gameover`에 `"countdown"` 추가:

```lua
-- Before
gameover  = { "lobby" },

-- After
gameover  = { "lobby", "countdown" }, -- gameover→countdown: ReturnToLobby 전에 포탈 재진입 가능 (레이스 컨디션 허용)
```

커밋: `5494191`

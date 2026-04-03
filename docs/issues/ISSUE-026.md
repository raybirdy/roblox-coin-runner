---
id: ISSUE-026
title: 포탈 진입 후 게임 시작 안 됨 — 상태 전이 누락 (반복 발생)
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

**근본 원인: VALID_TRANSITIONS 누락 + 복수의 레이스 컨디션**

### 주요 시나리오 (가장 빈번)

1. 플레이어 낙사 흐름:
   - 플레이어 Y < -10 → 서버 `EndGame()` → `GameOver:FireClient()` → `activeSessions[player] = nil`
   - Roblox 엔진이 캐릭터 리스폰 → `CharacterAdded` 발동 → 로비 스폰 위치에 배치
   - 스폰 위치가 포탈 근처 → 즉시 포탈 터치 → `activeSessions` nil 확인 후 `PortalEnter:FireClient()`
   - 클라이언트가 `GameOver:FireClient()`를 아직 수신하기 전이라 상태가 여전히 **"running"**
   - 파워업 선택 → `PortalEnter:FireServer()` → 서버가 `GameStart:FireClient()` 전송
   - 클라이언트: `SetState("countdown")` 시도 — 현재 상태 "running"
   - `VALID_TRANSITIONS["running"]`에 "countdown" 없음 → `newState = "lobby"` 강제 폴백
   - 카운트다운 콜백: `SetState("running")` 시도 — 현재 상태 "lobby"
   - `VALID_TRANSITIONS["lobby"]`에 "running" 없음 → 다시 폴백
   - 결과: `playerController:StartGame()` 호출되나 UI 상태 불일치로 게임 미작동

2. 부차 시나리오 (이전에 수정된):
   - `gameover` 상태에서 포탈 재진입 시 `gameover → countdown` 전이 누락 (커밋 `5494191`)
   - `ReturnToLobby:FireClient()`가 카운트다운 중 도착 시 interrupt (커밋 `ceebfd1`)

3. 부차 시나리오 (이번 수정):
   - 이전 세션의 `GameOver:FireClient()`가 새 게임 카운트다운 중에 지연 도착
   - `countdown → gameover` 전이 없어도, `GameOver.OnClientEvent`가 카운트다운을 끊어버림

### 영향 범위
- `src/client/Controllers/UIVisibilityManager.luau` — `VALID_TRANSITIONS` 테이블
- `src/client/init.client.luau` — `GameOver.OnClientEvent` 핸들러

## 해결 방안

### 1. `VALID_TRANSITIONS["running"]`에 `"countdown"`, `"lobby"` 추가
```lua
-- Before
running = { "minigame", "paused", "gameover" },

-- After
running = { "minigame", "paused", "gameover", "countdown", "lobby" },
-- running→countdown: 리스폰 후 GameOver 미수신 상태에서 포탈 재진입 허용
-- running→lobby: ReturnToLobby 수신 시 경고 없이 처리
```

### 2. `GameOver.OnClientEvent`에 카운트다운 가드 추가
```lua
-- 카운트다운 중이면 무시 (이전 세션의 지연 도착)
if UIVisibilityManager:GetState() == "countdown" then
    return
end
```

### 3. `minigame`, `paused`에도 `"countdown"` 추가 (방어적 수정)
- 미니게임/일시정지 중 재시작 엣지 케이스 허용

커밋: `5494191` (1차), `ceebfd1` (2차), 이번 커밋 (3차)

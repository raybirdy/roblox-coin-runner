---
id: ISSUE-028
title: 일일 미션 CHALLENGE_POOL에 미니게임 목표 포함 — 제거 필요
category: improvement
priority: P2-medium
status: resolved
resolved: 2026-04-03
related_sprint: none
related_ac: none
created: 2026-04-03
---

## 설명
일일 미션(Daily Challenge)에 미니게임 클리어 목표(`minigame_clear`)가 포함되어 있으나,
미니게임은 현재 비활성화 상태 (v3.1 재미 부족으로 의도적 비활성화).
달성 불가능한 목표가 일일 미션에 노출되어 플레이어 혼란 야기.

## 영향 분석

**근본 원인:**
- `src/shared/Constants/GameConstants.luau` 2536~2547 라인:
  ```lua
  { id = "minigame_clear", desc = "Clear %d minigames", difficulty = "normal", targets = { 1, 2, 3 } },
  ```
- `DailyChallengeService.luau` `generateChallenges()`: CHALLENGE_POOL에서 랜덤 선택
- GameManager:1394~1397: 미니게임 트리거 주석 처리 (비활성화)
- 결과: `minigame_clear` 목표가 배정되면 플레이어가 영구적으로 완료 불가

**영향 범위:**
- `src/shared/Constants/GameConstants.luau` — CHALLENGE_POOL

## 해결 방안
`CHALLENGE_POOL`에서 `minigame_clear` 항목 제거:
```lua
-- 제거 대상:
{ id = "minigame_clear", desc = "Clear %d minigames", difficulty = "normal", targets = { 1, 2, 3 } },
```

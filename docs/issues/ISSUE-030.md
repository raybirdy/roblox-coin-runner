---
id: ISSUE-030
title: DualFloor 진입 경사로 51° 과경사 — 게임 진행 불가
category: bug
priority: P1-high
status: resolved
resolved: 2026-04-03
related_sprint: Sprint 2 (IDEA-003)
related_ac: none
created: 2026-04-03
---

## 설명
2층 분기 맵(DualFloor) 진입 경사로가 약 51° 경사로 생성되어
플레이어 화면에서 거의 벽처럼 보이고, 근처에 장애물이 배치될 경우
게임 진행이 물리적으로 불가능해짐.

## 영향 분석

**근본 원인:**
- `GameConstants.DUAL_FLOOR`:
  - `FLOOR2_Y = 10` studs (2층 높이)
  - `RAMP_LENGTH = 8` studs (경사로 수평 길이)
  - `rampAngle = atan2(10, 8) ≈ 51.3°` — 매우 가파름
- `ProceduralChunkGenerator._createDualFloor()` 135~152 라인:
  - `ramp.CanCollide = true`
  - 경사로가 청크 시작점 바로 앞에 위치
  - 장애물 제외 구역 없음 → 이전 청크 장애물과 겹침 가능

**영향 범위:**
- `src/shared/Constants/GameConstants.luau` — DUAL_FLOOR 상수

## 해결 방안
`RAMP_LENGTH` 8 → 18 studs, `FLOOR2_Y` 10 → 8 studs로 변경:
- 경사각: `atan2(8, 18) ≈ 24°` (기존 51° → 24°)
- 완만한 경사로로 플레이어가 자연스럽게 올라갈 수 있음

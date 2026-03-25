---
id: ISSUE-007
title: 미니게임 게임성 고도화 필요 — 러너 흐름 방해
category: improvement
priority: P2-medium
status: resolved
related_sprint: v3.0 Sprint 3-4 (M1)
related_ac: none
created: 2026-03-19
resolved: 2026-03-25
---

## 설명
미니게임(장애물 러시, 코인 폭풍)이 러너 플레이 흐름을 방해함.
현재 v3.1에서 트리거 비활성화 상태 (GameManager:1377 주석 처리).

## 영향 분석
- **현재 상태**: 미니게임 트리거 off (코드 보존, 재활성화 가능)
- **문제**: 미니게임 진입 시 러너 속도감이 끊기고, 게임플레이 리듬 저해
- **기술 부채**: ISSUE-006 (task.cancel 에러)는 pcall로 보호했으나 근본적 상태 머신 안정성 개선 필요
- **관련 파일**:
  - `src/server/Services/MiniGameService.luau`
  - `src/server/Services/MiniGames/CoinStorm.luau`
  - `src/server/Services/MiniGames/ObstacleRush.luau`
  - `src/client/Controllers/MiniGameController.luau`
  - `src/server/Services/GameManager.luau:1377` (트리거 주석 처리)

## 해결 방안
ISSUE-010 (보너스 타임 이벤트)로 대체 — 러너 흐름을 끊지 않는 인라인 보너스 구간으로 재설계.
기존 미니게임(CoinStorm/ObstacleRush)은 보너스 타임으로 통합 예정.

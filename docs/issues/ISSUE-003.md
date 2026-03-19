---
id: ISSUE-003
title: GameManager 크래시 — TutorialService.new() nil 호출 (게임 시작 불가)
category: blocker
priority: P0-critical
status: open
related_sprint: Sprint 1 (v3 튜토리얼 리팩토링)
related_ac: AC-1-8
created: 2026-03-19
resolved: null
---

## 설명
게임 포탈 터치해도 게임이 시작되지 않음.
로그: `GameManager:200: attempt to call a nil value`

## 영향 분석
- **근본 원인**: v3 Sprint 1에서 TutorialService를 싱글톤으로 리팩토링했으나,
  GameManager:200의 `TutorialService.new()` 호출이 구 API를 참조.
  - `TutorialService.new()` → 존재하지 않음 (v3에서는 싱글톤 모듈)
  - `globalTutorialService:SetPlayerDataService()` → 존재하지 않음
- **영향 범위**: GameManager 모듈 로드 실패 → 포탈 터치 이벤트, 게임 시작, 모든 게임 로직 미동작
- **관련 파일**:
  - `src/server/Services/GameManager.luau:200-203`
  - `src/server/Services/TutorialService.luau` (v3 싱글톤 API)

## 해결 방안
GameManager:200-203의 구 API 호출을 v3 싱글톤 API로 교체:
- `TutorialService.new()` → 제거 (싱글톤이므로 직접 사용)
- `globalTutorialService:SetPlayerDataService()` → TutorialService 직접 사용 또는 해당 메서드 제거
- `globalTutorialService` 변수를 `TutorialService`로 교체

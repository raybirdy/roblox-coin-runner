---
id: ISSUE-004
title: Client 크래시 — TutorialController:SetNPCController() 미존재 메서드 호출
category: bug
priority: P1-high
status: open
related_sprint: Sprint 1 (v3 튜토리얼 리팩토링)
related_ac: AC-1-8
created: 2026-03-19
resolved: null
---

## 설명
클라이언트 초기화 중 에러 발생.
로그: `Client:470: attempt to call missing method 'SetNPCController' of table`

## 영향 분석
- **근본 원인**: v3 TutorialController에 `SetNPCController()` 메서드가 없음.
  init.client.luau:470에서 구 API를 호출 중.
- **영향 범위**: 클라이언트 초기화 스크립트 중단 (470행 이후 코드 미실행)
- **관련 파일**:
  - `src/client/init.client.luau:470`
  - `src/client/Controllers/TutorialController.luau` (v3 API)

## 해결 방안
init.client.luau:470의 `tutorialController:SetNPCController(npcController)` 호출을 제거하거나,
TutorialController에 해당 메서드를 추가.

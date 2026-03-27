---
id: ISSUE-017
title: UIVisibilityManager Init 메서드 누락 — init.client.luau 전체 크래시
category: bug
priority: P0-critical
status: resolved
related_sprint: v3.1 Sprint 0 (S0-7)
related_ac: S0-7
created: 2026-03-27
resolved: 2026-03-27
---

## 설명
`UIVisibilityManager.luau`에 `Init` 메서드가 정의되어 있지 않아 `init.client.luau` 168번째 줄에서
`UIVisibilityManager:Init({...})`를 호출할 때 "attempt to call nil value (method 'Init')" 에러가 발생.
Roblox LocalScript 크래시로 이후 모든 이벤트 리스너(`PortalEnter`, `GameStart`, `RandomEventStart` 등)가 등록되지 않아:
- 포털 진입 시 게임 시작이 안 됨
- giant_mode / coin_rain 등 랜덤 이벤트 비주얼 효과 미작동

## 영향 분석
- `src/client/init.client.luau` 168행 — Init 호출 지점에서 크래시
- `src/client/Controllers/UIVisibilityManager.luau` — Init 메서드 미구현
- 모든 클라이언트 이벤트 리스너 무효화 (게임 플레이 불가)

## 해결 방안
`UIVisibilityManager.luau`에 싱글톤 초기화 `Init(controllers)` 메서드 추가:
- `self._controllers`, `self._currentState = "lobby"`, `self._activeTweens = {}` 초기화
- `_applyState`에 `_controllers` nil 가드 추가 (Init 이전 호출 방어)

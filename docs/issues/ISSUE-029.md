---
id: ISSUE-029
title: giant_mode 등 랜덤 이벤트 시각 효과 미작동
category: bug
priority: P2-medium
status: open
related_sprint: none
related_ac: none
created: 2026-04-03
resolved: null
---

## 설명
`giant_mode` 랜덤 이벤트 등이 발동해도 시각 효과가 나타나지 않는 현상.
서버 측 이벤트 발동 자체는 작동하나 클라이언트 시각 반영이 안 되는 것으로 추정.

## 영향 분석

**`giant_mode` 이벤트 구조:**
- 서버: `RandomEventService.luau` 124~125 — `session._giantScaleFactor = 1.8` 설정
- 클라이언트: `RandomEventController.luau` 62~93 — R15 BodyScale NumberValue 변경

**미작동 추정 원인:**

1. **R15 BodyScale 경로 불일치**
   - R15 스케일: `character.Humanoid:FindFirstChild("BodyHeightScale")` 등
   - R6 폴백: `BasePart` 직접 크기 변경
   - 실제 캐릭터가 R15인지 R6인지에 따라 다른 코드 경로 사용
   - Roblox Studio 기본 테스트 캐릭터는 R6 → R15 경로가 적용 안 됨

2. **이벤트 발동 타이밍 및 UI 피드백 없음**
   - 이벤트가 발동돼도 시각적으로 티가 나지 않을 수 있음
   - TRIGGER_INTERVAL 8±3초로 발동 자체가 드문 경우

3. **ISSUE-021과 유사한 참조 문제**
   - 이전 ISSUE-021 (코인소나기 참조 관리) 수정 후 giant_mode도 동일 문제 가능성

**영향 범위:**
- `src/client/Controllers/RandomEventController.luau` — giant_mode 클라이언트 효과
- `src/server/Services/RandomEventService.luau` — 이벤트 발동 서버 로직

## 해결 방안
(등록 시점에는 비워둠 — 처리 시 채움)

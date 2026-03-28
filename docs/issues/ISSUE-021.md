---
id: ISSUE-021
title: 랜덤 이벤트 시각 효과 미작동 — 거인 모드 무음 실패 + 코인 소나기 stale 참조
category: bug
priority: P1-high
status: open
related_sprint: none
related_ac: none
created: 2026-03-28
resolved: null
---

## 설명
랜덤 이벤트가 서버에서 정상 발동되고 알림 토스트는 표시되지만,
거인 모드(캐릭터 커지지 않음)와 코인 소나기(코인 파트 미생성) 등의 **시각 효과가 없음**.
ISSUE-017(Init 크래시)과는 별개의 문제.

## 영향 분석

### Bug 1: 거인 모드 — R15 스케일 값 미존재 시 무음 실패
- `RandomEventController:_onEventStart` (line 63-75)
- `Humanoid:FindFirstChild("BodyHeightScale")` 등 4개 NumberValue 탐색
- R6 리그 또는 커스텀 리그 사용 시 이 값들이 존재하지 않아 `if scaleValue then` 가드에서 전부 스킵
- **에러도 warn도 없이 무음 실패** → 디버깅 불가

### Bug 2: 코인 소나기 — stale character 참조 + refCount 불일치
- `RandomEventController:_startCoinRainEffect` (line 231-277)
- line 238: `local character = self._player.Character` — 루프 시작 시 1회만 캡처
- 게임 중 캐릭터 리스폰 시 캡처된 참조가 destroyed 모델을 가리킴
- line 245: `character:FindFirstChild("HumanoidRootPart")` → nil 또는 에러 → 루프 break
- **refCount 불일치**: character가 nil이면 line 239에서 early return하지만, line 233에서 이미 refCount +1 됨. `_coinRainActive`는 설정 안 됨 → 이후 stop에서 상태 불일치

### 포그: 정상 동작 예상
- `Lighting.FogEnd` / `FogColor` 트윈은 캐릭터 리그에 무관

### 관련 파일
- `src/client/Controllers/RandomEventController.luau` — 모든 시각 효과 로직
- `src/shared/Constants/GameConstants.luau` — RANDOM_EVENTS 설정 (값 자체는 정상)
- `src/server/Services/RandomEventService.luau` — 서버 이벤트 발송 (정상 동작)

## 해결 방안
(처리 시 채움)

### 거인 모드
- R15 스케일 값이 없으면 R6 폴백: 캐릭터 BasePart.Size를 직접 스케일링
- `Humanoid:ScaleTo()` API 사용 검토 (R6/R15 모두 지원)
- 실패 시 warn 로그 추가

### 코인 소나기
- 루프 내에서 매 반복마다 `self._player.Character` 재취득
- character nil 시 early return 전에 refCount 원복 또는 `_coinRainActive = true`를 nil 체크 이전으로 이동
- 진단용 print/warn 추가

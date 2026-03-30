---
id: ISSUE-022
title: 랜덤 이벤트 미작동 — 거인 모드, 코인소나기, 포그 시각 효과 없음
category: bug
priority: P1-high
status: open
related_sprint: v3.1 Sprint 1 후보
related_ac: none
created: 2026-03-30
resolved: null
---

## 설명

ISSUE-021 해결(2026-03-28, commit 6c73342) 이후에도 다음 랜덤 이벤트가 동작하지 않는다고 보고됨:
- 거인 모드 (giant_mode): 캐릭터 확대 시각 효과 없음
- 코인소나기 (coin_rain): 낙하 코인 파티클 없음
- 포그 (fog): 안개 연출 없음

## 영향 분석

**코드 분석 결과**: 세 이벤트 모두 구현 완료 상태
- `RandomEventService.luau`: 서버 플래그 설정 정상
- `RandomEventController.luau`: 클라이언트 이펙트 핸들러 정상
- `GameConstants.luau`: 6종 이벤트 정의 완료

**의심 원인 3가지**

1. **이벤트 미발동**: `RandomEventService:Update()`가 GameManager 게임 루프에서 호출되지 않거나, 세션 상태 조건(running 상태) 미충족
   - 확인 위치: `GameManager.luau` 내 `RandomEventService:Update()` 호출 여부 및 조건

2. **클라이언트 수신 실패**: `RandomEventController:Init()` 실행 시점 vs `RemoteEvents.RandomEventStart` 연결 타이밍 이슈
   - v3.1 Sprint 0(UIVisibilityManager 통합) 이후 init.client.luau 실행 순서 변경 가능성
   - 확인 위치: `init.client.luau` 208번 줄 부근, randomEventController:Init() 호출 순서

3. **ISSUE-021 부분 해결**: R6 폴백 및 stale 참조 수정은 완료됐으나, 근본적인 FireClient 미도달 문제가 남아 있을 가능성
   - 확인 위치: RandomEventService 서버 로그 `[RandomEventService] {eventId} started for ...` 출력 여부

**영향 범위**
- src/server/Services/RandomEventService.luau
- src/client/Controllers/RandomEventController.luau
- src/client/init.client.luau (초기화 순서)
- src/server/GameManager.luau (Update 호출 지점)

**재현 조건**
- Studio 로컬 서버, 솔로 플레이
- 게임 시작 후 25~45초 대기 (SOLO_TRIGGER_INTERVAL = 25s)
- 콘솔에서 `[RandomEventService] ... started` 로그 확인

## 해결 방안
(등록 시점에는 비워둠 — 처리 시 채움)

---
id: ISSUE-010
title: 보너스 타임 이벤트 — 비활성화된 미니게임을 러너 내 보너스 구간으로 대체
category: improvement
priority: P1-high
status: resolved
related_sprint: none (v3.2 후보)
related_ac: none
created: 2026-03-25
resolved: 2026-03-25
---

## 설명
쿠키런 오븐브레이크 벤치마크: 달리는 도중 랜덤하게 "보너스 타임" 발동 → 코인 대량 출현 + 속도 감소 → "쫙 먹는" 만족감 제공.
현재 미니게임(CoinStorm, ObstacleRush)은 러너 흐름을 끊는 문제로 비활성화 상태 (ISSUE-006/007).

**개선 방향**: 러너 흐름을 유지하면서 보너스 이벤트 발동
- 10~15초 동안 코인 2~3배 스폰, 속도 70%로 감소
- 장애물 밀도 감소 (Bonus 청크와 유사)
- 팡파르 연출 + 화면 색상 변화 + 카운트다운 타이머
- 기존 RandomEventService 인프라를 재활용하여 구현
- 미니게임 `"minigame"` 세션 상태를 사용하지 않음 (러너 로직 중단 방지)

## 영향 분석
- **복잡도**: M (Medium) — 기존 인프라 활용도 높음
- **서버**:
  - `GameManager.luau` (line 1377): 미니게임 트리거 → BonusTime 트리거로 교체
  - `MiniGameService.luau`: 대폭 재작성 또는 BonusTimeService로 대체
  - `RandomEventService.luau`: BonusTime을 신규 이벤트 타입으로 추가 (가장 깔끔한 통합 경로)
  - `CoinService.luau`: BonusTime 중 코인 스폰률 부스트
  - `MiniGames/CoinStorm.luau`, `ObstacleRush.luau`: 아카이브 처리
- **클라이언트**:
  - `MiniGameController.luau`: BonusTime 오버레이(타이머, 2x 표시)로 재작성
  - `UIVisibilityManager.luau`: minigame 상태 → BonusTime은 running 상태 내 서브상태
- **상수**: `GameConstants.MINI_GAME` → `BONUS_TIME` 테이블 신설
- **의존성**: UIVisibilityManager 상태 머신 검토, 일일 챌린지 `minigame_clear` 마이그레이션
- **관련 이슈**: ISSUE-006 (미니게임 task.cancel 에러), ISSUE-007 (미니게임 게임성 고도화)

## 해결 방안
RandomEventService에 bonus_time 이벤트 추가 (코인 3배, 속도 75%). GameManager에서 _bonusTimeActive 플래그 소비 (코인/속도 모두 반영). 클라이언트: 골든 틴트 + 코인비 이펙트. 미니게임(ISSUE-007) 대체 완료.

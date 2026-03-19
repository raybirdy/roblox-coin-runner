# Sprint 6 완료 보고서

## 개요
- **Sprint**: 6 — 랜덤 이벤트 + 일일 도전
- **버전**: v3.0
- **PR**: #183
- **커밋**: 947c73d
- **상태**: 완료

## 목표
랜덤 이벤트 5종(S1)과 일일 도전 과제 3개(S3)를 구현하여 게임 세션 내 변주와 재방문 동기를 동시에 확보한다.

## 완료 항목
- `RandomEventService` 구현 — 랜덤 이벤트 5종 서버 트리거 및 상태 관리
- `RandomEventController` 구현 — 이벤트 연출 및 클라이언트 알림 UI
- 랜덤 이벤트 5종:
  - 코인비 — 일정 시간 코인 생성량 급증
  - 속도변환 — 플레이어 이동 속도 일시 변경
  - 거인 — 플레이어 캐릭터 크기 확대, 충돌 범위 증가
  - 중력반전 — 중력 방향 반전, 천장 코인 배치
  - 안개 — 화면 가시거리 축소, 반응 속도 도전
- `DailyChallengeService` 구현 — 매일 3개 도전 과제 생성, 00:00 UTC 리셋, 배틀패스 XP 지급
- `DailyChallengeController` 구현 — 도전 과제 진행 UI, 완료 알림
- 배틀패스 XP 연동 — 도전 완료 시 XP 서버에서 지급 및 검증

## Acceptance Criteria 결과

| AC | 항목 | 결과 |
|----|------|------|
| AC-6-1 | 랜덤 이벤트 5종 각각 정상 트리거 | 통과 |
| AC-6-2 | 이벤트 중복 방지 (동시에 2개 이상 발생 불가) | 통과 |
| AC-6-3 | 이벤트 종료 후 원상복귀 | 통과 |
| AC-6-4 | 일일 도전 과제 매일 3개 정상 생성 | 통과 |
| AC-6-5 | 00:00 UTC 기준 도전 과제 리셋 | 통과 |
| AC-6-6 | 도전 완료 시 배틀패스 XP 지급 | 통과 |
| AC-6-7 | 클라이언트 도전 과제 UI 진행률 표시 | 통과 |
| AC-6-8 | 서버 재시작 후 도전 과제 상태 유지 | 통과 |

## Deferred 항목
없음

## 주요 변경 파일
- `src/server/Services/RandomEventService.luau` — 랜덤 이벤트 5종 서버 로직 및 스케줄러
- `src/client/Controllers/RandomEventController.luau` — 이벤트 연출 및 알림 UI
- `src/server/Services/DailyChallengeService.luau` — 도전 과제 생성, 진행 추적, XP 지급
- `src/client/Controllers/DailyChallengeController.luau` — 도전 과제 UI 및 완료 피드백

## 다음 Sprint 영향
Sprint 7 솔로 밸런스 패스에서 랜덤 이벤트 발생 빈도와 일일 도전 난이도를 솔로 플레이 기준으로 재조정해야 한다. 특히 Co-op 대비 솔로 환경에서 거인/중력반전 이벤트의 체감 난이도 차이를 수치로 보정한다.

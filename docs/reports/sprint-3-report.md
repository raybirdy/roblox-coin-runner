# Sprint 3 완료 보고서

## 개요
- **Sprint**: 3 — 미니게임: 장애물 러시 + 상태 머신
- **버전**: v3.0
- **PR**: #180
- **커밋**: fafa395
- **상태**: 완료

## 목표
GameSession 상태 머신 구현 + MiniGameService 구축 + 장애물 러시 미니게임 출시 (M1 전반)

## 완료 항목
- GameSession 상태 머신 구현 (`running` / `minigame` / `paused` 3상태)
- MiniGameService 공통 프레임워크 구현
- ObstacleRush(장애물 러시) 미니게임 구현
- `shiftTimeFields`: 미니게임 복귀 시 12개 이상 시간 필드 일괄 보정
- Co-op 미니게임 동기화 처리
- momus 코드 리뷰 P0 버그 5건 수정

## Acceptance Criteria 결과

| AC | 내용 | 결과 |
|----|------|------|
| AC-3-1 | GameSession 상태가 running/minigame/paused 간 전환 | 통과 |
| AC-3-2 | 미니게임 진입/복귀 시 상태 정합성 유지 | 통과 |
| AC-3-3 | shiftTimeFields로 12개 이상 시간 필드 일괄 보정 | 통과 |
| AC-3-4 | ObstacleRush 미니게임 진행 및 완료 | 통과 |
| AC-3-5 | 미니게임 히트 판정 서버 auto-hit 처리 | 통과 |
| AC-3-6 | 클라이언트 dodge 보고 서버 검증 | 통과 |
| AC-3-7 | Co-op 모드 미니게임 동기화 | 통과 |
| AC-3-8 | mini_game_bonus 업그레이드 보상 반영 | 통과 |

## Deferred 항목
없음

## 주요 변경 파일
- `src/server/Services/MiniGameService.luau` — 신규 생성 (미니게임 공통 프레임워크)
- `src/server/Services/MiniGames/ObstacleRush.luau` — 신규 생성 (장애물 러시 구현)
- `src/client/Controllers/MiniGameController.luau` — 신규 생성 (미니게임 전환 및 UI 처리)

## 기술 참고: momus P0 버그 수정 내역
momus 코드 리뷰를 통해 발견된 P0 버그 5건을 Sprint 3 내 수정 완료:
1. `shiftTimeFields` 미적용 — 미니게임 복귀 시 시간 기반 필드 12개 이상 왜곡 발생 가능성
2. 미니게임 히트 판정 클라이언트 신뢰 문제 — 서버 auto-hit 방식으로 전환
3. Co-op 동기화 타이밍 경쟁 조건
4. 상태 머신 전환 중 이벤트 누락 가능성
5. ObstacleRush 종료 시 보상 미지급 엣지 케이스

## 다음 Sprint 영향
- MiniGameService 프레임워크를 Sprint 4 CoinStorm(코인 폭풍) 미니게임이 그대로 재사용
- GameSession 상태 머신이 이후 모든 Sprint의 실행 컨텍스트 기반이 됨
- `shiftTimeFields` 패턴이 시간 기반 필드를 다루는 모든 서비스의 표준으로 정착

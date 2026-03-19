# Sprint 0 완료 보고서

## 개요
- **Sprint**: 0 — 기반 정비 + 아키텍처 설계
- **버전**: v3.0
- **PR**: #177
- **커밋**: 29b6028
- **상태**: 완료

## 목표
v2.2 기술 부채 해소(M5) + Analytics 기반 구축(M4) + 미니게임 아키텍처 설계 확정(M1 설계 단계)

## 완료 항목
- AnalyticsService / AnalyticsController 구현 (10종 이벤트 추적)
- Co-op 포탈 터치 → 매칭큐 진입 로직 구현
- Co-op 카메라 FOV 솔로 모드와 구분 적용
- GameConstants.MINI_GAME 상수 정의
- MonetizationService ProductId=0 가드 처리 (MEGA/ULTRA 번들 임시 차단)
- 미니게임 아키텍처 설계 문서 작성

## Acceptance Criteria 결과

| AC | 내용 | 결과 |
|----|------|------|
| AC-0-1 | ProductId=0 → 실제 값 교체 | Deferred — Roblox Creator Hub 등록 필요 |
| AC-0-2 | SoundId 빈 문자열 0건 | 통과 |
| AC-0-3 | Co-op 포탈 터치 시 매칭큐 진입 | 통과 |
| AC-0-4 | Co-op 카메라 FOV 솔로와 다름 | 통과 |
| AC-0-5 | Analytics 10종 이벤트 발화 확인 | 통과 |
| AC-0-6 | Analytics DataStore 미사용 | 통과 |
| AC-0-7 | 미니게임 아키텍처 설계 문서 존재 | 통과 |
| AC-0-8 | GameConstants.MINI_GAME 상수 존재 | 통과 |
| AC-0-9 | 스모크 테스트 통과 | Deferred — Studio 통합 테스트 필요 |

## Deferred 항목
- **AC-0-1 (ProductId 교체)**: Roblox Creator Hub에서 MEGA/ULTRA 번들 상품 등록 후 실제 ProductId 값으로 교체 필요. 소프트 론치 전 완료 예정.
- **AC-0-9 (스모크 테스트)**: Studio 환경에서 통합 테스트 미실행. 소프트 론치 전 완료 예정.

## 주요 변경 파일
- `src/server/Services/AnalyticsService.luau` — 신규 생성 (10종 이벤트 서버 처리)
- `src/client/Controllers/AnalyticsController.luau` — 신규 생성 (클라이언트 이벤트 수집)
- `src/shared/Constants/GameConstants.luau` — MINI_GAME 상수 블록 추가, ProductId 가드 추가

## 다음 Sprint 영향
- Sprint 1 (튜토리얼)에서 `tutorial_step` Analytics 이벤트를 즉시 활용 가능
- MINI_GAME 상수가 Sprint 3 MiniGameService 구현의 기반이 됨
- ProductId 가드 덕분에 미등록 상태에서도 서버 에러 없이 운영 가능

# Sprint 1 완료 보고서

## 개요
- **Sprint**: 1 — 튜토리얼/온보딩 강화
- **버전**: v3.0
- **PR**: #178
- **커밋**: 6da3d32
- **상태**: 완료

## 목표
신규 유저의 첫 5런을 단계적으로 안내하는 튜토리얼 시스템 구현 (M2)

## 완료 항목
- TutorialService 5단계 튜토리얼 플로우 구현
- NPC "코이니(Coiny)" 대화 시스템 구현
- PlayerData 마이그레이션 (tutorial_step 필드 추가)
- 튜토리얼 스킵 기능 구현
- `tutorial_step` Analytics 이벤트 연동

## Acceptance Criteria 결과

| AC | 내용 | 결과 |
|----|------|------|
| AC-1-1 | 신규 유저 첫 접속 시 튜토리얼 자동 시작 | 통과 |
| AC-1-2 | 5단계 순서대로 진행 | 통과 |
| AC-1-3 | NPC "코이니" 대화 출력 | 통과 |
| AC-1-4 | 단계별 PlayerData 저장 | 통과 |
| AC-1-5 | 튜토리얼 스킵 기능 작동 | 통과 |
| AC-1-6 | 재접속 시 완료된 단계 스킵 | 통과 |
| AC-1-7 | tutorial_step Analytics 이벤트 발화 | 통과 |
| AC-1-8 | 기존 유저(v2.x) 데이터 마이그레이션 정상 처리 | 통과 |

## Deferred 항목
없음

## 주요 변경 파일
- `src/server/Services/TutorialService.luau` — 신규 생성 (5단계 튜토리얼 서버 로직)
- `src/client/Controllers/TutorialController.luau` — 신규 생성 (NPC 대화 UI, 단계 진행 표시)

## 다음 Sprint 영향
- PlayerData에 `tutorial_step` 필드가 추가되어 Sprint 2 업그레이드 마이그레이션 패턴의 참조 모델이 됨
- Analytics `tutorial_step` 이벤트 데이터로 온보딩 깔때기 지표 수집 시작

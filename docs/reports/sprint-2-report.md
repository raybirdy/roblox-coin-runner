# Sprint 2 완료 보고서

## 개요
- **Sprint**: 2 — 캐릭터 영구 성장
- **버전**: v3.0
- **PR**: #179
- **커밋**: a21d8c7
- **상태**: 완료

## 목표
UpgradeService에 5종 영구 성장 업그레이드 추가 및 밸런스 조정 (M3)

## 완료 항목
- 5종 영구 성장 업그레이드 구현
  - `base_speed`: 기본 이동 속도 증가
  - `jump`: 점프력 증가
  - `lives`: 최대 목숨 수 증가
  - `skill_cooldown`: 액티브 스킬 쿨다운 감소 (50% 적용)
  - `mini_game_bonus`: 미니게임 보상 배율 증가
- 업그레이드 구매 UI 구현
- 업그레이드별 밸런스 수치 확정
- PlayerData 마이그레이션 (5종 업그레이드 레벨 필드 추가)

## Acceptance Criteria 결과

| AC | 내용 | 결과 |
|----|------|------|
| AC-2-1 | 5종 업그레이드 항목 UI에 표시 | 통과 |
| AC-2-2 | 코인 소비 후 업그레이드 레벨 증가 | 통과 |
| AC-2-3 | base_speed 업그레이드 실제 이동 속도에 반영 | 통과 |
| AC-2-4 | jump 업그레이드 점프력에 반영 | 통과 |
| AC-2-5 | lives 업그레이드 최대 목숨에 반영 | 통과 |
| AC-2-6 | skill_cooldown 업그레이드 쿨다운 50% 감소 반영 | 통과 |
| AC-2-7 | mini_game_bonus 업그레이드 미니게임 보상에 반영 | 통과 |
| AC-2-8 | 기존 유저 데이터 마이그레이션 정상 처리 | 통과 |

## Deferred 항목
없음

## 주요 변경 파일
- `src/server/Services/UpgradeService.luau` — 5종 업그레이드 로직 추가
- `src/shared/Constants/GameConstants.luau` — 업그레이드 최대 레벨, 비용, 배율 상수 추가

## 다음 Sprint 영향
- `skill_cooldown` 업그레이드는 Sprint 5 ActiveSkillService에서 직접 참조하여 쿨다운 감소에 활용됨
- `mini_game_bonus` 업그레이드는 Sprint 3 MiniGameService 보상 계산에 활용됨
- PlayerData 마이그레이션 패턴이 이후 Sprint의 표준 참조 모델로 정착

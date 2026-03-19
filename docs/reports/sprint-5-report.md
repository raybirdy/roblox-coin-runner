# Sprint 5 완료 보고서

## 개요
- **Sprint**: 5 — 스킬/능력 시스템
- **버전**: v3.0
- **PR**: #182
- **커밋**: 93ac435
- **상태**: 완료

## 목표
액티브 스킬 3종(dash, shield, magnet_burst)을 구현하고, 쿨다운 서버 검증 및 skill_cooldown 업그레이드와 연동하여 S2 마일스톤을 완료한다.

## 완료 항목
- `ActiveSkillService` 구현 — 서버 측 스킬 쿨다운 검증, 스킬 효과 적용
- `ActiveSkillController` 구현 — 클라이언트 입력 처리, UI 쿨다운 표시
- dash 스킬 — 전방 순간이동, 무적 판정 프레임 포함
- shield 스킬 — 일정 시간 피격 무효화
- magnet_burst 스킬 — 범위 내 코인 즉시 흡수
- 쿨다운 서버 검증 — 클라이언트 요청 시 서버에서 쿨다운 잔여 시간 재검증
- skill_cooldown 업그레이드 연동 — 업그레이드 레벨에 따라 쿨다운 최대 50% 감소
- 미니게임 중 스킬 비활성화 — GameSession 상태가 `"minigame"`일 때 스킬 사용 차단

## Acceptance Criteria 결과

| AC | 항목 | 결과 |
|----|------|------|
| AC-5-1 | dash 스킬 정상 동작 | 통과 |
| AC-5-2 | shield 스킬 정상 동작 | 통과 |
| AC-5-3 | magnet_burst 스킬 정상 동작 | 통과 |
| AC-5-4 | 서버 쿨다운 검증 (핵 방지) | 통과 |
| AC-5-5 | skill_cooldown 업그레이드 50% 감소 반영 | 통과 |
| AC-5-6 | 미니게임 중 스킬 비활성화 | 통과 |
| AC-5-7 | 클라이언트 UI 쿨다운 표시 정확도 | 통과 |

## Deferred 항목
없음

## 주요 변경 파일
- `src/server/Services/ActiveSkillService.luau` — 스킬 쿨다운 검증, 효과 서버 처리
- `src/client/Controllers/ActiveSkillController.luau` — 스킬 입력 및 UI 쿨다운 표시
- `src/shared/Constants/GameConstants.luau` — 스킬 쿨다운 기본값, 업그레이드 계수 상수 추가

## 다음 Sprint 영향
Sprint 6의 랜덤 이벤트 중 일부(거인 이벤트, 중력반전)는 플레이어 이동에 영향을 미치므로 dash 스킬과 물리 충돌을 검토해야 한다. RandomEventService에서 이벤트 활성화 시 ActiveSkillService에 상태를 전달하는 구조가 필요할 수 있다.

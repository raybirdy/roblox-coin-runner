---
id: ISSUE-016
title: "Pet feverBonus 미적용 + RandomEvent speed_shift 미작동 — 추가 dead store 정리"
category: bug
priority: P2-medium
status: resolved
related_sprint: none
related_ac: none
created: 2026-03-25
resolved: 2026-03-25
---

## 설명
전체 시스템 감사에서 발견된 추가 dead store / 미연결 코드:

### 1. Pet Fever Bonus 미적용
- `PetService:GetFeverBonus()` (line 59-65): 펫별 `feverBonus` 초 반환
- GameManager line 1539 피버 지속 시간 계산: `upgradeBonuses.feverExtend`만 사용, **펫 보너스 미포함**
- 펫 코인/자석 보너스는 정상 적용 중 (GM line 1399, 1416)

### 2. RandomEvent `speed_shift` 미작동
- `session._speedShiftMultiplier = 1.5` 설정 → GameManager 속도 계산에서 안 읽음
- 클라이언트는 파란 틴트만 표시 → 실제 속도 변화 없음

### 3. RandomEvent `giant_mode` 서버측 미완성 (ISSUE-013 보완)
- 클라이언트 스케일링은 부분 작동하나 서버 히트박스 미동기화
- ObstacleService 충돌 판정에 giant 상태 반영 필요

### 4. RandomEvent `gravity_flip` / `fog` dead store 정리
- 클라이언트가 workspace.Gravity / Lighting.FogEnd를 직접 변경하므로 **효과 자체는 작동**
- 서버 세션 플래그는 불필요한 dead store → 정리 또는 서버 권위적 처리로 전환 권장

## 영향 분석
- **관련 파일**:
  - `src/server/Services/PetService.luau` (line 59-65)
  - `src/server/Services/RandomEventService.luau` (lines 116-142)
  - `src/server/Services/GameManager.luau` (line 1539: fever duration, Heartbeat: speed calc)
- **영향 범위**: 펫 시스템 경제 밸런스, 랜덤 이벤트 게임플레이
- **수정 방향**:
  - GM line 1539에 `PetService:GetFeverBonus()` 추가
  - GM Heartbeat 속도 계산에 `session._speedShiftMultiplier` 반영
  - gravity_flip/fog: dead store 제거 또는 서버 권위적 처리 전환

## 해결 방안
Pet feverBonus: 피버 지속시간 계산에 PetService:GetFeverBonus() 추가.
speed_shift: GameManager Heartbeat 속도 계산에 session._speedShiftMultiplier 반영.
gravity_flip/fog: 클라이언트 직접 변경으로 작동 중 — 서버 플래그는 향후 정리 대상.

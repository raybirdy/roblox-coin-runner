---
id: ISSUE-014
title: "액티브 스킬 dash/magnet_burst 미작동 — 서버 플래그 설정만 되고 GameManager 미소비"
category: bug
priority: P1-high
status: open
related_sprint: none
related_ac: none
created: 2026-03-25
resolved: null
---

## 설명
ActiveSkillService의 3종 스킬 중 2종이 미작동:
- **dash**: `session._dashActive=true`, `_dashSpeedMultiplier=3.0` 설정 → GameManager Heartbeat에서 안 읽음 → 속도 변화 없음
- **active_magnet_burst**: `session._magnetBurstActive=true`, `_magnetBurstRadius=35` 설정 → `ConsumeMagnetBurst()` 메서드 존재하나 GameManager가 호출 안 함 → 코인 흡수 안 됨
- **shield**: 정상 작동 (GameManager line 1698에서 `ConsumeShieldHit()` 호출)

플레이어가 업그레이드 비용을 지불하고 스킬을 해금 → 버튼 누르면 UI 피드백은 보이나 **실제 효과 없음**.

## 영향 분석
- **관련 파일**:
  - `src/server/Services/ActiveSkillService.luau` (lines 142-166: 효과 설정, 179-193: dead consumer)
  - `src/server/Services/GameManager.luau` (Heartbeat 속도 계산 / 코인 수집 로직에 미연결)
- **영향 범위**: 유료 콘텐츠 신뢰도 — 구매한 스킬이 작동하지 않음
- **수정 방향**:
  - dash: GameManager Heartbeat에서 `ActiveSkillService:GetDashMultiplier(session)` 호출하여 속도에 반영
  - magnet_burst: GameManager 코인 수집 섹션에서 `ConsumeMagnetBurst(session)` 호출하여 범위 내 코인 즉시 흡수

## 해결 방안
(등록 시점에는 비워둠 — /dev로 수정)

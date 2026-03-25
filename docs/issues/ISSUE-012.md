---
id: ISSUE-012
title: 펫 능동 스킬 시스템 — 패시브 보너스에서 타이밍 액티브 능력으로 전환
category: feature
priority: P2-medium
status: open
related_sprint: none (v3.3+ 백로그)
related_ac: none
created: 2026-03-25
resolved: null
---

## 설명
쿠키런 오븐브레이크 벤치마크: 펫이 고유 능동 스킬을 보유 → 쿠키+펫 조합이 전략적 선택.
현재 Coin Runner 펫은 패시브 % 보너스만 제공 (coinBonus, magnetBonus, feverBonus) → 펫이 단순 장식 수준.

**개선 방향**: 각 펫에 타이밍 기반 액티브 능력 부여
```
강아지   → 15초마다 짧은 자석 발동 (2초)
고양이   → 근처 코인 탐지 시 방향 알림 이펙트
피닉스   → 게임 오버 위기 시 1회 자동 부활
드래곤   → 10초마다 화염 브레스 → 앞 장애물 1개 소각
```
- 펫 레벨업 시 스킬 지속시간/효과 강화 (기존 % 보너스 대신)
- 펫 스킬 아이콘 + 쿨다운 표시 UI 필요

## 영향 분석
- **복잡도**: XL (Extra Large) — 가장 침습적 변경
- **서버**:
  - `PetService.luau`: 대폭 재작성 (패시브→액티브 API 전환)
  - `GameManager.luau` (lines 1399, 1416): 매 프레임 `GetMagnetBonus`/`GetCoinMultiplier` → 타이밍 스킬 활성화 체크로 변경
  - `ObstacleService.luau`: 화염 브레스 → 장애물 파괴 API 필요
  - `PlayerDataService.luau`: 펫 스킬 쿨다운/활성화 시간 저장
- **클라이언트**:
  - `PetController.luau`: 대폭 재작성 (이모지→스킬 아이콘+쿨다운+VFX)
  - `ShopController.luau`: 펫 상점 UI에 스킬 설명 표시
  - `InputController.luau`: 펫 스킬 수동 발동 입력 바인딩 (선택적)
- **상수**: `GameConstants.PETS.LIST` 구조 변경 (coinBonus→skill), `PET_SKILLS` 테이블 신설
- **의존성**:
  - 경제 밸런스 전면 재검토 (영구 패시브→간헐적 액티브로 수익률 곡선 변화)
  - ISSUE-005 (모바일 UI 과부하)와 충돌: 펫 스킬 버튼이 UI 밀도 증가
  - Co-op: 파트너 펫 스킬 공유 여부 설계 결정 필요
  - ActiveSkillService와 펫 스킬 간 쿨다운 시스템 통합/분리 결정

## 해결 방안
(v3.3+ 백로그 — Feature 1~3 안정화 후 진행 권장, 하이브리드 접근 검토: 패시브 유지 + 소규모 액티브 추가)

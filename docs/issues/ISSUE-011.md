---
id: ISSUE-011
title: 캐릭터 고유 스킬 활성화 검증 — 기존 구현의 서버 효과 적용 확인
category: improvement
priority: P1-high
status: open
related_sprint: none (v3.2 후보)
related_ac: none
created: 2026-03-25
resolved: null
---

## 설명
쿠키런 오븐브레이크 벤치마크: 각 쿠키(캐릭터)마다 고유 패시브/액티브 스킬 보유 → "내 캐릭터"에 대한 애착과 전략적 선택.

Coin Runner에는 이미 캐릭터 스킬 시스템이 **80% 구현되어 있음**:
- 6캐릭터 패시브 (hitbox_reduction, magnet_bonus, hit_resist, fever_extend, start_magnet)
- 액티브 스킬 (dash, vortex, shield, sparkle, magnet_field) + 쿨다운/지속시간 정의
- `CharacterService._onSkillUse` + `RemoteEvents.CharacterSkillUse/Activated` 존재

**문제**: `CharacterService._onSkillUse`가 RemoteEvent를 클라이언트에 발송하지만, **서버 GameManager 게임 루프에서 액티브 스킬 효과(dash 무적, vortex 자석, shield 방어 등)를 실제 적용하는 로직이 확인되지 않음** → 잠재적 미완성 코드.

**필요 작업**:
1. GameManager에서 캐릭터 액티브 스킬 효과가 실제 적용되는지 검증
2. 미적용 시 효과 로직 구현 (dash→일시 무적, vortex→범위 자석, shield→피격 흡수)
3. 캐릭터 선택 UI에서 스킬 설명 명확히 표시
4. 클라이언트 VFX (CharacterEffectsController) 보강

## 영향 분석
- **복잡도**: S (Small) — 인프라 80% 완성, 검증 + 폴리싱
- **서버**:
  - `GameManager.luau`: 액티브 스킬 효과 적용 로직 검증/추가
  - `CharacterService.luau`: `_onSkillUse` 효과 체인 검증
  - `ActiveSkillService.luau`: 런 스킬과 캐릭터 스킬 간 충돌 여부 확인
- **클라이언트**:
  - `CharacterSelectController.luau`: 스킬 설명 UI 보강
  - `CharacterEffectsController.luau`: 각 스킬 VFX 구현 확인
- **의존성**: ActiveSkillService와 캐릭터 스킬 간 슬롯 공유 여부 설계 결정 필요

## 해결 방안
(Sprint 편입 시 /dev로 검증 및 구현)

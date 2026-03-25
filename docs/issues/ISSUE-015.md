---
id: ISSUE-015
title: "캐릭터 패시브 5종 전체 미작동 — CharacterService가 GameManager에 연결되지 않음"
category: bug
priority: P1-high
status: resolved
related_sprint: none
related_ac: none
created: 2026-03-25
resolved: 2026-03-25
---

## 설명
CharacterService에 정의된 5종 캐릭터 패시브가 **전부 dead code**:
- `hitbox_reduction` (10%): 장애물 충돌 판정에 미적용
- `magnet_bonus` (+3 studs): 자석 반경 계산에 미적용
- `hit_resist` (50%): 피격 판정에 미적용
- `fever_extend` (+2s): 피버 지속 시간에 미적용
- `start_magnet` (5s): 게임 시작 시 자석 발동에 미적용

**GameManager에서 CharacterService를 import조차 하지 않음** — getter 메서드(GetMagnetBonus, GetFeverExtend, HasHitResist 등)가 존재하나 호출처 없음.

플레이어가 코인/젬으로 캐릭터를 구매했으나 패시브 효과 없음 → **유료 콘텐츠 신뢰도 문제**.

## 영향 분석
- **관련 파일**:
  - `src/server/Services/CharacterService.luau` (lines 74-118: dead getter 메서드)
  - `src/server/Services/GameManager.luau`:
    - line 1399: 자석 반경 → `CharacterService:GetMagnetBonus()` 추가 필요
    - line 1539: 피버 시간 → `CharacterService:GetFeverExtend()` 추가 필요
    - line ~1675: 피격 판정 → `CharacterService:GetHitResistChance()` 추가 필요
    - line ~480: 게임 시작 → `CharacterService:GetStartMagnetDuration()` 추가 필요
    - 장애물 충돌 → hitbox_reduction 적용 필요
- **영향 범위**: 캐릭터 시스템 전체, 경제 밸런스
- **수정 방향**: GameManager에서 CharacterService import 후 각 통합점에 getter 호출 추가

## 해결 방안
GameManager에 CharacterService import 추가.
hitbox_reduction: 장애물 충돌 시 effectiveMini로 축소 히트박스 적용.
magnet_bonus: 자석 반경 계산에 CharacterService:GetMagnetBonus() 추가.
hit_resist: 피격 체인에 확률적 저항 판정 추가.
fever_extend: 피버 지속시간에 CharacterService:GetFeverExtend() 추가.
start_magnet: 게임 시작 시 PowerupService:ActivatePowerup('Magnet') 발동.

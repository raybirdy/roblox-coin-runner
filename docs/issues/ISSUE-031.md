---
id: ISSUE-031
title: 피버 발동 빈도 과다 — 희귀성 하락으로 게임 재미 반감
category: improvement
priority: P2-medium
status: resolved
related_sprint: none
related_ac: none
created: 2026-04-06
resolved: 2026-04-06
---

## 설명

피버(Fever)가 너무 자주 발동되어 게임의 긴장감과 성취감이 희석됨.
피버는 "특별한 순간"으로 플레이어가 기대해야 하는데,
현재는 매 런마다 여러 번 발동되어 일상적인 상태처럼 느껴짐.

## 현재 수치 (GameConstants.luau)

| 항목 | 현재값 | 원래값 | 변경 이유 |
|------|--------|--------|-----------|
| FEVER.COMBO_THRESHOLD | 30 | 30 | 유지 |
| FEVER.COOLDOWN | 12초 | 15초 | "저연령층 피버 경험 빈도 향상" 목적으로 하향 |
| MINI_FEVER.COMBO_THRESHOLD | 15 | — | 저연령 도달 가능하게 설정 |
| MINI_FEVER.COOLDOWN | 10초 | — | — |

**발동 빈도 추정 (현재):**
- 피버 사이클: 6s(지속) + 12s(쿨타임) = 18s
- 2분 런 기준: 최대 6~7회 발동 가능
- 미니 피버까지 포함하면 거의 "상시 피버" 상태

## 영향 분석

### 관련 파일
- `src/shared/Constants/GameConstants.luau:1164` — FEVER 상수 (COMBO_THRESHOLD, DURATION, COOLDOWN)
- `src/shared/Constants/GameConstants.luau:1175` — MINI_FEVER 상수
- `src/server/Services/GameManager.luau:1560~1590` — 피버/미니피버 발동 체크 로직
- `src/server/Services/GameManager.luau:1664` — feverCooldown 계산 (`fever_extend` 스킬 연동)
- `src/client/Controllers/FeverController.luau` — 클라이언트 피버 연출

### 피버 희석 메커니즘
- 코인이 밀집 배치된 구간에서 30콤보는 수초 내 달성 가능
- `fever_boost` 스킬 보유 시 임계값이 30 → 23으로 추가 감소
- MINI_FEVER까지 합산하면 실질적으로 쿨타임 없이 보너스 상태 유지

### 파급 범위 (변경 시)
- GameConstants 상수 변경만으로 처리 가능 (서버/클라이언트 코드 변경 불필요)
- `fever_charge` 런 스킬 (Lv20 보상) 가치에 영향 — 추가 조정 필요 가능성

## 해결 방안 후보

### Option A: 쿨타임 원복 + 콤보 임계값 상향 (권장)
```
FEVER.COMBO_THRESHOLD: 30 → 40
FEVER.COOLDOWN: 12 → 20
MINI_FEVER.COMBO_THRESHOLD: 15 → 20
MINI_FEVER.COOLDOWN: 10 → 15
```
- 2분 런 기준 피버 3~4회로 제한
- 미니 피버가 "워밍업 → 피버"의 흐름 역할

### Option B: 게이지 방식 전환 (중장기)
- 콤보 카운트 대신 "수집 거리/점수 기반 게이지"로 변경
- 플레이 기술에 무관하게 일정 간격으로 발동 → 예측 가능한 리듬 제공
- 코드 변경 범위 큼 (GameManager 전면 수정)

### Option C: 피버 등급제 도입 (중장기)
- 1단계(미니) → 2단계(피버) → 3단계(슈퍼피버)를 단계적으로 달성
- 각 단계별 콤보 조건: 20 → 50 → 100
- 희귀성 확보 + 성취감 강화

## 참고

- SUPER_FEVER는 `GameConstants.luau:1368`에 별도 정의되어 있음 (현재 발동 조건 미확인)
- `feverBonus` 필드가 캐릭터 스탯에 있음 (0.05~0.10) — 변경 시 영향 없음

---
id: ISSUE-033
title: 코인 종류 확장 — 특수 효과 코인 추가
category: feature
priority: P2-medium
status: in-progress
related_sprint: none
related_ac: none
created: 2026-04-06
resolved: null
---

## 설명

현재 코인은 Bronze / Silver / Gold / Diamond 4종 (점수 배율 차이만 존재).
특수 효과를 가진 코인을 추가해 수집 전략과 게임 내 긴장감을 높이고 싶음.

코인 종류가 다양해지면:
- 플레이어가 "저 코인은 꼭 잡아야 해" / "저건 뭐지?" 반응 유발
- Fever 시스템과 시너지 (특수 코인이 Fever 게이지에 더 기여)
- 코인 도형 패턴(IDEA-008, v3.1 Sprint 7)과 결합해 시각적 다양성 극대화

## 제안 코인 종류

| 종류 | 색상 | 효과 | 희귀도 |
|------|------|------|--------|
| **Star** ⭐ | 노랑+반짝 | 콤보 +5 즉시 (Fever 촉진) | Uncommon |
| **Magnet** 🧲 | 파랑 | 3초간 자동수집 범위 2× | Rare |
| **Rainbow** 🌈 | 무지개 순환 | 2초간 수집 코인 2× 점수 | Rare |
| **Bomb** 💣 | 빨강+검정 | 주변 반경 10 studs 코인 전부 흡수 | Epic |
| **Crystal** 💎 | 청록+투명 | 존별 특화 통화 (상점 연계 예정) | Rare |

## 영향 분석

### 관련 파일
- `src/server/Services/CoinService.luau` — 코인 생성 로직, 타입 정의, 수집 처리
- `src/shared/Constants/GameConstants.luau` — `COIN.TYPES`, 점수 배율, 자석 범위 상수
- `src/server/Services/GameManager.luau` — 수집 이벤트 처리 (콤보, 점수 계산)
- `src/client/Controllers/PlayerController.luau` — 자석 효과 클라이언트 연출
- `src/client/Controllers/FeverController.luau` — Star 코인 → Fever 게이지 즉시 증가 연출

### 구현 난이도
- **Star**: 쉬움 — 수집 시 콤보 +5 처리만 추가
- **Magnet**: 중간 — 자석 효과 이미 구현됨(`magnetBonus` 스탯), 임시 2× 확대 처리
- **Rainbow**: 중간 — 수집 점수 배율 임시 변경 (서버 상태 플래그)
- **Bomb**: 어려움 — 범위 내 코인 탐지 + 일괄 흡수 연출 (새 로직)
- **Crystal**: 어려움 — 별도 통화 시스템 + 상점 연계 (중장기)

### 스폰 확률 설계 (안)
```
일반 코인    : 75%
Star        : 12%
Magnet      : 6%
Rainbow     : 5%
Bomb        : 2%
Crystal     : 0% (구현 후 활성화)
```

### 파급 범위
- CoinService 타입 분기 추가: 중간 수준 변경
- GameManager 수집 이벤트: 특수 효과 핸들러 추가 필요
- 클라이언트 연출: 각 타입별 파티클/사운드 (중간)

## 참고

- IDEA-008 (코인 도형 패턴 5종)과 결합: 특수 코인은 고유 도형 패턴 전용 사용 가능
- `magnetBonus` 스탯(캐릭터)은 기본 자석 범위. Magnet 코인은 임시 2× 중첩
- Crystal은 추후 `/game-economy` 스킬과 연동해 경제 설계 필요 — 단독 구현 비권장

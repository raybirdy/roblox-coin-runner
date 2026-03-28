---
id: ISSUE-019
title: 자석 파워업 시 코인 시각적 흡인 효과 없음 — 코인이 캐릭터를 따라오지 않음
category: improvement
priority: P1-high
status: open
related_sprint: none
related_ac: none
created: 2026-03-28
resolved: null
---

## 설명
자석(Magnet) 파워업 활성화 시 코인이 캐릭터를 향해 날아오는 시각 효과가 없음.
현재 구현은 수집 반경만 확장(15→15 studs)하여 범위 내 코인을 "조용히" 수집함.
유저 기대: 러너 게임 표준인 "코인이 캐릭터를 향해 빨려오는" 시각 효과.

## 영향 분석

### 근본 원인
자석 구현이 **수집 반경 확장 전용**임:
- `PowerupService:GetMagnetRadius()` → 15 studs (line 234)
- `CoinService:CheckCoinCollection` → magnetRadius 내 즉시 수집 (구형 거리, line 873)
- 코인 위치 이동(attraction) 로직 없음 (서버/클라이언트 모두)

### 관련 파일
- `src/server/Services/PowerupService.luau` — 자석 상태 관리 (line 196-237)
- `src/server/Services/CoinService.luau` — 수집 판정 (line 853-893)
- `src/server/Services/GameManager.luau` — 자석 반경 합산 (line 1413)
- `src/client/Controllers/CoinController.luau` — 코인 비주얼 (흡인 로직 없음)
- `src/shared/Constants/GameConstants.luau` — `MAGNET_RADIUS = 15` (line 239)

### 영향 범위
- 자석은 35% 스폰율의 주요 파워업 → 유저 체감 만족도 핵심
- 현재 "자석 먹어도 아무 효과가 없는 것 같다"는 인상
- ISSUE-018, ISSUE-020과 결합 시 코인 수집 전반의 체감 문제 악화

## 해결 방안
(처리 시 채움)
- 서버: magnetRadius 내 코인을 매 프레임 캐릭터 방향으로 이동 (Lerp)
- 클라이언트: 코인 모델 → 캐릭터 방향 트윈 애니메이션 + 잔상/파티클 효과

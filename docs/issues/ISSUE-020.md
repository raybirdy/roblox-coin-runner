---
id: ISSUE-020
title: Fever 모드 시 코인이 수집 전에 사라짐 — 속도 증가 + 청크 삭제 경합
category: bug
priority: P1-high
status: resolved
related_sprint: none
related_ac: none
created: 2026-03-28
resolved: 2026-03-28
---

## 설명
Fever/SuperFever 모드 활성화 시 코인이 캐릭터가 먹기 전에 사라진다.
Fever는 숙련 플레이의 보상인데, 코인이 사라지면 보상 체감이 무의미해짐.

## 영향 분석

### 근본 원인
ISSUE-018과 동일한 근본 원인(청크 삭제 시 코인 동반 파괴)이 Fever 속도 증가로 악화됨:

1. **Fever 속도 부스트**: 일반 52 studs/s → Fever 78 studs/s (1.5x), SuperFever 93.6 studs/s (1.8x)
2. **청크 통과 시간 단축**: 80-stud 청크를 ~1초만에 통과 → 코인 수집 기회 감소
3. **자석 반경 증가 역설**: Fever 자석 30 studs, SuperFever 40 studs로 확장되지만, 청크 경계의 코인은 청크 파괴로 반경 진입 전에 소멸
4. **시각적 흡인 부재** (ISSUE-019): 자석이 코인을 조용히 수집하므로, 유저는 "코인이 사라졌다"고 인식 (실제로는 일부가 수집됐을 수 있음)

### 관련 파일
- `src/server/Services/GameManager.luau` — Fever 속도 배율 (line 1705-1706)
- `src/server/Services/CoinService.luau` — 수집 판정 (line 853-893)
- `src/server/Services/ChunkService.luau` — 청크 정리 (line 640-661)
- `src/shared/Constants/GameConstants.luau` — `FEVER.SPEED_BOOST = 1.5`, `FEVER.MAGNET_RADIUS = 30`, `SUPER_FEVER.SPEED_BOOST = 1.8`, `SUPER_FEVER.MAGNET_RADIUS = 40`

### 영향 범위
- Fever 보상 루프 완전 훼손 (스킬 보상 → 코인 대량 획득 기대 → 실제로 사라짐)
- ISSUE-018 (일반 코인 사라짐) + ISSUE-019 (자석 흡인 없음)과 결합 시 핵심 게임플레이 만족도 하락

## 해결 방안
- ISSUE-018 해결로 기본 해결 (청크 삭제 전 코인 재부모화)
- ISSUE-019 해결로 Fever 자석 흡인 시각 효과 추가
- 거대 코인 Parent를 workspace로 변경하여 청크 삭제 영향 제거
- 커밋: 6c73342

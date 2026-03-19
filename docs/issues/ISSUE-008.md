---
id: ISSUE-008
title: 메인 러너 장애물 고도화 — 종류/난이도/배치 패턴 개선
category: improvement
priority: P1-high
status: open
related_sprint: none (v3.1+ 후보)
related_ac: none
created: 2026-03-19
resolved: null
---

## 설명
메인 달리기 게임의 장애물 시스템 전반적 고도화 필요:
1. **종류 단순**: 새로운 장애물 타입 추가 필요
2. **난이도 곡선**: 밸런스 조정 (너무 쉽거나 어려움)
3. **배치 패턴 반복**: 다양한 배치 조합 부족

## 영향 분석
- **관련 파일**:
  - `src/server/Services/ObstacleService.luau` — 장애물 생성/배치 로직
  - `src/server/Services/ChunkService.luau` — 청크 내 장애물 스폰 위치
  - `src/server/Services/ProceduralChunkGenerator.luau` — 절차적 청크 생성
  - `src/shared/Constants/GameConstants.luau` — 장애물 타입/난이도 상수
- **영향 범위**: 코어 게임플레이 — 리텐션/재미에 직결
- **의존성**: Zone 시스템, 난이도 스케일링과 연동

## 해결 방안
(v3.1 Sprint 또는 v3.2에서 구현 — /prd update + /draft update 필요)
- 장애물 신규 타입 설계 (움직이는 장애물, 타이밍 장애물 등)
- Zone별 난이도 곡선 재설계
- 절차적 배치 패턴 다양화 (리듬 패턴, 스킬 루트 등)

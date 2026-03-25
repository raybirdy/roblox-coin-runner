---
id: ISSUE-008
title: 메인 러너 장애물 고도화 — 종류/난이도/배치 패턴 개선
category: improvement
priority: P1-high
status: resolved
related_sprint: v3.1 Sprint 1
related_ac: none
created: 2026-03-19
resolved: 2026-03-25
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

## 해결 내역 (2026-03-25)

### 1. 신규 장애물 3종 추가
- **PendulumLog** (Zone 3+, Hard): 상하 스윙 통나무, 타이밍 맞춰 아래로 통과
- **LaserBeam** (Zone 4+, Hard): On/Off 토글 레이저, Off 구간에 통과 또는 점프/슬라이드
- **FallingRock** (Zone 3+, Normal/Hard): 바닥 경고 그림자 후 바위 낙하, 위치 회피

### 2. 난이도 곡선 개선
- 기존 3단계(60s/120s/180s+) → 5단계(30s/60s/90s/120s/180s/240s+) 존 연동
- Zone 2 초반(60~90s) Hard 비율 완화 (20%→15%)
- Zone 4+(180s+) 구간 세분화, Zone 5(240s+) 최고 난이도 47%

### 3. 패턴 다양화
- Normal 콤보 +1 (rock_tunnel), Hard 콤보 +3 (pendulum_barrel, laser_wall, rock_spike)
- Normal 리듬 +1 (rock_then_jump), Hard 리듬 +3 (pendulum_gap_wall, laser_slide_rock, rock_barrel)
- 스킬 루트 +3종 (PendulumLog, LaserBeam, FallingRock 보상 코인 위치)

### 변경 파일
- `src/shared/Constants/GameConstants.luau` — 신규 장애물 상수, 패턴, 난이도 테이블
- `src/server/Services/ObstacleService.luau` — 스폰/충돌/니어미스 로직, 존 필터링

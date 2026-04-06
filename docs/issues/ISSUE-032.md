---
id: ISSUE-032
title: 코인-장애물 시각적 구분 어려움 + 게임 단조로움
category: improvement
priority: P2-medium
status: open
related_sprint: none
related_ac: none
created: 2026-04-06
resolved: null
---

## 설명

맵 고도화(v3.1)로 레이아웃과 장식은 개선되었으나,
코인과 장애물의 시각적 구분이 여전히 부족하고 게임 흐름이 단조롭게 느껴짐.

- 코인(작은 2D 링 파트)과 장애물(SmoothPlastic/Concrete/Metal 블록)이
  빠른 속도에서 순간적으로 구분하기 어려움
- 장애물에 "피해야 한다"는 직관적 시각 신호(위협감)가 부족
- 구간마다 비슷한 색조·재질이 반복되어 자극이 단조로워짐

## 영향 분석

### 관련 파일
- `src/server/Services/ChunkService.luau` — 장애물 재질/색상 정의 (`Obstacle` 파트 생성)
- `src/server/Services/ProceduralChunkGenerator.luau` — `_createObstacle()`, 재질·BrickColor 설정
- `src/server/Services/CoinService.luau` — 코인 파트(링) 색상/크기 정의
- `src/shared/Constants/GameConstants.luau` — COIN 상수 (색상·크기)
- `src/client/Controllers/FeverController.luau` — 피버 중 코인 연출

### 현재 코인 시각
- 타입별 색상: Silver(192,192,192) / Gold(255,215,0) / Diamond(120,200,255) / Bronze(205,127,50)
- 형태: BillboardGui 기반 링 또는 얇은 Part 2D 디스크 (zone별 패턴 5종)
- 파티클/글로우: 없거나 최소

### 현재 장애물 시각
- 재질: Concrete, Metal, SmoothPlastic
- 색상: 회색·짙은 중립 계열
- 파티클/경고: 없음

### 파급 범위
- 코인 글로우/빌보드 추가: CoinService + 클라이언트 렌더 (중간)
- 장애물 위협 연출 추가: ProceduralChunkGenerator (소~중간)
- 존별 색조 변화 강화: ChunkService + ScenarioConstants (소)

## 해결 방안

### 코인 가시성 강화
- 코인마다 Highlight 인스턴스(FillTransparency=1, OutlineColor=Gold) 추가 → 항상 외곽 빛남
- PointLight 약하게 부착 (Brightness=0.5, Range=8) — 어두운 존에서 특히 효과
- BillboardGui 크기 소폭 확대 or 회전 애니메이션 추가 (눈길 잡기)

### 장애물 위협 연출
- 장애물 파트에 빨간/주황 경고 스트라이프 Decal 또는 Texture 추가
- `Neon` 재질의 경고등 파트 소형 부착 (깜빡임 효과 TweenService)
- 이동 장애물(RotatingBar/FallingDebris)에 SpawnParticle(연기/불꽃) 추가

### 게임 단조로움 완화
- 존별 환경 조명 색온도 강화 (Zone1=따뜻 / Zone3=차가움 / Zone5=보라)
- 장거리 무사 통과 시 "Clean Run!" 칭찬 텍스트 팝업 (달성감 부여)
- 코인 수집 시 간헐적 소형 파티클 버스트 (10개 중 1개 확률)

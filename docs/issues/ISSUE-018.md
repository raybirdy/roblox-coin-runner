---
id: ISSUE-018
title: 코인이 캐릭터에 닿기 전에 화면에서 사라짐 — 청크 삭제 시 코인 동반 파괴
category: bug
priority: P1-high
status: resolved
related_sprint: none
related_ac: none
created: 2026-03-28
resolved: 2026-03-28
---

## 설명
게임 러닝 중 코인이 캐릭터에 닿기 전에 화면에서 사라진다.
코인이 수집되지 않고 사라지므로 플레이 재미가 크게 저하됨.

## 영향 분석

### 근본 원인
1. **청크 기반 코인 파괴**: `CoinService`에서 일부 코인은 `chunk` 모델의 자식으로 생성됨 (`coinModel.Parent = chunk`). `ChunkService:CleanupOldChunks()`가 `DELETE_DISTANCE = 100` 뒤의 청크를 삭제하면 코인도 함께 파괴됨.
2. **수집 판정 빈틈**: 일반 수집 시 `delta.X * 2` 가중치로 전방 수집 범위가 ~1.5 studs. 최대 속도 52 studs/s 기준 ~29ms (1 서버 프레임)로, 서버 틱 타이밍에 따라 코인을 "통과"할 수 있음.

### 관련 파일
- `src/server/Services/CoinService.luau` — 코인 생성 (line 802, 969) + 수집 판정 (line 853-893)
- `src/server/Services/ChunkService.luau` — 청크 정리 (line 640-661, `DELETE_DISTANCE = 100`)
- `src/shared/Constants/GameConstants.luau` — `CHUNK.LENGTH = 80`, `CHUNK.DELETE_DISTANCE = 100`

### 영향 범위
- 코어 게임플레이 루프 (코인 수집 만족감) 직접 저하
- ISSUE-020 (Fever 시 코인 사라짐)과 동일 근본 원인

## 해결 방안
- ChunkService: 청크 삭제 전 SUPER_FEVER.MAGNET_RADIUS + 10 범위 내 코인을 workspace로 재부모화
- CoinService: 전방 수집 히트박스 X*2 → X*1.5로 완화 (유효 범위 ~1.5 → ~2 studs)
- CoinService: 거대 코인 Parent를 chunk → workspace로 변경
- 커밋: 6c73342

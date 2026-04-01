---
id: IDEA-003
title: 2층 분기 맵 (Dual-Floor Sections)
origin: feature
status: selected
created: 2026-04-01
---

## 아이디어
맵 중간 간헐적으로 2층 구간 등장. 플레이어가 점프로 2층 발판에 올라가 달리다가
플랫폼 끝에서 자동 낙하. 쿠키런 오븐브레이크/슈퍼마리오 스타일.

## 해결하는 문제
맵이 단일 레인이라 패턴이 단조로움. 수직 이동으로 게임 깊이 대폭 향상.

## 타겟 사용자
전체 플레이어 (30초+ 이후 등장)

## 평가
- 사용자 가치: ⭐⭐⭐⭐
- 구현 난이도: 🟡 M (1 Sprint)
- 리스크: 중간 (카메라 Y 팔로우 조정 필요)

## 구현 포인트
- ProceduralChunkGenerator: _createDualFloor() 신규 메서드
  - 1층 Y=0, 2층 Y=10 studs
  - 80 studs 청크 중 60 studs만 2층 유지 → 끝에서 자동 낙하
  - 진입: 2 studs 계단(단차), CanCollide=true
- ChunkService: dual_floor 청크 선택 로직 (30s+, Easy/Normal, ~10% 확률)
- CoinService: 2층에만 코인 집중 배치
- ObstacleService: dual_floor 청크 내 장애물 없음 (Bonus 스타일)
- CameraController: Y 소프트 팔로우 (CAMERA_HEIGHT += characterY * 0.3)
- GameConstants: DUAL_FLOOR 상수 추가

## MVP 범위 (1 Sprint)
- 장애물 없는 2층 보너스 청크
- 점프 진입 + 끝에서 낙하
- 카메라 Y 팔로우
- 출현 조건 (30s+, 10%)

## 다음 행동
/dev IDEA-003 → v3.1 Sprint 1 핵심 AC

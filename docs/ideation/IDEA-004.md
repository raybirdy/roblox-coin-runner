---
id: IDEA-004
title: 이동 장애물 고도화 (2종 추가)
origin: feature
status: selected
created: 2026-04-01
---

## 아이디어
현재 이동 플랫폼 외에 회전하는 벽(Rotating Bar)과 낙하 잔해(Falling Debris) 2종 추가.
Hard 구간 전용으로 숙련도 ceiling 향상.

## 해결하는 문제
Hard 구간 장애물 패턴이 단조로움. 스킬 상한선 부재.

## 타겟 사용자
중급 이상 플레이어

## 평가
- 사용자 가치: ⭐⭐⭐
- 구현 난이도: 🟡 M (3-5일)
- 리스크: 중간 (6세 이하 과도하게 어려울 수 있음)

## 구현 포인트
- ObstacleService: rotating_bar, falling_debris 타입 추가
- ProceduralChunkGenerator: Hard 패턴 테이블에 2종 추가
- 서버 TweenService on BasePart (네트워크 복제됨)
- 느린 회전 속도 (1.5s 1사이클), 밝은 경고색
- ACTION_HINT_RATES에 등록

## 다음 행동
/dev IDEA-004 → v3.1 Sprint 2 AC

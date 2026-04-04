---
id: IDEA-010
title: Obstacle-Coin Co-Design — 장애물-코인 세트 설계
origin: feature
status: selected
created: 2026-04-04
---

## 아이디어
EncounterTemplate{obstacles, coins} 구조로 장애물과 코인을 한 세트로 배치.
장애물 성공 → 보상 코인의 학습 루프 형성.

## 해결하는 문제
현재 장애물/코인이 독립 배치되어 "이 장애물 넘으면 이 보상" 관계가 없음.

## 타겟 사용자
전체 플레이어 — 공정성 체감과 숙련도 향상 동기

## 평가
- 사용자 가치: ⭐⭐⭐
- 구현 난이도: 🟡
- 리스크: 중간 (ObstacleService + CoinService 인터페이스 변경)

## 다음 행동
/dev IDEA-010 (EncounterTemplate 시스템 구현)

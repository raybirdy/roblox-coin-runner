---
id: IDEA-012
title: Chunk Transition Polish — 청크 연결부 폴리싱
origin: feature
status: selected
created: 2026-04-04
---

## 아이디어
경사로를 베지어 곡선 근사(3~5 Part)로 교체, 구간 전환점에 미니 아치/게이트 자동 생성.

## 해결하는 문제
현재 청크 경계가 직각 이음새로 거칠게 보임. CR처럼 부드러운 지형 전환 필요.

## 타겟 사용자
전체 플레이어 — 완성도 체감

## 평가
- 사용자 가치: ⭐⭐
- 구현 난이도: 🟡
- 리스크: 낮음~중간

## 다음 행동
/dev IDEA-012 (CurvedRamp + TransitionGate 구현)

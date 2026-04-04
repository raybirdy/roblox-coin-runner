---
id: IDEA-009
title: Decorative Prop System — 장식 프롭 밀도
origin: feature
status: selected
created: 2026-04-04
---

## 아이디어
zone 테마별 PROP_PALETTE (5~8종 프롭) 추가, 청크당 0~6개 CanCollide=false 장식 프롭 자동 배치.

## 해결하는 문제
현재 SideRail+FloorLine만 있어 화면이 비어 보임. CR처럼 경로 양쪽이 시각적으로 풍부해야 완성도 체감.

## 타겟 사용자
전체 플레이어 — 첫 인상 품질과 리텐션에 직결

## 평가
- 사용자 가치: ⭐⭐⭐
- 구현 난이도: 🟢
- 리스크: 낮음 (CanCollide=false, 게임 로직 영향 없음)

## 다음 행동
/dev IDEA-009 (ProceduralChunkGenerator 장식 확장)

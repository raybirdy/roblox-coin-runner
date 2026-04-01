---
id: IDEA-005
title: 챕터 연동 맵 테마
origin: feature
status: selected
created: 2026-04-01
---

## 아이디어
플레이어가 진행 중인 챕터(숲/도시/사막/설원/바다 등)에 맞춰 맵 바닥/장애물 색상이 변경됨.
현재 ScenarioConstants.CHAPTER_THEMES의 bgColor/accentColor를 청크 생성에 연동.

## 해결하는 문제
챕터 진행과 맵 비주얼이 무관. 스토리-맵 일체감 부재.

## 타겟 사용자
챕터 2+ 도달 플레이어

## 평가
- 사용자 가치: ⭐⭐⭐
- 구현 난이도: 🟡 M (3-5일)
- 리스크: Zone 테마와 충돌 가능 (오버레이 방식으로 해결)

## 구현 포인트
- ScenarioService → GameManager → ChunkService로 activeChapterId 전달
- ProceduralChunkGenerator.Generate()에 chapterTheme 파라미터 추가
- Zone 테마 우선, 챕터 accentColor를 바닥 엣지/레일에 오버레이
- 50가지 조합 피하기 위해 tint 방식 채택

## 다음 행동
/dev IDEA-005 → v3.2 Sprint 편입

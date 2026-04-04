---
id: IDEA-011
title: Segment Grammar Engine — 세그먼트 문법 엔진
origin: feature
status: selected
created: 2026-04-04
---

## 아이디어
ChunkService의 독립 난이도 선택을 "Phrase" 큐로 교체.
2~5청크를 하나의 문장(상승→점프갭→착지→보상)으로 사전 계획하여 리듬감 형성.

## 해결하는 문제
매 청크 독립 난이도 선택으로 "설계된 느낌" 없음. CR처럼 예측 가능한 리듬이 필요.

## 타겟 사용자
전체 플레이어 — 특히 재플레이 동기와 숙련도 체감

## 평가
- 사용자 가치: ⭐⭐⭐
- 구현 난이도: 🟡
- 리스크: 중간 (ChunkService 구조 변경, 기존 breathing/mercy 시스템 호환)

## 다음 행동
/dev IDEA-011 (PhraseGenerator 구현)

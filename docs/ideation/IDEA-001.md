---
id: IDEA-001
title: 존 전환 시각 연출 강화
origin: feature
status: selected
created: 2026-04-01
---

## 아이디어
60초마다 zone이 바뀔 때 화면 플래시, 컬러 틴트 오버레이, 크게 바운스 인 되는 배너로 극적 연출.
현재 ZoneController의 조용한 전환을 체감 가능한 이정표로 만든다.

## 해결하는 문제
현재 zone 전환이 너무 조용해서 진행감이 약함. 6-12세 타겟에게 "성취" 느낌을 줘야 함.

## 타겟 사용자
전체 플레이어

## 평가
- 사용자 가치: ⭐⭐⭐
- 구현 난이도: 🟢 S (1-2일)
- 리스크: 낮음

## 구현 포인트
- ZoneController:TransitionToZone() 확장
- 0.3s 풀스크린 컬러 플래시 (zone skyAmbient 색상)
- ZoneLabel 스케일 바운스 애니메이션 (Back EasingStyle)
- CameraController shake 연동 (이미 존재)

## 다음 행동
/dev IDEA-001 → Sprint 편입

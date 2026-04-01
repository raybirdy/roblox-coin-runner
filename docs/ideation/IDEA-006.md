---
id: IDEA-006
title: 보스런 전용 맵 스타일
origin: feature
status: selected
created: 2026-04-01
---

## 아이디어
보스런 진입 시 맵이 다른 분위기로 변경. MVP: 조명 필터(붉은 틴트) + 안개 + 보스 체력바.
대규모 새 청크 생성 없이 기존 시스템 재활용.

## 해결하는 문제
보스런이 일반 게임과 시각적으로 동일해 긴장감 없음.

## 타겟 사용자
챕터 완료 플레이어

## 평가
- 사용자 가치: ⭐⭐⭐
- 구현 난이도: 🟢 S (MVP) / 🔴 L (전용 청크)
- 리스크: 낮음 (MVP 기준)

## 구현 포인트 (MVP)
- BossRunController (클라이언트 신규): 보스런 시작/종료 이벤트 수신
- Lighting 틴트: 붉은/어두운 분위기 (ColorCorrectionEffect)
- FogEnd 감소: 가시거리 축소로 긴장감
- 보스 체력바 UI: 점수 기반 (targetScore 달성률)
- 미니게임 활성화 후 확장

## 다음 행동
/dev IDEA-006 → v3.2 Sprint 편입 (보스런 활성화 연계)

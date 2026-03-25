---
id: ISSUE-009
title: 콤보 배율 실시간 상승 시스템 — 마일스톤 방식에서 연속 배율로 전환
category: improvement
priority: P1-high
status: resolved
related_sprint: none (v3.2 후보)
related_ac: none
created: 2026-03-25
resolved: 2026-03-25
---

## 설명
쿠키런 오븐브레이크 벤치마크: 연속 수집 시 배율이 실시간 상승하여 "끊지 않아야 한다"는 긴장감 제공.
현재 Coin Runner는 마일스톤 방식(10콤보 +10, 30콤보 +30, 50콤보 +50)으로 콤보 피드백이 약함.

**개선 방향**: 연속 배율 시스템 도입
```
콤보 0~4:   x1.0
콤보 5~14:  x1.5
콤보 15~29: x2.0
콤보 30~49: x3.0
콤보 50+:   x5.0
장애물 피격: 콤보 리셋 + 배율 초기화
```
- 배율 상승 시 화면 테두리 글로우/색상 변화로 시각적 피드백
- Fever 시스템과 연동 (콤보 배율이 Fever 게이지 충전 속도에 영향)

## 영향 분석
- **복잡도**: M (Medium)
- **서버**:
  - `GameManager.luau` (lines 1466-1582): 콤보 마일스톤 로직 → 연속 배율 계산으로 교체
  - `GameManager.luau` (lines 1412-1427): coinMultiplier 체인에 콤보 배율 통합
  - `UpgradeService.luau` (line 104): combo_buffer 업그레이드 의미 변경 (타임아웃→배율 감쇠)
  - `CoopMatchService.luau` (line 189): 공유 콤보에 배율 정보 추가
- **클라이언트**:
  - `FeverController.luau` (line 374): 배율 티어 표시 추가
  - `CoinController.luau` (lines 241-257): 오디오 피치를 배율에 매핑
  - `UIController.luau` (line 1156): 게임오버 화면에 최고 배율 표시
- **상수**: `GameConstants.SCORE.COMBO_*_BONUS` 제거, `COMBO_MULTIPLIER` 테이블 신설
- **의존성**: Fever 임계값 재밸런싱, BattlePass XP `COMBO_10` 재설계, 일일 챌린지 `reach_combo` 목표 조정

## 해결 방안
GameConstants에 COMBO_MULTIPLIER 테이블 추가 (5/15/30/50 콤보 → 1.5x/2x/3x/5x). GameManager 코인 배율에 session.comboMultiplier 반영. 피격 시 콤보 리셋 + 배율 초기화. FeverGaugeUpdate에 comboMultiplier 포함.

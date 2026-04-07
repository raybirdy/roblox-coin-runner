---
id: IDEA-014
title: v3.2 "Feel" 패키지 — 조작감 + 최소 맵 게임성
origin: feature
status: selected
created: 2026-04-07
---

## 아이디어
v3.2는 "재미의 본질 복구" 버전. 시각 폴리싱(v3.1)에서 조작감/텐션/맵 의미로 축 전환.

## 해결하는 문제
- "조작감이 없다" — 피드백 레이어 부재
- "단조롭다" — 긴장-이완 루프 부재
- "맵이 배경일 뿐" — 플레이 경험에 관여 안 함
- "너무 쉽다" — 숙련자 보상 없음

## 타겟 사용자
8~14세 Roblox 플레이어 — 현재 초반 30초 이탈하는 유저

## 선정된 서브 아이디어 8개

### FEEL (조작감 — 최우선)
1. **Juice Pass** — 스크린 쉐이크 + 히트스톱 + 파티클 + SFX 번들 (🟢 S)
2. **Input Polish** — 점프 선입력 + 코요테 타임 + 슬라이드 캔슬 (🟢 S)
3. **Dynamic Camera** — 속도/액션 반응형 FOV & 틸트 (🟢 S)
9. **3HP Heart** — 1방 즉사 → 3HP + 5초 회복 (🟢 S)

### TENSION (긴장감)
4. **Grazing** — 아슬아슬 회피 감지 → 슬로우모션 + 점수×2 (🟡 M)
8. **Chaser** — 뒤에서 쫓아오는 위협, 실수 누적 시 잡힘 (🟡 M)

### MAP (레벨디자인 최소 투입)
M4. **Telegraph System** — 2초 전 위험 예고 UI (🟢 S)
M12. **Zone별 고유 메커닉** — 얼음/사막/숲/화산 룰 변경 (🔴 L, 핵심)

## 평가
- 사용자 가치: ⭐⭐⭐⭐⭐
- 구현 난이도: 🟡 M (8개 혼합)
- 리스크: 낮음~중간 (Zone 메커닉 물리 전환부 주의)
- 예상 Sprint: 4~5개

## v3.3 연기 항목 (v3.2 출시 후 데이터 보고 결정)
- GROWTH: #5 파쿠르 콤보, #6 Air Dash, #10 Risk Lane
- MAP: M1 Set Pieces, M7 Dual-Floor 재설계, M13 Chase Map, M5 Named Obstacles, M14 Bonus Room

## 다음 행동
1. /prd update — PRD-v3.md 기반으로 v3.2 목표/KPI 정의
2. /draft update — Sprint 4~5개 자동 생성
3. Sprint 시작 순서 (권장):
   - S1: Input Polish + Juice Pass (즉시 체감, 가장 싸고 가장 큰 효과)
   - S2: Dynamic Camera + 3HP Heart + Telegraph
   - S3: Grazing + Chaser
   - S4: Zone 메커닉 (얼음/사막 먼저, 숲/화산 Sprint 5)
   - S5: Zone 메커닉 2 + 통합 QA + 튜닝

## 측정 지표 (v3.2 성공 판정)
- 30초 이탈률 30% 감소
- 평균 세션 길이 1.5배
- "조작감" 관련 부정 피드백 50% 감소
- D1 리텐션 +10%p

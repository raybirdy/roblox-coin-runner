# Coin Runner PRD v3.2

> 작성: 2026-04-07 | CRAFT /prd update 스킬 자동 생성
> status: draft
> 이전 버전: PRD-v3.md (v3.0/v3.1 done, released 2026-04-07)

---

## Executive Summary

**제품**: Coin Runner
**v3.2 한 줄 목표**: **"Make It Feel Good"** — 조작감과 긴장감을 복구해 "재미의 본질"을 되찾는다
**플랫폼**: Roblox (Luau)
**타겟**: 8~14세
**작성일**: 2026-04-07
**v3.2 포커스**: 시각 폴리싱(v3.1) → **조작감 / 텐션 / 맵 게임성** 축 전환

---

## 1. v3.1 회고 → v3.2 문제 정의

### v3.1에서 달성한 것
- 시각 맵 고도화 13종 (Dual-Floor, Encounter, Phrase, 날씨, 프롭, 챕터 테마)
- 특수 코인 3종 + Fever 아이템화
- Analytics 15종 이벤트 와이어링
- Pre-launch Gate 통과 (GO)

### v3.1에서 드러난 진짜 문제
IDEA-014에서 진단한 재미 부족의 3축:
1. **조작감 (Game Feel)**: 입력 피드백 레이어 부재 — 점프/슬라이드/피격이 "묵직"하지 않음
2. **긴장-이완 루프**: 단조로움 — 처음 30초가 한가롭고 추격자/위기 순간 없음
3. **스킬 천장**: 고수/하수 차이 없음 — 잘해도 보상 없고 못해도 패널티 없음
4. **맵의 의미 부재**: v3.1에서 시각은 다양해졌지만 맵이 플레이 경험에 관여하지 않음

**핵심 통찰**: "시각 폴리싱"은 필요조건이지만 충분조건이 아니다. 유저가 러너에서 느끼는 재미는 **피드백 × 긴장감 × 선택**에서 나온다.

---

## 2. Contrarian Thesis (v3.2 업데이트)

**v3.1까지의 Thesis**: Roblox Co-op 러너 니치
**v3.2 Thesis 추가**: "Roblox 러너는 대부분 조작감 투자가 zero다. 조작감만 모바일 모바일 AAA 수준으로 올려도 Roblox 내에서 독점 가능하다."

**근거**:
- Subway Surfers 40억 DL의 핵심은 시각이 아니라 **0.1초 단위의 반응성**
- Roblox Humanoid 기본값은 "floaty" — 아무도 건드리지 않음 = 기회
- "Roblox에서 조작감이 가장 좋은 러너"라는 포지셔닝은 비어있음

---

## 3. v3.2 MoSCoW (변경 사항만)

### Must Have [NEW] — v3.2 핵심 8개
FEEL 패키지:
- [ ] [NEW] **Juice Pass** — 스크린 쉐이크 + 히트스톱(0.05s) + 파티클 + SFX 번들
- [ ] [NEW] **Input Polish** — 점프 선입력(150ms) + 코요테 타임(80ms) + 슬라이드 캔슬
- [ ] [NEW] **Dynamic Camera** — 속도 반응형 FOV, 액션 기반 틸트/쉐이크
- [ ] [NEW] **3HP Heart System** — 1방 즉사 → 3HP + 5초 무피격 시 회복

TENSION 패키지:
- [ ] [NEW] **Grazing (아슬 회피)** — 0.5 stud 이내 스침 감지 → 슬로우모션 + 점수 ×2
- [ ] [NEW] **Chaser 시스템** — 뒤에서 추격하는 위협, 실수 1회당 거리 축소

MAP 게임성 패키지:
- [ ] [NEW] **Telegraph System** — 2초 전 위험 예고 UI (화면 아이콘 + 바닥 경고 라인)
- [ ] [NEW] **Zone별 고유 메커닉** — 얼음(미끄럼) / 사막(바람 저항) / 숲(낮은 중력) / 화산(용암 상승) 룰 변경

### Should Have [NEW] — v3.2 여력 시
- [ ] [NEW] 사운드 에셋 4종 rbxassetid 교체 (v3.1 이월)
- [ ] [NEW] 로비 룰렛(777) Studio 재배치 (v3.1 이월)

### Won't Have [DEFERRED → v3.3]
v3.3으로 연기 (IDEA-014 참조):
- GROWTH 패키지: 파쿠르 콤보, Air Dash, Risk Lane
- MAP 확장: Set Pieces, Dual-Floor 재설계, Chase Map, Named Obstacles, Bonus Room

### Won't Have (유지)
- 미니게임 재활성화 (v3.1 제거, 추후 전면 재설계 시 재논의)

---

## 4. 성공 지표 (KPI) — v3.2 재설정

> v3.1 Analytics 와이어링 완료 → 처음으로 **실측 기반 목표** 설정 가능
> 소프트 론치 후 v3.1 기저선 2주 수집 → v3.2 출시로 개선 측정

| 지표 | v3.1 기저선 | v3.2 목표 | 측정 방법 |
|------|:---:|:---:|---------|
| 30초 이탈률 | TBD | **-30%p** | session_end < 30s 비율 |
| 평균 세션 길이 | TBD | **×1.5** | session_end.duration 평균 |
| D1 리텐션 | TBD | **+10%p** | Analytics 세션 추적 |
| 평균 런당 점프 수 | TBD | **+40%** | Input 활용도 (조작감 간접 지표) |
| "재미없음" 부정 피드백 | TBD | **-50%** | 유저 리뷰/Discord 수집 |

**v3.2 성공 판정**: 위 5개 중 3개 이상 목표 달성 시 v3.3 진행. 2개 이하면 /business review 재검토.

---

## 5. 비기능 요구사항 (v3.2 추가)

| 항목 | 요구사항 |
|------|---------|
| 성능 | 모바일 기준 30FPS 유지, 피드백 이펙트가 프레임 드롭 유발 금지 |
| 입력 지연 | 점프/슬라이드 입력 → 반응 < 50ms (Input Polish 필수) |
| 접근성 | 모션 민감 유저용 "스크린 쉐이크 끄기" 옵션 |
| 네트워크 | Zone 메커닉 전환 시 서버 권위 유지, 클라이언트 예측 금지 |

---

## 6. 제약사항

- **일정**: v3.2는 4~5 Sprint 이내. 6 Sprint 초과 시 범위 축소 강제 (Zone 메커닉은 2개만)
- **기술**: Roblox Humanoid 물리 한계 — Zone 메커닉은 기존 Humanoid API 범위 내에서만
- **솔로 개발**: 한 번에 한 Sprint 집중. 병렬 개발 금지

---

## 7. 기술 리스크 (oracle 분석)

| 리스크 | 심각도 | 대응 |
|--------|:---:|------|
| Zone 메커닉 전환부 물리 튐 (캐릭터 vault/flicker) | High | ZoneController 전환 시 1 tick 무적, Humanoid.PlatformStand 활용 |
| Juice Pass 이펙트가 모바일 FPS 드롭 유발 | Med | 모바일 감지 시 파티클 수 50% 감소, 스크린 쉐이크 강도 70% |
| Chaser AI가 플레이어 실력 차이에 공정하지 않음 | Med | 실수 누적 방식(거리 단계형)으로 rubber band 회피 |
| Input Polish가 기존 GameManager 타이밍과 충돌 | Low | InputBuffer 컨트롤러 분리, 기존 코드 최소 터치 |
| Grazing 히트박스 확장이 물리 성능에 영향 | Low | 매 프레임 거리 계산 대신 Region3 체크 |

---

## 8. 미해결 질문

- [ ] Chaser 비주얼: 경찰? 몬스터? IP 적절성 검토
- [ ] Zone 메커닉 중 얼음/사막/숲/화산 모두 v3.2에 넣을지, 2개만 넣고 나머지 v3.3?
- [ ] Telegraph UI 스타일: 이모지? 카드? 바닥 라인만?
- [ ] v3.1 Analytics 기저선 수집 기간 (2주? 1주?)

---

## 9. 다음 단계

PRD v3.2 승인 후 → `/draft update` 실행
→ v3.2 Sprint 4~5개 자동 생성 (Sprint 순서: Input Polish → Juice → Camera/HP/Telegraph → Grazing/Chaser → Zone 메커닉)

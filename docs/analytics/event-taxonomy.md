# Coin Runner — Analytics Event Taxonomy

> 작성: 2026-04-06 | CRAFT `/analytics` Pre-launch Gate
> 상태: **Draft — 와이어링 갭 존재 (출시 차단)**

---

## 목적

소프트 론치 후 PRD-v3 KPI(D1/D7/D30 리텐션, 과금 전환율, DAU, Co-op 참여율) 측정을 위한 최소 이벤트 정의.

**원칙**:
- Roblox AnalyticsService 전용 (DataStore 사용 금지)
- 서버 디스패치 기본, 클라이언트 이벤트는 `tutorial_step`만 허용
- RateLimiter: 플레이어당 초당 2건
- PII(이름, 채팅) 금지. userId는 Roblox UserId만 사용

---

## 코어 이벤트 10종

| # | 이벤트 | 소스 | 목적(KPI) | 필드 |
|---|--------|------|-----------|------|
| 1 | `session_start` | server/init | DAU, D1 | platform |
| 2 | `session_end` | server/init | 세션 길이 | duration, reason |
| 3 | `run_start` | GameManager | 런 수, 난이도 분포 | mode (solo/coop), zone, chapterId |
| 4 | `run_end` | GameManager | 세션 길이, 완주율, 사인 | duration, coinsCollected, maxCombo, bestZone, deathCause |
| 5 | `coin_earned` | GameManager (집계, 런 종료 시 1건) | 코인 인플레이션 감시 | total, gold, diamond, special(Star/Magnet/Rainbow) |
| 6 | `purchase` | MonetizationService.ProcessReceipt | 과금 전환율, ARPPU | productId, robuxSpent, currency, receiptKey |
| 7 | `coop_match` | CoopMatchService | Co-op 참여율 | matchResult (found/timeout/cancel), waitSeconds |
| 8 | `tutorial_step` | TutorialService (clientOK) | 온보딩 이탈 지점 | stepId, action (enter/complete/skip) |
| 9 | `battle_pass_purchase` | MonetizationService | 배틀패스 전환율 | seasonId, robuxSpent |
| 10 | `feature_engaged` | 범용 | 기능 사용률 | featureId (skill/special_coin/fever), context |

> Roblox AnalyticsService 무료 티어는 커스텀 이벤트 수 제한이 느슨. 10종이면 충분.

---

## 현재 와이어링 상태 (grep 기준)

| 이벤트 | 구현 상태 | 호출 위치 |
|--------|----------|---------|
| `session_start` | ✅ wired | `server/init.server.luau:154` |
| `session_end` | ✅ wired | `server/init.server.luau:242` |
| `tutorial_step` | ✅ wired | `TutorialService:98,133` + `ActiveSkillService:125` |
| `run_start` | ❌ **MISSING** | GameManager 런 시작 시 호출 필요 |
| `run_end` | ❌ **MISSING** | GameManager 게임 오버 처리 시 호출 필요 |
| `coin_earned` | ❌ **MISSING** | GameManager 런 종료 시 집계 1건 권장 |
| `purchase` | ❌ **MISSING** | MonetizationService.ProcessReceipt 성공 분기 |
| `coop_match` | ❌ **MISSING** | CoopMatchService 매칭 성사/실패 시 |
| `battle_pass_purchase` | ❌ **MISSING** | MonetizationService 배틀패스 GamePass 성공 시 |
| `feature_engaged` | ❌ whitelist 미등록 | VALID_EVENTS에 추가 필요 |

**갭**: 10종 중 7종 미와이어 → **출시 차단**.

---

## 와이어링 작업 범위 (Sprint 후보)

### P0 — 출시 전 필수 (예상 1~2일)

1. **`AnalyticsService` VALID_EVENTS 확장**
   - `run_start`, `run_end`, `coin_earned`, `purchase`, `coop_match`, `battle_pass_purchase`, `feature_engaged` 추가

2. **GameManager 런 라이프사이클**
   - `run_start`: `_startNewRun` 또는 세션 초기화 직후
   - `run_end`: `_handleGameOver` / `_endRun` 경로. `session.coins`, `session.maxCombo`, 최고 도달 Zone, 사인(obstacle/timeout/quit) 수집
   - `coin_earned`: run_end 시 tier별 집계 1건 (프레임마다 호출 금지)

3. **MonetizationService 과금 이벤트**
   - `ProcessReceipt` 성공 분기 (line ~170~220): `purchase` 이벤트 (productId, robuxSpent, receiptKey)
   - Battle Pass GamePass 성공 분기: `battle_pass_purchase` 별도 이벤트

4. **CoopMatchService 매칭 이벤트**
   - 매칭 성사: `coop_match` (matchResult="found", waitSeconds)
   - 타임아웃/취소: `coop_match` (matchResult="timeout"/"cancel", waitSeconds)

### P1 — 출시 후 2주 내

5. **`feature_engaged` 범용 이벤트**
   - 액티브 스킬 발동, 특수 코인 수집(Star/Magnet/Rainbow), 피버 진입, 파워업 사용
   - RateLimiter로 스팸 방지 (플레이어당 분당 최대 20건)

---

## 차단 사유 (Pre-launch Gate 관점)

PRD-v3 KPI는 7종 이벤트 없이 **단 하나도 측정 불가**:

| KPI | 필요 이벤트 | 현재 |
|-----|-----------|------|
| D1/D7/D30 리텐션 | session_start + userId 기반 재접속 조인 | ⚠️ session_start는 있으나 분석 파이프라인 미구축 |
| 월 DAU | session_start | ✅ |
| 과금 전환율 | purchase / session_start | ❌ purchase 미와이어 |
| 월 수익 | purchase (robuxSpent) | ❌ |
| 평균 세션 길이 | session_start + session_end | ⚠️ session_end에 duration 필드 누락 |
| Co-op 참여율 | coop_match / run_start | ❌ 둘 다 미와이어 |

**결론**: 출시 전에 최소 P0 1~4 와이어링 필수. Roblox Creator Dashboard에서 DAU/수익은 기본 제공되므로 커스텀 이벤트는 **리텐션/세그먼트 분석**에 집중.

---

## 데이터 파이프라인 (단기)

- **1차**: Roblox Creator Dashboard — 기본 DAU/수익/리텐션 자동 제공
- **2차**: AnalyticsService `LogCustomEvent` — 커스텀 이벤트 저장 (Roblox 무료 티어)
- **3차 (선택)**: 외부 데이터 웨어하우스 연결은 소프트 론치 후 판단

---

## 소프트 론치 30일 후 재검토 항목

- 이벤트 10종 실측 volume 확인
- 누락 필드 보강 (사용자 세그먼트, 디바이스 정보)
- A/B 테스트 인프라 필요성 검토

---

*분석 에이전트: oracle (갭 분석) — /craft Pre-launch Gate*

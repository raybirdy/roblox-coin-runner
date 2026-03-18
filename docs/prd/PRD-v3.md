# Coin Runner PRD v3

> 작성: 2026-03-18 | CRAFT /prd 스킬 자동 생성
> 상태: Draft
> 이전 버전: 없음 (v2.2까지 PRD 미작성, 최초 공식 PRD)

---

## Executive Summary

**제품**: Coin Runner
**한 줄 목표**: 친구와 함께 성장하는 Roblox Co-op 러너
**플랫폼**: Roblox (Luau)
**타겟**: 8~14세
**작성일**: 2026-03-18

---

## 1. Contrarian Thesis & Monopoly Niche

**Contrarian Thesis**: Roblox는 Co-op 플랫폼이다. 러너를 Co-op 핵심으로 만들면 모바일 러너(Subway Surfers, Talking Tom Run)와 경쟁하지 않아도 된다.

**독점 니치**: "Roblox에서 2인 Co-op으로 경쟁+협력이 동시에 되는 러너를 찾는 8~14세"

**시장 검증**: docs/business/market-analysis.md 참조
- 판정: CONDITIONAL GO (수익화 파이프라인 완성 후 소프트 론치)
- Roblox Co-op 오비 DAU ~50만 중 러너 전환 가능 10% = 5만 규모 니치
- 경쟁사(Subway Surfers, Talking Tom Run) 모두 솔로 전용 — Co-op 공백 실재

---

## 2. 문제 정의

**현재 상황 (v2.2 완성 후)**:
1. 러너 장르의 구조적 단조로움 — 달리고 코인 먹기 반복
2. 콘텐츠 소진 — 장기 플레이 동기 부족
3. 온보딩 부족 — 신규 유저가 뭘 해야 할지 모름
4. 솔로 플레이 재미 부족 — Co-op 없으면 접속 동기 약함
5. 수익화 동기 부족 — 과금할 이유가 게임플레이에서 자연스럽지 않음

**현재 대안 (경쟁자)**:
- Subway Surfers (모바일 + Roblox): IP 인지도 높지만 Co-op 없음, Roblox 최적화 미흡
- Talking Tom Run: 솔로 전용, Roblox 부재
- Tower of Hell / Carry Me!: Co-op 있지만 러너 장르가 아님

**우리 해결책**: 게임플레이 변주(미니게임, 랜덤 이벤트, 스킬)로 단조로움을 깨고, 캐릭터 영구 성장으로 장기 목표를 제공하는 "성장하는 Co-op 러너"

---

## 3. 타겟 사용자

### 페르소나 A: "10살 민수"
- **역할**: 초등학생, 게임 초보~중급
- **핵심 페인포인트**: 혼자 하면 심심함, 친구와 같이 할 게임이 필요
- **행동 패턴**: 학교 끝나면 친구와 Roblox 접속, 부모 계정으로 가끔 Robux 충전
- **기대하는 결과**: Co-op으로 친구와 함께 플레이, 매번 다른 느낌의 런

### 페르소나 B: "14살 지윤"
- **역할**: 중학생, 경쟁적 게이머
- **핵심 페인포인트**: 단조로운 러너는 빠르게 질림, 성장/경쟁 요소 필요
- **행동 패턴**: 용돈으로 직접 Robux 충전, 랭킹/배틀패스에 과금 의향
- **기대하는 결과**: 캐릭터 성장으로 강해지는 느낌, 랭킹 경쟁

---

## 4. 성공 지표 (KPI)

> ⚠️ 현재 analytics 미구현 상태. 모든 지표는 소프트 론치 후 측정 시작 기준.
> 기저선(Baseline)은 소프트 론치 첫 2주 데이터로 확정 후, 목표 수치를 재검증한다.

| 지표 | 3개월 목표 | 6개월 목표 | 측정 방법 |
|------|:---:|:---:|---------|
| D1 리텐션 | 25% | 35% | AnalyticsService 세션 추적 |
| D7 리텐션 | 10% | 15% | AnalyticsService 세션 추적 |
| D30 리텐션 | 5% | 8% | AnalyticsService 세션 추적 |
| 과금 전환율 (paying/DAU) | 1.5% | 3% | 구매 이벤트 / DAU |
| 월 DAU | 500 | 2,000 | Roblox Creator Dashboard |
| 월 수익 (USD) | ~$300 | ~$1,500 | Roblox 수익 리포트 |
| 평균 세션 길이 | 8분 | 12분 | AnalyticsService |
| Co-op 참여율 (Co-op 런/전체 런) | 20% | 35% | 서버 로그 |
| 미니게임 완주율 | 70%+ | 80%+ | 서버 로그 |

**소프트 론치 30일 재판정 기준** (docs/business/market-analysis.md 참조):

| 지표 | 위험 신호 | 액션 |
|------|----------|------|
| D1 리텐션 < 15% | 코어 루프 재검토 | 온보딩/튜토리얼 즉시 개선 |
| 과금 전환율 < 0.5% | 가격 정책 재검토 | 저가 상품 퍼스트 터치 최적화 |
| Co-op 참여율 < 10% | Co-op 진입 장벽 확인 | 포탈 UI/매칭 UX 개선 |
| 미니게임 스킵률 > 50% | 미니게임 재미 부족 | 미니게임 리디자인 또는 제거 |
| DAU 30일 후 < 200 | 디스커버리 실패 | Roblox Sponsored 테스트 |

---

## 5. MVP 기능 범위 (MoSCoW)

### Must Have (없으면 v3 출시 불가)

| ID | 기능 | 상세 | 기존 시스템 관계 |
|----|------|------|----------------|
| M1 | **미니게임 구간** | MVP 2종 (장애물 러시, 코인 폭풍). 10~15청크마다 1회 출현. 러너 일시정지 → 미니게임 → 복귀. 실패 시 보상 없음 (라이프 차감 없음). 15~30초 소요. | 신규 MiniGameService. 기존 ChunkService에 트리거 포인트 추가 |
| M2 | **튜토리얼/온보딩 강화** | 첫 5런 단계적 안내: 이동→코인→장애물→파워업→Co-op. NPC 가이드 캐릭터. | 기존 TutorialService 확장 (전면 재작성 아님) |
| M3 | **캐릭터 영구 성장** | 기존 UpgradeService에 5종 추가 (base_speed, base_jump, base_lives, skill_cooldown, mini_game_bonus). 플랫 딕셔너리 구조 유지. 성장 한도: 각 10레벨. | 기존 UpgradeService 확장, PlayerData.upgrades 필드 재사용 |
| M4 | **Analytics 최소 구현** | 핵심 이벤트 10종: session_start, session_end, run_start, run_end, coin_earned, purchase, coop_match, minigame_start, minigame_end, tutorial_step. Roblox AnalyticsService 사용. | 신규 AnalyticsService |
| M5 | **v2.2 기술 부채 해소** | ProductId 등록 (배틀패스, MEGA, ULTRA 번들), 사운드 에셋 교체, Co-op 포탈 로비 배치, CameraController FOV 적용 | 기존 파일 수정 |

### Should Have (출시 직후 4주 내)

| ID | 기능 | 상세 | 비고 |
|----|------|------|------|
| S1 | **랜덤 이벤트 시스템** | 런 중 돌발 이벤트 5종 (코인 비, 속도 변환, 거인 모드, 중력 반전, 안개). 확률 기반 출현 (평균 20초마다). 기존 PowerupService와 별도 — 환경 변화 이벤트. | M1(미니게임) 안정화 후 착수 |
| S2 | **스킬/능력 시스템** | 기존 RunSkillService에 "액티브 스킬 슬롯" 추가. 쿨다운 기반 능동 발동 3종 (대시, 실드, 자석 폭발). 영구 성장(M3)으로 해금/강화. | 기존 RunSkillService 확장 (신규 서비스 아님) |
| S3 | **일일 도전 과제** | 매일 3개 갱신. 배틀패스 XP 주요 소스. 난이도 Easy/Normal/Hard. | 신규 DailyChallengeService |
| S4 | **솔로 모드 재미 보강** | M1 미니게임 + S1 랜덤 이벤트가 솔로에서도 완전 작동하도록 최적화 | M1/S1의 솔로 모드 QA |

### Could Have (백로그 — 데이터 기반 판단 후)

| ID | 기능 |
|----|------|
| C1 | 시즌/테마 로테이션 (4~6주 단위 테마 변경) |
| C2 | Co-op 전용 미니게임 (2인 협력 구간) |
| C3 | 스킬 조합 시너지 |
| C4 | 리더보드 확장 (미니게임별 랭킹) |
| C5 | 커스텀 런 설정 (난이도/규칙 프라이빗 런) |
| C6 | 럭키 스핀 개선 (무료 전용으로 전환, 확률 공개) |
| C7 | 소셜 초대/선물 시스템 |

### Won't Have (명시적 제외)

| ID | 기능 | 제외 근거 |
|----|------|----------|
| W1 | UGC 콘텐츠 (유저 맵 제작) | 사용자 명시적 제외. 1인 개발로 모더레이션 불가 |
| W2 | 길드/클랜 시스템 확장 | 사용자 명시적 제외. 기존 5인 팀 시스템으로 충분 |
| W3 | PvP 실시간 대전 | Co-op 핵심 테제와 충돌. 고스트 레이싱으로 비동기 경쟁 커버 |
| W4 | 자체 채팅/음성 시스템 | COPPA 규제 리스크. Roblox 기본 채팅 사용 |
| W5 | 크로스 플랫폼 연동 | Roblox 단일 플랫폼 집중 |
| W6 | 유료 럭키 스핀 (젬으로 추가 스핀) | COPPA/Roblox 정책상 아동 대상 유료 랜덤박스 위험 |

---

## 6. 비기능 요구사항

| 항목 | 요구사항 |
|------|---------|
| **성능** | 미니게임 전환 시 프레임 드롭 30fps 이하 금지. 모바일(저사양) 기준. 기존 청크 유지+미니게임 에셋 로드 시 메모리 스파이크 방지를 위해 미니게임 진입 시 후방 청크 2개 해제 |
| **DataStore** | PlayerData 키당 50KB 이하 유지. 영구 성장 데이터는 기존 upgrades 플랫 딕셔너리에 추가 (트리 구조 금지). Analytics는 DataStore 사용 금지 — AnalyticsService 전용 API만 사용 |
| **서버 검증** | 스킬 발동: 서버에서 쿨다운/보유 여부/게임 상태 검증 필수. 미니게임 결과: 서버에서 점수 검증. RateLimiter 적용 |
| **보안** | 클라이언트 시간 불신 원칙 유지. 스킬 지속 시간은 서버 task.delay로 관리 |
| **접근성** | 8세 최소 연령 기준: 터치 버튼 최소 100px, 미니게임 제한 시간 최소 15초, 텍스트 가독성 확보 |
| **회귀 테스트** | 미니게임 추가 후 기존 솔로/Co-op 런 정상 동작 스모크 테스트 필수. GameSession 상태 머신 변경 시 전 모드 검증 |
| **타겟 연령 변경 영향** | 6~12세 → 8~14세 변경. 기존 파라미터 검토 대상: TOUCH_BUTTON_SIZE, COMBO_TIMEOUT, 난이도 커브. 14세 대응 난이도 옵션 추가 검토 (Could Have) |

---

## 7. 제약사항

- **기술**: Roblox Luau 단일 플랫폼, Rojo 워크플로우
- **인력**: 1인 개발 (예상 MVP 8~12주)
- **예산**: 취미/부업 수준 ($0~$100/월). Roblox Sponsored $100~300 테스트 가능
- **규제**: COPPA (13세 미만 대상), Roblox 커뮤니티 가이드라인, 아동 대상 유료 랜덤박스 금지
- **미등록 에셋**: ProductId 0 (배틀패스, MEGA, ULTRA), 사운드 에셋 빈 문자열 — v3 출시 전 반드시 해결 (M5)

---

## 8. 기술 리스크 (oracle 분석)

| 리스크 | 심각도 | 대응 |
|--------|:---:|------|
| 미니게임 ↔ GameSession 상태 충돌 | **High** | sessionState 상태 머신 도입 ("running"/"minigame"/"paused"). 시간 기반 값에 pausedDuration 오프셋 적용. 아키텍처를 1주차에 확정 |
| 스킬 효과 중첩 복잡도 (4번째 레이어) | **Med** | 신규 서비스 만들지 않음. 기존 RunSkillService에 "액티브 스킬 슬롯" 확장. 효과 중첩은 단일 함수에서 계산 |
| PlayerData 비대화 | **Med** | 플랫 딕셔너리 유지, 트리 구조 금지. 미니게임 기록은 GameSession 내에서만 관리, 런 종료 시 1회 저장 |
| Co-op 모드에서 미니게임 동기화 | **Med** | 두 플레이어 동시 미니게임 진입. CoopMatchService에서 미니게임 트리거 동기화. 실패/성공 독립 처리 |
| DataStore throttle | **Low** | Analytics는 AnalyticsService API 전용. 저장 빈도 기존 유지. 미니게임 결과는 런 종료 시 합산 저장 |
| COPPA 럭키 스핀 규제 | **Low** | 유료 스핀 Won't Have로 제외. 무료 전용으로 전환 시 Could Have |

---

## 9. 아키텍처 초기 결정 (oracle 권장)

### 미니게임 모듈화

```
src/server/Services/MiniGameService.luau       -- 미니게임 진입/퇴장 디스패처
src/server/Services/MiniGames/                 -- 개별 미니게임 모듈
    ObstacleRush.luau                          -- 장애물 러시
    CoinStorm.luau                             -- 코인 폭풍
src/client/Controllers/MiniGameController.luau -- 클라이언트 UI/입력
```

GameManager에 직접 넣지 않음. MiniGameService가 GameManager로부터 트리거를 받아 세션 상태 전환.

### 스킬 시스템

기존 RunSkillService 확장. 새 서비스 생성하지 않음.
- PlayerData.upgrades에 스킬 해금 레벨 저장
- equippedRunSkills 필드에 액티브 스킬 슬롯 추가
- 쿨다운은 서버 task.delay로 관리

### 영구 성장 데이터

기존 PlayerData.upgrades (플랫 딕셔너리) 그대로 확장:
```lua
upgrades = {
    magnet_range = 3,     -- 기존
    coin_value = 5,       -- 기존
    base_speed = 2,       -- v3 신규
    base_jump = 1,        -- v3 신규
    base_lives = 1,       -- v3 신규
    skill_cooldown = 0,   -- v3 신규
    mini_game_bonus = 0,  -- v3 신규
}
```
트리 전제 조건은 GameConstants에서만 정의. PlayerData에는 레벨만 저장.

---

## 10. 구현 순서 (권장)

> 1인 개발 기준. 의존성 기반 순서.

| 순서 | 피처 | 예상 공수 | 의존성 |
|:---:|------|:---:|------|
| 1 | M5: v2.2 기술 부채 해소 | 2~3일 | 없음 |
| 2 | M4: Analytics 최소 구현 | 2~3일 | 없음 |
| 3 | M2: 튜토리얼/온보딩 강화 | 1~2주 | M4 (퍼널 측정) |
| 4 | M3: 캐릭터 영구 성장 | 2~3주 | 없음 |
| 5 | M1: 미니게임 구간 (MVP 2종) | 3~4주 | M4 (미니게임 지표 측정) |
| 6 | S2: 스킬/능력 시스템 | 1~2주 | M3 (성장으로 해금) |
| 7 | S1: 랜덤 이벤트 시스템 | 3~5일 | M1 (미니게임 안정화 후) |
| 8 | S3: 일일 도전 과제 | 1주 | M4 (측정) |

**미니게임 아키텍처 설계는 1주차에 확정** (M5/M4 작업과 병행).
총 예상: **10~14주** (Must Have만 8~10주, Should Have 포함 시 12~14주)

---

## 11. 미해결 질문

- [ ] 미니게임 MVP 2종 외 추가 종류는 데이터 기반으로 결정 (완주율/스킵률 확인 후)
- [ ] 타겟 연령 8~14세 변경에 따른 기존 UI 파라미터 조정 범위 (Could Have vs Must Have)
- [ ] 14세 유저 대응 난이도 옵션 필요 여부
- [ ] 소프트 론치 지역 선정 (글로벌 동시? 특정 지역 먼저?)
- [ ] 시즌 1 테마/콘텐츠 준비 시점 (소프트 론치 후 몇 주?)

---

## 12. 다음 단계

1. PRD 승인 → `/draft update` 실행 (Sprint 계획 자동 생성)
2. Sprint 1: M5(기술 부채) + M4(Analytics) — 즉시 착수 가능
3. 소프트 론치 후 30일 재판정 (Section 4 기준)

---

*분석 에이전트: prometheus (기능 정리) + oracle (기술 타당성) + momus (비판적 검토)*
*다음 업데이트: 소프트 론치 30일 후 또는 주요 방향 변경 시*

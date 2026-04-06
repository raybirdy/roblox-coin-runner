# Coin Runner PRD v3

> 작성: 2026-03-18 | CRAFT /prd 스킬 자동 생성
> 최종 수정: 2026-04-06
> status: draft
> 이전 버전: 없음 (v2.2까지 PRD 미작성, 최초 공식 PRD)

---

## Executive Summary

**제품**: Coin Runner
**한 줄 목표**: 친구와 함께 성장하는 Roblox Co-op 러너
**플랫폼**: Roblox (Luau)
**타겟**: 8~14세
**작성일**: 2026-03-18
**v3.1 포커스**: 품질 폴리싱 + 시각 개선 + 특수 코인

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

**우리 해결책**: 게임플레이 변주(랜덤 이벤트, 스킬, 특수 코인)로 단조로움을 깨고, 캐릭터 영구 성장으로 장기 목표를 제공하며, 시각적 폴리싱으로 몰입감을 높이는 "성장하는 Co-op 러너"

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

> ⚠️ 현재 analytics 미구현 상태 (M4). 모든 지표는 소프트 론치 후 측정 시작 기준.
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

**소프트 론치 30일 재판정 기준** (docs/business/market-analysis.md 참조):

| 지표 | 위험 신호 | 액션 |
|------|----------|------|
| D1 리텐션 < 15% | 코어 루프 재검토 | 온보딩/튜토리얼 즉시 개선 |
| 과금 전환율 < 0.5% | 가격 정책 재검토 | 저가 상품 퍼스트 터치 최적화 |
| Co-op 참여율 < 10% | Co-op 진입 장벽 확인 | 포탈 UI/매칭 UX 개선 |
| DAU 30일 후 < 200 | 디스커버리 실패 | Roblox Sponsored 테스트 |

---

## 5. MVP 기능 범위 (MoSCoW)

### Must Have (없으면 v3 출시 불가)

| ID | 기능 | 상세 | 상태 |
|----|------|------|:---:|
| M2 | **튜토리얼/온보딩 강화** | 첫 5런 단계적 안내: 이동→코인→장애물→파워업→Co-op. NPC 가이드 캐릭터. | ✅ done |
| M3 | **캐릭터 영구 성장** | UpgradeService에 5종 추가 (base_speed, base_jump, base_lives, skill_cooldown, mini_game_bonus). 플랫 딕셔너리 구조 유지. 각 10레벨. | ✅ done |
| M4 | **Analytics 최소 구현** | 핵심 이벤트 10종. Roblox AnalyticsService 사용. DataStore 미사용. | ⚠️ 코드 구현 완료, 외부 검증 미완 |
| M5 | **v2.2 기술 부채 해소** | ProductId 등록 (배틀패스, MEGA, ULTRA), 사운드 에셋 교체, Co-op 포탈 로비 배치, **미니게임 데드코드 정리** [NEW] | ⚠️ ProductId=0 미등록, SoundId 일부 미교체 |

### Should Have (출시 직후 4주 내)

| ID | 기능 | 상세 | 상태 |
|----|------|------|:---:|
| S1 | **랜덤 이벤트 시스템** | 런 중 돌발 이벤트 5종. 확률 기반 출현. | ✅ done |
| S2 | **스킬/능력 시스템** | RunSkillService 확장. 쿨다운 기반 액티브 스킬 3종. | ✅ done |
| S3 | **일일 도전 과제** | 매일 3개 갱신. 배틀패스 XP 소스. | ✅ done |

### v3.1 추가 범위 — 품질 폴리싱 + 시각 개선

| ID | 기능 | 상세 | 상태 |
|----|------|------|:---:|
| V1 | **모바일 UI 최적화** | UITokens, ResponsiveUtil compactMode | ✅ done |
| V2 | **맵 고도화 12종** | 시차스크롤, 2층맵, 이동장애물, 챕터테마, 보스런연출, 날씨, 코인패턴, 장식프롭, Encounter, Phrase, 전환폴리싱, 멀티레인 | ✅ done |
| V3 | **챕터 2→3 전환 버그** | 챕터 완료 시 다음 챕터 언락 버그 수정 (ISSUE-023) | pending |
| V4 | **코인/장애물 시각 구분** | 코인 글로우+PointLight, 장애물 경고 연출, 존별 조명 차별화 (ISSUE-032) | pending |
| V5 | **특수 효과 코인 3종** | Star(콤보+5), Magnet(자동수집 3s), Rainbow(점수2×) (ISSUE-033) | pending |

### Could Have (백로그 — 데이터 기반 판단 후)

| ID | 기능 |
|----|------|
| C1 | 시즌/테마 로테이션 (4~6주 단위 테마 변경) |
| C2 | Co-op 전용 협력 구간 |
| C3 | 스킬 조합 시너지 |
| C4 | 리더보드 확장 |
| C5 | 커스텀 런 설정 (난이도/규칙 프라이빗 런) |
| C6 | 럭키 스핀 개선 (무료 전용, 확률 공개) |
| C7 | 소셜 초대/선물 시스템 |

### Won't Have (명시적 제외)

| ID | 기능 | 제외 근거 |
|----|------|----------|
| W1 | UGC 콘텐츠 (유저 맵 제작) | 1인 개발로 모더레이션 불가 |
| W2 | 길드/클랜 시스템 확장 | 기존 5인 팀 시스템으로 충분 |
| W3 | PvP 실시간 대전 | Co-op 핵심 테제와 충돌 |
| W4 | 자체 채팅/음성 시스템 | COPPA 규제 리스크 |
| W5 | 크로스 플랫폼 연동 | Roblox 단일 플랫폼 집중 |
| W6 | 유료 럭키 스핀 | COPPA/Roblox 정책상 아동 대상 유료 랜덤박스 위험 |
| W7 | **미니게임 구간** [REMOVED from Must Have] | 재미 부족으로 비활성화 상태. 추후 재논의 예정. 기존 데드코드는 M5에서 정리 |

---

## 6. 비기능 요구사항

| 항목 | 요구사항 |
|------|---------|
| **성능** | 모바일(저사양) 기준 30fps 이상 유지. 시각 개선(V4/V5) 시 MaxParticles 합산 100 이하. PointLight 동시 활성 10개 이하. 특수 코인 파티클 버스트는 10개 중 1개 확률로 제한 |
| **DataStore** | PlayerData 키당 50KB 이하 유지. 영구 성장 데이터는 기존 upgrades 플랫 딕셔너리에 추가 (트리 구조 금지). Analytics는 DataStore 사용 금지 — AnalyticsService 전용 API만 사용 |
| **서버 검증** | 스킬 발동: 서버에서 쿨다운/보유 여부/게임 상태 검증 필수. 특수 코인 효과(Magnet/Rainbow): 서버에서 상태 플래그 관리. RateLimiter 적용 |
| **보안** | 클라이언트 시간 불신 원칙 유지. 스킬/특수코인 지속 시간은 서버 task.delay로 관리 |
| **접근성** | 8세 최소 연령 기준: 터치 버튼 최소 100px, 텍스트 가독성 확보. 코인/장애물 색상 구분은 색맹 대응 (형태 차이 병행) |
| **회귀 테스트** | 시각 개선 후 기존 솔로/Co-op 런 정상 동작 스모크 테스트 필수 |
| **타겟 연령 변경 영향** | 6~12세 → 8~14세 변경. 기존 파라미터 검토 대상: TOUCH_BUTTON_SIZE, COMBO_TIMEOUT, 난이도 커브 |

---

## 7. 제약사항

- **기술**: Roblox Luau 단일 플랫폼, Rojo 워크플로우
- **인력**: 1인 개발
- **예산**: 취미/부업 수준 ($0~$100/월). Roblox Sponsored $100~300 테스트 가능
- **규제**: COPPA (13세 미만 대상), Roblox 커뮤니티 가이드라인, 아동 대상 유료 랜덤박스 금지
- **미등록 에셋**: ProductId 0 (배틀패스, MEGA, ULTRA), 사운드 에셋 빈 문자열 — v3 출시 전 반드시 해결 (M5)

---

## 8. 기술 리스크 (oracle 분석)

| 리스크 | 심각도 | 대응 |
|--------|:---:|------|
| 스킬 효과 + 특수 코인 효과 중첩 복잡도 | **Med** | 특수 코인 효과는 서버 상태 플래그로 관리. 기존 스킬/파워업과 독립 계산 후 합산 |
| 시각 개선 성능 영향 (V4/V5) | **Med** | PointLight 동시 10개 제한, MaxParticles 100 제한. 저사양 디바이스 프레임 테스트 필수 |
| PlayerData 비대화 | **Med** | 플랫 딕셔너리 유지. 특수 코인 상태는 GameSession 내에서만 관리, 런 종료 시 합산 저장 |
| 미니게임 데드코드 잔존 | **Low** | M5에서 MiniGameService/MiniGames/MiniGameController 및 관련 참조 정리 |
| DataStore throttle | **Low** | Analytics는 AnalyticsService API 전용. 저장 빈도 기존 유지 |
| COPPA 럭키 스핀 규제 | **Low** | 유료 스핀 Won't Have로 제외 |

---

## 9. 아키텍처 결정 (oracle 권장)

### 특수 코인 시스템 (V5)

```
GameConstants.SPECIAL_COINS = {
    Star   = { chance = 0.12, comboBonus = 5 },
    Magnet = { chance = 0.06, duration = 3, rangeMultiplier = 2 },
    Rainbow = { chance = 0.05, duration = 2, scoreMultiplier = 2 },
}
```

- CoinService에서 스폰 시 확률 분기 → 타입별 외형/색상 적용
- 수집 처리는 서버(GameManager)에서 상태 플래그 설정
- Magnet 범위 확대는 PlayerController에서 임시 적용 (서버 task.delay로 해제)

### 스킬 시스템 (기존 유지)

기존 RunSkillService 확장 구조 그대로 유지.
- PlayerData.upgrades 플랫 딕셔너리
- equippedRunSkills 필드에 액티브 스킬 슬롯
- 쿨다운은 서버 task.delay로 관리

### 영구 성장 데이터 (기존 유지)

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

---

## 10. 구현 순서 (권장)

> 미해결 항목 기준. 구현 완료 항목(M2, M3, S1~S3, V1, V2)은 제외.

| 순서 | 피처 | 예상 공수 | 의존성 |
|:---:|------|:---:|------|
| 1 | V3: 챕터 2→3 전환 버그 수정 | 1~2일 | 없음 |
| 2 | V4: 코인/장애물 시각 구분 | 2~3일 | 없음 |
| 3 | V5: 특수 효과 코인 3종 | 3~5일 | V4 (시각 기반) |
| 4 | M5: 기술 부채 해소 + 미니게임 코드 정리 | 2~3일 | Studio 작업 필요 |
| 5 | M4: Analytics 외부 검증 | 1~2일 | Studio 퍼블리싱 |

**총 예상: 2~3주** (V3~V5 + M4/M5 잔여)

---

## 11. 미해결 질문

- [ ] 타겟 연령 8~14세 변경에 따른 기존 UI 파라미터 조정 범위 (Could Have vs Must Have)
- [ ] 14세 유저 대응 난이도 옵션 필요 여부
- [ ] 소프트 론치 지역 선정 (글로벌 동시? 특정 지역 먼저?)
- [ ] 시즌 1 테마/콘텐츠 준비 시점 (소프트 론치 후 몇 주?)
- [ ] mini_game_bonus 업그레이드 — 미니게임 제거 후 용도 재정의 또는 삭제 필요

---

## 12. 다음 단계

1. PRD 승인 → `/draft update` 실행 (Sprint 13~15 활성화 + M5 확장)
2. Sprint 13: V3(챕터 버그) — 즉시 착수 가능
3. 소프트 론치 후 30일 재판정 (Section 4 기준)

---

*분석 에이전트: prometheus (인터뷰) + oracle (기술 타당성) + momus (비판적 검토)*
*최초 작성: 2026-03-18 | 업데이트: 2026-04-06 — M1 Won't Have 전환, v3.1 폴리싱 범위 추가*

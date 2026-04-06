# Coin Runner — 작업 계획서

> 작성: 2026-03-18 | CRAFT /draft 스킬 자동 생성
> 최종 수정: 2026-03-18

---

## Pre-flight Check (에이전트 작업 시작 전 반드시 확인)

> 이 섹션을 읽은 후 사용자에게 확인받고 작업을 시작할 것.

| 항목 | 확정값 | 주의 |
|------|--------|------|
| PRD | docs/prd/PRD-v3.md | v3 첫 공식 PRD |
| 기술 스택 | Roblox Luau + Rojo | 변경 없음 |
| Claude 연동 | N/A | Roblox 플랫폼 전용 |
| 배포 | Roblox 퍼블리싱 | 소프트 론치 예정 |
| 버전 | v3.1 (active) | v3.0 완료 후 |
| 현재 Sprint | 0 / ? (v3.1) | 모바일 UI 최적화 |
| 레포 위치 | /Users/parkjongha/Documents/git/roblox-coin-runner | |
| 브랜치 전략 | GitHub Flow (feature → PR → main) | 기존 유지 |
| PMF 스테이지 | pre-pmf | 소프트 론치 전, 속도 우선 |
| Permission 모드 | 개발 중 항상 허용 | |
| Last updated | 2026-04-06 | |

---

## 프로젝트 개요

**제품명**: Coin Runner
**한 줄 목표**: 친구와 함께 성장하는 Roblox Co-op 러너
**타겟**: 8~14세
**배포**: Roblox 퍼블리싱 (소프트 론치)
**기술 스택**: Roblox Luau + Rojo
**도메인**: Game (milestone 기반)

---

## 버전 관리

| 버전 | 상태 | Sprint 범위 | 비고 |
|------|------|------------|------|
| v1.0 | done | — | 코어 러너 루프 |
| v2.0 | done | — | 시나리오, 소셜, 수익화 |
| v2.2 | done | — | 배틀패스, 고스트, 팀랭킹, Co-op |
| v3.0 | done | Sprint 0~7 | 게임플레이 변주 + 성장 |
| **v3.1** | **active** | Sprint 0~ | 모바일 UI 최적화 + 품질 개선 |

---

## 요구사항 & Acceptance Criteria

### 요구사항 M5: v2.2 기술 부채 해소
**설명**: ProductId=0 등록, 사운드 에셋 교체, Co-op 포탈 배치, FOV 적용

**Acceptance Criteria**:
- [ ] ProductId 3건이 GameConstants에 실제 값으로 등록
- [ ] `rg "productId = 0" src/` 결과 0건
- [ ] SoundId 빈 문자열 0건
- [ ] Co-op 포탈 로비 배치 + 매칭큐 진입 동작
- [ ] Co-op 카메라 FOV 줌아웃 적용

### 요구사항 M4: Analytics 최소 구현
**설명**: AnalyticsService 래퍼 + 10종 핵심 이벤트

**Acceptance Criteria**:
- [ ] 10종 이벤트 정상 발화 (session_start/end, run_start/end, coin_earned, purchase, coop_match, minigame_start/end, tutorial_step)
- [ ] DataStore 미사용 — AnalyticsService API 전용
- [ ] 모든 API 호출 pcall 래핑

### 요구사항 M2: 튜토리얼/온보딩 강화
**설명**: 첫 5런 단계적 안내 (이동→코인→장애물→파워업→Co-op), NPC 가이드 "코이니"

**Acceptance Criteria**:
- [ ] 신규 계정 첫 접속 시 Step1 자동 시작
- [ ] 5단계 순차 완료 → 이후 런에 튜토리얼 미표시
- [ ] 스킵 기능 제공
- [ ] 기존 v2.2 유저 하위 호환
- [ ] 튜토리얼 대사는 GameConstants.TUTORIAL에서 참조 (하드코딩 금지)

### 요구사항 M3: 캐릭터 영구 성장
**설명**: UpgradeService 확장, 5종 추가 (base_speed/jump/lives/skill_cooldown/mini_game_bonus), 각 10레벨

**Acceptance Criteria**:
- [ ] 5종 업그레이드 UI 표시 + 구매 동작
- [ ] 만렙(10) 시 MAX 표시 + 추가 구매 차단
- [ ] PlayerData 플랫 딕셔너리 유지 (트리 구조 금지)
- [ ] PlayerData 50KB 이하 유지
- [ ] base_speed 만렙 보너스 ≤ SPEED_MAX * 1.3

### 요구사항 M1: 미니게임 구간 MVP 2종
**설명**: MiniGameService 신규 + 장애물 러시/코인 폭풍. 10~15청크마다 1회. 15~30초.

**Acceptance Criteria**:
- [ ] GameSession 상태 머신 ("running"/"minigame") 정상 전환
- [ ] 미니게임 중 기존 러너 로직 일시정지
- [ ] 복귀 후 점수/콤보/피버 상태 정확히 복원
- [ ] 미니게임 전환 시 30fps 이상 유지
- [ ] Co-op 동시 진입 동기화
- [ ] 미니게임 결과 서버 판정 (클라이언트 전송 금지)
- [ ] MiniGameService는 GameManager 외부 별도 모듈

### 요구사항 S2: 스킬/능력 시스템
**설명**: RunSkillService 확장, 액티브 3종 (dash/shield/magnet_burst), 쿨다운 기반

**Acceptance Criteria**:
- [ ] 3종 스킬 정상 발동 + 쿨다운 표시
- [ ] 해금 조건 (영구 성장 레벨) 검증
- [ ] 서버 검증 (쿨다운/보유/게임 상태)
- [ ] 미니게임 중 비활성화
- [ ] 스킬 지속 시간 서버 task.delay 관리

### 요구사항 S1: 랜덤 이벤트 시스템
**설명**: RandomEventService 신규, 환경 변화 5종 (코인 비/속도 변환/거인/중력 반전/안개)

**Acceptance Criteria**:
- [ ] 평균 20초마다 이벤트 1종 발생
- [ ] 이벤트 종료 후 모든 효과 완전 해제
- [ ] 미니게임 중 미발생
- [ ] PowerupService와 별도 서비스

### 요구사항 S3: 일일 도전 과제
**설명**: DailyChallengeService 신규, 매일 3개 과제, 배틀패스 XP 연동

**Acceptance Criteria**:
- [ ] 매일 00:00 UTC 리셋
- [ ] 배틀패스 XP 보상 지급
- [ ] 완료 판정 서버 전용
- [ ] 도전 과제 히스토리 미저장 (당일분만 PlayerData에 저장)

### 요구사항 S4: 솔로 모드 재미 보강
**설명**: M1+S1이 솔로에서 완전 동작하도록 밸런스 최적화

**Acceptance Criteria**:
- [ ] 솔로 모드 10회 연속 런 크래시 0건
- [ ] 솔로 전용 미니게임/이벤트 빈도 밸런스 적용

---

## MVP 기능 범위

### v3.0 포함 (Must Have)
- M5: v2.2 기술 부채 해소
- M4: Analytics 최소 구현 (10종 이벤트)
- M2: 튜토리얼/온보딩 강화 (5단계 + NPC 가이드)
- M3: 캐릭터 영구 성장 (5종, 각 10레벨)
- M1: 미니게임 구간 MVP 2종 (장애물 러시, 코인 폭풍)

### v3.0 포함 (Should Have — 출시 직후)
- S2: 스킬/능력 시스템 (액티브 3종)
- S1: 랜덤 이벤트 시스템 (환경 변화 5종)
- S3: 일일 도전 과제 (매일 3개)
- S4: 솔로 모드 재미 보강

### v3.1+ (Could Have — 백로그)
- C1: 시즌/테마 로테이션
- C2: Co-op 전용 미니게임
- C3: 스킬 조합 시너지
- C4: 리더보드 확장
- C5: 커스텀 런 설정
- C6: 럭키 스핀 개선 (무료 전용)
- C7: 소셜 초대/선물

### 명시적 제외 (Won't Have)
- UGC 콘텐츠
- 길드/클랜 시스템 확장
- PvP 실시간 대전
- 자체 채팅/음성
- 크로스 플랫폼
- 유료 럭키 스핀

---

## 구현 단계 (8 Sprint)

### Sprint 0 — 기반 정비 + 아키텍처 설계 [done]
**목표**: v2.2 기술 부채 해소(M5) + Analytics 기반(M4) + 미니게임 아키텍처 확정
**기간**: 1주
**피처**: M5, M4, M1(설계만)

- [ ] ProductId=0 3건 실제 ID로 교체
- [ ] 사운드 에셋 5종 교체 (FeverController, PlayerController)
- [ ] Co-op 포탈 로비 배치 + CoopMatchService 연결
- [ ] CameraController SetCoopMode FOV 적용
- [ ] AnalyticsService 신규 생성 (래퍼 + 10종 이벤트)
- [ ] AnalyticsController 클라이언트 보조
- [ ] 미니게임 아키텍처 설계 문서 작성
- [ ] GameConstants.MINI_GAME 상수 블록 추가

**Acceptance Criteria**:
- [ ] AC-0-1: `rg "productId = 0" src/` 결과 0건 [deferred → Sprint 1: Roblox Creator Hub에서 Product 생성 필요]
- [x] AC-0-2: SoundId 빈 문자열 0건 (이미 해결됨)
- [x] AC-0-3: Co-op 포탈 터치 시 매칭큐 진입
- [x] AC-0-4: Co-op 카메라 FOV 솔로와 다름
- [x] AC-0-5: Analytics 10종 이벤트 발화 (로그 확인)
- [x] AC-0-6: Analytics DataStore 미사용
- [x] AC-0-7: 미니게임 아키텍처 설계 문서 존재
- [x] AC-0-8: GameConstants.MINI_GAME 상수 존재
- [ ] AC-0-9: 기존 솔로/Co-op 런 5회 스모크 테스트 통과 [deferred → Sprint 1: Studio 테스트 필요]

### Sprint 1 — 튜토리얼/온보딩 강화 [done]
**목표**: 신규 유저 첫 5런 단계적 안내 시스템 (M2)
**기간**: 1.5주
**피처**: M2
**의존성**: Sprint 0 (M4)

- [ ] TutorialService 5단계 상태 머신 확장
- [ ] PlayerData tutorialProgress 필드 확장
- [ ] GameConstants.TUTORIAL 상수 확장
- [ ] 단계별 서버 트리거 로직
- [ ] TutorialController UI 오버레이
- [ ] NPC 가이드 "코이니"
- [ ] Step5 Co-op 포탈 안내
- [ ] tutorial_step 이벤트 연동
- [ ] 스킵 기능
- [ ] 기존 유저 마이그레이션

**Acceptance Criteria**:
- [ ] AC-1-1: 신규 계정 첫 접속 시 Step1 자동 시작
- [ ] AC-1-2: 각 단계 완료 시 다음 단계 전환
- [ ] AC-1-3: NPC "코이니" 말풍선 표시, 터치 100px+
- [ ] AC-1-4: Step5 완료 후 튜토리얼 완전 비활성화
- [ ] AC-1-5: 스킵 즉시 전 단계 완료 + 서버 저장
- [ ] AC-1-6: v2.2 유저 데이터 로드 에러 0건
- [ ] AC-1-7: tutorial_step 이벤트 발화 확인
- [ ] AC-1-8: 튜토리얼 중 기존 기능 정상 동작

### Sprint 2 — 캐릭터 영구 성장 [done]
**목표**: UpgradeService에 5종 영구 성장 추가 + UI (M3)
**기간**: 2주
**피처**: M3

- [ ] GameConstants UPGRADES.LIST에 5종 추가
- [ ] UpgradeService 효과 계산 확장
- [ ] UpgradeBonuses 타입 확장
- [ ] GameManager 세션 초기화 시 보너스 적용
- [ ] RunSkillService skill_cooldown 적용
- [ ] mini_game_bonus 인터페이스 정의
- [ ] 업그레이드 UI "성장" 탭
- [ ] 레벨별 수치/비용 프리뷰
- [ ] 밸런스 시뮬레이션
- [ ] PlayerData 마이그레이션 검증

**Acceptance Criteria**:
- [ ] AC-2-1: 5종 업그레이드 UI 표시 + 구매 동작
- [ ] AC-2-2: Lv10 만렙 시 MAX 표시 + 추가 구매 차단
- [ ] AC-2-3: base_speed 만렙 시 체감 속도 증가
- [ ] AC-2-4: base_lives 만렙 시 초기 라이프 증가
- [ ] AC-2-5: skill_cooldown 만렙 시 쿨다운 감소
- [ ] AC-2-6: PlayerData 50KB 이하 유지
- [ ] AC-2-7: v2.2 유저 신규 키 기본값 0 초기화
- [ ] AC-2-8: base_speed 만렙 ≤ SPEED_MAX * 1.3

### Sprint 3 — 미니게임: 장애물 러시 + 상태 머신 [done]
**목표**: GameSession 상태 머신 + MiniGameService + 장애물 러시 (M1 전반)
**기간**: 2주
**피처**: M1 (1/2)
**의존성**: Sprint 0 (설계), Sprint 2 (mini_game_bonus)

- [ ] GameSession sessionState 필드 추가
- [ ] GameManager 상태 전환 + pausedDuration 오프셋
- [ ] MiniGameService 신규 생성 (디스패처)
- [ ] MiniGames/ObstacleRush 장애물 러시
- [ ] ChunkService 트리거 포인트 삽입
- [ ] 미니게임 진입 시 후방 청크 해제
- [ ] MiniGameController 전환 연출 + UI
- [ ] mini_game_bonus 적용
- [ ] Co-op 동시 진입 동기화
- [ ] minigame_start/end 이벤트 연동

**Acceptance Criteria**:
- [ ] AC-3-1: sessionState "running"/"minigame" 정상 전환
- [ ] AC-3-2: 미니게임 중 러너 로직 일시정지
- [ ] AC-3-3: 복귀 후 상태 정확히 복원
- [ ] AC-3-4: 장애물 러시 15~30초 내 종료 + 보상
- [ ] AC-3-5: 실패 시 보상 없음 + 라이프 미차감
- [ ] AC-3-6: 10~15청크 주기 트리거
- [ ] AC-3-7: 전환 시 30fps 이상 유지
- [ ] AC-3-8: Co-op 동시 진입

### Sprint 4 — 미니게임: 코인 폭풍 + 통합 QA [done]
**목표**: 코인 폭풍 + M1 전체 안정화 (M1 후반)
**기간**: 1.5주
**피처**: M1 (2/2)
**의존성**: Sprint 3

- [ ] MiniGames/CoinStorm 코인 폭풍
- [ ] MiniGameController 코인 폭풍 UI/이펙트
- [ ] MiniGameService 선택 로직 (교대/가중 랜덤)
- [ ] 난이도 스케일링 (Zone 기반)
- [ ] Co-op 코인 폭풍 동기화
- [ ] 전체 미니게임 통합 QA
- [ ] 보상 밸런스 조정
- [ ] 성능 프로파일링

**Acceptance Criteria**:
- [ ] AC-4-1: 코인 폭풍 정상 동작
- [ ] AC-4-2: 연속 같은 미니게임 3회 금지
- [ ] AC-4-3: 솔로 10회 연속 크래시 0건
- [ ] AC-4-4: Co-op 5회 동기화 실패 0건
- [ ] AC-4-5: 보상 = 1런 코인의 10~20%
- [ ] AC-4-6: 메모리 스파이크 10MB 이하

### Sprint 5 — 스킬/능력 시스템 [done]
**목표**: RunSkillService에 액티브 스킬 3종 (S2)
**기간**: 1.5주
**피처**: S2
**의존성**: Sprint 2 (M3)

- [ ] GameConstants.ACTIVE_SKILLS 상수
- [ ] RunSkillService 액티브 슬롯 + 쿨다운 로직
- [ ] PlayerData equippedActiveSkill 필드
- [ ] 스킬 해금 조건 (영구 성장 레벨 기반)
- [ ] GameManager 스킬 효과 적용
- [ ] 서버 task.delay 쿨다운 관리
- [ ] SkillController 발동 버튼 UI
- [ ] 스킬 장착 UI
- [ ] 효과 중첩 테스트
- [ ] 미니게임 중 비활성화

**Acceptance Criteria**:
- [ ] AC-5-1: 3종 정상 발동 (dash/shield/magnet_burst)
- [ ] AC-5-2: 쿨다운 중 재발동 불가 + 타이머 표시
- [ ] AC-5-3: 해금 미충족 시 장착 불가
- [ ] AC-5-4: skill_cooldown Lv10 시 쿨다운 ~30% 감소
- [ ] AC-5-5: 패시브+액티브+파워업 3종 동시 충돌 없음
- [ ] AC-5-6: 서버 검증 (쿨다운/보유/상태)
- [ ] AC-5-7: 미니게임 중 비활성화

### Sprint 6 — 랜덤 이벤트 + 일일 도전 [done]
**목표**: 랜덤 이벤트 5종(S1) + 일일 도전 3개(S3)
**기간**: 1.5주
**피처**: S1, S3
**의존성**: Sprint 4 (M1), Sprint 0 (M4)

- [ ] GameConstants.RANDOM_EVENTS 상수
- [ ] RandomEventService 신규 생성
- [ ] GameManager 통합
- [ ] RandomEventController 시각 효과
- [ ] 미니게임 중 이벤트 비활성화
- [ ] DailyChallengeService 신규 생성
- [ ] GameConstants.DAILY_CHALLENGES 상수
- [ ] BattlePassService XP 연동
- [ ] DailyChallengeController UI
- [ ] PlayerData dailyChallenges 필드

**Acceptance Criteria**:
- [ ] AC-6-1: 평균 20초마다 이벤트 발생
- [ ] AC-6-2: 5종 각각 시각+게임플레이 효과 동작
- [ ] AC-6-3: 이벤트 종료 후 효과 완전 해제
- [ ] AC-6-4: 미니게임 중 이벤트 미발생
- [ ] AC-6-5: 매일 3개 과제 + 00:00 UTC 리셋
- [ ] AC-6-6: 도전 완료 시 배틀패스 XP 지급
- [ ] AC-6-7: 도전 진행률 실시간 업데이트
- [ ] AC-6-8: PlayerData 50KB 이하 유지

### Sprint 7 — 솔로 보강 + 최종 QA [done]
**목표**: 솔로 최적화(S4) + v3 전체 회귀 테스트 + 소프트 론치 준비
**기간**: 1주
**피처**: S4, QA

- [ ] 솔로 미니게임 빈도/보상 최적화
- [ ] 솔로 랜덤 이벤트 빈도/강도 최적화
- [ ] Co-op UI 솔로 미노출 확인
- [ ] 전체 회귀 테스트 매트릭스 실행
- [ ] 30분 연속 성능 프로파일링
- [ ] PlayerData 크기 최종 검증
- [ ] GameConstants 밸런스 리뷰
- [ ] 소프트 론치 체크리스트

**Acceptance Criteria**:
- [ ] AC-7-1: 솔로 10회 연속 크래시 0건
- [ ] AC-7-2: Co-op 5회 동기화 실패 0건
- [ ] AC-7-3: 튜토리얼 풀 플로우 에러 0건
- [ ] AC-7-4: 30분 연속 30fps 이상
- [ ] AC-7-5: PlayerData 만렙 상태 50KB 이하
- [ ] AC-7-6: 회귀 테스트 매트릭스 전 항목 PASS
- [ ] AC-7-7: Analytics 10종 발화 확인
- [ ] AC-7-8: ProductId 3건 결제 테스트 통과

---

## Sprint 타임라인

```
Week  1      2      3      4      5      6      7      8      9     10     11
      |------||----------||------------------||------------------||---------|
      Sprint0  Sprint 1    Sprint 2            Sprint 3            Sprint 4
      M5+M4    M2          M3                  M1(1/2)             M1(2/2)
      +설계    튜토리얼     영구성장             미니게임-러시        미니게임-폭풍

Week 11     12     13     14
      |----------||----------||------|
       Sprint 5    Sprint 6    Sprint 7
       S2          S1+S3       S4+QA
       스킬        이벤트+도전   최종검증
```

**총 기간**: ~12~14주

---

## 의존성 다이어그램

```
Sprint 0 (M5+M4+설계)
    |
    +---> Sprint 1 (M2 튜토리얼) -- M4 의존
    |
    +---> Sprint 2 (M3 영구성장) -- 독립
    |         |
    |         +---> Sprint 5 (S2 스킬) -- M3 의존
    |
    +---> Sprint 3 (M1 전반 미니게임) -- 설계+M3 의존
              |
              +---> Sprint 4 (M1 후반 미니게임)
                        |
                        +---> Sprint 6 (S1+S3 이벤트+도전) -- M1 의존
                                  |
                                  +---> Sprint 7 (S4+QA)
```

---

## 위험 신호 & 대응

| 위험 | 심각도 | 대응 |
|------|:---:|------|
| GameSession 상태 머신 전환 시 시간 로직 오동작 | High | `getAdjustedTime()` 헬퍼로 통일. pausedDuration 오프셋 |
| 미니게임+이벤트+스킬 3종 동시 활성 충돌 | High | 미니게임 중 이벤트/스킬 비활성화 원칙 |
| PlayerData 50KB 초과 | Med | 매 Sprint 크기 측정. 일일도전 히스토리 미저장 |
| 튜토리얼 기존 유저 강제 재실행 | Med | tutorialCompleted=true 유저 전 단계 완료 처리 |
| base_speed 만렙 P2W | Med | SPEED_MAX * 1.3 상한선 |
| Co-op 미니게임 동기화 실패 | Med | 세션 레벨 트리거 (청크 레벨 아님) |
| 중력 반전 8세 혼란 | Med | 지속 8초 최소 + NPC 경고 |
| dash 맵 이탈 | Low | 청크 내 이동 제한 + 경계 클램핑 |

---

## v3.1 구현 단계

### Sprint 0 — 모바일 UI 최적화 [done]
**목표**: 게임 플레이 중 화면에 표시되는 UI 요소를 핵심 정보(생명, 점수, 코인, 조작 버튼)로 축소하여 6~12세 모바일 유저의 정보 과부하를 해소하고, 좌측 엄지 영역을 확보한다.
**기간**: 3일
**피처**: ISSUE-005
**의존성**: none

- [x] S0-1: UIVisibilityManager 모듈 신설 — 게임 상태(lobby/running/minigame/paused)별 ScreenGui Enabled 일괄 제어
- [x] S0-2: DailyChallengeController 게임 중 숨김 — 로비에서만 Visible, GameStart 시 Enabled=false
- [x] S0-3: ObjectiveHudController 축소 모드 — 게임 시작 3초 후 아이콘(48px) 모드 자동 축소, 탭 시 1.5초 펼침
- [x] S0-4: ProgressionController 레벨/XP 바 게임 중 숨김 — LevelContainer+MissionButton Visible=false, 레벨업 토스트만 표시
- [x] S0-5: RunSkillHudController XP 바 게임 중 숨김 — 스킬 레벨업 시에만 2초 토스트
- [x] S0-6: HUD 레이아웃 재배치 — 좌측 화면 비움, ActiveSkill 버튼을 우측 하단(Jump 상단)으로 이동
- [x] S0-7: 터치 타겟 최소 48px 검증 — UITokens.Touch.MIN_TARGET_SIZE = 48 상수, 전 버튼 검증
- [x] S0-8: ResponsiveUtil compactMode — 화면 너비 500px 미만 시 HUD 추가 축소
- [x] S0-9: 스모크 테스트 체크리스트 작성 — docs/test/sprint0-smoke-test.md

**Acceptance Criteria**:
- [ ] AC-0-1: 게임 중(running) 동시 표시 UI 프레임 최대 3개 이하 (HudFrame, 터치버튼, 스킬버튼)
- [ ] AC-0-2: DailyChallengeGui는 로비에서만 표시, GameStart 이후 미노출
- [ ] AC-0-3: ObjectiveHUD 게임 시작 3초 후 아이콘 모드 자동 축소, 탭 시 펼침→1.5초 후 재축소
- [ ] AC-0-4: ProgressionController LevelContainer+MissionButton 게임 중 Visible=false, 레벨업 토스트만 표시
- [ ] AC-0-5: 모든 인터랙티브 터치 타겟 히트 영역 48x48px 이상
- [ ] AC-0-6: 화면 좌측 50%에 게임 중 상시 UI 없음 (SlideButton 제외, 엄지 영역 확보)
- [ ] AC-0-7: UIVisibilityManager가 lobby/running/minigame 3개 상태에서 올바른 UI set만 Enabled
- [ ] AC-0-8: iPhone SE(375x667) 해상도에서 HUD 요소 간 겹침 0건

### Sprint 1 — 존 전환 시각 연출 + 배경 시차 스크롤 [done]
**목표**: Zone 전환 시 극적 연출(IDEA-001) + 배경 원경/중경 시차 스크롤(IDEA-002)
**커밋**: e6f92d6
**피처**: IDEA-001, IDEA-002

**Acceptance Criteria**:
- [x] Zone 전환 시 0.3s 컬러 플래시 발생
- [x] ZoneLabel 바운스 애니메이션 (Back EasingStyle)
- [x] ParallaxController 원거리 0.15x / 중거리 0.40x 시차 동작

### Sprint 2 — 2층 분기 맵 Dual-Floor MVP [done]
**목표**: 점프 진입 2층 보너스 구간 (IDEA-003)
**커밋**: 395257e
**피처**: IDEA-003

**Acceptance Criteria**:
- [x] 2층 청크 30초+ 이후 ~10% 확률 등장
- [x] 진입 경사로 캐릭터 걸림 없음 (WedgePart, 24도)
- [x] 2층 끝에서 자동 낙하
- [x] CameraController Y 소프트 팔로우

### Sprint 3 — 이동 장애물 2종 [done]
**목표**: RotatingBar + FallingDebris 장애물 추가 (IDEA-004)
**커밋**: 5a1549f
**피처**: IDEA-004

**Acceptance Criteria**:
- [x] RotatingBar TweenService 1.5s 회전
- [x] FallingDebris 3연속 스태거 낙하
- [x] Hard 구간 전용, ACTION_HINT_MAP 등록

### Sprint 4 — 챕터 연동 맵 테마 [done]
**목표**: 진행 중인 챕터의 accentColor를 레일/바닥에 Lerp tint (IDEA-005)
**커밋**: 2d93bda
**피처**: IDEA-005

**Acceptance Criteria**:
- [x] 챕터별 레일/바닥라인 색상 35~40% Lerp tint
- [x] Zone 테마 우선, 챕터 오버레이 방식

### Sprint 5 — 보스런 전용 맵 스타일 MVP [done]
**목표**: 보스런 진입 시 붉은 틴트 + 안개 연출 (IDEA-006)
**커밋**: 048cb45
**피처**: IDEA-006

**Acceptance Criteria**:
- [x] 보스런 진입 시 ColorCorrectionEffect 활성화
- [x] FogEnd 200 감소 (가시거리 축소)
- [x] 보스런 종료 시 원복

### Sprint 6 — 환경 날씨 파티클 [done]
**목표**: Zone별 5종 날씨 파티클 (IDEA-007)
**커밋**: 5037ca6
**피처**: IDEA-007

**Acceptance Criteria**:
- [x] Zone별 전용 파티클 (sparkles/petals/spores/dust/stars)
- [x] MaxParticles 50 이하, 플레이어 위 18 studs 추적
- [x] ZoneController + ParallaxController + WeatherController 3중 동기화

### Sprint 7 — 코인 도형 패턴 5종 [done]
**목표**: 수학 함수 대신 인식 가능한 도형 좌표 테이블 방식으로 교체 (IDEA-008)
**커밋**: 7fa0848
**피처**: IDEA-008

**Acceptance Criteria**:
- [x] 5종 도형 패턴 (↑↓♥★◆) 청크에서 등장
- [x] 패턴이 시각적으로 인식 가능한 형태

### Sprint 8 — zone별 장식 프롭 시스템 [done]
**목표**: 청크당 0~6개 CanCollide=false 장식 프롭 자동 배치 (IDEA-009)
**커밋**: 01d1ef1
**피처**: IDEA-009

**Acceptance Criteria**:
- [x] Zone별 PROP_PALETTE (꽃/버섯/수정/등불 등 9종)
- [x] CanCollide=false, 게임플레이 영향 없음

### Sprint 9 — Encounter 라이브러리 + 장애물-코인 동시 설계 [done]
**목표**: 장애물-코인 세트 5종으로 학습 루프 형성 (IDEA-010)
**커밋**: c2a0614
**피처**: IDEA-010

**Acceptance Criteria**:
- [x] EncounterTemplate{obstacles, coins} 5종 구현
- [x] 장애물 이후 보상 코인 배치 확인

### Sprint 10 — Phrase 기반 청크 시퀀싱 [done]
**목표**: 2~5청크 단위 리듬 Phrase로 설계된 난이도 흐름 (IDEA-011)
**커밋**: c1f7d24
**피처**: IDEA-011

**Acceptance Criteria**:
- [x] Phrase 큐 기반 청크 순서 생성
- [x] breathing/mercy 시스템 호환

### Sprint 11 — 청크 연결부 폴리싱 [done]
**목표**: 청크 간 경사로 S-커브 + 전환 게이트 아치 (IDEA-012)
**커밋**: 8d271a1
**피처**: IDEA-012

**Acceptance Criteria**:
- [x] _createRamp → 3-Part 베지어 S-커브 (시작/중간/끝 파트)
- [x] _createTransitionGate 아치 게이트 (Zone 경계 시각화)
- [x] GameConstants.CHUNK_TRANSITION 상수 추가

### Sprint 12 — 다중 높이 플랫폼 MVP [done]
**목표**: LOW(Y=0)/HIGH(Y=12) 2-레인 멀티플랫폼 (IDEA-013)
**커밋**: 04834e6
**피처**: IDEA-013

**Acceptance Criteria**:
- [x] LOW(너비20)/HIGH(너비12) 2-레인 생성, 45s+ 7% 확률 등장
- [x] HIGH 레인 Gold 코인 40% 고밀도 배치
- [x] CameraController Y 팔로우 가중치 0.4 적용

### Sprint 13 — 챕터 2→3 전환 버그 픽스 [pending]
**목표**: 챕터 2 퀘스트 완료 후 챕터 3이 언락되지 않는 버그 수정 (ISSUE-023)
**이슈**: ISSUE-023 (P1-high)

**Acceptance Criteria**:
- [ ] 챕터 2 퀘스트 전체 완료 시 챕터 3 자동 언락
- [ ] 서버 콘솔에 `[ScenarioService] _completeChapter ch2` 로그 출력
- [ ] 클라이언트에 `ChapterUnlocked` 이벤트 정상 수신 + UI 표시
- [ ] 보스런 비활성화 상태에서도 챕터 완료 처리 가능 (우회 경로 확보)
- [ ] 챕터 1 완료 플래그가 정상 설정되어 있는지 검증

**주요 확인 파일**:
- `src/server/Services/ScenarioService.luau` — `_checkChapterCompletion`, `_completeChapter`
- `src/server/Services/BossRunService.luau` — 보스런 완료 → TriggerChapterCompletion
- `src/shared/Constants/ScenarioConstants.luau` — ch3.unlockConditions
- `src/client/Controllers/ScenarioController.luau` — ChapterUnlocked 구독 여부

### Sprint 14 — 코인/장애물 시각 구분 + 단조로움 개선 [pending]
**목표**: 코인 글로우 추가 + 장애물 위협 연출 + 존별 분위기 강화 (ISSUE-032)
**이슈**: ISSUE-032 (P2-medium)

**Acceptance Criteria**:
- [ ] 코인 파트에 Highlight 인스턴스 추가 (OutlineColor=Gold, FillTransparency=1)
- [ ] 코인에 PointLight 부착 (Brightness=0.5, Range=8)
- [ ] 장애물 파트에 빨강/주황 경고 Texture 또는 Decal 추가
- [ ] 이동 장애물(RotatingBar/FallingDebris)에 Neon 경고등 파트 깜빡임 연출
- [ ] 최소 3개 Zone에서 환경 조명 색온도 차별화 확인
- [ ] 코인 수집 시 소형 파티클 버스트 (10개 중 1개 확률)
- [ ] 성능 영향 없음 (MaxParticles 합산 100 이하)

**주요 파일**:
- `src/server/Services/CoinService.luau` — 코인 생성 시 Highlight/PointLight 추가
- `src/server/Services/ProceduralChunkGenerator.luau` — `_createObstacle()` 경고 연출
- `src/shared/Constants/GameConstants.luau` — 시각 상수 추가 (COIN_GLOW, OBSTACLE_WARNING)

### Sprint 15 — 특수 효과 코인 3종 MVP [pending]
**목표**: Star·Magnet·Rainbow 특수 코인 구현 (ISSUE-033 1단계)
**이슈**: ISSUE-033 (P2-medium)

**스코프**: Bomb(어려움)·Crystal(경제 시스템 연계)은 제외 — 다음 버전 검토

**Acceptance Criteria**:
- [ ] **Star** ⭐ — 수집 시 콤보 +5 즉시 추가 (Fever 촉진)
- [ ] **Magnet** 🧲 — 수집 후 3초간 자동수집 범위 2× (기존 magnetBonus와 중첩)
- [ ] **Rainbow** 🌈 — 수집 후 2초간 수집 코인 점수 2× (서버 상태 플래그)
- [ ] 스폰 확률: Star 12% / Magnet 6% / Rainbow 5% (나머지 77% 일반)
- [ ] 각 타입별 고유 색상·외형으로 일반 코인과 즉시 구분 가능
- [ ] 특수 코인 수집 시 전용 사운드 or 파티클 연출
- [ ] `GameConstants.SPECIAL_COINS` 상수 정의 (확률·지속시간·배율)

**주요 파일**:
- `src/server/Services/CoinService.luau` — 특수 코인 타입 분기 생성 + 수집 처리
- `src/shared/Constants/GameConstants.luau` — SPECIAL_COINS 상수 블록
- `src/server/Services/GameManager.luau` — 특수 코인 수집 이벤트 핸들러
- `src/client/Controllers/PlayerController.luau` — Magnet 범위 임시 확대 처리

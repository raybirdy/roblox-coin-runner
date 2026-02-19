# Coin Runner v1.0 출시 작업 내역서

## 프로젝트 개요

| 항목 | 내용 |
|------|------|
| 게임명 | Coin Runner (코인 러너) |
| 장르 | 횡스크롤 코인 수집 러너 |
| 타겟 | 6~12세 |
| 플랫폼 | Roblox (PC + Mobile) |
| 언어 | Luau |
| 개발 기간 | PR #1 ~ PR #53 |
| 현재 상태 | **v1.0 퍼블리싱 준비 완료** |

---

## 1. 완성된 기능 목록

### 1.1 코어 게임플레이

| 기능 | 설명 | 관련 PR |
|------|------|---------|
| 자동 달리기 | 속도 35→55 studs/s (90초간 EaseOutQuad 가속) | #1~#5 |
| 2단 점프 | 1단 8 studs, 2단 +5 studs | #6~#8 |
| 홀드 슬라이드 | 버튼 누르는 동안 슬라이드 유지, 최대 3초 | #49, #53 |
| 사이드뷰 카메라 | 측면 고정 카메라, 부드러운 추적 | #47 |
| Z축 고정 | AlignPosition 기반 2D 평면 잠금 | #3 |

### 1.2 레벨 시스템

| 기능 | 설명 | 관련 PR |
|------|------|---------|
| 청크 기반 월드 | 80x40 studs 단위, 최대 6개 동시 로드 | #9~#12 |
| 절차적 생성 | Easy/Normal/Hard/Bonus/NPC 난이도 분배 | #13~#15 |
| 시간 기반 난이도 | 0~30초 Easy 위주 → 180초+ Hard 45% | #15 |
| 배경 시스템 | 관중, 풍경 파트 자동 생성 | #25 |

### 1.3 장애물 (4종)

| 장애물 | 회피 방법 | 색상 | 관련 PR |
|--------|----------|------|---------|
| LowWall | 점프 | 빨강 | #10 |
| Tunnel | 슬라이드 | 파랑 | #10 |
| SpikeTrap | 점프 | 빨강 | #14 |
| Gap (구덩이) | 점프 | 주황 테두리 | #14 |

### 1.4 코인 시스템

| 코인 | 가치 | 출현 확률 (일반) |
|------|------|-----------------|
| Bronze | 1 | 79% |
| Silver | 5 | 15% |
| Gold | 10 | 5% |
| Diamond | 50 | 1% |

- 클라이언트 측 선제 감지로 즉시 이펙트 (PR #53)
- 파티클 풀링 (5개 사전 할당)
- 자석 파워업 연동 (수집 반경 확대)

### 1.5 점수 시스템

| 점수 소스 | 값 |
|----------|-----|
| 거리 | 1 stud = 1점 |
| 코인 | 코인 가치만큼 |
| 니어미스 | +5 |
| 콤보 10/30/50 | 각 1회 보너스 |

### 1.6 생존 시스템

- 3 라이프 (피격 시 빨간 플래시 + 무적 2초)
- 무료 부활 1회 (속도 감소 후 점진 회복)
- 위로 보상: 3연속 게임오버 시 +20 코인
- 자비 청크: 2연속 피격 시 Easy 청크 보장

### 1.7 NPC 시스템

| NPC | 역할 | 메시지 |
|-----|------|--------|
| Rabbit (분홍) | 응원 | 6종 |
| Bear (갈색) | 격려 | 6종 |
| Owl (갈색) | 튜토리얼 | 4종 |

### 1.8 튜토리얼

- 첫 플레이 시 자동 시작
- Owl NPC 가이드 (점프/슬라이드 안내)
- 슬로모션 구간 (장애물 앞에서 감속)
- 완료 후 다시 표시 안 함

---

## 2. 로비 시스템

| 요소 | 위치/크기 |
|------|----------|
| 로비 바닥 | 200x80 studs |
| 스폰 위치 | (-160, 2.5, 0) |
| 게임 포탈 | (-25, 3, 0) - 보라색 |
| 상점 NPC | (-100, 5, 28) |
| 리더보드 | (-100, 5, -28) |

- 자유 이동 + 카메라 회전 (게임 중에는 잠금)
- 장식물: 나무, 꽃, 벤치, 가로등, 분수, 풍선

---

## 3. 상점 & 수익화

### 3.1 스킨 시스템 (12종)

**코인 스킨 (7종)** - 게임 내 코인으로 구매:

| 스킨 | 가격 |
|------|------|
| Blue Cape | 100 코인 |
| Red Warrior | 200 코인 |
| Green Scout | 150 코인 |
| Gold Knight | 500 코인 |
| Purple Wizard | 300 코인 |
| White Angel | 400 코인 |
| Black Ninja | 350 코인 |

**프리미엄 스킨 (5종)** - 젬으로 구매:

| 스킨 | 가격 |
|------|------|
| Rainbow | 200 젬 |
| Galaxy | 300 젬 |
| Ice Crystal | 150 젬 |
| Fire Dragon | 400 젬 |
| Neon Cyber | 80 젬 |

### 3.2 시작 파워업

| 파워업 | 가격 | 효과 |
|--------|------|------|
| Magnet | 50 코인 | 5초 자석 |
| Shield | 80 코인 | 1회 보호 |
| 2x Coins | 100 코인 | 2배 코인 |

### 3.3 젬 패키지 (DevProduct)

| 패키지 | ProductId | 가격 | 젬 |
|--------|-----------|------|-----|
| 50 Gems | 3540343000 | 25 Robux | 50 |
| 200 Gems (+50) | 3540343177 | 75 Robux | 200+50 |
| 500 Gems (+150) | 3540343329 | 149 Robux | 500+150 |
| Starter Pack | 3540343511 | 49 Robux | 100+Pet |

### 3.4 VIP GamePass

| 항목 | 값 |
|------|-----|
| GamePass ID | 1720352633 |
| 효과 | 코인 2배 (영구) |
| 권장 가격 | 299 Robux |

---

## 4. 진행도 시스템

### 4.1 레벨 (20단계)

- XP 소스: 게임 참여(10), 100점당(5), 미션 완료(15)
- 마일스톤 레벨 (5/10/15/20): 젬 보상
- 레벨업 시 코인 보상

### 4.2 일일 미션 (매일 3개)

| 미션 유형 | 예시 |
|----------|------|
| play_games | 게임 3/5/7회 플레이 |
| collect_coins | 코인 50/100/200개 수집 |
| score_reach | 점수 500/1000/2000 달성 |
| near_miss | 니어미스 5/10/15회 |
| combo_reach | 콤보 10/20/30 달성 |
| distance_run | 거리 500/1000/2000 달리기 |

### 4.3 업적 (16종)

- 카테고리: 게임 참여, 점수, 코인, 거리, 레벨
- 보상: 젬 + XP
- 달성 시 클라이언트 알림 배너

### 4.4 리더보드

- 전체(ALL) / 일간(DAILY) / 주간(WEEKLY) 탭
- OrderedDataStore 기반
- 로비에서 상시 표시

---

## 5. 기술 인프라

### 5.1 보안 (PR #50)

| 항목 | 구현 |
|------|------|
| 입력 검증 | 모든 OnServerEvent 핸들러에 런타임 타입 체크 |
| 레이트 리미팅 | RateLimiter 유틸리티, 13개 핸들러 적용 |
| Studio 분리 | RunService:IsStudio() 가드 (프로덕션 무료 지급 차단) |
| 영수증 영구화 | DataStore 기반 구매 중복 방지 |
| 딥카피 | PlayerData 테이블 참조 버그 수정 |

### 5.2 데이터 저장

- DataStore 기반 플레이어 데이터 영구 저장
- 퇴장 시 저장 + 서버 종료 시 전체 저장
- processedReceipts 최대 50개 유지

### 5.3 클라이언트-서버 아키텍처

```
[클라이언트]                    [서버]
InputController ──→ RemoteEvent ──→ GameManager
PlayerController                    CoinService
CameraController                    ObstacleService
UIController     ←── RemoteEvent ←── PlayerDataService
CoinController                      ShopService
AnimationController                 MonetizationService
```

- 서버 권위 모델 (점수, 코인, 구매 모두 서버 검증)
- 클라이언트는 입력/시각 효과만 담당
- 코인 수집만 클라이언트 선제 감지 (이펙트 타이밍용)

### 5.4 모바일 지원

- 터치 스와이프 (동적 임계값: 화면 높이 8%)
- 120px 터치 버튼 (점프/슬라이드)
- MouseButton1Down 즉각 반응 (Click 대비 빠름)
- 이중 트리거 방지 (80ms debounce)
- 기본 Roblox 컨트롤 비활성화

---

## 6. 파일 구조

```
src/
├── server/
│   ├── init.server.luau              # 서버 진입점
│   └── Services/
│       ├── GameManager.luau          # 메인 게임 루프
│       ├── PlayerDataService.luau    # 데이터 저장/로드
│       ├── CoinService.luau          # 코인 생성/수집
│       ├── ObstacleService.luau      # 장애물 생성
│       ├── ChunkService.luau         # 청크 관리
│       ├── ProceduralChunkGenerator.luau  # 청크 절차 생성
│       ├── PowerupService.luau       # 파워업 처리
│       ├── NPCService.luau           # NPC 생성
│       ├── BackgroundService.luau    # 배경 생성
│       ├── ShopService.luau          # 상점 로직
│       ├── MonetizationService.luau  # 수익화 처리
│       ├── LobbyService.luau         # 로비 설정
│       ├── LeaderboardService.luau   # 리더보드
│       ├── ProgressionService.luau   # 레벨/미션/업적
│       └── TutorialService.luau      # 튜토리얼 상태
├── client/
│   ├── init.client.luau              # 클라이언트 진입점
│   └── Controllers/
│       ├── PlayerController.luau     # 캐릭터 이동
│       ├── InputController.luau      # PC/모바일 입력
│       ├── CameraController.luau     # 사이드뷰 카메라
│       ├── UIController.luau         # 메인 HUD
│       ├── CoinController.luau       # 코인 이펙트
│       ├── AnimationController.luau  # 애니메이션
│       ├── LifeController.luau       # 체력 표시
│       ├── PowerupController.luau    # 파워업 시각효과
│       ├── ShopController.luau       # 상점 UI
│       ├── LeaderboardController.luau # 리더보드 UI
│       ├── ProgressionController.luau # 진행도 UI
│       ├── StartPowerupController.luau # 시작 파워업 UI
│       ├── NPCController.luau        # NPC 렌더링
│       ├── TutorialController.luau   # 튜토리얼 UI
│       ├── MusicController.luau      # BGM
│       └── SpeedEffectController.luau # 속도 연출
└── shared/
    ├── Constants/GameConstants.luau   # 전체 게임 상수
    ├── RemoteEvents.luau             # 서버-클라이언트 통신
    └── Utils/
        ├── RateLimiter.luau          # 요청 제한
        └── ResponsiveUtil.luau       # 반응형 UI
```

---

## 7. PR 히스토리 요약

| 단계 | PR 범위 | 주요 작업 |
|------|---------|----------|
| 코어 게임플레이 | #1~#14 | 이동, 코인, 장애물, 청크, 카메라 |
| 로비 & 배경 | #15~#25 | 로비 시스템, 배경, 상점 기초 |
| 수익화 P0 | #26~#35 | 젬/VIP/상점/스킨 시스템 |
| 수익화 확장 | #36~#42 | 모바일 최적화, 리더보드, 시작 파워업 |
| 진행도 시스템 | #41~#45 | 레벨, 일일 미션, 업적, 위로보상 |
| 최종 폴리시 | #46~#53 | 사이드뷰 카메라, 배포 보안, 슬라이드 수정 |

---

## 8. 알려진 미해결 사항 (비블로킹)

| 항목 | 심각도 | 설명 |
|------|--------|------|
| 자동 저장 | Warning | 현재 퇴장 시만 저장 (주기적 저장 미구현) |
| SetAsync | Warning | UpdateAsync 미전환 (데이터 경합 가능성 낮음) |
| 콤보 미션 | Warning | score_reach 미션이 누적이 아닌 단일 게임 최고치로 판정 |
| 모바일 UI | Info | 반응형 프레임 크기 조정 미적용 (계획 수립 완료) |

---

*작성일: 2026-02-19*
*총 PR: 53개 머지 완료*
*상태: 퍼블리싱 준비 완료*

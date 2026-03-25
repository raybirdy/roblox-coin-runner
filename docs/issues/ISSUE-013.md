---
id: ISSUE-013
title: "Giant Mode / Coin Rain 랜덤 이벤트 미작동 — 서버 플래그 미소비 + 클라이언트 효과 미구현"
category: bug
priority: P1-high
status: resolved
related_sprint: none
related_ac: none
created: 2026-03-25
resolved: 2026-03-25
---

## 설명
랜덤 이벤트 `giant_mode`와 `coin_rain` 발동 시 실제 게임 효과가 나타나지 않음:
- **Giant Mode**: 캐릭터가 커지지 않음 (시각적 변화 없음)
- **Coin Rain**: 코인 비가 내리지 않음 (화면 틴트만 적용)

## 영향 분석

### Bug 1: Giant Mode — 캐릭터 스케일링 실패
- **서버** (`RandomEventService.luau:122`): `session._giantScaleFactor = 1.8` 설정하나 **GameManager가 이 값을 읽지 않음** (dead store)
- **클라이언트** (`RandomEventController.luau:58-71`): `BodyHeightScale`만 트윈 시도
  - **문제 1**: R6 또는 커스텀 리그에는 `BodyHeightScale` NumberValue가 없어 `FindFirstChild` → nil → 전체 블록 스킵
  - **문제 2**: `BodyWidthScale`, `BodyDepthScale` 미변경 → 높이만 늘어나는 비정상 스케일링
  - **문제 3**: 서버 권위적 스케일링 없이 클라이언트만 변경 → 히트박스/충돌 불일치

### Bug 2: Coin Rain — 효과 미구현 (스텁)
- **서버** (`RandomEventService.luau:118`): `session._coinRainActive = true` 설정하나 **코드베이스 전체에서 이 플래그를 읽는 곳이 없음**
- **클라이언트** (`RandomEventController.luau:50-52`): 골든 색상 보정 틴트만 적용, **코인 스폰/비주얼 코드 없음**
- **CoinWaterfall** (`ChunkService.luau:299-307`)은 별도 청크 이벤트로 `coin_rain`과 무관
- config에는 `effect = "double_coin_spawn"` 정의되어 있으나 이를 실행하는 로직 부재

### 추가 의심: speed_shift 이벤트
- `_speedShiftMultiplier` 세션 플래그도 동일하게 dead store일 가능성 높음 — 추가 검증 필요

### 관련 파일
| 파일 | 라인 | 역할 |
|------|------|------|
| `src/server/Services/RandomEventService.luau` | 116-143 | 세션 플래그 설정 (dead store) |
| `src/client/Controllers/RandomEventController.luau` | 50-71 | 클라이언트 효과 (미완성) |
| `src/server/Services/GameManager.luau` | — | `_coinRainActive` / `_giantScaleFactor` 미참조 |
| `src/server/Services/CoinService.luau` | — | 코인 레인 스폰 로직 부재 |
| `src/shared/Constants/GameConstants.luau` | 2417-2438 | 이벤트 config 정의 (정상) |

### 의존성
- 캐릭터 리그 타입 (R6/R15/커스텀) 확인 필요
- ObstacleService 충돌 판정: Giant 모드 시 히트박스 조정 필요 (`isMini` 파라미터의 역방향)
- 랜덤 이벤트 전체 파이프라인 검증 권장 (speed_shift 포함)

## 해결 방안
GameManager에서 RandomEvent 세션 플래그 소비 로직 추가 (_coinRainActive → 코인 2배, _giantScaleFactor → 서버측은 시각 전용 유지).
클라이언트 Giant Mode: 3축(Height/Width/Depth/Head) 모두 스케일링.
클라이언트 Coin Rain: 금색 코인 파트 낙하 이펙트 추가.

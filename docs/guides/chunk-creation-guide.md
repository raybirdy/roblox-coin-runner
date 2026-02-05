# 청크 템플릿 제작 가이드

> **Task #12: 청크 템플릿 제작**
> Roblox Studio에서 청크 모델을 직접 제작하는 방법

## 목차

1. [개요](#개요)
2. [준비 작업](#준비-작업)
3. [청크 기본 구조](#청크-기본-구조)
4. [난이도별 청크 제작](#난이도별-청크-제작)
5. [속성 설정](#속성-설정)
6. [코인/장애물/NPC 배치](#코인장애물npc-배치)
7. [체크리스트](#체크리스트)
8. [예시 청크](#예시-청크)

---

## 개요

### 왜 청크 템플릿이 필요한가?

Coin Runner는 **청크 기반 무한 생성** 방식을 사용합니다. 미리 만든 청크를 랜덤으로 이어붙여 끝없는 맵을 만듭니다.

### MVP 목표

| 난이도 | 최소 개수 | 권장 개수 |
|--------|-----------|-----------|
| Easy | 5개 | 8개 |
| Normal | 5개 | 8개 |
| Hard | 3개 | 5개 |
| Bonus | 2개 | 3개 |
| NPC | 2개 | 3개 |
| **합계** | **17개** | **27개** |

---

## 준비 작업

### 1. Rojo 서버 실행

```bash
cd /Users/parkjongha/Documents/git/roblox-coin-runner
rojo serve
```

### 2. Roblox Studio 열기

1. Roblox Studio 실행
2. Rojo 플러그인 클릭 → "Connect" 버튼
3. 프로젝트가 로드되면 ServerStorage 확인

### 3. Chunks 폴더 확인

- **ServerStorage** → **Chunks** 폴더가 있어야 함
- 없으면 ServerStorage에서 우클릭 → Insert Object → Folder → 이름을 "Chunks"로 변경

---

## 청크 기본 구조

### 청크 사양

| 항목 | 값 |
|------|-----|
| **청크 길이** | 80 studs |
| **청크 높이** | 40 studs (플레이 가능 영역) |
| **바닥 높이** | Y = 0 기준선 |
| **원점** | 청크 왼쪽 하단 = (0, 0, 0) |

### 청크 생성 단계

1. **Model 생성**
   - Workspace에서 우클릭 → Insert Object → Model
   - 이름: `Chunk_Easy_01` (난이도_번호 형식)

2. **바닥 생성**
   - Insert Object → Part
   - Size: `(80, 1, 20)` (길이 × 높이 × 폭)
   - Position: `(40, 0, 0)` (청크 중앙)
   - Anchored: **true** (체크)
   - Color: 밝은 초록 (잔디)

3. **PrimaryPart 설정**
   - Model 선택
   - Properties → PrimaryPart → 바닥 Part 선택

---

## 난이도별 청크 제작

### Easy 청크 (쉬움)

**특징:**
- 장애물 0~1개
- 코인 많음 (브론즈 위주)
- 휴식 구간

**예시: Easy-01 "코인 파티"**

```
청크 구조:
○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○
────────────────────────────────────────────
(장애물 없음, 브론즈 코인 직선 라인)
```

**제작 방법:**
1. 바닥 Part 생성 (80×1×20)
2. 코인 스폰 마커 배치:
   - 16개의 Part 생성 (Transparency = 1, 투명)
   - Size: (1, 1, 1)
   - 5 studs 간격으로 일렬 배치
   - 각 Part에 속성 추가: `CoinType = "Bronze"`
   - CollectionService 태그 추가: `CoinSpawn`

---

### Normal 청크 (보통)

**특징:**
- 장애물 2~3개
- 코인 적당량 (실버 혼합)
- 적절한 긴장감

**예시: Normal-01 "점프 앤 슬라이드"**

```
      ○ ○ ○        ○ ○ ○ ○ (슬라이드 중 코인)
        ○       ┌──────────┐
────┬──┬────────┘          └────────────────
    └──┘(낮은벽)  (높은벽 터널)
```

**제작 방법:**
1. 바닥 Part
2. 낮은 벽 (높이 4 studs):
   - Part 생성, Size: (4, 4, 3)
   - Position: (15, 2, 0)
   - CollectionService 태그: `Obstacle`
3. 높은 벽 터널 (통로 3 studs):
   - 상단 Part, Size: (8, 6, 3)
   - Position: (45, 6, 0)
   - CollectionService 태그: `Obstacle`
4. 코인 배치 (아치형 + 직선)

---

### Hard 청크 (어려움)

**특징:**
- 장애물 3~4개
- 코인 적음 (골드 위주)
- 도전 구간

**예시: Hard-01 "혼합 장애물"**

```
     ○ ★(골드)    ○ ○ ○ ○     ●(실버)
       ○     ┌────────────┐    ○
──┬──┬───────┘            └────────┬──┬──
  └──┘(벽)   (터널)                └──┘(벽)
```

**제작 방법:**
1. 바닥 Part
2. 낮은 벽 2개 (앞/뒤)
3. 높은 벽 터널 1개 (중간)
4. 골드 코인 1개 (위험한 위치)
5. 실버 코인 2개
6. 브론즈 코인 4개

---

### Bonus 청크 (보너스)

**특징:**
- 장애물 없음
- 코인 매우 많음 (실버/골드)
- 보상 구간

**예시: Bonus-01 "코인 샤워"**

```
○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○
○ ○ ○ ○ ● ● ○ ○ ○ ○ ● ● ○ ○ ○ ○
○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○
────────────────────────────────────────────
```

**제작 방법:**
1. 바닥 Part (밝은 색상, 특별한 Material)
2. 코인 3줄 배치:
   - 위줄: 브론즈 16개
   - 중간줄: 브론즈 12개 + 실버 4개
   - 아래줄: 브론즈 16개
3. 배경 파티클 효과 (옵션)

---

### NPC 청크 (NPC 등장)

**특징:**
- 장애물 0~1개
- 코인 많음
- NPC 1~2마리 등장

**예시: NPC-01 "토끼의 응원"**

```
○ ○ ○ ○ ○     ○ ○ ○ ● ● ○ ○ ○ ○
            [NPC위치]
────────────────────────────────────────────
```

**제작 방법:**
1. 바닥 Part
2. NPC 스폰 마커:
   - Part 생성 (Transparency = 1)
   - Size: (1, 1, 1)
   - Position: (30, 0, -10) (배경 레이어)
   - 속성: `NPCType = "Rabbit"` 또는 `"Bear"`
   - 태그: `NPCSpawn`
3. 코인 배치 (실버 2개 포함)

---

## 속성 설정

### 필수 속성 (Attributes)

청크 Model을 선택하고 Properties 창에서 Attributes 추가:

1. **Difficulty** (String)
   - 값: `"Easy"`, `"Normal"`, `"Hard"`, `"Bonus"`, `"NPC"` 중 하나

2. **StartHeight** (String)
   - 값: `"LOW"`, `"MID"`, `"HIGH"`
   - LOW = 0 studs, MID = 6 studs, HIGH = 12 studs

3. **EndHeight** (String)
   - 값: `"LOW"`, `"MID"`, `"HIGH"`
   - 다음 청크의 시작 높이와 연결

### Attribute 추가 방법

1. Model 선택
2. Properties 창 → Attributes 섹션
3. "+" 버튼 클릭 → "String" 선택
4. Name: `Difficulty`, Value: `Easy` 입력
5. 반복 (StartHeight, EndHeight)

### 높이 연결 규칙

- **같은 높이:** LOW → LOW (항상 허용)
- **인접 높이:** LOW → MID, MID → HIGH (1단계 차이 허용)
- **금지:** LOW → HIGH (2단계 차이, 너무 급격함)

---

## 코인/장애물/NPC 배치

### 코인 스폰 마커

**방법:**
1. Part 생성
2. Properties 설정:
   - Size: (1, 1, 1)
   - Transparency: 1 (완전 투명)
   - CanCollide: false
   - Anchored: true
3. Attribute 추가:
   - `CoinType` (String): `"Bronze"`, `"Silver"`, `"Gold"`, `"Diamond"`
4. CollectionService 태그:
   - Plugins → Tag Editor → 태그 추가: `CoinSpawn`

**배치 간격:**
- 브론즈: 3~5 studs 간격
- 실버: 5~8 studs 간격
- 골드: 단독 배치 (장애물 근처)
- 다이아: 특별 위치 (매우 드물게)

---

### 장애물

**낮은 벽 (Jump Wall):**
- Size: (4, 4, 3)
- Position Y: 2 (바닥 위)
- Color: 갈색 (나무) 또는 초록 (식물)
- 태그: `Obstacle`

**높은 벽 터널 (Slide Tunnel):**
- 상단 Part Size: (8, 6, 3)
- Position Y: 6 (통로 3 studs)
- Color: 초록 (나뭇잎) 또는 파랑 (무지개)
- 태그: `Obstacle`

**구덩이 (Gap):**
- 바닥 Part를 제거 (6~10 studs 폭)
- 또는 투명 Part + 태그: `Gap`

---

### NPC 스폰 마커

**방법:**
1. Part 생성 (투명)
2. Size: (1, 1, 1)
3. Position: (X, 0, -10) (배경 레이어)
4. Attribute:
   - `NPCType` (String): `"Rabbit"`, `"Bear"`, `"Owl"`
5. 태그: `NPCSpawn`

---

### 파워업 스폰 마커 (옵션)

**방법:**
1. Part 생성 (투명)
2. Size: (1, 1, 1)
3. Attribute:
   - `PowerupType` (String): `"Magnet"`, `"Shield"`
4. 태그: `PowerupSpawn`

---

## 체크리스트

### 청크 제작 전

- [ ] Rojo 서버 실행 중
- [ ] Roblox Studio에서 Rojo 연결됨
- [ ] ServerStorage/Chunks 폴더 존재

### 각 청크 제작 후

- [ ] Model 이름: `Chunk_난이도_번호` 형식
- [ ] PrimaryPart 설정됨
- [ ] Attributes 추가:
  - [ ] Difficulty
  - [ ] StartHeight
  - [ ] EndHeight
- [ ] 바닥 Part Anchored = true
- [ ] 코인 스폰 마커 태그: `CoinSpawn`
- [ ] 장애물 태그: `Obstacle`
- [ ] NPC 스폰 마커 태그: `NPCSpawn` (NPC 청크만)
- [ ] 모든 Part가 Model의 자식

### 테스트

- [ ] 청크를 ServerStorage/Chunks로 이동
- [ ] 게임 실행 시 청크가 랜덤으로 스폰되는지 확인
- [ ] 코인/장애물/NPC가 올바른 위치에 생성되는지 확인

---

## 예시 청크

### Easy-01: 코인 파티

```lua
-- 구조
Chunk_Easy_01 (Model)
├─ Floor (Part) - Size: (80, 1, 20), Anchored
├─ Coin1 (Part) - Transparency: 1, Tag: CoinSpawn, Attr: CoinType="Bronze"
├─ Coin2 (Part) - ...
├─ Coin3 (Part) - ...
...
└─ Coin16 (Part)

-- Attributes
Difficulty = "Easy"
StartHeight = "LOW"
EndHeight = "LOW"
```

---

### Normal-01: 점프 앤 슬라이드

```lua
Chunk_Normal_01 (Model)
├─ Floor (Part)
├─ LowWall (Part) - Size: (4, 4, 3), Tag: Obstacle
├─ TunnelTop (Part) - Size: (8, 6, 3), Tag: Obstacle
├─ Coin1~8 (Part) - 아치형 배치
└─ Coin9~12 (Part) - 터널 내부

-- Attributes
Difficulty = "Normal"
StartHeight = "LOW"
EndHeight = "LOW"
```

---

### NPC-01: 토끼의 응원

```lua
Chunk_NPC_01 (Model)
├─ Floor (Part)
├─ NPCSpawn1 (Part) - Transparency: 1, Tag: NPCSpawn, Attr: NPCType="Rabbit"
├─ Coin1~10 (Part) - 브론즈
└─ Coin11~12 (Part) - 실버

-- Attributes
Difficulty = "NPC"
StartHeight = "LOW"
EndHeight = "LOW"
```

---

## 추가 팁

### 효율적인 제작 방법

1. **템플릿 복사:**
   - 첫 번째 청크를 완벽하게 만들기
   - 복사 (Ctrl+D) → 이름/내용만 수정
   - 시간 절약!

2. **플러그인 활용:**
   - Roblox Studio 플러그인:
     - "Tag Editor" (태그 관리)
     - "Archimedes Two" (회전/복사)

3. **색상 코딩:**
   - Easy: 밝은 초록
   - Normal: 연두색
   - Hard: 어두운 초록
   - Bonus: 금색/노란색
   - NPC: 파스텔 색상

### 디자인 원칙

1. **공정성:** 모든 장애물은 회피 가능해야 함
2. **가독성:** 코인 배치로 안전 경로 표시
3. **리듬감:** 장애물 간격 일정하게
4. **다양성:** 같은 패턴 3연속 금지

---

## 저장 및 테스트

### 1. ServerStorage로 이동

- Workspace에서 제작한 청크를 **ServerStorage/Chunks**로 드래그

### 2. Rojo로 저장 (옵션)

- 청크는 Roblox Studio에만 저장됨 (외부 파일로 추출 불가)
- 프로젝트를 ".rbxl" 파일로 저장하여 백업

### 3. 테스트 실행

- Play 버튼 클릭
- 게임 시작 후 청크가 랜덤으로 생성되는지 확인
- F9 (Developer Console)로 로그 확인:
  - `[ChunkService] Spawned chunk #1: Easy at ...`

---

## 문제 해결

### 청크가 스폰되지 않음

- ServerStorage/Chunks 폴더 위치 확인
- Attributes (Difficulty, StartHeight, EndHeight) 확인
- PrimaryPart 설정 확인

### 코인/장애물이 생성되지 않음

- CollectionService 태그 확인 (`CoinSpawn`, `Obstacle`)
- Part Transparency = 1 (투명) 확인
- Attribute 이름 철자 확인 (대소문자 구분)

### 높이 연결 오류

- StartHeight/EndHeight 값 확인 ("LOW", "MID", "HIGH")
- 2단계 이상 차이나지 않는지 확인 (LOW → HIGH 금지)

---

## 마무리

모든 청크를 제작한 후:

1. **최소 17개 청크** 확인
2. 각 난이도별로 다양한 패턴 확보
3. 게임 실행하여 전체 플레이 테스트
4. 밸런스 조정 (너무 쉽거나 어려우면 수정)

**축하합니다! 🎉 Coin Runner의 청크 시스템이 완성되었습니다!**

---

**참고 문서:**
- `docs/design/level-design.md` - 레벨 디자인 상세 기획
- `docs/design/game-design.md` - 게임 전체 기획서

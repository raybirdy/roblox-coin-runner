# Roblox Studio 초보자 가이드

> 처음 Roblox Studio를 사용하는 분들을 위한 완전 가이드

## 목차

1. [Roblox Studio 설치](#roblox-studio-설치)
2. [첫 실행 및 인터페이스](#첫-실행-및-인터페이스)
3. [Rojo 연결하기](#rojo-연결하기)
4. [기본 조작법](#기본-조작법)
5. [Part (오브젝트) 만들기](#part-오브젝트-만들기)
6. [Properties 패널 사용법](#properties-패널-사용법)
7. [Explorer 패널 사용법](#explorer-패널-사용법)
8. [Attributes 추가하기](#attributes-추가하기)
9. [CollectionService 태그 사용법](#collectionservice-태그-사용법)
10. [게임 테스트하기](#게임-테스트하기)
11. [저장 및 퍼블리시](#저장-및-퍼블리시)
12. [자주 묻는 질문](#자주-묻는-질문)

---

## Roblox Studio 설치

### 1. Roblox 계정 만들기

1. [roblox.com](https://www.roblox.com) 접속
2. "Sign Up" (가입) 버튼 클릭
3. 생년월일, 사용자 이름, 비밀번호 입력
4. 이메일 인증 (선택사항이지만 권장)

### 2. Roblox Studio 다운로드

1. [create.roblox.com](https://create.roblox.com) 접속
2. "Start Creating" 버튼 클릭
3. 자동으로 Roblox Studio 설치 파일 다운로드 시작
4. 다운로드된 파일 실행하여 설치

### 3. 설치 확인

- 설치 완료 후 바탕화면에 "Roblox Studio" 아이콘 생성
- 더블클릭하여 실행

---

## 첫 실행 및 인터페이스

### Roblox Studio 실행

1. **Roblox Studio** 아이콘 더블클릭
2. Roblox 계정으로 로그인
3. 첫 화면에서 "New" 탭 선택

### 인터페이스 구성

```
┌─────────────────────────────────────────────────────────┐
│  [File] [Home] [Model] [Test] [View] [Plugins]          │ ← 메뉴 바
├─────────────────────────────────────────────────────────┤
│  [도구 모음: Select, Move, Scale, Rotate...]            │ ← 도구 바
├──────────────┬──────────────────────────┬───────────────┤
│              │                          │               │
│  Explorer    │    3D Viewport           │  Properties   │
│  (탐색기)     │    (게임 화면)            │  (속성 창)     │
│              │                          │               │
│  - Workspace │                          │  Part 속성:   │
│  - Players   │     여기서 게임을        │  - Size       │
│  - Lighting  │     만듭니다!            │  - Position   │
│              │                          │  - Color      │
│              │                          │               │
└──────────────┴──────────────────────────┴───────────────┘
```

### 주요 패널 설명

1. **Explorer (왼쪽)**
   - 게임의 모든 오브젝트를 트리 구조로 표시
   - Workspace, ServerStorage, ReplicatedStorage 등

2. **3D Viewport (중앙)**
   - 게임 세계를 3D로 보여주는 화면
   - 마우스로 회전, 이동, 줌 가능

3. **Properties (오른쪽)**
   - 선택한 오브젝트의 속성을 보여주고 수정

4. **Output (하단, 기본적으로 숨김)**
   - View → Output 클릭하여 표시
   - 게임 로그 및 에러 메시지 확인

---

## Rojo 연결하기

### Rojo란?

- 외부 코드 에디터(VS Code, Claude Code)와 Roblox Studio를 연결
- 코드 파일을 자동으로 동기화

### 1. Rojo 플러그인 설치

1. Roblox Studio에서 "Plugins" 탭 클릭
2. "Plugin Marketplace" 버튼 클릭
3. 검색창에 "Rojo" 입력
4. "Rojo" 플러그인 찾아서 "Install" 클릭
5. Studio 재시작

### 2. 터미널에서 Rojo 서버 실행

```bash
# 프로젝트 폴더로 이동
cd /Users/parkjongha/Documents/git/roblox-coin-runner

# Rojo 서버 실행
rojo serve
```

**출력 예시:**
```
Rojo server listening on port 34872
```

### 3. Roblox Studio에서 연결

1. Plugins 탭에서 "Rojo" 버튼 클릭
2. 팝업 창에서 "Connect" 버튼 클릭
3. 연결 성공 시 초록색 체크 표시
4. Explorer에서 프로젝트 구조 확인:
   ```
   - ServerScriptService
     - Server
       - Services
   - StarterPlayer
     - StarterPlayerScripts
       - Client
         - Controllers
   - ReplicatedStorage
     - Shared
       - Constants
   ```

**중요:** Rojo 연결 후에는 Studio에서 코드 파일을 직접 수정하지 마세요! 항상 외부 에디터에서 수정하세요.

---

## 기본 조작법

### 카메라 조작 (3D Viewport)

| 조작 | 키/마우스 | 설명 |
|------|----------|------|
| **회전** | 마우스 우클릭 + 드래그 | 카메라 시점 회전 |
| **이동** | W, A, S, D | 앞/왼쪽/뒤/오른쪽 이동 |
| **상하 이동** | E, Q | 위/아래 이동 |
| **줌** | 마우스 휠 | 확대/축소 |
| **포커스** | F | 선택한 오브젝트로 카메라 이동 |

### 오브젝트 선택 및 조작

| 조작 | 키/마우스 | 설명 |
|------|----------|------|
| **선택** | 좌클릭 | 오브젝트 선택 |
| **다중 선택** | Ctrl + 좌클릭 | 여러 오브젝트 선택 |
| **이동** | Ctrl + 1 또는 도구바 "Move" | 오브젝트 이동 모드 |
| **회전** | Ctrl + 3 또는 도구바 "Rotate" | 오브젝트 회전 모드 |
| **크기 조절** | Ctrl + 2 또는 도구바 "Scale" | 오브젝트 크기 변경 |
| **복사** | Ctrl + D | 선택한 오브젝트 복사 |
| **삭제** | Delete | 선택한 오브젝트 삭제 |
| **실행 취소** | Ctrl + Z | 이전 작업 취소 |
| **다시 실행** | Ctrl + Y | 취소한 작업 다시 실행 |

### 유용한 단축키

| 단축키 | 기능 |
|--------|------|
| **Ctrl + S** | 저장 |
| **F5** | 게임 테스트 시작 |
| **Shift + F5** | 게임 테스트 종료 |
| **Alt + S** | 그리드 스냅 토글 |
| **Ctrl + G** | 그룹 만들기 |
| **Ctrl + U** | 그룹 해제 |

---

## Part (오브젝트) 만들기

### Part란?

- Roblox 게임의 기본 구성 요소
- 블록, 구, 원기둥 등 3D 형태
- 모든 게임 오브젝트의 기초

### Part 생성 방법

#### 방법 1: 메뉴 사용

1. 상단 메뉴바에서 **"Home"** 탭 클릭
2. **"Part"** 버튼 클릭 (큰 블록 아이콘)
3. Workspace에 Part가 생성됨

#### 방법 2: Explorer에서 생성

1. **Explorer** 패널에서 **Workspace** 우클릭
2. **"Insert Object"** 선택
3. 검색창에 **"Part"** 입력
4. **Part** 선택 후 **OK**

### Part 종류

| 종류 | 설명 |
|------|------|
| **Block** | 기본 직육면체 |
| **Sphere** | 구 |
| **Cylinder** | 원기둥 |
| **Wedge** | 삼각 프리즘 |
| **CornerWedge** | 모서리 블록 |

**팁:** Part를 선택하고 Properties에서 `Shape` 속성을 변경하여 모양 바꾸기 가능

---

## Properties 패널 사용법

### Properties 패널 열기

- 화면 오른쪽에 기본적으로 표시됨
- 안 보이면: **View** → **Properties** 클릭

### 주요 속성

#### 1. Size (크기)

```
Size: X, Y, Z
- X: 가로 길이 (studs)
- Y: 세로 높이 (studs)
- Z: 깊이 (studs)

예시: (80, 1, 20) = 80 studs 길이의 바닥
```

**설정 방법:**
1. Part 선택
2. Properties → **Size** 찾기
3. 숫자 클릭하여 직접 입력
4. Enter로 적용

#### 2. Position (위치)

```
Position: X, Y, Z
- X: 좌우 위치
- Y: 높이 (위아래)
- Z: 앞뒤 위치

예시: (40, 0, 0) = X축으로 40 studs 이동
```

#### 3. Anchored (고정)

- **체크됨:** Part가 공중에 고정됨 (떨어지지 않음)
- **체크 안 됨:** Part가 중력의 영향을 받음 (떨어짐)

**청크 제작 시 모든 Part는 Anchored = true로 설정!**

#### 4. CanCollide (충돌)

- **체크됨:** 플레이어/다른 오브젝트와 충돌
- **체크 안 됨:** 통과 가능 (유령 모드)

**코인 스폰 마커는 CanCollide = false로 설정!**

#### 5. Transparency (투명도)

- **0:** 완전 불투명
- **1:** 완전 투명
- **0.5:** 반투명

**코인 스폰 마커는 Transparency = 1로 설정!**

#### 6. Color (색상)

- 색상 박스 클릭 → 색상 선택기에서 선택
- RGB 값 직접 입력 가능

#### 7. Material (재질)

- Plastic (기본), Wood, Metal, Grass 등
- 외형과 물리적 특성 변경

---

## Explorer 패널 사용법

### Explorer란?

- 게임의 모든 오브젝트를 계층 구조로 보여주는 패널
- 폴더처럼 확장/축소 가능

### 주요 컨테이너

#### 1. Workspace

- **게임 월드에 실제로 존재하는 모든 것**
- 플레이어가 볼 수 있는 Part, Model 등
- 청크를 여기서 제작 후 ServerStorage로 이동

#### 2. ServerStorage

- **서버 측에만 존재하는 저장소**
- 클라이언트에서는 보이지 않음
- **청크 템플릿을 여기에 저장!**
- 경로: `ServerStorage/Chunks`

#### 3. ReplicatedStorage

- **서버와 클라이언트 모두 접근 가능**
- 공유 모듈, RemoteEvents 등
- Rojo로 동기화된 코드 파일 위치

#### 4. StarterPlayer

- 플레이어 관련 설정
- StarterPlayerScripts: 클라이언트 스크립트

#### 5. ServerScriptService

- 서버 스크립트 전용
- Rojo로 동기화된 서버 코드 위치

### Explorer 조작

| 조작 | 방법 |
|------|------|
| **폴더 확장** | 삼각형 아이콘 클릭 또는 더블클릭 |
| **오브젝트 추가** | 우클릭 → Insert Object |
| **이름 변경** | 오브젝트 우클릭 → Rename (또는 F2) |
| **삭제** | 오브젝트 선택 후 Delete |
| **복사/붙여넣기** | Ctrl+C / Ctrl+V |
| **이동** | 드래그 앤 드롭 |
| **그룹화** | 여러 Part 선택 → 우클릭 → Group |

### Model 만들기

여러 Part를 하나로 묶으려면:

1. Explorer에서 Part 여러 개 선택 (Ctrl + 클릭)
2. 우클릭 → **"Group"** (또는 Ctrl+G)
3. 생성된 Model 이름 변경 (예: `Chunk_Easy_01`)

---

## Attributes 추가하기

### Attributes란?

- 오브젝트에 **커스텀 데이터**를 추가하는 기능
- 코드에서 읽어서 사용
- 예: `Difficulty = "Easy"`, `CoinType = "Bronze"`

### Attributes 추가 방법

#### 1. 오브젝트 선택

- Explorer에서 Model 또는 Part 선택

#### 2. Properties에서 Attributes 찾기

- Properties 패널 스크롤 다운
- **"Attributes"** 섹션 찾기 (맨 아래쪽)

#### 3. Attribute 추가

1. **"+" 버튼** 클릭
2. **타입 선택:**
   - **String:** 문자열 (예: "Easy", "Bronze")
   - **Number:** 숫자 (예: 10, 3.5)
   - **Boolean:** true/false
   - 기타 타입...

3. **이름 입력:**
   - 예: `Difficulty`

4. **값 입력:**
   - 예: `Easy`

5. **Enter로 확정**

### 청크에 필수 Attributes

모든 청크 Model에 추가:

| Name | Type | Value | 설명 |
|------|------|-------|------|
| **Difficulty** | String | `Easy`, `Normal`, `Hard`, `Bonus`, `NPC` | 난이도 |
| **StartHeight** | String | `LOW`, `MID`, `HIGH` | 시작 높이 |
| **EndHeight** | String | `LOW`, `MID`, `HIGH` | 끝 높이 |

### 코인 스폰 마커에 Attributes

각 코인 마커 Part에 추가:

| Name | Type | Value | 설명 |
|------|------|-------|------|
| **CoinType** | String | `Bronze`, `Silver`, `Gold`, `Diamond` | 코인 종류 |

### NPC 스폰 마커에 Attributes

각 NPC 마커 Part에 추가:

| Name | Type | Value | 설명 |
|------|------|-------|------|
| **NPCType** | String | `Rabbit`, `Bear`, `Owl` | NPC 종류 |

---

## CollectionService 태그 사용법

### CollectionService 태그란?

- 오브젝트에 **라벨**을 붙이는 기능
- 같은 태그를 가진 모든 오브젝트를 한번에 찾을 수 있음
- 코드에서 `CollectionService:GetTagged("태그명")` 사용

### Tag Editor 플러그인 설치

1. **Plugins** 탭 클릭
2. **"Plugin Marketplace"** 버튼 클릭
3. 검색: **"Tag Editor"**
4. 설치

### 태그 추가 방법

#### 1. Tag Editor 열기

- Plugins → **"Tag Editor"** 버튼 클릭
- 화면 왼쪽에 Tag Editor 패널 표시

#### 2. 오브젝트에 태그 추가

1. Explorer에서 Part 선택
2. Tag Editor 패널에서 **입력창에 태그명 입력**
   - 예: `CoinSpawn`
3. **Enter** 또는 **"+" 버튼** 클릭
4. 태그가 추가됨 (초록색 라벨로 표시)

### 청크 제작에 필요한 태그

| 태그명 | 대상 | 설명 |
|--------|------|------|
| **CoinSpawn** | 투명 Part | 코인 생성 위치 |
| **Obstacle** | 장애물 Part | 장애물 (벽, 터널) |
| **NPCSpawn** | 투명 Part | NPC 생성 위치 |
| **PowerupSpawn** | 투명 Part | 파워업 생성 위치 (옵션) |
| **Gap** | 투명 Part | 구덩이 (옵션) |

### 태그 확인

- Tag Editor에서 태그명 클릭 → 해당 태그를 가진 모든 오브젝트가 Explorer에서 하이라이트됨

---

## 게임 테스트하기

### Play 버튼으로 테스트

1. **상단 메뉴바의 "Test" 탭** 클릭
2. **"Play" 버튼** (재생 아이콘) 클릭 또는 **F5**
3. 게임이 시작되고 플레이 가능
4. 테스트 종료: **"Stop" 버튼** 또는 **Shift+F5**

### Output 창 확인

1. **View** → **Output** 클릭
2. 게임 로그 및 에러 메시지 확인
3. 중요 로그 예시:
   ```
   [Client] Coin Runner Client Starting...
   [Server] Coin Runner Server Starting...
   [ChunkService] Spawned chunk #1: Easy at ...
   [NPCService] Spawned Rabbit NPC at ...
   ```

### Developer Console (F9)

- 게임 실행 중 **F9** 키
- 더 상세한 로그, 스크립트 에러, 네트워크 상태 등 확인

### 테스트 모드 종류

| 모드 | 단축키 | 설명 |
|------|--------|------|
| **Play** | F5 | 게임 시작 (플레이어 시점) |
| **Play Here** | F6 | 현재 카메라 위치에서 시작 |
| **Run** | F8 | 플레이어 없이 게임 실행 (관찰자 모드) |
| **Stop** | Shift+F5 | 테스트 종료 |

### 자주 하는 실수

❌ **실수:** 테스트 중에 오브젝트 수정
- 테스트 모드에서의 변경사항은 **저장되지 않음!**
- 반드시 **Stop 후에 수정**하세요.

❌ **실수:** Anchored 체크 안 함
- Part가 공중에 떠있다가 게임 시작 시 떨어짐
- 모든 청크 Part는 **Anchored = true**로 설정!

---

## 저장 및 퍼블리시

### 로컬 저장 (Roblox 파일)

1. **File** → **Save to File** (또는 Ctrl+S)
2. 저장 위치 선택
3. 파일명 입력 (예: `coin-runner.rbxl`)
4. **Save** 클릭

**중요:** `.rbxl` 파일은 Roblox Studio 전용 형식입니다.

### Roblox 플랫폼에 퍼블리시

#### 1. Roblox에 업로드

1. **File** → **Publish to Roblox**
2. 로그인 (필요 시)
3. 게임 정보 입력:
   - **Name:** 게임 이름 (예: Coin Runner)
   - **Description:** 게임 설명
   - **Genre:** 장르 선택 (예: Adventure)
   - **Devices:** PC, Mobile, Tablet 선택
4. **Create** 버튼 클릭

#### 2. 게임 설정

퍼블리시 후 [create.roblox.com](https://create.roblox.com)에서:

1. **Creations** → 내 게임 선택
2. **Configure Start Place** 클릭
3. 설정:
   - **Public/Private:** Public (공개) 또는 Private (비공개)
   - **Allow Copying:** 비활성화 (추천)
   - **Genre, Description, Thumbnail** 설정
4. **Save** 클릭

#### 3. 게임 플레이

- 게임 페이지에서 **Play** 버튼으로 플레이
- 친구에게 링크 공유

---

## 자주 묻는 질문

### Q1. Rojo 연결이 안 돼요!

**해결 방법:**
1. 터미널에서 `rojo serve` 실행 중인지 확인
2. Rojo 플러그인이 설치되었는지 확인
3. Roblox Studio 재시작
4. 포트 충돌 시 Rojo 서버 재시작

---

### Q2. Part를 선택했는데 Properties가 안 보여요!

**해결 방법:**
1. **View** → **Properties** 클릭
2. Properties 패널이 숨겨져 있을 수 있음
3. 오른쪽 상단 모서리를 드래그하여 패널 크기 조절

---

### Q3. 게임 테스트 시 청크가 안 나와요!

**체크리스트:**
- [ ] 청크가 **ServerStorage/Chunks**에 있는지 확인
- [ ] 청크 Model에 **Attributes** 추가했는지 확인
  - Difficulty, StartHeight, EndHeight
- [ ] PrimaryPart가 설정되었는지 확인
- [ ] Output 창에서 에러 메시지 확인

---

### Q4. 코드를 수정했는데 게임에 반영이 안 돼요!

**해결 방법:**
1. Rojo가 연결되어 있는지 확인 (초록색 체크)
2. 파일 저장했는지 확인 (Claude Code에서 저장)
3. Rojo 서버가 변경사항을 감지했는지 터미널 확인
4. Roblox Studio 재시작

**중요:** Rojo 연결 후에는 **Studio에서 코드를 직접 수정하지 마세요!** 항상 외부 에디터에서 수정하세요.

---

### Q5. Part가 공중에서 떨어져요!

**해결 방법:**
- Part 선택 → Properties → **Anchored** 체크
- 청크의 모든 Part는 Anchored = true여야 합니다!

---

### Q6. 태그를 추가했는데 코드에서 못 찾아요!

**체크리스트:**
- [ ] Tag Editor 플러그인 설치 확인
- [ ] 태그 철자가 정확한지 확인 (대소문자 구분!)
  - 올바른 예: `CoinSpawn`
  - 틀린 예: `coinspawn`, `Coinspawn`
- [ ] Tag Editor에서 태그가 추가되었는지 확인 (초록색 라벨)

---

### Q7. Attributes가 안 보여요!

**해결 방법:**
1. Properties 패널 맨 아래까지 스크롤
2. "Attributes" 섹션 찾기
3. 없으면 Roblox Studio 버전 확인 (최신 버전 필요)

---

### Q8. 청크를 복사하고 싶어요!

**방법:**
1. Explorer에서 청크 Model 선택
2. **Ctrl + D** (복제)
3. 복제된 청크 이름 변경 (예: `Chunk_Easy_02`)
4. 내용 수정 (코인 위치, 장애물 등)

---

### Q9. 게임 실행 시 에러가 나요!

**확인 사항:**
1. **Output 창** (View → Output) 에러 메시지 확인
2. **Developer Console** (F9) 상세 에러 확인
3. 에러 메시지 복사해서 검색 또는 질문

**흔한 에러:**
- `"attempt to index nil with..."` → 오브젝트를 찾지 못함
- `"Infinite yield possible on..."` → 오브젝트가 존재하지 않음

---

### Q10. ServerStorage/Chunks 폴더가 없어요!

**생성 방법:**
1. Explorer에서 **ServerStorage** 우클릭
2. **Insert Object** 선택
3. 검색: **Folder**
4. Folder 선택 후 **OK**
5. 생성된 Folder 이름을 **"Chunks"**로 변경

---

## 다음 단계

이제 기본기를 익혔으니:

1. ✅ **청크 제작 가이드** 읽기
   - `/docs/guides/chunk-creation-guide.md`

2. ✅ **첫 청크 만들기**
   - Easy 청크부터 시작 (장애물 없음)
   - 코인 스폰 마커 배치 연습

3. ✅ **테스트 플레이**
   - F5로 게임 실행
   - 청크가 제대로 생성되는지 확인

4. ✅ **점진적으로 확장**
   - Normal, Hard, Bonus, NPC 청크 추가
   - 목표: 최소 17개, 권장 27개

---

## 유용한 리소스

### 공식 문서

- [Roblox Creator Hub](https://create.roblox.com/docs) - 공식 문서
- [Roblox DevForum](https://devforum.roblox.com) - 개발자 포럼
- [Rojo Documentation](https://rojo.space/docs) - Rojo 공식 문서

### 튜토리얼 (영어)

- [Roblox Studio Basics](https://www.youtube.com/watch?v=6jMr6Fs_2S4) - 공식 튜토리얼
- [Building in Roblox Studio](https://www.youtube.com/watch?v=rDV9A6uUX0U) - 건축 튜토리얼

### 단축키 치트시트

| 카테고리 | 단축키 | 기능 |
|---------|--------|------|
| **파일** | Ctrl+S | 저장 |
| | Ctrl+Shift+P | 퍼블리시 |
| **편집** | Ctrl+Z | 실행 취소 |
| | Ctrl+Y | 다시 실행 |
| | Ctrl+C/V/X | 복사/붙여넣기/잘라내기 |
| | Ctrl+D | 복제 |
| | Delete | 삭제 |
| **조작** | Ctrl+1 | 이동 |
| | Ctrl+2 | 크기 조절 |
| | Ctrl+3 | 회전 |
| | F | 선택 항목 포커스 |
| **테스트** | F5 | 플레이 |
| | F6 | 현재 위치에서 플레이 |
| | F8 | 실행 |
| | Shift+F5 | 중지 |
| **보기** | F9 | Developer Console |

---

## 마무리

Roblox Studio는 처음엔 복잡해 보이지만, 기본만 익히면 금방 익숙해집니다!

**기억하세요:**
1. **Anchored = true** (모든 청크 Part)
2. **Transparency = 1** (코인/NPC 스폰 마커)
3. **태그는 대소문자 구분** (`CoinSpawn`, 정확히)
4. **Attributes 3개 필수** (Difficulty, StartHeight, EndHeight)
5. **테스트 후 Stop** (변경사항 저장 안 됨)

**행운을 빕니다! 🎮🚀**

궁금한 점이 있으면 언제든 질문하세요!

# Roblox Testing Guide

Roblox Coin Runner 프로젝트의 테스트 방법론 가이드입니다.

## 목차

1. [Rojo 워크플로우를 통한 테스트](#rojo-workflow)
2. [Roblox Studio에서의 테스트](#roblox-studio-testing)
3. [로컬 테스트 서버](#local-test-server)
4. [멀티플레이어 테스트](#multiplayer-testing)
5. [디버깅 도구](#debugging-tools)
6. [성능 프로파일링](#performance-profiling)
7. [테스트 체크리스트](#test-checklist)

---

## Rojo Workflow

### 1. Rojo 서버 시작

```bash
cd /Users/parkjongha/Documents/git/roblox-coin-runner
rojo serve
```

Rojo 서버가 `localhost:34872`에서 실행됩니다.

### 2. Roblox Studio 연결

1. Roblox Studio 열기
2. **Plugins → Rojo** 클릭
3. **Connect** 버튼 클릭
4. 코드가 자동으로 동기화됩니다

### 3. 핫 리로딩 테스트

- 외부 에디터(Claude Code)에서 `.luau` 파일 수정
- 저장하면 Rojo가 자동으로 Studio에 반영
- **주의**: Studio에서 직접 스크립트를 수정하지 마세요 (덮어쓰기 됨)

---

## Roblox Studio Testing

### Play 모드 (F5)

**용도**: 싱글 플레이어 빠른 테스트

1. Roblox Studio에서 **Home → Play** (F5) 클릭
2. 게임이 실행되어 직접 플레이 가능
3. 출력 창(Output)에서 `print()` 로그 확인
4. **Stop** (Shift+F5) 버튼으로 종료

**장점**:
- 가장 빠른 테스트 방법
- 코드 수정 후 즉시 확인 가능

**단점**:
- 서버-클라이언트 분리 확인 어려움
- 네트워크 지연 시뮬레이션 불가

### Local Server 모드 (F7)

**용도**: 클라이언트-서버 아키텍처 테스트

1. **Test → Start Server and Players** 클릭
2. 서버 창 1개 + 플레이어 클라이언트 창 1개 (또는 여러 개) 생성
3. 각 창에서 독립적으로 로그 확인 가능

**설정**:
- **Players**: 테스트할 플레이어 수 (1~8)
- **Server**: 서버 창 표시 여부

**테스트 항목**:
- RemoteEvent/RemoteFunction 통신
- 서버 검증 로직
- 플레이어별 독립 게임 세션
- ChunkService 인스턴스 관리

### Team Test 모드

**용도**: 실제 네트워크 환경 테스트 (Studio 내 시뮬레이션)

1. **Test → Clients and Servers** 메뉴
2. 네트워크 지연, 패킷 손실 시뮬레이션 가능
3. 여러 기기에서 동시 접속 테스트

---

## Local Test Server

### Published Game 테스트

개발 중인 게임을 Roblox에 업로드하여 실제 환경에서 테스트합니다.

#### 1. 게임 퍼블리시

1. **File → Publish to Roblox** (Alt+P)
2. 게임 이름: `Coin Runner - Dev`
3. **Private** (비공개) 설정 ← 중요!
4. **Create** 클릭

#### 2. Roblox 웹사이트에서 플레이

1. [roblox.com](https://www.roblox.com) 로그인
2. **Create → My Creations → Experiences**
3. `Coin Runner - Dev` 선택
4. **Play** 버튼으로 실제 환경 테스트

#### 3. 장단점

**장점**:
- 실제 Roblox 서버 환경 테스트
- 모바일 기기에서도 접속 가능
- DataStore 실제 저장 테스트 가능

**단점**:
- 퍼블리시 시간 소요 (30초~1분)
- 빠른 반복 테스트에 부적합

---

## Multiplayer Testing

### 1. Studio에서 멀티플레이어 테스트

```
Test → Start Server and Players
Players: 2~4명 설정
```

**테스트 항목**:
- 플레이어별 독립 ChunkService 인스턴스
- 동시 게임 시작/종료
- 서버 부하 (여러 플레이어 동시 플레이 시)

### 2. Published Game에서 멀티플레이어 테스트

1. 게임을 Private으로 퍼블리시
2. 친구/팀원 초대
3. 여러 기기에서 동시 접속
4. 실제 네트워크 지연 환경에서 테스트

**테스트 항목**:
- RemoteEvent 지연 처리
- 서버 동기화
- 플레이어 간 간섭 없음 확인 (각자 독립 청크)

---

## Debugging Tools

### 1. Output 창 (View → Output)

```lua
print("[Client] Game started")
warn("[ChunkService] No chunks found") -- 노란색 경고
error("[Server] Critical error") -- 빨간색 에러 (스크립트 중단)
```

**팁**:
- `[Client]`, `[Server]`, `[Service명]` 등 prefix로 로그 구분
- Output 창 오른쪽 클릭 → **Filter by Source**로 스크립트별 필터링

### 2. Script Analysis (View → Script Analysis)

Selene 린터 결과를 Studio에서도 확인 가능합니다.

- 경고: 미사용 변수, deprecated API
- 에러: 타입 오류, 문법 오류

### 3. Developer Console (F9)

게임 실행 중 **F9** 키로 콘솔 열기

**탭**:
- **Log**: 모든 출력 로그
- **Memory**: 메모리 사용량
- **Server Stats**: 서버 성능 (Physics, Heartbeat)
- **Network**: 네트워크 트래픽

**활용**:
- 실시간 로그 확인
- 메모리 누수 감지
- 서버 부하 모니터링

### 4. Explorer 및 Properties 창

**실행 중 인스턴스 확인**:
1. Play 모드 실행
2. Explorer에서 `Workspace` 펼치기
3. 동적으로 생성된 Chunk 모델 확인
4. Properties 창에서 Attribute 값 확인

**디버깅 예시**:
- ChunkService가 생성한 청크들이 Workspace에 있는지 확인
- 각 청크의 `StartHeight`, `EndHeight` Attribute 확인
- AlignPosition Constraint 설정값 확인

### 5. Breakpoints (Studio 내장 디버거)

**사용법**:
1. Studio에서 스크립트 열기
2. 라인 번호 옆 클릭 → 빨간 점 (Breakpoint)
3. Play 모드 실행
4. 해당 라인에서 일시정지, 변수 값 확인 가능

**제한사항**:
- Rojo 동기화 파일에서는 동작 불안정
- 간단한 디버깅에만 권장

---

## Performance Profiling

### 1. MicroProfiler (Ctrl+Alt+F6)

실시간 프레임별 성능 분석 도구

**사용법**:
1. Play 모드 실행
2. **Ctrl+Alt+F6** 입력
3. 화면 상단에 프로파일러 표시

**분석 항목**:
- **Heartbeat**: 서버 메인 루프 (GameManager 업데이트)
- **Physics**: 물리 계산 (AlignPosition, Gravity)
- **Rendering**: 클라이언트 렌더링
- **Script**: Luau 스크립트 실행 시간

**최적화 목표**:
- Heartbeat < 16ms (60 FPS 유지)
- 플레이어 10명 동시 접속 시에도 안정적

### 2. Memory Profiler

**View → Developer Console (F9) → Memory**

**확인 항목**:
- **PlaceMemory**: 전체 메모리 사용량
- **LuaHeap**: Luau 스크립트 메모리
- **GraphicsMeshParts**: 청크 모델 메모리

**메모리 누수 체크**:
1. 게임 시작
2. 10분 플레이
3. Memory 탭에서 지속 증가하는 항목 확인
4. ChunkService의 `Destroy()` 메서드가 제대로 호출되는지 확인

### 3. Server Stats (F9 → ServerStats)

**주요 지표**:
- **Heartbeat (Step)**: 서버 프레임 시간 (목표: <16ms)
- **Physics**: 물리 계산 시간
- **DataSendKbps**: 서버→클라이언트 전송량
- **DataReceiveKbps**: 클라이언트→서버 전송량

---

## Test Checklist

### 기능 테스트

#### 플레이어 움직임
- [ ] 자동 전진 (속도 25→55 studs/s, 30초 ramping)
- [ ] 1단 점프 (Space/W/↑, 높이 8 studs)
- [ ] 2단 점프 (공중에서 추가 점프, 높이 5 studs)
- [ ] 슬라이드 (S/↓, 0.6초 지속)
- [ ] Z축 고정 (AlignPosition, Z=0)

#### 청크 시스템
- [ ] 게임 시작 시 3개 청크 생성
- [ ] 플레이어 진행 시 자동으로 청크 생성
- [ ] 뒤쪽 청크 자동 삭제 (100 studs 이상 뒤)
- [ ] 난이도별 생성 확률 정상 작동 (시간대별)
- [ ] 높이 태그 연결 규칙 (LOW↔MID↔HIGH, 인접만 허용)

#### 클라이언트-서버 통신
- [ ] GameStart RemoteEvent 정상 통신
- [ ] 서버에서 플레이어별 세션 생성
- [ ] ChunkService 인스턴스 플레이어마다 독립적으로 생성

### 성능 테스트

- [ ] 싱글 플레이어: 60 FPS 유지
- [ ] 4명 동시 플레이: 서버 Heartbeat <16ms
- [ ] 10분 플레이: 메모리 누수 없음
- [ ] 청크 100개 생성 후: 오래된 청크 정리 확인

### 멀티플레이어 테스트

- [ ] 2명 이상 동시 접속
- [ ] 각 플레이어 독립적으로 청크 생성
- [ ] 플레이어 간 청크 간섭 없음
- [ ] 한 플레이어 퇴장 시 세션 정리

### 디바이스별 테스트

- [ ] PC (키보드 입력)
- [ ] 모바일 (터치 UI - 향후 구현)
- [ ] 저사양 기기 (FPS 확인)

### 에러 핸들링

- [ ] ServerStorage/Chunks 폴더 없을 시 경고 메시지
- [ ] 플레이어 리스폰 시 컨트롤 재설정
- [ ] 네트워크 끊김 시 동작 확인

---

## 테스트 시나리오 예시

### Scenario 1: 기본 플레이 테스트

1. Rojo 서버 실행 (`rojo serve`)
2. Roblox Studio에서 Rojo 연결
3. **Play (F5)** 실행
4. 3초 후 자동으로 게임 시작
5. Space 키로 점프 테스트
6. S 키로 슬라이드 테스트
7. 청크가 자동으로 생성되는지 확인
8. Output 창에서 로그 확인:
   ```
   [Client] Coin Runner Client Starting...
   [Server] Coin Runner Server Starting...
   [Client] Requesting game start from server...
   [GameManager] Game start requested by Player1
   [ChunkService] Loaded 0 chunk templates
   [ChunkService] Game started, initial chunks spawned
   ```

### Scenario 2: 멀티플레이어 테스트

1. **Test → Start Server and Players** (Players: 2)
2. 서버 창과 2개 클라이언트 창 확인
3. 각 플레이어가 독립적으로 게임 시작하는지 확인
4. 서버 Output에서 세션 2개 생성 확인
5. 한 플레이어 게임 오버 후 세션 정리 확인

### Scenario 3: 청크 높이 연결 테스트

**사전 준비**: ServerStorage/Chunks에 테스트 청크 추가
- `TestChunk_Easy_LOW_MID` (LOW→MID)
- `TestChunk_Easy_MID_HIGH` (MID→HIGH)
- `TestChunk_Easy_HIGH_MID` (HIGH→MID)

**테스트**:
1. Play 모드 실행
2. 청크가 높이 순서대로 연결되는지 확인
3. Output에서 높이 호환 경고가 없는지 확인

---

## 트러블슈팅

### 문제: Rojo 연결 안 됨
**해결**:
1. `rojo serve` 재시작
2. Roblox Studio 재시작
3. 방화벽 확인 (포트 34872)

### 문제: 코드 수정이 반영 안 됨
**해결**:
1. Rojo 연결 상태 확인 (초록불)
2. `.luau` 파일 저장 확인
3. Studio에서 직접 수정했는지 확인 (Rojo가 덮어씀)

### 문제: 청크가 생성 안 됨
**원인**: ServerStorage/Chunks 폴더 비어있음
**해결**:
1. Studio에서 ServerStorage/Chunks 폴더 확인
2. 테스트용 청크 모델 추가
3. Attribute 설정: `Difficulty`, `StartHeight`, `EndHeight`

### 문제: 플레이어가 계속 낙하함
**원인**: 청크 바닥에 Collision이 없거나 위치가 잘못됨
**해결**:
1. 청크 모델에 BasePart로 바닥 추가
2. `CanCollide = true` 설정
3. 청크 PrimaryPart 설정 확인

### 문제: 메모리 계속 증가
**원인**: ChunkService의 Destroy() 미호출 또는 Connection 미정리
**해결**:
1. GameManager에서 EndGame 시 `chunkService:Destroy()` 호출 확인
2. PlayerRemoving 이벤트 연결 확인
3. F9 → Memory 탭에서 증가 항목 확인

---

## 다음 단계

MVP 완료 후 추가할 테스트:

1. **Unit Test** (향후): TestEZ 프레임워크 도입
2. **Integration Test**: 전체 게임 플로우 자동 테스트
3. **Automated Test**: GitHub Actions로 CI/CD 구축
4. **Closed Beta**: 실제 유저 소규모 테스트

---

**문서 버전**: v1.0
**작성일**: 2026-02-05
**다음 업데이트**: MVP 완료 후

# Roblox Coin Runner - Project Rules

## Project Overview

- **게임명**: Coin Runner (코인 러너)
- **장르**: 횡스크롤 코인 수집 러너
- **타겟**: 저연령층 (6~12세)
- **플랫폼**: Roblox
- **언어**: Luau

## Git Workflow (GitHub Flow)

### Branch Naming Convention

```
feature/<feature-name>    # 새 기능
fix/<bug-description>     # 버그 수정
docs/<doc-name>           # 문서 작업
refactor/<target>         # 리팩토링
```

### Workflow Rules

1. `main` 브랜치는 항상 배포 가능한 상태를 유지한다
2. 모든 작업은 `main`에서 새 브랜치를 생성하여 진행한다
3. 작업 완료 후 Pull Request를 생성한다
4. PR 머지 후 feature 브랜치는 삭제한다
5. 직접 `main`에 push하지 않는다

### Commit Message Convention

```
<type>: <subject>

<body (optional)>
```

**Type**: feat, fix, docs, style, refactor, test, chore

예시:
```
feat: 코인 수집 시스템 구현
fix: 플레이어 낙사 판정 오류 수정
docs: 게임 기획서 v1 작성
```

## Project Structure

```
roblox-coin-runner/
├── CLAUDE.md                   # 프로젝트 규칙 (이 파일)
├── default.project.json        # Rojo 프로젝트 설정
├── aftman.toml                 # 도구 버전 관리
├── selene.toml                 # 린터 설정
├── stylua.toml                 # 포매터 설정
├── wally.toml                  # 패키지 의존성
├── docs/
│   └── design/                 # 게임 기획 문서
│       └── game-design.md      # 메인 기획서
└── src/
    ├── server/                 # ServerScriptService
    │   ├── init.server.luau    # 서버 진입점
    │   └── Services/           # 서버 서비스 모듈
    ├── client/                 # StarterPlayerScripts
    │   ├── init.client.luau    # 클라이언트 진입점
    │   ├── Controllers/        # 입력, 카메라 등 제어 모듈
    │   └── UI/                 # GUI 관련 모듈
    └── shared/                 # ReplicatedStorage (서버/클라이언트 공유)
        └── Constants/          # 게임 상수 정의
```

## Coding Conventions

### Language

- **코드**: English (변수명, 함수명, 주석 모두 영어)
- **문서**: Korean (기획서, README 등)
- **커밋 메시지**: Korean body 허용, type/subject는 영어

### Luau Style

- Indentation: Tab
- Column width: 120
- Quote style: Double quotes
- Naming:
  - `PascalCase`: 모듈, 서비스, 클래스
  - `camelCase`: 지역 변수, 함수
  - `UPPER_SNAKE_CASE`: 상수
  - `_privateMethod`: private 메서드 prefix

### File Naming

- 서버 스크립트: `*.server.luau`
- 클라이언트 스크립트: `*.client.luau`
- 공유 모듈: `*.luau`
- 폴더 진입점: `init.luau`, `init.server.luau`, `init.client.luau`

## Rojo Workflow

1. `rojo serve`로 개발 서버 시작
2. Roblox Studio에서 Rojo 플러그인으로 연결
3. 코드는 외부 에디터(Claude Code)에서 편집
4. 맵/파트/UI 등 비주얼 작업은 Roblox Studio에서 직접 편집

## Architecture Principles

### Client-Server Model

- Roblox는 클라이언트-서버 모델을 사용한다
- **서버**: 게임 로직의 권위자 (코인 생성, 점수 관리, 검증)
- **클라이언트**: 입력 처리, 카메라, UI 렌더링
- **통신**: RemoteEvent / RemoteFunction 사용

### Key Rules

- 클라이언트를 절대 신뢰하지 않는다 (서버에서 항상 검증)
- 게임 상태는 서버가 소유한다
- 클라이언트는 요청만 하고, 서버가 승인한다
- 공유 상수는 `shared/Constants/`에 정의한다

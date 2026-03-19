---
id: ISSUE-002
title: 로비 비어 있어 게임 진행 불가 (LobbyService 초기화 의존성 문제)
category: blocker
priority: P0-critical
status: resolved
related_sprint: none (v3.0 완료 후 스모크 테스트)
related_ac: AC-0-9
created: 2026-03-19
resolved: 2026-03-19
---

## 설명
ISSUE-001 수정 후에도 로비가 여전히 비어 있어 게임 진행 불가.
LobbyService:Initialize()가 GameManager 내부(206행)에서 호출되므로,
GameManager의 40+개 require 중 하나라도 실패하면 로비가 생성되지 않음.

## 영향 분석
- **근본 원인**: LobbyService:Initialize()가 GameManager 모듈 로드 체인에 묶여 있음.
  GameManager는 42개 서비스를 require하며, 어느 하나라도 에러 시 전체 실패.
- **영향 범위**: 모든 플레이어 (게임 진입 불가 — P0 블로커)
- **관련 파일**:
  - `src/server/init.server.luau` — 서버 진입점
  - `src/server/Services/GameManager.luau` — 206행 LobbyService:Initialize()
  - `src/server/Services/LobbyService.luau` — 로비 생성

## 해결 방안
1. LobbyService:Initialize()를 init.server.luau에서 GameManager보다 먼저, pcall로 보호하여 호출
2. 성공 시에만 Baseplate 삭제, 실패 시 Baseplate를 fallback으로 유지
3. LobbyService에 initialized 가드 추가 (GameManager 내부 중복 호출 방지)

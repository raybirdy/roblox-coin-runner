---
id: ISSUE-001
title: 로비 바닥 미생성으로 캐릭터 낙사
category: bug
priority: P0-critical
status: resolved
related_sprint: none (v3.0 완료 후 발견)
related_ac: AC-0-9 (스모크 테스트)
created: 2026-03-19
resolved: 2026-03-19
---

## 설명
게임 실행 시 로비가 비어 있어 캐릭터가 떨어져 죽는 문제.

## 영향 분석
- **근본 원인**: `init.server.luau`에서 Baseplate를 서비스 로드 전에 즉시 삭제.
  GameManager require 중 에러 발생 시 `LobbyService:Initialize()`가 실행되지 않아 바닥 없이 캐릭터 스폰.
- **영향 범위**: 모든 플레이어 (게임 진입 불가)
- **관련 파일**: `src/server/init.server.luau`, `src/server/Services/LobbyService.luau`, `src/server/Services/GameManager.luau`

## 해결 방안
Baseplate 삭제를 GameManager require (= LobbyService:Initialize()) **이후**로 이동.
로비 바닥이 생성된 후에만 기본 Baseplate를 제거하도록 순서 변경.

**변경 파일**: `src/server/init.server.luau`
- 기존: 10~15행에서 Baseplate 즉시 삭제 → 23행에서 GameManager 로드
- 수정: GameManager 로드(16행) → Baseplate 삭제(18~23행)

---
id: ISSUE-023
title: 챕터 2 완료 후 챕터 3으로 전환되지 않음
category: bug
priority: P1-high
status: open
related_sprint: v3.1 Sprint 1 후보
related_ac: none
created: 2026-03-31
resolved: null
---

## 설명

챕터 2의 퀘스트가 모두 완료된 상태인데 챕터 3으로 넘어가지 않는다.

## 영향 분석

**챕터 완료 코드 경로** (oracle 분석):

```
GameManager:EndGame()
  → ScenarioService:UpdateQuestProgress() (8회 호출)
    → ScenarioService:_checkChapterCompletion()
      → 보스런 미클리어 시: BossRunService:StartBossRun()
      → 보스런 클리어 후:  ScenarioService:_completeChapter()
        → 다음 챕터 언락 조건 확인 (_isChapterUnlocked)
          → ChapterUnlocked RemoteEvent 발사
```

**의심 원인 3가지**

1. **챕터 3 언락 조건 미충족** (`ScenarioService:_isChapterUnlocked()`):
   - `minScore` 조건: ch3는 최소 점수 요구 가능성 (ScenarioConstants ch3 정의 확인 필요)
   - `requiredCompletedChapters`: ch1 + ch2 완료 모두 필요 — ch1이 완료 처리되지 않았을 수 있음
   - 확인 위치: `src/shared/Constants/ScenarioConstants.luau` ch3.unlockConditions

2. **보스런 미연동**: 챕터 2 퀘스트 완료 → 보스런 트리거 → 보스런 미출시/비활성화 상태로 인해
   `bossRunCompleted["ch2"]` 플래그가 영원히 false로 남음
   - `BossRunService`가 비활성화됐을 경우 `_checkChapterCompletion`이 StartBossRun만 호출하고 챕터 완료 불가
   - 확인 위치: `src/server/Services/BossRunService.luau` 활성화 여부

3. **클라이언트 이벤트 미수신**: `ScenarioService:_completeChapter()`는 정상 실행되지만
   클라이언트의 `ChapterUnlocked` 핸들러가 없거나 UI를 올바르게 표시하지 않음
   - 확인 위치: `src/client/Controllers/ScenarioController.luau` `ChapterUnlocked` 구독 여부

**영향 범위**
- `src/server/Services/ScenarioService.luau` — `_checkChapterCompletion`, `_completeChapter`
- `src/server/Services/BossRunService.luau` — 보스런 완료 → TriggerChapterCompletion 호출
- `src/shared/Constants/ScenarioConstants.luau` — ch3 unlockConditions
- `src/client/Controllers/ScenarioController.luau` — ChapterUnlocked 클라이언트 처리

**재현 조건**
- 챕터 2 퀘스트 전체 완료 후 게임 종료
- 서버 콘솔: `[ScenarioService] _completeChapter` 로그 출력 여부 확인
- 클라이언트 콘솔: `[ScenarioController] ChapterUnlocked` 로그 출력 여부 확인

## 해결 방안
(등록 시점에는 비워둠 — 처리 시 채움)

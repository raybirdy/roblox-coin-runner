# QA 리포트 — ISSUE-022, ISSUE-023
날짜: 2026-04-01

## 대상 픽스

| 이슈 | 제목 | 커밋 |
|------|------|------|
| ISSUE-022 | 랜덤 이벤트 첫 발동 지연 | e5c783d |
| ISSUE-023 | 챕터 2 완료 후 챕터 3 전환 불가 | 4dd5098 |

---

## 테스트 결과

| # | 체크 항목 | 결과 | 비고 |
|---|-----------|------|------|
| 1 | ISSUE-022: 이벤트 중복 발동 방지 (active guard) | PASS | RandomEventService:42-48 |
| 2 | ISSUE-022: 이벤트 오버랩 불가 | PASS | _nextEventTime nil 처리로 방지 |
| 3 | ISSUE-022: SOLO_TRIGGER_INTERVAL 미사용 (데드 코드) | **FIX** | getNextTriggerTime에 isSolo 파라미터 추가 |
| 4 | ISSUE-023: changed=false 시 _checkAndNotifyUnlockedChapters 미실행 | **FIX** | changed 가드 앞으로 이동 |
| 5 | ISSUE-023: ChapterUnlocked 이중 발송 방지 | PASS | sent[chapter.id] 플래그 |
| 6 | ISSUE-023: 기존 유저 마이그레이션 | PASS | chapterOpeningsSent 초기화 로직 |
| 7 | ISSUE-023: 순환 의존성 (ScenarioService ↔ BossRunService) | PASS | task.delay 내 deferred require |
| 8 | ISSUE-023: nil 안전성 | PASS | 모든 nil 경로 가드 확인 |

---

## QA 과정에서 발견·수정된 추가 버그

### QA-FIX-1: SOLO_TRIGGER_INTERVAL 데드 코드
- **위치**: `RandomEventService.luau:22-26`
- **증상**: `SOLO_TRIGGER_INTERVAL = 12` 가 GameConstants에 정의됐으나 `getNextTriggerTime()`이 solo 여부와 무관하게 동일 interval 적용
- **수정**: `getNextTriggerTime(isSolo: boolean?)` 파라미터 추가, `session.coopSessionId` 유무로 solo 판별

### QA-FIX-2: UpdateQuestProgress early-return 전 _checkAndNotifyUnlockedChapters 미실행
- **위치**: `ScenarioService.luau:96-98`
- **증상**: highScore가 이미 외부(PlayerDataService:OnGameEnd)에서 갱신됐더라도, 해당 게임에서 퀘스트 진행이 없으면(changed=false) 챕터 오프닝 체크가 스킵됨
- **수정**: `_checkAndNotifyUnlockedChapters` 호출을 `changed` 가드 앞으로 이동

---

## 수동 검증 체크리스트 (Studio 필요)

```
랜덤 이벤트:
[ ] 솔로 게임: 5-11초 내 첫 이벤트 발동
[ ] 솔로 게임: 이벤트 간격 12±3초 (이전 이벤트 종료 기준)
[ ] 이벤트 중 다른 이벤트가 동시 발동하지 않음
[ ] Output: "[RandomEventController] Event START: {id}" 로그 출력 확인
[ ] Output: "[RandomEventService] {id} started for {player}" 서버 로그 확인

챕터 전환:
[ ] ch2 퀘스트 완료 → 보스런 진입
[ ] 보스런 클리어 → ch2 완료 보상 수신
[ ] ch2 완료 직후 highScore>=1000이면 ch3 오프닝 즉시 표시
[ ] ch2 완료 시 highScore<1000이면 ch3 오프닝 표시 안 됨
[ ] 이후 게임에서 1000점 달성 → 게임 종료 직후 ch3 오프닝 표시
[ ] 재로그인 시 ch3 오프닝 재확인 (3초 딜레이 후)
```

---

## 릴리즈 게이팅 결론

```
[X] CONDITIONAL — 조건부 배포 가능
    조건: Studio 수동 검증 체크리스트 통과 후 배포
```

### 설계 주의사항 (코드 버그 아님)
- 이벤트 발동 빈도 ~50% (8s 간격, 8-12s 지속): 6-12세 타겟 감안하여 플레이테스트 후 재조정 고려

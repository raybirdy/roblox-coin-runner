# v3.1 Sprint 0 — 스모크 테스트 체크리스트

> 모바일 UI 최적화 스프린트의 기능 검증 체크리스트
> 테스트 환경: Roblox Studio (로컬 서버 + 클라이언트)

## 테스트 환경 설정

- [ ] `rojo serve` → Studio Rojo 플러그인 연결
- [ ] 로컬 서버 시작 (1 플레이어)
- [ ] Studio 디바이스 에뮬레이터: iPhone SE (375x667) 설정

---

## 1. UIVisibilityManager 상태 전환

### 1.1 로비 → 카운트다운 → 러닝

- [ ] 로비에서 DailyChallengeGui 표시됨
- [ ] 로비에서 ProgressionController(레벨/XP) 표시됨
- [ ] 로비에서 리더보드/랭킹 표시됨
- [ ] 게임 시작(카운트다운) 시 DailyChallengeGui 숨김
- [ ] 카운트다운 시 ObjectiveHUD 전체 모드 표시 (리롤 버튼 활성)
- [ ] 러닝 진입 시 ObjectiveHUD 3초 후 아이콘 모드로 자동 축소
- [ ] 러닝 중 ActiveSkill 버튼 표시
- [ ] 러닝 중 피버 게이지 표시

### 1.2 러닝 → 게임오버 → 로비

- [ ] 게임오버 시 ActiveSkill 버튼 숨김
- [ ] 게임오버 시 ObjectiveHUD 숨김
- [ ] 게임오버 시 피버 게이지 숨김
- [ ] 게임오버 프레임 표시 + 딤 오버레이
- [ ] 로비 복귀 시 DailyChallengeGui 재표시
- [ ] 로비 복귀 시 리더보드/랭킹 재표시

### 1.3 잘못된 전이 복구

- [ ] 콘솔에서 `[UIVisibilityManager] Invalid transition` 경고 시 lobby로 폴백 확인

---

## 2. ObjectiveHUD (목표 HUD)

- [ ] 카운트다운 중 전체 패널 표시 (3개 목표 행)
- [ ] 카운트다운 중 리롤 버튼(🔄) 터치 가능
- [ ] 러닝 진입 3초 후 48x48 아이콘 모드로 축소
- [ ] 아이콘 탭 시 전체 패널 1.5초 펼침 후 재축소
- [ ] 아이콘에 완료 진행도(0/3, 1/3 등) 표시
- [ ] 전체 완료 시 골드 테두리 + 완료 배너

---

## 3. DailyChallengeController

- [ ] 로비에서만 표시 (Enabled=true)
- [ ] 게임 시작 시 Enabled=false
- [ ] 게임오버 후 로비 복귀 시 Enabled=true 복구

---

## 4. ActiveSkillController

- [ ] 스킬 장착 상태에서 게임 시작 시 버튼 표시
- [ ] 버튼 터치 시 스킬 발동 (서버 확인)
- [ ] 쿨다운 중 오버레이 + 초 카운트 표시
- [ ] 게임오버 시 버튼 제거
- [ ] iPhone SE에서 버튼이 화면 밖으로 벗어나지 않음

---

## 5. RunSkillHudController

- [ ] 러닝 중 XP바 우측 상단 표시
- [ ] 런 레벨업 시 스킬 선택 패널 슬라이드 인
- [ ] 카드 3장 표시 (이모지, 이름, 설명, 희귀도)
- [ ] 카드 터치 시 스킬 선택 + 패널 닫힘
- [ ] iPhone SE(375px)에서 선택 패널이 화면 너비 초과하지 않음
- [ ] 자동 선택 타이머 바 애니메이션

---

## 6. ResponsiveUtil compactMode (iPhone SE 375px)

- [ ] HUD 요소 간 겹침 없음 (목표: AC-0-8)
- [ ] 모든 터치 버튼 최소 48x48px 확인 (AC-0-5)
- [ ] 점프/슬라이드 버튼 정상 크기 유지
- [ ] ActiveSkill 버튼 적절 크기 (64px 기반)
- [ ] RunSkill 선택 패널 화면 내 표시
- [ ] 텍스트 가독성 유지 (최소 폰트 크기 준수)

---

## 7. 일반 게임플레이

- [ ] 솔로 러닝 5회 정상 완료 (코인 수집, 장애물 회피)
- [ ] 코인 수집 시 시각 피드백 (캐릭터 플래시)
- [ ] 피버 모드 진입/종료 정상
- [ ] 다이아몬드 코인 슬로모 효과
- [ ] 게임오버 후 점수/코인/거리 정확히 표시

---

## 결과 기록

| 항목 | 통과 | 실패 | 비고 |
|------|------|------|------|
| UIVisibilityManager | | | |
| ObjectiveHUD | | | |
| DailyChallenge | | | |
| ActiveSkill | | | |
| RunSkillHud | | | |
| compactMode | | | |
| 일반 게임플레이 | | | |

**테스터**: ___
**날짜**: ___
**빌드**: v3.1 Sprint 0

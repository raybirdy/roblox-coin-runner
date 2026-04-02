---
id: ISSUE-025
title: 스킬 선택 화면 다이얼로그 overflow — 아이콘이 패널 밖으로 빠져나옴
category: bug
priority: P1-high
status: resolved
related_sprint: none
related_ac: none
created: 2026-04-02
resolved: 2026-04-02
---

## 설명
게임 시작 전 스킬 선택 화면(PreRunSkillController)에서 스킬 카드의 이모지 아이콘이
다이얼로그(패널) 밖으로 빠져나와 보임.

## 영향 분석

**근본 원인 2가지:**

1. **패널 고정 픽셀 크기** (`src/client/Controllers/PreRunSkillController.luau:66`)
   - `panel.Size = UDim2.new(0, 420, 0, 340)` — 화면 크기에 상관없이 고정
   - 모바일 소형 화면에서 비율이 맞지 않아 내부 컨텐츠가 상대적으로 과대해짐

2. **ClipDescendants 미설정** (panel 및 카드 Frame)
   - 패널과 카드에 `ClipDescendants = true` 없음
   - UICorner가 적용된 패널 밖으로 자식 요소가 시각적으로 overflow 가능

3. **스킬 카드 내부 레이아웃 여백 부족** (`_refresh() :287`)
   - `emojiLabel.Size = UDim2.new(0, 30, 1, 0)` — Position 미설정(기본 0,0,0,0)
   - 카드 크기(118×68)에서 이모지(TextSize=22) + 이름 + 설명 텍스트가 비좁음

**영향 범위:**
- `src/client/Controllers/PreRunSkillController.luau`

## 해결 방안
1. 패널 크기 420×340 → 460×420 (콘텐츠 여백 확보)
2. `panel.ClipDescendants = true` 추가 (UICorner 밖 overflow 방지)
3. GridScroll 높이 160 → 210, CellSize 118×68 → 130×82 (카드 확대)
4. 카드에 `ClipDescendants = true` 추가
5. `emojiLabel.Position = UDim2.new(0, 4, 0, 0)` 명시, nameLabel/descLabel 여백 정리
6. 커밋: `015d91b`

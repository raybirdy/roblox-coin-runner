---
id: IDEA-007
title: 환경 비주얼 이펙트 (날씨/파티클)
origin: feature
status: selected
created: 2026-04-01
---

## 아이디어
사막 모래 파티클, 도시 빗방울, 우주 별똥별 등 챕터/존별 비주얼 전용 날씨 이펙트.
게임플레이 영향 없이 순수 분위기 연출.

## 해결하는 문제
맵 배경이 정적이고 세계관 몰입감 부족.

## 타겟 사용자
전체 플레이어

## 평가
- 사용자 가치: ⭐⭐
- 구현 난이도: 🟢 S
- 리스크: 낮음 (게임플레이 영향 없음)
- 아이 위험도: 없음 (비주얼 전용)

## 구현 포인트
- WeatherController 클라이언트 신규 (ParticleEmitter 관리)
- Zone/챕터 전환 시 파티클 교체
- 종류: rain(도시), sand_dust(사막), snowflakes(설원), sparkles(숲), stars(우주)
- 성능: MaxParticles 50 이하, 카메라 근처만 방출

## 다음 행동
/dev IDEA-007 → v3.2 Sprint 편입

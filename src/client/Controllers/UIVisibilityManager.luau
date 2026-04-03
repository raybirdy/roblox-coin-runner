--!strict
-- UIVisibilityManager
-- 게임 상태별 UI 가시성 중앙 관리
-- docs/design/mobile-ui-spec.md §3 (UI 상태 머신), §7 (설계), §9.1-9.3 (momus 반영) 참조

local TweenService = game:GetService("TweenService")

local UIVisibilityManager = {}
UIVisibilityManager.__index = UIVisibilityManager

-- ===== 타입 정의 =====

export type GameUIState = "lobby" | "countdown" | "running" | "minigame" | "paused" | "gameover"

-- §9.1: 완전한 컨트롤러 목록 (randomEventController는 토스트 전용이므로 제외)
export type Controllers = {
	uiController: any?,
	progressionController: any?,
	objectiveHudController: any?,
	runSkillHudController: any?,
	dailyChallengeController: any?,
	activeSkillController: any?,
	feverController: any?,
	petController: any?,
	scenarioController: any?,
	worldMapController: any?,
	realtimeBattleController: any?,
	miniGameController: any?,
	coinKingController: any?,
	dailyEventController: any?,
	leaderboardController: any?,
	rankingController: any?,
}

-- ===== 유효 전이 테이블 (§9.2: momus P0 엣지 케이스 반영) =====
-- lobby -> lobby : 재접속/씬 전환 시 idempotent 재진입
-- countdown -> lobby : 카운트다운 중 연결 해제 또는 취소
-- minigame -> gameover : 미니게임 진행 중 라이프 소진
local VALID_TRANSITIONS: { [GameUIState]: { GameUIState } } = {
	lobby     = { "countdown", "lobby" },
	countdown = { "running", "lobby" },
	-- running→countdown: 캐릭터 리스폰 후 GameOver 미수신 상태에서 포탈 재진입 시 레이스 컨디션 허용
	-- running→lobby: ReturnToLobby 수신 시 경고 없이 처리
	running   = { "minigame", "paused", "gameover", "countdown", "lobby" },
	minigame  = { "running", "gameover", "countdown" }, -- minigame 중 재시작 허용
	paused    = { "running", "countdown" },             -- 일시정지 중 재시작 허용
	gameover  = { "lobby", "countdown" }, -- gameover→countdown: ReturnToLobby 전에 포탈 재진입 가능 (레이스 컨디션 허용)
}

-- ===== 생성자 =====

function UIVisibilityManager.new(controllers: Controllers)
	local self = setmetatable({}, UIVisibilityManager)
	self._controllers = controllers
	self._currentState = "lobby" :: GameUIState
	self._activeTweens = {} :: { Tween }  -- §9.8: 진행 중인 트윈 추적
	return self
end

-- ===== 공개 API =====

-- 싱글톤 초기화 (init.client.luau에서 호출)
function UIVisibilityManager:Init(controllers: Controllers)
	self._controllers = controllers
	self._currentState = "lobby" :: GameUIState
	self._activeTweens = {} :: { Tween }
end

-- 현재 상태 조회
function UIVisibilityManager:GetState(): GameUIState
	return self._currentState
end

-- 상태 전이 (§7.2 에러 복구 + §9.2 엣지 케이스 포함)
function UIVisibilityManager:SetState(newState: GameUIState)
	local prevState = self._currentState

	-- 유효 전이 검증
	local validTargets = VALID_TRANSITIONS[prevState]
	if validTargets then
		local isValid = false
		for _, target in validTargets do
			if target == newState then
				isValid = true
				break
			end
		end
		if not isValid then
			warn(
				"[UIVisibilityManager] Invalid transition: "
					.. tostring(prevState)
					.. " -> "
					.. tostring(newState)
					.. ", forcing lobby"
			)
			newState = "lobby"
		end
	else
		warn("[UIVisibilityManager] Unknown current state: " .. tostring(prevState))
		newState = "lobby"
	end

	-- §9.8: 상태 전이 전 진행 중인 트윈 모두 취소
	self:CancelAllTweens()

	self._currentState = newState
	self:_applyState(newState)

	print("[UIVisibilityManager] State: " .. tostring(prevState) .. " -> " .. tostring(newState))
end

-- §9.8: 진행 중인 트윈 일괄 취소 (컨트롤러 내부 트윈은 각 컨트롤러가 책임)
function UIVisibilityManager:CancelAllTweens()
	for _, tween in self._activeTweens do
		if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
			tween:Cancel()
		end
	end
	table.clear(self._activeTweens)
end

-- 트윈 등록 (UIVisibilityManager가 직접 생성하는 fade 트윈에 사용)
function UIVisibilityManager:_trackTween(tween: Tween)
	table.insert(self._activeTweens, tween)
end

-- ===== 상태 적용 내부 로직 =====

function UIVisibilityManager:_applyState(state: GameUIState)
	local c = self._controllers
	if not c then
		warn("[UIVisibilityManager] _applyState called before Init, state=" .. tostring(state))
		return
	end

	-- 컨트롤러 메서드를 안전하게 호출하는 헬퍼
	local function safeCall(controller: any?, method: string)
		if controller == nil then return end
		local fn = (controller :: any)[method]
		if type(fn) == "function" then
			fn(controller)
		else
			warn("[UIVisibilityManager] Method not found: " .. tostring(method) .. " on controller")
		end
	end

	-- ===== §3.2 상태별 UI 가시성 매트릭스 구현 =====

	if state == "lobby" then
		-- §7.1 lobby 진입 훅: 로비 전용 UI 전부 표시, 게임 전용 UI 숨김
		-- lobby -> lobby idempotent: prevState 무관하게 항상 전체 로비 UI 재적용
		safeCall(c.uiController, "ShowLobbyUI")
		safeCall(c.progressionController, "ShowInLobby")        -- Lv/XP/MissionBtn
		safeCall(c.dailyChallengeController, "Show")            -- 로비 전용 (§5.2)
		safeCall(c.objectiveHudController, "EndGame")           -- HUD 숨김
		safeCall(c.runSkillHudController, "EndGame")            -- XP바 + 스킬 패널 숨김
		safeCall(c.activeSkillController, "OnGameEnd")          -- 스킬 버튼 숨김
		safeCall(c.feverController, "HideGauge")                -- 피버 게이지 숨김
		safeCall(c.petController, "StopGame")                   -- 펫 UI 숨김
		safeCall(c.miniGameController, "HideUI")                -- §9.3: minigame HUD 숨김
		safeCall(c.coinKingController, "Hide")                  -- 코인킹 숨김
		safeCall(c.scenarioController, "ShowInLobby")           -- 시나리오 오버레이
		safeCall(c.worldMapController, "ShowInLobby")           -- 월드 맵
		safeCall(c.realtimeBattleController, "ShowInLobby")     -- 실시간 배틀
		safeCall(c.dailyEventController, "ShowInLobby")         -- 일일 이벤트 HUD
		safeCall(c.leaderboardController, "Show")               -- 리더보드
		safeCall(c.rankingController, "ShowInLobby")            -- 랭킹

	elseif state == "countdown" then
		-- §7.1 countdown 진입: 게임 준비 UI, 목표 HUD는 전체 모드(리롤 활성)
		safeCall(c.uiController, "HideLobbyUI")
		safeCall(c.progressionController, "HideForGame")        -- Lv/XP 숨김
		safeCall(c.dailyChallengeController, "Hide")            -- 로비 전용 패널 숨김
		safeCall(c.leaderboardController, "Hide")               -- 리더보드 숨김
		safeCall(c.rankingController, "HideForGame")            -- 랭킹 숨김
		safeCall(c.realtimeBattleController, "HideForGame")     -- 배틀 HUD 숨김
		safeCall(c.scenarioController, "HideForGame")           -- 시나리오 숨김
		safeCall(c.worldMapController, "HideForGame")           -- 월드 맵 숨김
		safeCall(c.dailyEventController, "Hide")                -- 일일 이벤트 숨김
		safeCall(c.activeSkillController, "OnGameEnd")          -- 스킬 버튼 숨김
		safeCall(c.feverController, "HideGauge")                -- 피버 게이지 숨김
		safeCall(c.miniGameController, "HideUI")                -- §9.3
		-- ObjectiveHUD는 전체 모드(리롤 가능): countdown 전용 동작
		safeCall(c.objectiveHudController, "StartGame")         -- 전체 모드 + 리롤 활성

	elseif state == "running" then
		-- §7.1 countdown -> running: 최소 HUD (activeSkill + objectiveHud 아이콘 모드)
		-- §9.3: miniGameController는 반드시 먼저 숨김
		safeCall(c.miniGameController, "HideUI")                -- §9.3: 복귀 시 숨김
		safeCall(c.dailyChallengeController, "Hide")            -- 로비 전용 숨김
		safeCall(c.progressionController, "HideForGame")        -- Lv/XP 숨김
		safeCall(c.runSkillHudController, "StartGame")          -- XP바 숨김, 스킬 패널 대기
		safeCall(c.scenarioController, "HideForGame")           -- 시나리오 숨김
		safeCall(c.worldMapController, "HideForGame")           -- 월드 맵 숨김
		safeCall(c.leaderboardController, "Hide")               -- 리더보드 숨김
		safeCall(c.rankingController, "HideForGame")            -- 랭킹 숨김
		safeCall(c.realtimeBattleController, "SetGameActive")   -- 실시간 배틀 게임 모드
		safeCall(c.coinKingController, "StartGame")             -- 코인킹 추적 시작
		safeCall(c.petController, "StartGame")                  -- 펫 동반 UI
		safeCall(c.dailyEventController, "StartGame")           -- 일일 이벤트 게임 모드
		-- 필수 게임 HUD
		safeCall(c.activeSkillController, "OnGameStart")        -- 스킬 버튼 표시
		safeCall(c.objectiveHudController, "CollapseToIcon")    -- 아이콘 모드 전환 (§6.1)
		safeCall(c.feverController, "ShowGauge")                -- 피버 게이지 표시

	elseif state == "minigame" then
		-- §7.1 + §9.3 minigame 진입: 게임 HUD 숨기고 미니게임 HUD 표시
		safeCall(c.objectiveHudController, "HideIcon")          -- 아이콘 숨김
		safeCall(c.activeSkillController, "OnGameEnd")          -- 스킬 버튼 숨김
		safeCall(c.feverController, "HideGauge")                -- 피버 게이지 숨김
		safeCall(c.dailyChallengeController, "Hide")
		safeCall(c.progressionController, "HideForGame")
		safeCall(c.runSkillHudController, "EndGame")            -- 스킬 패널 닫기
		safeCall(c.miniGameController, "ShowUI")                -- §9.3: 미니게임 HUD 활성화

	elseif state == "paused" then
		-- §7.1 paused: 스킬 선택 패널 표시 (RunSkillHud), 나머지 HUD 유지
		-- HUD(uiController)는 계속 표시 상태 유지 — 추가 오버레이만 적용
		safeCall(c.activeSkillController, "OnGameEnd")          -- 스킬 버튼 숨김 (선택 중)
		-- RunSkillHudController:ShowSkillSelection()은 RunSkillHudController 내부에서
		-- 런 레벨업 이벤트로 트리거하므로 UIVisibilityManager는 직접 호출하지 않음

	elseif state == "gameover" then
		-- §7.1 gameover: 게임 오버 화면 표시, 스탯 확인용 progression 표시
		safeCall(c.uiController, "ShowGameOver")                -- 게임오버 프레임
		safeCall(c.activeSkillController, "OnGameEnd")          -- 스킬 버튼 숨김
		safeCall(c.objectiveHudController, "EndGame")           -- 목표 HUD 숨김
		safeCall(c.runSkillHudController, "EndGame")            -- 런 스킬 패널 닫기
		safeCall(c.feverController, "HideGauge")                -- 피버 게이지 숨김
		safeCall(c.miniGameController, "HideUI")                -- §9.3: 미니게임 HUD 숨김
		safeCall(c.petController, "StopGame")                   -- 펫 UI 숨김
		safeCall(c.coinKingController, "Hide")                  -- 코인킹 숨김
		safeCall(c.dailyEventController, "EndGame")             -- 이벤트 HUD 숨김
		safeCall(c.progressionController, "ShowInLobby")        -- 게임오버 스탯 표시용
	end
end

return UIVisibilityManager

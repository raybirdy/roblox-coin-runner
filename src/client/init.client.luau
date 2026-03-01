--!strict
-- Client Entry Point
-- 클라이언트 측 진입점 - UI 및 입력 처리 초기화

print("[Client] Coin Runner Client Starting...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- 공유 모듈 로드
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local _humanoid = character:WaitForChild("Humanoid") :: Humanoid

print("[Client] Game Constants Loaded")
print("[Client] Remote Events Connected")

-- Roblox 기본 컨트롤 관리
local _PlayerGui = player:WaitForChild("PlayerGui")
local controlModule = require(player.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))

local function disableDefaultControls()
	-- 현재 캐릭터의 humanoid 가져오기
	local currentCharacter = player.Character
	local currentHumanoid = currentCharacter and currentCharacter:FindFirstChild("Humanoid") :: Humanoid?

	-- 기본 점프 버튼 비활성화
	if currentHumanoid then
		currentHumanoid.JumpHeight = 0 -- 기본 점프 비활성화 (커스텀 점프 사용)
		currentHumanoid.AutoRotate = false -- 게임 중에는 자동 회전 비활성화
	end

	-- 기본 이동 조이스틱 비활성화 (모바일)
	if controlModule then
		controlModule:Disable()
	end

	print("[Client] Default Roblox controls disabled")
end

local function enableDefaultControls()
	-- 현재 캐릭터의 humanoid 가져오기
	local currentCharacter = player.Character
	local currentHumanoid = currentCharacter and currentCharacter:FindFirstChild("Humanoid") :: Humanoid?

	-- 기본 이동 활성화 (로비용)
	if controlModule then
		controlModule:Enable()
	end

	-- 점프는 로비에서도 허용
	if currentHumanoid then
		currentHumanoid.JumpHeight = 7.2 -- Roblox 기본값
	end

	print("[Client] Default Roblox controls enabled (lobby mode)")
end

-- 초기 설정: 로비에서는 기본 이동 허용
enableDefaultControls()

-- 클라이언트 컨트롤러 로드
local InputController = require(script.Controllers.InputController)
local PlayerController = require(script.Controllers.PlayerController)
local CoinController = require(script.Controllers.CoinController)
local LifeController = require(script.Controllers.LifeController)
local UIController = require(script.Controllers.UIController)
local PowerupController = require(script.Controllers.PowerupController)
local CameraController = require(script.Controllers.CameraController)
local NPCController = require(script.Controllers.NPCController)
local TutorialController = require(script.Controllers.TutorialController)
local MusicController = require(script.Controllers.MusicController)
local ShopController = require(script.Controllers.ShopController)
local SpeedEffectController = require(script.Controllers.SpeedEffectController)
local LeaderboardController = require(script.Controllers.LeaderboardController)
local StartPowerupController = require(script.Controllers.StartPowerupController)
local ProgressionController = require(script.Controllers.ProgressionController)
local LoginRewardController = require(script.Controllers.LoginRewardController)
local LuckySpinController = require(script.Controllers.LuckySpinController)
local FeverController = require(script.Controllers.FeverController)
local ZoneController = require(script.Controllers.ZoneController)
local CharacterEffectsController = require(script.Controllers.CharacterEffectsController)
local ScenarioController = require(script.Controllers.ScenarioController)
local CutsceneController = require(script.Controllers.CutsceneController)
local WorldMapController = require(script.Controllers.WorldMapController)
local BossRunController = require(script.Controllers.BossRunController)
local SkillController = require(script.Controllers.SkillController)
local RankingController = require(script.Controllers.RankingController)
local AsyncBattleController = require(script.Controllers.AsyncBattleController)
local RealtimeBattleController = require(script.Controllers.RealtimeBattleController)

-- 컨트롤러 인스턴스 생성
local inputController = InputController.new()
local playerController = PlayerController.new(player, character)
local coinController = CoinController.new()
local _lifeController = LifeController.new()
local uiController = UIController.new(player)
local powerupController = PowerupController.new()
local cameraController = CameraController.new(player, character)
local npcController = NPCController.new()
local tutorialController = TutorialController.new()
local musicController = MusicController.new()
local shopController = ShopController.new(player)
local speedEffectController = SpeedEffectController.new(player)
local leaderboardController = LeaderboardController.new(player)
local startPowerupController = StartPowerupController.new(player)
local progressionController = ProgressionController.new(player)
local _loginRewardController = LoginRewardController.new(player)
local _luckySpinController = LuckySpinController.new(player)
local feverController = FeverController.new()
local zoneController = ZoneController.new()
local characterEffectsController = CharacterEffectsController.new(character)
local scenarioController = ScenarioController.new(player)
local _cutsceneController = CutsceneController.new()
local worldMapController = WorldMapController.new(player)
scenarioController:SetWorldMapController(worldMapController)
local _bossRunController = BossRunController.new()
local skillController = SkillController.new(player, playerController)
local rankingController = RankingController.new(player)
local asyncBattleController = AsyncBattleController.new(player)
local realtimeBattleController = RealtimeBattleController.new(player)

-- Fever mode callbacks (speed boost + camera shake)
feverController:OnFeverStart(function(speedBoost: number)
	playerController:SetSpeedMultiplier(speedBoost)
	cameraController:Shake(0.8) -- strong shake on fever start
end)

feverController:OnFeverEnd(function()
	playerController:SetSpeedMultiplier(1.0)
end)

-- 코인 수집 캐릭터 플래시
coinController:OnCoinEffect(function(coinType: string)
	characterEffectsController:FlashCoin(coinType)
end)

-- 파워업 캐릭터 글로우 (활성/비활성)
powerupController:OnPowerupGlowChange(
	function(powerupType: string)
		characterEffectsController:SetPowerupGlow(powerupType, true)
	end,
	function(powerupType: string)
		if powerupType == "Shield" then
			characterEffectsController:FlashShieldBreak()
		else
			characterEffectsController:SetPowerupGlow(powerupType, false)
		end
	end
)

-- Diamond coin slowmo + zoom + sound
local diamondSlowmoActive = false
coinController:OnDiamondCollected(function()
	if feverController:IsFever() or diamondSlowmoActive then
		return
	end
	diamondSlowmoActive = true
	playerController:SetSpeedMultiplier(0.3)
	cameraController:Zoom(-3, 1.0)
	cameraController:Shake(0.3)
	task.delay(1.0, function()
		diamondSlowmoActive = false
		if playerController:IsPlaying() and not feverController:IsFever() then
			playerController:SetSpeedMultiplier(1.0)
		end
	end)
end)

-- Mass coin collection zoom tracking
local massCollectCount = 0
local massCollectResetTime = 0

-- 배경 음악 시작
musicController:Start()

-- 초기 로비 모드 설정 (자유 회전 허용)
playerController:SetLobbyMode()

-- 리더보드 표시 (로비에서)
leaderboardController:Show()
rankingController:ShowInLobby()
realtimeBattleController:ShowInLobby()

-- 플레이어 데이터 캐시
local cachedPlayerData: any? = nil

-- 플레이어 데이터 로드 시 UI 업데이트
RemoteEvents.PlayerDataLoaded.OnClientEvent:Connect(function(data)
	print("[Client] Player data loaded")
	cachedPlayerData = data
	if data.highScore then
		uiController:UpdateHighScoreDisplay(data.highScore, data.coins or 0)
	end
end)

-- 초기화 완료 후 서버에 데이터 요청 (레이스 컨디션 방지)
RemoteEvents.PlayerDataRequest:FireServer()

-- 로비 복귀 처리
RemoteEvents.ReturnToLobby.OnClientEvent:Connect(function()
	print("[Client] Returned to lobby")
	uiController:ShowLobbyUI()
	feverController:HideGauge()

	-- 로비에서는 기본 이동 활성화
	enableDefaultControls()

	-- 카메라를 로비 모드로 전환 (기본 카메라)
	cameraController:SetLobbyMode()

	-- PlayerController 로비 모드 (자유 회전)
	playerController:SetLobbyMode()

	-- 리더보드 표시
	leaderboardController:Show()

	-- 진행도 UI 표시
	progressionController:ShowInLobby()
	scenarioController:ShowInLobby()
	worldMapController:ShowInLobby()
	rankingController:ShowInLobby()
	realtimeBattleController:ShowInLobby()
end)

-- 포탈 진입 안내 (서버에서 포탈 감지 시)
RemoteEvents.PortalEnter.OnClientEvent:Connect(function()
	print("[Client] Portal enter detected, showing powerup selection...")

	-- 시작 파워업 선택 UI 표시 (캐시된 플레이어 데이터 사용)
	startPowerupController:Show(cachedPlayerData, function(selectedPowerups)
		print(`[Client] Starting game with {#selectedPowerups} powerups`)
		RemoteEvents.PortalEnter:FireServer({ startPowerups = selectedPowerups })
	end)
end)

-- 상점 열기 (서버에서 상점 감지 시)
RemoteEvents.ShopOpen.OnClientEvent:Connect(function()
	print("[Client] Shop open requested")
	if not shopController:IsOpen() then
		shopController:Open()
	end
end)

-- 비동기 배틀 도전 콜백 연결 (리더보드 도전 버튼 → 서버)
leaderboardController:SetChallengeCallback(function(targetName: string, targetScore: number)
	RemoteEvents.AsyncBattleChallenge:FireServer({ targetName = targetName, targetScore = targetScore })
	uiController:ShowGameFeedback(`⚔️ {targetName}에게 도전!`, Color3.fromRGB(255, 100, 100))
end)

-- 튜토리얼 컨트롤러에 NPCController 연결
tutorialController:SetNPCController(npcController)

-- 캐릭터 리스폰 시 PlayerController 업데이트
player.CharacterAdded:Connect(function(newCharacter: Model)
	character = newCharacter
	_humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- 리스폰 시 로비 모드로 (기본 이동 활성화)
	enableDefaultControls()
	playerController:UpdateCharacter(newCharacter)
	cameraController:UpdateCharacter(newCharacter)
	speedEffectController:UpdateCharacter(newCharacter)
	characterEffectsController:UpdateCharacter(newCharacter)
	cameraController:SetLobbyMode() -- 카메라도 로비 모드로
	playerController:SetLobbyMode() -- PlayerController도 로비 모드로
	print("[Client] Character respawned, controllers updated")
end)

-- 입력 콜백 연결 (키보드)
inputController:OnJump(function()
	playerController:Jump()
	tutorialController:OnPlayerAction("jump")
end)

inputController:OnSlide(function()
	playerController:Slide()
	tutorialController:OnPlayerAction("slide")
end)

inputController:OnSlideEnd(function()
	playerController:SlideEnd()
end)

-- UI 모바일 버튼 콜백 연결 (터치) — InputController debounce를 거침
uiController:OnJump(function()
	inputController:TriggerJump()
end)

uiController:OnSlide(function()
	inputController:TriggerSlide()
end)

uiController:OnSlideEnd(function()
	inputController:TriggerSlideEnd()
end)

-- 서버로부터 게임 시작 응답 수신
RemoteEvents.GameStart.OnClientEvent:Connect(function(data)
	print("[Client] Game start confirmed by server")

	-- 1. UI 전환: 로비 UI 숨기고 게임 UI 표시
	uiController:HideGameOver()
	uiController:HideLobbyUI()
	leaderboardController:Hide()
	progressionController:HideForGame()
	scenarioController:HideForGame()
	worldMapController:HideForGame()
	rankingController:HideForGame()
	realtimeBattleController:HideForGame()

	-- 2. 컨트롤 전환: 기본 이동 비활성화
	disableDefaultControls()

	-- 3. 카메라 전환: 게임 모드 (측면 뷰)
	cameraController:SetGameMode()

	-- 4. PlayerController 초기화
	playerController:StopGame()

	-- 5. 플레이어 텔레포트 (게임 시작 위치로)
	local startPos = data.startPosition or Vector3.new(0, 2.5, 0)
	local currentCharacter = player.Character
	if currentCharacter then
		local hrp = currentCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.Anchored = true
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = CFrame.new(startPos) * CFrame.Angles(0, math.rad(-90), 0)
		end
	end

	-- 6. 카운트다운 후 게임 시작
	uiController:ShowCountdown(function()
		-- 고정 해제
		local charNow = player.Character
		if charNow then
			local hrp = charNow:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				hrp.Anchored = false
			end
		end

		-- 게임 시작!
		playerController:StartGame()
		inputController:SetGameActive(true)
		coinController:SetGameActive(true)
		feverController:ShowGauge()
		skillController:SetGameActive(true)

		-- 비동기 배틀 HUD (도전 모드인 경우)
		if data.asyncBattle then
			asyncBattleController:StartBattle(data.asyncBattle)
		end

		-- 실시간 배틀 HUD (매칭된 경우)
		realtimeBattleController:SetGameActive(true)

		-- 속도 연출 효과 시작
		if charNow then
			speedEffectController:StartGame(charNow)
		end

		-- 튜토리얼 시작 (필요 시)
		if data.startTutorial then
			tutorialController:Start(data.startPosition)
			uiController:ShowTutorialBanner()
		end
	end)
end)

-- 튜토리얼 모드 전환 (슬로모션)
RemoteEvents.TutorialMode.OnClientEvent:Connect(function(data)
	if data.active then
		print(`[Client] Tutorial mode enabled - speed: {data.speedMultiplier * 100}%`)
		playerController:SetSpeedMultiplier(data.speedMultiplier)
		uiController:ShowTutorialBanner() -- 튜토리얼 배너 표시
	else
		print("[Client] Tutorial mode disabled - normal speed")
		playerController:SetSpeedMultiplier(1.0)
		uiController:ShowTutorialComplete() -- 튜토리얼 완료 알림
	end
end)

-- 서버로부터 게임 종료 수신
RemoteEvents.GameOver.OnClientEvent:Connect(function(data)
	-- 스와이프 입력 비활성화
	inputController:SetGameActive(false)
	coinController:SetGameActive(false)

	-- 피버 게이지 숨기기
	feverController:HideGauge()

	-- 스킬 비활성화
	skillController:SetGameActive(false)

	-- 비동기 배틀 HUD 숨기기
	asyncBattleController:EndBattle()

	-- 실시간 배틀 HUD 숨기기
	realtimeBattleController:SetGameActive(false)

	-- 부활 가능한 경우 게임 일시정지만 (완전 종료 아님)
	if data.canRevive then
		print("[Client] Game paused - revive available")
		playerController:StopGame()
		speedEffectController:StopGame()
	else
		print("[Client] Game ended by server")
		playerController:StopGame()
		speedEffectController:StopGame()
		zoneController:ResetToDefault() -- Phase B: zone 복원

		-- 튜토리얼 종료 (활성화된 경우)
		if tutorialController:IsActive() then
			tutorialController:Stop()
		end

		-- 튜토리얼 UI 숨기기
		uiController:HideTutorialBanner()
	end
end)

-- 부활 응답 수신
RemoteEvents.Revive.OnClientEvent:Connect(function(data)
	if data.success then
		print(`[Client] Revive successful! Resuming game...`)
		playerController:StartGame()
		inputController:SetGameActive(true)
		coinController:SetGameActive(true)
		skillController:SetGameActive(true)

		-- 부활 후 속도 감소 및 점진적 회복
		local reduction = GameConstants.REVIVE.SPEED_REDUCTION
		local recoveryTime = GameConstants.REVIVE.SPEED_RECOVERY_TIME
		playerController:SetSpeedMultiplier(reduction)

		task.spawn(function()
			local elapsed = 0
			local STEP = 0.1
			while elapsed < recoveryTime do
				task.wait(STEP)
				elapsed += STEP
				local t = math.min(elapsed / recoveryTime, 1)
				local currentMultiplier = reduction + (1 - reduction) * t
				playerController:SetSpeedMultiplier(currentMultiplier)
			end
			playerController:SetSpeedMultiplier(1.0)
		end)
	else
		print(`[Client] Revive failed: {data.reason}`)
	end
end)

-- 위로 보상 피드백
RemoteEvents.ConsolationReward.OnClientEvent:Connect(function(data)
	uiController:ShowGameFeedback(`힘내! +{data.coins} 코인 선물!`, Color3.fromRGB(255, 150, 255))
end)

-- 니어미스 피드백 (기존 - 호환용)
RemoteEvents.NearMiss.OnClientEvent:Connect(function(_data)
	-- NearMissChain handles enhanced feedback now
end)

-- 니어미스 체인 피드백 (강화 버전 + 카메라 흔들림)
RemoteEvents.NearMissChain.OnClientEvent:Connect(function(data)
	-- Chain color escalation
	local chainColors = {
		Color3.fromRGB(255, 200, 0), -- Close! (yellow)
		Color3.fromRGB(255, 150, 0), -- NICE! (orange)
		Color3.fromRGB(255, 50, 50), -- PERFECT! (red)
		Color3.fromRGB(200, 50, 255), -- INSANE! (purple)
		Color3.fromRGB(255, 50, 255), -- GODLIKE! (magenta)
	}
	local color = chainColors[data.chain] or Color3.fromRGB(255, 200, 0)
	uiController:ShowGameFeedback(`{data.text} +{data.bonus}`, color)

	-- Camera shake (escalating intensity)
	local shakeIntensities = { 0.05, 0.1, 0.15, 0.25, 0.4 }
	cameraController:Shake(shakeIntensities[data.chain] or 0.05)
end)

-- 라이프 감소 시 카메라 흔들림
local previousLives = GameConstants.LIFE.STARTING_LIVES
RemoteEvents.LifeUpdate.OnClientEvent:Connect(function(data)
	if data.lives < previousLives then
		cameraController:Shake(0.5) -- hit shake
	end
	previousLives = data.lives
end)

-- 퍼펙트 런 보너스 피드백
RemoteEvents.PerfectRunBonus.OnClientEvent:Connect(function(data)
	uiController:ShowGameFeedback(`{data.title} +{data.bonus}`, Color3.fromRGB(50, 255, 100))
	cameraController:Shake(0.4)
end)

-- Phase B: Zone 전환 이벤트
RemoteEvents.ZoneTransition.OnClientEvent:Connect(function(data)
	zoneController:TransitionToZone(data.zoneIndex, data.displayName)
end)

-- Phase B: 이벤트 청크 알림
RemoteEvents.EventChunkAlert.OnClientEvent:Connect(function(data)
	if data.eventType == "CoinRush" then
		uiController:ShowGameFeedback("COIN RUSH!", Color3.fromRGB(255, 215, 0))
		cameraController:Shake(0.3)
	elseif data.eventType == "GiantCoin" then
		uiController:ShowGameFeedback("GIANT COIN!", Color3.fromRGB(0, 191, 255))
	end
end)

-- Phase B: 거인 코인 수집 연출
RemoteEvents.GiantCoinCollected.OnClientEvent:Connect(function(data)
	uiController:ShowGameFeedback(`+{data.reward}!`, Color3.fromRGB(0, 255, 200))
	cameraController:Shake(0.6)
	cameraController:Zoom(-4, 0.5)
	characterEffectsController:FlashGiantCoin()
	-- 슬로모 0.5초
	playerController:SetSpeedMultiplier(0.3)
	task.delay(0.5, function()
		if playerController:IsPlaying() and not feverController:IsFever() then
			playerController:SetSpeedMultiplier(1.0)
		end
	end)
end)

-- 코인 수집 시 대량 수집 카메라 줌
RemoteEvents.CoinCollected.OnClientEvent:Connect(function(_data)
	local now = tick()
	if now - massCollectResetTime < 1 then
		massCollectCount += 1
	else
		massCollectCount = 1
		massCollectResetTime = now
	end
	if massCollectCount == 5 then
		cameraController:Zoom(-2, 0.3) -- subtle zoom-in
		massCollectCount = 0
	end
end)

-- 콤보 피드백
RemoteEvents.ComboUpdate.OnClientEvent:Connect(function(data)
	if data.bonus and data.bonus > 0 then
		uiController:ShowGameFeedback(`{data.combo}x COMBO! +{data.bonus}`, Color3.fromRGB(0, 255, 150))
	elseif data.combo >= 5 and data.combo % 5 == 0 then
		uiController:ShowGameFeedback(`{data.combo}x COMBO!`, Color3.fromRGB(100, 200, 255))
	end
end)

-- 튜토리얼 거리 업데이트 및 속도 연출 동기화 (RunService)
RunService.Heartbeat:Connect(function(_deltaTime: number)
	-- 튜토리얼 거리 업데이트
	if tutorialController:IsActive() and character then
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			tutorialController:UpdateDistance(hrp.Position)
		end
	end

	-- 속도 연출 효과 동기화 (게임 중일 때만)
	if playerController:IsPlaying() then
		local effectiveSpeed = playerController:GetEffectiveSpeed()
		speedEffectController:SetSpeed(effectiveSpeed)
	end
end)

print("[Client] Coin Runner Client Ready")
print(
	"[Client] Controllers initialized: Input, Player, Coin, Life, UI, Powerup, Camera, NPC, Tutorial, Music, Shop, SpeedEffect, Leaderboard, Progression, Scenario, Cutscene, WorldMap"
)

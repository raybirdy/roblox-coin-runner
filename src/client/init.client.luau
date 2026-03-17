--!strict
-- Client Entry Point
-- 클라이언트 측 진입점 - UI 및 입력 처리 초기화

print("[Client] Coin Runner Client Starting...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

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
local DailyEventController = require(script.Controllers.DailyEventController)
local ObjectiveHudController = require(script.Controllers.ObjectiveHudController)
local PetController = require(script.Controllers.PetController)
local NametagController = require(script.Controllers.NametagController)
local CharacterSelectController = require(script.Controllers.CharacterSelectController)
local CoinKingController = require(script.Controllers.CoinKingController)
local CoinSpinController = require(script.Controllers.CoinSpinController)
local RunSkillHudController = require(script.Controllers.RunSkillHudController)
local PreRunSkillController = require(script.Controllers.PreRunSkillController)
local ReferralController = require(script.Controllers.ReferralController)
local BattlePassController = require(script.Controllers.BattlePassController)

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
local loginRewardController = LoginRewardController.new(player)
local luckySpinController = LuckySpinController.new(player)
local feverController = FeverController.new()
local zoneController = ZoneController.new()
local characterEffectsController = CharacterEffectsController.new(character)
local scenarioController = ScenarioController.new(player)
local cutsceneController = CutsceneController.new()
local worldMapController = WorldMapController.new(player)
scenarioController:SetWorldMapController(worldMapController)
local _bossRunController = BossRunController.new()
local skillController = SkillController.new(player, playerController)
local rankingController = RankingController.new(player)
local asyncBattleController = AsyncBattleController.new(player)
local realtimeBattleController = RealtimeBattleController.new(player)
local dailyEventController = DailyEventController.new(player)
local objectiveHudController = ObjectiveHudController.new()
local petController = PetController.new()
local _nametagController = NametagController.new(player)
local characterSelectController = CharacterSelectController.new(player)
local coinKingController = CoinKingController.new()
local _coinSpinController = CoinSpinController.new()
local runSkillHudController = RunSkillHudController.new()
local preRunSkillController = PreRunSkillController.new()
local referralController = ReferralController.new(player)
local battlePassController = BattlePassController.new()

-- 배틀패스 컨트롤러 초기화
battlePassController:Init()

-- Fever mode callbacks (speed boost + camera shake + BGM speed + P0: 카메라 줌인)
feverController:OnFeverStart(function(speedBoost: number, duration: number)
	playerController:SetSpeedMultiplier(speedBoost)
	cameraController:Shake(0.8) -- strong shake on fever start
	musicController:SetFeverSpeed(true)
	-- P0: 피버 진입 시 카메라 줌인 (피버 지속 시간 동안 유지 → 체감 강화)
	cameraController:Zoom(-6, duration)
end)

feverController:OnFeverEnd(function()
	playerController:SetSpeedMultiplier(1.0)
	musicController:SetFeverSpeed(false)
	-- P0: 피버 종료 시 카메라 원위치 복귀
	cameraController:Zoom(0, 0.6)
end)

-- 코인 수집 캐릭터 플래시
coinController:OnCoinEffect(function(coinType: string)
	characterEffectsController:FlashCoin(coinType)
end)

-- P0: 마이크로 카메라 쉐이크 (코인 타입별 강도)
local COIN_SHAKE_INTENSITY = { Bronze = 0.02, Silver = 0.04, Gold = 0.06 }
coinController:OnCoinShake(function(coinType: string)
	local intensity = COIN_SHAKE_INTENSITY[coinType] or 0.02
	cameraController:Shake(intensity)
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
dailyEventController:ShowInLobby()

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
	uiController:HideGameOver() -- 게임오버 화면 명시적 제거 (로비 안내와 겹침 방지)
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

	-- 코인 킹 연출 종료
	coinKingController:EndGame()

	-- 진행도 UI 표시
	progressionController:ShowInLobby()
	scenarioController:ShowInLobby()
	worldMapController:ShowInLobby()
	rankingController:ShowInLobby()
	realtimeBattleController:ShowInLobby()
	dailyEventController:ShowInLobby()
	objectiveHudController:EndGame()
end)

-- Zone Skip 프롬프트 표시 (선택 후 useZoneSkip과 함께 서버 전송)
local function _showZoneSkipPrompt(skipZone: number, zoneName: string, callback: (boolean) -> ())
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "ZoneSkipPrompt"
	gui.DisplayOrder = 15
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local dim = Instance.new("Frame")
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local box = Instance.new("Frame")
	box.Size = UDim2.new(0, 340, 0, 180)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.new(0.5, 0, 0.5, 0)
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	box.BorderSizePixel = 0
	box.Parent = dim

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = box

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = `✈️ Zone {skipZone} ({zoneName})부터 시작?`
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.TextWrapped = true
	title.Parent = box

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 40)
	desc.Position = UDim2.new(0, 10, 0, 50)
	desc.BackgroundTransparency = 1
	desc.Text = "이전에 도달한 구역 바로 전부터 시작합니다"
	desc.TextColor3 = Color3.fromRGB(180, 180, 200)
	desc.TextSize = 14
	desc.Font = Enum.Font.Gotham
	desc.TextWrapped = true
	desc.Parent = box

	local btnYes = Instance.new("TextButton")
	btnYes.Size = UDim2.new(0, 140, 0, 44)
	btnYes.Position = UDim2.new(0, 20, 1, -60)
	btnYes.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
	btnYes.Text = "✈️ 스킵해서 시작"
	btnYes.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnYes.TextSize = 15
	btnYes.Font = Enum.Font.GothamBold
	btnYes.BorderSizePixel = 0
	btnYes.Parent = box
	Instance.new("UICorner", btnYes).CornerRadius = UDim.new(0, 8)

	local btnNo = Instance.new("TextButton")
	btnNo.Size = UDim2.new(0, 140, 0, 44)
	btnNo.Position = UDim2.new(1, -160, 1, -60)
	btnNo.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
	btnNo.Text = "처음부터 시작"
	btnNo.TextColor3 = Color3.fromRGB(255, 255, 255)
	btnNo.TextSize = 15
	btnNo.Font = Enum.Font.GothamBold
	btnNo.BorderSizePixel = 0
	btnNo.Parent = box
	Instance.new("UICorner", btnNo).CornerRadius = UDim.new(0, 8)

	local function closeAndCall(skip: boolean)
		gui:Destroy()
		callback(skip)
	end

	btnYes.Activated:Connect(function() closeAndCall(true) end)
	btnNo.Activated:Connect(function() closeAndCall(false) end)
end

-- 포탈 진입 안내 (서버에서 포탈 감지 시)
RemoteEvents.PortalEnter.OnClientEvent:Connect(function()
	print("[Client] Portal enter detected, showing powerup selection...")

	-- 시작 파워업 선택 UI 표시 (캐시된 플레이어 데이터 사용)
	startPowerupController:Show(cachedPlayerData, function(selectedPowerups)
		print(`[Client] Starting game with {#selectedPowerups} powerups`)

		-- 런 스킬 슬롯 선택 (해금된 스킬이 있을 때만 표시)
		local function _launchWithSkills(preRunSkills: { string })
			-- Zone Skip 조건 확인 (maxZoneReached >= 2)
			local maxZone = cachedPlayerData and cachedPlayerData.maxZoneReached or 1
			if maxZone >= GameConstants.ZONE_SKIP.MIN_ZONE_TO_UNLOCK then
				local skipZone = math.max(1, maxZone - 1)
				local theme = GameConstants.ZONE_THEMES[skipZone]
				local zoneName = theme and theme.displayName or `Zone {skipZone}`
				_showZoneSkipPrompt(skipZone, zoneName, function(useZoneSkip)
							RemoteEvents.PortalEnter:FireServer({
						startPowerups = selectedPowerups,
						useZoneSkip = useZoneSkip,
						preRunSkills = preRunSkills,
					})
				end)
			else
					RemoteEvents.PortalEnter:FireServer({
					startPowerups = selectedPowerups,
					preRunSkills = preRunSkills,
				})
			end
		end

		-- 해금된 스킬이 있으면 슬롯 선택 UI 표시
		if preRunSkillController:HasUnlockedSkills() then
			preRunSkillController:Show(function(selectedSkills)
				_launchWithSkills(selectedSkills)
			end)
		else
			_launchWithSkills({})
		end
	end)
end)

-- 모달 상호배제 헬퍼
local function closeAllModals()
	if shopController:IsOpen() then
		shopController:Close()
	end
	if loginRewardController:IsOpen() then
		loginRewardController:Hide()
	end
	if luckySpinController:IsOpen() then
		luckySpinController:Hide()
	end
end

-- 상점 열기 (서버에서 상점 감지 시)
RemoteEvents.ShopOpen.OnClientEvent:Connect(function()
	print("[Client] Shop open requested")
	if not shopController:IsOpen() then
		closeAllModals()
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

-- 캐릭터 선택 버튼 콜백 연결
uiController:SetCharacterSelectCallback(function()
	characterSelectController:Open()
end)

-- 친구 초대 버튼 콜백 연결
uiController:SetInviteCallback(function()
	referralController:PromptInvite()
end)

-- NPC 상호작용 → 퀘스트 UI 오픈
RemoteEvents.NpcInteract.OnClientEvent:Connect(function(data: any)
	if type(data) ~= "table" then return end
	if data.npcId == "quest_npc" then
		scenarioController:OpenPanel()
	end
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

	-- 6. 카운트다운 시작 전 목표 HUD 미리 표시 (오늘의 목표 인지 향상)
	objectiveHudController:StartGame()

	-- 7. 카운트다운 후 게임 시작
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
		dailyEventController:StartGame()
		petController:StartGame()
		objectiveHudController:DisableReroll() -- 카운트다운 후 리롤 잠금

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

		-- 코인 킹 추적 연출 시작
		coinKingController:StartGame()

		-- 런 스킬 HUD 활성화
		runSkillHudController:StartGame()

		-- start_boost 업그레이드: 게임 시작 시 일시적 속도 부스트
		local boostSeconds = data.startBoostSeconds or 0
		if boostSeconds > 0 then
			playerController:SetSpeedMultiplier(1.25)
			uiController:ShowGameFeedback("⚡ 스타트 대시!", Color3.fromRGB(255, 220, 50))
			task.delay(boostSeconds, function()
				if playerController:IsPlaying() and not feverController:IsFever() then
					playerController:SetSpeedMultiplier(1.0)
				end
			end)
		end

		-- Zone Skip: 시작 Zone이 1이 아니면 즉시 ZoneController 전환
		local startZone = data.startZone or 1
		if startZone > 1 then
			local theme = GameConstants.ZONE_THEMES[startZone]
			if theme then
				zoneController:TransitionToZone(startZone, theme.displayName)
				uiController:ShowGameFeedback(
					`✈️ {theme.displayName}부터 시작!`,
					Color3.fromRGB(100, 200, 255)
				)
			end
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

	-- 데일리 이벤트 HUD 숨기기
	dailyEventController:EndGame()
	-- 런 목표 HUD 숨기기
	objectiveHudController:EndGame()
	-- 펫 HUD 숨기기
	petController:EndGame()

	-- 비동기 배틀 HUD 숨기기
	asyncBattleController:EndBattle()

	-- 실시간 배틀 HUD 숨기기
	realtimeBattleController:SetGameActive(false)

	-- 코인 킹 연출 종료
	coinKingController:EndGame()

	-- 런 스킬 HUD 비활성화
	runSkillHudController:EndGame()

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

		-- 출석 보상 팝업 (첫 런 완료 후 표시)
		loginRewardController:ShowIfPending()
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
		-- 게임오버 화면 복구 (부활 실패 시 빈 화면에 갇히는 버그 방지)
		uiController:RestoreGameOver()
		uiController:ShowGameFeedback("부활 실패 😢", Color3.fromRGB(255, 80, 80))
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
	-- 구역 도착 연출: 카메라 줌아웃 → 복귀 + 화면 피드백 + 미약한 흔들림
	cameraController:Zoom(8, 1.5) -- 1.5초 동안 살짝 줌아웃 (새 구역 전경 노출)
	cameraController:Shake(0.2)
	-- 축하 피드백 (더 큰 텍스트, 구역별 색상)
	uiController:ShowGameFeedback(`✨ {data.displayName} 도착!`, Color3.fromRGB(255, 220, 80))
	-- TIER 3: 구역 깊이에 따른 BGM 템포 진화
	musicController:UpdateZoneMood(data.zoneIndex)
end)

-- TIER 3: 생존 배율 마일스톤 도달 시 극적 연출 (카메라 줌 + 슬로우모션)
RemoteEvents.SurvivalMultiplierUpdate.OnClientEvent:Connect(function(data)
	if data.tier == 0 or not playerController:IsPlaying() then
		return
	end
	-- 티어별 효과 강도 조정
	local zoomAmount = -3 - (data.tier - 1) * 2 -- tier1: -3, tier2: -5, tier3: -7
	local slowmoSpeed = math.max(0.3, 0.55 - data.tier * 0.1) -- tier1: 0.45, tier2: 0.35, tier3: 0.25
	local slowmoDuration = 0.3 + data.tier * 0.1 -- tier1: 0.4, tier2: 0.5, tier3: 0.6

	-- 슬로우모션 + 카메라 줌인
	if not feverController:IsFever() then
		playerController:SetSpeedMultiplier(slowmoSpeed)
		cameraController:Zoom(zoomAmount, 0.2)
		characterEffectsController:FlashCoin("Gold") -- 황금 글로우 플래시

		task.delay(slowmoDuration, function()
			if playerController:IsPlaying() and not feverController:IsFever() then
				playerController:SetSpeedMultiplier(1.0)
			end
			cameraController:Zoom(0, 0.4)
		end)
	end
end)

-- 히트 회복 영웅 순간 연출 (피격 후 코인 러시 시작 시)
RemoteEvents.HitRushStart.OnClientEvent:Connect(function(data)
	-- 0.25초 슬로우모션으로 극적 효과
	playerController:SetSpeedMultiplier(0.4)
	task.delay(0.25, function()
		if playerController:IsPlaying() and not feverController:IsFever() then
			playerController:SetSpeedMultiplier(1.0)
		end
	end)
	-- 캐릭터 황금 글로우 (회복 시간 동안)
	characterEffectsController:FlashHitRecovery(data.duration)
	-- 카메라 살짝 줌인 (집중감)
	cameraController:Zoom(-3, 0.3)
	task.delay(0.3, function()
		cameraController:Zoom(0, 0.5)
	end)
end)

-- 추격자 등장 경고 (화면 빨간 플래시 + 피드백)
RemoteEvents.ChaseMobWarning.OnClientEvent:Connect(function()
	uiController:ShowGameFeedback("⚠️ 추격자 출현!", Color3.fromRGB(255, 60, 60))
	cameraController:Shake(0.4)
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

-- ESC/뒤로가기 키: 열린 모달 닫기 (Bug #1)
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		closeAllModals()
	end
end)

-- 컷신 재생 중 게임 입력 차단 (Bug #11)
cutsceneController:OnPlayStart(function()
	if playerController:IsPlaying() then
		inputController:SetGameActive(false)
	end
end)
cutsceneController:OnPlayEnd(function()
	if playerController:IsPlaying() then
		inputController:SetGameActive(true)
	end
end)

-- =====================================================================
-- Zone 고유 메커닉 이벤트 처리
-- =====================================================================

-- MushroomBounce: 버섯 밟기 → 점프력 일시 2배
RemoteEvents.MushroomBounce.OnClientEvent:Connect(function()
	if playerController:IsPlaying() then
		playerController:ApplyMushroomBounce()
	end
end)

-- GravityZone 진입: 저중력 시작
RemoteEvents.GravityZoneEnter.OnClientEvent:Connect(function()
	if playerController:IsPlaying() then
		playerController:EnterGravityZone()
	end
end)

-- GravityZone 퇴장: 정상 중력 복귀
RemoteEvents.GravityZoneExit.OnClientEvent:Connect(function()
	playerController:ExitGravityZone()
end)

print("[Client] Coin Runner Client Ready")
print(
	"[Client] Controllers initialized: Input, Player, Coin, Life, UI, Powerup, Camera, NPC, Tutorial, Music, Shop, SpeedEffect, Leaderboard, Progression, Scenario, Cutscene, WorldMap"
)

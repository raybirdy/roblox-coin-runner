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
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

print("[Client] Game Constants Loaded")
print("[Client] Remote Events Connected")

-- Roblox 기본 컨트롤 관리
local PlayerGui = player:WaitForChild("PlayerGui")
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

	-- 점프는 로비에서도 허용, 카메라 방향으로 캐릭터 회전
	if currentHumanoid then
		currentHumanoid.JumpHeight = 7.2 -- Roblox 기본값
		currentHumanoid.AutoRotate = true -- 카메라 방향으로 캐릭터 회전
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

-- 컨트롤러 인스턴스 생성
local inputController = InputController.new()
local playerController = PlayerController.new(player, character)
local coinController = CoinController.new()
local lifeController = LifeController.new()
local uiController = UIController.new(player)
local powerupController = PowerupController.new()
local cameraController = CameraController.new(player, character)
local npcController = NPCController.new()
local tutorialController = TutorialController.new()
local musicController = MusicController.new()
local shopController = ShopController.new(player)

-- 배경 음악 시작
musicController:Start()

-- 플레이어 데이터 로드 시 UI 업데이트
RemoteEvents.PlayerDataLoaded.OnClientEvent:Connect(function(data)
	print("[Client] Player data loaded")
	if data.highScore then
		uiController:UpdateHighScoreDisplay(data.highScore, data.coins or 0)
	end
end)

-- 로비 복귀 처리
RemoteEvents.ReturnToLobby.OnClientEvent:Connect(function()
	print("[Client] Returned to lobby")
	uiController:ShowLobbyUI()

	-- 로비에서는 기본 이동 활성화
	enableDefaultControls()

	-- 카메라를 로비 모드로 전환 (기본 카메라)
	cameraController:SetLobbyMode()
end)

-- 포탈 진입 안내 (서버에서 포탈 감지 시)
RemoteEvents.PortalEnter.OnClientEvent:Connect(function()
	print("[Client] Portal enter detected, confirming to server...")
	-- 시작 파워업 선택 UI 표시 가능 (Phase 2 확장)
	RemoteEvents.PortalEnter:FireServer({})
end)

-- 상점 열기 (서버에서 상점 감지 시)
RemoteEvents.ShopOpen.OnClientEvent:Connect(function()
	print("[Client] Shop open requested")
	if not shopController:IsOpen() then
		shopController:Open()
	end
end)

-- 튜토리얼 컨트롤러에 NPCController 연결
tutorialController:SetNPCController(npcController)

-- 캐릭터 리스폰 시 PlayerController 업데이트
player.CharacterAdded:Connect(function(newCharacter: Model)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	-- 리스폰 시 로비 모드로 (기본 이동 활성화)
	enableDefaultControls()
	playerController:UpdateCharacter(newCharacter)
	cameraController:UpdateCharacter(newCharacter)
	cameraController:SetLobbyMode() -- 카메라도 로비 모드로
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

-- UI 모바일 버튼 콜백 연결 (터치)
uiController:OnJump(function()
	playerController:Jump()
	tutorialController:OnPlayerAction("jump")
end)

uiController:OnSlide(function()
	playerController:Slide()
	tutorialController:OnPlayerAction("slide")
end)

-- 서버로부터 게임 시작 응답 수신
RemoteEvents.GameStart.OnClientEvent:Connect(function(data)
	print("[Client] Game start confirmed by server")

	-- 1. UI 전환: 로비 UI 숨기고 게임 UI 표시
	uiController:HideGameOver()
	uiController:HideLobbyUI()

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
	-- 부활 가능한 경우 게임 일시정지만 (완전 종료 아님)
	if data.canRevive then
		print("[Client] Game paused - revive available")
		playerController:StopGame()
	else
		print("[Client] Game ended by server")
		playerController:StopGame()

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
	else
		print(`[Client] Revive failed: {data.reason}`)
	end
end)

-- 튜토리얼 거리 업데이트 (RunService)
RunService.Heartbeat:Connect(function(deltaTime: number)
	if tutorialController:IsActive() and character then
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			tutorialController:UpdateDistance(hrp.Position)
		end
	end
end)

print("[Client] Coin Runner Client Ready")
print("[Client] Controllers initialized: Input, Player, Coin, Life, UI, Powerup, Camera, NPC, Tutorial, Music, Shop")

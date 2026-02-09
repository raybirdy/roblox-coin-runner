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

-- Roblox 기본 UI 비활성화
local PlayerGui = player:WaitForChild("PlayerGui")
local function disableDefaultControls()
	-- 기본 점프 버튼 비활성화
	if humanoid then
		humanoid.JumpHeight = 0 -- 기본 점프 비활성화 (커스텀 점프 사용)
	end

	-- 기본 이동 조이스틱 비활성화 (모바일)
	local controlModule = require(player.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
	if controlModule then
		controlModule:Disable()
	end

	print("[Client] Default Roblox controls disabled")
end

-- 초기 캐릭터 설정 (컨트롤러 정의 후 리스폰 핸들러 추가)

-- 초기 설정
disableDefaultControls()

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

-- 튜토리얼 컨트롤러에 NPCController 연결
tutorialController:SetNPCController(npcController)

-- 캐릭터 리스폰 시 PlayerController 업데이트
player.CharacterAdded:Connect(function(newCharacter: Model)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	disableDefaultControls()
	playerController:UpdateCharacter(newCharacter)
	cameraController:UpdateCharacter(newCharacter)
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
	uiController:HideGameOver() -- 게임 오버 화면 숨기기

	-- 카운트다운 후 게임 시작
	uiController:ShowCountdown(function()
		playerController:StartGame()

		-- 튜토리얼 시작 (필요 시)
		if data.startTutorial then
			tutorialController:Start(data.startPosition)
			uiController:ShowTutorialBanner() -- 튜토리얼 배너 표시
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
	print("[Client] Game ended by server")
	playerController:StopGame()

	-- 튜토리얼 종료 (활성화된 경우)
	if tutorialController:IsActive() then
		tutorialController:Stop()
	end

	-- 튜토리얼 UI 숨기기
	uiController:HideTutorialBanner()
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
print("[Client] Controllers initialized: Input, Player, Coin, Life, UI, Powerup, Camera, NPC, Tutorial")

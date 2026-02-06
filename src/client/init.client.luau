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

-- 캐릭터 리스폰 시 재설정
player.CharacterAdded:Connect(function(newCharacter: Model)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	disableDefaultControls()
	print("[Client] Character respawned, controls reset")
end)

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

-- 컨트롤러 인스턴스 생성
local inputController = InputController.new()
local playerController = PlayerController.new(player, character)
local coinController = CoinController.new()
local lifeController = LifeController.new()
local uiController = UIController.new(player)
local powerupController = PowerupController.new()
local cameraController = CameraController.new(player, character)
local npcController = NPCController.new()

-- 입력 콜백 연결 (키보드)
inputController:OnJump(function()
	playerController:Jump()
end)

inputController:OnSlide(function()
	playerController:Slide()
end)

-- UI 모바일 버튼 콜백 연결 (터치)
uiController:OnJump(function()
	playerController:Jump()
end)

uiController:OnSlide(function()
	playerController:Slide()
end)

-- 서버로부터 게임 시작 응답 수신
RemoteEvents.GameStart.OnClientEvent:Connect(function(data)
	print("[Client] Game start confirmed by server")
	playerController:StartGame()
	uiController:HideGameOver() -- 게임 오버 화면 숨기기
end)

-- 서버로부터 게임 종료 수신
RemoteEvents.GameOver.OnClientEvent:Connect(function(data)
	print("[Client] Game ended by server")
	playerController:StopGame()
end)

print("[Client] Coin Runner Client Ready")
print("[Client] Controllers initialized: Input, Player, Coin, Life, UI, Powerup, Camera, NPC")

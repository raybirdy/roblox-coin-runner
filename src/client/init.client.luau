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

-- 클라이언트 컨트롤러 로드 (향후 구현)
-- local InputController = require(script.Parent.Controllers.InputController)
-- local CameraController = require(script.Parent.Controllers.CameraController)
-- local UIController = require(script.Parent.Controllers.UIController)

print("[Client] Coin Runner Client Ready")

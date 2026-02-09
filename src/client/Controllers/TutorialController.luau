--!strict
-- Tutorial Controller
-- 튜토리얼 진행 관리 (클라이언트)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local TutorialController = {}
TutorialController.__index = TutorialController

type TutorialStep = {
	message: string,
	trigger: "auto" | "jump" | "slide" | "doubleJump",
	delay: number?,
}

export type TutorialController = typeof(setmetatable(
	{} :: {
		_isActive: boolean,
		_currentStep: number,
		_steps: { TutorialStep },
		_distanceTraveled: number,
		_startPosition: Vector3?,
		_connections: { RBXScriptConnection },
		_npcController: any?, -- NPCController 참조
	},
	TutorialController
))

function TutorialController.new(): TutorialController
	local self = setmetatable({
		_isActive = false,
		_currentStep = 0,
		_steps = {
			{ message = "자동으로 달려! 코인을 모아봐!", trigger = "auto", delay = 2 },
			{ message = "점프! ↑", trigger = "jump" },
			{ message = "슬라이드! ↓", trigger = "slide" },
			{ message = "공중에서 한 번 더 점프!", trigger = "auto", delay = 3 },
		},
		_distanceTraveled = 0,
		_startPosition = nil,
		_connections = {},
		_npcController = nil,
	}, TutorialController)

	return self
end

-- NPCController 설정
function TutorialController:SetNPCController(npcController: any)
	self._npcController = npcController
end

-- 튜토리얼 시작
function TutorialController:Start(startPosition: Vector3)
	if self._isActive then
		return
	end

	self._isActive = true
	self._currentStep = 0
	self._distanceTraveled = 0
	self._startPosition = startPosition

	print("[TutorialController] Tutorial started")

	-- 첫 번째 메시지 표시 (자동)
	self:_showNextStep()

	-- 서버에 튜토리얼 시작 알림
	RemoteEvents.TutorialStart:FireServer()
end

-- 튜토리얼 종료
function TutorialController:Stop()
	if not self._isActive then
		return
	end

	self._isActive = false
	self._currentStep = 0

	-- 서버에 튜토리얼 종료 알림
	RemoteEvents.TutorialEnd:FireServer()

	print("[TutorialController] Tutorial ended")
end

-- 튜토리얼 스킵
function TutorialController:Skip()
	if not self._isActive then
		return
	end

	print("[TutorialController] Tutorial skipped by player")
	self:Stop()
end

-- 플레이어 액션 체크 (점프, 슬라이드 등)
function TutorialController:OnPlayerAction(action: "jump" | "slide" | "doubleJump")
	if not self._isActive then
		return
	end

	-- 현재 스텝의 트리거와 일치하는지 확인
	local currentStep = self._steps[self._currentStep]
	if currentStep and currentStep.trigger == action then
		self:_showNextStep()
	end
end

-- 거리 업데이트
function TutorialController:UpdateDistance(currentPosition: Vector3)
	if not self._isActive or not self._startPosition then
		return
	end

	self._distanceTraveled = currentPosition.X - self._startPosition.X

	-- 200 studs 이동 시 자동 종료
	if self._distanceTraveled >= GameConstants.TUTORIAL.SKIP_AFTER_DISTANCE then
		print(`[TutorialController] Tutorial auto-completed after {self._distanceTraveled} studs`)
		self:Stop()
	end
end

-- 튜토리얼 활성 여부
function TutorialController:IsActive(): boolean
	return self._isActive
end

-- 다음 스텝 표시
function TutorialController:_showNextStep()
	self._currentStep += 1

	if self._currentStep > #self._steps then
		-- 모든 스텝 완료
		self:Stop()
		return
	end

	local step = self._steps[self._currentStep]
	if not step then
		return
	end

	-- 지연 시간이 있으면 대기 후 표시
	local delay = step.delay or 0
	task.delay(delay, function()
		if not self._isActive then
			return
		end

		-- NPC 컨트롤러를 통해 부엉이 메시지 표시
		if self._npcController then
			self._npcController:ShowOwlMessage(step.message)
		end

		print(`[TutorialController] Step {self._currentStep}: {step.message}`)
	end)
end

-- 정리
function TutorialController:Destroy()
	self:Stop()

	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
end

return TutorialController

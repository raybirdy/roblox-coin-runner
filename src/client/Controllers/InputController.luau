--!strict
-- Input Controller
-- 플레이어 입력 처리 (키보드 + 터치 스와이프)

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local InputController = {}
InputController.__index = InputController

local ACTION_DEBOUNCE_TIME = 0.08 -- 80ms debounce to prevent double triggers

export type InputController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_jumpCallback: ((any) -> ())?,
		_slideCallback: ((any) -> ())?,
		_touchStartPos: Vector2?,
		_touchStartTime: number,
		_isGameActive: boolean,
		_lastActionTime: number,
	},
	InputController
))

function InputController.new(): InputController
	local self = setmetatable({
		_connections = {},
		_jumpCallback = nil,
		_slideCallback = nil,
		_touchStartPos = nil,
		_touchStartTime = 0,
		_isGameActive = false,
		_lastActionTime = 0,
	}, InputController)

	self:_setupKeyboardInput()
	self:_setupTouchInput()

	return self
end

-- 점프 콜백 등록
function InputController:OnJump(callback: (any) -> ())
	self._jumpCallback = callback
end

-- 슬라이드 콜백 등록
function InputController:OnSlide(callback: (any) -> ())
	self._slideCallback = callback
end

-- 게임 활성화 상태 설정 (스와이프는 게임 중에만)
function InputController:SetGameActive(active: boolean)
	self._isGameActive = active
end

-- 키보드 입력 설정
function InputController:_setupKeyboardInput()
	local connection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		-- 점프: Space, W, ↑
		if
			input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.W
			or input.KeyCode == Enum.KeyCode.Up
		then
			if self._jumpCallback then
				self._jumpCallback()
			end
		end

		-- 슬라이드: S, ↓
		if input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.Down then
			if self._slideCallback then
				self._slideCallback()
			end
		end
	end)

	table.insert(self._connections, connection)
end

-- 터치 스와이프 입력 설정
function InputController:_setupTouchInput()
	if not UserInputService.TouchEnabled then
		return
	end

	-- 터치 시작
	local touchBeganConn = UserInputService.TouchStarted:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		self._touchStartPos = input.Position
		self._touchStartTime = tick()
	end)
	table.insert(self._connections, touchBeganConn)

	-- 터치 종료 (스와이프 감지)
	local touchEndedConn = UserInputService.TouchEnded:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if not self._isGameActive then
			return
		end
		if not self._touchStartPos then
			return
		end

		local elapsed = tick() - self._touchStartTime
		if elapsed > GameConstants.UI.SWIPE_MAX_TIME then
			self._touchStartPos = nil
			return
		end

		local delta = input.Position - self._touchStartPos
		local swipeThreshold = GameConstants.UI.SWIPE_THRESHOLD

		-- Dynamic swipe threshold based on screen size
		local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
			or Vector2.new(1920, 1080)
		local dynamicThreshold = math.max(swipeThreshold, viewport.Y * 0.08)

		-- 수직 스와이프가 수평보다 큰 경우만 처리
		if math.abs(delta.Y) > math.abs(delta.X) and math.abs(delta.Y) >= dynamicThreshold then
			if delta.Y < 0 then
				-- 위로 스와이프 = 점프 (debounce 적용)
				if self:_canTriggerAction() and self._jumpCallback then
					self._jumpCallback()
				end
			else
				-- 아래로 스와이프 = 슬라이드 (debounce 적용)
				if self:_canTriggerAction() and self._slideCallback then
					self._slideCallback()
				end
			end
		end

		self._touchStartPos = nil
	end)
	table.insert(self._connections, touchEndedConn)

	print("[InputController] Touch swipe input enabled")
end

-- Debounce check for shared action timing (prevents swipe + button double trigger)
function InputController:_canTriggerAction(): boolean
	local now = tick()
	if now - self._lastActionTime < ACTION_DEBOUNCE_TIME then
		return false
	end
	self._lastActionTime = now
	return true
end

-- 점프 트리거 (UI 버튼용 public 메서드)
function InputController:TriggerJump()
	if not self:_canTriggerAction() then
		return
	end
	if self._jumpCallback then
		self._jumpCallback()
	end
end

-- 슬라이드 트리거 (UI 버튼용 public 메서드)
function InputController:TriggerSlide()
	if not self:_canTriggerAction() then
		return
	end
	if self._slideCallback then
		self._slideCallback()
	end
end

-- 정리
function InputController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
	self._jumpCallback = nil
	self._slideCallback = nil
end

return InputController

--!strict
-- Input Controller
-- 플레이어 입력 처리 (점프, 슬라이드)

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local InputController = {}
InputController.__index = InputController

export type InputController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_jumpCallback: ((any) -> ())?,
		_slideCallback: ((any) -> ())?,
	},
	InputController
))

function InputController.new(): InputController
	local self = setmetatable({
		_connections = {},
		_jumpCallback = nil,
		_slideCallback = nil,
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

-- 터치 입력 설정 (모바일)
function InputController:_setupTouchInput()
	-- 터치 UI는 UI Controller에서 생성될 것이므로
	-- 여기서는 연결만 준비
	-- UI 버튼에서 직접 콜백을 호출할 수 있도록 public 메서드 제공
end

-- 점프 트리거 (UI 버튼용 public 메서드)
function InputController:TriggerJump()
	if self._jumpCallback then
		self._jumpCallback()
	end
end

-- 슬라이드 트리거 (UI 버튼용 public 메서드)
function InputController:TriggerSlide()
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

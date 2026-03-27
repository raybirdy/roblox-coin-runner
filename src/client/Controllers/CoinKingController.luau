--!strict
-- Coin King Controller
-- 런 시간에 따라 화면 좌측에서 서서히 다가오는 코인 킹 연출
-- 위기감과 긴장감을 부여해 달리기의 몰입도를 높임

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local CoinKingController = {}
CoinKingController.__index = CoinKingController

-- 코인 킹 출현 타이밍
local APPEAR_TIME = 15 -- 15초 후 슬쩍 등장
local FULL_VISIBLE_TIME = 120 -- 120초에 50px 노출 (위기감 최고조)
local BOB_SPEED = 3.0 -- 위아래 흔들림 속도 (rad/s)
local BOB_AMPLITUDE = 5 -- 흔들림 높이 (px)

export type CoinKingController = typeof(setmetatable(
	{} :: {
		_container: ScreenGui?,
		_kingLabel: TextLabel?,
		_shadowLabel: TextLabel?,
		_isActive: boolean,
		_gameStartTime: number,
		_heartbeatConn: RBXScriptConnection?,
	},
	CoinKingController
))

function CoinKingController.new(): CoinKingController
	local self = setmetatable({
		_container = nil,
		_kingLabel = nil,
		_shadowLabel = nil,
		_isActive = false,
		_gameStartTime = 0,
		_heartbeatConn = nil,
	}, CoinKingController)

	self:_createUI()
	return self
end

function CoinKingController:_createUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CoinKingOverlay"
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.None
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	self._container = screenGui

	-- 그림자 (왕관 뒤에 위치, 더 크고 검정 반투명)
	local shadow = Instance.new("TextLabel")
	shadow.Name = "CoinKingShadow"
	shadow.Size = UDim2.new(0, 86, 0, 86)
	shadow.AnchorPoint = Vector2.new(1, 0.5)
	shadow.Position = UDim2.new(0, -10, 0.5, 4)
	shadow.BackgroundTransparency = 1
	shadow.Text = "👑"
	shadow.TextSize = 52
	shadow.TextColor3 = Color3.fromRGB(0, 0, 0)
	shadow.TextTransparency = 0.85
	shadow.Font = Enum.Font.GothamBold
	shadow.ZIndex = 9
	shadow.Parent = screenGui
	self._shadowLabel = shadow

	-- 왕관 이모지 본체
	local king = Instance.new("TextLabel")
	king.Name = "CoinKing"
	king.Size = UDim2.new(0, 80, 0, 80)
	king.AnchorPoint = Vector2.new(1, 0.5)
	king.Position = UDim2.new(0, -10, 0.5, 0)
	king.BackgroundTransparency = 1
	king.Text = "👑"
	king.TextSize = 48
	king.TextTransparency = 1 -- 처음엔 완전 투명
	king.Font = Enum.Font.GothamBold
	king.ZIndex = 10
	king.Parent = screenGui
	self._kingLabel = king
end

function CoinKingController:StartGame()
	self._isActive = true
	self._gameStartTime = os.clock()

	if self._container then
		self._container.Enabled = true
	end

	-- 초기 위치: 완전히 화면 밖 (투명)
	if self._kingLabel then
		self._kingLabel.Position = UDim2.new(0, -10, 0.5, 0)
		self._kingLabel.TextTransparency = 1
	end
	if self._shadowLabel then
		self._shadowLabel.Position = UDim2.new(0, -10, 0.5, 4)
		self._shadowLabel.TextTransparency = 1
	end

	-- Heartbeat 업데이트 루프
	self._heartbeatConn = RunService.Heartbeat:Connect(function()
		self:_update()
	end)
end

function CoinKingController:_update()
	if not self._isActive then
		return
	end

	local elapsed = os.clock() - self._gameStartTime

	-- APPEAR_TIME 이전: 숨겨둠
	if elapsed < APPEAR_TIME then
		return
	end

	-- 등장 ~ 접근 보간 (quadratic ease-in: 위협감이 점점 빠르게 증가)
	local t = math.clamp((elapsed - APPEAR_TIME) / (FULL_VISIBLE_TIME - APPEAR_TIME), 0, 1)
	local eased = t * t

	-- 노출 거리: -10 (완전 숨김) → 50 (50px 노출)
	local xOffset = -10 + eased * 60

	-- 투명도: 등장 시 희미하게 → 점점 선명 (위협감 강조)
	local textTransp = math.max(0, 0.6 - eased * 0.6)

	-- 위아래 살랑거림 (살아있는 느낌)
	local yBob = math.sin(elapsed * BOB_SPEED) * BOB_AMPLITUDE * eased

	if self._kingLabel then
		self._kingLabel.Position = UDim2.new(0, xOffset, 0.5, yBob)
		self._kingLabel.TextTransparency = textTransp
	end
	if self._shadowLabel then
		self._shadowLabel.Position = UDim2.new(0, xOffset, 0.5, yBob + 4)
		self._shadowLabel.TextTransparency = math.min(0.85, textTransp + 0.4)
	end
end

function CoinKingController:EndGame()
	self._isActive = false

	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end

	if self._container then
		self._container.Enabled = false
	end
end

-- UIVisibilityManager 호환 alias (lobby/gameover 상태에서 호출)
function CoinKingController:Hide()
	self:EndGame()
end

function CoinKingController:Destroy()
	self:EndGame()
	if self._container then
		self._container:Destroy()
		self._container = nil
	end
end

return CoinKingController

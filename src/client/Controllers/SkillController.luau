--!strict
-- SkillController
-- 시나리오 스킬 클라이언트 관리: double_jump, dash 입력 처리 + 스킬 UI

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local DASH_COOLDOWN = 8 -- seconds (ScenarioConstants.SKILLS.dash.cooldown)
local MAGNET_BURST_FLASH_DURATION = 0.6

local SkillController = {}
SkillController.__index = SkillController

export type SkillController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_playerController: any,
		_connections: { RBXScriptConnection },
		_unlockedSkills: { [string]: boolean },
		_isGameActive: boolean,
		-- Dash cooldown
		_dashLastUsed: number,
		_dashCooldownLabel: TextLabel?,
		_dashBtn: TextButton?,
		-- GUI
		_gui: ScreenGui?,
	},
	SkillController
))

function SkillController.new(player: Player, playerController: any): SkillController
	local self = setmetatable({
		_player = player,
		_playerController = playerController,
		_connections = {},
		_unlockedSkills = {},
		_isGameActive = false,
		_dashLastUsed = 0,
		_dashCooldownLabel = nil,
		_dashBtn = nil,
		_gui = nil,
	}, SkillController)

	self:_createGui()
	self:_setupEventHandlers()

	return self
end

-- ==================== GUI 생성 ====================

function SkillController:_createGui()
	local playerGui = self._player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Enabled = false
	gui.Parent = playerGui
	self._gui = gui

	-- 대쉬 버튼 (우하단)
	local dashBtn = Instance.new("TextButton")
	dashBtn.Name = "DashBtn"
	dashBtn.Size = UDim2.new(0, 72, 0, 72)
	dashBtn.Position = UDim2.new(1, -88, 1, -180)
	dashBtn.AnchorPoint = Vector2.new(0, 0)
	dashBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 220)
	dashBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	dashBtn.TextSize = 14
	dashBtn.Font = Enum.Font.GothamBold
	dashBtn.Text = "💨\n대쉬"
	dashBtn.Parent = gui
	self._dashBtn = dashBtn

	local dashCorner = Instance.new("UICorner")
	dashCorner.CornerRadius = UDim.new(0, 12)
	dashCorner.Parent = dashBtn

	-- 쿨다운 오버레이 레이블
	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.Name = "CooldownLabel"
	cooldownLabel.Size = UDim2.new(1, 0, 1, 0)
	cooldownLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cooldownLabel.BackgroundTransparency = 0.4
	cooldownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	cooldownLabel.TextSize = 18
	cooldownLabel.Font = Enum.Font.GothamBold
	cooldownLabel.Text = ""
	cooldownLabel.Visible = false
	cooldownLabel.Parent = dashBtn
	self._dashCooldownLabel = cooldownLabel

	local cooldownCorner = Instance.new("UICorner")
	cooldownCorner.CornerRadius = UDim.new(0, 12)
	cooldownCorner.Parent = cooldownLabel

	-- 대쉬 버튼 터치 이벤트
	dashBtn.MouseButton1Click:Connect(function()
		self:_activateDash()
	end)
end

-- ==================== 이벤트 핸들러 ====================

function SkillController:_setupEventHandlers()
	-- Q키 → 대쉬
	local keyConn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or not self._isGameActive then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			self:_activateDash()
		end
	end)
	table.insert(self._connections, keyConn)

	-- 게임 시작 이벤트: 스킬 정보 수신
	local gameStartConn = RemoteEvents.GameStart.OnClientEvent:Connect(function(data)
		local skills = data.unlockedSkills
		if type(skills) ~= "table" then
			return
		end
		self._unlockedSkills = {}
		for _, skillId in skills do
			self._unlockedSkills[skillId] = true
		end
		self:_applySkills()
	end)
	table.insert(self._connections, gameStartConn)

	-- 서버 스킬 발동 확인 (magnet_burst, shield_regen)
	local activatedConn = RemoteEvents.SkillActivated.OnClientEvent:Connect(function(data)
		if data.skillId == "magnet_burst" then
			self:_showMagnetBurstEffect(data.value)
		end
	end)
	table.insert(self._connections, activatedConn)

	-- 쉴드 재생 알림
	local shieldConn = RemoteEvents.ShieldRegenerated.OnClientEvent:Connect(function()
		self:_showShieldRegenEffect()
	end)
	table.insert(self._connections, shieldConn)
end

-- ==================== 스킬 적용 ====================

function SkillController:_applySkills()
	-- double_jump: PlayerController에 2단 점프 허용 설정
	self._playerController:SetDoubleJump(self._unlockedSkills["double_jump"] == true)

	-- dash: 해금 시 버튼 표시
	if self._gui then
		self._gui.Enabled = self._isGameActive and self._unlockedSkills["dash"] == true
	end

	print(`[SkillController] Skills applied: double_jump={self._unlockedSkills["double_jump"]}, dash={self._unlockedSkills["dash"]}`)
end

function SkillController:SetGameActive(active: boolean)
	self._isGameActive = active
	if not active then
		if self._gui then
			self._gui.Enabled = false
		end
		-- 스킬 비활성화 (게임 종료 시 double_jump 리셋)
		self._playerController:SetDoubleJump(false)
	else
		self:_applySkills()
	end
end

-- ==================== 대쉬 ====================

function SkillController:_activateDash()
	if not self._isGameActive then
		return
	end
	if not self._unlockedSkills["dash"] then
		return
	end

	local now = tick()
	if now - self._dashLastUsed < DASH_COOLDOWN then
		return
	end
	self._dashLastUsed = now

	-- PlayerController에 대쉬 적용
	self._playerController:Dash()

	-- 쿨다운 UI 시작
	self:_startDashCooldownUI()
end

function SkillController:_startDashCooldownUI()
	local label = self._dashCooldownLabel
	if not label then
		return
	end
	label.Visible = true

	task.spawn(function()
		local remaining = DASH_COOLDOWN
		while remaining > 0 do
			task.wait(0.1)
			remaining = math.max(0, DASH_COOLDOWN - (tick() - self._dashLastUsed))
			if label and label.Parent then
				label.Text = math.ceil(remaining) .. "s"
			end
		end
		if label and label.Parent then
			label.Visible = false
			label.Text = ""
		end
	end)
end

-- ==================== 시각 효과 ====================

function SkillController:_showMagnetBurstEffect(coinValue: number)
	-- 화면 상단에 자석 폭발 토스트 표시
	local gui = self._gui
	if not gui then
		return
	end

	local toast = Instance.new("Frame")
	toast.Name = "MagnetBurstToast"
	toast.Size = UDim2.new(0, 220, 0, 44)
	toast.Position = UDim2.new(0.5, -110, 0, -50)
	toast.BackgroundColor3 = Color3.fromRGB(30, 120, 220)
	toast.BorderSizePixel = 0
	toast.Parent = gui

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 10)
	toastCorner.Parent = toast

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Text = `🧲 자석 폭발! +{coinValue} 코인`
	label.Parent = toast

	-- 슬라이드 다운 → 자동 사라짐
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -110, 0, 60),
	}):Play()

	task.delay(MAGNET_BURST_FLASH_DURATION + 1.5, function()
		if toast and toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.25), {
				Position = UDim2.new(0.5, -110, 0, -50),
			}):Play()
			task.delay(0.3, function()
				if toast and toast.Parent then
					toast:Destroy()
				end
			end)
		end
	end)
end

function SkillController:_showShieldRegenEffect()
	local gui = self._gui
	if not gui then
		return
	end

	local toast = Instance.new("Frame")
	toast.Name = "ShieldRegenToast"
	toast.Size = UDim2.new(0, 200, 0, 40)
	toast.Position = UDim2.new(0.5, -100, 0, -50)
	toast.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
	toast.BorderSizePixel = 0
	toast.Parent = gui

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 10)
	toastCorner.Parent = toast

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Text = "🛡️ 쉴드 재생!"
	label.Parent = toast

	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -100, 0, 60),
	}):Play()

	task.delay(2.0, function()
		if toast and toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.25), {
				Position = UDim2.new(0.5, -100, 0, -50),
			}):Play()
			task.delay(0.3, function()
				if toast and toast.Parent then
					toast:Destroy()
				end
			end)
		end
	end)
end

-- ==================== 정리 ====================

function SkillController:Destroy()
	for _, conn in self._connections do
		conn:Disconnect()
	end
	self._connections = {}
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
end

return SkillController

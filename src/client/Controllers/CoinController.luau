--!strict
-- Coin Controller
-- 코인 수집 피드백 처리 (시각/청각 효과)
-- 클라이언트 측 근접 감지로 즉시 이펙트 재생 (서버 네트워크 지연 해소)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local ResponsiveUtil = require(ReplicatedStorage.Shared.Utils.ResponsiveUtil)

local CoinController = {}
CoinController.__index = CoinController

local PARTICLE_POOL_SIZE = 5
local SOUND_POOL_SIZE = 5 -- 빠른 연속 수집 시 사운드 끊김 방지
local LOCAL_COLLECTION_RADIUS = 3.5 -- 서버(3)보다 약간 넓게 (선제 감지)

type ParticlePoolEntry = {
	attachment: Attachment,
	emitter: ParticleEmitter,
	inUse: boolean,
}

export type CoinController = typeof(setmetatable(
	{} :: {
		_connections: { RBXScriptConnection },
		_totalCoins: number,
		_popupGui: ScreenGui?,
		_soundPool: { Sound }, -- #10 사운드 풀링 (빠른 연속 수집)
		_soundPoolIndex: number,
		_comboStreak: number, -- #10 연속 수집 카운터 (상승 음계용)
		_lastCoinTime: number,
		_particlePool: { ParticlePoolEntry },
		_isGameActive: boolean,
		_localCollectedCoins: { [Model]: boolean },
		_onDiamondCollected: (() -> ())?,
		_onCoinEffect: ((coinType: string) -> ())?,
		_onCoinShake: ((coinType: string) -> ())?,
	},
	CoinController
))

function CoinController.new(): CoinController
	local self = setmetatable({
		_connections = {},
		_totalCoins = 0,
		_popupGui = nil,
		_soundPool = {},
		_soundPoolIndex = 0,
		_comboStreak = 0,
		_lastCoinTime = 0,
		_particlePool = {},
		_isGameActive = false,
		_localCollectedCoins = {},
		_onDiamondCollected = nil,
		_onCoinEffect = nil,
		_onCoinShake = nil,
	}, CoinController)

	self:_setupEventHandlers()
	self:_createPopupGui()
	self:_createSoundPool()
	self:_createParticlePool()
	self:_setupLocalCollectionCheck()

	return self
end

-- 게임 활성화/비활성화
function CoinController:SetGameActive(active: boolean)
	self._isGameActive = active
	if not active then
		self._localCollectedCoins = {}
	end
end

-- 팝업 GUI 생성
function CoinController:_createPopupGui()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CoinPopupGui"
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screenGui.Parent = playerGui
	self._popupGui = screenGui
end

-- 사운드 풀 생성 (#10: 5개 인스턴스로 빠른 연속 수집 시 끊김 방지)
function CoinController:_createSoundPool()
	for i = 1, SOUND_POOL_SIZE do
		local sound = Instance.new("Sound")
		sound.Name = "CoinSound_" .. i
		sound.SoundId = "rbxassetid://1169755927" -- Coin Collect SFX (public, free to use)
		sound.Volume = 0.5
		sound.Parent = SoundService
		table.insert(self._soundPool, sound)
	end
end

-- 코인 팝업 표시 (+1, +5 등)
function CoinController:_showCoinPopup(value: number, coinType: string, isDoubled: boolean?)
	if not self._popupGui then
		return
	end

	-- 색상 설정 (코인 종류에 따라)
	local color = Color3.fromRGB(255, 215, 0) -- 기본 금색
	if coinType == "Silver" then
		color = Color3.fromRGB(192, 192, 192)
	elseif coinType == "Diamond" then
		color = Color3.fromRGB(0, 191, 255)
	end

	-- 2배 코인이면 주황색으로 강조
	if isDoubled then
		color = Color3.fromRGB(255, 140, 0)
	end

	-- 팝업 라벨 생성
	local popup = Instance.new("TextLabel")
	popup.Name = "CoinPopup"
	local popupW = ResponsiveUtil.scaledOffset(150)
	popup.Size = UDim2.new(0, popupW, 0, ResponsiveUtil.scaledOffset(50))
	popup.Position = UDim2.new(0.5, -popupW / 2, 0.4, 0)
	popup.BackgroundTransparency = 1
	popup.TextColor3 = color
	popup.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	popup.TextStrokeTransparency = 0.3
	popup.TextSize = isDoubled and ResponsiveUtil.scaledTextSize(42, 28) or ResponsiveUtil.scaledTextSize(36, 24)
	popup.Font = Enum.Font.GothamBold
	-- 정수 강제 (부동소수점 표시 버그 방어)
	local intValue = math.floor(value + 0.5)
	popup.Text = isDoubled and `+{intValue} x2!` or `+{intValue}`
	popup.Parent = self._popupGui

	-- 위로 올라가면서 사라지는 애니메이션
	local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(popup, tweenInfo, {
		Position = UDim2.new(0.5, -popupW / 2, 0.3, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

-- 코인 수집 이벤트 처리
function CoinController:_setupEventHandlers()
	local connection = RemoteEvents.CoinCollected.OnClientEvent:Connect(function(data)
		self:OnCoinCollected(data)
	end)

	table.insert(self._connections, connection)
end

-- 서버 코인 수집 이벤트 (점수/팝업만 처리, 이펙트는 로컬에서 이미 재생됨)
function CoinController:OnCoinCollected(data: {
	coinType: string,
	coinValue: number,
	totalCoins: number,
	isDoubled: boolean?,
})
	self._totalCoins = data.totalCoins

	-- 팝업 표시 (서버에서 확정된 실제 값으로)
	self:_showCoinPopup(data.coinValue, data.coinType, data.isDoubled)

	local doubledText = data.isDoubled and " (x2!)" or ""
	print(`[CoinController] Collected {data.coinType} coin! +{data.coinValue}{doubledText} (Total: {data.totalCoins})`)
end

-- 클라이언트 측 코인 근접 감지 (즉시 이펙트 재생)
function CoinController:_setupLocalCollectionCheck()
	local conn = RunService.Heartbeat:Connect(function()
		if not self._isGameActive then
			return
		end

		local player = Players.LocalPlayer
		local character = player.Character
		if not character then
			return
		end

		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end

		local playerPos = hrp.Position

		-- workspace:GetPartBoundsInBox로 주변 파트 검색
		local params = OverlapParams.new()
		params.FilterDescendantsInstances = { character }
		params.FilterType = Enum.RaycastFilterType.Exclude

		local nearbyParts = workspace:GetPartBoundsInBox(
			CFrame.new(playerPos),
			Vector3.new(LOCAL_COLLECTION_RADIUS * 2, LOCAL_COLLECTION_RADIUS * 2, LOCAL_COLLECTION_RADIUS * 2),
			params
		)

		for _, part in nearbyParts do
			-- OuterRing 파트에 CoinType Attribute가 있는 코인만 처리
			if part.Name ~= "OuterRing" then
				continue
			end

			local coinType = part:GetAttribute("CoinType")
			if not coinType then
				continue
			end

			local coinModel = part.Parent
			if not coinModel or not coinModel:IsA("Model") then
				continue
			end

			-- 이미 로컬에서 처리한 코인 스킵
			if self._localCollectedCoins[coinModel] then
				continue
			end

			-- 정확한 거리 체크 (전진 방향 X 가중치 2배 → 앞쪽 수집 범위 절반으로 제한)
			local delta = part.Position - playerPos
			local scaledDist = Vector3.new(delta.X * 2, delta.Y, delta.Z).Magnitude
			if scaledDist > LOCAL_COLLECTION_RADIUS then
				continue
			end

			-- 로컬에서 즉시 이펙트 재생
			self._localCollectedCoins[coinModel] = true

			-- #10 사운드 풀링 + 상승 음계 (연속 수집마다 피치 +3%, 최대 +25%)
			local now = os.clock()
			if now - self._lastCoinTime > 1.5 then
				self._comboStreak = 0 -- 1.5초 공백 시 스트릭 리셋
			end
			self._comboStreak = self._comboStreak + 1
			self._lastCoinTime = now

			if #self._soundPool > 0 then
				self._soundPoolIndex = (self._soundPoolIndex % #self._soundPool) + 1
				local sound = self._soundPool[self._soundPoolIndex]
				local pitchMap = { Bronze = 1.0, Silver = 1.2, Gold = 1.5, Diamond = 2.0 }
				local basePitch = pitchMap[coinType :: string] or 1.0
				local comboBonus = math.min((self._comboStreak - 1) * 0.03, 0.25) -- 연속 수집 음계 상승
				local jitter = math.random() * 0.06 - 0.03 -- ±3% 자연스러운 변형
				sound.PlaybackSpeed = basePitch + comboBonus + jitter
				sound:Play()
			end

			-- 파티클 효과 (플레이어 위치에서)
			self:_playCoinParticle(coinType :: string, false)

			-- 캐릭터 하이라이트 플래시 콜백
			if self._onCoinEffect then
				self._onCoinEffect(coinType :: string)
			end

			-- 마이크로 카메라 쉐이크 (Diamond는 별도 핸들러에서 더 강한 쉐이크 처리)
			if self._onCoinShake and coinType ~= "Diamond" then
				self._onCoinShake(coinType :: string)
			end

			-- 다이아몬드 코인 특수 콜백
			if coinType == "Diamond" and self._onDiamondCollected then
				self._onDiamondCollected()
			end

			-- #6 코인 스케일팝: 1.8x 확대 + 투명화 (0.12s) 후 소멸
			local scaleTween = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			for _, child in coinModel:GetChildren() do
				if child:IsA("BasePart") then
					TweenService:Create(child, scaleTween, {
						Size = child.Size * 1.8,
						Transparency = 1,
					}):Play()
				end
			end
		end
	end)

	table.insert(self._connections, conn)
end

-- 파티클 풀 생성 (사전 할당으로 GC 부하 감소)
function CoinController:_createParticlePool()
	for i = 1, PARTICLE_POOL_SIZE do
		local attachment = Instance.new("Attachment")
		attachment.Name = `CoinParticle_{i}`

		local particle = Instance.new("ParticleEmitter")
		particle.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		particle.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.8, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		particle.Lifetime = NumberRange.new(0.1, 0.25) -- 빠르게 터지는 임팩트
		particle.Speed = NumberRange.new(15, 35) -- 폭발적 속도
		particle.SpreadAngle = Vector2.new(80, 80) -- 집중된 방향성
		particle.Rate = 0
		particle.Acceleration = Vector3.new(0, -40, 0) -- 중력: "팡!" 후 낙하
		particle.Drag = 3 -- 공기 저항으로 자연스러운 감속
		particle.Parent = attachment

		table.insert(self._particlePool, {
			attachment = attachment,
			emitter = particle,
			inUse = false,
		})
	end
end

-- 풀에서 사용 가능한 파티클 가져오기
function CoinController:_getPooledParticle(): ParticlePoolEntry?
	for _, entry in self._particlePool do
		if not entry.inUse then
			return entry
		end
	end
	return nil
end

-- 코인 수집 파티클 효과
function CoinController:_playCoinParticle(coinType: string, isDoubled: boolean?)
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	-- 파티클 색상 설정
	local color = Color3.fromRGB(255, 215, 0) -- 기본 금색
	if coinType == "Silver" then
		color = Color3.fromRGB(192, 192, 192)
	elseif coinType == "Diamond" then
		color = Color3.fromRGB(0, 191, 255)
	end

	-- 2배 코인이면 주황색
	if isDoubled then
		color = Color3.fromRGB(255, 140, 0)
	end

	-- 풀에서 파티클 가져오기
	local poolEntry = self:_getPooledParticle()
	if not poolEntry then
		return -- 풀이 모두 사용 중이면 스킵
	end

	poolEntry.inUse = true
	poolEntry.attachment.Parent = hrp
	poolEntry.emitter.Color = ColorSequence.new(color)

	-- 코인 타입별 방출 수 차별화 (가치 높을수록 더 화려하게)
	local emitCounts = { Bronze = 10, Silver = 14, Gold = 22, Diamond = 35 }
	local baseCount = emitCounts[coinType] or 10
	poolEntry.emitter:Emit(isDoubled and baseCount * 2 or baseCount)

	-- 파티클 완료 후 풀에 반환 (짧은 Lifetime에 맞춰 빠르게 반환)
	task.delay(0.4, function()
		poolEntry.attachment.Parent = nil
		poolEntry.inUse = false
	end)
end

-- 다이아몬드 코인 수집 콜백 설정
function CoinController:OnDiamondCollected(callback: () -> ())
	self._onDiamondCollected = callback
end

-- 코인 수집 캐릭터 이펙트 콜백 설정
function CoinController:OnCoinEffect(callback: (coinType: string) -> ())
	self._onCoinEffect = callback
end

-- 마이크로 카메라 쉐이크 콜백 설정
function CoinController:OnCoinShake(callback: (coinType: string) -> ())
	self._onCoinShake = callback
end

-- 현재 총 코인 수 반환
function CoinController:GetTotalCoins(): number
	return self._totalCoins
end

-- 정리
function CoinController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	-- 파티클 풀 정리
	for _, entry in self._particlePool do
		entry.attachment:Destroy()
	end
	self._particlePool = {}

	-- 사운드 풀 정리
	for _, sound in self._soundPool do
		sound:Destroy()
	end
	self._soundPool = {}

	if self._popupGui then
		self._popupGui:Destroy()
	end

	self._localCollectedCoins = {}
end

return CoinController

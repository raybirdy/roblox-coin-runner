--!strict
-- JuiceController (Sprint 21)
-- 통합 게임필 피드백 레이어 — Hitstop + Shake 프로파일 + Mobile 스케일링 + Settings 토글
--
-- 사용법:
--   local juice = JuiceController.new(player, cameraController)
--   juice:Trigger("COIN_NORMAL")    -- 프로파일 기반 호출
--   juice:Trigger("HIT")
--   juice:Trigger("FEVER_START")
--
-- 원칙:
--   - 모든 피드백 강도는 GameConstants.JUICE에서만 정의 (하드코딩 금지)
--   - 모바일 자동 감지 → 강도 자동 스케일링
--   - Hitstop은 클라 전용 (Humanoid.WalkSpeed save/restore)
--   - 동시 hitstop 누적 시 게임 정지 방지

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local JuiceController = {}
JuiceController.__index = JuiceController

export type JuiceController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_cameraController: any,
		_isMobile: boolean,
		_shakeEnabled: boolean,
		_hitstopEnabled: boolean,
		_activeHitstopUntil: number,
		_savedWalkSpeed: number?,
	},
	JuiceController
))

function JuiceController.new(player: Player, cameraController: any): JuiceController
	local self = setmetatable({
		_player = player,
		_cameraController = cameraController,
		_isMobile = JuiceController._detectMobile(),
		_shakeEnabled = true,
		_hitstopEnabled = true,
		_activeHitstopUntil = 0,
		_savedWalkSpeed = nil,
	}, JuiceController)

	print(`[JuiceController] Initialized — mobile={self._isMobile}, shake={self._shakeEnabled}, hitstop={self._hitstopEnabled}`)
	return self
end

-- ==================== 모바일 감지 ====================

function JuiceController._detectMobile(): boolean
	-- TouchEnabled + 키보드 없음 = 모바일
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- ==================== Public API ====================

-- 통합 트리거: 프로파일 이름으로 모든 피드백 일괄 발사
-- profile: "COIN_NORMAL" | "COIN_SPECIAL" | "HIT" | "FEVER_START" | "GRAZE" | "LANDING"
function JuiceController:Trigger(profile: string)
	local hitstopMap = GameConstants.JUICE.HITSTOP
	local shakeMap = GameConstants.JUICE.SHAKE

	local hitstopDuration = hitstopMap[profile] or 0
	local shakeIntensity = shakeMap[profile] or 0

	if hitstopDuration > 0 then
		self:Hitstop(hitstopDuration)
	end

	if shakeIntensity > 0 then
		self:Shake(shakeIntensity)
	end
end

-- 카메라 쉐이크 (Settings 토글 + 모바일 스케일 적용)
function JuiceController:Shake(intensity: number)
	if not self._shakeEnabled then
		return
	end
	if self._isMobile then
		intensity *= GameConstants.JUICE.MOBILE_SCALE.SHAKE
	end
	if self._cameraController and self._cameraController.Shake then
		self._cameraController:Shake(intensity)
	else
		-- Fallback: BindableEvent
		local evt = ReplicatedStorage:FindFirstChild("CameraShake") :: BindableEvent?
		if evt then
			evt:Fire(intensity)
		end
	end
end

-- 히트스톱 (frame freeze) — Humanoid WalkSpeed 일시 정지
function JuiceController:Hitstop(duration: number)
	if not self._hitstopEnabled then
		return
	end
	if duration <= 0 then
		return
	end

	-- 모바일 감지 시 히트스톱 단축 (프레임 손실 체감 감소)
	if self._isMobile then
		duration *= GameConstants.JUICE.MOBILE_SCALE.HITSTOP
	end

	local now = os.clock()

	-- 누적 안전장치: 동시 hitstop이 너무 길어지면 무시
	local maxConcurrent = GameConstants.JUICE.MAX_CONCURRENT_HITSTOP
	if self._activeHitstopUntil - now > maxConcurrent then
		return
	end

	local newEnd = math.max(self._activeHitstopUntil, now + duration)
	self._activeHitstopUntil = newEnd

	local character = self._player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- 첫 hitstop 시작이면 현재 속도 저장
	if not self._savedWalkSpeed then
		self._savedWalkSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
	end

	-- end 시점에 복원 (이미 예약된 경우는 newEnd가 더 길면 자동 연장됨)
	task.delay(duration, function()
		-- 다른 hitstop이 더 길게 활성화되어 있으면 복원하지 않음
		if os.clock() < self._activeHitstopUntil - 0.005 then
			return
		end
		local char = self._player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and self._savedWalkSpeed then
				hum.WalkSpeed = self._savedWalkSpeed
			end
		end
		self._savedWalkSpeed = nil
		self._activeHitstopUntil = 0
	end)
end

-- ==================== Settings ====================

function JuiceController:SetShakeEnabled(enabled: boolean)
	self._shakeEnabled = enabled
	print(`[JuiceController] Shake = {enabled}`)
end

function JuiceController:SetHitstopEnabled(enabled: boolean)
	self._hitstopEnabled = enabled
	print(`[JuiceController] Hitstop = {enabled}`)
end

function JuiceController:IsMobile(): boolean
	return self._isMobile
end

function JuiceController:GetMobileParticleScale(): number
	if self._isMobile then
		return GameConstants.JUICE.MOBILE_SCALE.PARTICLES
	end
	return 1.0
end

return JuiceController

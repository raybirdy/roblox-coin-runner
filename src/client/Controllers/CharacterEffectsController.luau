--!strict
-- Character Effects Controller
-- 캐릭터 몸에 Highlight 기반 시각 효과 적용 (코인 수집 플래시, 파워업 글로우)
-- 성능: 단일 Highlight 인스턴스 + TweenService = 파티클/GC 부하 없음

local TweenService = game:GetService("TweenService")

local CharacterEffectsController = {}
CharacterEffectsController.__index = CharacterEffectsController

-- 코인 타입별 플래시 색상
local COIN_FLASH_COLORS = {
	Bronze = Color3.fromRGB(220, 170, 40),
	Silver = Color3.fromRGB(200, 200, 220),
	Gold = Color3.fromRGB(255, 220, 0),
	Diamond = Color3.fromRGB(0, 210, 255),
}

-- 파워업 지속 글로우 색상
local POWERUP_GLOW_COLORS = {
	Magnet = Color3.fromRGB(60, 140, 255),
	Shield = Color3.fromRGB(50, 220, 80),
	Invincible = Color3.fromRGB(255, 230, 0),
	DoubleCoin = Color3.fromRGB(255, 140, 0),
}

-- 파워업 활성 중 글로우 강도 (0 = 불투명, 1 = 투명)
local GLOW_FILL = 0.75
local GLOW_OUTLINE = 0.2

export type CharacterEffectsController = typeof(setmetatable(
	{} :: {
		_highlight: Highlight,
		_activePowerupGlow: string?, -- 현재 글로우가 켜진 파워업 타입
		_flashTween: Tween?,
	},
	CharacterEffectsController
))

function CharacterEffectsController.new(character: Model): CharacterEffectsController
	local highlight = Instance.new("Highlight")
	highlight.Name = "CharacterHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Parent = character

	local self = setmetatable({
		_highlight = highlight,
		_activePowerupGlow = nil,
		_flashTween = nil,
	}, CharacterEffectsController)

	return self
end

-- 코인 수집 플래시 (코인 타입별 색상, 짧은 flash)
function CharacterEffectsController:FlashCoin(coinType: string)
	local color = COIN_FLASH_COLORS[coinType] or COIN_FLASH_COLORS.Bronze
	local duration = coinType == "Diamond" and 0.3 or 0.15
	self:_flash(color, duration)
end

-- 거인 코인 수집 플래시 (밝은 흰색)
function CharacterEffectsController:FlashGiantCoin()
	self:_flash(Color3.fromRGB(255, 255, 255), 0.4)
end

-- 파워업 활성/비활성 글로우 제어
function CharacterEffectsController:SetPowerupGlow(powerupType: string, active: boolean)
	if active then
		self._activePowerupGlow = powerupType
		local color = POWERUP_GLOW_COLORS[powerupType] or Color3.fromRGB(255, 255, 255)

		-- 진행 중인 플래시 트윈 취소
		if self._flashTween then
			self._flashTween:Cancel()
			self._flashTween = nil
		end

		self._highlight.FillColor = color
		self._highlight.OutlineColor = color
		self._highlight.FillTransparency = GLOW_FILL
		self._highlight.OutlineTransparency = GLOW_OUTLINE
	else
		if self._activePowerupGlow == powerupType then
			self._activePowerupGlow = nil

			-- 부드럽게 페이드 아웃
			if self._flashTween then
				self._flashTween:Cancel()
			end
			local tween = TweenService:Create(
				self._highlight,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ FillTransparency = 1, OutlineTransparency = 1 }
			)
			tween:Play()
			self._flashTween = tween
		end
	end
end

-- 쉴드 파괴 플래시 (녹색-흰색 버스트)
function CharacterEffectsController:FlashShieldBreak()
	self._activePowerupGlow = nil
	self:_flash(Color3.fromRGB(160, 255, 160), 0.25)
end

-- 내부: 플래시 후 글로우 상태로 복귀 or 투명으로 복귀
function CharacterEffectsController:_flash(color: Color3, duration: number)
	if self._flashTween then
		self._flashTween:Cancel()
		self._flashTween = nil
	end

	self._highlight.FillColor = color
	self._highlight.OutlineColor = color
	self._highlight.FillTransparency = 0.3
	self._highlight.OutlineTransparency = 0

	-- 플래시 후 복귀 목표값 결정
	local targetFill: number
	local targetOutline: number

	if self._activePowerupGlow then
		targetFill = GLOW_FILL
		targetOutline = GLOW_OUTLINE
	else
		targetFill = 1
		targetOutline = 1
	end

	local tween = TweenService:Create(
		self._highlight,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = targetFill, OutlineTransparency = targetOutline }
	)
	tween:Play()
	self._flashTween = tween

	-- 플래시 완료 후 파워업 글로우 색상 복원
	if self._activePowerupGlow then
		local capturedGlow = self._activePowerupGlow
		tween.Completed:Connect(function()
			if self._activePowerupGlow == capturedGlow then
				local glowColor = POWERUP_GLOW_COLORS[capturedGlow]
				if glowColor then
					self._highlight.FillColor = glowColor
					self._highlight.OutlineColor = glowColor
				end
			end
		end)
	end
end

-- 캐릭터 리스폰 시 Highlight 재생성
function CharacterEffectsController:UpdateCharacter(newCharacter: Model)
	if self._flashTween then
		self._flashTween:Cancel()
		self._flashTween = nil
	end
	if self._highlight then
		self._highlight:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "CharacterHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Parent = newCharacter
	self._highlight = highlight

	-- 리스폰 후에도 파워업 글로우 복원
	if self._activePowerupGlow then
		local color = POWERUP_GLOW_COLORS[self._activePowerupGlow] or Color3.fromRGB(255, 255, 255)
		highlight.FillColor = color
		highlight.OutlineColor = color
		highlight.FillTransparency = GLOW_FILL
		highlight.OutlineTransparency = GLOW_OUTLINE
	end
end

-- 정리
function CharacterEffectsController:Destroy()
	if self._flashTween then
		self._flashTween:Cancel()
	end
	if self._highlight then
		self._highlight:Destroy()
	end
end

return CharacterEffectsController

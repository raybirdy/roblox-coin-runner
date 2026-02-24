--!strict
-- Animation Controller
-- 캐릭터 애니메이션 관리

local AnimationController = {}
AnimationController.__index = AnimationController

-- Roblox 기본 애니메이션 ID (R6/R15 호환)
local ANIMATION_IDS = {
	Run = "rbxassetid://180426354", -- 달리기
	Jump = "rbxassetid://125750702", -- 점프
	Fall = "rbxassetid://180436148", -- 낙하
	Idle = "rbxassetid://180435571", -- 대기
	Slide = "rbxassetid://180436334", -- 앉기 (슬라이드 대체)
}

export type AnimationController = typeof(setmetatable(
	{} :: {
		_humanoid: Humanoid,
		_animator: Animator?,
		_animations: { [string]: Animation },
		_tracks: { [string]: AnimationTrack },
		_currentTrack: AnimationTrack?,
		_currentState: string,
	},
	AnimationController
))

function AnimationController.new(humanoid: Humanoid): AnimationController
	local self = setmetatable({
		_humanoid = humanoid,
		_animator = nil,
		_animations = {},
		_tracks = {},
		_currentTrack = nil,
		_currentState = "Idle",
	}, AnimationController)

	self:_initialize()

	return self
end

-- 초기화
function AnimationController:_initialize()
	-- Animator 가져오기 또는 생성
	self._animator = self._humanoid:FindFirstChildOfClass("Animator")
	if not self._animator then
		self._animator = Instance.new("Animator")
		self._animator.Parent = self._humanoid
	end

	-- 애니메이션 객체 생성
	for name, id in pairs(ANIMATION_IDS) do
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = id
		self._animations[name] = animation
	end

	-- 애니메이션 트랙 로드
	for name, animation in pairs(self._animations) do
		local success, track = pcall(function()
			return self._animator:LoadAnimation(animation)
		end)

		if success and track then
			self._tracks[name] = track

			-- 루프 설정
			if name == "Run" or name == "Idle" or name == "Slide" then
				track.Looped = true
			else
				track.Looped = false
			end

			-- 우선순위 설정 (기본 Animate 스크립트보다 높은 우선순위)
			track.Priority = Enum.AnimationPriority.Action4
		else
			warn(`[AnimationController] Failed to load animation: {name}`)
		end
	end

	print("[AnimationController] Initialized with animations")
end

-- 애니메이션 재생 (fadeTime: 전환 시간, 기본 0.1초)
function AnimationController:Play(state: string, speed: number?, fadeTime: number?)
	-- 같은 상태면 무시
	if self._currentState == state and self._currentTrack and self._currentTrack.IsPlaying then
		return
	end

	local fade = fadeTime or 0.1

	-- 이전 애니메이션 정지
	if self._currentTrack then
		pcall(function()
			self._currentTrack:Stop(fade)
		end)
	end

	-- 새 애니메이션 재생
	local track = self._tracks[state]
	if track then
		local success = pcall(function()
			track:Play(fade)

			-- 속도 조절 (달리기 속도에 맞춤)
			if speed then
				track:AdjustSpeed(speed)
			end
		end)

		if success then
			self._currentTrack = track
			self._currentState = state
		end
	end
end

-- 달리기 애니메이션 (속도에 따라 조절)
function AnimationController:PlayRun(speedMultiplier: number?, immediate: boolean?)
	local speed = speedMultiplier or 1.0
	local fade = immediate and 0 or nil
	self:Play("Run", speed, fade)
end

-- 점프 애니메이션
function AnimationController:PlayJump()
	self:Play("Jump")
end

-- 낙하 애니메이션
function AnimationController:PlayFall()
	self:Play("Fall")
end

-- 슬라이드 애니메이션
function AnimationController:PlaySlide()
	self:Play("Slide", 0.5)
end

-- 대기 애니메이션
function AnimationController:PlayIdle()
	self:Play("Idle")
end

-- 모든 애니메이션 정지
function AnimationController:StopAll()
	for _, track in pairs(self._tracks) do
		track:Stop(0.1)
	end
	self._currentTrack = nil
	self._currentState = ""
end

-- 현재 상태 가져오기
function AnimationController:GetCurrentState(): string
	return self._currentState
end

-- 정리
function AnimationController:Destroy()
	self:StopAll()

	for _, animation in pairs(self._animations) do
		animation:Destroy()
	end
	self._animations = {}
	self._tracks = {}
end

return AnimationController

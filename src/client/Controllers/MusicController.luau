--!strict
-- Music Controller
-- 배경 음악 재생 및 관리

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local MusicController = {}
MusicController.__index = MusicController

export type MusicController = typeof(setmetatable(
	{} :: {
		_bgm: Sound?,
		_isPlaying: boolean,
		_volume: number,
		_connections: { RBXScriptConnection },
	},
	MusicController
))

-- 배경 음악 설정
local BGM_CONFIG = {
	-- Roblox 무료 음악 에셋 (나중에 교체 가능)
	menuMusic = "rbxassetid://1837849285", -- 밝은 분위기 음악
	gameMusic = "rbxassetid://1845756489", -- 신나는 게임 음악
	volume = 0.3,
	fadeTime = 1.0,
}

function MusicController.new(): MusicController
	local self = setmetatable({
		_bgm = nil,
		_isPlaying = false,
		_volume = BGM_CONFIG.volume,
		_connections = {},
	}, MusicController)

	self:_createBGM()
	self:_setupEventHandlers()

	return self
end

-- BGM 사운드 객체 생성
function MusicController:_createBGM()
	local bgm = Instance.new("Sound")
	bgm.Name = "BackgroundMusic"
	bgm.SoundId = BGM_CONFIG.menuMusic
	bgm.Volume = 0
	bgm.Looped = true
	bgm.Parent = SoundService
	self._bgm = bgm

	print("[MusicController] BGM created")
end

-- 이벤트 핸들러 설정
function MusicController:_setupEventHandlers()
	-- 게임 시작 시 게임 음악으로 전환
	local gameStartConnection = RemoteEvents.GameStart.OnClientEvent:Connect(function()
		self:PlayGameMusic()
	end)
	table.insert(self._connections, gameStartConnection)

	-- 게임 오버 시 메뉴 음악으로 전환
	local gameOverConnection = RemoteEvents.GameOver.OnClientEvent:Connect(function(data)
		-- 부활 가능한 경우 음악 유지
		if not data.canRevive then
			self:PlayMenuMusic()
		end
	end)
	table.insert(self._connections, gameOverConnection)

	print("[MusicController] Event handlers set up")
end

-- 메뉴 음악 재생
function MusicController:PlayMenuMusic()
	if not self._bgm then
		return
	end

	self:_fadeToMusic(BGM_CONFIG.menuMusic)
	print("[MusicController] Playing menu music")
end

-- 게임 음악 재생
function MusicController:PlayGameMusic()
	if not self._bgm then
		return
	end

	self:_fadeToMusic(BGM_CONFIG.gameMusic)
	print("[MusicController] Playing game music")
end

-- 음악 페이드 전환
function MusicController:_fadeToMusic(soundId: string)
	if not self._bgm then
		return
	end

	local TweenService = game:GetService("TweenService")

	-- 현재 음악이 같으면 무시
	if self._bgm.SoundId == soundId and self._isPlaying then
		return
	end

	-- 페이드 아웃
	if self._isPlaying then
		local fadeOut = TweenService:Create(self._bgm, TweenInfo.new(BGM_CONFIG.fadeTime / 2), {
			Volume = 0,
		})
		fadeOut:Play()
		fadeOut.Completed:Wait()
	end

	-- 음악 변경 및 페이드 인
	self._bgm.SoundId = soundId
	self._bgm:Play()
	self._isPlaying = true

	local fadeIn = TweenService:Create(self._bgm, TweenInfo.new(BGM_CONFIG.fadeTime / 2), {
		Volume = self._volume,
	})
	fadeIn:Play()
end

-- 음악 시작 (초기 재생)
function MusicController:Start()
	self:PlayMenuMusic()
end

-- 음악 정지
function MusicController:Stop()
	if not self._bgm then
		return
	end

	local TweenService = game:GetService("TweenService")
	local fadeOut = TweenService:Create(self._bgm, TweenInfo.new(BGM_CONFIG.fadeTime), {
		Volume = 0,
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		if self._bgm then
			self._bgm:Stop()
		end
		self._isPlaying = false
	end)

	print("[MusicController] Music stopped")
end

-- 볼륨 설정
function MusicController:SetVolume(volume: number)
	self._volume = math.clamp(volume, 0, 1)
	if self._bgm and self._isPlaying then
		self._bgm.Volume = self._volume
	end
end

-- 볼륨 가져오기
function MusicController:GetVolume(): number
	return self._volume
end

-- 정리
function MusicController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}

	if self._bgm then
		self._bgm:Destroy()
	end
end

print("[MusicController] Initialized")

return MusicController

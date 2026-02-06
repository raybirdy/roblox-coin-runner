--!strict
-- Tutorial Service
-- 튜토리얼 관리 (서버)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local TutorialService = {}
TutorialService.__index = TutorialService

export type TutorialService = typeof(setmetatable(
	{} :: {
		_activeTutorials: { [Player]: boolean },
		_playerDataService: any?, -- PlayerDataService 참조
	},
	TutorialService
))

function TutorialService.new(): TutorialService
	local self = setmetatable({
		_activeTutorials = {},
		_playerDataService = nil,
	}, TutorialService)

	self:_setupEventHandlers()

	return self
end

-- PlayerDataService 설정
function TutorialService:SetPlayerDataService(playerDataService: any)
	self._playerDataService = playerDataService
end

-- 이벤트 핸들러 설정
function TutorialService:_setupEventHandlers()
	-- 튜토리얼 시작
	RemoteEvents.TutorialStart.OnServerEvent:Connect(function(player: Player)
		self:StartTutorial(player)
	end)

	-- 튜토리얼 종료
	RemoteEvents.TutorialEnd.OnServerEvent:Connect(function(player: Player)
		self:EndTutorial(player)
	end)
end

-- 튜토리얼 필요 여부 확인
function TutorialService:NeedsTutorial(player: Player): boolean
	if not self._playerDataService then
		return false
	end

	local playerData = self._playerDataService:GetPlayerData(player)
	if not playerData then
		return true -- 데이터가 없으면 튜토리얼 필요
	end

	return not playerData.tutorialCompleted
end

-- 튜토리얼 시작
function TutorialService:StartTutorial(player: Player)
	if self._activeTutorials[player] then
		return
	end

	self._activeTutorials[player] = true

	-- 클라이언트에 튜토리얼 모드 알림
	RemoteEvents.TutorialMode:FireClient(player, {
		active = true,
		speedMultiplier = GameConstants.TUTORIAL.SLOWMO_SPEED_MULTIPLIER,
	})

	print(`[TutorialService] Tutorial started for {player.Name}`)
end

-- 튜토리얼 종료
function TutorialService:EndTutorial(player: Player)
	if not self._activeTutorials[player] then
		return
	end

	self._activeTutorials[player] = nil

	-- 튜토리얼 완료 상태 저장
	if self._playerDataService then
		self._playerDataService:SetTutorialCompleted(player, true)
	end

	-- 클라이언트에 정상 속도 복귀 알림
	RemoteEvents.TutorialMode:FireClient(player, {
		active = false,
		speedMultiplier = 1.0,
	})

	print(`[TutorialService] Tutorial ended for {player.Name}`)
end

-- 튜토리얼 활성 여부
function TutorialService:IsActive(player: Player): boolean
	return self._activeTutorials[player] == true
end

-- 정리
function TutorialService:Destroy()
	self._activeTutorials = {}
end

return TutorialService

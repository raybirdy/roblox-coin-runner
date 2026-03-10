--!strict
-- Run Skill Service
-- 런 내 레벨 성장 및 스킬 선택 처리

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local RunSkillService = {}

-- 플레이어별 런 세션 상태
type RunSession = {
	runXP: number,
	runLevel: number,
	activeRunSkills: { [string]: any }, -- skillId → { effectType, effectValue, duration, startTime }
	pendingSelection: boolean, -- 스킬 선택 대기 중
	pendingOptions: { any }, -- 제안된 스킬 목록
	autoSelectTimer: thread?, -- 자동 선택 태스크
	-- 누적 효과
	magnetBonus: number,
	speedBonus: number,
	coinMultiplier: number,
	hasRunShield: boolean,
	luckyCoinsLeft: number,
	timeSlow: boolean,
	timeSlowEndTime: number,
}

local runSessions: { [Player]: RunSession } = {}

-- 런 내 XP 요구량 계산
local function getXPRequired(level: number): number
	return math.floor(50 * level ^ 1.2)
end

-- 스킬 풀에서 등급별 가중치 적용 랜덤 선택
local RARITY_WEIGHTS = { common = 50, rare = 35, legendary = 15 }

local function pickSkills(count: number, excluded: { [string]: boolean }): { any }
	local pool: { any } = {}
	for _, skill in GameConstants.RUN_SKILLS do
		if not excluded[skill.id] then
			local weight = RARITY_WEIGHTS[skill.rarity] or 10
			for _ = 1, weight do
				table.insert(pool, skill)
			end
		end
	end

	local picked: { any } = {}
	local pickedIds: { [string]: boolean } = {}
	local attempts = 0
	while #picked < count and attempts < 100 do
		attempts += 1
		if #pool == 0 then
			break
		end
		local idx = math.random(1, #pool)
		local skill = pool[idx]
		if not pickedIds[skill.id] then
			table.insert(picked, skill)
			pickedIds[skill.id] = true
		end
	end
	return picked
end

-- 런 세션 시작
function RunSkillService:StartSession(player: Player)
	runSessions[player] = {
		runXP = 0,
		runLevel = 1,
		activeRunSkills = {},
		pendingSelection = false,
		pendingOptions = {},
		autoSelectTimer = nil,
		magnetBonus = 0,
		speedBonus = 0,
		coinMultiplier = 1,
		hasRunShield = false,
		luckyCoinsLeft = 0,
		timeSlow = false,
		timeSlowEndTime = 0,
	}

	-- 초기 XP 바 전송
	RemoteEvents.RunXPUpdate:FireClient(player, {
		runXP = 0,
		runXPMax = getXPRequired(1),
		runLevel = 1,
	})
end

-- 런 세션 종료
function RunSkillService:EndSession(player: Player)
	local session = runSessions[player]
	if session and session.autoSelectTimer then
		task.cancel(session.autoSelectTimer)
	end
	runSessions[player] = nil
end

-- XP 추가 (코인 수집, 니어미스, 피버 시 호출)
function RunSkillService:AddXP(player: Player, amount: number)
	local session = runSessions[player]
	if not session then
		return
	end

	-- 스킬 선택 대기 중이면 XP 잠시 보류 (UI 집중 유도)
	if session.pendingSelection then
		return
	end

	session.runXP += amount

	-- 레벨업 체크
	while session.runLevel < GameConstants.RUN_PROGRESSION.MAX_RUN_LEVEL do
		local required = getXPRequired(session.runLevel)
		if session.runXP >= required then
			session.runXP -= required
			session.runLevel += 1
			self:_triggerSkillSelection(player, session)
			break -- 레벨업 후 스킬 선택 대기 → XP 잠금
		else
			break
		end
	end

	-- XP 업데이트 전송
	RemoteEvents.RunXPUpdate:FireClient(player, {
		runXP = session.runXP,
		runXPMax = getXPRequired(session.runLevel),
		runLevel = session.runLevel,
	})
end

-- 스킬 선택 화면 트리거
function RunSkillService:_triggerSkillSelection(player: Player, session: RunSession)
	-- 이미 선택 대기 중이면 무시
	if session.pendingSelection then
		return
	end

	-- 이미 보유한 스킬 제외 (중복 방지)
	local ownedSet: { [string]: boolean } = {}
	for skillId in session.activeRunSkills do
		ownedSet[skillId] = true
	end

	local choices = pickSkills(GameConstants.RUN_PROGRESSION.SKILL_CHOICES, ownedSet)
	if #choices == 0 then
		return
	end

	session.pendingSelection = true
	session.pendingOptions = choices

	-- 클라이언트에 스킬 선택 옵션 전송
	local choiceData = {}
	for _, skill in choices do
		table.insert(choiceData, {
			id = skill.id,
			name = skill.name,
			emoji = skill.emoji,
			desc = skill.desc,
			rarity = skill.rarity,
		})
	end

	RemoteEvents.RunSkillOptions:FireClient(player, {
		skills = choiceData,
		autoSelectDelay = GameConstants.RUN_PROGRESSION.AUTO_SELECT_DELAY,
	})

	-- 자동 선택 타이머 (5초 후 첫 번째 카드 자동 선택)
	session.autoSelectTimer = task.delay(GameConstants.RUN_PROGRESSION.AUTO_SELECT_DELAY, function()
		if runSessions[player] and runSessions[player].pendingSelection then
			self:_applySkill(player, choices[1])
			runSessions[player].pendingSelection = false
			runSessions[player].pendingOptions = {}
		end
	end)
end

-- 스킬 효과 적용
function RunSkillService:_applySkill(player: Player, skill: any)
	local session = runSessions[player]
	if not session then
		return
	end

	local now = os.clock()

	-- 효과 등록
	session.activeRunSkills[skill.id] = {
		effectType = skill.effectType,
		effectValue = skill.effectValue,
		duration = skill.duration,
		startTime = now,
	}

	-- 누적 효과 업데이트
	if skill.effectType == "magnet_bonus" then
		session.magnetBonus += skill.effectValue
	elseif skill.effectType == "speed_multiplier" then
		session.speedBonus += skill.effectValue
	elseif skill.effectType == "coin_multiplier" then
		session.coinMultiplier = skill.effectValue -- 2배 고정
	elseif skill.effectType == "shield" then
		session.hasRunShield = true
	elseif skill.effectType == "lucky_coins" then
		session.luckyCoinsLeft += skill.effectValue
	elseif skill.effectType == "time_slow" then
		session.timeSlow = true
		session.timeSlowEndTime = now + skill.duration
		task.delay(skill.duration, function()
			if runSessions[player] then
				runSessions[player].timeSlow = false
			end
		end)
	elseif skill.effectType == "combo_boost" then
		-- combo_boost는 즉시 발동, GameManager에서 처리 필요
		-- 여기서는 RemoteEvent로 알림만
	elseif skill.effectType == "invincible" then
		-- invincible은 duration 후 자동 해제, GameManager에서 처리
	elseif skill.effectType == "vacuum" then
		-- vacuum은 즉시 발동, GameManager에서 처리
	elseif skill.effectType == "coin_density" then
		-- coin_density는 duration 후 해제, GameManager에서 처리
	end

	-- 클라이언트에 스킬 발동 알림
	RemoteEvents.RunSkillActivated:FireClient(player, {
		skillId = skill.id,
		name = skill.name,
		emoji = skill.emoji,
		effectType = skill.effectType,
		effectValue = skill.effectValue,
		duration = skill.duration,
	})

	print(`[RunSkillService] {player.Name} selected skill: {skill.name} ({skill.rarity})`)
end

-- 스킬 선택 핸들러 (클라이언트 → 서버)
-- 런 시작 전 장착 스킬 적용 (GameManager에서 호출)
function RunSkillService:ApplyPreRunSkills(player: Player, skillIds: { string })
	if #skillIds == 0 then
		return
	end

	-- GameConstants.RUN_SKILLS에서 해당 스킬 데이터 조회
	local skillMap: { [string]: any } = {}
	for _, skill in GameConstants.RUN_SKILLS do
		skillMap[skill.id] = skill
	end

	for _, skillId in skillIds do
		local skill = skillMap[skillId]
		if skill then
			self:_applySkill(player, skill)
			print(`[RunSkillService] Pre-run skill applied: {skill.name} for {player.Name}`)
		end
	end
end

function RunSkillService:SetupRemoteEvents(playerDataService: any)
	-- 런 중 스킬 선택
	RemoteEvents.RunSkillSelect.OnServerEvent:Connect(function(player: Player, data: { skillId: string })
		if not RateLimiter.Check(player, "RunSkillSelect", 2) then
			return
		end

		local session = runSessions[player]
		if not session or not session.pendingSelection then
			return
		end

		-- 제안된 스킬 중 선택한 스킬 검증
		local selectedSkill = nil
		for _, skill in session.pendingOptions do
			if skill.id == data.skillId then
				selectedSkill = skill
				break
			end
		end

		if not selectedSkill then
			return
		end

		-- 자동 선택 타이머 취소
		if session.autoSelectTimer then
			task.cancel(session.autoSelectTimer)
			session.autoSelectTimer = nil
		end

		session.pendingSelection = false
		session.pendingOptions = {}

		self:_applySkill(player, selectedSkill)
	end)

	-- 런 스킬 슬롯 장착 (로비에서)
	RemoteEvents.EquipRunSkills.OnServerEvent:Connect(function(player: Player, data: { skillIds: { string } })
		if not RateLimiter.Check(player, "EquipRunSkills", 2) then
			return
		end
		if type(data) ~= "table" or type(data.skillIds) ~= "table" then
			return
		end
		local success = playerDataService:SetEquippedRunSkills(player, data.skillIds)
		if success then
			-- 최신 슬롯 데이터 재전송
			RunSkillService:SendPreRunSkillData(player, playerDataService)
		end
	end)
end

-- ==================== 효과 조회 (GameManager에서 사용) ====================

-- 자석 보너스 합산
function RunSkillService:GetMagnetBonus(player: Player): number
	local session = runSessions[player]
	return session and session.magnetBonus or 0
end

-- 속도 보너스 합산
function RunSkillService:GetSpeedBonus(player: Player): number
	local session = runSessions[player]
	return session and session.speedBonus or 0
end

-- 코인 배율
function RunSkillService:GetCoinMultiplier(player: Player): number
	local session = runSessions[player]
	return session and session.coinMultiplier or 1
end

-- 런 방어막 소모 (피격 시 호출)
function RunSkillService:ConsumeRunShield(player: Player): boolean
	local session = runSessions[player]
	if session and session.hasRunShield then
		session.hasRunShield = false
		session.activeRunSkills["shield"] = nil
		return true
	end
	return false
end

-- 럭키 코인 소모 (코인 수집 시 호출)
function RunSkillService:ConsumeLuckyCoin(player: Player): boolean
	local session = runSessions[player]
	if session and session.luckyCoinsLeft > 0 then
		session.luckyCoinsLeft -= 1
		return true
	end
	return false
end

-- 시간 지연 활성 여부
function RunSkillService:IsTimeSlow(player: Player): boolean
	local session = runSessions[player]
	return session ~= nil and session.timeSlow
end

-- 런 레벨 조회
function RunSkillService:GetRunLevel(player: Player): number
	local session = runSessions[player]
	return session and session.runLevel or 1
end

-- 런 스킬 슬롯 데이터 전송 (PlayerAdded + 슬롯 변경 시)
function RunSkillService:SendPreRunSkillData(player: Player, playerDataService: any)
	local unlockedIds = playerDataService:GetUnlockedRunSkills(player)
	local equippedIds = playerDataService:GetEquippedRunSkills(player)

	-- 스킬 메타데이터 조회
	local skillMap: { [string]: any } = {}
	for _, skill in GameConstants.RUN_SKILLS do
		skillMap[skill.id] = skill
	end

	local unlockedData: { any } = {}
	for _, skillId in unlockedIds do
		local skill = skillMap[skillId]
		if skill then
			table.insert(unlockedData, {
				id = skill.id,
				name = skill.name,
				emoji = skill.emoji,
				desc = skill.desc,
				rarity = skill.rarity,
			})
		end
	end

	RemoteEvents.PreRunSkillData:FireClient(player, {
		unlockedSkills = unlockedData,
		equippedSkills = equippedIds,
	})
end

print("[RunSkillService] Initialized")

return RunSkillService

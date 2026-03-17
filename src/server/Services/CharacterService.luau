--!strict
-- Character Service
-- 플레이어블 캐릭터 해금/장착/비주얼/스킬 처리

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local CharacterService = {}

-- 캐릭터 ID → 데이터 맵
local characterMap: { [string]: any } = {}
for _, char in GameConstants.CHARACTERS.LIST do
	characterMap[char.id] = char
end

-- ==================== 캐릭터 데이터 ====================

-- 캐릭터 데이터 전송 (서버 → 클라이언트)
function CharacterService:SendCharacterData(player: Player, playerDataService: any)
	local playerData = playerDataService:GetPlayerData(player)
	if not playerData then
		return
	end
	RemoteEvents.CharacterData:FireClient(player, {
		ownedCharacters = playerData.ownedCharacters or { "runner" },
		equippedCharacter = playerData.equippedCharacter or "runner",
	})
end

-- ==================== 캐릭터 해금 ====================

-- 캐릭터 해금 (외부 호출용)
function CharacterService:UnlockCharacter(player: Player, characterId: string, playerDataService: any)
	if playerDataService:OwnsCharacter(player, characterId) then
		return
	end
	playerDataService:AddCharacter(player, characterId)
	playerDataService:SavePlayerData(player)

	local charData = characterMap[characterId]
	RemoteEvents.CharacterUnlocked:FireClient(player, {
		characterId = characterId,
		characterName = charData and charData.name or characterId,
	})

	print(`[CharacterService] {player.Name} unlocked character: {characterId}`)
end

-- 레벨 기반 캐릭터 해금 체크 (ProgressionService가 레벨업 시 호출)
function CharacterService:CheckLevelUnlocks(player: Player, newLevel: number, playerDataService: any)
	for _, char in GameConstants.CHARACTERS.LIST do
		-- 일반 레벨 해금
		if char.unlockType == "level" and char.unlockValue <= newLevel then
			if not playerDataService:OwnsCharacter(player, char.id) then
				self:UnlockCharacter(player, char.id, playerDataService)
			end
		end
		-- 임시 해금 경로 (배틀패스 등 출시 전 임시 레벨 해금)
		if char.tempUnlockType == "level" and char.tempUnlockValue and char.tempUnlockValue <= newLevel then
			if not playerDataService:OwnsCharacter(player, char.id) then
				self:UnlockCharacter(player, char.id, playerDataService)
			end
		end
	end
end

-- ==================== 패시브 보너스 ====================

-- 장착 중인 캐릭터의 패시브 보너스 반환
function CharacterService:GetPassiveBonus(player: Player, playerDataService: any): { type: string, value: number }
	local characterId = playerDataService:GetEquippedCharacter(player)
	local charData = characterMap[characterId]
	if not charData or not charData.passive or charData.passive.type == "none" then
		return { type = "none", value = 0 }
	end
	return charData.passive
end

-- 패시브 타입별 편의 함수
function CharacterService:GetMagnetBonus(player: Player, playerDataService: any): number
	local passive = self:GetPassiveBonus(player, playerDataService)
	if passive.type == "magnet_bonus" then
		return math.min(passive.value, GameConstants.CHARACTERS.MAX_MAGNET_BONUS)
	end
	return 0
end

function CharacterService:GetFeverExtend(player: Player, playerDataService: any): number
	local passive = self:GetPassiveBonus(player, playerDataService)
	if passive.type == "fever_extend" then
		return math.min(passive.value, GameConstants.CHARACTERS.MAX_FEVER_EXTEND)
	end
	return 0
end

function CharacterService:HasHitResist(player: Player, playerDataService: any): boolean
	local passive = self:GetPassiveBonus(player, playerDataService)
	return passive.type == "hit_resist"
end

function CharacterService:GetHitResistChance(player: Player, playerDataService: any): number
	local passive = self:GetPassiveBonus(player, playerDataService)
	if passive.type == "hit_resist" then
		return passive.value
	end
	return 0
end

function CharacterService:GetStartMagnetDuration(player: Player, playerDataService: any): number
	local passive = self:GetPassiveBonus(player, playerDataService)
	if passive.type == "start_magnet" then
		return passive.value
	end
	return 0
end

-- ==================== 캐릭터 스킬 ====================

-- 스킬 쿨다운 체크
local function isSkillReady(playerData: any, characterId: string, cooldown: number): boolean
	if not playerData.characterSkillLastUsed then
		return true
	end
	local lastUsed = playerData.characterSkillLastUsed[characterId] or 0
	return os.time() - lastUsed >= cooldown
end

-- 스킬 사용 처리
function CharacterService:_onSkillUse(player: Player, playerDataService: any)
	local playerData = playerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	local characterId = playerData.equippedCharacter or "runner"
	local charData = characterMap[characterId]
	if not charData or not charData.skill then
		return
	end

	local skill = charData.skill
	if not isSkillReady(playerData, characterId, skill.cooldown) then
		return
	end

	-- 쿨다운 기록
	if not playerData.characterSkillLastUsed then
		playerData.characterSkillLastUsed = {}
	end
	playerData.characterSkillLastUsed[characterId] = os.time()

	-- 클라이언트에 스킬 발동 알림
	RemoteEvents.CharacterSkillActivated:FireClient(player, {
		skillId = skill.id,
		duration = skill.duration,
		cooldown = skill.cooldown,
	})

	print(`[CharacterService] {player.Name} used skill: {skill.id} ({characterId})`)
end

-- ==================== 캐릭터 비주얼 ====================

-- 캐릭터 비주얼 적용 (서버: 색상/재질, 클라이언트에도 CharacterData 전송)
function CharacterService:ApplyCharacterModel(player: Player, characterId: string)
	local character = player.Character
	if not character then
		return
	end

	local charData = characterMap[characterId]
	if not charData then
		return
	end

	local skinColor = charData.color or Color3.fromRGB(0, 170, 255)
	local skinMaterial = Enum.Material.SmoothPlastic
	if charData.material == "Metal" then
		skinMaterial = Enum.Material.Metal
	elseif charData.material == "Neon" then
		skinMaterial = Enum.Material.Neon
	end

	-- Shirt/Pants/ShirtGraphic 제거 (아바타 의상이 BasePart 색상을 덮어쓰는 현상 방지)
	for _, item in character:GetChildren() do
		if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
			item:Destroy()
		end
	end

	-- BodyPart 색상 + 재질 변경
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = skinColor
			part.Material = skinMaterial
		end
	end

	-- HumanoidRootPart 크기로 판정 박스 조정 (닌자: 날씬, 요정: 작음 등)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and charData.bodySize then
		hrp.Size = charData.bodySize
	end
end

-- ==================== RemoteEvent 연결 ====================

function CharacterService:SetupRemoteEvents(playerDataService: any)
	-- 캐릭터 구매 요청
	RemoteEvents.BuyCharacter.OnServerEvent:Connect(function(player: Player, data: any)
		if type(data) ~= "table" or type(data.characterId) ~= "string" then
			return
		end
		if not RateLimiter.Check(player, "BuyCharacter", 2) then
			return
		end

		local characterId = data.characterId
		local charData = characterMap[characterId]
		if not charData then
			RemoteEvents.BuyCharacterResult:FireClient(player, { success = false, characterId = characterId, reason = "unknown_character" })
			return
		end

		-- 이미 보유 중
		if playerDataService:OwnsCharacter(player, characterId) then
			RemoteEvents.BuyCharacterResult:FireClient(player, { success = false, characterId = characterId, reason = "already_owned" })
			return
		end

		-- 구매 가능 타입만 허용
		local ok = false
		if charData.unlockType == "coins" then
			ok = playerDataService:SpendCoins(player, charData.unlockValue)
		elseif charData.unlockType == "gems" then
			ok = playerDataService:SpendGems(player, charData.unlockValue)
		end

		if not ok then
			RemoteEvents.BuyCharacterResult:FireClient(player, { success = false, characterId = characterId, reason = "insufficient_funds" })
			return
		end

		playerDataService:AddCharacter(player, characterId)
		playerDataService:SavePlayerData(player)
		self:SendCharacterData(player, playerDataService)

		RemoteEvents.BuyCharacterResult:FireClient(player, { success = true, characterId = characterId })
		print(`[CharacterService] {player.Name} purchased character: {characterId}`)
	end)

	-- 캐릭터 장착 요청
	RemoteEvents.EquipCharacter.OnServerEvent:Connect(function(player: Player, data: any)
		if type(data) ~= "table" or type(data.characterId) ~= "string" then
			return
		end
		if not RateLimiter.Check(player, "EquipCharacter", 1) then
			return
		end

		local characterId = data.characterId
		local ok = playerDataService:EquipCharacter(player, characterId)
		if ok then
			self:SendCharacterData(player, playerDataService)
			self:ApplyCharacterModel(player, characterId)
			print(`[CharacterService] {player.Name} equipped: {characterId}`)
		end
	end)

	-- 캐릭터 스킬 사용 요청
	RemoteEvents.CharacterSkillUse.OnServerEvent:Connect(function(player: Player)
		if not RateLimiter.Check(player, "CharacterSkillUse", 1) then
			return
		end
		self:_onSkillUse(player, playerDataService)
	end)

	-- 캐릭터 스폰 시 비주얼 적용 (리스폰 포함)
	Players.PlayerAdded:Connect(function(p: Player)
		p.CharacterAdded:Connect(function()
			-- 데이터 로드 대기 (최대 10초)
			local waited = 0
			while waited < 10 do
				local data = playerDataService:GetPlayerData(p)
				if data then
					break
				end
				task.wait(0.5)
				waited += 0.5
			end
			local equippedChar = playerDataService:GetEquippedCharacter(p)
			if equippedChar and equippedChar ~= "runner" then
				self:ApplyCharacterModel(p, equippedChar)
			end
		end)
	end)

	print("[CharacterService] RemoteEvents connected")
end

print("[CharacterService] Initialized")

return CharacterService

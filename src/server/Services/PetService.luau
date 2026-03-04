--!strict
-- Pet Service
-- 펫 구매/장착/보너스 관리

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local PetService = {}

-- 펫 ID → 데이터 맵 (빠른 조회)
local petMap: { [string]: any } = {}
for _, pet in GameConstants.PETS.LIST do
	petMap[pet.id] = pet
end

-- 펫 데이터 전송 (서버 → 클라이언트)
function PetService:SendPetData(player: Player, playerDataService: any)
	local playerData = playerDataService:GetPlayerData(player)
	if not playerData then
		return
	end
	RemoteEvents.PetData:FireClient(player, {
		ownedPets = playerData.ownedPets or { "chick" },
		equippedPet = playerData.equippedPet or "chick",
	})
end

-- 현재 장착된 펫 데이터 가져오기
local function _getEquippedPetData(player: Player, playerDataService: any): any?
	local petId = playerDataService:GetEquippedPet(player)
	return petMap[petId]
end

-- 코인 배율 (1.0 + coinBonus)
function PetService:GetCoinMultiplier(player: Player, playerDataService: any): number
	local pet = _getEquippedPetData(player, playerDataService)
	if not pet then
		return 1.0
	end
	return 1.0 + (pet.coinBonus or 0)
end

-- 자석 추가 범위 (stud)
function PetService:GetMagnetBonus(player: Player, playerDataService: any): number
	local pet = _getEquippedPetData(player, playerDataService)
	if not pet then
		return 0
	end
	return pet.magnetBonus or 0
end

-- 피버 지속 시간 추가 (초)
function PetService:GetFeverBonus(player: Player, playerDataService: any): number
	local pet = _getEquippedPetData(player, playerDataService)
	if not pet then
		return 0
	end
	return pet.feverBonus or 0
end

-- RemoteEvent 연결 설정
function PetService:SetupRemoteEvents(playerDataService: any)
	-- 펫 구매 요청
	RemoteEvents.PetPurchase.OnServerEvent:Connect(function(player: Player, data: any)
		if type(data) ~= "table" or type(data.petId) ~= "string" then
			return
		end
		local petId = data.petId
		local pet = petMap[petId]
		if not pet then
			RemoteEvents.PetPurchaseResult:FireClient(player, {
				success = false,
				error = "존재하지 않는 펫",
			})
			return
		end

		-- 이미 소유 중인지 확인
		if playerDataService:OwnsPet(player, petId) then
			RemoteEvents.PetPurchaseResult:FireClient(player, {
				success = false,
				error = "이미 보유 중",
			})
			return
		end

		-- 재화 차감
		local paid = false
		if pet.currency == "gems" then
			paid = playerDataService:SpendGems(player, pet.price)
		else
			paid = playerDataService:SpendCoins(player, pet.price)
		end

		if not paid then
			RemoteEvents.PetPurchaseResult:FireClient(player, {
				success = false,
				error = "코인이 부족합니다",
			})
			return
		end

		-- 펫 추가 후 자동 장착
		playerDataService:AddPet(player, petId)
		playerDataService:EquipPet(player, petId)
		playerDataService:SavePlayerData(player)

		local playerData = playerDataService:GetPlayerData(player)
		local balance = (playerData and playerData.coins) or 0

		RemoteEvents.PetPurchaseResult:FireClient(player, {
			success = true,
			petId = petId,
			newBalance = balance,
		})

		-- 최신 데이터 동기화
		self:SendPetData(player, playerDataService)
		print(`[PetService] {player.Name} purchased pet: {petId}`)
	end)

	-- 펫 장착 요청
	RemoteEvents.EquipPet.OnServerEvent:Connect(function(player: Player, data: any)
		if type(data) ~= "table" or type(data.petId) ~= "string" then
			return
		end
		local ok = playerDataService:EquipPet(player, data.petId)
		if ok then
			self:SendPetData(player, playerDataService)
			print(`[PetService] {player.Name} equipped pet: {data.petId}`)
		end
	end)

	print("[PetService] RemoteEvents connected")
end

print("[PetService] Initialized")

return PetService

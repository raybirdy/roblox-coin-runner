--!strict
-- Shop Service
-- 상점 시스템 서버 로직 (구매, 장착)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local ShopService = {}

-- 스킨 정보 가져오기
local function getSkinInfo(skinId: string): { id: string, name: string, price: number, currency: string? }?
	for _, skin in GameConstants.SHOP.SKINS do
		if skin.id == skinId then
			return skin
		end
	end
	return nil
end

-- 시작 파워업 정보 가져오기
local function getStartPowerupInfo(
	powerupId: string
): { id: string, name: string, price: number, duration: number?, uses: number? }?
	for _, powerup in GameConstants.SHOP.START_POWERUPS do
		if powerup.id == powerupId then
			return powerup
		end
	end
	return nil
end

-- 상점 구매 요청 처리
RemoteEvents.ShopPurchase.OnServerEvent:Connect(function(player: Player, data: { itemType: string, itemId: string })
	if type(data) ~= "table" then
		return
	end
	if type(data.itemType) ~= "string" then
		return
	end
	if type(data.itemId) ~= "string" then
		return
	end
	if not RateLimiter.Check(player, "ShopPurchase", 1) then
		return
	end

	local itemType = data.itemType
	local itemId = data.itemId

	print(`[ShopService] Purchase request from {player.Name}: {itemType}/{itemId}`)

	local success = false
	local errorMsg: string? = nil
	local newBalance = 0

	if itemType == "skin" then
		-- 스킨 구매
		local skinInfo = getSkinInfo(itemId)
		if not skinInfo then
			errorMsg = "invalid_item"
		elseif skinInfo.availableUntil and os.time() > skinInfo.availableUntil then
			errorMsg = "expired"
		elseif PlayerDataService:OwnsSkin(player, itemId) then
			errorMsg = "already_owned"
		elseif skinInfo.currency == "pieces" then
			-- 조각 교환 구매
			if not PlayerDataService:RedeemSkinPieces(player, itemId) then
				errorMsg = "insufficient_pieces"
			else
				success = true
				print(`[ShopService] {player.Name} redeemed skin: {itemId} with pieces`)
			end
		else
			-- 재화 종류 확인 (coins 또는 gems)
			local currency = skinInfo.currency or "coins"
			if not PlayerDataService:PurchaseSkin(player, itemId, skinInfo.price, currency) then
				if currency == "gems" then
					errorMsg = "insufficient_gems"
				else
					errorMsg = "insufficient_coins"
				end
			else
				success = true
				print(`[ShopService] {player.Name} purchased skin: {itemId} with {currency}`)
			end
		end
	elseif itemType == "start_powerup" then
		-- 시작 파워업 구매
		local powerupInfo = getStartPowerupInfo(itemId)
		if not powerupInfo then
			errorMsg = "invalid_item"
		elseif not PlayerDataService:PurchaseStartPowerup(player, itemId, powerupInfo.price) then
			errorMsg = "insufficient_coins"
		else
			success = true
			print(`[ShopService] {player.Name} purchased start powerup: {itemId}`)
		end
	elseif itemType == "revive_ticket" then
		-- 부활권 구매
		if not PlayerDataService:PurchaseReviveTicket(player, GameConstants.SHOP.REVIVE_TICKET_PRICE) then
			errorMsg = "insufficient_coins"
		else
			success = true
			print(`[ShopService] {player.Name} purchased revive ticket`)
		end
	else
		errorMsg = "invalid_item_type"
	end

	-- 현재 코인 잔액 가져오기
	local playerData = PlayerDataService:GetPlayerData(player)
	if playerData then
		newBalance = playerData.coins
	end

	-- 클라이언트에 결과 전송
	RemoteEvents.ShopPurchaseResult:FireClient(player, {
		success = success,
		itemType = itemType,
		itemId = itemId,
		newBalance = newBalance,
		error = errorMsg,
	})

	-- 플레이어 데이터 업데이트 전송
	if success and playerData then
		RemoteEvents.PlayerDataLoaded:FireClient(player, playerData)
	end
end)

-- 스킨 장착 요청 처리
RemoteEvents.EquipSkin.OnServerEvent:Connect(function(player: Player, data: { skinId: string })
	if type(data) ~= "table" then
		return
	end
	if type(data.skinId) ~= "string" then
		return
	end
	if not RateLimiter.Check(player, "EquipSkin", 1) then
		return
	end

	local skinId = data.skinId

	print(`[ShopService] Equip skin request from {player.Name}: {skinId}`)

	local success = PlayerDataService:EquipSkin(player, skinId)

	if success then
		print(`[ShopService] {player.Name} equipped skin: {skinId}`)

		-- 플레이어 데이터 업데이트 전송
		local playerData = PlayerDataService:GetPlayerData(player)
		if playerData then
			RemoteEvents.PlayerDataLoaded:FireClient(player, playerData)
		end

		-- 캐릭터 외형 변경
		ShopService:ApplySkinToCharacter(player, skinId)
	else
		warn(`[ShopService] Failed to equip skin for {player.Name}: {skinId}`)
	end
end)

-- 시작 파워업 사용 요청 처리
RemoteEvents.UseStartPowerup.OnServerEvent:Connect(function(player: Player, data: { powerupId: string })
	if type(data) ~= "table" then
		return
	end
	if type(data.powerupId) ~= "string" then
		return
	end
	if not RateLimiter.Check(player, "UseStartPowerup", 1) then
		return
	end

	local powerupId = data.powerupId

	print(`[ShopService] Use start powerup request from {player.Name}: {powerupId}`)

	local success = PlayerDataService:UseStartPowerup(player, powerupId)

	if success then
		print(`[ShopService] {player.Name} used start powerup: {powerupId}`)
	else
		warn(`[ShopService] Failed to use start powerup for {player.Name}: {powerupId}`)
	end
end)

-- 스킨 색상 정보 가져오기
local function getSkinColor(skinId: string): Color3
	for _, skin in GameConstants.SHOP.SKINS do
		if skin.id == skinId and skin.color then
			return skin.color
		end
	end
	return Color3.fromRGB(0, 170, 255) -- 기본 색상
end

-- 캐릭터에 스킨 외형 적용
function ShopService:ApplySkinToCharacter(player: Player, skinId: string)
	local character = player.Character
	if not character then
		return
	end

	local skinColor = getSkinColor(skinId)

	-- 캐릭터의 모든 BodyPart 색상 변경
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = skinColor
		end
	end

	print(`[ShopService] Applied skin '{skinId}' to {player.Name}`)
end

-- 상점 데이터 가져오기 (클라이언트 초기화용)
function ShopService:GetShopData(player: Player)
	local playerData = PlayerDataService:GetPlayerData(player)

	-- 스킨 목록 (코인/젬 재화 정보 + 시즌 정보 포함)
	local skins = {}
	for _, skin in GameConstants.SHOP.SKINS do
		table.insert(skins, {
			id = skin.id,
			name = skin.name,
			price = skin.price,
			currency = skin.currency or "coins",
			owned = playerData and PlayerDataService:OwnsSkin(player, skin.id) or skin.id == "default",
			equipped = playerData and PlayerDataService:GetEquippedSkin(player) == skin.id or skin.id == "default",
			availableUntil = skin.availableUntil,
			pieces = playerData and PlayerDataService:GetSkinPieces(player, skin.id) or 0,
			piecesRequired = GameConstants.SHOP.SEASON.SKIN_PIECES_REQUIRED,
		})
	end

	-- 시작 파워업 목록
	local startPowerups = {}
	for _, powerup in GameConstants.SHOP.START_POWERUPS do
		table.insert(startPowerups, {
			id = powerup.id,
			name = powerup.name,
			price = powerup.price,
			count = playerData and PlayerDataService:GetStartPowerupCount(player, powerup.id) or 0,
		})
	end

	-- 부활권
	local reviveTickets = {
		price = GameConstants.SHOP.REVIVE_TICKET_PRICE,
		count = playerData and PlayerDataService:GetReviveTicketCount(player) or 0,
	}

	-- 젬 상품 목록
	local gemProducts = {}
	for _, product in GameConstants.MONETIZATION.GEM_PRODUCTS do
		table.insert(gemProducts, {
			id = product.id,
			gems = product.gems,
			bonus = product.bonus or 0,
			robux = product.robux,
		})
	end

	-- 플레이어 재화 정보
	local playerCurrency = {
		coins = playerData and playerData.coins or 0,
		gems = playerData and playerData.gems or 0,
		hasVIP = playerData and playerData.hasVIP or false,
	}

	return {
		skins = skins,
		startPowerups = startPowerups,
		reviveTickets = reviveTickets,
		gemProducts = gemProducts,
		playerCurrency = playerCurrency,
	}
end

-- 상점 데이터 요청 처리
RemoteEvents.ShopDataRequest.OnServerEvent:Connect(function(player: Player)
	if not RateLimiter.Check(player, "ShopDataRequest", 1) then
		return
	end

	print(`[ShopService] Shop data request from {player.Name}`)

	local shopData = ShopService:GetShopData(player)
	RemoteEvents.ShopDataResponse:FireClient(player, shopData)
end)

-- 캐릭터 스폰 시 장착 스킨 자동 적용
Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function()
		-- 데이터 로드 대기
		task.wait(0.5)
		local equippedSkin = PlayerDataService:GetEquippedSkin(player)
		if equippedSkin and equippedSkin ~= "default" then
			ShopService:ApplySkinToCharacter(player, equippedSkin)
		end
	end)
end)

-- 이미 접속한 플레이어 처리
for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		local equippedSkin = PlayerDataService:GetEquippedSkin(player)
		if equippedSkin and equippedSkin ~= "default" then
			ShopService:ApplySkinToCharacter(player, equippedSkin)
		end
	end)
end

print("[ShopService] Initialized")

return ShopService

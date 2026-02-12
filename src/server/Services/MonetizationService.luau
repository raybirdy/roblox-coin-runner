--!strict
-- Monetization Service
-- Robux 결제 처리 (DevProduct, GamePass)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)

local MonetizationService = {}

-- 처리 완료된 구매 기록 (중복 방지)
local processedReceipts: { [string]: boolean } = {}

-- 젬 상품 정보 가져오기
local function getGemProductById(productId: string): { id: string, productId: number, gems: number, bonus: number }?
	for _, product in GameConstants.MONETIZATION.GEM_PRODUCTS do
		if product.id == productId then
			return product
		end
	end
	return nil
end

-- DevProduct ID로 상품 정보 가져오기
local function getGemProductByDevProductId(
	devProductId: number
): { id: string, productId: number, gems: number, bonus: number }?
	for _, product in GameConstants.MONETIZATION.GEM_PRODUCTS do
		if product.productId == devProductId then
			return product
		end
	end
	return nil
end

-- 젬 구매 처리 (DevProduct)
local function processGemPurchase(
	player: Player,
	product: { id: string, productId: number, gems: number, bonus: number }
): boolean
	local totalGems = product.gems + (product.bonus or 0)

	-- 젬 지급
	PlayerDataService:AddGems(player, totalGems)
	PlayerDataService:SavePlayerData(player)

	-- 클라이언트에 알림
	RemoteEvents.PurchaseGemsResult:FireClient(player, {
		success = true,
		gems = totalGems,
		productId = product.id,
	})

	-- 젬 잔액 업데이트 알림
	local currentGems = PlayerDataService:GetGems(player)
	RemoteEvents.GemsUpdated:FireClient(player, { gems = currentGems })

	-- 플레이어 데이터 전체 업데이트
	local playerData = PlayerDataService:GetPlayerData(player)
	if playerData then
		RemoteEvents.PlayerDataLoaded:FireClient(player, playerData)
	end

	print(`[MonetizationService] {player.Name} purchased {totalGems} gems (product: {product.id})`)

	return true
end

-- ProcessReceipt 콜백 (DevProduct 구매 처리)
local function processReceipt(
	receiptInfo: { PlayerId: number, PurchaseId: string, ProductId: number }
): Enum.ProductPurchaseDecision
	-- 중복 처리 방지
	local receiptKey = `{receiptInfo.PlayerId}_{receiptInfo.PurchaseId}`
	if processedReceipts[receiptKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 플레이어 찾기
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- 플레이어가 없으면 나중에 다시 처리
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 상품 정보 확인
	local product = getGemProductByDevProductId(receiptInfo.ProductId)
	if not product then
		warn(`[MonetizationService] Unknown product ID: {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 구매 처리
	local success = processGemPurchase(player, product)

	if success then
		processedReceipts[receiptKey] = true
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

-- VIP GamePass 확인
function MonetizationService:CheckVIPStatus(player: Player): boolean
	local vipGamePassId = GameConstants.MONETIZATION.VIP_GAMEPASS_ID

	-- GamePass ID가 설정되지 않은 경우 (개발 중)
	if vipGamePassId == 0 then
		-- Studio 모드에서는 기존 데이터 유지
		return PlayerDataService:HasVIP(player)
	end

	local success, hasVIP = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipGamePassId)
	end)

	if success then
		-- VIP 상태 저장
		PlayerDataService:SetVIP(player, hasVIP)
		return hasVIP
	else
		warn(`[MonetizationService] Failed to check VIP status for {player.Name}`)
		return PlayerDataService:HasVIP(player)
	end
end

-- 코인 획득 배율 가져오기 (VIP 적용)
function MonetizationService:GetCoinMultiplier(player: Player): number
	if PlayerDataService:HasVIP(player) then
		return GameConstants.MONETIZATION.VIP_BENEFITS.coinMultiplier
	end
	return 1
end

-- 젬 구매 요청 처리
RemoteEvents.PurchaseGems.OnServerEvent:Connect(function(player: Player, data: { productId: string })
	local productId = data.productId

	print(`[MonetizationService] Purchase request from {player.Name}: {productId}`)

	-- VIP GamePass 구매 요청
	if productId == "vip_gamepass" then
		local vipGamePassId = GameConstants.MONETIZATION.VIP_GAMEPASS_ID

		-- 이미 VIP 보유 중
		if PlayerDataService:HasVIP(player) then
			RemoteEvents.PurchaseGemsResult:FireClient(player, {
				success = false,
				error = "already_owned",
			})
			return
		end

		-- GamePass ID가 설정되지 않은 경우 (개발 중 테스트 모드)
		if vipGamePassId == 0 then
			print(`[MonetizationService] Test mode - granting VIP for free`)
			PlayerDataService:SetVIP(player, true)
			RemoteEvents.VIPStatusChanged:FireClient(player, { hasVIP = true })
			return
		end

		-- MarketplaceService로 GamePass 구매 프롬프트 표시
		local success, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, vipGamePassId)
		end)

		if not success then
			warn(`[MonetizationService] Failed to prompt VIP purchase: {err}`)
			RemoteEvents.PurchaseGemsResult:FireClient(player, {
				success = false,
				error = "purchase_failed",
			})
		end
		return
	end

	-- 젬 상품 구매 요청
	local product = getGemProductById(productId)
	if not product then
		RemoteEvents.PurchaseGemsResult:FireClient(player, {
			success = false,
			error = "invalid_product",
		})
		return
	end

	-- DevProduct ID가 설정되지 않은 경우 (개발 중)
	if product.productId == 0 then
		-- 테스트 모드: 무료로 젬 지급
		print(`[MonetizationService] Test mode - granting gems for free`)
		processGemPurchase(player, product)
		return
	end

	-- MarketplaceService로 구매 프롬프트 표시
	local success, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, product.productId)
	end)

	if not success then
		warn(`[MonetizationService] Failed to prompt purchase: {err}`)
		RemoteEvents.PurchaseGemsResult:FireClient(player, {
			success = false,
			error = "purchase_failed",
		})
	end
end)

-- 플레이어 입장 시 VIP 상태 확인
local function onPlayerAdded(player: Player)
	-- 데이터 로드 대기
	task.wait(1)

	-- VIP 상태 확인
	local hasVIP = MonetizationService:CheckVIPStatus(player)

	if hasVIP then
		print(`[MonetizationService] {player.Name} is a VIP member`)
		RemoteEvents.VIPStatusChanged:FireClient(player, { hasVIP = true })
	end
end

-- 플레이어 입장 이벤트 연결
Players.PlayerAdded:Connect(onPlayerAdded)

-- 이미 접속한 플레이어 처리
for _, player in Players:GetPlayers() do
	task.spawn(function()
		onPlayerAdded(player)
	end)
end

-- ProcessReceipt 콜백 등록
MarketplaceService.ProcessReceipt = processReceipt

-- GamePass 구매 완료 이벤트
MarketplaceService.PromptGamePassPurchaseFinished:Connect(
	function(player: Player, gamePassId: number, wasPurchased: boolean)
		if gamePassId == GameConstants.MONETIZATION.VIP_GAMEPASS_ID and wasPurchased then
			print(`[MonetizationService] {player.Name} purchased VIP GamePass!`)
			PlayerDataService:SetVIP(player, true)
			RemoteEvents.VIPStatusChanged:FireClient(player, { hasVIP = true })
		end
	end
)

print("[MonetizationService] Initialized")

return MonetizationService

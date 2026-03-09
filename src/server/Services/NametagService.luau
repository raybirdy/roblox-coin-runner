--!strict
-- Nametag Service
-- 이름표 아이템 구매 및 데이터 동기화

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local NametagService = {}

-- 아이템 ID → 데이터 맵
local itemMap: { [string]: any } = {}
for _, item in GameConstants.NAMETAG.ITEMS do
	itemMap[item.id] = item
end

-- 플레이어에게 이름표 데이터 전송
function NametagService:SendNametagData(player: Player, playerDataService: any)
	local nametag = playerDataService:GetNametag(player)
	RemoteEvents.NametagData:FireClient(player, nametag)
end

-- RemoteEvent 연결
function NametagService:SetupRemoteEvents(playerDataService: any)
	RemoteEvents.NametagPurchase.OnServerEvent:Connect(function(player: Player, data: any)
		if type(data) ~= "table" or type(data.itemId) ~= "string" then
			return
		end
		if not RateLimiter.Check(player, "NametagPurchase", 1) then
			return
		end

		local itemId = data.itemId
		local item = itemMap[itemId]
		if not item then
			RemoteEvents.NametagPurchaseResult:FireClient(player, {
				success = false,
				error = "invalid_item",
			})
			return
		end

		local ok = playerDataService:PurchaseNametagItem(player, itemId, item.price)
		if not ok then
			RemoteEvents.NametagPurchaseResult:FireClient(player, {
				success = false,
				error = "insufficient_coins",
			})
			return
		end

		playerDataService:SavePlayerData(player)
		local playerData = playerDataService:GetPlayerData(player)
		local newBalance = (playerData and playerData.coins) or 0

		RemoteEvents.NametagPurchaseResult:FireClient(player, {
			success = true,
			itemId = itemId,
			newBalance = newBalance,
		})

		-- 이름표 데이터 동기화
		self:SendNametagData(player, playerDataService)

		print(`[NametagService] {player.Name} purchased nametag item: {itemId}`)
	end)

	print("[NametagService] RemoteEvents connected")
end

print("[NametagService] Initialized")

return NametagService

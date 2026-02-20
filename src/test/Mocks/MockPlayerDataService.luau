-- MockPlayerDataService
-- PlayerDataService 테스트 대역 (in-memory)

local MockPlayerDataService = {}
MockPlayerDataService.__index = MockPlayerDataService

function MockPlayerDataService.new()
	local self = setmetatable({}, MockPlayerDataService)
	self._data = {} :: { [string]: any }
	self._coinsAdded = {} :: { [string]: number }
	self._gemsAdded = {} :: { [string]: number }
	self._gemsSpent = {} :: { [string]: number }
	self._saved = {} :: { [string]: boolean }
	return self
end

-- Test setup: inject player data
function MockPlayerDataService:SetPlayerData(playerName: string, data: any)
	self._data[playerName] = data
end

-- Same signatures as real PlayerDataService
function MockPlayerDataService:GetPlayerData(player: any): any?
	return self._data[player.Name]
end

function MockPlayerDataService:AddCoins(player: any, amount: number)
	local data = self._data[player.Name]
	if data then
		data.coins = (data.coins or 0) + amount
	end
	self._coinsAdded[player.Name] = (self._coinsAdded[player.Name] or 0) + amount
end

function MockPlayerDataService:AddGems(player: any, amount: number)
	local data = self._data[player.Name]
	if data then
		data.gems = (data.gems or 0) + amount
	end
	self._gemsAdded[player.Name] = (self._gemsAdded[player.Name] or 0) + amount
end

function MockPlayerDataService:SpendGems(player: any, amount: number): boolean
	local data = self._data[player.Name]
	if not data or (data.gems or 0) < amount then
		return false
	end
	data.gems -= amount
	self._gemsSpent[player.Name] = (self._gemsSpent[player.Name] or 0) + amount
	return true
end

function MockPlayerDataService:SavePlayerData(_player: any): boolean
	self._saved[_player.Name] = true
	return true
end

-- Test verification helpers
function MockPlayerDataService:GetCoinsAdded(playerName: string): number
	return self._coinsAdded[playerName] or 0
end

function MockPlayerDataService:GetGemsAdded(playerName: string): number
	return self._gemsAdded[playerName] or 0
end

function MockPlayerDataService:GetGemsSpent(playerName: string): number
	return self._gemsSpent[playerName] or 0
end

function MockPlayerDataService:WasSaved(playerName: string): boolean
	return self._saved[playerName] or false
end

function MockPlayerDataService:Reset()
	self._data = {}
	self._coinsAdded = {}
	self._gemsAdded = {}
	self._gemsSpent = {}
	self._saved = {}
end

return MockPlayerDataService

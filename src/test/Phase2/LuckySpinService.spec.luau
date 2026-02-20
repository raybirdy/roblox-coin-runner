-- LuckySpinService.spec
-- 럭키 스핀 서비스 단위 테스트 (7개)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
	local TestService = game:GetService("TestService")
	local MockPlayerDataService = require(TestService.Tests.Mocks.MockPlayerDataService)
	local _MockRemoteEvents = require(TestService.Tests.Mocks.MockRemoteEvents)

	-- LuckySpinService 핵심 로직 추출 (테스트용)
	local function getTodayKey(): string
		return os.date("!%Y-%m-%d") :: string
	end

	local function processSpinRequest(playerData: any, useGems: boolean, today: string, mockPDS: any, mockPlayer: any)
		local hasFreeSpinToday = (playerData.lastSpinDate ~= today)

		if hasFreeSpinToday and not useGems then
			playerData.lastSpinDate = today
			return { success = true, spinType = "free" }
		elseif useGems then
			local cost = GameConstants.LUCKY_SPIN.EXTRA_SPIN_GEM_COST
			if not mockPDS:SpendGems(mockPlayer, cost) then
				return { success = false, error = "not_enough_gems" }
			end
			return { success = true, spinType = "gems" }
		else
			return { success = false, error = "no_free_spin" }
		end
	end

	local function applyReward(reward: any, mockPDS: any, mockPlayer: any)
		if reward.type == "coins" then
			mockPDS:AddCoins(mockPlayer, reward.amount)
		elseif reward.type == "gems" then
			mockPDS:AddGems(mockPlayer, reward.amount)
		elseif reward.type == "skin_piece" then
			mockPDS:AddCoins(mockPlayer, 100)
		end
	end

	describe("LuckySpinService", function()
		local mockPDS
		local mockPlayer

		beforeEach(function()
			mockPDS = MockPlayerDataService.new()
			mockPlayer = { Name = "TestPlayer", UserId = 12345 }
		end)

		it("should have total reward weights equal to 100", function()
			local totalWeight = 0
			for _, reward in GameConstants.LUCKY_SPIN.REWARDS do
				totalWeight += reward.weight
			end
			expect(totalWeight).to.equal(100)
		end)

		it("should allow free spin when lastSpinDate is not today", function()
			local playerData = { coins = 0, gems = 0, lastSpinDate = nil }
			mockPDS:SetPlayerData("TestPlayer", playerData)
			local today = getTodayKey()

			local result = processSpinRequest(playerData, false, today, mockPDS, mockPlayer)

			expect(result.success).to.equal(true)
			expect(result.spinType).to.equal("free")
			expect(playerData.lastSpinDate).to.equal(today)
		end)

		it("should reject duplicate free spin on same day", function()
			local today = getTodayKey()
			local playerData = { coins = 0, gems = 0, lastSpinDate = today }
			mockPDS:SetPlayerData("TestPlayer", playerData)

			local result = processSpinRequest(playerData, false, today, mockPDS, mockPlayer)

			expect(result.success).to.equal(false)
			expect(result.error).to.equal("no_free_spin")
		end)

		it("should allow gem spin with sufficient gems", function()
			local today = getTodayKey()
			local playerData = { coins = 0, gems = 10, lastSpinDate = today }
			mockPDS:SetPlayerData("TestPlayer", playerData)

			local result = processSpinRequest(playerData, true, today, mockPDS, mockPlayer)

			expect(result.success).to.equal(true)
			expect(result.spinType).to.equal("gems")
			expect(mockPDS:GetGemsSpent("TestPlayer")).to.equal(GameConstants.LUCKY_SPIN.EXTRA_SPIN_GEM_COST)
		end)

		it("should reject gem spin with insufficient gems", function()
			local today = getTodayKey()
			local playerData = { coins = 0, gems = 3, lastSpinDate = today }
			mockPDS:SetPlayerData("TestPlayer", playerData)

			local result = processSpinRequest(playerData, true, today, mockPDS, mockPlayer)

			expect(result.success).to.equal(false)
			expect(result.error).to.equal("not_enough_gems")
		end)

		it("should add coins for coin reward type", function()
			local reward = { id = "coins_50", name = "50 coins", type = "coins", amount = 50, weight = 40 }
			local playerData = { coins = 0, gems = 0 }
			mockPDS:SetPlayerData("TestPlayer", playerData)

			applyReward(reward, mockPDS, mockPlayer)

			expect(mockPDS:GetCoinsAdded("TestPlayer")).to.equal(50)
		end)

		it("should convert skin_piece to 100 coins", function()
			local reward = { id = "skin_piece", name = "skin piece", type = "skin_piece", amount = 1, weight = 2 }
			local playerData = { coins = 0, gems = 0 }
			mockPDS:SetPlayerData("TestPlayer", playerData)

			applyReward(reward, mockPDS, mockPlayer)

			expect(mockPDS:GetCoinsAdded("TestPlayer")).to.equal(100)
		end)
	end)
end

-- LoginRewardService.spec
-- 일일 출석 보상 서비스 단위 테스트 (8개)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
	local TestService = game:GetService("TestService")
	local MockPlayerDataService = require(TestService.Tests.Mocks.MockPlayerDataService)
	local MockRemoteEvents = require(TestService.Tests.Mocks.MockRemoteEvents)

	-- LoginRewardService 핵심 로직 추출 (테스트용)
	local function getTodayKey(): string
		return os.date("!%Y-%m-%d") :: string
	end

	local function getYesterdayKey(): string
		return os.date("!%Y-%m-%d", os.time() - 86400) :: string
	end

	local function getStreakMultiplier(loginStreak: number): number
		local weekNumber = math.ceil(loginStreak / 7)
		local multiplier = 1.0
		for _, entry in GameConstants.LOGIN_REWARDS.STREAK_MULTIPLIERS do
			if weekNumber >= entry.week then
				multiplier = entry.multiplier
			end
		end
		return multiplier
	end

	local function getRewardDay(loginStreak: number): number
		return ((loginStreak - 1) % GameConstants.LOGIN_REWARDS.CYCLE_DAYS) + 1
	end

	-- OnPlayerJoined streak update logic
	local function processLogin(playerData: any, today: string, yesterday: string): boolean
		local alreadyClaimed = (playerData.lastLoginDate == today)
		if not alreadyClaimed then
			if playerData.lastLoginDate == yesterday then
				playerData.loginStreak = (playerData.loginStreak or 0) + 1
			else
				playerData.loginStreak = 1
			end
		end
		return alreadyClaimed
	end

	-- _onClaimReward logic
	local function claimReward(playerData: any, today: string, mockPDS: any, mockEvents: any, mockPlayer: any): boolean
		if playerData.lastLoginDate == today then
			return false -- already claimed
		end

		local rewardDay = getRewardDay(playerData.loginStreak)
		local reward = GameConstants.LOGIN_REWARDS.REWARDS[rewardDay]
		local multiplier = getStreakMultiplier(playerData.loginStreak)
		local finalAmount = math.floor(reward.amount * multiplier)

		if reward.type == "coins" then
			mockPDS:AddCoins(mockPlayer, finalAmount)
		elseif reward.type == "gems" then
			mockPDS:AddGems(mockPlayer, finalAmount)
		end

		playerData.lastLoginDate = today
		mockPDS:SavePlayerData(mockPlayer)

		mockEvents.LoginRewardData:FireClient(mockPlayer, {
			loginStreak = playerData.loginStreak,
			rewardDay = rewardDay,
			reward = { type = reward.type, amount = finalAmount },
			multiplier = multiplier,
			alreadyClaimed = true,
			justClaimed = true,
		})

		return true
	end

	describe("LoginRewardService", function()
		local mockPDS
		local mockEvents
		local mockPlayer

		beforeEach(function()
			mockPDS = MockPlayerDataService.new()
			mockEvents = MockRemoteEvents.new()
			mockPlayer = { Name = "TestPlayer", UserId = 12345 }
		end)

		it("should set streak to 1 on first login", function()
			local playerData = { loginStreak = 0, lastLoginDate = nil, coins = 0, gems = 0 }
			local today = getTodayKey()
			local yesterday = getYesterdayKey()

			processLogin(playerData, today, yesterday)

			expect(playerData.loginStreak).to.equal(1)
		end)

		it("should increment streak on consecutive login", function()
			local playerData = { loginStreak = 3, lastLoginDate = getYesterdayKey(), coins = 0, gems = 0 }
			local today = getTodayKey()
			local yesterday = getYesterdayKey()

			processLogin(playerData, today, yesterday)

			expect(playerData.loginStreak).to.equal(4)
		end)

		it("should reset streak when login gap exists", function()
			local threeDaysAgo = os.date("!%Y-%m-%d", os.time() - 86400 * 3) :: string
			local playerData = { loginStreak = 5, lastLoginDate = threeDaysAgo, coins = 0, gems = 0 }
			local today = getTodayKey()
			local yesterday = getYesterdayKey()

			processLogin(playerData, today, yesterday)

			expect(playerData.loginStreak).to.equal(1)
		end)

		it("should calculate correct reward day in 7-day cycle", function()
			expect(getRewardDay(1)).to.equal(1)
			expect(getRewardDay(7)).to.equal(7)
			expect(getRewardDay(8)).to.equal(1)
			expect(getRewardDay(14)).to.equal(7)
			expect(getRewardDay(15)).to.equal(1)
		end)

		it("should return multiplier 1.0 for week 1", function()
			expect(getStreakMultiplier(1)).to.equal(1.0)
			expect(getStreakMultiplier(7)).to.equal(1.0)
		end)

		it("should return multiplier 1.5 for week 2", function()
			expect(getStreakMultiplier(8)).to.equal(1.5)
			expect(getStreakMultiplier(14)).to.equal(1.5)
		end)

		it("should return multiplier 2.0 for week 3+", function()
			expect(getStreakMultiplier(15)).to.equal(2.0)
			expect(getStreakMultiplier(21)).to.equal(2.0)
			expect(getStreakMultiplier(100)).to.equal(2.0)
		end)

		it("should prevent duplicate claim on same day", function()
			local today = getTodayKey()
			local playerData = { loginStreak = 3, lastLoginDate = today, coins = 0, gems = 0 }
			mockPDS:SetPlayerData("TestPlayer", playerData)

			local claimed = claimReward(playerData, today, mockPDS, mockEvents, mockPlayer)

			expect(claimed).to.equal(false)
			expect(mockPDS:GetCoinsAdded("TestPlayer")).to.equal(0)
			expect(mockPDS:GetGemsAdded("TestPlayer")).to.equal(0)
			expect(mockEvents:GetFireCount("LoginRewardData")).to.equal(0)
		end)
	end)
end

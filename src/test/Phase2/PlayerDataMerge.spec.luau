-- PlayerDataMerge.spec
-- 플레이어 데이터 병합 로직 단위 테스트 (4개)

return function()
	-- PlayerDataService merge logic extracted for testing
	local DEFAULT_DATA = {
		coins = 0,
		gems = 0,
		highScore = 0,
		gamesPlayed = 0,
		totalDistance = 0,
		totalCoinsCollected = 0,
		tutorialCompleted = false,
		ownedSkins = { "default" },
		equippedSkin = "default",
		startPowerups = {},
		reviveTickets = 0,
		hasVIP = false,
		level = 1,
		xp = 0,
		dailyMissions = nil,
		dailyMissionDate = nil,
		completedAchievements = {},
		processedReceipts = {},
		loginStreak = 0,
		lastLoginDate = nil,
		lastSpinDate = nil,
	}

	-- Valid keys (including nil-default fields)
	local VALID_KEYS: { [string]: boolean } = {}
	for key, _ in DEFAULT_DATA do
		VALID_KEYS[key] = true
	end
	VALID_KEYS["dailyMissions"] = true
	VALID_KEYS["dailyMissionDate"] = true
	VALID_KEYS["completedAchievements"] = true
	VALID_KEYS["processedReceipts"] = true
	VALID_KEYS["lastLoginDate"] = true
	VALID_KEYS["lastSpinDate"] = true

	local function copyTable(original: any): any
		local copy = {}
		for key, value in original do
			if type(value) == "table" then
				copy[key] = copyTable(value)
			else
				copy[key] = value
			end
		end
		return copy
	end

	local function mergeWithDefaults(data: any): any
		local merged = copyTable(DEFAULT_DATA)
		for key, value in data do
			if VALID_KEYS[key] then
				merged[key] = value
			end
		end
		return merged
	end

	describe("PlayerDataMerge", function()
		it("should return default values for new player", function()
			local merged = mergeWithDefaults({})

			expect(merged.loginStreak).to.equal(0)
			expect(merged.lastLoginDate).to.equal(nil)
			expect(merged.coins).to.equal(0)
			expect(merged.gems).to.equal(0)
			expect(merged.level).to.equal(1)
			expect(merged.tutorialCompleted).to.equal(false)
		end)

		it("should preserve existing data values", function()
			local saved = { coins = 500, gems = 20, highScore = 1000 }
			local merged = mergeWithDefaults(saved)

			expect(merged.coins).to.equal(500)
			expect(merged.gems).to.equal(20)
			expect(merged.highScore).to.equal(1000)
			-- Other fields retain defaults
			expect(merged.level).to.equal(1)
			expect(merged.loginStreak).to.equal(0)
		end)

		it("should restore nullable fields", function()
			local saved = {
				lastLoginDate = "2026-02-19",
				lastSpinDate = "2026-02-18",
				loginStreak = 5,
			}
			local merged = mergeWithDefaults(saved)

			expect(merged.lastLoginDate).to.equal("2026-02-19")
			expect(merged.lastSpinDate).to.equal("2026-02-18")
			expect(merged.loginStreak).to.equal(5)
		end)

		it("should ignore unknown keys", function()
			local saved = {
				hackedField = true,
				unknownValue = 9999,
				coins = 100,
			}
			local merged = mergeWithDefaults(saved)

			expect(merged.hackedField).to.equal(nil)
			expect(merged.unknownValue).to.equal(nil)
			expect(merged.coins).to.equal(100)
		end)
	end)
end

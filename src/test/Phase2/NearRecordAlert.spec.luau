-- NearRecordAlert.spec
-- 신기록 임박 알림 단위 테스트 (5개)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
	local TestService = game:GetService("TestService")
	local MockRemoteEvents = require(TestService.Tests.Mocks.MockRemoteEvents)

	local THRESHOLD_RATIO = GameConstants.NEAR_RECORD.THRESHOLD_RATIO

	-- GameManager near-record check logic extracted for testing
	local function checkNearRecord(session: any, highScore: number, mockEvents: any, mockPlayer: any): boolean
		if session.nearRecordAlerted then
			return false
		end

		if highScore <= 0 then
			return false
		end

		if session.score / highScore >= THRESHOLD_RATIO then
			session.nearRecordAlerted = true
			mockEvents.NearRecordAlert:FireClient(mockPlayer, {
				currentScore = session.score,
				highScore = highScore,
			})
			return true
		end

		return false
	end

	-- GameManager new-record celebration logic
	local function checkNewRecord(finalScore: number, highScore: number, mockEvents: any, mockPlayer: any): boolean
		local isNewRecord = finalScore > 0 and finalScore >= highScore
		if isNewRecord then
			mockEvents.NewRecordCelebration:FireClient(mockPlayer, {
				newRecord = finalScore,
			})
		end
		return isNewRecord
	end

	describe("NearRecordAlert", function()
		local mockEvents
		local mockPlayer

		beforeEach(function()
			mockEvents = MockRemoteEvents.new()
			mockPlayer = { Name = "TestPlayer", UserId = 12345 }
		end)

		it("should fire alert when score reaches 80% of high score", function()
			local session = { score = 80, nearRecordAlerted = false }
			local highScore = 100

			local fired = checkNearRecord(session, highScore, mockEvents, mockPlayer)

			expect(fired).to.equal(true)
			expect(session.nearRecordAlerted).to.equal(true)

			local lastFired = mockEvents:GetLastFired("NearRecordAlert")
			expect(lastFired).to.be.ok()
			expect(lastFired.data.currentScore).to.equal(80)
			expect(lastFired.data.highScore).to.equal(100)
		end)

		it("should not fire alert when score is below 80%", function()
			local session = { score = 79, nearRecordAlerted = false }
			local highScore = 100

			local fired = checkNearRecord(session, highScore, mockEvents, mockPlayer)

			expect(fired).to.equal(false)
			expect(session.nearRecordAlerted).to.equal(false)
			expect(mockEvents:GetFireCount("NearRecordAlert")).to.equal(0)
		end)

		it("should fire alert only once per session", function()
			local session = { score = 90, nearRecordAlerted = true }
			local highScore = 100

			local fired = checkNearRecord(session, highScore, mockEvents, mockPlayer)

			expect(fired).to.equal(false)
			expect(mockEvents:GetFireCount("NearRecordAlert")).to.equal(0)
		end)

		it("should not fire alert when high score is 0", function()
			local session = { score = 50, nearRecordAlerted = false }
			local highScore = 0

			local fired = checkNearRecord(session, highScore, mockEvents, mockPlayer)

			expect(fired).to.equal(false)
			expect(mockEvents:GetFireCount("NearRecordAlert")).to.equal(0)
		end)

		it("should fire celebration event on new record", function()
			local finalScore = 150
			local highScore = 100

			local isNewRecord = checkNewRecord(finalScore, highScore, mockEvents, mockPlayer)

			expect(isNewRecord).to.equal(true)

			local lastFired = mockEvents:GetLastFired("NewRecordCelebration")
			expect(lastFired).to.be.ok()
			expect(lastFired.data.newRecord).to.equal(150)
		end)
	end)
end

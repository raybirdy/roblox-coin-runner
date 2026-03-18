--!strict
-- TutorialService (v3)
-- 5-step progressive tutorial system
-- Step 1: Move & Collect (Run 1)
-- Step 2: Jump (Run 2)
-- Step 3: Slide (Run 3)
-- Step 4: Powerup (Run 4)
-- Step 5: Co-op Portal (Run 5, lobby)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local TutorialService = {}

local _activeSteps: { [Player]: number? } = {}

-- Check if player still needs tutorial
function TutorialService:NeedsTutorial(playerData: any): boolean
	if not playerData or not playerData.tutorialProgress then
		return true
	end
	return playerData.tutorialProgress.currentStep <= GameConstants.TUTORIAL.TOTAL_STEPS
end

-- Get current tutorial step for this run
-- Returns step number if tutorial should run, nil otherwise
function TutorialService:GetStepForRun(playerData: any): number?
	if not self:NeedsTutorial(playerData) then
		return nil
	end

	local progress = playerData.tutorialProgress
	local currentStep = progress.currentStep
	local stepConfig = GameConstants.TUTORIAL.STEPS[currentStep]

	if not stepConfig then
		return nil
	end

	-- Step 5 is lobby-only, don't trigger during runs
	if currentStep == 5 then
		return nil
	end

	-- Check if this run matches the step's trigger
	local gamesPlayed = playerData.gamesPlayed or 0
	if gamesPlayed + 1 >= stepConfig.triggerRun then
		return currentStep
	end

	return nil
end

-- Check if lobby step should trigger
function TutorialService:GetLobbyStep(playerData: any): number?
	if not self:NeedsTutorial(playerData) then
		return nil
	end

	local progress = playerData.tutorialProgress
	if progress.currentStep == 5 then
		local gamesPlayed = playerData.gamesPlayed or 0
		if gamesPlayed >= GameConstants.TUTORIAL.STEPS[5].triggerRun - 1 then
			return 5
		end
	end

	return nil
end

-- Complete a tutorial step
function TutorialService:CompleteStep(player: Player, stepNumber: number, PlayerDataService: any, AnalyticsService: any?)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData or not playerData.tutorialProgress then
		return
	end

	local progress = playerData.tutorialProgress
	if progress.currentStep ~= stepNumber then
		warn(`[TutorialService] Step mismatch: expected {progress.currentStep}, got {stepNumber}`)
		return
	end

	-- Mark step as completed
	table.insert(progress.completedSteps, stepNumber)
	progress.currentStep = stepNumber + 1
	progress.lastStepRunId = playerData.gamesPlayed or 0

	-- Save progress
	PlayerDataService:SetTutorialProgress(player, progress)

	-- Track analytics
	if AnalyticsService then
		AnalyticsService:Track(player, "tutorial_step", {
			step = stepNumber,
			stepId = GameConstants.TUTORIAL.STEPS[stepNumber] and GameConstants.TUTORIAL.STEPS[stepNumber].id or "unknown",
			action = "complete",
		})
	end

	-- Check if all steps done
	if progress.currentStep > GameConstants.TUTORIAL.TOTAL_STEPS then
		print(`[TutorialService] Player {player.Name} completed all tutorial steps`)
	else
		print(`[TutorialService] Player {player.Name} completed step {stepNumber}, next: {progress.currentStep}`)
	end

	_activeSteps[player] = nil
end

-- Skip all tutorial steps
function TutorialService:SkipTutorial(player: Player, PlayerDataService: any, AnalyticsService: any?)
	local playerData = PlayerDataService:GetPlayerData(player)
	if not playerData then
		return
	end

	local progress = {
		currentStep = 6,
		completedSteps = {1, 2, 3, 4, 5},
		skipped = true,
		lastStepRunId = playerData.gamesPlayed or 0,
	}

	PlayerDataService:SetTutorialProgress(player, progress)

	-- Track analytics
	if AnalyticsService then
		AnalyticsService:Track(player, "tutorial_step", {
			step = playerData.tutorialProgress and playerData.tutorialProgress.currentStep or 1,
			action = "skip",
		})
	end

	_activeSteps[player] = nil
	print(`[TutorialService] Player {player.Name} skipped tutorial`)
end

-- Mark a step as active (for tracking)
function TutorialService:SetActiveStep(player: Player, step: number)
	_activeSteps[player] = step
end

-- Get active step
function TutorialService:GetActiveStep(player: Player): number?
	return _activeSteps[player]
end

-- Setup RemoteEvent handlers
function TutorialService:SetupRemoteEvents(PlayerDataService: any, AnalyticsService: any?)
	-- Step completion from client
	RemoteEvents.TutorialStepComplete.OnServerEvent:Connect(function(player: Player, stepNumber: number)
		if not RateLimiter.Check(player, "TutorialStepComplete", 1) then
			return
		end

		if type(stepNumber) ~= "number" or stepNumber < 1 or stepNumber > GameConstants.TUTORIAL.TOTAL_STEPS then
			return
		end

		self:CompleteStep(player, stepNumber, PlayerDataService, AnalyticsService)
	end)

	-- Skip from client
	RemoteEvents.TutorialSkip.OnServerEvent:Connect(function(player: Player)
		if not RateLimiter.Check(player, "TutorialSkip", 1) then
			return
		end

		self:SkipTutorial(player, PlayerDataService, AnalyticsService)
	end)

	print("[TutorialService] RemoteEvents initialized (v3 5-step)")
end

-- Cleanup on player leave
function TutorialService:OnPlayerRemoving(player: Player)
	_activeSteps[player] = nil
end

return TutorialService

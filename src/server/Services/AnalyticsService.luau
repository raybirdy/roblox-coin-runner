--!strict
-- AnalyticsService
-- Server-side analytics event tracking (v3)
-- Uses Roblox AnalyticsService for event dispatch
-- Does NOT use DataStore

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsServiceRoblox = game:GetService("AnalyticsService")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local RateLimiter = require(ReplicatedStorage.Shared.Utils.RateLimiter)

local AnalyticsService = {}

-- Whitelist of valid event names
local VALID_EVENTS: { [string]: boolean } = {
	session_start = true,
	session_end = true,
	run_start = true,
	run_end = true,
	coin_earned = true,
	purchase = true,
	coop_match = true,
	battle_pass_purchase = true,
	tutorial_step = true,
}

-- Track an analytics event (server-side)
function AnalyticsService:Track(player: Player, eventName: string, data: { [string]: any }?)
	if not VALID_EVENTS[eventName] then
		warn(`[AnalyticsService] Invalid event name: {eventName}`)
		return
	end

	local eventData = data or {}
	eventData.userId = player.UserId
	eventData.timestamp = os.time()

	-- Dispatch to Roblox AnalyticsService (wrapped in pcall for safety)
	local ok, err = pcall(function()
		AnalyticsServiceRoblox:LogCustomEvent(player, eventName, 1, eventData)
	end)

	if not ok then
		warn(`[AnalyticsService] Failed to log event '{eventName}': {err}`)
	end
end

-- Setup RemoteEvent listener for client-side events
function AnalyticsService:SetupRemoteEvents()
	RemoteEvents.AnalyticsTrack.OnServerEvent:Connect(function(player: Player, eventName: string, data: { [string]: any }?)
		-- Rate limit: max 2 events per second per player
		if not RateLimiter.Check(player, "AnalyticsTrack", 2) then
			return
		end

		-- Only allow specific client-originated events
		if eventName ~= "tutorial_step" then
			warn(`[AnalyticsService] Client attempted unauthorized event: {eventName}`)
			return
		end

		self:Track(player, eventName, data)
	end)

	print("[AnalyticsService] RemoteEvent listener initialized")
end

-- Initialize service
function AnalyticsService:Init()
	self:SetupRemoteEvents()
	print("[AnalyticsService] Initialized")
end

return AnalyticsService

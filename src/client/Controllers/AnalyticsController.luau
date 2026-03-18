--!strict
-- AnalyticsController
-- Client-side analytics helper (v3)
-- Fires events to server via RemoteEvent for client-originated events

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local AnalyticsController = {}
AnalyticsController.__index = AnalyticsController

function AnalyticsController.new()
	local self = setmetatable({}, AnalyticsController)
	return self
end

-- Track a client-originated event (sends to server for validation)
function AnalyticsController:Track(eventName: string, data: { [string]: any }?)
	local ok, err = pcall(function()
		RemoteEvents.AnalyticsTrack:FireServer(eventName, data or {})
	end)

	if not ok then
		warn(`[AnalyticsController] Failed to send event '{eventName}': {err}`)
	end
end

function AnalyticsController:Init()
	print("[AnalyticsController] Initialized")
end

function AnalyticsController:Destroy()
	-- No connections to clean up
end

return AnalyticsController

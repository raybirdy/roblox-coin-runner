--!strict
-- Rate Limiter
-- Per-player rate limiting for RemoteEvent handlers

local RateLimiter = {}

-- Per-player cooldown tracking: { [eventName]: { [Player]: lastCallTime } }
local cooldowns: { [string]: { [Player]: number } } = {}

-- Check if a player can call this event (returns true if allowed)
function RateLimiter.Check(player: Player, eventName: string, cooldownTime: number): boolean
	if not cooldowns[eventName] then
		cooldowns[eventName] = {}
	end

	local now = tick()
	local lastCall = cooldowns[eventName][player]

	if lastCall and (now - lastCall) < cooldownTime then
		return false -- Rate limited
	end

	cooldowns[eventName][player] = now
	return true
end

-- Clean up player data when they leave
function RateLimiter.CleanupPlayer(player: Player)
	for _, playerCooldowns in cooldowns do
		playerCooldowns[player] = nil
	end
end

return RateLimiter

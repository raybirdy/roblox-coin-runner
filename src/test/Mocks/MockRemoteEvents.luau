-- MockRemoteEvents
-- RemoteEvents 테스트 대역 (FireClient 호출 기록)

local MockRemoteEvents = {}
MockRemoteEvents.__index = MockRemoteEvents

function MockRemoteEvents.new()
	local self = setmetatable({}, MockRemoteEvents)
	self._lastFired = {} :: { [string]: any }
	self._allFired = {} :: { [string]: { any } }

	-- Phase 2 event names
	local eventNames = {
		"LoginRewardData",
		"LoginRewardClaim",
		"SpinRequest",
		"SpinResult",
		"PlayerDataLoaded",
		"NearRecordAlert",
		"NewRecordCelebration",
	}

	for _, name in eventNames do
		self[name] = self:_createMockEvent(name)
	end

	return self
end

function MockRemoteEvents:_createMockEvent(eventName: string)
	local mockEvent = {}
	local parent = self

	function mockEvent.FireClient(_self: any, player: any, data: any)
		parent._lastFired[eventName] = { player = player, data = data }
		if not parent._allFired[eventName] then
			parent._allFired[eventName] = {}
		end
		table.insert(parent._allFired[eventName], { player = player, data = data })
	end

	-- Mock OnServerEvent (no-op for tests)
	mockEvent.OnServerEvent = {
		Connect = function(_self: any, _callback: any) end,
	}

	return mockEvent
end

-- Test verification helpers
function MockRemoteEvents:GetLastFired(eventName: string): any?
	return self._lastFired[eventName]
end

function MockRemoteEvents:GetAllFired(eventName: string): { any }
	return self._allFired[eventName] or {}
end

function MockRemoteEvents:GetFireCount(eventName: string): number
	return #(self._allFired[eventName] or {})
end

function MockRemoteEvents:Reset()
	self._lastFired = {}
	self._allFired = {}
end

return MockRemoteEvents

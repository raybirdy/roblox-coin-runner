--!strict
-- GhostController
-- Ghost Racing client: renders a translucent ghost that replays a friend's best run
-- using an action sequence (jump / slide events at recorded timestamps)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)
local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)

local GhostController = {}
GhostController.__index = GhostController

local _localPlayer = Players.LocalPlayer

-- Ghost state
local _ghostModel: Model? = nil
local _ghostRoot: BasePart? = nil
local _ghostRunning: boolean = false
local _ghostData: any = nil -- { name, score, actions, runDuration }
local _ghostRunTime: number = 0
local _actionIndex: number = 1
local _ghostLoopConnection: RBXScriptConnection? = nil

-- Recording state for the local player's current run
local _isRecording: boolean = false
local _runStartTime: number = 0

export type GhostController = typeof(setmetatable({} :: {}, GhostController))

function GhostController.new(): GhostController
	local self = setmetatable({}, GhostController)
	return self
end

-- Init: wire up RemoteEvent listener
function GhostController:Init()
	-- Receive ghost data from server (fired in response to RequestGhostData)
	RemoteEvents.GhostData.OnClientEvent:Connect(function(ghostInfo: any)
		if ghostInfo and type(ghostInfo) == "table" then
			_ghostData = ghostInfo
			self:_spawnGhost()
		else
			-- No friend ghost available — clear any previous ghost
			self:_despawnGhost()
		end
	end)
end

-- Called when a new run begins (by the GameStart handler in init.client.luau)
function GhostController:OnRunStart()
	-- Request best friend ghost from server
	RemoteEvents.RequestGhostData:FireServer()

	-- Begin recording this run's actions
	_isRecording = true
	_runStartTime = os.clock()
end

-- Called when a run ends
function GhostController:OnRunEnd()
	_isRecording = false
	self:_despawnGhost()
end

-- Record a local player action and send to server for persistence
-- action: "jump" | "double_jump" | "slide"
function GhostController:RecordAction(action: string)
	if not _isRecording then
		return
	end
	local runTime = os.clock() - _runStartTime
	RemoteEvents.RecordGhostAction:FireServer(action, runTime)
end

-- ── Internal ────────────────────────────────────────────────────────────────

function GhostController:_spawnGhost()
	self:_despawnGhost()
	if not _ghostData then
		return
	end

	local ghost = Instance.new("Model")
	ghost.Name = "GhostRunner"

	-- Root part (the ghost "body")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = GameConstants.PLAYER.SIZE
	root.Transparency = GameConstants.GHOST.TRANSPARENCY
	root.Color = Color3.fromRGB(100, 180, 255)
	root.Material = Enum.Material.Neon
	root.Anchored = false
	root.CanCollide = false
	root.CastShadow = false
	root.Parent = ghost

	-- Invisible humanoid (keeps the model valid; no walk/jump physics)
	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.Parent = ghost

	-- Nametag billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GhostNametag"
	billboard.Size = UDim2.new(0, 160, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = root

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = "Ghost: " .. tostring(_ghostData.name or "???")
	nameLabel.Parent = billboard

	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Size = UDim2.new(1, 0, 0.4, 0)
	scoreLabel.Position = UDim2.new(0, 0, 0.6, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	scoreLabel.TextSize = 11
	scoreLabel.Font = Enum.Font.Gotham
	scoreLabel.Text = "Best: " .. tostring(_ghostData.score or 0)
	scoreLabel.Parent = billboard

	ghost.PrimaryPart = root
	ghost.Parent = workspace

	_ghostModel = ghost
	_ghostRoot = root
	_ghostRunTime = 0
	_actionIndex = 1
	_ghostRunning = true

	-- Place ghost at the player's start position, offset slightly in Z
	local character = _localPlayer.Character
	if character then
		local playerRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if playerRoot then
			root.CFrame = playerRoot.CFrame * CFrame.new(0, 0, -3)
		end
	end

	self:_startGhostLoop()
	print(`[GhostController] Ghost spawned for friend: {_ghostData.name}`)
end

function GhostController:_despawnGhost()
	_ghostRunning = false

	if _ghostLoopConnection then
		_ghostLoopConnection:Disconnect()
		_ghostLoopConnection = nil
	end

	if _ghostModel then
		_ghostModel:Destroy()
		_ghostModel = nil
	end

	_ghostRoot = nil
	_ghostData = nil
end

function GhostController:_startGhostLoop()
	local loopStart = os.clock()

	-- Disconnect any previous loop before creating a new one
	if _ghostLoopConnection then
		_ghostLoopConnection:Disconnect()
		_ghostLoopConnection = nil
	end

	_ghostLoopConnection = RunService.Heartbeat:Connect(function(dt: number)
		if not _ghostRunning then
			return
		end

		local root = _ghostRoot
		if not root or not root.Parent then
			self:_despawnGhost()
			return
		end

		_ghostRunTime = os.clock() - loopStart

		-- Stop ghost once the recorded run duration has elapsed
		local runDuration = (_ghostData and _ghostData.runDuration) or 60
		if _ghostRunTime > runDuration then
			self:_despawnGhost()
			return
		end

		-- Move ghost forward at approximately the same speed the player would have
		-- using the same ramp formula as PlayerController
		local approxSpeed = GameConstants.PHYSICS.SPEED_MIN
			+ (GameConstants.PHYSICS.SPEED_MAX - GameConstants.PHYSICS.SPEED_MIN)
				* math.min(_ghostRunTime / GameConstants.PHYSICS.SPEED_RAMP_TIME, 1)

		root.CFrame = root.CFrame * CFrame.new(approxSpeed * dt, 0, 0)

		-- Replay recorded actions at the correct timestamps
		local actions = (_ghostData and _ghostData.actions) or {}
		while _actionIndex <= #actions do
			local nextAction = actions[_actionIndex]
			if nextAction and _ghostRunTime >= (nextAction.time :: number) then
				self:_playGhostAction(nextAction.action :: string)
				_actionIndex += 1
			else
				break
			end
		end
	end)
end

function GhostController:_playGhostAction(action: string)
	local root = _ghostRoot
	if not root or not root.Parent then
		return
	end

	if action == "jump" or action == "double_jump" then
		-- Apply a brief upward impulse to mimic the jump arc
		local attachment = Instance.new("Attachment")
		attachment.Parent = root

		local force = Instance.new("LinearVelocity")
		force.Attachment0 = attachment
		force.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
		force.LineDirection = Vector3.new(0, 1, 0)
		force.LineVelocity = GameConstants.PHYSICS.JUMP_POWER
		force.MaxForce = 100000
		force.Parent = root

		task.delay(0.15, function()
			if force.Parent then
				force:Destroy()
			end
			if attachment.Parent then
				attachment:Destroy()
			end
		end)

	elseif action == "slide" then
		-- Shrink the ghost briefly to show the slide posture
		local originalSize = root.Size
		root.Size = GameConstants.PLAYER.SLIDE_SIZE
		task.delay(GameConstants.PHYSICS.SLIDE_DURATION, function()
			if root.Parent then
				root.Size = originalSize
			end
		end)
	end
end

return GhostController

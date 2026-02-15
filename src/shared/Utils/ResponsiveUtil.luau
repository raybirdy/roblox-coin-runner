--!strict
-- ResponsiveUtil
-- ViewportSize-based responsive UI helper

local Workspace = game:GetService("Workspace")

local ResponsiveUtil = {}

-- Reference resolution (1920x1080)
local REFERENCE_WIDTH = 1920
local REFERENCE_HEIGHT = 1080

-- Get current viewport size
local function getViewportSize(): Vector2
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(REFERENCE_WIDTH, REFERENCE_HEIGHT)
end

-- Get scale factor relative to reference resolution
function ResponsiveUtil.getScaleFactor(): number
	local viewport = getViewportSize()
	local scaleX = viewport.X / REFERENCE_WIDTH
	local scaleY = viewport.Y / REFERENCE_HEIGHT
	return math.min(scaleX, scaleY)
end

-- Create a clamped responsive size (max ratio relative to screen)
function ResponsiveUtil.clampedSize(baseW: number, baseH: number, maxWRatio: number, maxHRatio: number): UDim2
	local viewport = getViewportSize()
	local maxW = viewport.X * maxWRatio
	local maxH = viewport.Y * maxHRatio
	local w = math.min(baseW, maxW)
	local h = math.min(baseH, maxH)
	return UDim2.new(0, w, 0, h)
end

-- Create a centered position for a clamped size
function ResponsiveUtil.clampedPosition(baseW: number, baseH: number, maxWRatio: number, maxHRatio: number): UDim2
	local viewport = getViewportSize()
	local maxW = viewport.X * maxWRatio
	local maxH = viewport.Y * maxHRatio
	local w = math.min(baseW, maxW)
	local h = math.min(baseH, maxH)
	return UDim2.new(0.5, -w / 2, 0.5, -h / 2)
end

-- Scale a pixel offset by viewport ratio
function ResponsiveUtil.scaledOffset(px: number): number
	local scale = ResponsiveUtil.getScaleFactor()
	return math.round(px * scale)
end

-- Scale text size with a minimum bound
function ResponsiveUtil.scaledTextSize(base: number, min: number): number
	local scale = ResponsiveUtil.getScaleFactor()
	return math.max(math.round(base * scale), min)
end

-- Register callback when viewport changes
function ResponsiveUtil.onViewportChanged(callback: (Vector2) -> ()): RBXScriptConnection
	local camera = Workspace.CurrentCamera
	if camera then
		return camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			callback(camera.ViewportSize)
		end)
	end
	-- Fallback: return a dummy connection
	local event = Instance.new("BindableEvent")
	return event.Event:Connect(function() end)
end

-- Get current viewport size (public)
function ResponsiveUtil.getViewportSize(): Vector2
	return getViewportSize()
end

return ResponsiveUtil

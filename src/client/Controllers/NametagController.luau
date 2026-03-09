--!strict
-- Nametag Controller
-- 캐릭터 머리 위 이름표 표시 (색상/글꼴/프레임 커스텀)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local NametagController = {}
NametagController.__index = NametagController

export type NametagController = typeof(setmetatable(
	{} :: {
		_player: Player,
		_nametagData: { color: string?, font: string?, frame: string? },
		_billboard: BillboardGui?,
	},
	NametagController
))

-- 이름표 색상 아이템 ID → Color3 맵
local colorMap: { [string]: Color3 } = {}
for _, item in GameConstants.NAMETAG.ITEMS do
	if item.category == "color" and item.color then
		colorMap[item.id] = item.color
	end
end

-- 글꼴 아이템 ID → Enum.Font 맵
local fontMap: { [string]: Enum.Font } = {
	font_bold = Enum.Font.GothamBold,
	font_retro = Enum.Font.Code,
}

function NametagController.new(player: Player): NametagController
	local self = setmetatable({
		_player = player,
		_nametagData = {},
		_billboard = nil,
	}, NametagController)

	-- 이름표 데이터 수신
	RemoteEvents.NametagData.OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			self._nametagData = data
			self:_rebuildBillboard()
		end
	end)

	-- 캐릭터 스폰 시 이름표 재부착
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		self:_rebuildBillboard()
	end)

	return self
end

-- BillboardGui 생성 또는 갱신
function NametagController:_rebuildBillboard()
	local character = self._player.Character
	if not character then
		return
	end

	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	-- 기존 이름표 제거
	local existing = head:FindFirstChild("NametagBillboard")
	if existing then
		existing:Destroy()
	end

	local data = self._nametagData
	-- 아이템이 하나도 없으면 표시하지 않음
	if not data.color and not data.font and not data.frame then
		return
	end

	-- BillboardGui 생성
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NametagBillboard"
	billboard.Size = UDim2.fromOffset(160, 32)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 40
	billboard.Parent = head
	self._billboard = billboard

	-- 프레임 배경 (frame 아이템 구매 시 테두리)
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundTransparency = if data.frame then 0.3 else 1
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	if data.frame then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = if data.frame == "frame_star"
			then Color3.fromRGB(255, 215, 0)
			else Color3.fromRGB(255, 120, 180)
		stroke.Parent = bg

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = bg
	end

	-- 이름 텍스트
	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = self._player.DisplayName
	label.TextScaled = true
	label.Font = (data.font and fontMap[data.font]) or Enum.Font.Gotham
	label.TextColor3 = (data.color and colorMap[data.color]) or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.Parent = bg
end

-- 정리
function NametagController:Destroy()
	if self._billboard then
		self._billboard:Destroy()
		self._billboard = nil
	end
end

return NametagController

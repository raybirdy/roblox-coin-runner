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
		_nametagData: { color: string?, font: string?, frame: string?, badge: string? },
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
	font_bold    = Enum.Font.GothamBold,
	font_retro   = Enum.Font.Code,
	font_pixel   = Enum.Font.RobotoMono,
	font_bubble  = Enum.Font.Cartoon,
	font_elegant = Enum.Font.Merriweather,
}

-- 프레임 아이템 ID → 테두리 색상 맵
local frameColorMap: { [string]: Color3 } = {
	frame_star      = Color3.fromRGB(255, 215, 0),
	frame_heart     = Color3.fromRGB(255, 120, 180),
	frame_crown     = Color3.fromRGB(255, 200, 50),
	frame_cloud     = Color3.fromRGB(180, 220, 255),
	frame_lightning = Color3.fromRGB(255, 240, 60),
	frame_diamond   = Color3.fromRGB(100, 220, 255),
	frame_fire      = Color3.fromRGB(255, 90, 20),
	frame_galaxy    = Color3.fromRGB(150, 80, 255),
	frame_sakura    = Color3.fromRGB(255, 180, 200),
	frame_rainbow   = Color3.fromRGB(160, 255, 120),
}

-- 뱃지 아이템 ID → 배지 아이콘 텍스트 맵
local badgeIconMap: { [string]: string } = {
	badge_speedstar  = "★",
	badge_coinmaster = "◆",
	badge_feverking  = "♛",
	badge_coinhunter = "✦",
	badge_survivor   = "⚑",
}

-- 뱃지 해금 조건 텍스트 맵 (잠금 상태 표시용)
local badgeUnlockDescMap: { [string]: string } = {}
for _, item in GameConstants.NAMETAG.ITEMS do
	if item.category == "badge" and item.unlockDesc then
		badgeUnlockDescMap[item.id] = item.unlockDesc
	end
end

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
	if not data.color and not data.font and not data.frame and not data.badge then
		return
	end

	-- BillboardGui 생성 (뱃지 보유 시 세로 크기 확장)
	local hasBadge = data.badge ~= nil
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NametagBillboard"
	billboard.Size = UDim2.fromOffset(160, if hasBadge then 44 else 32)
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
		stroke.Color = frameColorMap[data.frame] or Color3.fromRGB(255, 255, 255)
		stroke.Parent = bg

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = bg
	end

	-- 뱃지 아이콘 + 이름 레이아웃
	if hasBadge then
		-- 뱃지 아이콘 (상단 작게)
		local badgeLabel = Instance.new("TextLabel")
		badgeLabel.Name = "BadgeLabel"
		badgeLabel.Size = UDim2.new(1, 0, 0, 14)
		badgeLabel.Position = UDim2.fromOffset(0, 0)
		badgeLabel.BackgroundTransparency = 1
		-- 뱃지 이름 찾기
		local badgeDisplayText = badgeIconMap[data.badge] or "◉"
		for _, item in GameConstants.NAMETAG.ITEMS do
			if item.id == data.badge then
				badgeDisplayText = (badgeIconMap[data.badge] or "◉") .. " " .. item.name
				break
			end
		end
		badgeLabel.Text = badgeDisplayText
		badgeLabel.TextScaled = true
		badgeLabel.Font = Enum.Font.GothamBold
		badgeLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
		badgeLabel.TextStrokeTransparency = 0.4
		badgeLabel.Parent = bg

		-- 이름 텍스트 (하단)
		local label = Instance.new("TextLabel")
		label.Name = "NameLabel"
		label.Size = UDim2.new(1, 0, 0, 24)
		label.Position = UDim2.new(0, 0, 0, 16)
		label.BackgroundTransparency = 1
		label.Text = self._player.DisplayName
		label.TextScaled = true
		label.Font = (data.font and fontMap[data.font]) or Enum.Font.Gotham
		label.TextColor3 = (data.color and colorMap[data.color]) or Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.5
		label.Parent = bg
	else
		-- 이름 텍스트 (기본 — 전체 크기)
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
end

-- 뱃지 해금 조건 텍스트 조회 (UI에서 잠금 상태 표시용)
function NametagController:GetBadgeUnlockDesc(badgeId: string): string
	return badgeUnlockDescMap[badgeId] or ""
end

-- 정리
function NametagController:Destroy()
	if self._billboard then
		self._billboard:Destroy()
		self._billboard = nil
	end
end

return NametagController

--!strict
-- Pet Controller
-- 게임 중 플레이어 머리 위에 펫 이모지 표시 (BillboardGui 부유 애니메이션)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents = require(ReplicatedStorage.Shared.RemoteEvents)
local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local PetController = {}
PetController.__index = PetController

-- 펫 ID → 이모지 맵
local petEmojiMap: { [string]: string } = {}
for _, pet in GameConstants.PETS.LIST do
	petEmojiMap[pet.id] = pet.emoji
end

-- 상태
local _equippedPet: string = "chick"
local _billboard: BillboardGui? = nil
local _floatTween: Tween? = nil
local _active: boolean = false

-- BillboardGui 생성
local function _createBillboard(emoji: string): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "PetDisplay"
	gui.Size = UDim2.fromOffset(60, 60)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 50

	local label = Instance.new("TextLabel")
	label.Name = "EmojiLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = emoji
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return gui
end

-- 부유 애니메이션 시작
local function _startFloat(root: BasePart)
	if _floatTween then
		_floatTween:Cancel()
		_floatTween = nil
	end
	if not _billboard then
		return
	end

	-- 위아래 3.5 ↔ 4.2 반복
	local function floatUp()
		_floatTween = TweenService:Create(
			_billboard :: BillboardGui,
			TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ StudsOffset = Vector3.new(0, 4.2, 0) }
		)
		_floatTween:Play()
		_floatTween.Completed:Once(function()
			if not _active then
				return
			end
			_floatTween = TweenService:Create(
				_billboard :: BillboardGui,
				TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ StudsOffset = Vector3.new(0, 3.5, 0) }
			)
			_floatTween:Play()
			_floatTween.Completed:Once(function()
				if _active then
					floatUp()
				end
			end)
		end)
	end
	floatUp()
	_ = root -- suppress unused warning
end

function PetController.new()
	local self = setmetatable({}, PetController)
	return self
end

-- 게임 시작: 캐릭터 머리 위에 펫 표시
function PetController:StartGame()
	_active = true
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local emoji = petEmojiMap[_equippedPet] or "🐤"

	_billboard = _createBillboard(emoji)
	_billboard.Parent = root

	_startFloat(root)
	print(`[PetController] Pet '{_equippedPet}' displayed`)
end

-- 게임 종료: 펫 표시 제거
function PetController:EndGame()
	_active = false
	if _floatTween then
		_floatTween:Cancel()
		_floatTween = nil
	end
	if _billboard then
		_billboard:Destroy()
		_billboard = nil
	end
end

-- 서버에서 펫 데이터 수신
RemoteEvents.PetData.OnClientEvent:Connect(function(data: any)
	if type(data) ~= "table" then
		return
	end
	_equippedPet = data.equippedPet or "chick"

	-- 게임 중이라면 이모지 업데이트
	if _active and _billboard then
		local label = _billboard:FindFirstChild("EmojiLabel") :: TextLabel?
		if label then
			label.Text = petEmojiMap[_equippedPet] or "🐤"
		end
	end
end)

print("[PetController] Initialized")

return PetController

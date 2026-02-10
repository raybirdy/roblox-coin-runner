--!strict
-- Lobby Service
-- 로비 물리 요소 생성 및 관리

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConstants = require(ReplicatedStorage.Shared.Constants.GameConstants)

local LobbyService = {}

-- 로비 요소들을 저장할 폴더
local lobbyFolder: Folder? = nil

-- 로비 초기화
function LobbyService:Initialize()
	-- 기존 로비 정리
	self:Destroy()

	-- 로비 폴더 생성
	lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = workspace

	-- 로비 바닥 생성
	self:_createFloor()

	-- 게임 시작 포탈 생성
	self:_createPortal()

	-- 타이틀 간판 생성
	self:_createTitle()

	-- 상점 부스 생성
	self:_createShop()

	-- 장식 코인 생성
	self:_createDecorationCoin()

	-- 스폰 포인트 설정
	self:_setupSpawnPoint()

	print("[LobbyService] Lobby initialized")
end

-- 로비 바닥 생성
function LobbyService:_createFloor()
	if not lobbyFolder then
		return
	end

	local floor = Instance.new("Part")
	floor.Name = "LobbyFloor"
	floor.Size = GameConstants.LOBBY.FLOOR_SIZE
	floor.Position = GameConstants.LOBBY.FLOOR_POSITION
	floor.Anchored = true
	floor.CanCollide = true
	floor.Color = Color3.fromRGB(180, 180, 180) -- 밝은 회색
	floor.Material = Enum.Material.Concrete
	floor.Parent = lobbyFolder

	-- 바닥 테두리
	local border = Instance.new("Part")
	border.Name = "FloorBorder"
	border.Size = Vector3.new(GameConstants.LOBBY.FLOOR_SIZE.X + 2, 0.5, GameConstants.LOBBY.FLOOR_SIZE.Z + 2)
	border.Position = GameConstants.LOBBY.FLOOR_POSITION - Vector3.new(0, 0.25, 0)
	border.Anchored = true
	border.CanCollide = false
	border.Color = Color3.fromRGB(255, 215, 0) -- 금색
	border.Material = Enum.Material.Neon
	border.Parent = lobbyFolder
end

-- 게임 시작 포탈 생성
function LobbyService:_createPortal()
	if not lobbyFolder then
		return
	end

	-- 포탈 프레임 (아치형)
	local portalFrame = Instance.new("Part")
	portalFrame.Name = "PortalFrame"
	portalFrame.Size = Vector3.new(GameConstants.LOBBY.PORTAL_SIZE.X, GameConstants.LOBBY.PORTAL_SIZE.Y + 2, GameConstants.LOBBY.PORTAL_SIZE.Z + 2)
	portalFrame.Position = GameConstants.LOBBY.PORTAL_POSITION
	portalFrame.Anchored = true
	portalFrame.CanCollide = false
	portalFrame.Color = Color3.fromRGB(0, 200, 0) -- 초록색
	portalFrame.Material = Enum.Material.Neon
	portalFrame.Transparency = 0.3
	portalFrame.Parent = lobbyFolder

	-- 포탈 터치 영역 (투명)
	local portalTrigger = Instance.new("Part")
	portalTrigger.Name = "PortalTrigger"
	portalTrigger.Size = GameConstants.LOBBY.PORTAL_SIZE
	portalTrigger.Position = GameConstants.LOBBY.PORTAL_POSITION
	portalTrigger.Anchored = true
	portalTrigger.CanCollide = false
	portalTrigger.Transparency = 1
	portalTrigger.Parent = lobbyFolder

	-- 포탈 파티클 효과
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "PortalParticles"
	particles.Color = ColorSequence.new(Color3.fromRGB(0, 255, 100))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 20
	particles.Speed = NumberRange.new(2, 5)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = portalFrame

	-- 포탈 텍스트
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "PortalText"
	billboardGui.Size = UDim2.new(0, 200, 0, 50)
	billboardGui.StudsOffset = Vector3.new(0, 6, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.Parent = portalFrame

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
	textLabel.TextSize = 24
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Text = "ENTER TO PLAY"
	textLabel.TextStrokeTransparency = 0.5
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.Parent = billboardGui

	-- 텍스트 애니메이션 (펄스)
	task.spawn(function()
		while portalFrame and portalFrame.Parent do
			local tween = TweenService:Create(textLabel, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				TextSize = 28,
			})
			tween:Play()
			tween.Completed:Wait()

			if not portalFrame or not portalFrame.Parent then
				break
			end

			local tween2 = TweenService:Create(textLabel, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				TextSize = 24,
			})
			tween2:Play()
			tween2.Completed:Wait()
		end
	end)
end

-- 타이틀 간판 생성
function LobbyService:_createTitle()
	if not lobbyFolder then
		return
	end

	-- 타이틀 배경
	local titleBackground = Instance.new("Part")
	titleBackground.Name = "TitleBackground"
	titleBackground.Size = Vector3.new(40, 10, 2)
	titleBackground.Position = GameConstants.LOBBY.TITLE_POSITION
	titleBackground.Anchored = true
	titleBackground.CanCollide = false
	titleBackground.Color = Color3.fromRGB(30, 30, 30)
	titleBackground.Material = Enum.Material.SmoothPlastic
	titleBackground.Parent = lobbyFolder

	-- 타이틀 텍스트
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "TitleGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.CanvasSize = Vector2.new(800, 200)
	surfaceGui.Parent = titleBackground

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- 금색
	titleLabel.TextSize = 80
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "COIN RUNNER"
	titleLabel.TextStrokeTransparency = 0.3
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.Parent = surfaceGui

	-- 네온 테두리
	local neonBorder = Instance.new("Part")
	neonBorder.Name = "TitleBorder"
	neonBorder.Size = Vector3.new(42, 12, 0.5)
	neonBorder.Position = GameConstants.LOBBY.TITLE_POSITION + Vector3.new(0, 0, -1)
	neonBorder.Anchored = true
	neonBorder.CanCollide = false
	neonBorder.Color = Color3.fromRGB(255, 215, 0)
	neonBorder.Material = Enum.Material.Neon
	neonBorder.Parent = lobbyFolder
end

-- 상점 부스 생성
function LobbyService:_createShop()
	if not lobbyFolder then
		return
	end

	-- 상점 부스
	local shopBooth = Instance.new("Part")
	shopBooth.Name = "ShopBooth"
	shopBooth.Size = Vector3.new(15, 10, 8)
	shopBooth.Position = GameConstants.LOBBY.SHOP_POSITION
	shopBooth.Anchored = true
	shopBooth.CanCollide = true
	shopBooth.Color = Color3.fromRGB(128, 0, 128) -- 보라색
	shopBooth.Material = Enum.Material.SmoothPlastic
	shopBooth.Parent = lobbyFolder

	-- 상점 터치 영역 (투명)
	local shopTrigger = Instance.new("Part")
	shopTrigger.Name = "ShopTrigger"
	shopTrigger.Size = Vector3.new(18, 12, 10)
	shopTrigger.Position = GameConstants.LOBBY.SHOP_POSITION
	shopTrigger.Anchored = true
	shopTrigger.CanCollide = false
	shopTrigger.Transparency = 1
	shopTrigger.Parent = lobbyFolder

	-- 상점 간판
	local shopSign = Instance.new("Part")
	shopSign.Name = "ShopSign"
	shopSign.Size = Vector3.new(12, 4, 1)
	shopSign.Position = GameConstants.LOBBY.SHOP_POSITION + Vector3.new(0, 8, -4)
	shopSign.Anchored = true
	shopSign.CanCollide = false
	shopSign.Color = Color3.fromRGB(255, 215, 0) -- 금색
	shopSign.Material = Enum.Material.Neon
	shopSign.Parent = lobbyFolder

	-- 상점 텍스트
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "ShopGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.CanvasSize = Vector2.new(400, 100)
	surfaceGui.Parent = shopSign

	local shopLabel = Instance.new("TextLabel")
	shopLabel.Size = UDim2.new(1, 0, 1, 0)
	shopLabel.BackgroundTransparency = 1
	shopLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	shopLabel.TextSize = 50
	shopLabel.Font = Enum.Font.GothamBold
	shopLabel.Text = "SHOP"
	shopLabel.Parent = surfaceGui
end

-- 장식 코인 생성 (회전)
function LobbyService:_createDecorationCoin()
	if not lobbyFolder then
		return
	end

	-- 대형 코인
	local coin = Instance.new("Part")
	coin.Name = "DecorationCoin"
	coin.Size = Vector3.new(8, 8, 1)
	coin.Position = Vector3.new(-70, 12, 0)
	coin.Anchored = true
	coin.CanCollide = false
	coin.Color = Color3.fromRGB(255, 215, 0) -- 금색
	coin.Material = Enum.Material.Neon
	coin.Shape = Enum.PartType.Cylinder
	coin.Orientation = Vector3.new(0, 0, 90) -- 세로로 눕히기
	coin.Parent = lobbyFolder

	-- 코인 회전 애니메이션
	task.spawn(function()
		while coin and coin.Parent do
			coin.CFrame = coin.CFrame * CFrame.Angles(0, math.rad(1), 0)
			task.wait(0.02)
		end
	end)

	-- 코인 파티클
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "CoinSparkle"
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Rate = 10
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Parent = coin
end

-- 스폰 포인트 설정
function LobbyService:_setupSpawnPoint()
	-- 기존 SpawnLocation 모두 제거 (충돌 방지)
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	-- 새 SpawnLocation 생성
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawnLocation"
	spawnLocation.Parent = workspace

	-- 로비 스폰 위치로 설정
	spawnLocation.Position = GameConstants.LOBBY.SPAWN_POSITION
	spawnLocation.Anchored = true
	spawnLocation.CanCollide = false
	spawnLocation.Transparency = 1 -- 숨김
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0 -- 즉시 스폰
end

-- 포탈 트리거 가져오기
function LobbyService:GetPortalTrigger(): BasePart?
	if not lobbyFolder then
		return nil
	end
	return lobbyFolder:FindFirstChild("PortalTrigger") :: BasePart?
end

-- 상점 트리거 가져오기
function LobbyService:GetShopTrigger(): BasePart?
	if not lobbyFolder then
		return nil
	end
	return lobbyFolder:FindFirstChild("ShopTrigger") :: BasePart?
end

-- 로비 정리
function LobbyService:Destroy()
	if lobbyFolder then
		lobbyFolder:Destroy()
		lobbyFolder = nil
	end
end

-- 로비 표시/숨김
function LobbyService:SetVisible(visible: boolean)
	if lobbyFolder then
		for _, child in lobbyFolder:GetChildren() do
			if child:IsA("BasePart") then
				child.Transparency = visible and (child.Name == "PortalTrigger" or child.Name == "ShopTrigger") and 1 or (visible and 0 or 1)
				child.CanCollide = visible
			end
		end
	end
end

print("[LobbyService] Module loaded")

return LobbyService

--!strict
-- Lobby Service
-- 로비 물리 요소 생성 및 관리 (확장: 장식물 + 동물 NPC)

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

	-- 장식물 생성
	self:_createDecorations()

	-- 동물 NPC 생성
	self:_createLobbyNPCs()

	-- 리더보드 간판 생성
	self:_createLeaderboard()

	-- 스폰 포인트 설정
	self:_setupSpawnPoint()

	print("[LobbyService] Lobby initialized with decorations, NPCs, and leaderboard")
end

-- 로비 바닥 생성
function LobbyService:_createFloor()
	if not lobbyFolder then
		return
	end

	-- 잔디 바닥
	local floor = Instance.new("Part")
	floor.Name = "LobbyFloor"
	floor.Size = GameConstants.LOBBY.FLOOR_SIZE
	floor.Position = GameConstants.LOBBY.FLOOR_POSITION
	floor.Anchored = true
	floor.CanCollide = true
	floor.Color = Color3.fromRGB(100, 180, 100) -- 잔디 초록
	floor.Material = Enum.Material.Grass
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

	-- 중앙 길 (돌 바닥)
	local path = Instance.new("Part")
	path.Name = "LobbyPath"
	path.Size = Vector3.new(GameConstants.LOBBY.FLOOR_SIZE.X - 20, 0.1, 8)
	path.Position = GameConstants.LOBBY.FLOOR_POSITION + Vector3.new(0, 0.5, 0)
	path.Anchored = true
	path.CanCollide = true
	path.Color = Color3.fromRGB(180, 180, 180)
	path.Material = Enum.Material.Cobblestone
	path.Parent = lobbyFolder
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

	-- 포탈 텍스트 간판 (SurfaceGui로 3D 공간에 표시)
	local signPart = Instance.new("Part")
	signPart.Name = "PortalSign"
	signPart.Size = Vector3.new(0.3, 2, 8)
	signPart.Position = GameConstants.LOBBY.PORTAL_POSITION + Vector3.new(-3, 7, 0)
	signPart.Color = Color3.fromRGB(20, 40, 20)
	signPart.Material = Enum.Material.SmoothPlastic
	signPart.CanCollide = false
	signPart.Anchored = true
	signPart.Parent = lobbyFolder

	-- 간판 테두리 (초록 네온)
	local signBorder = Instance.new("Part")
	signBorder.Name = "PortalSignBorder"
	signBorder.Size = Vector3.new(0.1, 2.2, 8.2)
	signBorder.Position = GameConstants.LOBBY.PORTAL_POSITION + Vector3.new(-3.15, 7, 0)
	signBorder.Color = Color3.fromRGB(0, 255, 100)
	signBorder.Material = Enum.Material.Neon
	signBorder.CanCollide = false
	signBorder.Anchored = true
	signBorder.Parent = lobbyFolder

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "PortalGui"
	surfaceGui.Face = Enum.NormalId.Left -- 플레이어 방향(-X)을 향함
	surfaceGui.CanvasSize = Vector2.new(300, 75)
	surfaceGui.Parent = signPart

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Text = "ENTER TO PLAY"
	textLabel.TextStrokeTransparency = 0
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.Parent = surfaceGui

	-- 간판 애니메이션 (네온 테두리 펄스)
	task.spawn(function()
		while signBorder and signBorder.Parent do
			local tween = TweenService:Create(signBorder, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.3,
			})
			tween:Play()
			tween.Completed:Wait()

			if not signBorder or not signBorder.Parent then
				break
			end

			local tween2 = TweenService:Create(signBorder, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0,
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
	titleBackground.Size = Vector3.new(50, 12, 2)
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
	surfaceGui.CanvasSize = Vector2.new(1000, 240)
	surfaceGui.Parent = titleBackground

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- 금색
	titleLabel.TextSize = 100
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "COIN RUNNER"
	titleLabel.TextStrokeTransparency = 0.3
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.Parent = surfaceGui

	-- 네온 테두리
	local neonBorder = Instance.new("Part")
	neonBorder.Name = "TitleBorder"
	neonBorder.Size = Vector3.new(52, 14, 0.5)
	neonBorder.Position = GameConstants.LOBBY.TITLE_POSITION + Vector3.new(0, 0, -1)
	neonBorder.Anchored = true
	neonBorder.CanCollide = false
	neonBorder.Color = Color3.fromRGB(255, 215, 0)
	neonBorder.Material = Enum.Material.Neon
	neonBorder.Parent = lobbyFolder
end

-- 상점 부스 생성 (개선된 가시성)
function LobbyService:_createShop()
	if not lobbyFolder then
		return
	end

	-- 상점 부스 (더 밝은 보라색)
	local shopBooth = Instance.new("Part")
	shopBooth.Name = "ShopBooth"
	shopBooth.Size = Vector3.new(15, 10, 8)
	shopBooth.Position = GameConstants.LOBBY.SHOP_POSITION
	shopBooth.Anchored = true
	shopBooth.CanCollide = true
	shopBooth.Color = Color3.fromRGB(180, 80, 200) -- 더 밝은 보라색
	shopBooth.Material = Enum.Material.SmoothPlastic
	shopBooth.Parent = lobbyFolder

	-- 상점 지붕 (네온 효과)
	local shopRoof = Instance.new("Part")
	shopRoof.Name = "ShopRoof"
	shopRoof.Size = Vector3.new(17, 1, 10)
	shopRoof.Position = GameConstants.LOBBY.SHOP_POSITION + Vector3.new(0, 5.5, 0)
	shopRoof.Anchored = true
	shopRoof.CanCollide = false
	shopRoof.Color = Color3.fromRGB(255, 150, 255)
	shopRoof.Material = Enum.Material.Neon
	shopRoof.Parent = lobbyFolder

	-- 상점 테두리 (금색 네온)
	local shopBorder = Instance.new("Part")
	shopBorder.Name = "ShopBorder"
	shopBorder.Size = Vector3.new(16, 10.5, 8.5)
	shopBorder.Position = GameConstants.LOBBY.SHOP_POSITION
	shopBorder.Anchored = true
	shopBorder.CanCollide = false
	shopBorder.Color = Color3.fromRGB(255, 215, 0)
	shopBorder.Material = Enum.Material.Neon
	shopBorder.Transparency = 0.7
	shopBorder.Parent = lobbyFolder

	-- 상점 터치 영역 (투명)
	local shopTrigger = Instance.new("Part")
	shopTrigger.Name = "ShopTrigger"
	shopTrigger.Size = Vector3.new(18, 12, 12)
	shopTrigger.Position = GameConstants.LOBBY.SHOP_POSITION
	shopTrigger.Anchored = true
	shopTrigger.CanCollide = false
	shopTrigger.Transparency = 1
	shopTrigger.Parent = lobbyFolder

	-- 상점 간판 배경 (검은색)
	local shopSignBg = Instance.new("Part")
	shopSignBg.Name = "ShopSignBg"
	shopSignBg.Size = Vector3.new(14, 5, 0.5)
	shopSignBg.Position = GameConstants.LOBBY.SHOP_POSITION + Vector3.new(0, 9, -5)
	shopSignBg.Anchored = true
	shopSignBg.CanCollide = false
	shopSignBg.Color = Color3.fromRGB(20, 20, 30)
	shopSignBg.Material = Enum.Material.SmoothPlastic
	shopSignBg.Parent = lobbyFolder

	-- 상점 간판 테두리 (금색 네온)
	local shopSignBorder = Instance.new("Part")
	shopSignBorder.Name = "ShopSignBorder"
	shopSignBorder.Size = Vector3.new(14.5, 5.5, 0.3)
	shopSignBorder.Position = GameConstants.LOBBY.SHOP_POSITION + Vector3.new(0, 9, -5.2)
	shopSignBorder.Anchored = true
	shopSignBorder.CanCollide = false
	shopSignBorder.Color = Color3.fromRGB(255, 215, 0)
	shopSignBorder.Material = Enum.Material.Neon
	shopSignBorder.Parent = lobbyFolder

	-- 상점 SurfaceGui (물리적 간판에 표시)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "ShopGui"
	surfaceGui.Face = Enum.NormalId.Front -- 플레이어 방향(로비 중앙)을 향함
	surfaceGui.CanvasSize = Vector2.new(280, 100)
	surfaceGui.Parent = shopSignBg

	-- 상점 텍스트
	local shopLabel = Instance.new("TextLabel")
	shopLabel.Size = UDim2.new(1, 0, 0.65, 0)
	shopLabel.Position = UDim2.new(0, 0, 0, 0)
	shopLabel.BackgroundTransparency = 1
	shopLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	shopLabel.TextScaled = true
	shopLabel.Font = Enum.Font.GothamBlack
	shopLabel.Text = "SHOP"
	shopLabel.TextStrokeTransparency = 0
	shopLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	shopLabel.Parent = surfaceGui

	-- 안내 텍스트
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.new(1, 0, 0.35, 0)
	hintLabel.Position = UDim2.new(0, 0, 0.65, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	hintLabel.TextScaled = true
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.Text = "Touch to open"
	hintLabel.Parent = surfaceGui

	-- 상점 파티클 효과
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "ShopSparkle"
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 100))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 8
	particles.Speed = NumberRange.new(2, 4)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = shopRoof
end

-- 리더보드 간판 생성
function LobbyService:_createLeaderboard()
	if not lobbyFolder then
		return
	end

	local leaderboardPos = GameConstants.LOBBY.LEADERBOARD_POSITION

	-- 리더보드 기둥 (왼쪽)
	local pillarLeft = Instance.new("Part")
	pillarLeft.Name = "LeaderboardPillarL"
	pillarLeft.Size = Vector3.new(1, 14, 1)
	pillarLeft.Position = leaderboardPos + Vector3.new(-6, 7, 0)
	pillarLeft.Anchored = true
	pillarLeft.CanCollide = true
	pillarLeft.Color = Color3.fromRGB(50, 50, 60)
	pillarLeft.Material = Enum.Material.Metal
	pillarLeft.Parent = lobbyFolder

	-- 리더보드 기둥 (오른쪽)
	local pillarRight = Instance.new("Part")
	pillarRight.Name = "LeaderboardPillarR"
	pillarRight.Size = Vector3.new(1, 14, 1)
	pillarRight.Position = leaderboardPos + Vector3.new(6, 7, 0)
	pillarRight.Anchored = true
	pillarRight.CanCollide = true
	pillarRight.Color = Color3.fromRGB(50, 50, 60)
	pillarRight.Material = Enum.Material.Metal
	pillarRight.Parent = lobbyFolder

	-- 리더보드 배경 (검은색 보드)
	local boardBackground = Instance.new("Part")
	boardBackground.Name = "LeaderboardBackground"
	boardBackground.Size = Vector3.new(12, 12, 0.5)
	boardBackground.Position = leaderboardPos + Vector3.new(0, 8, 0)
	boardBackground.Anchored = true
	boardBackground.CanCollide = false
	boardBackground.Color = Color3.fromRGB(20, 20, 30)
	boardBackground.Material = Enum.Material.SmoothPlastic
	boardBackground.Parent = lobbyFolder

	-- 리더보드 테두리 (금색 네온)
	local boardBorder = Instance.new("Part")
	boardBorder.Name = "LeaderboardBorder"
	boardBorder.Size = Vector3.new(12.5, 12.5, 0.3)
	boardBorder.Position = leaderboardPos + Vector3.new(0, 8, -0.2)
	boardBorder.Anchored = true
	boardBorder.CanCollide = false
	boardBorder.Color = Color3.fromRGB(255, 215, 0)
	boardBorder.Material = Enum.Material.Neon
	boardBorder.Parent = lobbyFolder

	-- SurfaceGui로 리더보드 내용 표시
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "LeaderboardGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.CanvasSize = Vector2.new(600, 600)
	surfaceGui.Parent = boardBackground

	-- 타이틀
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 70)
	titleLabel.Position = UDim2.new(0, 0, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = 50
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "LEADERBOARD"
	titleLabel.Parent = surfaceGui

	-- 순위 컨테이너
	local rankContainer = Instance.new("Frame")
	rankContainer.Name = "RankContainer"
	rankContainer.Size = UDim2.new(1, -40, 0, 480)
	rankContainer.Position = UDim2.new(0, 20, 0, 85)
	rankContainer.BackgroundTransparency = 1
	rankContainer.Parent = surfaceGui

	-- 10개의 순위 슬롯 미리 생성
	for i = 1, 10 do
		local rankFrame = Instance.new("Frame")
		rankFrame.Name = `Rank{i}`
		rankFrame.Size = UDim2.new(1, 0, 0, 45)
		rankFrame.Position = UDim2.new(0, 0, 0, (i - 1) * 48)
		rankFrame.BackgroundTransparency = 1
		rankFrame.Parent = rankContainer

		-- 순위별 색상
		local rankColors = {
			[1] = Color3.fromRGB(255, 215, 0), -- 금
			[2] = Color3.fromRGB(192, 192, 192), -- 은
			[3] = Color3.fromRGB(205, 127, 50), -- 동
		}
		local textColor = rankColors[i] or Color3.fromRGB(255, 255, 255)

		-- 순위 번호
		local rankLabel = Instance.new("TextLabel")
		rankLabel.Name = "RankNum"
		rankLabel.Size = UDim2.new(0, 60, 1, 0)
		rankLabel.Position = UDim2.new(0, 0, 0, 0)
		rankLabel.BackgroundTransparency = 1
		rankLabel.TextColor3 = textColor
		rankLabel.TextSize = 32
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.Text = `#{i}`
		rankLabel.TextXAlignment = Enum.TextXAlignment.Left
		rankLabel.Parent = rankFrame

		-- 이름
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.Size = UDim2.new(0, 280, 1, 0)
		nameLabel.Position = UDim2.new(0, 70, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 28
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Text = "---"
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = rankFrame

		-- 점수
		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Name = "Score"
		scoreLabel.Size = UDim2.new(0, 150, 1, 0)
		scoreLabel.Position = UDim2.new(1, -160, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		scoreLabel.TextSize = 28
		scoreLabel.Font = Enum.Font.GothamBold
		scoreLabel.Text = "0"
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Parent = rankFrame
	end

	-- 트로피 장식 (상단)
	local trophy = Instance.new("Part")
	trophy.Name = "Trophy"
	trophy.Size = Vector3.new(2, 3, 1)
	trophy.Position = leaderboardPos + Vector3.new(0, 15, -0.5)
	trophy.Anchored = true
	trophy.CanCollide = false
	trophy.Color = Color3.fromRGB(255, 215, 0)
	trophy.Material = Enum.Material.Neon
	trophy.Parent = lobbyFolder

	print("[LobbyService] Leaderboard display created")
end

-- 리더보드 트리거 가져오기
function LobbyService:GetLeaderboardGui(): SurfaceGui?
	if not lobbyFolder then
		return nil
	end
	local board = lobbyFolder:FindFirstChild("LeaderboardBackground") :: BasePart?
	if board then
		return board:FindFirstChild("LeaderboardGui") :: SurfaceGui?
	end
	return nil
end

-- 장식 코인 생성 (회전)
function LobbyService:_createDecorationCoin()
	if not lobbyFolder then
		return
	end

	-- 대형 코인 (타이틀 옆)
	local coin = Instance.new("Part")
	coin.Name = "DecorationCoin"
	coin.Size = Vector3.new(10, 10, 1.5)
	coin.Position = GameConstants.LOBBY.TITLE_POSITION + Vector3.new(-30, -5, 10)
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

-- 장식물 생성
function LobbyService:_createDecorations()
	if not lobbyFolder then
		return
	end

	local decorations = GameConstants.LOBBY.DECORATIONS

	-- 나무 생성
	for _, pos in decorations.TREES do
		self:_createTree(pos)
	end

	-- 꽃밭 생성
	for _, pos in decorations.FLOWERS do
		self:_createFlowerBed(pos)
	end

	-- 벤치 생성
	for _, pos in decorations.BENCHES do
		self:_createBench(pos)
	end

	-- 가로등 생성
	for _, pos in decorations.LAMPS do
		self:_createLamp(pos)
	end

	-- 분수대 생성
	self:_createFountain(decorations.FOUNTAIN)

	-- 풍선 생성
	for i, pos in decorations.BALLOONS do
		local colors = {
			Color3.fromRGB(255, 100, 100), -- 빨강
			Color3.fromRGB(100, 100, 255), -- 파랑
		}
		self:_createBalloon(pos, colors[i] or colors[1])
	end

	print("[LobbyService] Decorations created")
end

-- 나무 생성
function LobbyService:_createTree(position: Vector3)
	if not lobbyFolder then
		return
	end

	local treeFolder = Instance.new("Model")
	treeFolder.Name = "Tree"
	treeFolder.Parent = lobbyFolder

	-- 줄기
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(2, 8, 2)
	trunk.Position = position + Vector3.new(0, 4, 0)
	trunk.Anchored = true
	trunk.CanCollide = true
	trunk.Color = Color3.fromRGB(101, 67, 33) -- 갈색
	trunk.Material = Enum.Material.Wood
	trunk.Parent = treeFolder

	-- 잎 (구 3개로 풍성하게)
	local leafPositions = {
		Vector3.new(0, 10, 0),
		Vector3.new(-1.5, 9, 1),
		Vector3.new(1.5, 9, -1),
	}

	for _, leafPos in leafPositions do
		local leaves = Instance.new("Part")
		leaves.Name = "Leaves"
		leaves.Size = Vector3.new(6, 6, 6)
		leaves.Position = position + leafPos
		leaves.Anchored = true
		leaves.CanCollide = false
		leaves.Color = Color3.fromRGB(34, 139, 34) -- 초록
		leaves.Material = Enum.Material.Grass
		leaves.Shape = Enum.PartType.Ball
		leaves.Parent = treeFolder
	end
end

-- 꽃밭 생성
function LobbyService:_createFlowerBed(position: Vector3)
	if not lobbyFolder then
		return
	end

	local flowerColors = {
		Color3.fromRGB(255, 100, 150), -- 분홍
		Color3.fromRGB(255, 255, 100), -- 노랑
		Color3.fromRGB(255, 150, 100), -- 주황
		Color3.fromRGB(200, 100, 255), -- 보라
		Color3.fromRGB(100, 200, 255), -- 하늘
	}

	for i = 1, 8 do
		local offsetX = math.random(-3, 3)
		local offsetZ = math.random(-3, 3)

		-- 줄기
		local stem = Instance.new("Part")
		stem.Name = "FlowerStem"
		stem.Size = Vector3.new(0.2, 1.5, 0.2)
		stem.Position = position + Vector3.new(offsetX, 0.75, offsetZ)
		stem.Anchored = true
		stem.CanCollide = false
		stem.Color = Color3.fromRGB(34, 139, 34)
		stem.Material = Enum.Material.Grass
		stem.Parent = lobbyFolder

		-- 꽃
		local flower = Instance.new("Part")
		flower.Name = "Flower"
		flower.Size = Vector3.new(0.8, 0.8, 0.8)
		flower.Position = position + Vector3.new(offsetX, 1.8, offsetZ)
		flower.Anchored = true
		flower.CanCollide = false
		flower.Color = flowerColors[math.random(1, #flowerColors)]
		flower.Material = Enum.Material.Neon
		flower.Shape = Enum.PartType.Ball
		flower.Parent = lobbyFolder
	end
end

-- 벤치 생성
function LobbyService:_createBench(position: Vector3)
	if not lobbyFolder then
		return
	end

	local benchFolder = Instance.new("Model")
	benchFolder.Name = "Bench"
	benchFolder.Parent = lobbyFolder

	-- 좌석
	local seat = Instance.new("Part")
	seat.Name = "Seat"
	seat.Size = Vector3.new(5, 0.5, 2)
	seat.Position = position + Vector3.new(0, 1.5, 0)
	seat.Anchored = true
	seat.CanCollide = true
	seat.Color = Color3.fromRGB(139, 90, 43)
	seat.Material = Enum.Material.Wood
	seat.Parent = benchFolder

	-- 등받이
	local back = Instance.new("Part")
	back.Name = "Back"
	back.Size = Vector3.new(5, 2, 0.3)
	back.Position = position + Vector3.new(0, 2.75, -0.85)
	back.Anchored = true
	back.CanCollide = true
	back.Color = Color3.fromRGB(139, 90, 43)
	back.Material = Enum.Material.Wood
	back.Parent = benchFolder

	-- 다리
	for _, xOffset in { -2, 2 } do
		local leg = Instance.new("Part")
		leg.Name = "Leg"
		leg.Size = Vector3.new(0.5, 1.5, 2)
		leg.Position = position + Vector3.new(xOffset, 0.75, 0)
		leg.Anchored = true
		leg.CanCollide = true
		leg.Color = Color3.fromRGB(80, 80, 80)
		leg.Material = Enum.Material.Metal
		leg.Parent = benchFolder
	end
end

-- 가로등 생성
function LobbyService:_createLamp(position: Vector3)
	if not lobbyFolder then
		return
	end

	local lampFolder = Instance.new("Model")
	lampFolder.Name = "Lamp"
	lampFolder.Parent = lobbyFolder

	-- 기둥
	local pole = Instance.new("Part")
	pole.Name = "Pole"
	pole.Size = Vector3.new(0.5, 10, 0.5)
	pole.Position = position + Vector3.new(0, 5, 0)
	pole.Anchored = true
	pole.CanCollide = true
	pole.Color = Color3.fromRGB(50, 50, 50)
	pole.Material = Enum.Material.Metal
	pole.Parent = lampFolder

	-- 등
	local light = Instance.new("Part")
	light.Name = "Light"
	light.Size = Vector3.new(2, 2, 2)
	light.Position = position + Vector3.new(0, 10.5, 0)
	light.Anchored = true
	light.CanCollide = false
	light.Color = Color3.fromRGB(255, 255, 200)
	light.Material = Enum.Material.Neon
	light.Shape = Enum.PartType.Ball
	light.Parent = lampFolder

	-- PointLight
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 1
	pointLight.Range = 20
	pointLight.Color = Color3.fromRGB(255, 255, 200)
	pointLight.Parent = light
end

-- 분수대 생성
function LobbyService:_createFountain(position: Vector3)
	if not lobbyFolder then
		return
	end

	local fountainFolder = Instance.new("Model")
	fountainFolder.Name = "Fountain"
	fountainFolder.Parent = lobbyFolder

	-- 베이스 (원형)
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(12, 1, 12)
	base.Position = position + Vector3.new(0, 0.5, 0)
	base.Anchored = true
	base.CanCollide = true
	base.Color = Color3.fromRGB(180, 180, 180)
	base.Material = Enum.Material.Marble
	base.Shape = Enum.PartType.Cylinder
	base.Orientation = Vector3.new(0, 0, 90)
	base.Parent = fountainFolder

	-- 물 영역
	local water = Instance.new("Part")
	water.Name = "Water"
	water.Size = Vector3.new(10, 0.5, 10)
	water.Position = position + Vector3.new(0, 1.25, 0)
	water.Anchored = true
	water.CanCollide = false
	water.Color = Color3.fromRGB(100, 150, 255)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.3
	water.Shape = Enum.PartType.Cylinder
	water.Orientation = Vector3.new(0, 0, 90)
	water.Parent = fountainFolder

	-- 중앙 기둥
	local pillar = Instance.new("Part")
	pillar.Name = "Pillar"
	pillar.Size = Vector3.new(1.5, 5, 1.5)
	pillar.Position = position + Vector3.new(0, 3.5, 0)
	pillar.Anchored = true
	pillar.CanCollide = true
	pillar.Color = Color3.fromRGB(200, 200, 200)
	pillar.Material = Enum.Material.Marble
	pillar.Parent = fountainFolder

	-- 물 파티클
	local waterParticles = Instance.new("ParticleEmitter")
	waterParticles.Name = "WaterSpray"
	waterParticles.Color = ColorSequence.new(Color3.fromRGB(150, 200, 255))
	waterParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	waterParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	waterParticles.Lifetime = NumberRange.new(1, 1.5)
	waterParticles.Rate = 30
	waterParticles.Speed = NumberRange.new(8, 12)
	waterParticles.SpreadAngle = Vector2.new(10, 10)
	waterParticles.EmissionDirection = Enum.NormalId.Top
	waterParticles.Parent = pillar
end

-- 풍선 생성
function LobbyService:_createBalloon(position: Vector3, color: Color3)
	if not lobbyFolder then
		return
	end

	local balloonFolder = Instance.new("Model")
	balloonFolder.Name = "Balloon"
	balloonFolder.Parent = lobbyFolder

	-- 풍선
	local balloon = Instance.new("Part")
	balloon.Name = "Balloon"
	balloon.Size = Vector3.new(3, 4, 3)
	balloon.Position = position
	balloon.Anchored = true
	balloon.CanCollide = false
	balloon.Color = color
	balloon.Material = Enum.Material.SmoothPlastic
	balloon.Shape = Enum.PartType.Ball
	balloon.Parent = balloonFolder

	-- 끈
	local string = Instance.new("Part")
	string.Name = "String"
	string.Size = Vector3.new(0.1, 5, 0.1)
	string.Position = position - Vector3.new(0, 4.5, 0)
	string.Anchored = true
	string.CanCollide = false
	string.Color = Color3.fromRGB(200, 200, 200)
	string.Material = Enum.Material.Fabric
	string.Parent = balloonFolder

	-- 풍선 흔들림 애니메이션
	task.spawn(function()
		local originalPos = position
		local time = math.random() * math.pi * 2 -- 랜덤 시작 위치
		while balloon and balloon.Parent do
			time += 0.05
			local offsetX = math.sin(time) * 0.3
			local offsetY = math.cos(time * 0.7) * 0.2
			balloon.Position = originalPos + Vector3.new(offsetX, offsetY, 0)
			string.Position = originalPos - Vector3.new(0, 4.5, 0) + Vector3.new(offsetX * 0.5, 0, 0)
			task.wait(0.03)
		end
	end)
end

-- 동물 NPC 생성
function LobbyService:_createLobbyNPCs()
	if not lobbyFolder then
		return
	end

	local npcTypes = GameConstants.LOBBY_NPC.TYPES

	for npcId, npcData in npcTypes do
		self:_createAnimalNPC(npcId, npcData)
	end

	print("[LobbyService] Lobby NPCs created")
end

-- 동물 NPC 생성 (개별)
function LobbyService:_createAnimalNPC(npcId: string, npcData: {
	name: string,
	position: Vector3,
	color: Color3,
	message: string,
	animation: string,
})
	if not lobbyFolder then
		return
	end

	local npcFolder = Instance.new("Model")
	npcFolder.Name = "LobbyNPC_" .. npcId
	npcFolder.Parent = lobbyFolder

	local baseY = npcData.position.Y + 1

	-- 몸통
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.5, 3, 2)
	body.Position = npcData.position + Vector3.new(0, 1.5, 0)
	body.Anchored = true
	body.CanCollide = true
	body.Color = npcData.color
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = npcFolder

	-- 머리
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 2, 2)
	head.Position = npcData.position + Vector3.new(0, 3.5, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Color = npcData.color
	head.Material = Enum.Material.SmoothPlastic
	head.Shape = Enum.PartType.Ball
	head.Parent = npcFolder

	-- 눈 (왼쪽)
	local eyeL = Instance.new("Part")
	eyeL.Name = "EyeL"
	eyeL.Size = Vector3.new(0.4, 0.4, 0.2)
	eyeL.Position = npcData.position + Vector3.new(-0.4, 3.7, 0.9)
	eyeL.Anchored = true
	eyeL.CanCollide = false
	eyeL.Color = Color3.fromRGB(0, 0, 0)
	eyeL.Material = Enum.Material.SmoothPlastic
	eyeL.Shape = Enum.PartType.Ball
	eyeL.Parent = npcFolder

	-- 눈 (오른쪽)
	local eyeR = Instance.new("Part")
	eyeR.Name = "EyeR"
	eyeR.Size = Vector3.new(0.4, 0.4, 0.2)
	eyeR.Position = npcData.position + Vector3.new(0.4, 3.7, 0.9)
	eyeR.Anchored = true
	eyeR.CanCollide = false
	eyeR.Color = Color3.fromRGB(0, 0, 0)
	eyeR.Material = Enum.Material.SmoothPlastic
	eyeR.Shape = Enum.PartType.Ball
	eyeR.Parent = npcFolder

	-- 동물별 특징 추가
	if npcId == "Rabbit" then
		-- 토끼 귀
		for _, xOffset in { -0.5, 0.5 } do
			local ear = Instance.new("Part")
			ear.Name = "Ear"
			ear.Size = Vector3.new(0.4, 1.5, 0.3)
			ear.Position = npcData.position + Vector3.new(xOffset, 4.8, 0)
			ear.Anchored = true
			ear.CanCollide = false
			ear.Color = npcData.color
			ear.Material = Enum.Material.SmoothPlastic
			ear.Parent = npcFolder
		end
	elseif npcId == "Dog" then
		-- 강아지 귀 (늘어진)
		for _, xOffset in { -0.8, 0.8 } do
			local ear = Instance.new("Part")
			ear.Name = "Ear"
			ear.Size = Vector3.new(0.5, 1, 0.3)
			ear.Position = npcData.position + Vector3.new(xOffset, 3.8, 0.3)
			ear.Anchored = true
			ear.CanCollide = false
			ear.Color = Color3.fromRGB(139, 90, 43) -- 갈색
			ear.Material = Enum.Material.SmoothPlastic
			ear.Parent = npcFolder
		end
		-- 꼬리
		local tail = Instance.new("Part")
		tail.Name = "Tail"
		tail.Size = Vector3.new(0.4, 0.4, 1)
		tail.Position = npcData.position + Vector3.new(0, 1.5, -1.3)
		tail.Anchored = true
		tail.CanCollide = false
		tail.Color = npcData.color
		tail.Material = Enum.Material.SmoothPlastic
		tail.Parent = npcFolder

		-- 꼬리 흔들기 애니메이션
		task.spawn(function()
			local originalPos = tail.Position
			local time = 0
			while tail and tail.Parent do
				time += 0.15
				local offsetX = math.sin(time) * 0.3
				tail.Position = originalPos + Vector3.new(offsetX, 0, 0)
				task.wait(0.03)
			end
		end)
	elseif npcId == "Cat" then
		-- 고양이 귀 (삼각형)
		for _, xOffset in { -0.6, 0.6 } do
			local ear = Instance.new("Part")
			ear.Name = "Ear"
			ear.Size = Vector3.new(0.5, 0.7, 0.3)
			ear.Position = npcData.position + Vector3.new(xOffset, 4.5, 0)
			ear.Anchored = true
			ear.CanCollide = false
			ear.Color = npcData.color
			ear.Material = Enum.Material.SmoothPlastic
			ear.Parent = npcFolder
		end
		-- 수염
		for _, zOffset in { 0.3, -0.3 } do
			local whisker = Instance.new("Part")
			whisker.Name = "Whisker"
			whisker.Size = Vector3.new(1.5, 0.05, 0.05)
			whisker.Position = npcData.position + Vector3.new(0, 3.3, 1)
			whisker.Anchored = true
			whisker.CanCollide = false
			whisker.Color = Color3.fromRGB(200, 200, 200)
			whisker.Material = Enum.Material.SmoothPlastic
			whisker.Parent = npcFolder
		end
	elseif npcId == "Penguin" then
		-- 펭귄 배 (흰색)
		local belly = Instance.new("Part")
		belly.Name = "Belly"
		belly.Size = Vector3.new(1.8, 2.2, 0.5)
		belly.Position = npcData.position + Vector3.new(0, 1.5, 0.8)
		belly.Anchored = true
		belly.CanCollide = false
		belly.Color = Color3.fromRGB(255, 255, 255)
		belly.Material = Enum.Material.SmoothPlastic
		belly.Parent = npcFolder
		-- 부리
		local beak = Instance.new("Part")
		beak.Name = "Beak"
		beak.Size = Vector3.new(0.5, 0.3, 0.5)
		beak.Position = npcData.position + Vector3.new(0, 3.3, 1.2)
		beak.Anchored = true
		beak.CanCollide = false
		beak.Color = Color3.fromRGB(255, 165, 0)
		beak.Material = Enum.Material.SmoothPlastic
		beak.Parent = npcFolder

		-- 뒤뚱뒤뚱 애니메이션
		task.spawn(function()
			local originalPos = body.Position
			local time = 0
			while body and body.Parent do
				time += 0.08
				local offsetX = math.sin(time) * 0.15
				local rotation = math.sin(time) * 5
				body.CFrame = CFrame.new(originalPos + Vector3.new(offsetX, 0, 0)) * CFrame.Angles(0, 0, math.rad(rotation))
				task.wait(0.03)
			end
		end)
	elseif npcId == "Bear" then
		-- 곰 귀 (둥근)
		for _, xOffset in { -0.7, 0.7 } do
			local ear = Instance.new("Part")
			ear.Name = "Ear"
			ear.Size = Vector3.new(0.6, 0.6, 0.3)
			ear.Position = npcData.position + Vector3.new(xOffset, 4.4, 0)
			ear.Anchored = true
			ear.CanCollide = false
			ear.Color = npcData.color
			ear.Material = Enum.Material.SmoothPlastic
			ear.Shape = Enum.PartType.Ball
			ear.Parent = npcFolder
		end
		-- 코
		local nose = Instance.new("Part")
		nose.Name = "Nose"
		nose.Size = Vector3.new(0.5, 0.4, 0.3)
		nose.Position = npcData.position + Vector3.new(0, 3.3, 1)
		nose.Anchored = true
		nose.CanCollide = false
		nose.Color = Color3.fromRGB(0, 0, 0)
		nose.Material = Enum.Material.SmoothPlastic
		nose.Shape = Enum.PartType.Ball
		nose.Parent = npcFolder
	end

	-- 이름표 + 말풍선
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "NPCGui"
	billboardGui.Size = UDim2.new(0, 150, 0, 80)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.AlwaysOnTop = true
	billboardGui.Parent = head

	-- 이름
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.3, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 18
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = npcData.name
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Parent = billboardGui

	-- 말풍선 (처음엔 숨김)
	local speechBubble = Instance.new("TextLabel")
	speechBubble.Name = "SpeechBubble"
	speechBubble.Size = UDim2.new(1, 0, 0.7, 0)
	speechBubble.Position = UDim2.new(0, 0, 0.3, 0)
	speechBubble.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	speechBubble.BackgroundTransparency = 0.2
	speechBubble.TextColor3 = Color3.fromRGB(0, 0, 0)
	speechBubble.TextSize = 12
	speechBubble.Font = Enum.Font.Gotham
	speechBubble.Text = npcData.message
	speechBubble.TextWrapped = true
	speechBubble.Visible = false
	speechBubble.Parent = billboardGui

	-- 모서리 둥글게
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = speechBubble

	-- 터치 시 말풍선 표시
	body.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if character and character:FindFirstChild("Humanoid") then
			speechBubble.Visible = true
			task.delay(GameConstants.LOBBY_NPC.SPEECH_DURATION, function()
				if speechBubble and speechBubble.Parent then
					speechBubble.Visible = false
				end
			end)
		end
	end)

	-- 점프 애니메이션 (토끼)
	if npcData.animation == "jump" then
		task.spawn(function()
			local originalY = body.Position.Y
			while body and body.Parent do
				-- 점프 업
				local tween = TweenService:Create(body, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = body.Position + Vector3.new(0, 1.5, 0),
				})
				tween:Play()
				tween.Completed:Wait()

				if not body or not body.Parent then
					break
				end

				-- 점프 다운
				local tween2 = TweenService:Create(body, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = Vector3.new(body.Position.X, originalY, body.Position.Z),
				})
				tween2:Play()
				tween2.Completed:Wait()

				task.wait(2) -- 2초마다 점프
			end
		end)
	end

	-- 손 흔들기 애니메이션 (곰돌이) - 머리 흔들기로 대체
	if npcData.animation == "wave" then
		task.spawn(function()
			while head and head.Parent do
				local tween = TweenService:Create(head, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Orientation = Vector3.new(0, 15, 0),
				})
				tween:Play()
				tween.Completed:Wait()

				if not head or not head.Parent then
					break
				end

				local tween2 = TweenService:Create(head, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Orientation = Vector3.new(0, -15, 0),
				})
				tween2:Play()
				tween2.Completed:Wait()
			end
		end)
	end
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
		for _, child in lobbyFolder:GetDescendants() do
			if child:IsA("BasePart") then
				if child.Name == "PortalTrigger" or child.Name == "ShopTrigger" then
					child.Transparency = 1
				else
					child.Transparency = visible and 0 or 1
				end
				child.CanCollide = visible
			end
		end
	end
end

print("[LobbyService] Module loaded")

return LobbyService

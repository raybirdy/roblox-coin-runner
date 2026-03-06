--!strict
-- CutsceneCharacterBuilder
-- 컷씬용 Part 기반 3D 캐릭터 빌더 + 관절 애니메이션

local TweenService = game:GetService("TweenService")

local CutsceneCharacterBuilder = {}

-- CharacterRig type: built character with joints for animation
export type CharacterRig = {
	model: Model,
	root: Part, -- HumanoidRootPart (transparent anchor)
	head: Part,
	upperBody: Part,
	lowerBody: Part,
	leftArm: Part,
	rightArm: Part,
	-- Motor6D joints
	neck: Motor6D?,
	waist: Motor6D?,
	leftShoulder: Motor6D?,
	rightShoulder: Motor6D?,
	-- joint default C0 values for resetting
	neckC0: CFrame,
	waistC0: CFrame,
	leftShoulderC0: CFrame,
	rightShoulderC0: CFrame,
	-- character metadata
	idleStyle: string, -- "sway", "float", "stoic", "bounce"
	talkStyle: string, -- "nod", "shake", "bounce"
	role: string, -- "mentor", "villain", "ally", "hero"
}

type CharSpec = {
	headSize: Vector3,
	upperSize: Vector3,
	lowerSize: Vector3,
	armSize: Vector3,
	legSize: Vector3,
	primary: Color3,
	accent: Color3,
	idleStyle: string,
	talkStyle: string,
	role: string,
	accessories: { string },
}

-- ---------------------------------------------------------------------------
-- Character visual specs
-- ---------------------------------------------------------------------------

local CHAR_SPECS: { [string]: CharSpec } = {
	owl = {
		headSize = Vector3.new(2.4, 2.4, 2.4),
		upperSize = Vector3.new(1.0, 1.6, 0.8),
		lowerSize = Vector3.new(1.0, 0.8, 0.8),
		armSize = Vector3.new(1.6, 0.5, 0.4),
		legSize = Vector3.new(0.5, 0.9, 0.5),
		primary = Color3.fromRGB(55, 80, 140),
		accent = Color3.fromRGB(200, 220, 255),
		idleStyle = "float",
		talkStyle = "nod",
		role = "mentor",
		accessories = { "eyes" },
	},
	coin_king = {
		headSize = Vector3.new(2.2, 2.4, 2.2),
		upperSize = Vector3.new(2.0, 1.8, 1.2),
		lowerSize = Vector3.new(1.6, 1.0, 1.0),
		armSize = Vector3.new(0.7, 1.8, 0.7),
		legSize = Vector3.new(0.7, 1.1, 0.7),
		primary = Color3.fromRGB(160, 20, 20),
		accent = Color3.fromRGB(220, 170, 30),
		idleStyle = "stoic",
		talkStyle = "shake",
		role = "villain",
		accessories = { "crown" },
	},
	player = {
		headSize = Vector3.new(1.8, 1.8, 1.8),
		upperSize = Vector3.new(1.4, 1.6, 1.0),
		lowerSize = Vector3.new(1.2, 0.9, 0.9),
		armSize = Vector3.new(0.6, 1.5, 0.6),
		legSize = Vector3.new(0.6, 1.0, 0.6),
		primary = Color3.fromRGB(50, 160, 80),
		accent = Color3.fromRGB(220, 255, 220),
		idleStyle = "sway",
		talkStyle = "nod",
		role = "hero",
		accessories = {},
	},
	chichi = {
		headSize = Vector3.new(1.8, 1.8, 1.8),
		upperSize = Vector3.new(0.9, 1.2, 0.7),
		lowerSize = Vector3.new(0.9, 0.7, 0.7),
		armSize = Vector3.new(0.5, 1.1, 0.5),
		legSize = Vector3.new(0.5, 0.8, 0.5),
		primary = Color3.fromRGB(70, 140, 60),
		accent = Color3.fromRGB(160, 100, 50),
		idleStyle = "bounce",
		talkStyle = "nod",
		role = "ally",
		accessories = { "ears" },
	},
	cyberbot = {
		headSize = Vector3.new(2.0, 2.0, 2.0),
		upperSize = Vector3.new(1.5, 1.6, 1.1),
		lowerSize = Vector3.new(1.3, 0.9, 0.9),
		armSize = Vector3.new(0.7, 1.6, 0.7),
		legSize = Vector3.new(0.6, 1.0, 0.6),
		primary = Color3.fromRGB(60, 100, 180),
		accent = Color3.fromRGB(160, 200, 255),
		idleStyle = "sway",
		talkStyle = "nod",
		role = "ally",
		accessories = { "antenna", "visor" },
	},
	hamam = {
		headSize = Vector3.new(2.0, 1.8, 2.0),
		upperSize = Vector3.new(1.8, 2.0, 1.3),
		lowerSize = Vector3.new(1.5, 1.0, 1.0),
		armSize = Vector3.new(0.6, 1.3, 0.6),
		legSize = Vector3.new(0.65, 0.9, 0.65),
		primary = Color3.fromRGB(160, 110, 40),
		accent = Color3.fromRGB(220, 180, 80),
		idleStyle = "sway",
		talkStyle = "nod",
		role = "ally",
		accessories = { "turban" },
	},
	luna = {
		headSize = Vector3.new(1.8, 2.4, 1.8),
		upperSize = Vector3.new(1.0, 1.8, 0.8),
		lowerSize = Vector3.new(0.9, 0.8, 0.8),
		armSize = Vector3.new(0.5, 1.8, 0.5),
		legSize = Vector3.new(0.5, 1.0, 0.5),
		primary = Color3.fromRGB(130, 180, 230),
		accent = Color3.fromRGB(220, 240, 255),
		idleStyle = "float",
		talkStyle = "nod",
		role = "ally",
		accessories = { "crystal" },
	},
	marina = {
		headSize = Vector3.new(1.8, 1.8, 1.8),
		upperSize = Vector3.new(1.2, 1.8, 0.9),
		lowerSize = Vector3.new(1.0, 1.8, 0.7),
		armSize = Vector3.new(0.5, 1.4, 0.5),
		legSize = Vector3.new(0.0, 0.0, 0.0),
		primary = Color3.fromRGB(30, 100, 160),
		accent = Color3.fromRGB(80, 210, 200),
		idleStyle = "float",
		talkStyle = "nod",
		role = "ally",
		accessories = {},
	},
	bulmu = {
		headSize = Vector3.new(2.6, 2.4, 2.6),
		upperSize = Vector3.new(2.2, 1.8, 1.5),
		lowerSize = Vector3.new(1.8, 1.0, 1.2),
		armSize = Vector3.new(0.9, 1.4, 0.9),
		legSize = Vector3.new(0.8, 0.9, 0.8),
		primary = Color3.fromRGB(140, 40, 10),
		accent = Color3.fromRGB(240, 100, 30),
		idleStyle = "stoic",
		talkStyle = "nod",
		role = "ally",
		accessories = { "flame" },
	},
	areum = {
		headSize = Vector3.new(1.8, 2.2, 1.8),
		upperSize = Vector3.new(1.2, 1.8, 0.9),
		lowerSize = Vector3.new(1.0, 0.9, 0.8),
		armSize = Vector3.new(0.5, 1.6, 0.5),
		legSize = Vector3.new(0.5, 1.0, 0.5),
		primary = Color3.fromRGB(110, 90, 180),
		accent = Color3.fromRGB(210, 200, 255),
		idleStyle = "float",
		talkStyle = "nod",
		role = "ally",
		accessories = { "cloud_crown" },
	},
	alexander = {
		headSize = Vector3.new(2.0, 2.2, 2.0),
		upperSize = Vector3.new(2.0, 1.8, 1.5),
		lowerSize = Vector3.new(1.6, 1.0, 1.1),
		armSize = Vector3.new(0.9, 1.6, 0.9),
		legSize = Vector3.new(0.7, 1.0, 0.7),
		primary = Color3.fromRGB(100, 80, 40),
		accent = Color3.fromRGB(200, 160, 60),
		idleStyle = "stoic",
		talkStyle = "nod",
		role = "ally",
		accessories = { "helmet_visor" },
	},
	omega = {
		headSize = Vector3.new(2.0, 2.0, 2.0),
		upperSize = Vector3.new(1.6, 1.7, 1.1),
		lowerSize = Vector3.new(1.4, 1.0, 1.0),
		armSize = Vector3.new(0.7, 1.6, 0.7),
		legSize = Vector3.new(0.6, 1.0, 0.6),
		primary = Color3.fromRGB(20, 20, 80),
		accent = Color3.fromRGB(60, 180, 255),
		idleStyle = "float",
		talkStyle = "nod",
		role = "ally",
		accessories = { "antenna_array" },
	},
}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = false
	p.CanCollide = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function makeMotor6D(name: string, part0: Part, part1: Part, c0: CFrame, c1: CFrame, parent: Instance): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = parent
	return m
end

local function weldTo(part: Part, target: Part, offset: CFrame)
	part.CFrame = target.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = target
	w.Part1 = part
	w.Parent = target
end

-- ---------------------------------------------------------------------------
-- Accessory builders
-- ---------------------------------------------------------------------------

local function addAccessory(name: string, head: Part, headSize: Vector3, accent: Color3)
	if name == "eyes" then
		-- Two white eye dots on the front face of the head
		local eyeSize = Vector3.new(0.4, 0.4, 0.2)
		local leftEye = makePart("EyeLeft", eyeSize, Color3.fromRGB(255, 255, 255), head.Parent :: Instance)
		weldTo(leftEye, head, CFrame.new(-0.4, 0.0, headSize.Z / 2 + 0.1))
		local rightEye = makePart("EyeRight", eyeSize, Color3.fromRGB(255, 255, 255), head.Parent :: Instance)
		weldTo(rightEye, head, CFrame.new(0.4, 0.0, headSize.Z / 2 + 0.1))

	elseif name == "crown" then
		-- Three gold crown spikes
		local gold = Color3.fromRGB(220, 180, 30)
		local center = makePart("CrownCenter", Vector3.new(0.4, 0.8, 0.4), gold, head.Parent :: Instance)
		weldTo(center, head, CFrame.new(0, headSize.Y / 2 + 0.4, 0))
		local leftSpike = makePart("CrownLeft", Vector3.new(0.4, 0.6, 0.4), gold, head.Parent :: Instance)
		weldTo(leftSpike, head, CFrame.new(-0.5, headSize.Y / 2 + 0.3, 0))
		local rightSpike = makePart("CrownRight", Vector3.new(0.4, 0.6, 0.4), gold, head.Parent :: Instance)
		weldTo(rightSpike, head, CFrame.new(0.5, headSize.Y / 2 + 0.3, 0))

	elseif name == "ears" then
		-- Two small ear nubs, brown
		local brown = Color3.fromRGB(120, 70, 30)
		local earSize = Vector3.new(0.4, 0.5, 0.4)
		local leftEar = makePart("EarLeft", earSize, brown, head.Parent :: Instance)
		weldTo(leftEar, head, CFrame.new(-0.5, headSize.Y / 2 + 0.25, 0))
		local rightEar = makePart("EarRight", earSize, brown, head.Parent :: Instance)
		weldTo(rightEar, head, CFrame.new(0.5, headSize.Y / 2 + 0.25, 0))

	elseif name == "antenna" then
		-- Single thin antenna on top
		local antenna = makePart("Antenna", Vector3.new(0.15, 0.8, 0.15), accent, head.Parent :: Instance)
		weldTo(antenna, head, CFrame.new(0, headSize.Y / 2 + 0.4, 0))

	elseif name == "visor" then
		-- Flat visor strip on front of head
		local visorColor = Color3.fromRGB(
			math.floor(accent.R * 255 * 0.6),
			math.floor(accent.G * 255 * 0.6),
			math.floor(accent.B * 255 * 0.6)
		)
		local visor = makePart(
			"Visor",
			Vector3.new(headSize.X * 0.7, 0.4, 0.15),
			visorColor,
			head.Parent :: Instance
		)
		weldTo(visor, head, CFrame.new(0, 0, headSize.Z / 2 + 0.08))

	elseif name == "turban" then
		-- Wide flat turban-like hat
		local turban = makePart(
			"Turban",
			Vector3.new(headSize.X * 1.1, 0.5, headSize.Z * 1.1),
			accent,
			head.Parent :: Instance
		)
		weldTo(turban, head, CFrame.new(0, headSize.Y / 2 + 0.25, 0))

	elseif name == "crystal" then
		-- Tall thin crystal above head
		local crystal = makePart("Crystal", Vector3.new(0.3, 0.9, 0.3), Color3.fromRGB(200, 230, 255), head.Parent :: Instance)
		weldTo(crystal, head, CFrame.new(0, headSize.Y / 2 + 0.45, 0))

	elseif name == "flame" then
		-- Orange flame part on top
		local flame = makePart("Flame", Vector3.new(0.6, 0.8, 0.6), Color3.fromRGB(255, 80, 20), head.Parent :: Instance)
		weldTo(flame, head, CFrame.new(0, headSize.Y / 2 + 0.4, 0))

	elseif name == "cloud_crown" then
		-- Three small cloud puffs in an arc above head
		local cloudColor = Color3.fromRGB(230, 225, 255)
		local puffSize = Vector3.new(0.5, 0.5, 0.5)
		local puffLeft = makePart("CloudLeft", puffSize, cloudColor, head.Parent :: Instance)
		weldTo(puffLeft, head, CFrame.new(-0.5, headSize.Y / 2 + 0.25, 0))
		local puffCenter = makePart("CloudCenter", puffSize, cloudColor, head.Parent :: Instance)
		weldTo(puffCenter, head, CFrame.new(0, headSize.Y / 2 + 0.4, 0))
		local puffRight = makePart("CloudRight", puffSize, cloudColor, head.Parent :: Instance)
		weldTo(puffRight, head, CFrame.new(0.5, headSize.Y / 2 + 0.25, 0))

	elseif name == "helmet_visor" then
		-- Dark brow-plate / visor for helmet
		local visor = makePart(
			"HelmetVisor",
			Vector3.new(headSize.X * 0.8, 0.3, 0.2),
			Color3.fromRGB(60, 50, 30),
			head.Parent :: Instance
		)
		weldTo(visor, head, CFrame.new(0, -0.3, headSize.Z / 2 + 0.1))

	elseif name == "antenna_array" then
		-- Three thin antenna prongs on head top
		local antennaColor = accent
		local center = makePart("AntCenter", Vector3.new(0.12, 0.7, 0.12), antennaColor, head.Parent :: Instance)
		weldTo(center, head, CFrame.new(0, headSize.Y / 2 + 0.35, 0))
		local leftAnt = makePart("AntLeft", Vector3.new(0.1, 0.5, 0.1), antennaColor, head.Parent :: Instance)
		weldTo(leftAnt, head, CFrame.new(-0.4, headSize.Y / 2 + 0.25, 0))
		local rightAnt = makePart("AntRight", Vector3.new(0.1, 0.5, 0.1), antennaColor, head.Parent :: Instance)
		weldTo(rightAnt, head, CFrame.new(0.4, headSize.Y / 2 + 0.25, 0))
	end
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------

function CutsceneCharacterBuilder.Build(characterId: string): CharacterRig?
	local spec = CHAR_SPECS[characterId]
	if not spec then
		return nil
	end

	local headSize = spec.headSize
	local upperSize = spec.upperSize
	local lowerSize = spec.lowerSize
	local armSize = spec.armSize
	local legSize = spec.legSize

	-- Create model container
	local model = Instance.new("Model")
	model.Name = "CutsceneChar_" .. characterId

	-- -----------------------------------------------------------------------
	-- Calculate local-space Y positions (stack from bottom up)
	-- -----------------------------------------------------------------------
	local lowerBodyY = -0.3
	local upperBodyY = lowerBodyY + lowerSize.Y / 2 + upperSize.Y / 2 + 0.05
	local headY = upperBodyY + upperSize.Y / 2 + headSize.Y / 2 + 0.1
	local armY = upperBodyY + 0.2
	local legBottomY = lowerBodyY - lowerSize.Y / 2

	-- -----------------------------------------------------------------------
	-- Create all parts (positions set before joints)
	-- -----------------------------------------------------------------------

	-- Root anchor (transparent)
	local root = makePart("HumanoidRootPart", Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(255, 255, 255), model)
	root.Transparency = 1
	root.CFrame = CFrame.new(0, 0, 0)

	-- Body parts
	local lowerBody = makePart("LowerBody", lowerSize, spec.primary, model)
	lowerBody.CFrame = CFrame.new(0, lowerBodyY, 0)

	local upperBody = makePart("UpperBody", upperSize, spec.primary, model)
	upperBody.CFrame = CFrame.new(0, upperBodyY, 0)

	local head = makePart("Head", headSize, spec.accent, model)
	head.CFrame = CFrame.new(0, headY, 0)

	local leftArm = makePart("LeftArm", armSize, spec.primary, model)
	leftArm.CFrame = CFrame.new(-(upperSize.X / 2 + armSize.X / 2 + 0.05), armY, 0)

	local rightArm = makePart("RightArm", armSize, spec.primary, model)
	rightArm.CFrame = CFrame.new(upperSize.X / 2 + armSize.X / 2 + 0.05, armY, 0)

	-- Legs (only if legSize.X > 0; marina has no legs)
	if legSize.X > 0 then
		local leftLeg = makePart("LeftLeg", legSize, spec.primary, model)
		leftLeg.CFrame = CFrame.new(-0.35, legBottomY - legSize.Y / 2 - 0.05, 0)

		local rightLeg = makePart("RightLeg", legSize, spec.primary, model)
		rightLeg.CFrame = CFrame.new(0.35, legBottomY - legSize.Y / 2 - 0.05, 0)
	end

	model.PrimaryPart = root

	-- -----------------------------------------------------------------------
	-- Create Motor6D joints (after CFrame positions are set)
	-- -----------------------------------------------------------------------

	local waist = makeMotor6D(
		"Waist",
		lowerBody,
		upperBody,
		CFrame.new(0, lowerSize.Y / 2, 0),
		CFrame.new(0, -upperSize.Y / 2, 0),
		lowerBody
	)

	local neck = makeMotor6D(
		"Neck",
		upperBody,
		head,
		CFrame.new(0, upperSize.Y / 2, 0),
		CFrame.new(0, -headSize.Y / 2, 0),
		upperBody
	)

	local leftShoulder = makeMotor6D(
		"LeftShoulder",
		upperBody,
		leftArm,
		CFrame.new(-upperSize.X / 2 - 0.05, upperSize.Y / 2 - 0.4, 0),
		CFrame.new(0, armSize.Y / 2, 0),
		upperBody
	)

	local rightShoulder = makeMotor6D(
		"RightShoulder",
		upperBody,
		rightArm,
		CFrame.new(upperSize.X / 2 + 0.05, upperSize.Y / 2 - 0.4, 0),
		CFrame.new(0, armSize.Y / 2, 0),
		upperBody
	)

	-- Anchor: weld root to lowerBody (static, not animated)
	local rootWeld = Instance.new("WeldConstraint")
	rootWeld.Part0 = root
	rootWeld.Part1 = lowerBody
	rootWeld.Parent = root

	-- -----------------------------------------------------------------------
	-- Add accessories
	-- -----------------------------------------------------------------------
	for _, accessoryName in ipairs(spec.accessories) do
		addAccessory(accessoryName, head, headSize, spec.accent)
	end

	-- -----------------------------------------------------------------------
	-- Return rig with stored default C0 values
	-- -----------------------------------------------------------------------
	return {
		model = model,
		root = root,
		head = head,
		upperBody = upperBody,
		lowerBody = lowerBody,
		leftArm = leftArm,
		rightArm = rightArm,
		neck = neck,
		waist = waist,
		leftShoulder = leftShoulder,
		rightShoulder = rightShoulder,
		neckC0 = neck.C0,
		waistC0 = waist.C0,
		leftShoulderC0 = leftShoulder.C0,
		rightShoulderC0 = rightShoulder.C0,
		idleStyle = spec.idleStyle,
		talkStyle = spec.talkStyle,
		role = spec.role,
	} :: CharacterRig
end

-- ---------------------------------------------------------------------------
-- Idle animation (looping coroutine)
-- ---------------------------------------------------------------------------

function CutsceneCharacterBuilder.PlayIdleAnimation(rig: CharacterRig, holder: { thread: thread? })
	if holder.thread then
		task.cancel(holder.thread)
	end
	holder.thread = task.spawn(function()
		local t = 0
		while true do
			task.wait(1 / 30)
			t += 1 / 30
			if rig.idleStyle == "sway" then
				-- Waist gentle left-right sway
				if rig.waist then
					rig.waist.C0 = rig.waistC0 * CFrame.Angles(0, 0, math.sin(t * 1.2) * 0.05)
				end
				-- Head slight counter-sway
				if rig.neck then
					rig.neck.C0 = rig.neckC0 * CFrame.Angles(0, 0, math.sin(t * 1.2) * -0.03)
				end
			elseif rig.idleStyle == "float" then
				-- Gentle up-down float + slight pitch
				if rig.waist then
					rig.waist.C0 = rig.waistC0 * CFrame.new(0, math.sin(t * 1.5) * 0.08, 0)
				end
				if rig.neck then
					rig.neck.C0 = rig.neckC0 * CFrame.Angles(math.sin(t * 1.0) * 0.04, 0, 0)
				end
			elseif rig.idleStyle == "bounce" then
				-- Energetic up-down + head yaw
				if rig.waist then
					rig.waist.C0 = rig.waistC0 * CFrame.new(0, math.abs(math.sin(t * 3.0)) * 0.12, 0)
				end
				if rig.neck then
					rig.neck.C0 = rig.neckC0 * CFrame.Angles(0, math.sin(t * 3.0) * 0.06, 0)
				end
			elseif rig.idleStyle == "stoic" then
				-- Minimal breathing-like movement only
				if rig.waist then
					rig.waist.C0 = rig.waistC0 * CFrame.new(0, math.sin(t * 0.8) * 0.03, 0)
				end
			end
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Talk animation (one-shot)
-- ---------------------------------------------------------------------------

function CutsceneCharacterBuilder.PlayTalkAnimation(rig: CharacterRig)
	task.spawn(function()
		if not rig.neck then
			return
		end
		local neckC0 = rig.neckC0
		local neck = rig.neck :: Motor6D
		if rig.talkStyle == "nod" then
			-- Nod down
			TweenService
				:Create(neck, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					C0 = neckC0 * CFrame.Angles(math.rad(-12), 0, 0),
				})
				:Play()
			task.wait(0.2)
			-- Return with slight Back overshoot
			TweenService
				:Create(neck, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					C0 = neckC0,
				})
				:Play()
		elseif rig.talkStyle == "shake" then
			-- Menacing side-to-side shake (villain)
			TweenService:Create(neck, TweenInfo.new(0.1), {
				C0 = neckC0 * CFrame.Angles(0, math.rad(10), 0),
			}):Play()
			task.wait(0.12)
			TweenService:Create(neck, TweenInfo.new(0.1), {
				C0 = neckC0 * CFrame.Angles(0, math.rad(-10), 0),
			}):Play()
			task.wait(0.12)
			TweenService:Create(neck, TweenInfo.new(0.1), { C0 = neckC0 }):Play()
		elseif rig.talkStyle == "bounce" then
			-- Happy body-up bounce
			if rig.waist then
				local waist = rig.waist :: Motor6D
				TweenService
					:Create(waist, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						C0 = rig.waistC0 * CFrame.new(0, 0.15, 0),
					})
					:Play()
				task.wait(0.25)
				TweenService:Create(waist, TweenInfo.new(0.1), { C0 = rig.waistC0 }):Play()
			end
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Effect animation (one-shot, effect string key)
-- ---------------------------------------------------------------------------

function CutsceneCharacterBuilder.PlayEffectAnimation(rig: CharacterRig, effect: string)
	task.spawn(function()
		if effect == "shake" then
			-- Scared/shock: rapid head shake
			for _ = 1, 4 do
				if rig.neck then
					rig.neck.C0 = rig.neckC0 * CFrame.Angles(0, math.rad(8), 0)
				end
				task.wait(0.05)
				if rig.neck then
					rig.neck.C0 = rig.neckC0 * CFrame.Angles(0, math.rad(-8), 0)
				end
				task.wait(0.05)
			end
			if rig.neck then
				rig.neck.C0 = rig.neckC0
			end
		elseif effect == "particle" then
			-- Victory: both arms raise up
			local ls = rig.leftShoulder
			local rs = rig.rightShoulder
			if ls and rs then
				TweenService
					:Create(ls, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						C0 = rig.leftShoulderC0 * CFrame.Angles(0, 0, math.rad(50)),
					})
					:Play()
				TweenService
					:Create(rs, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						C0 = rig.rightShoulderC0 * CFrame.Angles(0, 0, math.rad(-50)),
					})
					:Play()
				task.wait(0.6)
				TweenService:Create(ls, TweenInfo.new(0.2), { C0 = rig.leftShoulderC0 }):Play()
				TweenService:Create(rs, TweenInfo.new(0.2), { C0 = rig.rightShoulderC0 }):Play()
			end
		elseif effect == "flash" then
			-- Dramatic villain lean-back
			if rig.waist then
				local waist = rig.waist :: Motor6D
				TweenService:Create(waist, TweenInfo.new(0.15), {
					C0 = rig.waistC0 * CFrame.Angles(math.rad(-8), 0, 0),
				}):Play()
				task.wait(0.4)
				TweenService:Create(waist, TweenInfo.new(0.2), { C0 = rig.waistC0 }):Play()
			end
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Reset pose (joints back to default C0)
-- ---------------------------------------------------------------------------

function CutsceneCharacterBuilder.ResetPose(rig: CharacterRig)
	if rig.neck then
		rig.neck.C0 = rig.neckC0
	end
	if rig.waist then
		rig.waist.C0 = rig.waistC0
	end
	if rig.leftShoulder then
		rig.leftShoulder.C0 = rig.leftShoulderC0
	end
	if rig.rightShoulder then
		rig.rightShoulder.C0 = rig.rightShoulderC0
	end
end

return CutsceneCharacterBuilder

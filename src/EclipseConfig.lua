--!strict
--[[
	EclipseConfig.lua
	Every tunable for the Eclipse hub in one ModuleScript.
	The hub edits these tables live; Save/Load round-trips them as JSON.
]]

local HttpService = game:GetService("HttpService")

local Config = {}

Config.Version = "1.1.0"
Config.Brand = "Soul Society"

-- // Theme -------------------------------------------------------------
Config.Theme = {
	-- Deep-space palette: saturated blues + vibrant green on dark navy.
	Background  = Color3.fromRGB(8, 13, 32),      -- deep space navy
	Panel       = Color3.fromRGB(16, 26, 60),     -- navy panel
	PanelAlt    = Color3.fromRGB(26, 42, 92),     -- lighter navy
	Stroke      = Color3.fromRGB(58, 112, 224),   -- electric blue edge
	Text        = Color3.fromRGB(240, 246, 255),
	TextDim     = Color3.fromRGB(140, 160, 205),  -- blue-tinted dim
	AccentStart = Color3.fromRGB(35, 125, 255),   -- vibrant blue
	AccentEnd   = Color3.fromRGB(45, 215, 255),   -- cyan
	Good        = Color3.fromRGB(45, 235, 135),   -- vibrant green
	Bad         = Color3.fromRGB(235, 90, 90),
}

-- // Input --------------------------------------------------------------
Config.Input = {
	MobileSupport = true, -- flip to false if the game ships PC-only
	DashKey  = Enum.KeyCode.Q,
	BlockKey = Enum.KeyCode.F,
	ToggleKey = Enum.KeyCode.RightShift, -- show/hide the hub window
}

-- // Assists ------------------------------------------------------------
Config.Assists = {
	FaceLock = {
		Enabled = false,
		Keybind = Enum.KeyCode.C, -- hold to snap toward nearest live player
		Range = 60,
	},
	AutoDash = {
		Enabled = false,
		Style = "V1",        -- "V1" hooks around the target, "V2" wider flip
		FireOnFrontDash = true,
		StartDelay = 0.0,
		TurnDelay = 0.015,
		MaxRange = 48,
	},
	AutoUppercut = {
		Enabled = false,
		Detection = "Animation", -- "Click" | "Animation" | "Both"
		ComboLength = 4,         -- fire on this M1 of the chain
		ComboReset = 1.28,       -- seconds before the chain resets
	},
}

-- // Movement tuning (server-owned stats in his game; hub edits the ask) --
Config.Movement = {
	FrontDashSpeed = 60,
	DashDistance   = 105,
	FrontDashCut   = false,
	CutTime        = 0.3,
	SideDashSpeed     = 55,
	SideDashDuration  = 0.3,
	BackDashSpeed     = 50,
	BackDashDuration  = 0.3,
	DashDuration      = 0.35, -- front dash
}

-- // Visuals --------------------------------------------------------------
Config.Visuals = {
	DashAnnounce = false, -- big "DASH xN" popup whenever you dash
}

-- // Per-tech params ------------------------------------------------------
-- The engine resolves {kind="wait", param="Delay"} against these tables,
-- so the hub sliders are always live.
Config.Techs = {
	BackdashCancel = {
		Enabled = true, Keybind = Enum.KeyCode.X,
		Delay = 0.05, MoveSlot = 1, CameraMode = "Default",
	},
	AerialBackdashCancel = {
		Enabled = true, Keybind = Enum.KeyCode.Z,
		Delay = 0.05, Jump = 55, MoveSlot = 1, CameraMode = "Default",
	},
	SidedashCancel = {
		Enabled = true, Keybind = Enum.KeyCode.V,
		Direction = "Left", Delay = 0.05, MoveSlot = 1, CameraMode = "Default",
	},
	FrontdashCancel = {
		Enabled = false, Keybind = Enum.KeyCode.B,
		Delay = 0.05, MoveSlot = 1, CameraMode = "Default",
	},
	UppercutDash = {
		Enabled = true, Keybind = Enum.KeyCode.G,
		Delay = 0.3, Jump = 55, Spin = 180, DashStop = 0.5, CameraMode = "Legit",
	},
	UppercutFlick = {
		Enabled = true, Keybind = Enum.KeyCode.H,
		Delay = 0.25, Jump = 55, CameraMode = "Default",
	},
	Floater = {
		Enabled = true, Keybind = Enum.KeyCode.J,
		Delay = 0.3, Jump = 55, DashStop = 0.4, CameraMode = "Default",
	},
	Twinnie = {
		Enabled = true, Keybind = Enum.KeyCode.K,
		Delay = 0.3, Jump = 55, Spin = 180, CameraMode = "Legit",
		PressQ = false, QPressDelay = 0.0, CameraDuration = 0.5,
	},
	Oreo = {
		Enabled = true, Keybind = Enum.KeyCode.L,
		Delay = 0.3, Jump = 55, Direction = "Right", CameraMode = "Default",
	},
	Kakyo = {
		Enabled = true, Keybind = Enum.KeyCode.Semicolon,
		Delay = 0.3, Jump = 55, Spin = 180, DashStop = 0.35, CameraMode = "Default",
	},
	LoopdashRework = {
		Enabled = true, Keybind = Enum.KeyCode.N,
		Delay = 0.4, Jump = 55, EnableJump = true, Spin = 180, DashStop = 0.5,
	},
	Supa = {
		Enabled = true, Keybind = Enum.KeyCode.U,
		Delay = 0.25, Jump = 60, DashStop = 0.35, CameraMode = "Default",
	},
	-- Prepped, pending his confirmation (enable when he says yes):
	Wasp = {
		Enabled = true, Keybind = Enum.KeyCode.I,
		Delay = 0.15, Jump = 55, Direction = "Left", CameraMode = "Default",
	},
	KibaFloat = {
		Enabled = true, Keybind = Enum.KeyCode.O,
		Delay = 0.2, Jump = 65, DashStop = 0.3, CameraMode = "Default",
	},

	-- Universal canon:
	UppercutJump = {
		Enabled = true, Keybind = Enum.KeyCode.T,
		Jump = 55, CameraMode = "Default",
	},
	UpsideDownRagdoll = {
		Enabled = true, Keybind = Enum.KeyCode.Y,
		Delay = 0.1, CameraMode = "Default",
	},
	StunNegation = {
		Enabled = true, CameraMode = "Default", -- auto: fires when stunned
	},
	DelayedM1s = {
		Enabled = true, Keybind = Enum.KeyCode.P,
		Delay = 0.4, CameraMode = "Default",
	},
	M1Shove = {
		Enabled = true, Keybind = Enum.KeyCode.F1,
		Delay = 0.05, CameraMode = "Default",
	},
	WallExtend = {
		Enabled = true, Keybind = Enum.KeyCode.F2,
		Delay = 0.2, CameraMode = "Default",
	},
	GroundPunch = {
		Enabled = true, Keybind = Enum.KeyCode.F3,
		Delay = 0.6, CameraMode = "Default",
	},
	DMGChip = {
		Enabled = true, Keybind = Enum.KeyCode.F4,
		DashStop = 0.15, CameraMode = "Default",
	},
	MicroDash = {
		Enabled = true, Keybind = Enum.KeyCode.F5,
		DashStop = 0.1, CameraMode = "Default",
	},
	Headwalk = {
		Enabled = true, Keybind = Enum.KeyCode.F6,
		Jump = 70, Delay = 0.2, CameraMode = "Default",
	},
	TrueDownslam = {
		Enabled = true, Keybind = Enum.KeyCode.F7,
		Delay = 0.05, CameraMode = "Default",
	},
	TrashyEscapePlan = {
		Enabled = true, Keybind = Enum.KeyCode.F8,
		Jump = 55, CameraMode = "Default",
	},
	BenchJump = {
		Enabled = true, Keybind = Enum.KeyCode.F9,
		Jump = 60, CameraMode = "Default",
	},
	-- Creator variants:
	TwinnieV2 = {
		Enabled = true, Keybind = Enum.KeyCode.Equals,
		Delay = 0.25, Jump = 60, Spin = 180, CameraDuration = 0.4, CameraMode = "Legit",
	},
	TwinnieDash = {
		Enabled = true, Keybind = Enum.KeyCode.Backquote,
		Delay = 0.3, Spin = 180, CameraMode = "Legit",
	},
	Solitude = {
		Enabled = true, Keybind = Enum.KeyCode.Five,
		Delay = 0.3, Jump = 55, Spin = 90, CameraMode = "Legit",
	},
	Xcz = {
		Enabled = true, Keybind = Enum.KeyCode.Six,
		Delay = 0.3, Jump = 55, DashStop = 0.4, CameraMode = "Default",
	},
	Kyo = {
		Enabled = true, Keybind = Enum.KeyCode.Seven,
		Delay = 0.2, Spin = 180, Direction = "Left", DashStop = 0.4, CameraMode = "Default",
	},
	Lixxit = {
		Enabled = true, Keybind = Enum.KeyCode.Eight,
		Delay = 0.25, Jump = 55, CameraMode = "Default",
	},
	Dripz = {
		Enabled = true, Keybind = Enum.KeyCode.Nine,
		Delay = 0.3, Direction = "Right", CameraMode = "Legit",
	},
	K1ng = {
		Enabled = true, Keybind = Enum.KeyCode.Zero,
		Delay = 0.3, Spin = 360, DashStop = 0.5, CameraMode = "Default",
	},
	-- Hero Hunter character techs:
	TwistedDash = {
		Enabled = true, -- auto: fires on your 4th M1
		Delay = 0.05, Spin = 180, CameraMode = "Default",
	},
	WhirlwindFlickDash = {
		Enabled = true, Keybind = Enum.KeyCode.F11,
		RequiresMove = "LethalWhirlwind",
		Delay = 1.0, Jump = 55, CameraMode = "Default",
	},
	CurveDash = {
		Enabled = true, Keybind = Enum.KeyCode.F12,
		MoveSlot = 2, Delay = 0.1, Direction = "Right", CameraMode = "Default",
	},
	PerilTwist = {
		Enabled = true, Keybind = Enum.KeyCode.LeftBracket,
		RequiresMove = "PreysPeril",
		Spin = 180, Direction = "Left", CameraMode = "Default",
	},
	FlowingDash = {
		Enabled = true, Keybind = Enum.KeyCode.RightBracket,
		RequiresMove = "FlowingWater",
		Delay = 0.3, CameraMode = "Default",
	},
	UppercutGrasp = {
		Enabled = true, Keybind = Enum.KeyCode.BackSlash,
		RequiresMove = "HuntersGrasp",
		Jump = 55, CameraMode = "Default",
	},

	-- Round-2 research additions:
	HeadRide = {
		Enabled = true, Keybind = Enum.KeyCode.Home,
		Jump = 75, Delay = 0.25, CameraMode = "Default",
	},
	OneEightyUppercut = {
		Enabled = true, Keybind = Enum.KeyCode.End,
		Spin = 180, CameraDuration = 0.3, CameraMode = "Default",
	},
	Surf = {
		Enabled = true, Keybind = Enum.KeyCode.PageUp,
		Jump = 55, DashStop = 0.2, CameraMode = "Default",
	},
	Reflex = {
		Enabled = false, -- auto: side dash on every M1 you land
		Direction = "Right", CameraMode = "Default",
	},
	SupaV2 = {
		Enabled = true, Keybind = Enum.KeyCode.PageDown,
		Delay = 0.2, Jump = 65, DashStop = 0.25, CameraMode = "Default",
	},
	Notpaki = {
		Enabled = true, Keybind = Enum.KeyCode.Insert,
		Spin = 270, DashStop = 0.45, CameraMode = "Default",
	},
	MiniUppercutDash = {
		Enabled = true, Keybind = Enum.KeyCode.Minus,
		DashStop = 0.3, CameraMode = "Default",
	},
	LethalRevamp = {
		Enabled = true, Keybind = Enum.KeyCode.F10,
		RequiresMove = "LethalWhirlwind",
		Delay = 1.2, Spin = 90, DashStop = 0.5, CameraMode = "Default",
	},

	TreeTwisted = {
		Enabled = true, Keybind = Enum.KeyCode.Quote,
		Delay = 0.05, Jump = 55, Spin = 180, CameraDuration = 0.4, CameraMode = "Legit",
	},
	TreeLoop = {
		Enabled = true, Keybind = Enum.KeyCode.KeypadOne,
		Delay = 0.35, Jump = 55, Spin = 180, DashStop = 0.5, CameraMode = "Default",
	},

	-- Character-gated: need the matching move in his moveset. The engine
	-- skips these with a clear warning until the move name exists.
	Lethal = {
		Enabled = true, Keybind = Enum.KeyCode.M,
		RequiresMove = "LethalWhirlwind",
		Delay = 1.7, Jump = 55, CameraMode = "Default",
	},
	LoopLethal = {
		Enabled = true, Keybind = Enum.KeyCode.Comma,
		RequiresMove = "LethalWhirlwind",
		Delay = 1.7, Jump = 55, Spin = 90, DashStop = 0.55,
	},
	Kyoto = {
		Enabled = true, Keybind = Enum.KeyCode.Period,
		RequiresMove = "FlowingWater",
		Delay = 0.1, CameraMode = "Default",
	},
	RagdollEscape = { -- Praiseres-style: break ragdoll with a dash, 30s cd server-side
		Enabled = true, Keybind = Enum.KeyCode.R,
		Direction = "Back", CameraMode = "Default",
	},
}

-- // Mobile ---------------------------------------------------------------
Config.Mobile = {
	ForceShow = false, -- show on-screen buttons even without a touchscreen
	Favorites = { -- techs that get on-screen buttons (button-trigger techs only)
		"BackdashCancel", "SidedashCancel", "UppercutDash",
		"Floater", "Twinnie", "RagdollEscape",
	},
}

-- // Performance ----------------------------------------------------------
Config.Performance = {
	DisableShadows = false,
	DisableMeshes = false,
	DisableTextures = false,
	LowPolyMode = false,
	FpsCap = 240,
	UncapFps = false,
}

-- // Named presets (save / load / rename the whole config) -------------------
Config.Presets = {}

local function presetsToFile()
	pcall(function()
		(writefile :: any)("SoulSociety_presets.json", HttpService:JSONEncode(Config.Presets))
	end)
end

function Config.LoadPresetsFromFile()
	pcall(function()
		local raw = (readfile :: any)("SoulSociety_presets.json")
		local decoded = HttpService:JSONDecode(raw)
		if type(decoded) == "table" then Config.Presets = decoded end
	end)
end

function Config.SavePreset(name: string)
	Config.Presets[name] = Config.Serialize()
	presetsToFile()
end

function Config.LoadPreset(name: string): boolean
	local json = Config.Presets[name]
	if not json then return false end
	return Config.LoadFrom(json)
end

function Config.RenamePreset(oldName: string, newName: string): boolean
	if not Config.Presets[oldName] or Config.Presets[newName] then return false end
	Config.Presets[newName] = Config.Presets[oldName]
	Config.Presets[oldName] = nil
	presetsToFile()
	return true
end

function Config.DeletePreset(name: string)
	Config.Presets[name] = nil
	presetsToFile()
end

function Config.ListPresets(): {string}
	local out = {}
	for name in pairs(Config.Presets) do table.insert(out, name) end
	table.sort(out)
	return out
end

-- // JSON round-trip ------------------------------------------------------
local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = deepCopy(v) end
	return out
end

-- Serializes with enums as strings so the file survives outside Roblox.
function Config.Serialize(): string
	local function encode(v)
		local tv = typeof(v)
		if tv == "EnumItem" then
			return { __enum = tostring(v) }
		elseif tv == "Color3" then
			return { __color3 = { v.R, v.G, v.B } }
		elseif tv == "table" then
			local out = {}
			for k, vv in pairs(v) do out[tostring(k)] = encode(vv) end
			return out
		end
		return v
	end
	return HttpService:JSONEncode(encode(Config))
end

function Config.LoadFrom(json: string): boolean
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or type(decoded) ~= "table" then return false end
	local function merge(dst, src)
		for k, v in pairs(src) do
			if type(v) == "table" and v.__enum then
				local okE, enumItem = pcall(function()
					local enumName, itemName = v.__enum:match("^Enum%.(.-)%.(.+)$")
					return (Enum :: any)[enumName][itemName]
				end)
				if okE then dst[k] = enumItem end
			elseif type(v) == "table" and v.__color3 then
				dst[k] = Color3.new(v.__color3[1], v.__color3[2], v.__color3[3])
			elseif type(v) == "table" and type(dst[k]) == "table" then
				merge(dst[k], v)
			elseif type(v) ~= "table" then
				dst[k] = v
			end
		end
	end
	merge(Config, decoded)
	return true
end

Config._defaults = deepCopy(Config)
function Config.ResetToDefaults()
	for k, v in pairs(Config._defaults) do
		if k ~= "_defaults" then Config[k] = deepCopy(v) end
	end
end

return Config

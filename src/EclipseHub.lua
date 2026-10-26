--!strict
--[[
	EclipseHub.lua  (client GUI)
	The SOUL SOCIETY interface. Lunar-style dark theme: near-black
	translucent window, left sidebar with live Search, grouped tabs
	(MAIN / FEATURES) with an active indicator bar, profile card at the
	bottom, minimize + hide window controls, an Earth accent drawn from
	plain instances. ORIGINAL design and code - same layout language as
	the hubs he showed us, none of their assets or code.

	Runs Studio-native (PlayerGui) or via executor (gethui/CoreGui).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")


-- Dual-path module resolution: executor bundle (getgenv cache) first,
-- Studio ModuleScript install as fallback. Same file works in both.
local function mod(name)
	if getgenv and getgenv().SoulSocietyModules and getgenv().SoulSocietyModules[name] then
		return getgenv().SoulSocietyModules[name]
	end
	if name == "EclipseConfig" or name == "Techs" then
		return require(ReplicatedStorage:WaitForChild(name))
	end
	return require(game.StarterPlayer.StarterPlayerScripts:WaitForChild(name))
end

local Config = mod("EclipseConfig")
local Techs = mod("Techs")

local LocalPlayer = Players.LocalPlayer
local T = Config.Theme

local Hub = {}

-- // Instance helpers ----------------------------------------------------------
local function new(class: string, props: {[string]: any}, children: {Instance}?)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then (inst :: any)[k] = v end
	end
	if children then
		for _, child in ipairs(children) do child.Parent = inst end
	end
	if props.Parent then inst.Parent = props.Parent end
	return inst
end

local function corner(r: number)
	return new("UICorner", {CornerRadius = UDim.new(0, r)})
end

local function stroke(color: Color3, thickness: number?)
	return new("UIStroke", {Color = color, Thickness = thickness or 1, Transparency = 0.25})
end

local function gradient(c0: Color3, c1: Color3, rotation: number?)
	return new("UIGradient", {Color = ColorSequence.new(c0, c1), Rotation = rotation or 90})
end

local function label(text: string, size: number, color: Color3?, props: {[string]: any}?)
	local p = props or {}
	p.BackgroundTransparency = 1
	p.Text = text
	p.TextColor3 = color or T.Text
	p.TextSize = size
	p.Font = Enum.Font.GothamMedium
	p.TextXAlignment = Enum.TextXAlignment.Left
	return new("TextLabel", p)
end

-- // Root ------------------------------------------------------------------------
local parent: Instance
do
	-- gethui first (executors). CoreGui only if we can ACTUALLY parent to it
	-- (Studio play mode returns the service but rejects non-core parenting).
	local ok, hui = pcall(function() return (gethui :: any)() end)
	if ok and hui then
		parent = hui
	else
		local coreOk, coreGui = pcall(function() return game:GetService("CoreGui") end)
		local canParent = false
		if coreOk and coreGui then
			canParent = pcall(function()
				local probe = Instance.new("Folder")
				probe.Parent = coreGui
				probe:Destroy()
			end)
		end
		parent = (canParent and coreGui) or LocalPlayer:WaitForChild("PlayerGui")
	end
end

local gui = new("ScreenGui", {
	Name = "SoulSocietyHub",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = parent,
})

-- drop shadow behind the window (depth)
local shadow = new("Frame", {
	Name = "Shadow", Size = UDim2.fromOffset(676, 436),
	Position = UDim2.new(0.5, -338, 0.5, -202),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.55,
	BorderSizePixel = 0, ZIndex = 1, Parent = gui,
}, {corner(16)})

local main = new("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(660, 420),
	Position = UDim2.new(0.5, -330, 0.5, -210),
	BackgroundColor3 = T.Background,
	BackgroundTransparency = 0.06,
	ClipsDescendants = true,
	ZIndex = 2,
	Parent = gui,
}, {corner(14), stroke(T.Stroke, 1)})
local function syncShadow()
	shadow.Position = UDim2.new(main.Position.X.Scale, main.Position.X.Offset - 8, main.Position.Y.Scale, main.Position.Y.Offset + 8)
	shadow.Size = UDim2.new(0, main.Size.X.Offset + 16, 0, main.Size.Y.Offset + 16)
	shadow.Visible = main.Visible
end
main:GetPropertyChangedSignal("Position"):Connect(syncShadow)
main:GetPropertyChangedSignal("Size"):Connect(syncShadow)
main:GetPropertyChangedSignal("Visible"):Connect(syncShadow)
syncShadow()

-- // Galaxy backdrop (all primitives, no image assets) -------------------------
-- Wrapped in pcall: if ANY decoration fails, the window still opens.
local galaxy = new("Frame", {
	Name = "Galaxy", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	ClipsDescendants = true, ZIndex = 1, Parent = main,
}, {corner(14)})
do
	local ok, err = pcall(function()
		-- starfield: tinted stars with slow twinkle
		local starColors = {
			Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 200, 255),
			Color3.fromRGB(120, 230, 255), Color3.fromRGB(140, 255, 190),
		}
		for i = 1, 110 do
			local big = math.random() < 0.12
			local dot = new("Frame", {
				Size = UDim2.fromOffset(big and 3 or 2, big and 3 or 2),
				Position = UDim2.fromScale(math.random(), math.random()),
				BackgroundColor3 = starColors[math.random(#starColors)],
				BackgroundTransparency = 0.2 + math.random() * 0.4,
				BorderSizePixel = 0, ZIndex = 1, Parent = galaxy,
			}, {corner(3)})
			TweenService:Create(dot, TweenInfo.new(1.2 + math.random() * 2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				BackgroundTransparency = 0.0,
			}):Play()
		end
		-- nebulas: soft onion-skin glow blobs (saturated blue / cyan / green)
		local function nebula(cx: number, cy: number, radius: number, color: Color3)
			for ring = 4, 1, -1 do
				local r = math.floor(radius * (0.55 + 0.45 * ring / 4))
				local blob = new("Frame", {
					Size = UDim2.fromOffset(r * 2, r * 2),
					Position = UDim2.new(cx, -r, cy, -r),
					BackgroundColor3 = color,
					BackgroundTransparency = 0.92 + (4 - ring) * 0.02,
					BorderSizePixel = 0, ZIndex = 1, Parent = galaxy,
				}, {corner(r * 2)})
				if ring == 1 then
					TweenService:Create(blob, TweenInfo.new(9 + math.random() * 6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
						Position = UDim2.new(cx, -r + math.random(-30, 30), cy, -r + math.random(-20, 20)),
					}):Play()
				end
			end
		end
		nebula(0.25, 0.35, 110, Color3.fromRGB(35, 125, 255))  -- blue
		nebula(0.6, 0.8, 95, Color3.fromRGB(45, 215, 255))     -- cyan
		nebula(0.85, 0.3, 80, Color3.fromRGB(45, 235, 135))    -- green
		nebula(0.1, 0.85, 70, Color3.fromRGB(120, 80, 255))    -- violet hint
	end)
	if not ok then warn("[SoulSociety] galaxy decoration skipped: " .. tostring(err)) end
end

-- // Title bar (Lunar-style header) ---------------------------------------------
local titleBar = new("Frame", {
	Name = "TitleBar", Size = UDim2.new(1, 0, 0, 52),
	BackgroundColor3 = T.Panel, BackgroundTransparency = 0.15,
	ZIndex = 3, Parent = main,
}, {corner(14)})

local moonLabel = label("\u{263E}", 24, T.AccentEnd, {
	Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, 10, 0.5, -15),
	TextXAlignment = Enum.TextXAlignment.Center, Font = Enum.Font.GothamBold,
	Parent = titleBar,
})
new("UIStroke", {Color = T.AccentStart, Thickness = 1, Transparency = 0.35, Parent = moonLabel})
label("v" .. Config.Version, 10, T.AccentEnd, {
	Size = UDim2.new(0, 160, 0, 14), Position = UDim2.new(0, 46, 0, 9),
	Font = Enum.Font.GothamMedium, Parent = titleBar,
})
local titleLabel = label("SOUL SOCIETY", 17, T.Text, {
	Size = UDim2.new(0, 220, 0, 20), Position = UDim2.new(0, 46, 0, 24),
	Font = Enum.Font.GothamBold, Parent = titleBar,
})
gradient(Color3.fromRGB(255, 255, 255), T.AccentEnd, 0).Parent = titleLabel
-- glow divider under the header
new("Frame", {
	Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
	BackgroundColor3 = T.AccentStart, BackgroundTransparency = 0.4,
	BorderSizePixel = 0, Parent = titleBar,
}, {gradient(T.AccentStart, T.AccentEnd, 0)})

local function winBtn(txt: string, xOff: number)
	return new("TextButton", {
		Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, xOff, 0.5, -13),
		BackgroundColor3 = T.PanelAlt, BackgroundTransparency = 0.4, Text = txt,
		TextColor3 = T.TextDim, TextSize = 13, Font = Enum.Font.GothamBold,
		Parent = titleBar,
	}, {corner(7)})
end
local minBtn = winBtn("-", -68)
local closeBtn = winBtn("X", -36)
-- X hides the window; RightShift (Config.Input.ToggleKey) brings it back
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

-- drag by the title bar
do
	local dragging, dragStart, startPos
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- // Earth centerpiece, bottom-right (vibrant blue+green, drawn from instances) --
-- pcall-wrapped: if it fails, the hub still opens without it.
local earth = new("Frame", {
	Name = "EarthLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	ZIndex = 1, Parent = main,
})
do
	local ok, err = pcall(function()
		-- soft glow halo (onion-skin rings)
		for ring = 3, 1, -1 do
			local r = 68 + ring * 15
			new("Frame", {
				Size = UDim2.fromOffset(r * 2, r * 2), Position = UDim2.new(1, -95 - r, 1, -75 - r),
				BackgroundColor3 = Color3.fromRGB(60, 150, 255),
				BackgroundTransparency = 0.9 + ring * 0.025,
				BorderSizePixel = 0, ZIndex = 1, Parent = earth,
			}, {corner(r * 2)})
		end
		-- planet body: vibrant saturated blue sphere
		local body = new("Frame", {
			Size = UDim2.fromOffset(130, 130), Position = UDim2.new(1, -160, 1, -140),
			BackgroundColor3 = Color3.fromRGB(30, 110, 235),
			BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 1, Parent = earth,
		}, {
			corner(130),
			gradient(Color3.fromRGB(70, 170, 255), Color3.fromRGB(12, 55, 160), 135),
			new("UIStroke", {Color = Color3.fromRGB(120, 220, 255), Thickness = 2, Transparency = 0.25}),
		})
		-- continents: vibrant green landmasses
		local lands = {
			{0.22, 0.28, 30}, {0.55, 0.2, 22}, {0.42, 0.55, 34},
			{0.7, 0.6, 20}, {0.15, 0.62, 17}, {0.62, 0.42, 14},
		}
		for _, l in ipairs(lands) do
			new("Frame", {
				Size = UDim2.fromOffset(l[3], l[3]),
				Position = UDim2.new(l[1], -l[3] / 2, l[2], -l[3] / 2),
				BackgroundColor3 = Color3.fromRGB(45, 220, 120),
				BackgroundTransparency = 0.15, BorderSizePixel = 0,
				ZIndex = 1, Parent = body,
			}, {corner(l[3])})
		end
		-- terminator shadow: bottom-right dark crescent for 3D sphere depth
		new("Frame", {
			Size = UDim2.fromOffset(130, 130), Position = UDim2.new(0.25, 0, 0.25, 0),
			BackgroundColor3 = Color3.fromRGB(2, 6, 20), BackgroundTransparency = 0.55,
			BorderSizePixel = 0, ZIndex = 1, Parent = body,
		}, {corner(130)})
		-- slow rotation drift of the whole planet
		TweenService:Create(body, TweenInfo.new(14, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Position = UDim2.new(1, -164, 1, -144),
		}):Play()
		-- orbit ring
		new("Frame", {
			Size = UDim2.fromOffset(190, 190), Position = UDim2.new(1, -190, 1, -170),
			BackgroundTransparency = 1, Rotation = 18, ZIndex = 1, Parent = earth,
		}, {
			corner(190),
			new("UIStroke", {Color = T.AccentStart, Transparency = 0.7, Thickness = 1}),
		})
	end)
	if not ok then warn("[SoulSociety] earth decoration skipped: " .. tostring(err)) end
end

-- // Sidebar (search + grouped tabs + profile card) ------------------------------
local sidebar = new("Frame", {
	Name = "Sidebar", Size = UDim2.new(0, 148, 1, -68), Position = UDim2.new(0, 8, 0, 60),
	BackgroundColor3 = T.Panel, BackgroundTransparency = 0.25,
	ZIndex = 3, Parent = main,
}, {corner(10), stroke(T.Stroke)})

local searchBox = new("TextBox", {
	Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 0, 8),
	BackgroundColor3 = T.PanelAlt, PlaceholderText = "Search",
	PlaceholderColor3 = T.TextDim, Text = "", TextColor3 = T.Text, TextSize = 12,
	Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false, Parent = sidebar,
}, {corner(8), stroke(T.Stroke), new("UIPadding", {PaddingLeft = UDim.new(0, 10)})})

local rail = new("Frame", {
	Name = "Rail", Size = UDim2.new(1, -16, 1, -110), Position = UDim2.new(0, 8, 0, 46),
	BackgroundTransparency = 1, Parent = sidebar,
}, {
	new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
})

local pages = new("Frame", {
	Name = "Pages", Size = UDim2.new(1, -172, 1, -76), Position = UDim2.new(0, 164, 0, 66),
	BackgroundTransparency = 1, ZIndex = 3, Parent = main,
})

local TAB_GROUPS = {
	{label = "MAIN", tabs = {"Home", "Techs", "Macros"}},
	{label = "FEATURES", tabs = {"Movement", "Assists", "Performance", "Settings"}},
}
local pageFrames: {[string]: ScrollingFrame} = {}
local tabButtons: {[string]: TextButton} = {}
local tabBars: {[string]: Frame} = {}
local tabGrads: {[string]: UIGradient} = {}

local function showPage(name: string)
	for tabName, page in pairs(pageFrames) do
		page.Visible = tabName == name
	end
	for tabName, btn in pairs(tabButtons) do
		local active = tabName == name
		btn.BackgroundColor3 = active and T.AccentStart or T.Panel
		btn.BackgroundTransparency = active and 0.35 or 0.85
		btn.TextColor3 = active and T.Text or T.TextDim
		tabGrads[tabName].Enabled = active
		tabBars[tabName].Visible = active
	end
end

local railOrder = 0
for _, group in ipairs(TAB_GROUPS) do
	railOrder += 1
	label(group.label, 10, T.TextDim, {
		Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold,
		LayoutOrder = railOrder, Parent = rail,
	})
	for _, tabName in ipairs(group.tabs) do
		railOrder += 1
		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.Panel,
			BackgroundTransparency = 0.85, Text = "    " .. tabName,
			TextColor3 = T.TextDim, TextSize = 13,
			Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = railOrder, Parent = rail,
		}, {corner(8)})
		local bar = new("Frame", {
			Size = UDim2.new(0, 3, 0.6, 0), Position = UDim2.new(0, 3, 0.2, 0),
			BackgroundColor3 = T.Good, BorderSizePixel = 0,
			Visible = false, Parent = btn,
		}, {corner(3)})
		local bg = gradient(T.AccentStart, T.AccentEnd, 0)
		bg.Enabled = false
		bg.Parent = btn
		btn.MouseButton1Click:Connect(function() showPage(tabName) end)
		tabButtons[tabName] = btn
		tabBars[tabName] = bar
		tabGrads[tabName] = bg

		local page = new("ScrollingFrame", {
			Name = tabName, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Visible = false, ScrollBarThickness = 4, ScrollBarImageColor3 = T.Stroke,
			CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = pages,
		}, {
			new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
			new("UIPadding", {PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)}),
		})
		pageFrames[tabName] = page
	end
end

-- search filters the Techs page rows live
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local q = string.lower(searchBox.Text)
	for _, child in ipairs(pageFrames.Techs:GetChildren()) do
		if child:IsA("Frame") and string.sub(child.Name, 1, 8) == "techrow:" then
			child.Visible = q == "" or string.find(string.lower(child.Name), q, 1, true) ~= nil
		elseif child:IsA("TextLabel") then
			child.Visible = q == ""
		end
	end
end)

-- profile card, bottom of sidebar
local profile = new("Frame", {
	Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -52),
	BackgroundColor3 = T.PanelAlt, BackgroundTransparency = 0.4, Parent = sidebar,
}, {corner(8)})
local pthumb = new("ImageLabel", {
	Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, 7, 0.5, -15),
	BackgroundColor3 = T.Panel, Parent = profile,
}, {corner(30), new("UIStroke", {Color = T.AccentEnd, Thickness = 1, Transparency = 0.4})})
new("Frame", {
	Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 33, 1, -10),
	BackgroundColor3 = T.Good, BorderSizePixel = 0, Parent = profile,
}, {corner(8)})
task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if ok then pthumb.Image = img end
end)
label(LocalPlayer.DisplayName, 12, T.Text, {
	Size = UDim2.new(1, -46, 0, 16), Position = UDim2.new(0, 44, 0, 6),
	Font = Enum.Font.GothamBold, Parent = profile,
})
label("@" .. LocalPlayer.Name, 10, T.TextDim, {
	Size = UDim2.new(1, -46, 0, 14), Position = UDim2.new(0, 44, 0, 22),
	Parent = profile,
})

-- minimize: collapse to just the title bar
local minimized = false
local fullSize = main.Size
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	sidebar.Visible = not minimized
	pages.Visible = not minimized
	earth.Visible = not minimized
	main.Size = minimized and UDim2.fromOffset(fullSize.X.Offset, 52) or fullSize
	minBtn.Text = minimized and "+" or "-"
end)

-- // Widgets -------------------------------------------------------------------------
local function sectionHeader(parent: Instance, text: string, order: number)
	label(text, 12, T.TextDim, {
		Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold,
		LayoutOrder = order, Parent = parent,
	})
end

local function card(parent: Instance, height: number, order: number): Frame
	return new("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = T.Panel,
		LayoutOrder = order, Parent = parent,
	}, {corner(10), stroke(T.Stroke)})
end

local function toggle(parent: Instance, pos: UDim2, initial: boolean, onChange: (boolean) -> ())
	local state = initial
	local btn = new("TextButton", {
		Size = UDim2.fromOffset(40, 20), Position = pos, Text = "",
		BackgroundColor3 = state and T.AccentStart or T.PanelAlt, Parent = parent,
	}, {corner(20)})
	local trackGrad = gradient(T.AccentStart, T.AccentEnd, 0)
	trackGrad.Enabled = state
	trackGrad.Parent = btn
	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
		BackgroundColor3 = state and Color3.fromRGB(255, 255, 255) or T.TextDim, Parent = btn,
	}, {corner(14)})
	btn.MouseButton1Click:Connect(function()
		state = not state
		TweenService:Create(knob, TweenInfo.new(0.12), {
			Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
		}):Play()
		btn.BackgroundColor3 = state and T.AccentStart or T.PanelAlt
		trackGrad.Enabled = state
		knob.BackgroundColor3 = state and Color3.fromRGB(255, 255, 255) or T.TextDim
		onChange(state)
	end)
end

-- slider: label left, live value right, drag bar underneath
local function slider(parent: Instance, order: number, name: string, minV: number, maxV: number, stepV: number, initial: number, onChange: (number) -> ())
	local value = initial
	local c = card(parent, 52, order)
	label(name, 12, T.Text, {Size = UDim2.new(0.7, 0, 0, 20), Position = UDim2.new(0, 10, 0, 4), Parent = c})
	local valueLabel = label(tostring(value), 12, T.AccentStart, {
		Size = UDim2.new(0.3, -10, 0, 20), Position = UDim2.new(0.7, 0, 0, 4),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = c,
	})
	local bar = new("Frame", {
		Size = UDim2.new(1, -20, 0, 6), Position = UDim2.new(0, 10, 0, 32),
		BackgroundColor3 = T.PanelAlt, Parent = c,
	}, {corner(6)})
	local frac = (initial - minV) / (maxV - minV)
	local fill = new("Frame", {
		Size = UDim2.new(frac, 0, 1, 0), BackgroundColor3 = T.AccentEnd, Parent = bar,
	}, {corner(6), gradient(T.AccentStart, T.AccentEnd, 0)})
	local dragging = false
	local function setFromX(x: number)
		local absPos = bar.AbsolutePosition.X
		local width = math.max(1, bar.AbsoluteSize.X)
		local f = math.clamp((x - absPos) / width, 0, 1)
		value = math.floor((minV + (maxV - minV) * f) / stepV + 0.5) * stepV
		value = math.clamp(value, minV, maxV)
		fill.Size = UDim2.new((value - minV) / (maxV - minV), 0, 1, 0)
		valueLabel.Text = string.format("%g", value)
		onChange(value)
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- keybind capture: click, then press the new key
local function keybindButton(parent: Instance, pos: UDim2, current: Enum.KeyCode, onChange: (Enum.KeyCode) -> ())
	local btn = new("TextButton", {
		Size = UDim2.fromOffset(86, 22), Position = pos,
		BackgroundColor3 = T.PanelAlt, Text = current.Name, TextColor3 = T.Text,
		TextSize = 11, Font = Enum.Font.GothamMedium, Parent = parent,
	}, {corner(6), stroke(T.Stroke)})
	btn.MouseButton1Click:Connect(function()
		btn.Text = "press key..."
		local conn
		conn = UserInputService.InputBegan:Connect(function(input, gpe)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				btn.Text = input.KeyCode.Name
				onChange(input.KeyCode)
				conn:Disconnect()
			end
		end)
	end)
end

-- dropdown (camera mode, direction, detection, style)
local function dropdown(parent: Instance, pos: UDim2, options: {string}, current: string, onChange: (string) -> ())
	local idx = table.find(options, current) or 1
	local btn = new("TextButton", {
		Size = UDim2.fromOffset(96, 22), Position = pos,
		BackgroundColor3 = T.PanelAlt, Text = options[idx], TextColor3 = T.Text,
		TextSize = 11, Font = Enum.Font.GothamMedium, Parent = parent,
	}, {corner(6), stroke(T.Stroke)})
	btn.MouseButton1Click:Connect(function()
		idx = idx % #options + 1
		btn.Text = options[idx]
		onChange(options[idx])
	end)
end

-- // Page: Home ----------------------------------------------------------------------
do
	local page = pageFrames.Home
	-- engine status: is the Studio server half installed?
	local statusCard = card(page, 42, 0)
	local statusDot = new("Frame", {
		Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 12, 0.5, -5),
		BackgroundColor3 = T.Bad, BorderSizePixel = 0, Parent = statusCard,
	}, {corner(10)})
	local statusLabel = label("Checking game engine...", 12, T.TextDim, {
		Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 32, 0, 0),
		TextWrapped = true, Parent = statusCard,
	})
	task.spawn(function()
		while gui.Parent do
			local connected = ReplicatedStorage:FindFirstChild("EclipseRemotes") ~= nil
			if connected then
				statusDot.BackgroundColor3 = T.Good
				statusLabel.Text = "Game engine connected - techs will fire."
				statusLabel.TextColor3 = T.Good
			else
				statusDot.BackgroundColor3 = Color3.fromRGB(255, 190, 80)
				statusLabel.Text = "Engine not installed yet - techs won't fire. Do STUDIO_SETUP.md (10 min)."
				statusLabel.TextColor3 = Color3.fromRGB(255, 200, 120)
			end
			task.wait(2)
		end
	end)
	local c = card(page, 96, 1)
	local thumb = new("ImageLabel", {
		Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0, 12, 0.5, -32),
		BackgroundColor3 = T.PanelAlt, Parent = c,
	}, {corner(64), stroke(T.AccentEnd)})
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then thumb.Image = img else warn("[SoulSociety] avatar thumbnail failed to load (cosmetic only)") end
	end)
	label(LocalPlayer.DisplayName, 16, T.Text, {
		Size = UDim2.new(0, 200, 0, 22), Position = UDim2.new(0, 88, 0, 16),
		Font = Enum.Font.GothamBold, Parent = c,
	})
	local pingLabel = label("Ping: ...", 12, T.TextDim, {
		Size = UDim2.new(0, 200, 0, 18), Position = UDim2.new(0, 88, 0, 44), Parent = c,
	})
	task.spawn(function()
		while gui.Parent do
			local ok, ping = pcall(function()
				return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
			end)
			pingLabel.Text = "Ping: " .. (ok and tostring(ping) or "?") .. " ms"
			task.wait(3)
		end
	end)

	local info = card(page, 74, 2)
	label("Soul Society", 13, T.Text, {
		Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 0, 8),
		Font = Enum.Font.GothamBold, Parent = info,
	})
	label("Techs, macros and movement tuning for this game. Everything here runs on mechanics the server owns - configs save as JSON.", 11, T.TextDim, {
		Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 10, 0, 28),
		TextWrapped = true, Parent = info,
	})
end

-- // Page: Techs ----------------------------------------------------------------------
do
	local page = pageFrames.Techs
	local order = 0
	local currentCategory = nil
	for _, tech in ipairs(Techs.List) do
		order += 1
		if tech.category ~= currentCategory then
			currentCategory = tech.category
			sectionHeader(page, string.upper(currentCategory), order)
			order += 1
		end
		local params = Config.Techs[tech.id]
		if not params then continue end

		local c = card(page, 0, order) -- height set after we know the widgets
		c.Name = "techrow:" .. tech.name
		c.AutomaticSize = Enum.AutomaticSize.Y
		c.Size = UDim2.new(1, 0, 0, 0)
		new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = c})

		label(tech.name, 14, T.Text, {
			Size = UDim2.new(0.6, 0, 0, 20), Font = Enum.Font.GothamBold, Parent = c,
		})
		-- trigger badge
		label(tech.trigger == "auto" and "AUTO" or "BUTTON", 10,
			tech.trigger == "auto" and T.AccentStart or T.AccentEnd, {
			Size = UDim2.fromOffset(56, 16), Position = UDim2.new(1, -120, 0, 2),
			Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center,
			Parent = c,
		})
		toggle(c, UDim2.new(1, -52, 0, 0), params.Enabled, function(state)
			params.Enabled = state
		end)
		label(tech.description, 11, T.TextDim, {
			Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 22),
			TextWrapped = true, Parent = c,
		})

		local controls = new("Frame", {
			Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 56),
			BackgroundTransparency = 1, Parent = c,
		})
		if tech.trigger == "button" and params.Keybind then
			label("Key", 10, T.TextDim, {Size = UDim2.fromOffset(24, 22), Parent = controls})
			keybindButton(controls, UDim2.fromOffset(28, 2), params.Keybind, function(kc)
				params.Keybind = kc
				local engine = mod("EclipseTechEngine")
				engine.Rebind()
			end)
		end
		-- every tech: AUTO or BUTTON, his choice
		label("Mode", 10, T.TextDim, {Size = UDim2.fromOffset(34, 22), Position = UDim2.fromOffset(122, 0), Parent = controls})
		local currentMode = (params.Mode or tech.trigger):gsub("^%l", string.upper)
		dropdown(controls, UDim2.fromOffset(158, 2), {"Button", "Auto"}, currentMode, function(v)
			params.Mode = v
			local engine = mod("EclipseTechEngine")
			engine.Rebind()
			engine.RebindAuto()
		end)
		if params.CameraMode then
			dropdown(controls, UDim2.new(1, -96, 0, 2), {"Default", "Legit"}, params.CameraMode, function(v)
				params.CameraMode = v
			end)
		end

		-- one slider per numeric tuning param, in a stable order
		local sliderOrder = {"Delay", "Jump", "Spin", "DashStop", "JumpHeight", "StartDelay", "QPressDelay", "CameraDuration"}
		local sliderRanges = {
			Delay = {0, 2, 0.05}, Jump = {0, 100, 1}, Spin = {0, 360, 15},
			DashStop = {0, 1, 0.05}, JumpHeight = {0, 100, 1},
			StartDelay = {0, 2, 0.05}, QPressDelay = {0, 1, 0.05}, CameraDuration = {0, 2, 0.05},
		}
		local y = 84
		for _, key in ipairs(sliderOrder) do
			local v = params[key]
			if type(v) == "number" and sliderRanges[key] then
				local r = sliderRanges[key]
				local holder = new("Frame", {
					Size = UDim2.new(1, 0, 0, 52), Position = UDim2.new(0, 0, 0, y),
					BackgroundTransparency = 1, Parent = c,
				})
				slider(holder, 1, key, r[1], r[2], r[3], v, function(nv)
					params[key] = nv
				end)
				y += 56
			end
		end
	end
end

-- // Page: Macros -----------------------------------------------------------------------
do
	local page = pageFrames.Macros
	local engine_ok, MacroEngine = pcall(function()
		return mod("EclipseMacroEngine")
	end)
	sectionHeader(page, "PRESETS", 1)
	local all = engine_ok and MacroEngine.Presets or {}
	for i, m in ipairs(all) do
		local c = card(page, 64, i + 1)
		label(m.name, 13, T.Text, {
			Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.new(0, 10, 0, 8),
			Font = Enum.Font.GothamBold, Parent = c,
		})
		local parts = {}
		for _, s in ipairs(m.steps) do
			table.insert(parts, string.upper(s.kind) .. (s.dir and (" " .. string.upper(s.dir)) or s.t and (" " .. tostring(s.t)) or ""))
		end
		label(table.concat(parts, "  >  "), 10, T.TextDim, {
			Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 0, 32), Parent = c,
		})
		local runBtn = new("TextButton", {
			Size = UDim2.fromOffset(80, 24), Position = UDim2.new(1, -90, 0, 8),
			BackgroundColor3 = T.PanelAlt, Text = "TEST RUN", TextColor3 = T.AccentStart,
			TextSize = 11, Font = Enum.Font.GothamBold, Parent = c,
		}, {corner(6), stroke(T.Stroke)})
		runBtn.MouseButton1Click:Connect(function()
			if engine_ok then MacroEngine.Run(m) end
		end)
	end
	sectionHeader(page, "EDITOR", 10)
	do
		local editorCard = card(page, 0, 11)
		editorCard.AutomaticSize = Enum.AutomaticSize.Y
		editorCard.Size = UDim2.new(1, 0, 0, 0)
		new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = editorCard})
		new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = editorCard})

		local editorSteps = {}

		local function describeStep(st)
			if st.kind == "wait" then return ("WAIT %.2f"):format(st.t) end
			if st.kind == "dash" then return "DASH " .. string.upper(st.dir) end
			if st.kind == "move" then return "MOVE slot " .. tostring(st.slot) end
			if st.kind == "m1" then return "M1 x" .. tostring(st.count or 1) end
			if st.kind == "uppercut" then return "UPPERCUT" end
			if st.kind == "jump" then return "JUMP" end
			if st.kind == "camera" then return "CAMERA spin " .. tostring(st.degrees) end
			return string.upper(st.kind)
		end

		local stepsFrame = new("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, LayoutOrder = 1, Parent = editorCard,
		}, {
			new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
		})

		local function rebuildSteps()
			for _, ch in ipairs(stepsFrame:GetChildren()) do
				if ch.Name == "StepRow" then ch:Destroy() end
			end
			for i, st in ipairs(editorSteps) do
				local row = new("TextButton", {
					Name = "StepRow",
					Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.PanelAlt,
					Text = "  " .. i .. ". " .. describeStep(st) .. "   (tap to cycle)",
					TextColor3 = T.Text, TextSize = 11, Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = stepsFrame,
				}, {corner(6)})
				local del = new("TextButton", {
					Size = UDim2.fromOffset(22, 18), Position = UDim2.new(1, -26, 0.5, -9),
					BackgroundColor3 = T.Bad, Text = "X", TextColor3 = T.Text,
					TextSize = 10, Font = Enum.Font.GothamBold, Parent = row,
				}, {corner(5)})
				del.MouseButton1Click:Connect(function()
					table.remove(editorSteps, i)
					rebuildSteps()
				end)
				row.MouseButton1Click:Connect(function()
					if st.kind == "wait" then
						st.t = ((st.t or 0.1) + 0.05) % 1.0
						if st.t < 0.05 then st.t = 0.05 end
					elseif st.kind == "dash" then
						st.dir = ({front = "back", back = "left", left = "right", right = "front"})[st.dir]
					elseif st.kind == "move" then
						st.slot = (st.slot % 4) + 1
					elseif st.kind == "m1" then
						st.count = (st.count or 1) % 4 + 1
					elseif st.kind == "camera" then
						st.degrees = ((st.degrees or 180) % 360) + 90
					end
					rebuildSteps()
				end)
			end
		end

		local addGrid = new("Frame", {
			Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1,
			LayoutOrder = 2, Parent = editorCard,
		}, {
			new("UIGridLayout", {CellSize = UDim2.fromOffset(66, 22), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
		})
		local function addButton(text, mk)
			local b = new("TextButton", {
				Size = UDim2.fromOffset(66, 22), BackgroundColor3 = T.PanelAlt,
				Text = text, TextColor3 = T.AccentStart, TextSize = 10,
				Font = Enum.Font.GothamBold, Parent = addGrid,
			}, {corner(5)})
			b.MouseButton1Click:Connect(function()
				table.insert(editorSteps, mk())
				rebuildSteps()
			end)
		end
		addButton("+ JUMP", function() return {kind = "jump"} end)
		addButton("+ WAIT", function() return {kind = "wait", t = 0.1} end)
		addButton("+ DASH", function() return {kind = "dash", dir = "front"} end)
		addButton("+ MOVE", function() return {kind = "move", slot = 1} end)
		addButton("+ M1", function() return {kind = "m1", count = 1} end)
		addButton("+ UPPER", function() return {kind = "uppercut"} end)
		addButton("+ CAM", function() return {kind = "camera", degrees = 180} end)

		local nameBox = new("TextBox", {
			Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = T.PanelAlt,
			Text = "My Macro", TextColor3 = T.Text, TextSize = 12,
			Font = Enum.Font.Gotham, ClearTextOnFocus = false,
			LayoutOrder = 3, Parent = editorCard,
		}, {corner(6), stroke(T.Stroke)})

		local btnRow = new("Frame", {
			Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
			LayoutOrder = 4, Parent = editorCard,
		})
		local testBtn = new("TextButton", {
			Size = UDim2.new(0.48, 0, 1, 0), BackgroundColor3 = T.PanelAlt,
			Text = "TEST RUN", TextColor3 = T.AccentStart, TextSize = 11,
			Font = Enum.Font.GothamBold, Parent = btnRow,
		}, {corner(6), stroke(T.Stroke)})
		local saveBtn = new("TextButton", {
			Size = UDim2.new(0.48, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0),
			BackgroundColor3 = T.PanelAlt, Text = "SAVE", TextColor3 = T.Good,
			TextSize = 11, Font = Enum.Font.GothamBold, Parent = btnRow,
		}, {corner(6), stroke(T.Stroke)})
		testBtn.MouseButton1Click:Connect(function()
			if engine_ok and #editorSteps > 0 then
				MacroEngine.Run({id = "editor_preview", name = nameBox.Text, steps = editorSteps})
			end
		end)
		saveBtn.MouseButton1Click:Connect(function()
			if engine_ok and #editorSteps > 0 then
				MacroEngine.Save({
					id = "custom_" .. HttpService:GenerateGUID(false):sub(1, 8),
					name = nameBox.Text,
					steps = editorSteps,
				})
				table.clear(editorSteps)
				rebuildSteps()
				saveBtn.Text = "SAVED"
				task.delay(1, function() saveBtn.Text = "SAVE" end)
			end
		end)
	end
end

-- // Page: Movement ----------------------------------------------------------------------
do
	local page = pageFrames.Movement
	slider(page, 1, "Front Dash Speed", 20, 120, 5, Config.Movement.FrontDashSpeed, function(v)
		Config.Movement.FrontDashSpeed = v
	end)
	slider(page, 2, "Dash Distance", 40, 200, 5, Config.Movement.DashDistance, function(v)
		Config.Movement.DashDistance = v
	end)
	local cut = card(page, 40, 3)
	label("Front Dash Cut", 12, T.Text, {
		Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = cut,
	})
	toggle(cut, UDim2.new(1, -52, 0.5, -10), Config.Movement.FrontDashCut, function(state)
		Config.Movement.FrontDashCut = state
	end)
	slider(page, 4, "Cut Time", 0.1, 1, 0.05, Config.Movement.CutTime, function(v)
		Config.Movement.CutTime = v
	end)

	-- per-direction dash tuning; the server clamps and applies it per player
	local function pushMovement()
		local remotes = ReplicatedStorage:FindFirstChild("EclipseRemotes")
		local um = remotes and remotes:FindFirstChild("UpdateMovement")
		if um then
			um:FireServer({
				front = {speed = Config.Movement.FrontDashSpeed, duration = Config.Movement.DashDuration},
				left  = {speed = Config.Movement.SideDashSpeed,  duration = Config.Movement.SideDashDuration},
				right = {speed = Config.Movement.SideDashSpeed,  duration = Config.Movement.SideDashDuration},
				back  = {speed = Config.Movement.BackDashSpeed,  duration = Config.Movement.BackDashDuration},
			})
		end
	end
	task.delay(2, pushMovement) -- initial sync once remotes exist
	sectionHeader(page, "PER-DIRECTION DASHES", 5)
	slider(page, 6, "Side Dash Speed", 10, 200, 5, Config.Movement.SideDashSpeed, function(v)
		Config.Movement.SideDashSpeed = v
		pushMovement()
	end)
	slider(page, 7, "Side Dash Duration", 0.05, 1, 0.05, Config.Movement.SideDashDuration, function(v)
		Config.Movement.SideDashDuration = v
		pushMovement()
	end)
	slider(page, 8, "Back Dash Speed", 10, 200, 5, Config.Movement.BackDashSpeed, function(v)
		Config.Movement.BackDashSpeed = v
		pushMovement()
	end)
	slider(page, 9, "Front Dash Duration", 0.05, 1, 0.05, Config.Movement.DashDuration, function(v)
		Config.Movement.DashDuration = v
		pushMovement()
	end)
	pushMovement()
end

-- // Page: Assists -------------------------------------------------------------------------
do
	local page = pageFrames.Assists
	local fl = card(page, 64, 1)
	label("Face Lock", 13, T.Text, {
		Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.new(0, 10, 0, 8),
		Font = Enum.Font.GothamBold, Parent = fl,
	})
	label("Hold the key to snap toward the nearest live player.", 11, T.TextDim, {
		Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 30), Parent = fl,
	})
	toggle(fl, UDim2.new(1, -52, 0, 8), Config.Assists.FaceLock.Enabled, function(state)
		Config.Assists.FaceLock.Enabled = state
	end)
	keybindButton(fl, UDim2.new(1, -150, 0, 8), Config.Assists.FaceLock.Keybind, function(kc)
		Config.Assists.FaceLock.Keybind = kc
	end)

	local ad = card(page, 64, 2)
	label("Auto Dash", 13, T.Text, {
		Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.new(0, 10, 0, 8),
		Font = Enum.Font.GothamBold, Parent = ad,
	})
	label("Locks the nearest torso and steers your front dash through it.", 11, T.TextDim, {
		Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 30), Parent = ad,
	})
	toggle(ad, UDim2.new(1, -52, 0, 8), Config.Assists.AutoDash.Enabled, function(state)
		Config.Assists.AutoDash.Enabled = state
	end)
	dropdown(ad, UDim2.new(1, -150, 0, 34), {"V1", "V2"}, Config.Assists.AutoDash.Style, function(v)
		Config.Assists.AutoDash.Style = v
	end)

	local au = card(page, 64, 3)
	label("Auto Uppercut", 13, T.Text, {
		Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.new(0, 10, 0, 8),
		Font = Enum.Font.GothamBold, Parent = au,
	})
	label("Fires the uppercut macro on the last hit of your combo.", 11, T.TextDim, {
		Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 30), Parent = au,
	})
	toggle(au, UDim2.new(1, -52, 0, 8), Config.Assists.AutoUppercut.Enabled, function(state)
		Config.Assists.AutoUppercut.Enabled = state
	end)
	dropdown(au, UDim2.new(1, -150, 0, 34), {"Click", "Animation", "Both"}, Config.Assists.AutoUppercut.Detection, function(v)
		Config.Assists.AutoUppercut.Detection = v
	end)
end

-- // Page: Performance ----------------------------------------------------------------------
do
	local page = pageFrames.Performance
	local function perfToggle(order: number, name: string, key: string, apply: (boolean) -> ())
		local c = card(page, 40, order)
		label(name, 12, T.Text, {
			Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = c,
		})
		toggle(c, UDim2.new(1, -52, 0.5, -10), Config.Performance[key], function(state)
			Config.Performance[key] = state
			apply(state)
		end)
	end
	perfToggle(1, "Disable Shadows", "DisableShadows", function(state)
		Lighting.GlobalShadows = not state
	end)
	perfToggle(2, "Low Poly Mode", "LowPolyMode", function(state)
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("MeshPart") then d.RenderFidelity = state and Enum.RenderFidelity.Performance or Enum.RenderFidelity.Automatic end
		end
	end)
	perfToggle(3, "Disable Textures", "DisableTextures", function(state)
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("Texture") or d:IsA("Decal") then d.Transparency = state and 1 or 0 end
		end
	end)
	slider(page, 4, "FPS Cap", 60, 360, 10, Config.Performance.FpsCap, function(v)
		Config.Performance.FpsCap = v
		local ok = pcall(function() (setfpscap :: any)(v) end) -- executor-only; no-op in Studio
	end)
end

-- // Page: Settings ---------------------------------------------------------------------------
do
	local page = pageFrames.Settings
	local function actionButton(order: number, text: string, cb: () -> ())
		local b = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Panel,
			Text = text, TextColor3 = T.Text, TextSize = 13,
			Font = Enum.Font.GothamMedium, LayoutOrder = order, Parent = page,
		}, {corner(8), stroke(T.Stroke)})
		b.MouseButton1Click:Connect(cb)
	end
	actionButton(1, "Save Config", function()
		local json = Config.Serialize()
		local ok = pcall(function() (writefile :: any)("SoulSociety_config.json", json) end)
		-- in Studio: copy to clipboard so he can paste it anywhere
		if not ok then pcall(function() (setclipboard :: any)(json) end) end
	end)
	actionButton(2, "Reset Config to Defaults", function()
		Config.ResetToDefaults()
	end)
	actionButton(3, "Reset Character", function()
		local c = LocalPlayer.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h then h.Health = 0 end
	end)
	actionButton(4, "Destroy GUI", function()
		gui:Destroy()
	end)
	local mb = card(page, 40, 5)
	label("Mobile Buttons (on-screen tech pad)", 12, T.Text, {
		Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = mb,
	})
	toggle(mb, UDim2.new(1, -52, 0.5, -10), Config.Mobile.ForceShow, function(state)
		Config.Mobile.ForceShow = state
		if state then
			pcall(function()
				mod("EclipseMobileButtons").Start()
			end)
		end
	end)
	local da = card(page, 40, 6)
	label("Dash Announcements", 12, T.Text, {
		Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = da,
	})
	toggle(da, UDim2.new(1, -52, 0.5, -10), Config.Visuals.DashAnnounce, function(state)
		Config.Visuals.DashAnnounce = state
	end)

	-- named config presets: save / load / rename / delete the whole setup
	sectionHeader(page, "CONFIG PRESETS", 7)
	local presetCard = card(page, 176, 8)
	local presetListLabel = label("Saved: (none yet)", 11, T.TextDim, {
		Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 8), Parent = presetCard,
	})
	local function refreshPresets()
		local names = Config.ListPresets()
		presetListLabel.Text = #names > 0 and ("Saved: " .. table.concat(names, ", ")) or "Saved: (none yet)"
	end
	Config.LoadPresetsFromFile()
	refreshPresets()
	local presetName = new("TextBox", {
		Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 32),
		BackgroundColor3 = T.PanelAlt, Text = "my preset", TextColor3 = T.Text,
		TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, Parent = presetCard,
	}, {corner(6), stroke(T.Stroke)})
	local function presetBtn(text, pos, color, cb)
		local b = new("TextButton", {
			Size = UDim2.new(0.5, -14, 0, 26), Position = pos,
			BackgroundColor3 = T.PanelAlt, Text = text, TextColor3 = color,
			TextSize = 11, Font = Enum.Font.GothamBold, Parent = presetCard,
		}, {corner(6), stroke(T.Stroke)})
		b.MouseButton1Click:Connect(cb)
	end
	presetBtn("SAVE", UDim2.new(0, 10, 0, 66), T.Good, function()
		Config.SavePreset(presetName.Text)
		refreshPresets()
	end)
	presetBtn("LOAD", UDim2.new(0.5, 4, 0, 66), T.AccentStart, function()
		if Config.LoadPreset(presetName.Text) then refreshPresets() end
	end)
	presetBtn("RENAME", UDim2.new(0, 10, 0, 100), T.Text, function()
		local names = Config.ListPresets()
		if #names > 0 and Config.RenamePreset(names[#names], presetName.Text) then refreshPresets() end
	end)
	presetBtn("DELETE", UDim2.new(0.5, 4, 0, 100), T.Bad, function()
		Config.DeletePreset(presetName.Text)
		refreshPresets()
	end)
	label("Rename renames your most recent preset to the box name. Presets save to SoulSociety_presets.json with an executor; in Studio they last for the session.", 10, T.TextDim, {
		Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 134),
		TextWrapped = true, Parent = presetCard,
	})
end

-- // Start ---------------------------------------------------------------------------------------
function Hub.Start()
	showPage("Home")

	-- dash announcements: big popup + counter whenever you dash
	local dashCount = 0
	local announce = new("TextLabel", {
		Size = UDim2.fromOffset(300, 60), Position = UDim2.new(0.5, -150, 0, 60),
		BackgroundTransparency = 1, Text = "", TextColor3 = T.AccentStart,
		TextSize = 34, Font = Enum.Font.GothamBold, TextTransparency = 1, Parent = gui,
	})
	local function watchCharacter(c)
		c:GetAttributeChangedSignal("State"):Connect(function()
			if not Config.Visuals.DashAnnounce then return end
			if c:GetAttribute("State") == "Dashing" then
				dashCount += 1
				announce.Text = "DASH x" .. dashCount
				announce.TextTransparency = 0
				TweenService:Create(announce, TweenInfo.new(0.8), {TextTransparency = 1}):Play()
			end
		end)
	end
	if LocalPlayer.Character then watchCharacter(LocalPlayer.Character) end
	LocalPlayer.CharacterAdded:Connect(watchCharacter)
	local engine = mod("EclipseTechEngine")
	engine.Start()
	local ok, err = pcall(function()
		mod("EclipseMobileButtons").Start()
	end)
	if not ok then
		warn("[SoulSociety] mobile buttons failed to start: " .. tostring(err))
	end
	-- show/hide the whole window with the toggle key
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Config.Input.ToggleKey then
			main.Visible = not main.Visible
		end
	end)

	local toast = new("TextLabel", {
		Size = UDim2.fromOffset(340, 40), Position = UDim2.new(0.5, -170, 1, -90),
		BackgroundColor3 = T.Panel, BackgroundTransparency = 0.1,
		Text = "SOUL SOCIETY loaded", TextColor3 = T.AccentStart,
		TextSize = 16, Font = Enum.Font.GothamBold, Parent = gui,
	}, {corner(8)})
	task.delay(4, function()
		TweenService:Create(toast, TweenInfo.new(0.6), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
		task.wait(0.7)
		toast:Destroy()
	end)
	print("[SoulSociety] SOUL SOCIETY loaded - hub is on screen. Press " .. tostring(Config.Input.ToggleKey.Name) .. " to toggle.")
end

return Hub

--!strict
--[[
	EclipseMobileButtons.lua  (client)
	On-screen controls for touch players. Right side: M1 / DASH / BLOCK pads.
	Bottom strip: a button per favorite tech from Config.Mobile.Favorites,
	running the same tech programs the keybinds fire.

	Shows automatically on touch devices; Config.Mobile.ForceShow forces it
	on (Settings page toggle). Tapping a tech button is identical to pressing
	its keybind - the server validates everything the same way.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


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

local Mobile = {}
local started = false

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

function Mobile.Start()
	if started then return end
	if not (UserInputService.TouchEnabled or Config.Mobile.ForceShow) then return end
	started = true

	local remotes = ReplicatedStorage:FindFirstChild("EclipseRemotes")
	local function fire(name, ...)
		local r = remotes and remotes:FindFirstChild(name)
		if r then r:FireServer(...) else warn("[SoulSociety] mobile button: server remote '" .. name .. "' missing - install the server scripts") end
	end
	local engine = mod("EclipseTechEngine")

	local parent: Instance
	local ok, hui = pcall(function() return (gethui :: any)() end)
	parent = (ok and hui) or LocalPlayer:WaitForChild("PlayerGui")

	local gui = new("ScreenGui", {
		Name = "EclipseMobile",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Parent = parent,
	})

	-- // Combat pads (right side, above the default jump button) --------------
	local function pad(text: string, size: number, pos: UDim2, accent: Color3?): TextButton
		return new("TextButton", {
			Size = UDim2.fromOffset(size, size), Position = pos,
			BackgroundColor3 = T.Panel, BackgroundTransparency = 0.25,
			Text = text, TextColor3 = accent or T.Text, TextSize = 13,
			Font = Enum.Font.GothamBold, Parent = gui,
		}, {
			corner(size / 2),
			new("UIStroke", {Color = accent or T.AccentEnd, Transparency = 0.4, Thickness = 1.5}),
		})
	end

	local m1Btn = pad("M1", 64, UDim2.new(1, -150, 1, -220))
	m1Btn.MouseButton1Click:Connect(function()
		fire("M1")
	end)

	local dashBtn = pad("DASH", 64, UDim2.new(1, -230, 1, -170), T.AccentStart)
	dashBtn.MouseButton1Click:Connect(function()
		-- dash in the direction the player is currently moving; front by default
		local c = LocalPlayer.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local dir = "front"
		if h and h.MoveDirection.Magnitude > 0.1 then
			local root = c:FindFirstChild("HumanoidRootPart")
			if root then
				local look = root.CFrame.LookVector
				local dot = h.MoveDirection:Dot(look)
				local side = h.MoveDirection:Dot(root.CFrame.RightVector)
				if dot < -0.5 then dir = "back"
				elseif side > 0.5 then dir = "right"
				elseif side < -0.5 then dir = "left" end
			end
		end
		fire("Dash", dir)
	end)

	local blockBtn = pad("BLOCK", 56, UDim2.new(1, -150, 1, -300), T.AccentEnd)
	blockBtn.MouseButton1Down:Connect(function()
		fire("Block", true)
		blockBtn.BackgroundTransparency = 0
	end)
	blockBtn.MouseButton1Up:Connect(function()
		fire("Block", false)
		blockBtn.BackgroundTransparency = 0.25
	end)

	-- // Tech strip (bottom-left, horizontally scrollable) ---------------------
	local strip = new("ScrollingFrame", {
		Size = UDim2.new(0, 300, 0, 46), Position = UDim2.new(0, 12, 1, -60),
		BackgroundColor3 = T.Background, BackgroundTransparency = 0.35,
		ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X,
		Parent = gui,
	}, {
		corner(10),
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
		new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 6)}),
	})

	local order = 0
	for _, techId in ipairs(Config.Mobile.Favorites) do
		local tech = Techs.ById[techId]
		local params = Config.Techs[techId]
		if tech and params and tech.trigger == "button" then
			order += 1
			local b = new("TextButton", {
				Size = UDim2.fromOffset(64, 34), BackgroundColor3 = T.PanelAlt,
				Text = tech.name:gsub(" Cancel", ""):gsub("Backdash", "BDC"), -- compact labels
				TextColor3 = T.Text, TextSize = 10, Font = Enum.Font.GothamBold,
				TextWrapped = true, LayoutOrder = order, Parent = strip,
			}, {corner(8), new("UIStroke", {Color = T.AccentEnd, Transparency = 0.5, Thickness = 1})})
			b.MouseButton1Click:Connect(function()
				local live = Config.Techs[techId]
				if live and live.Enabled then
					task.spawn(engine.RunProgram, tech)
				end
			end)
		end
	end
end

return Mobile

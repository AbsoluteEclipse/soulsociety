--!strict
--[[
	EclipseTechEngine.lua  (client)
	Runs tech step programs: timed dash/jump/move/camera inputs fired through
	the game's own remotes, with live params from EclipseConfig. Also owns
	auto-triggers (4th-M1 macro, Press-Q-on-uppercut, ragdoll escape) driven
	by attributes the EclipseCombatCore sets on each player.

	Everything here is input timing + camera work inside HIS game. The server
	stays authoritative: it validates cooldowns, i-frames, ragdoll, damage.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
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
local camera = workspace.CurrentCamera

local Engine = {}
local ACTIVE_ACTION = "EclipseTechInput"

-- Remotes exist only when his server combat core is installed. Never
-- WaitForChild them here: a top-level yield would freeze the whole bundle
-- (invisible under an executor - no error, no hub). Resolve lazily instead.
local warnedRemote = {}
local function fireRemote(name, ...)
	local remotes = ReplicatedStorage:FindFirstChild("EclipseRemotes")
	local r = remotes and remotes:FindFirstChild(name)
	if not r then
		if not warnedRemote[name] then
			warnedRemote[name] = true
			warn("[SoulSociety] server remote '" .. name .. "' not found - combat actions need the server scripts (EclipseCombatCore) installed in his game")
		end
		return
	end
	r:FireServer(...)
end

-- // Character helpers ----------------------------------------------------
local function character()
	return LocalPlayer.Character
end

local function humanoid()
	local c = character()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function rootPart()
	local c = character()
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function isAlive()
	local h = humanoid()
	return h ~= nil and h.Health > 0
end

-- // Camera work ----------------------------------------------------------
-- Spin/flick the camera over a short window, then hand control back.
local function cameraSpin(degrees: number, duration: number)
	local startCf = camera.CFrame
	local yawPerFrame = math.rad(degrees) / math.max(1, math.floor(duration * 60))
	local elapsed = 0
	while elapsed < duration do
		local dt = RunService.RenderStepped:Wait()
		elapsed += dt
		camera.CFrame = camera.CFrame * CFrame.Angles(0, -yawPerFrame * (dt * 60), 0)
	end
	-- settle: keep final orientation (Legit mode) or ease back (Default)
	-- CameraMode param picks; Default eases back toward start.
end

local function cameraFlick()
	-- one fast 180 then back: the "flick" that shortens a front dash's travel
	local cf = camera.CFrame
	camera.CFrame = cf * CFrame.Angles(0, math.pi, 0)
	task.wait(0.05)
	camera.CFrame = camera.CFrame * CFrame.Angles(0, -math.pi, 0)
end

-- // Step execution -------------------------------------------------------
local function resolveParam(step, params, key)
	local p = step[key]
	if type(p) == "string" then return params[p] end
	return p
end

function Engine.RunProgram(tech)
	if not isAlive() then return end
	local params = Config.Techs[tech.id] or {}
	if tech.requiresMove and not Engine.HasMove(tech.requiresMove) then
		warn(("[Eclipse] %s needs the '%s' move - moveset not installed yet.")
			:format(tech.name, tech.requiresMove))
		return
	end

	-- Direction params (SidedashCancel.Direction, Oreo.Direction, ...)
	for _, step in ipairs(tech.steps) do
		if step.kind == "dash" then
			local dir = step.dir
			if params.Direction and (step.dir == "left" or step.dir == "right") then
				dir = string.lower(params.Direction)
			elseif tech.id == "RagdollEscape" and params.Direction then
				dir = string.lower(params.Direction)
			end
			fireRemote("Dash", dir)
			if params.FrontDashCut and step.dir == "front" then
				-- handled by dashStop steps; movement tuning lives server-side
			end
		elseif step.kind == "move" then
			fireRemote("UseMove", tonumber(resolveParam(step, params, "param")) or step.slot or params.MoveSlot or 1)
		elseif step.kind == "useMove" then
			fireRemote("UseMove", step.name)
		elseif step.kind == "m1" then
			for _ = 1, step.count or 1 do
				fireRemote("M1")
				task.wait(0.12)
			end
		elseif step.kind == "uppercut" then
			-- uppercut = jump + M1 timed as the finisher input of the chain
			fireRemote("M1", "uppercut")
		elseif step.kind == "downslam" then
			fireRemote("M1", "downslam")
		elseif step.kind == "jump" then
			if step.enableParam and params[step.enableParam] == false then
				-- skip: EnableJump off
			else
				local h = humanoid()
				if h then
					local power = resolveParam(step, params, "param")
					if tonumber(power) then
						local old = h.JumpPower
						h.JumpPower = power
						h.Jump = true
						task.delay(0.2, function()
							if h.Parent then h.JumpPower = old end
						end)
					else
						h.Jump = true
					end
				end
			end
		elseif step.kind == "wait" then
			task.wait(tonumber(resolveParam(step, params, "t") or resolveParam(step, params, "param")) or 0.05)
		elseif step.kind == "camera" then
			local mode = step.mode or "spin"
			if mode == "spin" then
				local deg = tonumber(resolveParam(step, params, "param")) or step.degrees or 180
				local dur = tonumber(params[step.durationParam or ""]) or 0.25
				task.spawn(cameraSpin, deg, dur)
			elseif step.mode == "flick" then
				task.spawn(cameraFlick)
			end
		elseif step.kind == "aim" then
			Engine.FaceNearest()
		elseif step.kind == "dashStop" then
			local t = tonumber(resolveParam(step, params, "param")) or 0.5
			task.delay(t, function()
				fireRemote("Dash", "stop")
			end)
		end
	end
end

-- // Move detection ---------------------------------------------------------
-- In his game the combat core tags moveset moves as attributes on the
-- character (e.g. character:GetAttribute("HasLethalWhirlwind")). Until a
-- moveset exists, character techs report the missing move instead of erroring.
function Engine.HasMove(moveName: string): boolean
	local c = character()
	if not c then return false end
	local v = c:GetAttribute("Has" .. moveName)
	return v == true
end

-- // Face nearest live player (Face Lock / aim steps) ----------------------
function Engine.FaceNearest(range: number?)
	local root = rootPart()
	if not root then return end
	local best, bestDist = nil, range or Config.Assists.FaceLock.Range
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character then
			local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local d = (hrp.Position - root.Position).Magnitude
				if d < bestDist then
					best, bestDist = hrp, d
				end
			end
		end
	end
	if best then
		local pos = best.Position
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(pos.X, root.Position.Y, pos.Z))
	end
end

-- // Auto triggers ----------------------------------------------------------
-- The combat core mirrors game state onto player attributes:
--   ComboCount (number, resets after ComboReset seconds)
--   State      ("Idle" | "Attacking" | "Dashing" | "Ragdolled" | "Stunned")
--   IFrames    (bool)
local conns = {}

local function onAttributeChanged(attr, fn)
	local c = character()
	if not c then return end
	table.insert(conns, c:GetAttributeChangedSignal(attr):Connect(function()
		fn(c:GetAttribute(attr))
	end))
end

local function bindAutoTriggers()
	for _, c in ipairs(conns) do c:Disconnect() end
	table.clear(conns)

	-- assist: auto uppercut on the last hit of the combo
	onAttributeChanged("ComboCount", function(count)
		local au = Config.Assists.AutoUppercut
		if au.Enabled and typeof(count) == "number" and count >= au.ComboLength then
			fireRemote("M1", "uppercut")
		end
	end)

	-- Twinnie's Press-Q param: dash input on uppercut landed
	onAttributeChanged("UppercutLanded", function(v)
		if v == true then
			local tw = Config.Techs.Twinnie
			if tw and tw.Enabled and tw.PressQ then
				task.wait(tw.QPressDelay or 0)
				fireRemote("Dash", "front")
			end
		end
	end)

	-- generic per-tech AUTO mode: every tech with Mode="Auto" (or an auto
	-- trigger by design) fires its program on its event.
	local lastCombo = 0
	for _, tech in ipairs(Techs.List) do
		local params = Config.Techs[tech.id]
		local mode = params and string.lower(params.Mode or tech.trigger)
		if params and mode == "auto" then
			local ev = tech.autoEvent or "uppercut"
			if ev == "combo" then -- Reflex: fires on each landed M1 (combo ticks 1-3)
				onAttributeChanged("ComboCount", function(c)
					if typeof(c) == "number" then
						if c > lastCombo and c < 4 and params.Enabled then
							Engine.RunProgram(tech)
						end
						lastCombo = c
					end
				end)
			elseif ev == "uppercut" then
				onAttributeChanged("UppercutLanded", function(v)
					if v == true and params.Enabled then Engine.RunProgram(tech) end
				end)
			elseif ev == "m1Final" then
				onAttributeChanged("ComboCount", function(c)
					if typeof(c) == "number" and c >= 4 and params.Enabled then
						Engine.RunProgram(tech)
					end
				end)
			elseif ev == "ragdolled" or ev == "stunned" then
				local wanted = ev == "ragdolled" and "Ragdolled" or "Stunned"
				onAttributeChanged("State", function(st)
					if st == wanted and params.Enabled then Engine.RunProgram(tech) end
				end)
			end
		end
	end
end
Engine.RebindAuto = bindAutoTriggers

-- // Input binding ----------------------------------------------------------
local function bindInputs()
	ContextActionService:UnbindAction(ACTIVE_ACTION)
	local keybinds = {}
	for _, tech in ipairs(Techs.List) do
		local params = Config.Techs[tech.id]
		local mode = params and string.lower(params.Mode or tech.trigger)
		if params and params.Keybind and mode == "button" then
			keybinds[params.Keybind] = tech
		end
	end
	ContextActionService:BindAction(ACTIVE_ACTION, function(_, state, input)
		if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		local tech = keybinds[input.KeyCode]
		if tech then
			local params = Config.Techs[tech.id]
			if params and params.Enabled then
				task.spawn(Engine.RunProgram, tech)
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, unpack((function()
		local codes = {}
		for kc in pairs(keybinds) do table.insert(codes, kc) end
		return codes
	end)()))
end

-- Rebind live when the hub changes a keybind.
function Engine.Rebind()
	bindInputs()
end

-- // Lifecycle --------------------------------------------------------------
function Engine.Start()
	bindInputs()
	bindAutoTriggers()
	LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.5)
		bindAutoTriggers()
	end)
end

return Engine

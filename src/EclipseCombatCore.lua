--!strict
--[[
	EclipseCombatCore.lua  (server, ModuleScript - call .Start() from one Script)
	The server-authoritative foundation of Jagger's battlegrounds game:
	M1 chains, directional dashes with i-frames, ragdoll + knockback physics,
	stun, block. Techs work because THIS code makes them work - they are
	intentional mechanics of his game, tunable from one config table.

	Design notes:
	- TechPhysics: when a close-range front dash hits a ragdolled/falling
	  target, knockback is damped (they enter the rolling state with nothing
	  to roll on). This is THE mechanic behind uppercut dash / twisted dash /
	  lethal extenders, implemented on purpose.
	- Ragdoll Cancel: dashing while ragdolled breaks the ragdoll. 30s cooldown
	  per player. The most important defensive mechanic in the genre.
	- The server validates everything (cooldowns, state, range). Clients ask;
	  the core decides.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Moveset = require(script.Parent:WaitForChild("EclipseMovesetHeroHunter"))

local Core = {}

-- // Tunables (his game, his rules) ----------------------------------------
Core.Config = {
	M1Damage = 4,
	M1Range = 5,
	M1Cooldown = 0.35,
	ComboReset = 1.28,          -- seconds before the M1 chain resets
	FinalHitKnockback = 60,

	DashCooldown = 3,           -- his design knob (hubs can't lower it - server owns it)
	DashSpeed = 60,             -- fallback front-dash speed
	DashDuration = 0.35,
	-- per-direction tuning; players can adjust within bounds via UpdateMovement
	DashSpeedByDir = {front = 60, back = 50, left = 55, right = 55},
	DashDurationByDir = {front = 0.35, back = 0.3, left = 0.3, right = 0.3},
	DashIFrameWindow = 0.15,    -- startup frames that cancel techs ride on
	DashDamage = 4,

	TechPhysics = true,         -- the flag that makes extension techs real
	TechPhysicsDamping = 0.15,  -- fraction of knockback kept on a tech-physics hit
	TechPhysicsRange = 6,       -- "close range" for the rolling-state interaction

	RagdollTime = 1.5,
	RagdollCancelCooldown = 30,

	BlockDamageReduction = 0.8,
	StunOnBlockBreak = 0.8,
}

-- // State ------------------------------------------------------------------
type PlayerState = {
	combo: number,
	lastM1: number,
	lastDash: number,
	lastRagdollCancel: number,
	state: string, -- "Idle" | "Attacking" | "Dashing" | "Ragdolled" | "Stunned"
	blocking: boolean,
}
local states: {[Player]: PlayerState} = {}
local moveCfg: {[Player]: {[string]: {speed: number, duration: number}}} = {}

local Remotes = Instance.new("Folder")
Remotes.Name = "EclipseRemotes"

local function makeRemote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end

local DashRemote = makeRemote("Dash")
local M1Remote = makeRemote("M1")
local MoveRemote = makeRemote("UseMove")
local UpdateMovementRemote = makeRemote("UpdateMovement")
local BlockRemote = makeRemote("Block")

-- // Helpers ------------------------------------------------------------------
local function rootOf(plr: Player): BasePart?
	local c = plr.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humOf(plr: Player): Humanoid?
	local c = plr.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function setState(plr: Player, s: string)
	local st = states[plr]
	if st then st.state = s end
	local c = plr.Character
	if c then c:SetAttribute("State", s) end
end

local function getState(plr: Player): PlayerState
	local st = states[plr]
	if not st then
		st = {combo = 0, lastM1 = 0, lastDash = 0, lastRagdollCancel = 0, state = "Idle", blocking = false}
		states[plr] = st
	end
	return st
end

local function setIFrames(plr: Player, on: boolean)
	local c = plr.Character
	if c then c:SetAttribute("IFrames", on) end
end

-- Push `targetRoot` away from `sourceRoot` with knockback, damping it when
-- the tech-physics interaction applies (close range + target airborne/ragdolled).
local function applyKnockback(sourceRoot: BasePart, targetRoot: BasePart, power: number, targetHum: Humanoid)
	local cfg = Core.Config
	local damped = false
	if cfg.TechPhysics then
		local dist = (targetRoot.Position - sourceRoot.Position).Magnitude
		local falling = targetRoot.AssemblyLinearVelocity.Y < -5
		local ragdolled = targetHum:GetState() == Enum.HumanoidStateType.Ragdoll
			or targetHum:GetState() == Enum.HumanoidStateType.FallingDown
		if dist <= cfg.TechPhysicsRange and (falling or ragdolled) then
			power *= cfg.TechPhysicsDamping
			damped = true
		end
	end
	local dir = (targetRoot.Position - sourceRoot.Position).Unit
	local lv = Instance.new("LinearVelocity")
	lv.MaxForce = Vector3.new(1e5, 0, 1e5)
	lv.VectorVelocity = dir * power + Vector3.new(0, damped and 5 or 25, 0)
	lv.Attachment0 = targetRoot:FindFirstChildOfClass("Attachment")
		or (function()
			local a = Instance.new("Attachment")
			a.Parent = targetRoot
			return a
		end)()
	lv.Parent = targetRoot
	game:GetService("Debris"):AddItem(lv, 0.25)
end

local function ragdoll(plr: Player, seconds: number)
	local hum = humOf(plr)
	if not hum then return end
	setState(plr, "Ragdolled")
	hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
	hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	task.delay(seconds, function()
		if hum.Parent and states[plr] and states[plr].state == "Ragdolled" then
			hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			setState(plr, "Idle")
		end
	end)
end

local function damage(target: Player, amount: number, source: Player?)
	local targetHum = humOf(target)
	if not targetHum or targetHum.Health <= 0 then return end
	local c = target.Character
	if c and c:GetAttribute("IFrames") then return end -- i-frames eat the hit
	local st = getState(target)
	local c2 = target.Character
	if c2 and c2:GetAttribute("CounterActive") and source then
		-- Apex Counter: negate the hit and return it
		local srcHum = humOf(source)
		if srcHum then srcHum:TakeDamage(amount * 2) end
		ragdoll(source, 1.2)
		return
	end
	if st.blocking then
		amount *= (1 - Core.Config.BlockDamageReduction)
	end
	targetHum:TakeDamage(amount)
end

-- // M1 chain -----------------------------------------------------------------
M1Remote.OnServerEvent:Connect(function(plr: Player, variant: string?)
	local st = getState(plr)
	local now = os.clock()
	if st.state == "Ragdolled" or st.state == "Stunned" or st.state == "Dashing" then return end
	if now - st.lastM1 < Core.Config.M1Cooldown then return end

	if now - st.lastM1 > Core.Config.ComboReset then
		st.combo = 0
	end
	st.lastM1 = now
	st.combo += 1
	setState(plr, "Attacking")

	local c = plr.Character
	if c then
		c:SetAttribute("ComboCount", st.combo)
		if variant == "uppercut" then
			c:SetAttribute("UppercutLanded", true)
			task.delay(0.1, function()
				if c.Parent then c:SetAttribute("UppercutLanded", false) end
			end)
		end
	end

	-- hitbox: parts in front of the root
	local root = rootOf(plr)
	if root then
		local cf = root.CFrame * CFrame.new(0, 0, -Core.Config.M1Range / 2)
		local parts = workspace:GetPartBoundsInBox(cf, Vector3.new(5, 5, Core.Config.M1Range))
		local hit = {}
		for _, part in ipairs(parts) do
			local model = part:FindFirstAncestorOfClass("Model")
			local targetPlr = model and Players:GetPlayerFromCharacter(model)
			if targetPlr and targetPlr ~= plr and not hit[targetPlr] then
				hit[targetPlr] = true
				damage(targetPlr, Core.Config.M1Damage, plr)
				local tRoot = rootOf(targetPlr)
				local tHum = humOf(targetPlr)
				if tRoot and tHum then
					if variant == "downslam" then
						-- downslam: short knockdown, low knockback
						applyKnockback(root, tRoot, 18, tHum)
						ragdoll(targetPlr, 1.0)
						st.combo = 0
						if c then c:SetAttribute("ComboCount", 0) end
					elseif st.combo >= 4 or variant == "uppercut" then
						-- 4th hit / uppercut: launch
						applyKnockback(root, tRoot, Core.Config.FinalHitKnockback, tHum)
						ragdoll(targetPlr, Core.Config.RagdollTime)
						st.combo = 0
						if c then c:SetAttribute("ComboCount", 0) end
					else
						applyKnockback(root, tRoot, 12, tHum)
					end
					-- block break: a blocked final hit stuns the blocker
					if (st.combo >= 4 or variant == "uppercut") and getState(targetPlr).blocking then
						setState(targetPlr, "Stunned")
						task.delay(Core.Config.StunOnBlockBreak, function()
							if states[targetPlr] and states[targetPlr].state == "Stunned" then
								setState(targetPlr, "Idle")
							end
						end)
					end
				end
			end
		end
	end
	task.delay(0.2, function()
		if states[plr] and states[plr].state == "Attacking" then setState(plr, "Idle") end
	end)
end)

-- // Dash ---------------------------------------------------------------------
-- dir: "front" | "back" | "left" | "right" | "stop"
DashRemote.OnServerEvent:Connect(function(plr: Player, dir: string)
	local st = getState(plr)
	local now = os.clock()
	local root = rootOf(plr)
	local hum = humOf(plr)
	if not root or not hum then return end

	if dir == "stop" then
		local lv = root:FindFirstChildOfClass("LinearVelocity")
		if lv then lv:Destroy() end
		if st.state == "Dashing" then setState(plr, "Idle") end
		setIFrames(plr, false)
		return
	end

	-- Ragdoll cancel: dashing out of ragdoll, 30s cooldown
	if st.state == "Ragdolled" then
		if now - st.lastRagdollCancel < Core.Config.RagdollCancelCooldown then return end
		st.lastRagdollCancel = now
		hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		setState(plr, "Idle")
		return
	end

	if st.state == "Stunned" or st.state == "Dashing" then return end
	if now - st.lastDash < Core.Config.DashCooldown then return end
	st.lastDash = now

	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local vec =
		if dir == "front" then look
		elseif dir == "back" then -look
		elseif dir == "left" then -right
		else right

	setState(plr, "Dashing")
	setIFrames(plr, true)
	task.delay(Core.Config.DashIFrameWindow, function() setIFrames(plr, false) end)

	local dirCfg = (moveCfg[plr] and moveCfg[plr][dir])
		or {speed = Core.Config.DashSpeedByDir[dir] or Core.Config.DashSpeed,
			duration = Core.Config.DashDurationByDir[dir] or Core.Config.DashDuration}

	local lv = Instance.new("LinearVelocity")
	lv.MaxForce = Vector3.new(1e5, 0, 1e5)
	lv.VectorVelocity = vec * dirCfg.speed
	local att = root:FindFirstChildOfClass("Attachment")
	if not att then
		att = Instance.new("Attachment")
		att.Parent = root
	end
	lv.Attachment0 = att
	lv.Parent = root
	game:GetService("Debris"):AddItem(lv, dirCfg.duration)

	-- dash contact: damage + the tech-physics knockback interaction
	task.delay(0.05, function()
		if not root.Parent then return end
		local parts = workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(4, 4, 4))
		local hit = {}
		for _, part in ipairs(parts) do
			local model = part:FindFirstAncestorOfClass("Model")
			local targetPlr = model and Players:GetPlayerFromCharacter(model)
			if targetPlr and targetPlr ~= plr and not hit[targetPlr] then
				hit[targetPlr] = true
				local tRoot = rootOf(targetPlr)
				local tHum = humOf(targetPlr)
				if tRoot and tHum and dir == "front" then
					damage(targetPlr, Core.Config.DashDamage, plr)
					applyKnockback(root, tRoot, 40, tHum)
				end
			end
		end
	end)

	task.delay(dirCfg.duration, function()
		if states[plr] and states[plr].state == "Dashing" then setState(plr, "Idle") end
	end)
end)

-- // Block ----------------------------------------------------------------------
BlockRemote.OnServerEvent:Connect(function(plr: Player, blocking: boolean)
	local st = getState(plr)
	st.blocking = blocking == true
end)

-- // Movement tuning (per-player, clamped - the server keeps the bounds) ----------
UpdateMovementRemote.OnServerEvent:Connect(function(plr: Player, settings: any)
	if type(settings) ~= "table" then return end
	moveCfg[plr] = moveCfg[plr] or {}
	for _, dir in ipairs({"front", "back", "left", "right"}) do
		local d = settings[dir]
		if type(d) == "table" then
			moveCfg[plr][dir] = {
				speed = math.clamp(tonumber(d.speed) or 60, 10, 200),
				duration = math.clamp(tonumber(d.duration) or 0.35, 0.05, 1),
			}
		end
	end
end)

-- // Moveset moves ---------------------------------------------------------------
-- Placeholder dispatch: when his moveset exists, move names map to functions
-- here. Character techs (Lethal, Kyoto) call these by name.
MoveRemote.OnServerEvent:Connect(function(plr: Player, slotOrName: any)
	local st = getState(plr)
	if st.state == "Ragdolled" or st.state == "Stunned" then return end
	-- Dispatch to the equipped moveset (Hero Hunter-style until he picks more).
	Moveset.Use(plr, slotOrName)
end)

-- // Lifecycle ---------------------------------------------------------------------
function Core.Start()
	Remotes.Parent = ReplicatedStorage
	Moveset.Init({
		Damage = damage,
		Knockback = applyKnockback,
		Ragdoll = ragdoll,
	})
	Players.PlayerRemoving:Connect(function(plr)
		states[plr] = nil
		moveCfg[plr] = nil
	end)
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(c)
			c:SetAttribute("ComboCount", 0)
			c:SetAttribute("State", "Idle")
			c:SetAttribute("IFrames", false)
		end)
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			plr.Character:SetAttribute("ComboCount", 0)
			plr.Character:SetAttribute("State", "Idle")
			plr.Character:SetAttribute("IFrames", false)
		end
	end
end

return Core

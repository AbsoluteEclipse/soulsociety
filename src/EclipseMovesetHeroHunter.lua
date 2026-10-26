--!strict
--[[
	EclipseMovesetHeroHunter.lua  (server ModuleScript)
	The first moveset for the game: a Hunter-style kit in the SPIRIT of
	Garou/Rampage (his gameplay videos all show it) with original names,
	original timings, original code.

	Moves:
	  1. Rushing Stream    - quick forward lunge strike (Flowing Water slot)
	  2. Vortex Rush       - spinning multi-hit AOE dash (Lethal Whirlwind slot)
	  3. Predator Grip     - short-range grab + slam (Hunter's Grasp slot)
	  4. Apex Counter      - brief counter stance (Prey's Peril slot)

	Wires into EclipseCombatCore through UseMove. Tags each character with
	Has<MoveName> attributes so character techs (Lethal Extender, Kyoto)
	unlock. The tech definitions reference the names "LethalWhirlwind" and
	"FlowingWater" - this module ALSO sets those aliases so the existing
	tech programs fire against this kit. When he picks different movesets,
	only this module changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Moveset = {}

Moveset.SlotNames = {
	[1] = "RushingStream",
	[2] = "VortexRush",
	[3] = "PredatorGrip",
	[4] = "ApexCounter",
}

-- attribute aliases the tech programs look for
Moveset.Aliases = {
	RushingStream = "FlowingWater",
	VortexRush = "LethalWhirlwind",
	PredatorGrip = "HuntersGrasp",
	ApexCounter = "PreysPeril",
}

local COOLDOWNS = {
	RushingStream = 6,
	VortexRush = 14,
	PredatorGrip = 12,
	ApexCounter = 18,
}

local lastUse: {[Player]: {[string]: number}} = {}

local function rootOf(plr: Player): BasePart?
	local c = plr.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function targetsInBox(cf: CFrame, size: Vector3, exclude: Player): {Player}
	local out = {}
	local parts = workspace:GetPartBoundsInBox(cf, size)
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		local plr = model and Players:GetPlayerFromCharacter(model)
		if plr and plr ~= exclude and not table.find(out, plr) then
			table.insert(out, plr)
		end
	end
	return out
end

-- These call back into the combat core's helpers via a registered hook so
-- damage/knockback/ragdoll stay consistent (set in Moveset.Init).
local Hooks: {
	Damage: (target: Player, amount: number, source: Player?) -> (),
	Knockback: (sourceRoot: BasePart, targetRoot: BasePart, power: number, targetHum: Humanoid) -> (),
	Ragdoll: (plr: Player, seconds: number) -> (),
} = nil :: any

local Moves = {}

-- 1. Rushing Stream: short lunge, single hit, sets up Kyoto's side-dash window
function Moves.RushingStream(plr: Player)
	local root = rootOf(plr)
	if not root then return end
	local lv = Instance.new("LinearVelocity")
	lv.MaxForce = Vector3.new(1e5, 0, 1e5)
	lv.VectorVelocity = root.CFrame.LookVector * 70
	lv.Attachment0 = root:FindFirstChildOfClass("Attachment")
	if not lv.Attachment0 then
		local a = Instance.new("Attachment")
		a.Parent = root
		lv.Attachment0 = a
	end
	lv.Parent = root
	game:GetService("Debris"):AddItem(lv, 0.3)
	task.delay(0.15, function()
		if not root.Parent then return end
		for _, target in ipairs(targetsInBox(root.CFrame * CFrame.new(0, 0, -4), Vector3.new(6, 5, 7), plr)) do
			local tRoot = rootOf(target)
			local tHum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			Hooks.Damage(target, 8, plr)
			if tRoot and tHum then Hooks.Knockback(root, tRoot, 25, tHum) end
		end
	end)
	-- Kyoto window: the instant the move ends, a side dash catches them
	plr.Character:SetAttribute("KyotoWindow", true)
	task.delay(0.9, function()
		if plr.Character then plr.Character:SetAttribute("KyotoWindow", false) end
	end)
end

-- 2. Vortex Rush: spinning multi-hit - the move Lethal Extender loops a dash after
function Moves.VortexRush(plr: Player)
	local root = rootOf(plr)
	if not root then return end
	for i = 1, 4 do
		task.wait(0.3)
		if not root.Parent then break end
		for _, target in ipairs(targetsInBox(root.CFrame, Vector3.new(10, 6, 10), plr)) do
			Hooks.Damage(target, 5, plr)
			local tRoot = rootOf(target)
			local tHum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if i == 4 and tRoot and tHum then
				-- final spin slams them down: this is the moment the extender tech catches
				Hooks.Knockback(root, tRoot, 30, tHum)
				Hooks.Ragdoll(target, 1.2)
			end
		end
	end
	plr.Character:SetAttribute("LethalWindow", true)
	task.delay(1.4, function()
		if plr.Character then plr.Character:SetAttribute("LethalWindow", false) end
	end)
end

-- 3. Predator Grip: grab the first target in front, slam them
function Moves.PredatorGrip(plr: Player)
	local root = rootOf(plr)
	if not root then return end
	local targets = targetsInBox(root.CFrame * CFrame.new(0, 0, -3), Vector3.new(4, 5, 5), plr)
	local target = targets[1]
	if not target then return end
	local tRoot = rootOf(target)
	if not tRoot then return end
	-- grab: lock them for the slam duration
	tRoot.Anchored = true
	Hooks.Damage(target, 10, plr)
	task.wait(0.6)
	if tRoot.Parent then
		tRoot.Anchored = false
		local tHum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if tHum then
			Hooks.Knockback(root, tRoot, 45, tHum)
			Hooks.Ragdoll(target, 1.5)
		end
	end
end

-- 4. Apex Counter: 1s stance; the next hit against you is negated and returned
function Moves.ApexCounter(plr: Player)
	local c = plr.Character
	if not c then return end
	c:SetAttribute("CounterActive", true)
	task.delay(1, function()
		if c.Parent then c:SetAttribute("CounterActive", false) end
	end)
end

-- // Dispatch (called by EclipseCombatCore's UseMove remote) ---------------------
function Moveset.Use(plr: Player, slotOrName: any): boolean
	local moveName = if type(slotOrName) == "number" then Moveset.SlotNames[slotOrName] else tostring(slotOrName)
	-- accept alias names too (tech programs fire "LethalWhirlwind")
	for real, alias in pairs(Moveset.Aliases) do
		if moveName == alias then moveName = real end
	end
	local fn = Moves[moveName]
	if not fn then return false end
	local now = os.clock()
	lastUse[plr] = lastUse[plr] or {}
	if now - (lastUse[plr][moveName] or 0) < (COOLDOWNS[moveName] or 5) then return false end
	lastUse[plr][moveName] = now
	task.spawn(fn, plr)
	return true
end

-- // Init ----------------------------------------------------------------------
-- hooks: table with Damage/Knockback/Ragdoll from the combat core.
function Moveset.Init(hooks)
	Hooks = hooks
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(c)
			-- tag the character so tech gating works
			c:SetAttribute("HasRushingStream", true)
			c:SetAttribute("HasVortexRush", true)
			c:SetAttribute("HasPredatorGrip", true)
			c:SetAttribute("HasApexCounter", true)
			c:SetAttribute("HasFlowingWater", true)   -- alias for Kyoto
			c:SetAttribute("HasLethalWhirlwind", true) -- alias for Lethal techs
			c:SetAttribute("HasHuntersGrasp", true)    -- alias for Uppercut Grasp
			c:SetAttribute("HasPreysPeril", true)      -- alias for Peril Twist
		end)
	end)
end

return Moveset

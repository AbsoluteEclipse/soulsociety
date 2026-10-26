--!strict
--[[
	EclipseMacroEngine.lua  (client)
	Step-sequence macros in the style his TSB HUB reference uses: a macro is
	a list of steps (JUMP / WAIT x / DASH dir / MOVE slot / M1 / UPPERCUT /
	CAMERA spin) that the TechEngine runs. Ships the three presets from his
	reference, lets the hub TEST RUN and SAVE new ones as JSON.
]]

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

local Macro = {}

-- Presets mirroring what he liked in the reference hub, built as our own steps.
Macro.Presets = {
	{
		id = "macro_uppercutdash", name = "Uppercut dash",
		steps = {
			{kind="jump"},
			{kind="wait", t=0.18},
			{kind="dash", dir="front"},
		},
	},
	{
		id = "macro_sidedashcancel", name = "Side dash cancel",
		steps = {
			{kind="dash", dir="left"},
			{kind="wait", t=0.05},
			{kind="move", slot=1},
		},
	},
	{
		id = "macro_m1uppercut", name = "M1 uppercut",
		steps = {
			{kind="m1", count=3},
			{kind="uppercut"},
		},
	},
}

-- Custom macros the player saves in the hub (loaded from JSON on Start).
Macro.Custom = {}

function Macro.Run(macroDef)
	local engine = mod("EclipseTechEngine")
	-- adapt macro steps into a throwaway tech program and reuse the engine
	local pseudo = {
		id = macroDef.id,
		name = macroDef.name,
		steps = macroDef.steps,
	}
	engine.RunProgram(pseudo)
end

function Macro.SerializeAll(): string
	return HttpService:JSONEncode(Macro.Custom)
end

function Macro.LoadFrom(json: string)
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	if ok and type(decoded) == "table" then
		Macro.Custom = decoded
	elseif not ok then
		warn("[SoulSociety] could not decode saved macros JSON (starting fresh): " .. tostring(decoded))
	end
end

function Macro.Save(macroDef)
	for i, m in ipairs(Macro.Custom) do
		if m.id == macroDef.id then
			Macro.Custom[i] = macroDef
			return
		end
	end
	table.insert(Macro.Custom, macroDef)
end

return Macro

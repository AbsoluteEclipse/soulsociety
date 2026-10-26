-- SOUL SOCIETY bootstrap (formerly Eclipse) (for players in HIS game, executor-style).
-- He hosts the /src modules on his OWN GitHub repo; this one line is what
-- players run. Format matches what he showed us; the code is 100% ours.
--
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/AbsoluteEclipse/soulsociety/main/src/bootstrap_loadstring.lua"))()

local BASE = "https://raw.githubusercontent.com/AbsoluteEclipse/soulsociety/main/src/"

local function loadModule(name)
	print("[SoulSociety] loading " .. name .. " ...")
	local src = game:HttpGet(BASE .. name .. ".lua")
	local chunk = loadstring(src, "=" .. name)
	local ok, result = pcall(chunk)
	if not ok then
		warn("[SoulSociety] FAILED to load " .. name .. ": " .. tostring(result))
		return nil
	end
	return result
end

-- The client bundle: config + tech defs + engine + hub.
-- (The combat core and moveset live in the game itself - he installs those
-- in Studio; players only ever run this client bundle.)
getgenv().SoulSocietyModules = getgenv().SoulSocietyModules or {}
local modules = getgenv().SoulSocietyModules

modules.EclipseConfig = modules.EclipseConfig or loadModule("EclipseConfig")
modules.Techs = modules.Techs or loadModule("Techs")
modules.EclipseTechEngine = loadModule("EclipseTechEngine")
modules.EclipseMacroEngine = loadModule("EclipseMacroEngine")
modules.EclipseMobileButtons = loadModule("EclipseMobileButtons")
modules.EclipseHub = loadModule("EclipseHub")

if modules.EclipseHub then
	modules.EclipseHub.Start()
else
	warn("[SoulSociety] hub module failed to load - see the FAILED line above")
end

--!strict
--[[
	EclipseDummy.server.lua  (server Script)
	Spawns a practice dummy at workspace.DummySpawn (a Part he places, or a
	default spot). The dummy stands, respawns 4s after dying, and mirrors the
	state attributes the combat core sets on players - so techs can be
	practiced against it exactly like against a person.
]]

local Workspace = game:GetService("Workspace")

local function spawnDummy()
	local spawnPart = Workspace:FindFirstChild("DummySpawn")
	local cf = spawnPart and spawnPart.CFrame or CFrame.new(0, 5, 0)

	local dummy = Instance.new("Model")
	dummy.Name = "PracticeDummy"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = cf
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = dummy

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.CFrame = cf
	torso.Color = Color3.fromRGB(220, 220, 230)
	torso.Parent = dummy

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 200
	hum.Health = 200
	hum.Parent = dummy

	dummy.PrimaryPart = root
	dummy:SetAttribute("ComboCount", 0)
	dummy:SetAttribute("State", "Idle")
	dummy:SetAttribute("IFrames", false)
	dummy.Parent = Workspace

	hum.Died:Connect(function()
		task.wait(4)
		dummy:Destroy()
		spawnDummy()
	end)
end

spawnDummy()

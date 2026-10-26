--!strict
--[[
	Techs.lua
	Declarative tech definitions. Each tech is metadata + a step program the
	EclipseTechEngine runs. Step params like {kind="wait", param="Delay"}
	resolve live against EclipseConfig.Techs[techId], so hub sliders always
	drive the real timing.

	Step kinds:
	  {kind="dash",    dir="front"|"back"|"left"|"right"}
	  {kind="move",    param="MoveSlot"}            -- fire a moveset move
	  {kind="m1",      count=number?}               -- basic attack input(s)
	  {kind="uppercut"}                               -- jump+M1 finisher input
	  {kind="jump",    param="Jump"?}               -- jump (power assist)
	  {kind="wait",    t=seconds | param="Delay"}
	  {kind="camera",  mode="spin"|"flick", param="Spin"?, durationParam="CameraDuration"?}
	  {kind="aim",     target="nearest"}            -- face nearest live player
	  {kind="dashStop", param="DashStop"}           -- cut the dash after t
	  {kind="useMove", name="LethalWhirlwind"}      -- named moveset move (character techs)

	trigger = "button" -> runs on keybind.
	trigger = "auto"   -> engine listens to autoEvent game state:
	                      "m1Final" (Nth M1 of chain), "uppercut", "ragdolled".
]]

local Techs = {}

Techs.List = {
	-- // Universal dash cancels ------------------------------------------
	{
		id = "BackdashCancel", name = "Backdash Cancel", category = "Cancels",
		trigger = "button",
		description = "Fire a move during backdash startup. The move cancels the dash but keeps its i-frames, so it can't be punished on startup.",
		steps = {
			{kind="dash", dir="back"},
			{kind="wait", param="Delay"},
			{kind="move", param="MoveSlot"},
		},
	},
	{
		id = "AerialBackdashCancel", name = "Aerial Backdash Cancel", category = "Cancels",
		trigger = "button",
		description = "Jump, then backdash cancel. Stretches the cancel's range with height.",
		steps = {
			{kind="jump", param="Jump"},
			{kind="wait", t=0.08},
			{kind="dash", dir="back"},
			{kind="wait", param="Delay"},
			{kind="move", param="MoveSlot"},
		},
	},
	{
		id = "SidedashCancel", name = "Side Dash Cancel", category = "Cancels",
		trigger = "button",
		description = "Side dash cancelled into a move. Repositions laterally before the hit; creates cross-ups.",
		steps = {
			{kind="dash", dir="left"}, -- Direction param flips this at runtime
			{kind="wait", param="Delay"},
			{kind="move", param="MoveSlot"},
		},
	},
	{
		id = "FrontdashCancel", name = "Front Dash Cancel", category = "Cancels",
		trigger = "button",
		description = "Front dash cancelled into a move. Instant gap-close into a combo starter; punishable if mistimed.",
		steps = {
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="move", param="MoveSlot"},
		},
	},

	-- // Extension techs --------------------------------------------------
	{
		id = "UppercutDash", name = "Uppercut Dash", category = "Extensions",
		trigger = "button",
		description = "Mini uppercut, then loop a front dash under the falling target. They roll into empty air, take almost no knockback, and stay in side-dash reach.",
		steps = {
			{kind="uppercut"},
			{kind="wait", param="Delay"},
			{kind="jump", param="Jump"},
			{kind="dash", dir="front"},
			{kind="camera", mode="spin", param="Spin", durationParam="CameraDuration"},
			{kind="dashStop", param="DashStop"},
		},
	},
	{
		id = "UppercutFlick", name = "Uppercut Flick", category = "Extensions",
		trigger = "button",
		description = "The easy Uppercut Dash: mini uppercut, then a flicked front dash that clips them as they float.",
		steps = {
			{kind="uppercut"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
			{kind="camera", mode="flick"},
		},
	},
	{
		id = "Floater", name = "Floater", category = "Extensions",
		trigger = "button",
		description = "Jump-boosted dash with an early dash stop. Keeps the target floating airborne for the extension.",
		steps = {
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="jump", param="Jump"},
			{kind="dashStop", param="DashStop"},
		},
	},
	{
		id = "Twinnie", name = "Twinnie", category = "Extensions",
		trigger = "button",
		description = "Dash-jump with a camera spin. Optional Press-Q assist fires the dash input automatically when your uppercut lands.",
		autoEvent = "uppercut", -- only used when the PressQ param is on
		steps = {
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="jump", param="Jump"},
			{kind="camera", mode="spin", param="Spin", durationParam="CameraDuration"},
		},
	},
	{
		id = "Oreo", name = "Oreo", category = "Extensions",
		trigger = "button",
		description = "Uppercut into an immediate side dash extension. Forgiving on both low and high ping.",
		steps = {
			{kind="uppercut"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="right"}, -- Direction param flips this at runtime
		},
	},
	{
		id = "Kakyo", name = "Kakyo", category = "Extensions",
		trigger = "button",
		description = "Front dash with a hard spin and an early stop. Fast, flashy extension.",
		steps = {
			{kind="dash", dir="front"},
			{kind="camera", mode="spin", param="Spin"},
			{kind="wait", param="Delay"},
			{kind="jump", param="Jump"},
			{kind="dashStop", param="DashStop"},
		},
	},
	{
		id = "LoopdashRework", name = "Loopdash Rework", category = "Extensions",
		trigger = "button",
		description = "Looping dash with a full spin and a timed stop. The classic loop dash, tightened.",
		steps = {
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="camera", mode="spin", param="Spin"},
			{kind="jump", param="Jump", enableParam="EnableJump"},
			{kind="dashStop", param="DashStop"},
		},
	},

	{
		id = "Supa", name = "Supa", category = "Extensions",
		trigger = "button",
		description = "Uppercut into a fast front dash with a jump boost and an early stop. Snappy extension from the creator-tech family.",
		steps = {
			{kind="uppercut"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
			{kind="jump", param="Jump"},
			{kind="dashStop", param="DashStop"},
		},
	},
	{
		id = "Wasp", name = "Wasp", category = "Extensions",
		trigger = "button",
		description = "Sting in from the side: a quick side dash chained straight into a front dash. Fastest opener of the family.",
		steps = {
			{kind="dash", dir="left"}, -- Direction param flips this at runtime
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
			{kind="jump", param="Jump"},
		},
	},
	{
		id = "KibaFloat", name = "Kiba 20% Float", category = "Extensions",
		trigger = "button",
		description = "Floater variant: high jump boost with a very early dash stop keeps them hanging at peak float for the extension.",
		steps = {
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="jump", param="Jump"},
			{kind="dashStop", param="DashStop"},
		},
	},

	-- // Universal techs (the community canon, original implementations) ----
	{
		id = "UppercutJump", name = "Uppercut Jump", category = "Universal",
		trigger = "button",
		description = "Three M1s, jump, instant uppercut. Opens the window for air extensions.",
		steps = {
			{kind="m1", count=3},
			{kind="jump", param="Jump"},
			{kind="uppercut"},
		},
	},
	{
		id = "UpsideDownRagdoll", name = "Upside Down Ragdoll", category = "Universal",
		trigger = "button",
		description = "Downslam the instant they rise from ragdoll - they over-rotate and eat the follow-up.",
		steps = {
			{kind="wait", param="Delay"},
			{kind="downslam"},
		},
	},
	{
		id = "StunNegation", name = "Stun Negation", category = "Universal",
		trigger = "auto", autoEvent = "stunned",
		description = "The instant you're stunned, a back dash cancels it. Turns their punish into your escape.",
		steps = {
			{kind="dash", dir="back"},
		},
	},
	{
		id = "DelayedM1s", name = "Delayed M1s", category = "Universal",
		trigger = "button",
		description = "An M1 chain with a beat between each hit - stretches their stun so the chain stays true.",
		steps = {
			{kind="m1"}, {kind="wait", param="Delay"},
			{kind="m1"}, {kind="wait", param="Delay"},
			{kind="m1"}, {kind="wait", param="Delay"},
			{kind="uppercut"},
		},
	},
	{
		id = "M1Shove", name = "M1 Shove", category = "Universal",
		trigger = "button",
		description = "M1 straight into a front dash shove. Quick push-through pressure.",
		steps = {
			{kind="m1"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
		},
	},
	{
		id = "WallExtend", name = "Wall Extend", category = "Universal",
		trigger = "button",
		description = "Three M1s, dash them into the wall, M1 as they roll. The wall keeps them in reach for the extension.",
		steps = {
			{kind="m1", count=3},
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="m1"},
		},
	},
	{
		id = "GroundPunch", name = "Ground Punch", category = "Universal",
		trigger = "button",
		description = "Wait a beat after they ragdoll, then start the M1 string as they rise to knock them straight back down.",
		steps = {
			{kind="wait", param="Delay"},
			{kind="m1", count=3},
		},
	},
	{
		id = "DMGChip", name = "DMG Chip", category = "Universal",
		trigger = "button",
		description = "A cut-short front dash into a single M1. Safe chip damage.",
		steps = {
			{kind="dash", dir="front"},
			{kind="dashStop", param="DashStop"},
			{kind="m1"},
		},
	},
	{
		id = "MicroDash", name = "Micro Dash", category = "Universal",
		trigger = "button",
		description = "The shortest possible dash - a tiny reposition that still carries the i-frame startup.",
		steps = {
			{kind="dash", dir="front"},
			{kind="dashStop", param="DashStop"},
		},
	},
	{
		id = "Headwalk", name = "Headwalk", category = "Universal",
		trigger = "button",
		description = "High jump onto their head, downslam on the way down.",
		steps = {
			{kind="jump", param="Jump"},
			{kind="wait", param="Delay"},
			{kind="downslam"},
		},
	},
	{
		id = "TrueDownslam", name = "True Downslam", category = "Universal",
		trigger = "button",
		description = "A frame-tight downslam that always lands its knockdown.",
		steps = {
			{kind="wait", param="Delay"},
			{kind="downslam"},
		},
	},
	{
		id = "TrashyEscapePlan", name = "Trashy Escape Plan", category = "Universal",
		trigger = "button",
		description = "Back dash out and hop away. Ugly, effective, gone.",
		steps = {
			{kind="dash", dir="back"},
			{kind="jump", param="Jump"},
		},
	},
	{
		id = "BenchJump", name = "Bench-Jump", category = "Universal",
		trigger = "button",
		description = "Jump into a flicked front dash - hops obstacles and closes distance weird.",
		steps = {
			{kind="jump", param="Jump"},
			{kind="dash", dir="front"},
			{kind="camera", mode="flick"},
		},
	},

	{
		id = "HeadRide", name = "Head Ride", category = "Universal",
		trigger = "button",
		description = "Jump high onto their head, ride it with a micro dash, downslam off. Hard to block coming from above.",
		steps = {
			{kind="jump", param="Jump"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
			{kind="dashStop", t=0.15},
			{kind="downslam"},
		},
	},
	{
		id = "OneEightyUppercut", name = "180 Uppercut", category = "Universal",
		trigger = "button",
		description = "Uppercut with a 180 camera spin mid-swing - the spin whips the hit around their guard.",
		steps = {
			{kind="uppercut"},
			{kind="camera", mode="spin", param="Spin", durationParam="CameraDuration"},
		},
	},
	{
		id = "Surf", name = "Surf Tech", category = "Universal",
		trigger = "button",
		description = "Dash onto a ragdolled target and ride the knockback wave, hopping off with a jump.",
		steps = {
			{kind="dash", dir="front"},
			{kind="dashStop", param="DashStop"},
			{kind="jump", param="Jump"},
		},
	},
	{
		id = "Reflex", name = "Reflex", category = "Universal",
		trigger = "auto", autoEvent = "combo",
		description = "Every time your M1 lands, an instant micro side dash repositions you. Pure reflex, zero thought.",
		steps = {
			{kind="dash", dir="right"}, -- Direction param flips this at runtime
			{kind="dashStop", t=0.1},
		},
	},

	-- // Creator techs (the named variants from his hubs) --------------------
	{
		id = "TwinnieV2", name = "Twinnie V2", category = "Creator",
		trigger = "button",
		description = "Twinnie tightened: faster delay, higher jump, quicker camera.",
		steps = {
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="jump", param="Jump"},
			{kind="camera", mode="spin", param="Spin", durationParam="CameraDuration"},
		},
	},
	{
		id = "TwinnieDash", name = "Twinnie Dash", category = "Creator",
		trigger = "button",
		description = "Twinnie as a pure dash - no jump, just the spin.",
		steps = {
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="camera", mode="spin", param="Spin"},
		},
	},
	{
		id = "Solitude", name = "Solitude", category = "Creator",
		trigger = "button",
		description = "Dash-jump with a quarter spin. Clean and quiet.",
		steps = {
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="jump", param="Jump"},
			{kind="camera", mode="spin", param="Spin"},
		},
	},
	{
		id = "Xcz", name = "Xcz", category = "Creator",
		trigger = "button",
		description = "Dash-jump with a timed stop. The sleeper pick from the Lunar list.",
		steps = {
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="jump", param="Jump"},
			{kind="dashStop", param="DashStop"},
		},
	},
	{
		id = "Kyo", name = "Kyo Tech", category = "Creator",
		trigger = "button",
		description = "Side dash with a full spin and a stop. Stylish lateral extension.",
		steps = {
			{kind="dash", dir="left"}, -- Direction param flips this at runtime
			{kind="camera", mode="spin", param="Spin"},
			{kind="dashStop", param="DashStop"},
		},
	},
	{
		id = "Lixxit", name = "Lixxit", category = "Creator",
		trigger = "button",
		description = "Front dash with a camera flick and a late jump. Slippery.",
		steps = {
			{kind="dash", dir="front"},
			{kind="camera", mode="flick"},
			{kind="wait", param="Delay"},
			{kind="jump", param="Jump"},
		},
	},
	{
		id = "Dripz", name = "Dripz Tech", category = "Creator",
		trigger = "button",
		description = "Uppercut into a side dash, legit camera style. Oreo's mirror twin.",
		steps = {
			{kind="uppercut"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="right"}, -- Direction param flips this at runtime
		},
	},
	{
		id = "K1ng", name = "K1ng Tech", category = "Creator",
		trigger = "button",
		description = "Front dash with a full 360 spin and a hard stop. Maximum style.",
		steps = {
			{kind="dash", dir="front"},
			{kind="camera", mode="spin", param="Spin"},
			{kind="dashStop", param="DashStop"},
		},
	},

	{
		id = "SupaV2", name = "Supa V2", category = "Creator",
		trigger = "button",
		description = "Supa with a higher boost and a tighter stop.",
		steps = {
			{kind="uppercut"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
			{kind="jump", param="Jump"},
			{kind="dashStop", param="DashStop"},
		},
	},
	{
		id = "Notpaki", name = "Notpaki", category = "Creator",
		trigger = "button",
		description = "Front dash with a 270 spin and a hard stop. Flashy creator variant.",
		steps = {
			{kind="dash", dir="front"},
			{kind="camera", mode="spin", param="Spin"},
			{kind="dashStop", param="DashStop"},
		},
	},
	{
		id = "MiniUppercutDash", name = "Mini Uppercut Dash", category = "Creator",
		trigger = "button",
		description = "Mini uppercut into an instant cut-short front dash. The classic tutorial opener.",
		steps = {
			{kind="uppercut"},
			{kind="dash", dir="front"},
			{kind="dashStop", param="DashStop"},
		},
	},

	{
		id = "TreeTwisted", name = "Tree Twisted", category = "Creator",
		trigger = "button",
		description = "Treetsb-style twisted: instant dash after your M1 with a jump boost and full spin, so they stay floating in reach.",
		steps = {
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
			{kind="jump", param="Jump"},
			{kind="camera", mode="spin", param="Spin", durationParam="CameraDuration"},
		},
	},
	{
		id = "TreeLoop", name = "Tree Loop", category = "Creator",
		trigger = "button",
		description = "Treetsb-style loop chain: loop dash with a jump and a late stop, his gameplay-flow finisher.",
		steps = {
			{kind="dash", dir="front"},
			{kind="wait", param="Delay"},
			{kind="camera", mode="spin", param="Spin"},
			{kind="jump", param="Jump"},
			{kind="dashStop", param="DashStop"},
		},
	},

	-- // Character techs (gated on moveset moves) -------------------------
	{
		id = "Lethal", name = "Lethal Extender", category = "Character",
		trigger = "button", requiresMove = "LethalWhirlwind",
		description = "Right after Lethal Whirlwind Stream, loop a front dash to catch them before they escape. They land in side-dash reach.",
		steps = {
			{kind="useMove", name="LethalWhirlwind"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
			{kind="jump", param="Jump"},
			{kind="camera", mode="spin", param="Spin"},
		},
	},
	{
		id = "LoopLethal", name = "Loop Lethal", category = "Character",
		trigger = "button", requiresMove = "LethalWhirlwind",
		description = "Looping lethal extender with a quarter spin and a timed stop.",
		steps = {
			{kind="useMove", name="LethalWhirlwind"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
			{kind="camera", mode="spin", param="Spin"},
			{kind="dashStop", param="DashStop"},
		},
	},
	{
		id = "Kyoto", name = "Kyoto", category = "Character",
		trigger = "button", requiresMove = "FlowingWater",
		description = "Side dash (or backdash cancel) the instant Flowing Water ends, sweeping them into Lethal Whirlwind Stream.",
		steps = {
			{kind="useMove", name="FlowingWater"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="left"},
			{kind="useMove", name="LethalWhirlwind"},
		},
	},

	{
		id = "TwistedDash", name = "Twisted Dash", category = "Character",
		trigger = "auto", autoEvent = "m1Final",
		description = "Fires itself right after your 4th M1 lands: dash catches them mid-roll with almost no knockback, combo extends. The 'instant twisted' from his hub.",
		steps = {
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
			{kind="camera", mode="spin", param="Spin"},
		},
	},
	{
		id = "WhirlwindFlickDash", name = "Whirlwind Flick-Dash", category = "Character",
		trigger = "button", requiresMove = "LethalWhirlwind",
		description = "The flick-input Vortex extender: jump through the slam, flicked front dash catches them as they drop.",
		steps = {
			{kind="useMove", name="LethalWhirlwind"},
			{kind="wait", param="Delay"},
			{kind="jump", param="Jump"},
			{kind="dash", dir="front"},
			{kind="camera", mode="flick"},
		},
	},
	{
		id = "CurveDash", name = "Curve Dash", category = "Character",
		trigger = "button",
		description = "Four M1s, side dash behind them as they fall, ability from the blind side.",
		steps = {
			{kind="m1", count=4},
			{kind="dash", dir="right"}, -- Direction param flips this at runtime
			{kind="wait", param="Delay"},
			{kind="move", param="MoveSlot"},
		},
	},
	{
		id = "PerilTwist", name = "Peril Twist", category = "Character",
		trigger = "button", requiresMove = "PreysPeril",
		description = "Apex Counter with a twisted side dash - counter stance while you slide off their screen.",
		steps = {
			{kind="useMove", name="PreysPeril"},
			{kind="dash", dir="left"}, -- Direction param flips this at runtime
			{kind="camera", mode="spin", param="Spin"},
		},
	},
	{
		id = "FlowingDash", name = "Flowing Dash", category = "Character",
		trigger = "button", requiresMove = "FlowingWater",
		description = "Rushing Stream chained straight into a front dash - the lunge carries the dash's momentum.",
		steps = {
			{kind="useMove", name="FlowingWater"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
		},
	},
	{
		id = "UppercutGrasp", name = "Uppercut Grasp", category = "Character",
		trigger = "button", requiresMove = "HuntersGrasp",
		description = "Three M1s, jump, mini uppercut, Predator Grip. The fastest reliable grab confirm.",
		steps = {
			{kind="m1", count=3},
			{kind="jump", param="Jump"},
			{kind="uppercut"},
			{kind="useMove", name="HuntersGrasp"},
		},
	},

	{
		id = "LethalRevamp", name = "Lethal Revamp", category = "Character",
		trigger = "button", requiresMove = "LethalWhirlwind",
		description = "Vortex Rush with the revamp timing: shorter wait, dash with a quarter spin.",
		steps = {
			{kind="useMove", name="LethalWhirlwind"},
			{kind="wait", param="Delay"},
			{kind="dash", dir="front"},
			{kind="camera", mode="spin", param="Spin"},
			{kind="dashStop", param="DashStop"},
		},
	},

	-- // Defense -----------------------------------------------------------
	{
		id = "RagdollEscape", name = "Ragdoll Cancel", category = "Defense",
		trigger = "auto", autoEvent = "ragdolled",
		description = "Breaks ragdoll instantly with a dash. Server enforces a 30s cooldown - save it for the hits that matter.",
		steps = {
			{kind="dash", dir="back"}, -- Direction param flips this at runtime
		},
	},
}

Techs.ById = {}
for _, tech in ipairs(Techs.List) do
	Techs.ById[tech.id] = tech
end

return Techs

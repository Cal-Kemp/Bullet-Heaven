extends RefCounted
## All the game's tuning numbers live here.

const CURRENCY := "cr"
const FINAL_GOAL := 1000          # heavy shells to deliver to finish the war contract
const START_POWER := 3            # the old hand-crank dynamo
const AUTO_GROWTH := 2.0          # each further automated step costs x2
const SPEED_BASE := 5.0           # speed upgrade cost = auto_base * 5 * 1.8^level
const SPEED_GROWTH := 1.8
const SPEED_MULT := 1.25          # each speed level makes a line 25% faster
const LINE_BASE := 8.0            # extra line cost = auto_base * 8 * 1.7^(lines-1)
const LINE_GROWTH := 1.7
const OFFLINE_CAP := 4.0 * 3600.0 # at most 4 hours of offline production
const OFFLINE_RATE := 0.5         # offline production runs at half speed

# Each product is one workbench. Steps are worked left-to-right along the bench;
# automation takes steps over from the left.
# case / proj = [radius, height] in metres for the work-piece model on the bench.
const PRODUCTS := [
	{
		"id": "pistol", "name": "Pistol Cartridges", "unit": "rounds",
		"value": 1.0, "step_time": 0.5, "clicks": 1, "power": 1, "unlock": 0.0, "auto_base": 8.0,
		"requires": [], "pos": Vector3(-14, 0, -9), "crate": 50,
		"steps": ["Measure powder", "Seat bullet", "Crimp case", "Pack in box"],
		"machines": ["Powder hopper", "Bullet feeder", "Crimping press", "Boxing chute"],
		"case": [0.022, 0.07], "case_col": Color(0.8, 0.62, 0.26),
		"proj": [0.02, 0.04], "proj_col": Color(0.72, 0.42, 0.25), "count": 1, "show_scale": 2.2,
		"desc": "Small rounds for sidearms and sub-machine guns.",
	},
	{
		"id": "rifle", "name": "Rifle Cartridges", "unit": "rounds",
		"value": 8.0, "step_time": 0.8, "clicks": 1, "power": 1, "unlock": 150.0, "auto_base": 70.0,
		"requires": [], "pos": Vector3(-7, 0, -9), "crate": 20,
		"steps": ["Charge powder", "Seat bullet", "Crimp neck", "Load clip"],
		"machines": ["Charging hopper", "Bullet seater", "Neck crimper", "Clip loader"],
		"case": [0.022, 0.13], "case_col": Color(0.8, 0.62, 0.26),
		"proj": [0.016, 0.07], "proj_col": Color(0.72, 0.42, 0.25), "count": 1, "show_scale": 1.6,
		"desc": "Standard infantry rifle rounds, loaded into five-round clips.",
	},
	{
		"id": "mg", "name": "Machine-Gun Belts", "unit": "belts",
		"value": 60.0, "step_time": 1.2, "clicks": 2, "power": 2, "unlock": 2500.0, "auto_base": 600.0,
		"requires": ["lights"], "pos": Vector3(0, 0, -9), "crate": 5,
		"steps": ["Feed rounds", "Link belt", "Inspect belt", "Pack ammo tin"],
		"machines": ["Round feeder", "Belt linker", "Gauge inspector", "Tin packer"],
		"case": [0.022, 0.13], "case_col": Color(0.78, 0.6, 0.25),
		"proj": [0.016, 0.07], "proj_col": Color(0.55, 0.35, 0.22), "count": 3, "show_scale": 1.6,
		"desc": "Linked belts for machine guns. Precise work: needs proper lighting.",
	},
	{
		"id": "mortar", "name": "Mortar Bombs", "unit": "bombs",
		"value": 450.0, "step_time": 2.0, "clicks": 2, "power": 3, "unlock": 30000.0, "auto_base": 5000.0,
		"requires": ["roof"], "pos": Vector3(7, 0, -9), "crate": 4,
		"steps": ["Cast body", "Fill charge", "Fit tail fins", "Fuze & crate"],
		"machines": ["Casting mould", "Charge filler", "Fin press", "Fuze setter"],
		"case": [0.02, 0.12], "case_col": Color(0.4, 0.42, 0.38),
		"proj": [0.05, 0.22], "proj_col": Color(0.33, 0.37, 0.24), "count": 1,
		"desc": "High-explosive bombs for infantry mortars. Keep them dry: needs a sound roof.",
	},
	{
		"id": "at", "name": "Anti-Tank Shells", "unit": "shells",
		"value": 3500.0, "step_time": 3.0, "clicks": 3, "power": 4, "unlock": 250000.0, "auto_base": 40000.0,
		"requires": ["floor"], "pos": Vector3(-10, 0, 0), "crate": 2,
		"steps": ["Draw casing", "Fill propellant", "Seat projectile", "Crate shell"],
		"machines": ["Drawing press", "Propellant filler", "Projectile seater", "Crating rig"],
		"case": [0.045, 0.32], "case_col": Color(0.8, 0.6, 0.25),
		"proj": [0.038, 0.2], "proj_col": Color(0.15, 0.15, 0.15), "count": 1,
		"desc": "Armour-piercing rounds for anti-tank guns. Heavy presses need a reinforced floor.",
	},
	{
		"id": "tank", "name": "Tank Shells", "unit": "shells",
		"value": 28000.0, "step_time": 4.5, "clicks": 3, "power": 6, "unlock": 2500000.0, "auto_base": 400000.0,
		"requires": ["crane"], "pos": Vector3(0, 0, 0), "crate": 1,
		"steps": ["Press casing", "Fill propellant", "Seat projectile", "Rack shell"],
		"machines": ["Hydraulic press", "Propellant filler", "Projectile seater", "Racking hoist"],
		"case": [0.055, 0.42], "case_col": Color(0.8, 0.6, 0.25),
		"proj": [0.047, 0.28], "proj_col": Color(0.32, 0.36, 0.22), "count": 1,
		"desc": "Main-gun rounds for tanks. Too heavy to lift by hand: needs the gantry crane.",
	},
	{
		"id": "heavy", "name": "Heavy Artillery Shells", "unit": "shells",
		"value": 250000.0, "step_time": 6.0, "clicks": 4, "power": 8, "unlock": 25000000.0, "auto_base": 1500000.0,
		"requires": ["crane", "rail"], "pos": Vector3(10, 0, 0), "crate": 1,
		"steps": ["Forge shell body", "Pour explosive", "Fit driving band", "Fuze & hoist"],
		"machines": ["Forging hammer", "Explosive pourer", "Band press", "Fuze & hoist rig"],
		"case": [0.08, 0.48], "case_col": Color(0.3, 0.34, 0.22),
		"proj": [0.08, 0.26], "proj_col": Color(0.3, 0.34, 0.22), "count": 1,
		"desc": "Huge shells for the big guns. Shipped by rail only.",
	},
]

# One-off warehouse repairs. "bonus" adds to the factory-wide output multiplier.
const REPAIRS := [
	{"id": "rubble", "name": "Clear the rubble", "cost": 15.0, "bonus": 0.05,
		"desc": "Shovel out the broken brick and timber. Room to breathe."},
	{"id": "roof", "name": "Patch the roof", "cost": 250.0, "bonus": 0.10,
		"desc": "Skylight sheets over the holes. No more rain on the powder."},
	{"id": "lights", "name": "Rewire the lamps", "cost": 1000.0, "bonus": 0.10,
		"desc": "Get the overhead lamps working again."},
	{"id": "windows", "name": "Glaze the windows", "cost": 5000.0, "bonus": 0.10,
		"desc": "Prise off the boards and fit new glass."},
	{"id": "paint", "name": "Paint & stencil signage", "cost": 20000.0, "bonus": 0.15,
		"desc": "Fresh paint, safety lines and proper signs. Looks like a real works now."},
	{"id": "dock", "name": "Repair the loading dock", "cost": 80000.0, "bonus": 0.25,
		"desc": "Fix the shutter and hire a lorry. Opens the yard outside."},
	{"id": "floor", "name": "Reinforce the floor", "cost": 200000.0, "bonus": 0.10,
		"desc": "Steel plate on fresh concrete. Needed for anti-tank presses."},
	{"id": "canteen", "name": "Workers' canteen", "cost": 800000.0, "bonus": 0.20,
		"desc": "Tea, stew and a sit-down. Happier crews work faster."},
	{"id": "crane", "name": "Overhead gantry crane", "cost": 1500000.0, "bonus": 0.15,
		"desc": "Lifts the big shells. Needed for tank and artillery shells."},
	{"id": "shelter", "name": "Sandbags & blackout", "cost": 5000000.0, "bonus": 0.20,
		"desc": "Blast walls, blackout curtains and a shelter. Work goes on through the raids."},
	{"id": "rail", "name": "Railway siding", "cost": 12000000.0, "bonus": 0.50,
		"desc": "A spur line to the main railway. Needed for heavy artillery shells."},
]

const POWER := [
	{"id": "diesel", "name": "Diesel generator", "cost": 120.0, "power": 10,
		"desc": "A rattling old generator from a scrapyard."},
	{"id": "boiler", "name": "Coal boiler & turbine", "cost": 12000.0, "power": 20,
		"desc": "Steam power. Hot, loud and reliable."},
	{"id": "grid", "name": "Mains grid connection", "cost": 200000.0, "power": 40,
		"desc": "A proper cable to the town's power station."},
	{"id": "substation", "name": "Electrical substation", "cost": 6000000.0, "power": 60,
		"desc": "Your own substation off the high-voltage lines."},
]


static func repair_name(id: String) -> String:
	for r in REPAIRS:
		if r["id"] == id:
			return r["name"]
	return id

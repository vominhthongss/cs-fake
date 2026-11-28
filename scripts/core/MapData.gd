class_name MapData
extends RefCounted

const MAP_HALF_SIZE: float = 34.0
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0.0, 24.0)
const PLAYER_SPAWN_YAW: float = 0.0

const BOT_NAMES: Array[String] = [
	"BOT Viper",
	"BOT Kestrel",
	"BOT Rook",
	"BOT Jaeger",
	"BOT Nomad",
]

const MAP_PROPS: Array[Dictionary] = [
	# Central Mid Archway Pillars & Overhead Beam
	{"id": "mid_pillar_w", "kind": "wall", "x": -5.5, "y": 0.0, "z": 4.0, "w": 3.0, "h": 4.5, "d": 3.0, "penetrable": false},
	{"id": "mid_pillar_e", "kind": "wall", "x": 5.5, "y": 0.0, "z": 4.0, "w": 3.0, "h": 4.5, "d": 3.0, "penetrable": false},
	{"id": "mid_arch_lintel", "kind": "arch", "x": 0.0, "y": 3.6, "z": 4.0, "w": 14.0, "h": 1.4, "d": 3.0, "penetrable": false},

	# Mid Tactical Cover
	{"id": "mid_xbox", "kind": "crate", "x": -2.2, "y": 0.0, "z": -2.5, "w": 2.2, "h": 1.7, "d": 2.2, "penetrable": true},
	{"id": "mid_crate_low", "kind": "crate", "x": 3.2, "y": 0.0, "z": -6.5, "w": 1.8, "h": 1.35, "d": 1.8, "penetrable": true},

	# Courtyard flanking walls
	{"id": "div_wall_sw", "kind": "wall", "x": -12.0, "y": 0.0, "z": 10.0, "w": 2.0, "h": 3.8, "d": 9.0, "penetrable": false},
	{"id": "div_wall_se", "kind": "wall", "x": 12.0, "y": 0.0, "z": 10.0, "w": 2.0, "h": 3.8, "d": 9.0, "penetrable": false},
	{"id": "div_wall_nw", "kind": "wall", "x": -12.0, "y": 0.0, "z": -12.0, "w": 2.0, "h": 3.8, "d": 9.0, "penetrable": false},
	{"id": "div_wall_ne", "kind": "wall", "x": 12.0, "y": 0.0, "z": -12.0, "w": 2.0, "h": 3.8, "d": 9.0, "penetrable": false},

	# West A-Site
	{"id": "a_container_blue", "kind": "container", "x": -22.0, "y": 0.0, "z": -4.0, "w": 3.2, "h": 2.8, "d": 7.5, "penetrable": false, "tint": Color("#2c4b66")},
	{"id": "a_container_rust", "kind": "container", "x": -25.0, "y": 0.0, "z": 11.0, "w": 7.0, "h": 2.8, "d": 3.2, "penetrable": false, "tint": Color("#7c3e2b")},
	{"id": "a_crate_site_1", "kind": "crate", "x": -18.0, "y": 0.0, "z": -14.0, "w": 2.2, "h": 2.0, "d": 2.2, "penetrable": true},
	{"id": "a_crate_site_2", "kind": "crate", "x": -20.5, "y": 0.0, "z": -14.0, "w": 1.8, "h": 1.4, "d": 1.8, "penetrable": true},
	{"id": "a_sandbag_1", "kind": "sandbag", "x": -16.0, "y": 0.0, "z": 2.0, "w": 3.0, "h": 1.05, "d": 1.0, "penetrable": true},
	{"id": "a_barrel_1", "kind": "barrel", "x": -19.8, "y": 0.0, "z": -11.8, "w": 0.9, "h": 1.25, "d": 0.9, "penetrable": true},

	# East B-Site
	{"id": "b_platform", "kind": "ramp_block", "x": 22.0, "y": 0.0, "z": -4.0, "w": 8.0, "h": 1.2, "d": 8.0, "penetrable": false},
	{"id": "b_step_1", "kind": "ramp_block", "x": 22.0, "y": 0.0, "z": 1.0, "w": 4.0, "h": 0.45, "d": 2.0, "penetrable": false},
	{"id": "b_step_2", "kind": "ramp_block", "x": 22.0, "y": 0.0, "z": -0.2, "w": 4.0, "h": 0.85, "d": 1.2, "penetrable": false},
	{"id": "b_crate_top", "kind": "crate", "x": 23.5, "y": 1.2, "z": -5.5, "w": 1.8, "h": 1.5, "d": 1.8, "penetrable": true},
	{"id": "b_container_olive", "kind": "container", "x": 25.0, "y": 0.0, "z": 12.0, "w": 6.8, "h": 2.8, "d": 3.1, "penetrable": false, "tint": Color("#45583a")},
	{"id": "b_crate_mid_e", "kind": "crate", "x": 18.0, "y": 0.0, "z": -15.0, "w": 2.0, "h": 1.8, "d": 2.0, "penetrable": true},
	{"id": "b_sandbag_e", "kind": "sandbag", "x": 16.0, "y": 0.0, "z": 3.0, "w": 3.0, "h": 1.05, "d": 1.0, "penetrable": true},
	{"id": "b_barrel_e", "kind": "barrel", "x": 19.6, "y": 0.0, "z": -13.2, "w": 0.9, "h": 1.25, "d": 0.9, "penetrable": true},

	# North Plaza
	{"id": "north_sandbag_c", "kind": "sandbag", "x": 0.0, "y": 0.0, "z": -19.0, "w": 4.5, "h": 1.1, "d": 1.1, "penetrable": true},
	{"id": "north_crate_w", "kind": "crate", "x": -7.0, "y": 0.0, "z": -23.0, "w": 2.1, "h": 1.8, "d": 2.1, "penetrable": true},
	{"id": "north_crate_e", "kind": "crate", "x": 7.0, "y": 0.0, "z": -23.0, "w": 2.1, "h": 1.8, "d": 2.1, "penetrable": true},

	# South Spawn Flank Cover
	{"id": "south_crate_w", "kind": "crate", "x": -7.5, "y": 0.0, "z": 19.0, "w": 1.8, "h": 1.4, "d": 1.8, "penetrable": true},
	{"id": "south_crate_e", "kind": "crate", "x": 7.5, "y": 0.0, "z": 19.0, "w": 1.8, "h": 1.4, "d": 1.8, "penetrable": true},
	{"id": "south_barrel", "kind": "barrel", "x": -5.4, "y": 0.0, "z": 19.2, "w": 0.9, "h": 1.25, "d": 0.9, "penetrable": true},
]

const COVER_SPOTS: Array[Vector3] = [
	Vector3(-2.2, 0.0, -5.2),
	Vector3(3.2, 0.0, -9.0),
	Vector3(-18.0, 0.0, -17.0),
	Vector3(-19.0, 0.0, -4.0),
	Vector3(18.0, 0.0, -18.0),
	Vector3(22.0, 1.2, -7.5),
	Vector3(0.0, 0.0, -21.5),
	Vector3(-7.0, 0.0, -26.0),
	Vector3(7.0, 0.0, -26.0),
	Vector3(-16.0, 0.0, 0.0),
	Vector3(16.0, 0.0, 1.0),
]

static func get_map_colliders() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in MAP_PROPS:
		var kind: String = p["kind"]
		var mat_type: String = "concrete"
		if kind == "crate":
			mat_type = "wood"
		elif kind == "container" or kind == "barrel":
			mat_type = "metal"
		elif kind == "sandbag":
			mat_type = "sandbag"
		var x: float = float(p["x"])
		var y: float = float(p["y"])
		var z: float = float(p["z"])
		var w: float = float(p["w"])
		var h: float = float(p["h"])
		var d: float = float(p["d"])
		result.append({
			"id": p["id"],
			"min_x": x - w * 0.5,
			"max_x": x + w * 0.5,
			"min_y": y,
			"max_y": y + h,
			"min_z": z - d * 0.5,
			"max_z": z + d * 0.5,
			"material_type": mat_type,
			"penetrable": bool(p["penetrable"]),
		})

	result.append({"id": "bound_n", "min_x": -36.0, "max_x": 36.0, "min_y": 0.0, "max_y": 6.0, "min_z": -35.0, "max_z": -33.5, "material_type": "cliff", "penetrable": false})
	result.append({"id": "bound_s", "min_x": -36.0, "max_x": 36.0, "min_y": 0.0, "max_y": 6.0, "min_z": 33.5, "max_z": 35.0, "material_type": "cliff", "penetrable": false})
	result.append({"id": "bound_w", "min_x": -35.0, "max_x": -33.5, "min_y": 0.0, "max_y": 6.0, "min_z": -36.0, "max_z": 36.0, "material_type": "cliff", "penetrable": false})
	result.append({"id": "bound_e", "min_x": 33.5, "max_x": 35.0, "min_y": 0.0, "max_y": 6.0, "min_z": -36.0, "max_z": 36.0, "material_type": "cliff", "penetrable": false})
	return result

static func get_bot_spawns() -> Array[Dictionary]:
	return [
		{
			"id": "bot_mid_entry",
			"pos": Vector3(0.0, 0.0, -17.0),
			"archetype": GameTypes.BotArchetype.ENTRY,
			"patrol_route": [
				Vector3(0.0, 0.0, -14.0),
				Vector3(2.5, 0.0, -4.0),
				Vector3(-2.2, 0.0, -1.0),
				Vector3(0.0, 0.0, 9.0),
			],
		},
		{
			"id": "bot_a_anchor",
			"pos": Vector3(-21.0, 0.0, -18.0),
			"archetype": GameTypes.BotArchetype.ANCHOR,
			"patrol_route": [
				Vector3(-17.0, 0.0, -10.0),
				Vector3(-17.0, 0.0, 0.0),
				Vector3(-22.0, 0.0, 6.0),
				Vector3(-16.0, 0.0, -12.0),
			],
		},
		{
			"id": "bot_b_anchor",
			"pos": Vector3(21.0, 0.0, -18.0),
			"archetype": GameTypes.BotArchetype.ANCHOR,
			"patrol_route": [
				Vector3(17.0, 0.0, -10.0),
				Vector3(22.0, 1.2, -4.0),
				Vector3(17.0, 0.0, 5.0),
				Vector3(19.0, 0.0, -14.0),
			],
		},
		{
			"id": "bot_overwatch",
			"pos": Vector3(-4.0, 0.0, -26.0),
			"archetype": GameTypes.BotArchetype.SNIPER,
			"patrol_route": [
				Vector3(-2.0, 0.0, -21.0),
				Vector3(3.5, 0.0, -20.0),
				Vector3(0.0, 0.0, -15.0),
			],
		},
		{
			"id": "bot_flanker",
			"pos": Vector3(15.0, 0.0, -24.0),
			"archetype": GameTypes.BotArchetype.ENTRY,
			"patrol_route": [
				Vector3(18.0, 0.0, -6.0),
				Vector3(18.0, 0.0, 8.0),
				Vector3(8.0, 0.0, 14.0),
				Vector3(16.0, 0.0, -4.0),
			],
		},
	]

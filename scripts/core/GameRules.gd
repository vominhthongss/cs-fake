class_name GameRules
extends RefCounted

## Pure tactical FPS math & rules ported 1:1 from src/game/rules.ts

static func calculate_ballistic_damage(
	weapon_id: String,
	region: GameTypes.HitRegion,
	distance: float,
	target_armor: float,
	target_has_helmet: bool,
	penetrated_walls: int
) -> Dictionary:
	var spec: Dictionary = GameTypes.WEAPONS[weapon_id]
	var base: float = float(spec["damage"])

	if region == GameTypes.HitRegion.HEAD:
		base *= float(spec["headshot_multiplier"])
	elif region == GameTypes.HitRegion.LIMB:
		base *= 0.75

	var cat: GameTypes.WeaponCategory = spec["category"]
	var falloff_rate: float = 0.0035
	if cat == GameTypes.WeaponCategory.SHOTGUN:
		falloff_rate = 0.032
	elif cat == GameTypes.WeaponCategory.SMG:
		falloff_rate = 0.011
	elif cat == GameTypes.WeaponCategory.SNIPER:
		falloff_rate = 0.001

	var dist_factor: float = maxf(0.25, 1.0 - maxf(0.0, distance - 8.0) * falloff_rate)
	base *= dist_factor

	for _i in range(penetrated_walls):
		base *= float(spec["wall_penetration"])

	var is_headshot: bool = (region == GameTypes.HitRegion.HEAD)
	var protected_by_armor: bool = (
		target_armor > 0.0 and (target_has_helmet if is_headshot else region == GameTypes.HitRegion.CHEST)
	)

	if not protected_by_armor:
		return {
			"hp_damage": maxi(1, int(round(base))),
			"armor_damage": 0,
			"is_headshot": is_headshot,
		}

	var hp_damage: int = maxi(1, int(round(base * float(spec["armor_penetration"]))))
	var absorbed: float = maxf(0.0, base - float(hp_damage))
	var armor_damage: int = mini(int(target_armor), maxi(1, int(round(absorbed * 0.55))))

	return {
		"hp_damage": hp_damage,
		"armor_damage": armor_damage,
		"is_headshot": is_headshot,
	}

## Returns Vector2(yaw_deg, pitch_deg) for the nth consecutive shot in a burst.
static func get_recoil_for_shot(weapon_id: String, shot_index: int) -> Vector2:
	var pattern: Array = GameTypes.WEAPONS[weapon_id]["recoil_pattern"]
	if pattern.is_empty():
		return Vector2.ZERO
	var idx: int = mini(shot_index, pattern.size() - 1)
	return pattern[idx]

static func compute_dynamic_spread(
	weapon_id: String,
	horizontal_speed: float,
	is_grounded: bool,
	is_crouching: bool,
	is_scoped: bool,
	recoil_bloom: float
) -> float:
	var spec: Dictionary = GameTypes.WEAPONS[weapon_id]
	var spread: float = float(spec["base_spread"])

	if bool(spec["can_scope"]) and not is_scoped:
		spread += 0.042

	spread += horizontal_speed * float(spec["move_spread_factor"])
	if not is_grounded:
		spread += 0.055
	if is_crouching:
		spread *= 0.72
	spread += recoil_bloom * 0.015
	return spread

static func evaluate_purchase(
	item: String,
	cash: int,
	current_armor: float,
	has_helmet: bool,
	he_count: int,
	flash_count: int,
	current_primary_id: String,
	current_pistol_id: String
) -> Dictionary:
	if item == "kevlar_helmet":
		var cost: int = 0 if (current_armor >= 100.0 and has_helmet) else (350 if current_armor > 0.0 else 1000)
		if cost == 0:
			return {"ok": false, "cost": 0, "reason": "Armor full"}
		if cash < cost:
			return {"ok": false, "cost": cost, "reason": "Insufficient funds"}
		return {"ok": true, "cost": cost, "reason": ""}

	if not GameTypes.WEAPONS.has(item):
		return {"ok": false, "cost": 0, "reason": "Unknown item"}

	var spec: Dictionary = GameTypes.WEAPONS[item]
	var price: int = int(spec["price"])
	if item == "he_grenade" and he_count >= 2:
		return {"ok": false, "cost": price, "reason": "Max HE grenades"}
	if item == "flashbang" and flash_count >= 2:
		return {"ok": false, "cost": price, "reason": "Max flashbangs"}
	if int(spec["slot"]) == 1 and current_primary_id == item:
		return {"ok": false, "cost": price, "reason": "Already equipped"}
	if int(spec["slot"]) == 2 and current_pistol_id == item:
		return {"ok": false, "cost": price, "reason": "Already equipped"}
	if cash < price:
		return {"ok": false, "cost": price, "reason": "Insufficient funds"}
	return {"ok": true, "cost": price, "reason": ""}

static func resolve_horizontal_collision(
	pos: Vector3,
	radius: float,
	player_height: float,
	colliders: Array
) -> Vector3:
	var x: float = pos.x
	var z: float = pos.z

	for box in colliders:
		if pos.y + player_height <= float(box["min_y"]) + 0.05 or pos.y >= float(box["max_y"]) - 0.05:
			continue

		var min_x: float = float(box["min_x"])
		var max_x: float = float(box["max_x"])
		var min_z: float = float(box["min_z"])
		var max_z: float = float(box["max_z"])

		var closest_x: float = clampf(x, min_x, max_x)
		var closest_z: float = clampf(z, min_z, max_z)

		var dx: float = x - closest_x
		var dz: float = z - closest_z
		var dist_sq: float = dx * dx + dz * dz

		if dist_sq < radius * radius:
			var dist: float = sqrt(dist_sq)
			if dist > 0.0001:
				var push: float = radius - dist
				x += (dx / dist) * push
				z += (dz / dist) * push
			else:
				var pen_left: float = absf(x - min_x)
				var pen_right: float = absf(max_x - x)
				var pen_front: float = absf(z - min_z)
				var pen_back: float = absf(max_z - z)
				var min_pen: float = minf(minf(pen_left, pen_right), minf(pen_front, pen_back))
				if min_pen == pen_left:
					x = min_x - radius
				elif min_pen == pen_right:
					x = max_x + radius
				elif min_pen == pen_front:
					z = min_z - radius
				else:
					z = max_z + radius

	return Vector3(x, pos.y, z)

static func get_support_floor_y(
	x: float,
	z: float,
	feet_y: float,
	radius: float,
	colliders: Array,
	step_height: float = 0.55
) -> float:
	var floor_y: float = 0.0
	for box in colliders:
		if (
			x + radius * 0.7 > float(box["min_x"])
			and x - radius * 0.7 < float(box["max_x"])
			and z + radius * 0.7 > float(box["min_z"])
			and z - radius * 0.7 < float(box["max_z"])
		):
			var box_top: float = float(box["max_y"])
			if box_top <= feet_y + step_height and box_top > floor_y:
				floor_y = box_top
	return floor_y

static func evaluate_bot_next_state(
	hp: float,
	max_hp: float,
	ammo_in_mag: int,
	blind_timer: float,
	can_see_player: bool,
	distance_to_player: float,
	time_since_heard_player: float,
	has_cover_nearby: bool,
	archetype: GameTypes.BotArchetype,
	difficulty: GameTypes.BotDifficulty
) -> GameTypes.BotAIState:
	if hp <= 0.0:
		return GameTypes.BotAIState.KO
	if blind_timer > 0.0:
		return GameTypes.BotAIState.BLINDED
	if ammo_in_mag <= 0:
		return GameTypes.BotAIState.RELOAD

	var low_hp_threshold: float = 0.2
	if difficulty == GameTypes.BotDifficulty.ELITE:
		low_hp_threshold = 0.35
	elif difficulty == GameTypes.BotDifficulty.TACTICAL:
		low_hp_threshold = 0.28

	if (
		hp / maxf(max_hp, 1.0) <= low_hp_threshold
		and has_cover_nearby
		and can_see_player
		and archetype != GameTypes.BotArchetype.ENTRY
	):
		return GameTypes.BotAIState.TAKE_COVER

	if can_see_player:
		if archetype == GameTypes.BotArchetype.SNIPER and distance_to_player < 9.0 and has_cover_nearby:
			return GameTypes.BotAIState.FLANK
		return GameTypes.BotAIState.ENGAGE

	var memory_window: float = 2.5
	if difficulty == GameTypes.BotDifficulty.ELITE:
		memory_window = 6.0
	elif difficulty == GameTypes.BotDifficulty.TACTICAL:
		memory_window = 4.2

	if time_since_heard_player <= memory_window:
		if archetype == GameTypes.BotArchetype.ENTRY and distance_to_player > 14.0:
			return GameTypes.BotAIState.FLANK
		return GameTypes.BotAIState.INVESTIGATE

	return GameTypes.BotAIState.PATROL

static func get_difficulty_tuning(difficulty: GameTypes.BotDifficulty) -> Dictionary:
	match difficulty:
		GameTypes.BotDifficulty.RECRUIT:
			return {
				"reaction_delay": 0.58,
				"aim_error_rad": 0.085,
				"burst_length": 3,
				"strafe_frequency": 0.7,
				"move_speed": 3.9,
				"bot_hp": 90.0,
				"headshot_chance": 0.08,
			}
		GameTypes.BotDifficulty.TACTICAL:
			return {
				"reaction_delay": 0.34,
				"aim_error_rad": 0.045,
				"burst_length": 4,
				"strafe_frequency": 1.4,
				"move_speed": 4.5,
				"bot_hp": 100.0,
				"headshot_chance": 0.18,
			}
		GameTypes.BotDifficulty.ELITE:
			return {
				"reaction_delay": 0.19,
				"aim_error_rad": 0.022,
				"burst_length": 5,
				"strafe_frequency": 2.1,
				"move_speed": 5.0,
				"bot_hp": 110.0,
				"headshot_chance": 0.34,
			}
	return get_difficulty_tuning(GameTypes.BotDifficulty.TACTICAL)

## Checks if a segment (p1 -> p2) intersects an AABB (slab method).
## Returns normalized t in [0, 1] or -1.0 if no intersection.
static func intersect_segment_aabb(p1: Vector3, p2: Vector3, box: Dictionary) -> float:
	var d: Vector3 = p2 - p1
	var tmin: float = 0.0
	var tmax: float = 1.0

	var axes: Array = [
		[p1.x, d.x, float(box["min_x"]), float(box["max_x"])],
		[p1.y, d.y, float(box["min_y"]), float(box["max_y"])],
		[p1.z, d.z, float(box["min_z"]), float(box["max_z"])],
	]

	for axis in axes:
		var origin: float = axis[0]
		var dir: float = axis[1]
		var bmin: float = axis[2]
		var bmax: float = axis[3]
		if absf(dir) < 1e-8:
			if origin < bmin or origin > bmax:
				return -1.0
		else:
			var t1: float = (bmin - origin) / dir
			var t2: float = (bmax - origin) / dir
			if t1 > t2:
				var tmp: float = t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return -1.0

	return tmin

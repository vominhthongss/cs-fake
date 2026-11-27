export interface GodotScriptFile {
  filename: string;
  path: string;
  role: string;
  language: 'gdscript' | 'ini';
  code: string;
}

export const GODOT_SCRIPTS: GodotScriptFile[] = [
  {
    filename: 'WeaponData.gd',
    path: 'res://scripts/weapons/WeaponData.gd',
    role: 'Resource schema defining CS-style weapon ballistics, spray patterns & penetration',
    language: 'gdscript',
    code: `class_name WeaponData
extends Resource

## CS-style Tactical Weapon Resource (Godot 4.3+)
## Create .tres presets for AK-47, M4A1-S, AWP, P90, Nova, Deagle, USP-S, Karambit

enum Category { RIFLE, SNIPER, SMG, SHOTGUN, PISTOL, MELEE, GRENADE }

@export var weapon_id: String = "ak47"
@export var display_name: String = "AK-47"
@export var category: Category = Category.RIFLE
@export var slot_index: int = 1
@export var price: int = 2700
@export var kill_reward: int = 300

@export_group("Ballistics & Damage")
@export var base_damage: float = 36.0
@export var headshot_multiplier: float = 3.9
@export var armor_penetration: float = 0.775
@export var wall_penetration: float = 0.60
@export var pellets: int = 1
@export var max_range: float = 120.0
@export var fire_rate_rpm: float = 600.0
@export var automatic: bool = true

@export_group("Magazine & Mobility")
@export var magazine_size: int = 30
@export var reserve_max: int = 90
@export var reload_duration: float = 2.4
@export var move_speed_multiplier: float = 0.88
@export var can_scope: bool = false
@export var silenced: bool = false

@export_group("Spread & Spray Pattern")
@export var base_spread_rad: float = 0.004
@export var move_spread_factor: float = 0.011
## Vector2(yaw_deg, pitch_deg) per consecutive shot in spray
@export var recoil_pattern: Array[Vector2] = [
\tVector2(0.0, 0.6), Vector2(0.1, 1.1), Vector2(-0.2, 1.5),
\tVector2(0.3, 1.8), Vector2(-0.4, 1.9), Vector2(0.7, 1.7),
\tVector2(1.3, 1.4), Vector2(1.5, 1.1), Vector2(-1.2, 0.8),
\tVector2(-1.8, 0.6), Vector2(-1.6, 0.5), Vector2(1.4, 0.5)
]

func get_fire_interval() -> float:
\treturn 60.0 / maxf(fire_rate_rpm, 1.0)

func compute_dynamic_spread(horizontal_speed: float, is_grounded: bool, is_crouching: bool, is_scoped: bool, bloom: float) -> float:
\tvar spread := base_spread_rad
\tif can_scope and not is_scoped:
\t\tspread += 0.042
\tspread += horizontal_speed * move_spread_factor
\tif not is_grounded:
\t\tspread += 0.055
\tif is_crouching:
\t\tspread *= 0.72
\treturn spread + bloom * 0.015
`,
  },
  {
    filename: 'WeaponManager.gd',
    path: 'res://scripts/weapons/WeaponManager.gd',
    role: 'Handles firing cadence, raycast wallbang penetration, recoil kick, reload & scoping',
    language: 'gdscript',
    code: `class_name WeaponManager
extends Node3D

signal weapon_fired(weapon_id: String, recoil_offset: Vector2)
signal ammo_changed(in_mag: int, reserve: int)
signal hit_confirmed(is_headshot: bool, is_kill: bool)

@export var camera: Camera3D
@export var shooter_body: CharacterBody3D
@export var arsenal: Array[WeaponData] = []
@export var tracer_scene: PackedScene

var active_index: int = 0
var mag_ammo: Dictionary = {}
var reserve_ammo: Dictionary = {}
var fire_cooldown: float = 0.0
var reload_timer: float = 0.0
var is_reloading: bool = false
var is_scoped: bool = false
var spray_shot_count: int = 0
var recoil_reset_timer: float = 0.0
var recoil_bloom: float = 0.0

func _ready() -> void:
\tfor w in arsenal:
\t\tmag_ammo[w.weapon_id] = w.magazine_size
\t\treserve_ammo[w.weapon_id] = w.reserve_max
\t_emit_ammo()

func _physics_process(delta: float) -> void:
\tfire_cooldown = maxf(0.0, fire_cooldown - delta)
\trecoil_bloom = maxf(0.0, recoil_bloom - delta * 3.8)
\tif recoil_reset_timer > 0.0:
\t\trecoil_reset_timer -= delta
\t\tif recoil_reset_timer <= 0.0:
\t\t\tspray_shot_count = 0

\tif is_reloading:
\t\treload_timer -= delta
\t\tif reload_timer <= 0.0:
\t\t\t_finish_reload()

\tvar w := get_active_weapon()
\tif w == null:
\t\treturn

\tvar want_fire := Input.is_action_pressed("fire") if w.automatic else Input.is_action_just_pressed("fire")
\tif want_fire and fire_cooldown <= 0.0 and not is_reloading:
\t\ttry_fire(w)

\tif Input.is_action_just_pressed("reload") and not is_reloading:
\t\tstart_reload(w)

\tif Input.is_action_just_pressed("scope") and w.can_scope:
\t\tis_scoped = not is_scoped
\t\tcamera.fov = 26.0 if is_scoped else 75.0

func get_active_weapon() -> WeaponData:
\tif arsenal.is_empty():
\t\treturn null
\treturn arsenal[active_index]

func try_fire(w: WeaponData) -> void:
\tif w.category != WeaponData.Category.MELEE:
\t\tvar current: int = mag_ammo.get(w.weapon_id, 0)
\t\tif current <= 0:
\t\t\tstart_reload(w)
\t\t\treturn
\t\tmag_ammo[w.weapon_id] = current - 1
\t\t_emit_ammo()

\tfire_cooldown = w.get_fire_interval()
\trecoil_reset_timer = 0.38
\tvar pattern_idx := mini(spray_shot_count, max(0, w.recoil_pattern.size() - 1))
\tvar kick := w.recoil_pattern[pattern_idx] if not w.recoil_pattern.is_empty() else Vector2.ZERO
\tspray_shot_count += 1
\trecoil_bloom = minf(1.5, recoil_bloom + 0.25)

\tvar horiz_speed := Vector2(shooter_body.velocity.x, shooter_body.velocity.z).length()
\tvar spread := w.compute_dynamic_spread(
\t\thoriz_speed,
\t\tshooter_body.is_on_floor(),
\t\tInput.is_action_pressed("crouch"),
\t\tis_scoped,
\t\trecoil_bloom
\t)

\tfor i in w.pellets:
\t\t_cast_ballistic_ray(w, spread, kick)

\temit_signal("weapon_fired", w.weapon_id, kick)

func _cast_ballistic_ray(w: WeaponData, spread: float, kick: Vector2) -> void:
\tvar space := get_world_3d().direct_space_state
\tvar origin := camera.global_position
\tvar forward := -camera.global_transform.basis.z
\t# Apply spread & pattern kick
\tvar yaw_rad := deg_to_rad(kick.x * 0.45) + randf_range(-spread, spread)
\tvar pitch_rad := deg_to_rad(kick.y * 0.45) + randf_range(-spread, spread)
\tvar dir := forward.rotated(camera.global_transform.basis.y, -yaw_rad).rotated(camera.global_transform.basis.x, pitch_rad).normalized()

\tvar damage_mult := 1.0
\tvar remaining_dist := w.max_range
\tvar exclude: Array[RID] = [shooter_body.get_rid()]

\t# Multi-pass raycast supporting CS-style wallbang penetration
\tfor pass_idx in 3:
\t\tvar query := PhysicsRayQueryParameters3D.create(origin, origin + dir * remaining_dist)
\t\tquery.exclude = exclude
\t\tquery.collide_with_areas = true
\t\tvar hit := space.intersect_ray(query)
\t\tif hit.is_empty():
\t\t\tbreak

\t\tvar collider = hit.collider
\t\tif collider.is_in_group("hitbox"):
\t\t\tvar is_head: bool = collider.get_meta("hit_region", "chest") == "head"
\t\t\tvar mult := w.headshot_multiplier if is_head else 1.0
\t\t\tvar final_dmg := w.base_damage * mult * damage_mult
\t\t\tvar killed: bool = collider.owner.apply_ballistic_damage(final_dmg, w.armor_penetration, is_head, dir)
\t\t\temit_signal("hit_confirmed", is_head, killed)
\t\t\tbreak
\t\telif collider.is_in_group("penetrable_cover") and w.wall_penetration > 0.2:
\t\t\tdamage_mult *= w.wall_penetration
\t\t\texclude.append(collider.get_rid())
\t\t\torigin = hit.position + dir * 0.15
\t\t\tremaining_dist -= hit.position.distance_to(origin)
\t\telse:
\t\t\tbreak

func start_reload(w: WeaponData) -> void:
\tif is_reloading or reserve_ammo.get(w.weapon_id, 0) <= 0:
\t\treturn
\tif mag_ammo.get(w.weapon_id, 0) >= w.magazine_size:
\t\treturn
\tis_reloading = true
\treload_timer = w.reload_duration
\tis_scoped = false

func _finish_reload() -> void:
\tis_reloading = false
\tvar w := get_active_weapon()
\tif w == null:
\t\treturn
\tvar need := w.magazine_size - int(mag_ammo[w.weapon_id])
\tvar take := mini(need, int(reserve_ammo[w.weapon_id]))
\tmag_ammo[w.weapon_id] += take
\treserve_ammo[w.weapon_id] -= take
\t_emit_ammo()

func _emit_ammo() -> void:
\tvar w := get_active_weapon()
\tif w:
\t\temit_signal("ammo_changed", mag_ammo.get(w.weapon_id, 0), reserve_ammo.get(w.weapon_id, 0))
`,
  },
  {
    filename: 'PlayerController.gd',
    path: 'res://scripts/player/PlayerController.gd',
    role: 'CS-style CharacterBody3D physics: counter-strafing friction, air accel, crouch & recoil recovery',
    language: 'gdscript',
    code: `class_name PlayerController
extends CharacterBody3D

@export var mouse_sensitivity: float = 0.0022
@export var walk_speed: float = 6.2
@export var crouch_speed: float = 3.2
@export var jump_velocity: float = 5.4
@export var ground_accel: float = 42.0
@export var ground_friction: float = 12.0
@export var air_accel: float = 10.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_mgr: WeaponManager = $Head/Camera3D/WeaponManager

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var recoil_pitch: float = 0.0
var recoil_yaw: float = 0.0

func _ready() -> void:
\tInput.mouse_mode = Input.MOUSE_MODE_CAPTURED
\tweapon_mgr.weapon_fired.connect(_on_weapon_fired)

func _unhandled_input(event: InputEvent) -> void:
\tif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
\t\trotate_y(-event.relative.x * mouse_sensitivity)
\t\thead.rotate_x(-event.relative.y * mouse_sensitivity)
\t\thead.rotation.x = clampf(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

func _physics_process(delta: float) -> void:
\t# Smooth recoil recovery
\trecoil_pitch = lerpf(recoil_pitch, 0.0, 1.0 - exp(-10.0 * delta))
\trecoil_yaw = lerpf(recoil_yaw, 0.0, 1.0 - exp(-10.0 * delta))
\tcamera.rotation.x = deg_to_rad(recoil_pitch)
\tcamera.rotation.y = deg_to_rad(recoil_yaw)

\tif not is_on_floor():
\t\tvelocity.y -= gravity * delta

\tif Input.is_action_just_pressed("jump") and is_on_floor():
\t\tvelocity.y = jump_velocity

\tvar input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
\tvar wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

\tvar w := weapon_mgr.get_active_weapon()
\tvar w_mult := w.move_speed_multiplier if w else 1.0
\tvar max_spd := (crouch_speed if Input.is_action_pressed("crouch") else walk_speed) * w_mult

\tif is_on_floor():
\t\t# CS-style crisp counter-strafe friction
\t\tvar speed := Vector2(velocity.x, velocity.z).length()
\t\tif speed > 0.01:
\t\t\tvar drop := speed * ground_friction * delta
\t\t\tvar new_speed := maxf(0.0, speed - drop) / speed
\t\t\tvelocity.x *= new_speed
\t\t\tvelocity.z *= new_speed
\t\t_accelerate(wish_dir, max_spd, ground_accel, delta)
\telse:
\t\t_accelerate(wish_dir, max_spd, air_accel, delta)

\tmove_and_slide()

func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
\tvar current_speed := velocity.dot(wish_dir)
\tvar add_speed := wish_speed - current_speed
\tif add_speed <= 0.0:
\t\treturn
\tvar accel_speed := minf(accel * wish_speed * delta, add_speed)
\tvelocity.x += wish_dir.x * accel_speed
\tvelocity.z += wish_dir.z * accel_speed

func _on_weapon_fired(_weapon_id: String, kick: Vector2) -> void:
\trecoil_pitch += kick.y
\trecoil_yaw += kick.x
`,
  },
  {
    filename: 'BotAIController.gd',
    path: 'res://scripts/ai/BotAIController.gd',
    role: 'Smart Tactical Utility AI: Patrol, Sound Investigation, Counter-Strafe Engage, Cover Retreat, Flank & Flash Blindness',
    language: 'gdscript',
    code: `class_name BotAIController
extends CharacterBody3D

enum State { PATROL, INVESTIGATE, ENGAGE, TAKE_COVER, FLANK, RELOAD, BLINDED, KO }
enum Archetype { ENTRY, ANCHOR, SNIPER }

@export var archetype: Archetype = Archetype.ANCHOR
@export var max_hp: float = 100.0
@export var move_speed: float = 4.5
@export var reaction_delay: float = 0.30
@export var aim_error_rad: float = 0.042
@export var patrol_waypoints: Array[Vector3] = []
@export var cover_spots: Array[Vector3] = []

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var eye_ray: RayCast3D = $EyeRay
@onready var muzzle: Marker3D = $MuzzlePoint

var state: State = State.PATROL
var hp: float = 100.0
var ammo_in_mag: int = 30
var blind_timer: float = 0.0
var time_since_heard_player: float = 99.0
var last_known_player_pos: Vector3 = Vector3.ZERO
var reaction_timer: float = 0.0
var fire_cooldown: float = 0.0
var strafe_phase: float = 0.0
var patrol_idx: int = 0
var player_ref: Node3D = null

func _ready() -> void:
\thp = max_hp
\tplayer_ref = get_tree().get_first_node_in_group("player")
\tadd_to_group("bots")

func notify_sound_event(source_pos: Vector3, hear_radius: float = 28.0) -> void:
\tif state == State.KO:
\t\treturn
\tif global_position.distance_to(source_pos) <= hear_radius:
\t\tlast_known_player_pos = source_pos
\t\ttime_since_heard_player = 0.0

func apply_flashbang(duration: float) -> void:
\tif state != State.KO:
\t\tblind_timer = maxf(blind_timer, duration)
\t\tstate = State.BLINDED

func _physics_process(delta: float) -> void:
\tif state == State.KO:
\t\treturn

\ttime_since_heard_player += delta
\tfire_cooldown = maxf(0.0, fire_cooldown - delta)
\tblind_timer = maxf(0.0, blind_timer - delta)

\tvar can_see := _check_line_of_sight()
\tif can_see and player_ref:
\t\tlast_known_player_pos = player_ref.global_position
\t\ttime_since_heard_player = 0.0

\t# Utility State Evaluation
\tstate = _evaluate_next_state(can_see)

\tmatch state:
\t\tState.BLINDED:
\t\t\tvelocity.x *= 0.85
\t\t\tvelocity.z *= 0.85
\t\tState.RELOAD:
\t\t\t_move_to_nearest_cover(delta)
\t\tState.TAKE_COVER:
\t\t\t_move_to_nearest_cover(delta)
\t\tState.ENGAGE:
\t\t\t_execute_engage(delta)
\t\tState.INVESTIGATE, State.FLANK:
\t\t\tnav_agent.target_position = last_known_player_pos
\t\t\t_follow_nav(delta, move_speed)
\t\tState.PATROL:
\t\t\t_execute_patrol(delta)

\tif not is_on_floor():
\t\tvelocity.y -= 18.0 * delta
\tmove_and_slide()

func _evaluate_next_state(can_see: bool) -> State:
\tif hp <= 0.0:
\t\treturn State.KO
\tif blind_timer > 0.0:
\t\treturn State.BLINDED
\tif ammo_in_mag <= 0:
\t\treturn State.RELOAD
\tif hp / max_hp <= 0.30 and can_see and archetype != Archetype.ENTRY and not cover_spots.is_empty():
\t\treturn State.TAKE_COVER
\tif can_see:
\t\treturn State.ENGAGE
\tif time_since_heard_player <= 4.5:
\t\tif archetype == Archetype.ENTRY and global_position.distance_to(last_known_player_pos) > 14.0:
\t\t\treturn State.FLANK
\t\treturn State.INVESTIGATE
\treturn State.PATROL

func _execute_engage(delta: float) -> void:
\tif not player_ref:
\t\treturn
\t# Face target smoothly
\tvar to_target := (player_ref.global_position - global_position)
\tto_target.y = 0.0
\tif to_target.length_squared() > 0.01:
\t\tvar target_yaw := atan2(-to_target.x, -to_target.z)
\t\trotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-10.0 * delta))

\t# Counter-strafe sideways to avoid standing still
\tstrafe_phase += delta * 2.2
\tvar strafe_dir := global_transform.basis.x * sin(strafe_phase)
\tvelocity.x = strafe_dir.x * move_speed * 0.65
\tvelocity.z = strafe_dir.z * move_speed * 0.65

\treaction_timer += delta
\tif reaction_timer >= reaction_delay and fire_cooldown <= 0.0:
\t\t_fire_at_player()

func _fire_at_player() -> void:
\tfire_cooldown = 0.14 if archetype == Archetype.ENTRY else 1.2 if archetype == Archetype.SNIPER else 0.16
\tammo_in_mag -= 1
\tvar aim_target := player_ref.global_position + Vector3(0.0, 1.45, 0.0)
\tvar dir := (aim_target - muzzle.global_position).normalized()
\tdir = dir.rotated(Vector3.UP, randf_range(-aim_error_rad, aim_error_rad))
\tdir = dir.rotated(global_transform.basis.x, randf_range(-aim_error_rad, aim_error_rad))
\t# Raycast damage against player...

func _check_line_of_sight() -> bool:
\tif not player_ref:
\t\treturn false
\tvar eye_pos := global_position + Vector3(0, 1.65, 0)
\tvar target_pos := player_ref.global_position + Vector3(0, 1.5, 0)
\tif eye_pos.distance_to(target_pos) > 55.0:
\t\treturn false
\teye_ray.global_position = eye_pos
\teye_ray.target_position = eye_ray.to_local(target_pos)
\teye_ray.force_raycast_update()
\treturn eye_ray.is_colliding() and eye_ray.get_collider() == player_ref

func _move_to_nearest_cover(delta: float) -> void:
\tif cover_spots.is_empty():
\t\treturn
\tvar best := cover_spots[0]
\tvar best_d := INF
\tfor c in cover_spots:
\t\tvar d := global_position.distance_to(c)
\t\tif d < best_d:
\t\t\tbest_d = d
\t\t\tbest = c
\tnav_agent.target_position = best
\t_follow_nav(delta, move_speed * 1.1)

func _execute_patrol(delta: float) -> void:
\treaction_timer = 0.0
\tif patrol_waypoints.is_empty():
\t\treturn
\tvar wp := patrol_waypoints[patrol_idx]
\tif global_position.distance_to(wp) < 1.5:
\t\tpatrol_idx = (patrol_idx + 1) % patrol_waypoints.size()
\tnav_agent.target_position = patrol_waypoints[patrol_idx]
\t_follow_nav(delta, move_speed * 0.85)

func _follow_nav(delta: float, spd: float) -> void:
\tif nav_agent.is_navigation_finished():
\t\tvelocity.x = lerpf(velocity.x, 0.0, 10.0 * delta)
\t\tvelocity.z = lerpf(velocity.z, 0.0, 10.0 * delta)
\t\treturn
\tvar next_pt := nav_agent.get_next_path_position()
\tvar dir := (next_pt - global_position)
\tdir.y = 0.0
\tif dir.length() > 0.05:
\t\tdir = dir.normalized()
\t\tvelocity.x = dir.x * spd
\t\tvelocity.z = dir.z * spd
\t\trotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * delta))
`,
  },
  {
    filename: 'GrenadePhysics.gd',
    path: 'res://scripts/weapons/GrenadePhysics.gd',
    role: 'RigidBody3D ballistic HE Frag & Flashbang physics with bounce impulse and line-of-sight stun',
    language: 'gdscript',
    code: `class_name GrenadePhysics
extends RigidBody3D

enum Kind { HE_FRAG, FLASHBANG }

@export var kind: Kind = Kind.HE_FRAG
@export var fuse_time: float = 1.6
@export var blast_radius: float = 8.5
@export var max_damage: float = 98.0

var timer: float = 0.0

func _ready() -> void:
\tcontinuous_cd = true
\tphysics_material_override = PhysicsMaterial.new()
\tphysics_material_override.bounce = 0.45
\tphysics_material_override.friction = 0.6

func _physics_process(delta: float) -> void:
\ttimer += delta
\tif timer >= fuse_time:
\t\t_detonate()

func _detonate() -> void:
\tvar space := get_world_3d().direct_space_state
\tvar targets := get_tree().get_nodes_in_group("bots") + get_tree().get_nodes_in_group("player")
\tfor target in targets:
\t\tvar dist := global_position.distance_to(target.global_position)
\t\tif kind == Kind.HE_FRAG and dist <= blast_radius:
\t\t\tvar falloff := 1.0 - (dist / blast_radius)
\t\t\tif target.has_method("apply_explosive_damage"):
\t\t\t\ttarget.apply_explosive_damage(max_damage * falloff)
\t\telif kind == Kind.FLASHBANG and dist <= 18.0:
\t\t\tvar query := PhysicsRayQueryParameters3D.create(global_position, target.global_position + Vector3(0, 1.5, 0))
\t\t\tvar hit := space.intersect_ray(query)
\t\t\tif hit.is_empty() or hit.collider == target:
\t\t\t\tif target.has_method("apply_flashbang"):
\t\t\t\t\ttarget.apply_flashbang(2.6 * (1.0 - dist / 20.0))
\tqueue_free()
`,
  },
  {
    filename: 'project.godot',
    path: 'res://project.godot',
    role: 'Godot 4.3 project configuration & input map bindings (WASD, Fire, Scope, Reload, Buy)',
    language: 'ini',
    code: `; Engine configuration file (Godot 4.3+)
config_version=5

[application]
config/name="CS-Protocol Tactical FPS"
run/main_scene="res://scenes/Arena.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")

[input]
move_forward={ "deadzone": 0.2, "events": [Object(InputEventKey,"keycode":87)] }
move_back={ "deadzone": 0.2, "events": [Object(InputEventKey,"keycode":83)] }
move_left={ "deadzone": 0.2, "events": [Object(InputEventKey,"keycode":65)] }
move_right={ "deadzone": 0.2, "events": [Object(InputEventKey,"keycode":68)] }
jump={ "deadzone": 0.2, "events": [Object(InputEventKey,"keycode":32)] }
crouch={ "deadzone": 0.2, "events": [Object(InputEventKey,"keycode":16777232)] }
reload={ "deadzone": 0.2, "events": [Object(InputEventKey,"keycode":82)] }
fire={ "deadzone": 0.2, "events": [Object(InputEventMouseButton,"button_index":1)] }
scope={ "deadzone": 0.2, "events": [Object(InputEventMouseButton,"button_index":2)] }
`,
  },
];

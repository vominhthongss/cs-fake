class_name FpsGameController
extends Node3D

## Complete 3D FPS Game Engine ported 1:1 from src/game/engine.ts

signal hud_updated(snapshot: Dictionary)
signal phase_changed(next_phase: GameTypes.GamePhase)

const MAX_ROUNDS: int = 5
const TRACER_POOL_SIZE: int = 16
const PARTICLE_POOL_SIZE: int = 96

var phase: GameTypes.GamePhase = GameTypes.GamePhase.TITLE
var difficulty: GameTypes.BotDifficulty = GameTypes.BotDifficulty.TACTICAL
var bot_count: int = 4
var buy_menu_open: bool = false

var _colliders: Array[Dictionary] = []
var _textures: Dictionary = {}
var _elapsed: float = 0.0
var _hud_sync_timer: float = 0.0

# Player state
var player_pos: Vector3 = MapData.PLAYER_SPAWN
var player_vel: Vector3 = Vector3.ZERO
var player_yaw: float = MapData.PLAYER_SPAWN_YAW
var player_pitch: float = 0.0
var player_grounded: bool = true
var player_hp: float = 100.0
var player_armor: float = 100.0
var player_has_helmet: bool = true
var player_cash: int = 3500
var _walk_bob_phase: float = 0.0
var _step_dist_accum: float = 0.0

# Weapons & recoil
var slots: Dictionary = {}
var active_slot: int = 1
var he_count: int = 1
var flash_count: int = 1
var _fire_cooldown: float = 0.0
var _reload_timer: float = 0.0
var is_reloading: bool = false
var is_scoped: bool = false
var _recoil_pitch: float = 0.0
var _recoil_yaw: float = 0.0
var _recoil_bloom: float = 0.0
var _spray_count: int = 0
var _spray_reset_timer: float = 0.0
var _view_kick_z: float = 0.0
var _view_kick_rot: float = 0.0
var _knife_swing_timer: float = 0.0

# Juice & feedback
var _hitstop_timer: float = 0.0
var _camera_trauma: float = 0.0
var _flash_alpha: float = 0.0
var _damage_flash_alpha: float = 0.0
var _hitmarker_type: String = "none"
var _hitmarker_timer: float = 0.0
var _round_banner: String = ""
var _round_banner_key: String = ""
var _round_banner_arg: int = 0
var _round_banner_timer: float = 0.0

# Match stats
var round_num: int = 1
var player_score: int = 0
var bot_score: int = 0
var kills: int = 0
var headshots: int = 0
var shots_fired: int = 0
var shots_hit: int = 0
var damage_dealt: int = 0
var _round_end_delay: float = 0.0
var _round_pending_state: String = "none"
var killfeed: Array[Dictionary] = []
var _next_kill_id: int = 1

# Input state
var _mouse_down: bool = false
var _mouse_just_pressed: bool = false
var _is_dragging_look: bool = false
var _pointer_locked: bool = false
var _macos_checked: bool = false
var _is_macos_cached: bool = false
var _touch_controls_enabled: bool = false
var _virtual_move: Vector2 = Vector2.ZERO
var _virtual_fire_down: bool = false
var _virtual_fire_just_pressed: bool = false
var _virtual_crouch: bool = false
var _virtual_jump_queued: bool = false

# Scene nodes
var camera: Camera3D
var view_model_mount: Node3D
var view_models: Dictionary = {}
var _muzzle_flash_mesh: MeshInstance3D
var _muzzle_flash_timer: float = 0.0
var _bots_container: Node3D
var _grenades_container: Node3D
var _fx_container: Node3D

var bots: Array[Dictionary] = []
var _bots_by_id: Dictionary = {}
var _grenades: Array[Dictionary] = []
var _tracer_pool: Array[Dictionary] = []
var _tracer_cursor: int = 0
var _particle_mmi: MultiMeshInstance3D
var _particles: Array[Dictionary] = []
var _particle_cursor: int = 0

func _ready() -> void:
	_colliders = MapData.get_map_colliders()
	_textures = ProceduralTextures.create_texture_set()
	ArenaBuilder.build_arena(self, _textures)

	camera = Camera3D.new()
	camera.name = "MainCamera"
	camera.fov = 75.0
	camera.near = 0.08
	camera.far = 220.0
	camera.rotation_order = EULER_ORDER_YXZ
	camera.current = true
	add_child(camera)

	_setup_view_models()

	_bots_container = Node3D.new()
	_bots_container.name = "Bots"
	add_child(_bots_container)

	_grenades_container = Node3D.new()
	_grenades_container.name = "Grenades"
	add_child(_grenades_container)

	_fx_container = Node3D.new()
	_fx_container.name = "Effects"
	add_child(_fx_container)

	_setup_fx_pools()
	_init_default_loadout()
	_spawn_round_bots()
	_update_visible_view_model()
	push_hud_snapshot()

func _init_default_loadout() -> void:
	slots = {
		1: GameTypes.create_weapon_instance("m4a1s"),
		2: GameTypes.create_weapon_instance("usps"),
		3: GameTypes.create_weapon_instance("karambit"),
		4: GameTypes.create_weapon_instance("he_grenade"),
		5: GameTypes.create_weapon_instance("flashbang"),
	}
	active_slot = 1
	he_count = 1
	flash_count = 1

func _setup_view_models() -> void:
	view_model_mount = Node3D.new()
	view_model_mount.name = "ViewModelMount"
	view_model_mount.position = Vector3(0.24, -0.22, -0.35)
	camera.add_child(view_model_mount)

	for wid in GameTypes.ALL_WEAPON_IDS:
		var vm: Dictionary = ProceduralModels.build_view_model(wid)
		var vm_root: Node3D = vm["root"]
		vm_root.visible = false
		view_model_mount.add_child(vm_root)
		view_models[wid] = vm

	_muzzle_flash_mesh = MeshInstance3D.new()
	var flash_sphere := SphereMesh.new()
	flash_sphere.radius = 0.075
	flash_sphere.height = 0.15
	flash_sphere.radial_segments = 6
	flash_sphere.rings = 4
	_muzzle_flash_mesh.mesh = flash_sphere
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1.0, 0.82, 0.48, 0.92)
	_muzzle_flash_mesh.material_override = flash_mat
	_muzzle_flash_mesh.visible = false
	view_model_mount.add_child(_muzzle_flash_mesh)

func _setup_fx_pools() -> void:
	var tracer_box := BoxMesh.new()
	tracer_box.size = Vector3(0.018, 0.018, 1.0)
	for i in range(TRACER_POOL_SIZE):
		var mi := MeshInstance3D.new()
		mi.mesh = tracer_box
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.87, 0.6, 0.0)
		mi.material_override = mat
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fx_container.add_child(mi)
		_tracer_pool.append({"mesh": mi, "mat": mat, "life": 0.0, "max_life": 0.12})

	_particle_mmi = MultiMeshInstance3D.new()
	_particle_mmi.name = "Particles"
	_particle_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var p_box := BoxMesh.new()
	p_box.size = Vector3(0.09, 0.09, 0.09)
	mm.mesh = p_box
	mm.instance_count = PARTICLE_POOL_SIZE
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.vertex_color_use_as_albedo = true
	_particle_mmi.material_override = p_mat
	for i in range(PARTICLE_POOL_SIZE):
		_particles.append({
			"active": false,
			"pos": Vector3(0.0, -50.0, 0.0),
			"vel": Vector3.ZERO,
			"life": 0.0,
			"max_life": 0.4,
			"scale": 0.0,
		})
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -50, 0)))
		mm.set_instance_color(i, Color("#ffc168"))
	_particle_mmi.multimesh = mm
	_fx_container.add_child(_particle_mmi)

func get_active_weapon_id() -> String:
	var inst = slots.get(active_slot, null)
	return String(inst["id"]) if inst != null else "karambit"

func _update_visible_view_model() -> void:
	var active_id: String = get_active_weapon_id()
	for wid in view_models.keys():
		var vm_root: Node3D = view_models[wid]["root"]
		vm_root.visible = (wid == active_id and not is_scoped and phase == GameTypes.GamePhase.PLAYING)

func _spawn_round_bots() -> void:
	for child in _bots_container.get_children():
		child.queue_free()
	bots.clear()
	_bots_by_id.clear()

	var tuning: Dictionary = GameRules.get_difficulty_tuning(difficulty)
	var spawns: Array[Dictionary] = MapData.get_bot_spawns()
	var count: int = mini(bot_count, spawns.size())

	var laser_box := BoxMesh.new()
	laser_box.size = Vector3(0.015, 0.015, 1.0)
	var laser_mat := StandardMaterial3D.new()
	laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_mat.albedo_color = Color(1.0, 0.23, 0.19, 0.78)

	for i in range(count):
		var spec: Dictionary = spawns[i]
		var bid: String = spec["id"]
		var arch: GameTypes.BotArchetype = spec["archetype"]
		var rig: Dictionary = ProceduralModels.build_bot_rig(bid, arch)
		var root_node: Node3D = rig["root"]
		var spawn_pos: Vector3 = spec["pos"]
		root_node.position = spawn_pos
		_bots_container.add_child(root_node)

		var wid: String = "awp" if arch == GameTypes.BotArchetype.SNIPER else ("ak47" if arch == GameTypes.BotArchetype.ENTRY else "m4a1s")
		var laser := MeshInstance3D.new()
		laser.mesh = laser_box
		laser.material_override = laser_mat
		laser.visible = false
		laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bots_container.add_child(laser)

		var bot: Dictionary = {
			"id": bid,
			"name": MapData.BOT_NAMES[i % MapData.BOT_NAMES.size()],
			"archetype": arch,
			"rig": rig,
			"pos": spawn_pos,
			"vel": Vector3.ZERO,
			"yaw": 0.0,
			"hp": float(tuning["bot_hp"]),
			"max_hp": float(tuning["bot_hp"]),
			"armor": 35.0 if difficulty == GameTypes.BotDifficulty.RECRUIT else 85.0,
			"has_helmet": difficulty == GameTypes.BotDifficulty.ELITE,
			"ammo_in_mag": int(GameTypes.WEAPONS[wid]["magazine_size"]),
			"max_mag": int(GameTypes.WEAPONS[wid]["magazine_size"]),
			"reload_timer": 0.0,
			"fire_cooldown": 0.5 + float(i) * 0.2,
			"reaction_timer": 0.0,
			"blind_timer": 0.0,
			"hit_flash_timer": 0.0,
			"ko_timer": 0.0,
			"state": GameTypes.BotAIState.PATROL,
			"patrol_route": spec["patrol_route"],
			"patrol_idx": 0,
			"last_heard_pos": spawn_pos,
			"time_since_heard": 99.0,
			"strafe_phase": float(i) * 1.4,
			"walk_dist": 0.0,
			"weapon_id": wid,
			"laser": laser,
		}
		bots.append(bot)
		_bots_by_id[bid] = bot

func start_new_match(diff: GameTypes.BotDifficulty = difficulty, count: int = bot_count) -> void:
	difficulty = diff
	bot_count = clampi(count, 1, 5)
	buy_menu_open = false

	round_num = 1
	player_score = 0
	bot_score = 0
	kills = 0
	headshots = 0
	shots_fired = 0
	shots_hit = 0
	damage_dealt = 0
	player_cash = 3500
	killfeed.clear()

	_init_default_loadout()
	_reset_round_state("banner_round_1", 1)
	set_phase(GameTypes.GamePhase.PLAYING)

func _reset_round_state(banner_key: String, banner_arg: int = 0) -> void:
	player_pos = MapData.PLAYER_SPAWN
	player_vel = Vector3.ZERO
	player_yaw = MapData.PLAYER_SPAWN_YAW
	player_pitch = 0.0
	player_grounded = true
	player_hp = 100.0
	player_armor = 100.0
	player_has_helmet = true
	is_reloading = false
	is_scoped = false
	_fire_cooldown = 0.0
	_hitstop_timer = 0.0
	camera.fov = 75.0
	_recoil_pitch = 0.0
	_recoil_yaw = 0.0
	_recoil_bloom = 0.0
	_spray_count = 0
	_flash_alpha = 0.0
	_damage_flash_alpha = 0.0
	_round_pending_state = "none"
	_round_end_delay = 0.0
	reset_virtual_inputs()

	for s in [1, 2]:
		var w = slots.get(s, null)
		if w != null:
			var spec: Dictionary = GameTypes.WEAPONS[w["id"]]
			w["ammo_in_mag"] = int(spec["magazine_size"])
			w["reserve_ammo"] = int(spec["reserve_max"])

	for child in _grenades_container.get_children():
		child.queue_free()
	_grenades.clear()

	_spawn_round_bots()
	_round_banner_key = banner_key
	_round_banner_arg = banner_arg
	_round_banner = Localization.format_banner(banner_key, banner_arg)
	_round_banner_timer = 2.4
	_update_visible_view_model()
	push_hud_snapshot()

func set_phase(next_phase: GameTypes.GamePhase) -> void:
	phase = next_phase
	_mouse_down = false
	_mouse_just_pressed = false
	_is_dragging_look = false
	reset_virtual_inputs()
	if next_phase != GameTypes.GamePhase.PLAYING:
		buy_menu_open = false
		is_scoped = false
		camera.fov = 75.0
		release_pointer_lock()
	else:
		if not buy_menu_open and not _touch_controls_enabled:
			request_pointer_lock()
	_update_visible_view_model()
	emit_signal("phase_changed", next_phase)
	push_hud_snapshot()

func set_buy_menu_open(open_state: bool) -> void:
	buy_menu_open = open_state
	_mouse_down = false
	_is_dragging_look = false
	if open_state:
		reset_virtual_inputs()
		release_pointer_lock()
	elif phase == GameTypes.GamePhase.PLAYING and not _touch_controls_enabled:
		request_pointer_lock()
	push_hud_snapshot()

func request_pointer_lock() -> void:
	if phase == GameTypes.GamePhase.PLAYING and not buy_menu_open and not _touch_controls_enabled and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_pointer_locked = true
		push_hud_snapshot()

func release_pointer_lock() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pointer_locked = false

func set_touch_controls_enabled(enabled: bool) -> void:
	_touch_controls_enabled = enabled
	if enabled:
		_mouse_down = false
		_mouse_just_pressed = false
		_is_dragging_look = false
		release_pointer_lock()
	else:
		reset_virtual_inputs()
	push_hud_snapshot()

func reset_virtual_inputs() -> void:
	_virtual_move = Vector2.ZERO
	_virtual_fire_down = false
	_virtual_fire_just_pressed = false
	_virtual_crouch = false
	_virtual_jump_queued = false

func set_virtual_move(move_vec: Vector2) -> void:
	_virtual_move = move_vec.limit_length(1.0)

func apply_virtual_look(delta_px: Vector2) -> void:
	if phase != GameTypes.GamePhase.PLAYING or buy_menu_open:
		return
	var sens: float = 0.0020 if is_scoped else 0.0048
	player_yaw -= delta_px.x * sens
	player_pitch = clampf(player_pitch - delta_px.y * sens, -PI * 0.46, PI * 0.46)

func set_virtual_fire(pressed: bool) -> void:
	if phase != GameTypes.GamePhase.PLAYING or buy_menu_open:
		_virtual_fire_down = false
		_virtual_fire_just_pressed = false
		return
	if pressed and not _virtual_fire_down:
		_virtual_fire_just_pressed = true
	_virtual_fire_down = pressed

func set_virtual_crouch(active: bool) -> void:
	_virtual_crouch = active
	push_hud_snapshot()

func trigger_virtual_jump() -> void:
	if phase == GameTypes.GamePhase.PLAYING and not buy_menu_open:
		_virtual_jump_queued = true

func trigger_virtual_reload() -> void:
	if phase == GameTypes.GamePhase.PLAYING and not buy_menu_open:
		_try_start_reload()

func trigger_virtual_scope() -> void:
	if phase == GameTypes.GamePhase.PLAYING and not buy_menu_open:
		_toggle_scope()

func trigger_virtual_grenade(kind: String) -> void:
	if phase != GameTypes.GamePhase.PLAYING or buy_menu_open:
		return
	if kind == "he_grenade" and he_count > 0:
		select_slot(4)
		_throw_active_grenade("he_grenade")
	elif kind == "flashbang" and flash_count > 0:
		select_slot(5)
		_throw_active_grenade("flashbang")

func _is_player_crouching() -> bool:
	return Input.is_action_pressed("crouch") or _virtual_crouch

func _is_macos_platform() -> bool:
	if _macos_checked:
		return _is_macos_cached
	_macos_checked = true
	if OS.has_feature("macos") or OS.has_feature("web_macos"):
		_is_macos_cached = true
		return true
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var res = JavaScriptBridge.eval(
			"(function(){try{return /Mac/i.test(navigator.platform||'')||/Macintosh/i.test(navigator.userAgent||'');}catch(e){return false;}})()"
		)
		_is_macos_cached = bool(res)
	return _is_macos_cached

func _is_macos_ctrl_fire_click(event: InputEventMouseButton) -> bool:
	# On macOS (native & web), holding Ctrl (crouch) + Left Click is remapped by the OS to Right Click.
	return (
		_is_macos_platform()
		and event.button_index == MOUSE_BUTTON_RIGHT
		and (event.ctrl_pressed or Input.is_key_pressed(KEY_CTRL))
	)

func _toggle_scope() -> void:
	var spec: Dictionary = GameTypes.WEAPONS[get_active_weapon_id()]
	if bool(spec["can_scope"]) and not is_reloading:
		is_scoped = not is_scoped
		camera.fov = 28.0 if is_scoped else 75.0
		_play_click(1450.0)
		_update_visible_view_model()
		push_hud_snapshot()

func _audio() -> TacticalAudioManager:
	return get_node_or_null("/root/TacticalAudio") as TacticalAudioManager

func _play_click(freq: float) -> void:
	var a := _audio()
	if a != null:
		a.play_metallic_click(freq)

func select_slot(slot_idx: int) -> void:
	if slots.get(slot_idx, null) == null:
		return
	if slot_idx == 4 and he_count <= 0:
		return
	if slot_idx == 5 and flash_count <= 0:
		return
	active_slot = slot_idx
	is_reloading = false
	is_scoped = false
	camera.fov = 75.0
	_spray_count = 0
	_view_kick_z = -0.07
	_play_click(880.0)
	_update_visible_view_model()
	push_hud_snapshot()

func buy_item(item: String) -> Dictionary:
	var primary_id: String = String(slots[1]["id"]) if slots.get(1, null) != null else ""
	var pistol_id: String = String(slots[2]["id"]) if slots.get(2, null) != null else "usps"
	var check: Dictionary = GameRules.evaluate_purchase(
		item,
		player_cash,
		player_armor,
		player_has_helmet,
		he_count,
		flash_count,
		primary_id,
		pistol_id
	)
	if not bool(check["ok"]):
		_play_click(320.0)
		return check

	player_cash -= int(check["cost"])
	_play_click(1260.0)

	if item == "kevlar_helmet":
		player_armor = 100.0
		player_has_helmet = true
	elif item == "he_grenade":
		he_count += 1
		slots[4] = GameTypes.create_weapon_instance("he_grenade")
	elif item == "flashbang":
		flash_count += 1
		slots[5] = GameTypes.create_weapon_instance("flashbang")
	else:
		var spec: Dictionary = GameTypes.WEAPONS[item]
		var slot_idx: int = int(spec["slot"])
		slots[slot_idx] = GameTypes.create_weapon_instance(item)
		select_slot(slot_idx)

	push_hud_snapshot()
	return {"ok": true, "cost": check["cost"], "reason": ""}

func grant_ad_bonus_cash(amount: int = 1500) -> void:
	if amount <= 0:
		return
	player_cash = mini(16000, player_cash + amount)
	_play_click(1420.0)
	push_hud_snapshot()

func _unhandled_input(event: InputEvent) -> void:
	if phase != GameTypes.GamePhase.PLAYING or buy_menu_open:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var kc: Key = event.physical_keycode
		if kc == KEY_1:
			select_slot(1)
		elif kc == KEY_2:
			select_slot(2)
		elif kc == KEY_3:
			select_slot(3)
		elif kc == KEY_4:
			select_slot(4)
		elif kc == KEY_5:
			select_slot(5)
		elif kc == KEY_G:
			if he_count > 0:
				select_slot(4)
				_throw_active_grenade("he_grenade")
		elif kc == KEY_F:
			if flash_count > 0:
				select_slot(5)
				_throw_active_grenade("flashbang")
		elif kc == KEY_R:
			_try_start_reload()
	elif event is InputEventMouseButton:
		# Ignore emulated or synthetic mouse events when touch controls are active so screen taps never fire or jerk aim.
		if event.device == InputEvent.DEVICE_ID_EMULATION or _touch_controls_enabled:
			return
		var is_fire_click: bool = (event.button_index == MOUSE_BUTTON_LEFT) or _is_macos_ctrl_fire_click(event)
		if is_fire_click:
			if event.pressed:
				_mouse_down = true
				_mouse_just_pressed = true
				_is_dragging_look = true
				if not _touch_controls_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					request_pointer_lock()
			else:
				_mouse_down = false
				_is_dragging_look = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_toggle_scope()
			elif _mouse_down and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				# Guard against stuck fire if Ctrl was pressed mid-spray before releasing LMB on macOS.
				_mouse_down = false
				_is_dragging_look = false
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION or _touch_controls_enabled:
			return
		var sens: float = 0.00095 if is_scoped else 0.0022
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			player_yaw -= event.relative.x * sens
			player_pitch = clampf(player_pitch - event.relative.y * sens, -PI * 0.46, PI * 0.46)
		elif _is_dragging_look:
			player_yaw -= event.relative.x * sens * 1.4
			player_pitch = clampf(player_pitch - event.relative.y * sens * 1.4, -PI * 0.46, PI * 0.46)

func _physics_process(delta: float) -> void:
	step_simulation(minf(delta, 0.05))

func step_simulation(dt: float) -> void:
	_elapsed += dt
	if DisplayServer.get_name() != "headless":
		_pointer_locked = (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	if phase == GameTypes.GamePhase.TITLE:
		var t: float = _elapsed * 0.22 + 0.55
		var cam_pos := Vector3(sin(t) * 24.0, 9.5 + sin(t * 1.4) * 1.6, cos(t) * 26.0)
		camera.look_at_from_position(cam_pos, Vector3(0.0, 1.8, -4.0), Vector3.UP)
		_update_bots(dt, false)
		_update_effects(dt)
	elif phase == GameTypes.GamePhase.PLAYING:
		if _hitstop_timer > 0.0:
			_hitstop_timer -= dt
			_update_effects(dt)
		else:
			if not buy_menu_open:
				_update_player(dt)
			_update_bots(dt, true)
			_update_grenades(dt)
			_update_effects(dt)

		if _round_pending_state != "none":
			_round_end_delay -= dt
			if _round_end_delay <= 0.0:
				var match_over: bool = (player_score >= 3 or bot_score >= 3 or round_num >= MAX_ROUNDS)
				if match_over:
					set_phase(GameTypes.GamePhase.GAMEOVER)
				else:
					round_num += 1
					_reset_round_state("banner_round_n", round_num)

		_mouse_just_pressed = false
		_virtual_fire_just_pressed = false
		_hud_sync_timer += dt
		if _hud_sync_timer >= 0.05:
			_hud_sync_timer = 0.0
			push_hud_snapshot()

func _try_start_reload() -> void:
	var inst = slots.get(active_slot, null)
	if inst == null:
		return
	var spec: Dictionary = GameTypes.WEAPONS[inst["id"]]
	var cat: GameTypes.WeaponCategory = spec["category"]
	if cat == GameTypes.WeaponCategory.MELEE or cat == GameTypes.WeaponCategory.GRENADE:
		return
	if is_reloading or int(inst["ammo_in_mag"]) >= int(spec["magazine_size"]) or int(inst["reserve_ammo"]) <= 0:
		return
	is_reloading = true
	_reload_timer = float(spec["reload_time"])
	is_scoped = false
	camera.fov = 75.0
	_update_visible_view_model()
	if _audio() != null:
		_audio().play_reload()

func _finish_reload() -> void:
	is_reloading = false
	var inst = slots.get(active_slot, null)
	if inst == null:
		return
	var spec: Dictionary = GameTypes.WEAPONS[inst["id"]]
	var need: int = int(spec["magazine_size"]) - int(inst["ammo_in_mag"])
	var take: int = mini(need, int(inst["reserve_ammo"]))
	inst["ammo_in_mag"] = int(inst["ammo_in_mag"]) + take
	inst["reserve_ammo"] = int(inst["reserve_ammo"]) - take

func _try_fire_weapon() -> void:
	var inst = slots.get(active_slot, null)
	if inst == null:
		return
	var wid: String = String(inst["id"])
	var spec: Dictionary = GameTypes.WEAPONS[wid]
	var cat: GameTypes.WeaponCategory = spec["category"]

	if cat == GameTypes.WeaponCategory.GRENADE:
		_throw_active_grenade(wid)
		return

	if cat != GameTypes.WeaponCategory.MELEE:
		if int(inst["ammo_in_mag"]) <= 0:
			_try_start_reload()
			return
		inst["ammo_in_mag"] = int(inst["ammo_in_mag"]) - 1
	else:
		_knife_swing_timer = 0.22

	_fire_cooldown = 60.0 / float(spec["fire_rate_rpm"])
	_spray_reset_timer = 0.4

	var kick: Vector2 = GameRules.get_recoil_for_shot(wid, _spray_count)
	_recoil_yaw += kick.x
	_recoil_pitch += kick.y
	_spray_count += 1
	_recoil_bloom = minf(1.6, _recoil_bloom + (0.36 if cat == GameTypes.WeaponCategory.PISTOL else 0.24))
	_view_kick_z = 0.065
	_view_kick_rot = 0.09
	_camera_trauma = minf(0.65, _camera_trauma + (0.45 if wid == "awp" else 0.14))

	if cat != GameTypes.WeaponCategory.MELEE:
		shots_fired += 1
		_muzzle_flash_timer = 0.045
		_muzzle_flash_mesh.visible = not bool(spec["silenced"])
		if view_models.has(wid):
			var mp: Node3D = view_models[wid]["muzzle_point"]
			_muzzle_flash_mesh.position = mp.position
			_muzzle_flash_mesh.rotation.z = randf() * PI
		var hear_radius: float = 16.0 if bool(spec["silenced"]) else 36.0
		for b in bots:
			if b["pos"].distance_to(player_pos) <= hear_radius:
				b["last_heard_pos"] = player_pos
				b["time_since_heard"] = 0.0

	if _audio() != null:
		_audio().play_gunshot(wid, 1.0)

	var crouching: bool = _is_player_crouching()
	var horiz_speed: float = Vector2(player_vel.x, player_vel.z).length()
	var spread: float = GameRules.compute_dynamic_spread(wid, horiz_speed, player_grounded, crouching, is_scoped, _recoil_bloom)

	var eye_origin := Vector3(player_pos.x, player_pos.y + (1.25 if crouching else 1.62), player_pos.z)
	var cam_basis: Basis = camera.global_transform.basis
	var cam_fwd: Vector3 = (-cam_basis.z).normalized()
	var cam_right: Vector3 = cam_basis.x.normalized()
	var cam_up: Vector3 = cam_basis.y.normalized()

	var hit_something: bool = false
	var best_hit_type: String = "body"
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var max_range: float = float(spec["range"])
	var wall_pen: float = float(spec["wall_penetration"])

	for _p in range(int(spec["pellets"])):
		var rx: float = randf_range(-spread, spread) + deg_to_rad(kick.x * 0.35)
		var ry: float = randf_range(-spread, spread) + deg_to_rad(kick.y * 0.35)
		var ray_dir: Vector3 = (cam_fwd + cam_right * rx + cam_up * ry).normalized()
		var ray_end: Vector3 = eye_origin + ray_dir * max_range

		var wall_hits: Array[Dictionary] = []
		for box in _colliders:
			var t: float = GameRules.intersect_segment_aabb(eye_origin, ray_end, box)
			if t >= 0.0:
				wall_hits.append({"t": t, "penetrable": bool(box["penetrable"])})
		wall_hits.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))

		var max_allowed_dist: float = max_range
		var pen_count: int = 0
		for wh in wall_hits:
			if not bool(wh["penetrable"]) or wall_pen <= 0.1:
				max_allowed_dist = float(wh["t"]) * max_range
				break
			pen_count += 1
			if pen_count > 1:
				max_allowed_dist = float(wh["t"]) * max_range
				break

		var query := PhysicsRayQueryParameters3D.create(eye_origin, eye_origin + ray_dir * max_allowed_dist)
		query.collision_mask = 2
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var hit: Dictionary = space.intersect_ray(query)
		var end_point: Vector3 = eye_origin + ray_dir * minf(max_allowed_dist, 65.0)

		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"]
			var hit_dist: float = eye_origin.distance_to(hit_pos)
			var col_area: Object = hit["collider"]
			end_point = hit_pos
			if col_area != null and col_area.has_meta("bot_id"):
				var bid: String = String(col_area.get_meta("bot_id"))
				var bot: Dictionary = _bots_by_id.get(bid, {})
				if not bot.is_empty() and bot["state"] != GameTypes.BotAIState.KO:
					var region: GameTypes.HitRegion = col_area.get_meta("hit_region", GameTypes.HitRegion.CHEST)
					var walls_through: int = 0
					for wh in wall_hits:
						if float(wh["t"]) * max_range < hit_dist and bool(wh["penetrable"]):
							walls_through += 1
					var dmg_res: Dictionary = GameRules.calculate_ballistic_damage(
						wid, region, hit_dist, float(bot["armor"]), bool(bot["has_helmet"]), walls_through
					)
					var hp_dmg: int = int(dmg_res["hp_damage"])
					bot["hp"] = maxf(0.0, float(bot["hp"]) - float(hp_dmg))
					bot["armor"] = maxf(0.0, float(bot["armor"]) - float(dmg_res["armor_damage"]))
					bot["hit_flash_timer"] = 0.055
					bot["last_heard_pos"] = player_pos
					bot["time_since_heard"] = 0.0
					damage_dealt += hp_dmg
					hit_something = true

					bot["vel"] = bot["vel"] + ray_dir * (3.5 if wid == "nova" else 1.4)
					var is_hs: bool = bool(dmg_res["is_headshot"])
					_spawn_particle_burst(hit_pos, Color("#ff453a") if is_hs else Color("#d9483b"), 10)

					if float(bot["hp"]) <= 0.0:
						_handle_bot_eliminated(bot, String(spec["short_name"]), is_hs, int(spec["kill_reward"]))
						best_hit_type = "kill"
						_hitstop_timer = 0.045
					elif is_hs and best_hit_type != "kill":
						best_hit_type = "head"
						_hitstop_timer = 0.03
		elif not wall_hits.is_empty():
			var first_dist: float = float(wall_hits[0]["t"]) * max_range
			end_point = eye_origin + ray_dir * first_dist
			if cat != GameTypes.WeaponCategory.MELEE:
				_spawn_particle_burst(end_point, Color("#e8d5b5"), 5)

		if cat != GameTypes.WeaponCategory.MELEE:
			var start_pt: Vector3
			if view_models.has(wid) and not is_scoped:
				var mp: Node3D = view_models[wid]["muzzle_point"]
				start_pt = mp.global_position
			else:
				start_pt = eye_origin + cam_right * 0.12 - cam_up * 0.08
			_spawn_tracer(start_pt, end_point)

	if hit_something:
		shots_hit += 1
		_hitmarker_type = best_hit_type
		_hitmarker_timer = 0.22
		if _audio() != null:
			_audio().play_hitmarker(best_hit_type == "head" or best_hit_type == "kill")

	if wid == "awp" and is_scoped:
		is_scoped = false
		camera.fov = 75.0
		_update_visible_view_model()

func _throw_active_grenade(kind: String) -> void:
	if kind == "he_grenade":
		if he_count <= 0:
			return
		he_count -= 1
		if he_count == 0:
			slots[4] = null
	else:
		if flash_count <= 0:
			return
		flash_count -= 1
		if flash_count == 0:
			slots[5] = null

	if _audio() != null:
		_audio().play_gunshot("karambit", 0.8)

	var mesh := Node3D.new()
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = 0.14
	cyl.radial_segments = 10
	body.mesh = cyl
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("#45583a") if kind == "he_grenade" else Color("#b0bac5")
	body_mat.roughness = 0.45
	body_mat.metallic = 0.5
	body.material_override = body_mat
	mesh.add_child(body)

	var band := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 0.064
	bcyl.bottom_radius = 0.064
	bcyl.height = 0.03
	bcyl.radial_segments = 10
	band.mesh = bcyl
	var band_mat := StandardMaterial3D.new()
	band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	band_mat.albedo_color = Color("#f59e0b") if kind == "he_grenade" else Color("#38bdf8")
	band.material_override = band_mat
	band.position.y = 0.02
	mesh.add_child(band)

	var forward: Vector3 = (-camera.global_transform.basis.z).normalized()
	var start_pos := Vector3(player_pos.x, player_pos.y + 1.55, player_pos.z) + forward * 0.6
	mesh.position = start_pos
	_grenades_container.add_child(mesh)

	var throw_vel: Vector3 = forward * 17.5
	throw_vel.y += 4.2

	_grenades.append({
		"kind": kind,
		"mesh": mesh,
		"pos": start_pos,
		"vel": throw_vel,
		"fuse": 1.55 if kind == "he_grenade" else 1.25,
		"active": true,
	})

	if slots.get(1, null) != null:
		select_slot(1)
	elif slots.get(2, null) != null:
		select_slot(2)
	else:
		select_slot(3)

func _detonate_grenade(g: Dictionary) -> void:
	g["active"] = false
	var g_mesh: Node3D = g["mesh"]
	if is_instance_valid(g_mesh):
		g_mesh.queue_free()

	var is_flash: bool = (String(g["kind"]) == "flashbang")
	var g_pos: Vector3 = g["pos"]
	if _audio() != null:
		_audio().play_explosion(is_flash)
	_spawn_particle_burst(g_pos, Color.WHITE if is_flash else Color("#ff7b29"), 24)
	_camera_trauma = minf(1.0, _camera_trauma + (0.25 if is_flash else 0.65))

	for b in bots:
		if b["state"] != GameTypes.BotAIState.KO and b["pos"].distance_to(g_pos) < 35.0:
			b["last_heard_pos"] = g_pos
			b["time_since_heard"] = 0.0

	if is_flash:
		var player_eye := Vector3(player_pos.x, player_pos.y + 1.6, player_pos.z)
		var dist_p: float = player_eye.distance_to(g_pos)
		if dist_p < 18.0 and _has_line_of_sight(g_pos, player_eye):
			var to_flash: Vector3 = (g_pos - player_eye).normalized()
			var look_dir: Vector3 = (-camera.global_transform.basis.z).normalized()
			if to_flash.dot(look_dir) > 0.15:
				_flash_alpha = minf(1.0, 0.85 * (1.0 - dist_p / 20.0))

		for b in bots:
			if b["state"] == GameTypes.BotAIState.KO:
				continue
			var b_pos: Vector3 = b["pos"]
			var bot_eye := Vector3(b_pos.x, b_pos.y + 1.65, b_pos.z)
			var dist_b: float = bot_eye.distance_to(g_pos)
			if dist_b < 18.0 and _has_line_of_sight(g_pos, bot_eye):
				b["blind_timer"] = maxf(float(b["blind_timer"]), 3.2 * (1.0 - dist_b / 22.0))
		return

	var blast_radius: float = float(GameTypes.WEAPONS["he_grenade"]["range"])
	var he_dmg: float = float(GameTypes.WEAPONS["he_grenade"]["damage"])
	for b in bots:
		if b["state"] == GameTypes.BotAIState.KO:
			continue
		var b_pos: Vector3 = b["pos"]
		var dist: float = b_pos.distance_to(g_pos)
		if dist <= blast_radius:
			var falloff: float = maxf(0.15, 1.0 - dist / blast_radius)
			var dmg: int = int(round(he_dmg * falloff))
			b["hp"] = maxf(0.0, float(b["hp"]) - float(dmg))
			b["hit_flash_timer"] = 0.08
			damage_dealt += dmg
			var push_dir: Vector3 = (b_pos - g_pos)
			if push_dir.length_squared() > 0.001:
				b["vel"] = b["vel"] + push_dir.normalized() * (8.0 * falloff)
			if float(b["hp"]) <= 0.0:
				_handle_bot_eliminated(b, "__HE_FRAG__", false, 300)

	var p_dist: float = player_pos.distance_to(g_pos)
	if p_dist <= blast_radius:
		var falloff: float = maxf(0.1, 1.0 - p_dist / blast_radius)
		_apply_player_damage(int(round(58.0 * falloff)))

func _disable_bot_hitboxes(node: Node) -> void:
	if node is Area3D:
		node.monitorable = false
	for child in node.get_children():
		_disable_bot_hitboxes(child)

func _handle_bot_eliminated(bot: Dictionary, weapon_short: String, is_hs: bool, reward: int) -> void:
	bot["state"] = GameTypes.BotAIState.KO
	bot["ko_timer"] = 0.38
	var laser: Node3D = bot["laser"]
	laser.visible = false
	_disable_bot_hitboxes(bot["rig"]["root"])

	kills += 1
	if is_hs:
		headshots += 1
	player_cash += reward
	killfeed.push_front({
		"id": _next_kill_id,
		"killer": "__YOU__",
		"victim": bot["name"],
		"weapon": weapon_short,
		"headshot": is_hs,
		"timestamp": _elapsed,
	})
	_next_kill_id += 1
	if killfeed.size() > 4:
		killfeed.resize(4)

	var alive: int = 0
	for b in bots:
		if b["state"] != GameTypes.BotAIState.KO:
			alive += 1
	if alive == 0 and _round_pending_state == "none":
		_round_pending_state = "won"
		_round_end_delay = 1.6
		player_score += 1
		player_cash += 3250
		_round_banner_key = "banner_round_won"
		_round_banner_arg = 0
		_round_banner = Localization.format_banner(_round_banner_key, 0)
		_round_banner_timer = 2.5
		if _audio() != null:
			_audio().play_round_sting(true)

func _apply_player_damage(raw_dmg: int) -> void:
	if phase != GameTypes.GamePhase.PLAYING or player_hp <= 0.0:
		return
	var hp_dmg: int = raw_dmg
	if player_armor > 0.0:
		var absorbed: float = minf(player_armor, round(float(raw_dmg) * 0.35))
		player_armor -= absorbed
		hp_dmg = maxi(1, raw_dmg - int(absorbed))
	player_hp = maxf(0.0, player_hp - float(hp_dmg))
	_damage_flash_alpha = minf(0.85, _damage_flash_alpha + 0.55)
	_camera_trauma = minf(0.85, _camera_trauma + 0.32)
	if _audio() != null:
		_audio().play_player_hurt()

	if player_hp <= 0.0 and _round_pending_state == "none":
		_round_pending_state = "lost"
		_round_end_delay = 0.85
		bot_score += 1
		player_cash += 1900
		killfeed.push_front({
			"id": _next_kill_id,
			"killer": "__BOT_SQUAD__",
			"victim": "__YOU__",
			"weapon": "__RIFLE__",
			"headshot": false,
			"timestamp": _elapsed,
		})
		_round_banner_key = "banner_round_lost"
		_round_banner_arg = 0
		_round_banner = Localization.format_banner(_round_banner_key, 0)
		_round_banner_timer = 1.8
		_next_kill_id += 1
		if killfeed.size() > 4:
			killfeed.resize(4)
		if _audio() != null:
			_audio().play_round_sting(false)

func _has_line_of_sight(from_pt: Vector3, to_pt: Vector3) -> bool:
	for box in _colliders:
		if GameRules.intersect_segment_aabb(from_pt, to_pt, box) >= 0.0:
			return false
	return true

func _orient_beam(beam: MeshInstance3D, start_pt: Vector3, end_pt: Vector3) -> void:
	var diff: Vector3 = end_pt - start_pt
	var length: float = diff.length()
	if length < 0.001:
		beam.visible = false
		return
	var mid: Vector3 = (start_pt + end_pt) * 0.5
	var up_vec: Vector3 = Vector3.UP if absf(diff.normalized().y) < 0.99 else Vector3.RIGHT
	beam.look_at_from_position(mid, end_pt, up_vec)
	beam.scale = Vector3(1.0, 1.0, length)

func _spawn_tracer(start_pt: Vector3, end_pt: Vector3) -> void:
	var slot: Dictionary = _tracer_pool[_tracer_cursor]
	_tracer_cursor = (_tracer_cursor + 1) % _tracer_pool.size()
	var mi: MeshInstance3D = slot["mesh"]
	var mat: StandardMaterial3D = slot["mat"]
	_orient_beam(mi, start_pt, end_pt)
	slot["life"] = slot["max_life"]
	mat.albedo_color = Color(1.0, 0.87, 0.6, 0.9)
	mi.visible = true

func _spawn_particle_burst(origin: Vector3, col: Color, count: int) -> void:
	var mm: MultiMesh = _particle_mmi.multimesh
	for _i in range(count):
		var idx: int = _particle_cursor
		var p: Dictionary = _particles[idx]
		_particle_cursor = (_particle_cursor + 1) % _particles.size()
		p["active"] = true
		p["pos"] = origin
		p["vel"] = Vector3(randf_range(-3.5, 3.5), randf_range(1.5, 6.0), randf_range(-3.5, 3.5))
		var ml: float = randf_range(0.25, 0.50)
		p["max_life"] = ml
		p["life"] = ml
		p["scale"] = randf_range(0.7, 1.5)
		mm.set_instance_color(idx, col)

func _update_player(dt: float) -> void:
	var key_turn_speed: float = 2.0
	if Input.is_key_pressed(KEY_LEFT):
		player_yaw += key_turn_speed * dt
	if Input.is_key_pressed(KEY_RIGHT):
		player_yaw -= key_turn_speed * dt
	if Input.is_key_pressed(KEY_UP):
		player_pitch = clampf(player_pitch + 1.5 * dt, -1.4, 1.4)
	if Input.is_key_pressed(KEY_DOWN):
		player_pitch = clampf(player_pitch - 1.5 * dt, -1.4, 1.4)

	var kb_fwd: float = (1.0 if Input.is_action_pressed("move_forward") else 0.0) - (1.0 if Input.is_action_pressed("move_back") else 0.0)
	var kb_str: float = (1.0 if Input.is_action_pressed("move_right") else 0.0) - (1.0 if Input.is_action_pressed("move_left") else 0.0)
	var fwd_in: float = clampf(kb_fwd + _virtual_move.y, -1.0, 1.0)
	var str_in: float = clampf(kb_str + _virtual_move.x, -1.0, 1.0)
	var crouching: bool = _is_player_crouching()
	var analog_mag: float = _virtual_move.length()
	var soft_touch_walk: bool = (analog_mag > 0.01 and analog_mag < 0.55 and absf(kb_fwd) < 0.01 and absf(kb_str) < 0.01)
	var walking: bool = Input.is_action_pressed("walk") or soft_touch_walk

	var fwd_x: float = -sin(player_yaw)
	var fwd_z: float = -cos(player_yaw)
	var right_x: float = cos(player_yaw)
	var right_z: float = -sin(player_yaw)

	var wish_x: float = fwd_x * fwd_in + right_x * str_in
	var wish_z: float = fwd_z * fwd_in + right_z * str_in
	var wish_len: float = Vector2(wish_x, wish_z).length()
	var wish_scale: float = minf(1.0, wish_len)
	if wish_len > 0.001:
		wish_x /= wish_len
		wish_z /= wish_len

	var spec: Dictionary = GameTypes.WEAPONS[get_active_weapon_id()]
	var base_speed: float = 3.2 if crouching else (3.8 if walking else 6.4)
	var max_speed: float = base_speed * float(spec["move_speed_multiplier"]) * (0.55 if is_scoped else 1.0) * (wish_scale if wish_len > 0.001 else 1.0)

	if player_grounded:
		var h_spd: float = Vector2(player_vel.x, player_vel.z).length()
		if h_spd > 0.01:
			var drop: float = h_spd * 11.5 * dt
			var factor: float = maxf(0.0, h_spd - drop) / h_spd
			player_vel.x *= factor
			player_vel.z *= factor
		var cur_proj: float = player_vel.x * wish_x + player_vel.z * wish_z
		var add_spd: float = max_speed - cur_proj
		if add_spd > 0.0 and wish_len > 0.001:
			var accel: float = minf(48.0 * dt, add_spd)
			player_vel.x += wish_x * accel
			player_vel.z += wish_z * accel
	else:
		var cur_proj: float = player_vel.x * wish_x + player_vel.z * wish_z
		var add_spd: float = max_speed - cur_proj
		if add_spd > 0.0 and wish_len > 0.001:
			var accel: float = minf(12.0 * dt, add_spd)
			player_vel.x += wish_x * accel
			player_vel.z += wish_z * accel

	if (Input.is_action_pressed("jump") or _virtual_jump_queued) and player_grounded:
		player_vel.y = 5.6
		player_grounded = false
	_virtual_jump_queued = false

	player_vel.y -= 17.5 * dt

	var next_pos := Vector3(player_pos.x + player_vel.x * dt, player_pos.y, player_pos.z + player_vel.z * dt)
	var resolved: Vector3 = GameRules.resolve_horizontal_collision(next_pos, 0.45, 1.3 if crouching else 1.8, _colliders)
	player_pos.x = resolved.x
	player_pos.z = resolved.z

	player_pos.y += player_vel.y * dt
	var support_y: float = GameRules.get_support_floor_y(player_pos.x, player_pos.z, player_pos.y, 0.45, _colliders)
	if player_pos.y <= support_y:
		player_pos.y = support_y
		player_vel.y = 0.0
		player_grounded = true
	else:
		player_grounded = false

	var h_speed: float = Vector2(player_vel.x, player_vel.z).length()
	if player_grounded and h_speed > 0.4:
		_walk_bob_phase += h_speed * dt * 2.2
		_step_dist_accum += h_speed * dt
		if _step_dist_accum >= 2.2 and not walking and not crouching:
			_step_dist_accum = 0.0
			if _audio() != null:
				_audio().play_footstep()
			for b in bots:
				if b["pos"].distance_to(player_pos) <= 12.0:
					b["last_heard_pos"] = player_pos
					b["time_since_heard"] = 0.0

	_fire_cooldown = maxf(0.0, _fire_cooldown - dt)
	_recoil_bloom = maxf(0.0, _recoil_bloom - dt * 3.8)
	if _spray_reset_timer > 0.0:
		_spray_reset_timer -= dt
		if _spray_reset_timer <= 0.0:
			_spray_count = 0

	if is_reloading:
		_reload_timer -= dt
		if _reload_timer <= 0.0:
			_finish_reload()
	else:
		var fire_down: bool = _mouse_down or _virtual_fire_down
		var fire_just: bool = _mouse_just_pressed or _virtual_fire_just_pressed
		var want_fire: bool = fire_down if bool(spec["automatic"]) else fire_just
		if want_fire and _fire_cooldown <= 0.0:
			_try_fire_weapon()

	_recoil_pitch = lerpf(_recoil_pitch, 0.0, 1.0 - exp(-10.0 * dt))
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, 1.0 - exp(-10.0 * dt))
	_view_kick_z = lerpf(_view_kick_z, 0.0, 1.0 - exp(-14.0 * dt))
	_view_kick_rot = lerpf(_view_kick_rot, 0.0, 1.0 - exp(-14.0 * dt))
	_knife_swing_timer = maxf(0.0, _knife_swing_timer - dt)

	var eye_h: float = 1.25 if crouching else 1.62
	var bob_y: float = (sin(_walk_bob_phase) * 0.035 * minf(1.0, h_speed / 5.0)) if player_grounded else 0.0
	var shake: float = _camera_trauma * _camera_trauma
	var shake_x: float = randf_range(-0.03, 0.03) * shake
	var shake_y: float = randf_range(-0.03, 0.03) * shake

	camera.position = Vector3(player_pos.x, player_pos.y + eye_h + bob_y, player_pos.z)
	camera.rotation = Vector3(
		player_pitch + deg_to_rad(_recoil_pitch) + shake_x,
		player_yaw + deg_to_rad(_recoil_yaw) + shake_y,
		0.0
	)

	var reload_dip: float = (sin((_reload_timer / maxf(0.1, float(spec["reload_time"]))) * PI) * 0.14) if is_reloading else 0.0
	var knife_slash: float = (sin((_knife_swing_timer / 0.22) * PI) * 0.55) if _knife_swing_timer > 0.0 else 0.0
	view_model_mount.position = Vector3(
		0.24 + cos(_walk_bob_phase * 0.5) * 0.012 * minf(1.0, h_speed / 5.0) - knife_slash * 0.25,
		-0.22 + absf(sin(_walk_bob_phase * 0.5)) * 0.012 * minf(1.0, h_speed / 5.0) - reload_dip,
		-0.35 + _view_kick_z - knife_slash * 0.2
	)
	view_model_mount.rotation = Vector3(_view_kick_rot - reload_dip * 1.4, knife_slash * 0.9, knife_slash * 0.4)

func _update_bots(dt: float, combat_mode: bool) -> void:
	var tuning: Dictionary = GameRules.get_difficulty_tuning(difficulty)
	var player_eye := Vector3(player_pos.x, player_pos.y + 1.5, player_pos.z)

	for bot in bots:
		var rig: Dictionary = bot["rig"]
		var armor_mat: StandardMaterial3D = rig["armor_mat"]
		if float(bot["hit_flash_timer"]) > 0.0:
			bot["hit_flash_timer"] = float(bot["hit_flash_timer"]) - dt
			armor_mat.emission_enabled = true
			armor_mat.emission = Color.WHITE
			armor_mat.emission_energy_multiplier = 0.7
		else:
			armor_mat.emission_enabled = false

		var body_pivot: Node3D = rig["body_pivot"]
		var laser: MeshInstance3D = bot["laser"]
		if bot["state"] == GameTypes.BotAIState.KO:
			bot["ko_timer"] = maxf(0.0, float(bot["ko_timer"]) - dt)
			body_pivot.rotation.x = lerpf(body_pivot.rotation.x, -PI * 0.48, 1.0 - exp(-12.0 * dt))
			body_pivot.position.y = lerpf(body_pivot.position.y, 0.2, 1.0 - exp(-12.0 * dt))
			rig["contact_shadow"].visible = false
			laser.visible = false
			continue

		bot["time_since_heard"] = float(bot["time_since_heard"]) + dt
		bot["fire_cooldown"] = maxf(0.0, float(bot["fire_cooldown"]) - dt)
		bot["blind_timer"] = maxf(0.0, float(bot["blind_timer"]) - dt)

		if bot["state"] == GameTypes.BotAIState.RELOAD:
			bot["reload_timer"] = float(bot["reload_timer"]) - dt
			if float(bot["reload_timer"]) <= 0.0:
				bot["ammo_in_mag"] = bot["max_mag"]

		var b_pos: Vector3 = bot["pos"]
		var bot_eye := Vector3(b_pos.x, b_pos.y + 1.62, b_pos.z)
		var dist_to_player: float = bot_eye.distance_to(player_eye)
		var can_see: bool = (
			combat_mode
			and player_hp > 0.0
			and dist_to_player < 56.0
			and _has_line_of_sight(bot_eye, player_eye)
		)
		if can_see:
			bot["last_heard_pos"] = player_pos
			bot["time_since_heard"] = 0.0

		var prev_state: GameTypes.BotAIState = bot["state"]
		var next_state: GameTypes.BotAIState = GameRules.evaluate_bot_next_state(
			float(bot["hp"]),
			float(bot["max_hp"]),
			int(bot["ammo_in_mag"]),
			float(bot["blind_timer"]),
			can_see,
			dist_to_player,
			float(bot["time_since_heard"]),
			not MapData.COVER_SPOTS.is_empty(),
			bot["archetype"],
			difficulty
		)
		bot["state"] = next_state
		if next_state == GameTypes.BotAIState.RELOAD and prev_state != GameTypes.BotAIState.RELOAD:
			bot["reload_timer"] = 2.0

		# Visor color cue
		var visor_mat: StandardMaterial3D = rig["visor_mat"]
		if next_state == GameTypes.BotAIState.BLINDED:
			visor_mat.albedo_color = Color.WHITE
			visor_mat.emission = Color("#e2e8f0")
		elif next_state == GameTypes.BotAIState.ENGAGE:
			visor_mat.albedo_color = Color("#ff3b30")
			visor_mat.emission = Color("#dc2626")
		elif next_state == GameTypes.BotAIState.TAKE_COVER or next_state == GameTypes.BotAIState.RELOAD:
			visor_mat.albedo_color = Color("#38bdf8")
			visor_mat.emission = Color("#0284c7")
		else:
			visor_mat.albedo_color = Color("#f59e0b")
			visor_mat.emission = Color("#d97706")

		var has_target: bool = false
		var move_target := Vector3.ZERO
		var move_speed: float = float(tuning["move_speed"])
		var b_vel: Vector3 = bot["vel"]
		var head_group: Node3D = rig["head_group"]
		laser.visible = false

		if next_state == GameTypes.BotAIState.BLINDED:
			b_vel.x *= 0.85
			b_vel.z *= 0.85
			head_group.rotation.y = sin(_elapsed * 9.0) * 0.45
		elif next_state == GameTypes.BotAIState.ENGAGE:
			head_group.rotation.y = 0.0
			var to_p: Vector3 = player_pos - b_pos
			var target_yaw: float = atan2(to_p.x, to_p.z)
			bot["yaw"] = lerp_angle(float(bot["yaw"]), target_yaw, 1.0 - exp(-10.0 * dt))

			bot["strafe_phase"] = float(bot["strafe_phase"]) + dt * float(tuning["strafe_frequency"])
			var byaw: float = float(bot["yaw"])
			var strafe: float = sin(float(bot["strafe_phase"]))
			b_vel.x = cos(byaw) * strafe * move_speed * 0.65
			b_vel.z = -sin(byaw) * strafe * move_speed * 0.65

			bot["reaction_timer"] = float(bot["reaction_timer"]) + dt
			if bot["archetype"] == GameTypes.BotArchetype.SNIPER and float(bot["fire_cooldown"]) < 0.45 and float(bot["reaction_timer"]) >= float(tuning["reaction_delay"]) * 0.5:
				laser.visible = true
				var mp: Node3D = rig["muzzle_point"]
				_orient_beam(laser, mp.global_position, player_eye)

			if float(bot["reaction_timer"]) >= float(tuning["reaction_delay"]) and float(bot["fire_cooldown"]) <= 0.0:
				_fire_bot_weapon(bot, float(tuning["aim_error_rad"]), float(tuning["headshot_chance"]))
		elif next_state == GameTypes.BotAIState.TAKE_COVER or next_state == GameTypes.BotAIState.RELOAD:
			var best_spot: Vector3 = MapData.COVER_SPOTS[0]
			var best_score: float = -1e9
			for c in MapData.COVER_SPOTS:
				var d_bot: float = Vector2(c.x - b_pos.x, c.z - b_pos.z).length()
				var blocked: bool = not _has_line_of_sight(Vector3(c.x, c.y + 1.4, c.z), player_eye)
				var score: float = (30.0 if blocked else 0.0) - d_bot
				if score > best_score:
					best_score = score
					best_spot = c
			move_target = best_spot
			has_target = true
			move_speed *= 1.1
		elif next_state == GameTypes.BotAIState.INVESTIGATE or next_state == GameTypes.BotAIState.FLANK:
			bot["reaction_timer"] = 0.0
			move_target = bot["last_heard_pos"]
			if next_state == GameTypes.BotAIState.FLANK and bot["archetype"] == GameTypes.BotArchetype.ENTRY:
				move_target.x += 7.0 if b_pos.x > 0.0 else -7.0
			has_target = true
		else:
			bot["reaction_timer"] = 0.0
			var route: Array = bot["patrol_route"]
			var p_idx: int = int(bot["patrol_idx"])
			var wp: Vector3 = route[p_idx]
			if Vector2(wp.x - b_pos.x, wp.z - b_pos.z).length() < 1.6:
				p_idx = (p_idx + 1) % route.size()
				bot["patrol_idx"] = p_idx
			move_target = route[p_idx]
			has_target = true
			move_speed *= 0.78

		if has_target:
			var dx: float = move_target.x - b_pos.x
			var dz: float = move_target.z - b_pos.z
			var dist: float = Vector2(dx, dz).length()
			if dist > 0.4:
				var dir_x: float = dx / dist
				var dir_z: float = dz / dist
				var probe := Vector3(b_pos.x + dir_x * 1.3, b_pos.y + 0.9, b_pos.z + dir_z * 1.3)
				var start_probe := Vector3(b_pos.x, b_pos.y + 0.9, b_pos.z)
				for box in _colliders:
					if GameRules.intersect_segment_aabb(start_probe, probe, box) >= 0.0:
						var side: float = 1.0 if float(bot["strafe_phase"]) >= 0.0 else -1.0
						var rx: float = -dir_z * side
						var rz: float = dir_x * side
						dir_x = dir_x * 0.35 + rx * 0.85
						dir_z = dir_z * 0.35 + rz * 0.85
						var n: float = maxf(0.001, Vector2(dir_x, dir_z).length())
						dir_x /= n
						dir_z /= n
						break
				b_vel.x = lerpf(b_vel.x, dir_x * move_speed, 1.0 - exp(-8.0 * dt))
				b_vel.z = lerpf(b_vel.z, dir_z * move_speed, 1.0 - exp(-8.0 * dt))
				bot["yaw"] = lerp_angle(float(bot["yaw"]), atan2(dir_x, dir_z), 1.0 - exp(-8.0 * dt))
			else:
				b_vel.x *= 0.8
				b_vel.z *= 0.8

		b_vel.y -= 17.5 * dt
		var next_b := GameRules.resolve_horizontal_collision(
			Vector3(b_pos.x + b_vel.x * dt, b_pos.y, b_pos.z + b_vel.z * dt),
			0.45,
			1.8,
			_colliders
		)
		b_pos.x = next_b.x
		b_pos.z = next_b.z
		b_pos.y += b_vel.y * dt
		var floor_y: float = GameRules.get_support_floor_y(b_pos.x, b_pos.z, b_pos.y, 0.45, _colliders)
		if b_pos.y <= floor_y:
			b_pos.y = floor_y
			b_vel.y = 0.0

		bot["pos"] = b_pos
		bot["vel"] = b_vel

		var root_node: Node3D = rig["root"]
		root_node.position = b_pos
		root_node.rotation.y = float(bot["yaw"])
		var speed: float = Vector2(b_vel.x, b_vel.z).length()
		bot["walk_dist"] = float(bot["walk_dist"]) + speed * dt * 3.2
		var swing: float = sin(float(bot["walk_dist"])) * minf(0.6, speed * 0.14)
		rig["leg_l"].rotation.x = swing
		rig["leg_r"].rotation.x = -swing

func _fire_bot_weapon(bot: Dictionary, aim_error_rad: float, headshot_chance: float) -> void:
	var wid: String = String(bot["weapon_id"])
	var spec: Dictionary = GameTypes.WEAPONS[wid]
	bot["ammo_in_mag"] = maxi(0, int(bot["ammo_in_mag"]) - 1)
	bot["fire_cooldown"] = 1.55 if bot["archetype"] == GameTypes.BotArchetype.SNIPER else (60.0 / float(spec["fire_rate_rpm"]) + randf() * 0.08)

	var mp: Node3D = bot["rig"]["muzzle_point"]
	var muzzle_pos: Vector3 = mp.global_position
	var dist: float = muzzle_pos.distance_to(player_pos)
	var atten: float = maxf(0.15, 1.0 - dist / 45.0)
	if _audio() != null:
		_audio().play_gunshot(wid, atten * 0.65)

	var target_center := Vector3(player_pos.x, player_pos.y + 1.4, player_pos.z)
	var dir: Vector3 = (target_center - muzzle_pos).normalized()
	dir += Vector3(
		randf_range(-aim_error_rad, aim_error_rad),
		randf_range(-aim_error_rad, aim_error_rad),
		randf_range(-aim_error_rad, aim_error_rad)
	)
	dir = dir.normalized()

	var end_pt: Vector3 = muzzle_pos + dir * 50.0
	var player_eye := Vector3(player_pos.x, player_pos.y + 1.35, player_pos.z)
	var to_player: Vector3 = player_eye - muzzle_pos
	var proj: float = to_player.dot(dir)

	var hit_player: bool = false
	if proj > 0.0 and proj < 55.0:
		var closest: Vector3 = muzzle_pos + dir * proj
		if closest.distance_to(player_eye) < 0.48 and _has_line_of_sight(muzzle_pos, closest):
			hit_player = true
			end_pt = closest
			var is_head: bool = randf() < headshot_chance
			var base_dmg: float = 48.0 if bot["archetype"] == GameTypes.BotArchetype.SNIPER else 16.0
			_apply_player_damage(int(round(base_dmg * 1.65)) if is_head else int(base_dmg))

	if not hit_player:
		for box in _colliders:
			var t: float = GameRules.intersect_segment_aabb(muzzle_pos, end_pt, box)
			if t >= 0.0:
				end_pt = muzzle_pos.lerp(end_pt, t)
				break

	_spawn_tracer(muzzle_pos, end_pt)

func _update_grenades(dt: float) -> void:
	var kept: Array[Dictionary] = []
	for g in _grenades:
		if not bool(g["active"]):
			continue
		g["fuse"] = float(g["fuse"]) - dt
		var g_vel: Vector3 = g["vel"]
		var g_pos: Vector3 = g["pos"]
		g_vel.y -= 16.5 * dt

		var next_x: float = g_pos.x + g_vel.x * dt
		var next_z: float = g_pos.z + g_vel.z * dt
		var hit_wall: Vector3 = GameRules.resolve_horizontal_collision(Vector3(next_x, g_pos.y, next_z), 0.12, 0.24, _colliders)
		if absf(hit_wall.x - next_x) > 0.001:
			g_vel.x *= -0.52
			if _audio() != null:
				_audio().play_grenade_bounce()
		if absf(hit_wall.z - next_z) > 0.001:
			g_vel.z *= -0.52
			if _audio() != null:
				_audio().play_grenade_bounce()
		g_pos.x = hit_wall.x
		g_pos.z = hit_wall.z

		g_pos.y += g_vel.y * dt
		var floor_y: float = GameRules.get_support_floor_y(g_pos.x, g_pos.z, g_pos.y, 0.12, _colliders, 0.1) + 0.08
		if g_pos.y <= floor_y:
			g_pos.y = floor_y
			if absf(g_vel.y) > 1.2:
				g_vel.y = -g_vel.y * 0.45
				g_vel.x *= 0.72
				g_vel.z *= 0.72
				if _audio() != null:
					_audio().play_grenade_bounce()
			else:
				g_vel.y = 0.0
				g_vel.x *= 0.85
				g_vel.z *= 0.85

		g["pos"] = g_pos
		g["vel"] = g_vel
		var mesh: Node3D = g["mesh"]
		mesh.position = g_pos
		mesh.rotation.x += dt * 7.0
		mesh.rotation.z += dt * 5.0

		if float(g["fuse"]) <= 0.0:
			_detonate_grenade(g)
		else:
			kept.append(g)
	_grenades = kept

func _update_effects(dt: float) -> void:
	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer -= dt
		if _muzzle_flash_timer <= 0.0:
			_muzzle_flash_mesh.visible = false

	for t in _tracer_pool:
		var life: float = float(t["life"])
		if life > 0.0:
			life -= dt
			t["life"] = life
			var mat: StandardMaterial3D = t["mat"]
			mat.albedo_color.a = maxf(0.0, life / float(t["max_life"]))
			if life <= 0.0:
				t["mesh"].visible = false

	var mm: MultiMesh = _particle_mmi.multimesh
	for i in range(_particles.size()):
		var p: Dictionary = _particles[i]
		if not bool(p["active"]):
			continue
		var life: float = float(p["life"]) - dt
		p["life"] = life
		if life <= 0.0:
			p["active"] = false
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -50, 0)))
			continue
		var vel: Vector3 = p["vel"]
		vel.y -= 11.0 * dt
		var pos: Vector3 = p["pos"] + vel * dt
		p["vel"] = vel
		p["pos"] = pos
		var s: float = float(p["scale"]) * (life / float(p["max_life"]))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), pos))

	_camera_trauma = maxf(0.0, _camera_trauma - dt * 1.8)
	_flash_alpha = maxf(0.0, _flash_alpha - dt * 0.55)
	_damage_flash_alpha = maxf(0.0, _damage_flash_alpha - dt * 1.9)
	if _hitmarker_timer > 0.0:
		_hitmarker_timer -= dt
		if _hitmarker_timer <= 0.0:
			_hitmarker_type = "none"
	if _round_banner_timer > 0.0:
		_round_banner_timer -= dt
		if _round_banner_timer <= 0.0:
			_round_banner = ""
			_round_banner_key = ""
			_round_banner_arg = 0

func get_hud_snapshot() -> Dictionary:
	var active_inst = slots.get(active_slot, null)
	var active_id: String = String(active_inst["id"]) if active_inst != null else "karambit"
	var spec: Dictionary = GameTypes.WEAPONS[active_id]
	var h_speed: float = Vector2(player_vel.x, player_vel.z).length()
	var spread: float = GameRules.compute_dynamic_spread(
		active_id, h_speed, player_grounded, _is_player_crouching(), is_scoped, _recoil_bloom
	)

	var radar_blips: Array[Dictionary] = []
	var alive_count: int = 0
	for b in bots:
		if b["state"] != GameTypes.BotAIState.KO:
			alive_count += 1
			radar_blips.append({
				"id": b["id"],
				"x": float(b["pos"].x),
				"z": float(b["pos"].z),
				"state": b["state"],
			})

	var slot_summary: Dictionary = {
		1: {"id": slots[1]["id"], "name": GameTypes.WEAPONS[slots[1]["id"]]["short_name"]} if slots.get(1, null) != null else null,
		2: {"id": slots[2]["id"], "name": GameTypes.WEAPONS[slots[2]["id"]]["short_name"]} if slots.get(2, null) != null else null,
		3: {"id": "karambit", "name": "__KNIFE__"},
		4: {"id": "he_grenade", "name": "__HE__"} if he_count > 0 else null,
		5: {"id": "flashbang", "name": "__FLASH__"} if flash_count > 0 else null,
	}

	return {
		"phase": phase,
		"hp": int(round(player_hp)),
		"armor": int(round(player_armor)),
		"has_helmet": player_has_helmet,
		"cash": player_cash,
		"round": round_num,
		"max_rounds": MAX_ROUNDS,
		"player_score": player_score,
		"bot_score": bot_score,
		"bots_alive": alive_count,
		"total_bots": bots.size(),
		"active_slot": active_slot,
		"active_weapon_id": active_id,
		"active_weapon_name": spec["name"],
		"ammo_in_mag": int(active_inst["ammo_in_mag"]) if active_inst != null else 0,
		"reserve_ammo": int(active_inst["reserve_ammo"]) if active_inst != null else 0,
		"is_reloading": is_reloading,
		"reload_progress": (1.0 - _reload_timer / maxf(0.1, float(spec["reload_time"]))) if is_reloading else 0.0,
		"is_scoped": is_scoped,
		"crosshair_spread": spread,
		"flash_alpha": _flash_alpha,
		"damage_flash_alpha": _damage_flash_alpha,
		"hitmarker_type": _hitmarker_type,
		"he_count": he_count,
		"flash_count": flash_count,
		"slots": slot_summary,
		"kills": kills,
		"headshots": headshots,
		"shots_fired": shots_fired,
		"shots_hit": shots_hit,
		"damage_dealt": damage_dealt,
		"round_banner": _round_banner,
		"round_banner_key": _round_banner_key,
		"round_banner_arg": _round_banner_arg,
		"killfeed": killfeed,
		"radar_blips": radar_blips,
		"player_x": player_pos.x,
		"player_z": player_pos.z,
		"player_yaw": player_yaw,
		"pointer_locked": _pointer_locked,
		"is_crouching": _is_player_crouching(),
		"touch_controls_enabled": _touch_controls_enabled,
		"is_victory": player_score >= bot_score,
		"difficulty": difficulty,
		"bot_count": bot_count,
	}

func push_hud_snapshot() -> void:
	emit_signal("hud_updated", get_hud_snapshot())

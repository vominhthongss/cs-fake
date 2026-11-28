class_name TouchControls
extends Control

## Multi-touch FPS virtual joycon & vector-icon tactical action overlay for Native Mobile & Mobile Web.
## Uses strict left/right zone separation and per-finger position tracking so movement and camera aim
## never interfere with each other or with synthetic mobile browser mouse events.

signal move_changed(move_vec: Vector2)
signal look_dragged(delta_px: Vector2)
signal fire_changed(pressed: bool)
signal jump_pressed()
signal crouch_toggled(active: bool)
signal reload_pressed()
signal scope_pressed()
signal grenade_pressed(kind: String)
signal touch_input_detected()

const DEADZONE_RATIO: float = 0.12
const BASE_JOYSTICK_RADIUS: float = 108.0
const BASE_KNOB_RADIUS: float = 44.0
const MAX_LOOK_STEP_PX: float = 180.0
const MOUSE_FINGER_ID: int = -100

var _font_bold: Font
var _active: bool = false
var _excluded_controls: Array[Control] = []
var _seen_real_touch: bool = false
var _is_mobile_os: bool = false

# Dynamic HUD state synced from FpsGameController snapshot
var _can_scope: bool = false
var _is_scoped: bool = false
var _is_reloading: bool = false
var _reload_progress: float = 0.0
var _he_count: int = 0
var _flash_count: int = 0
var _crouch_active: bool = false

# Multi-touch tracking state (keyed strictly by finger_id)
var _move_finger: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_knob_offset: Vector2 = Vector2.ZERO
var _move_vector: Vector2 = Vector2.ZERO

var _look_finger: int = -1
var _fire_finger: int = -1
var _finger_last_pos: Dictionary = {} # finger_id -> Vector2
var _button_fingers: Dictionary = {} # finger_id -> button_id
var _pressed_buttons: Dictionary = {} # button_id -> bool

# Computed layout geometry (recomputed on viewport resize)
var _scale_factor: float = 1.0
var _joy_home: Vector2 = Vector2(158.0, 564.0)
var _joy_radius: float = BASE_JOYSTICK_RADIUS
var _knob_radius: float = BASE_KNOB_RADIUS
var _left_zone_max_x: float = 614.0
var _left_zone_min_y: float = 172.0
var _right_zone_min_x: float = 614.0
var _right_zone_min_y: float = 100.0
var _buttons: Dictionary = {} # id -> {"center": Vector2, "radius": float}

static func detect_touch_device() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile"):
		return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var js_res = JavaScriptBridge.eval(
			"(function(){try{return (navigator.maxTouchPoints||0)>0||('ontouchstart' in window)||(window.matchMedia&&window.matchMedia('(pointer: coarse)').matches);}catch(e){return false;}})()"
		)
		if bool(js_res):
			return true
	return false

static func compute_stick_vector(delta: Vector2, max_radius: float, deadzone: float = DEADZONE_RATIO) -> Vector2:
	if max_radius <= 0.001:
		return Vector2.ZERO
	var dist: float = delta.length()
	var norm_dist: float = clampf(dist / max_radius, 0.0, 1.0)
	if norm_dist <= deadzone:
		return Vector2.ZERO
	var scaled: float = (norm_dist - deadzone) / maxf(0.001, 1.0 - deadzone)
	var dir: Vector2 = delta / dist
	# Screen +X = strafe right (+X), Screen -Y = move forward (+Y)
	return Vector2(dir.x * scaled, -dir.y * scaled)

static func clamp_knob_offset(delta: Vector2, max_radius: float) -> Vector2:
	if max_radius <= 0.001:
		return Vector2.ZERO
	var dist: float = delta.length()
	if dist <= max_radius:
		return delta
	return (delta / dist) * max_radius

func _ready() -> void:
	_is_mobile_os = (
		OS.has_feature("android")
		or OS.has_feature("ios")
		or OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_recompute_layout)
	_recompute_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset_state()

func set_fonts(bold_font: Font) -> void:
	_font_bold = bold_font
	queue_redraw()

func set_excluded_controls(controls: Array[Control]) -> void:
	_excluded_controls = controls

func set_labels(_fire_lbl: String, _jump_lbl: String, _crouch_lbl: String, _reload_lbl: String, _scope_lbl: String, _he_lbl: String, _flash_lbl: String) -> void:
	# Buttons use language-independent vector tactical icons; keep signature for compatibility.
	queue_redraw()

func set_controls_active(active: bool) -> void:
	if _active == active:
		visible = active
		return
	_active = active
	visible = active
	if not active:
		reset_state()
	else:
		_recompute_layout()
		queue_redraw()

func reset_state() -> void:
	var had_move: bool = _move_vector != Vector2.ZERO
	var had_fire: bool = (_fire_finger != -1) or bool(_pressed_buttons.get("fire", false))
	var had_crouch: bool = _crouch_active
	_move_finger = -1
	_move_origin = _joy_home
	_move_knob_offset = Vector2.ZERO
	_move_vector = Vector2.ZERO
	_look_finger = -1
	_fire_finger = -1
	_finger_last_pos.clear()
	_button_fingers.clear()
	_pressed_buttons.clear()
	_crouch_active = false
	if had_move:
		emit_signal("move_changed", Vector2.ZERO)
	if had_fire:
		emit_signal("fire_changed", false)
	if had_crouch:
		emit_signal("crouch_toggled", false)
	queue_redraw()

func update_hud_state(hud: Dictionary) -> void:
	var active_id: String = String(hud.get("active_weapon_id", "m4a1s"))
	var spec: Dictionary = GameTypes.WEAPONS.get(active_id, {})
	var next_can_scope: bool = bool(spec.get("can_scope", false))
	var next_scoped: bool = bool(hud.get("is_scoped", false))
	var next_reloading: bool = bool(hud.get("is_reloading", false))
	var next_reload_prog: float = float(hud.get("reload_progress", 0.0))
	var next_he: int = int(hud.get("he_count", 0))
	var next_flash: int = int(hud.get("flash_count", 0))
	var next_crouch: bool = bool(hud.get("is_crouching", _crouch_active))

	var changed: bool = (
		next_can_scope != _can_scope
		or next_scoped != _is_scoped
		or next_reloading != _is_reloading
		or absf(next_reload_prog - _reload_progress) > 0.01
		or next_he != _he_count
		or next_flash != _flash_count
		or next_crouch != _crouch_active
	)
	_can_scope = next_can_scope
	_is_scoped = next_scoped
	_is_reloading = next_reloading
	_reload_progress = next_reload_prog
	_he_count = next_he
	_flash_count = next_flash
	_crouch_active = next_crouch
	if changed and _active:
		queue_redraw()

func get_safe_insets() -> Dictionary:
	var vp_size: Vector2 = size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = get_viewport_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = Vector2(1280.0, 720.0)

	var left_in: float = 0.0
	var right_in: float = 0.0
	var top_in: float = 0.0
	var bottom_in: float = 0.0

	if DisplayServer.get_name() != "headless":
		var win_size: Vector2i = DisplayServer.window_get_size()
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		if win_size.x > 0 and win_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var sx: float = vp_size.x / float(win_size.x)
			var sy: float = vp_size.y / float(win_size.y)
			left_in = maxf(0.0, float(safe.position.x) * sx)
			top_in = maxf(0.0, float(safe.position.y) * sy)
			right_in = maxf(0.0, float(win_size.x - safe.end.x) * sx)
			bottom_in = maxf(0.0, float(win_size.y - safe.end.y) * sy)

	return {
		"left": clampf(left_in, 0.0, vp_size.x * 0.12),
		"right": clampf(right_in, 0.0, vp_size.x * 0.12),
		"top": clampf(top_in, 0.0, vp_size.y * 0.12),
		"bottom": clampf(bottom_in, 0.0, vp_size.y * 0.12),
	}

func _recompute_layout() -> void:
	var vp: Vector2 = size
	if vp.x <= 1.0 or vp.y <= 1.0:
		vp = get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		vp = Vector2(1280.0, 720.0)

	var insets: Dictionary = get_safe_insets()
	var safe_l: float = float(insets["left"])
	var safe_r: float = float(insets["right"])
	var safe_b: float = float(insets["bottom"])

	var s: float = clampf(minf(vp.x / 1280.0, vp.y / 720.0), 0.85, 1.45)
	_scale_factor = s
	_joy_radius = BASE_JOYSTICK_RADIUS * s
	_knob_radius = BASE_KNOB_RADIUS * s

	_joy_home = Vector2(safe_l + 158.0 * s, vp.y - safe_b - 156.0 * s)
	if _move_finger == -1:
		_move_origin = _joy_home

	# Strict non-overlapping split: left half exclusively for movement, right half exclusively for aim/actions.
	_left_zone_max_x = vp.x * 0.48
	_left_zone_min_y = vp.y * 0.24
	_right_zone_min_x = vp.x * 0.48
	_right_zone_min_y = 0.0

	var fire_center := Vector2(vp.x - safe_r - 134.0 * s, vp.y - safe_b - 172.0 * s)
	_buttons = {
		"fire": {"center": fire_center, "radius": 72.0 * s},
		"jump": {"center": fire_center + Vector2(36.0 * s, -148.0 * s), "radius": 46.0 * s},
		"scope": {"center": fire_center + Vector2(-84.0 * s, -138.0 * s), "radius": 44.0 * s},
		"reload": {"center": fire_center + Vector2(-150.0 * s, -40.0 * s), "radius": 44.0 * s},
		"crouch": {"center": fire_center + Vector2(-132.0 * s, 74.0 * s), "radius": 44.0 * s},
		"he": {"center": Vector2(safe_l + 68.0 * s, vp.y - safe_b - 332.0 * s), "radius": 38.0 * s},
		"flash": {"center": Vector2(safe_l + 162.0 * s, vp.y - safe_b - 332.0 * s), "radius": 38.0 * s},
	}
	queue_redraw()

func _is_button_visible(btn_id: String) -> bool:
	if btn_id == "scope":
		return _can_scope
	if btn_id == "he":
		return _he_count > 0
	if btn_id == "flash":
		return _flash_count > 0
	return true

func _hit_test_button(pos: Vector2) -> String:
	var best_id: String = ""
	var best_dist: float = 1e9
	for btn_id in _buttons.keys():
		if not _is_button_visible(btn_id):
			continue
		var b: Dictionary = _buttons[btn_id]
		var hit_r: float = float(b["radius"]) * 1.10
		var d: float = pos.distance_to(b["center"])
		if d <= hit_r and d < best_dist:
			best_dist = d
			best_id = btn_id
	return best_id

func _is_over_excluded_hud(pos: Vector2) -> bool:
	for ctrl in _excluded_controls:
		if ctrl != null and is_instance_valid(ctrl) and ctrl.is_visible_in_tree():
			if ctrl.get_global_rect().grow(6.0).has_point(pos):
				return true
	return false

func _to_local_pos(event_pos: Vector2) -> Vector2:
	if is_inside_tree():
		return get_global_transform().affine_inverse() * event_pos
	return event_pos

func _clamp_joystick_origin(pos: Vector2) -> Vector2:
	var vp: Vector2 = size if size.x > 1.0 else Vector2(1280.0, 720.0)
	var insets: Dictionary = get_safe_insets()
	var margin: float = _joy_radius + 14.0 * _scale_factor
	return Vector2(
		clampf(pos.x, float(insets["left"]) + margin, _left_zone_max_x - _joy_radius * 0.55),
		clampf(pos.y, _left_zone_min_y + _joy_radius * 0.45, vp.y - float(insets["bottom"]) - margin)
	)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_seen_real_touch = true
		if event.pressed:
			emit_signal("touch_input_detected")
		if not _active or not is_visible_in_tree():
			return
		var is_pressed: bool = event.pressed and not event.canceled
		var handled: bool = _handle_pointer_touch(event.index, _to_local_pos(event.position), is_pressed, false)
		if handled:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		_seen_real_touch = true
		if not _active or not is_visible_in_tree():
			return
		var handled: bool = _handle_pointer_drag(event.index, _to_local_pos(event.position))
		if handled:
			get_viewport().set_input_as_handled()
		return

	if not _active or not is_visible_in_tree():
		return

	# Never accept synthetic/browser compatibility mouse events on mobile or once real touch is seen.
	if _seen_real_touch or _is_mobile_os:
		return

	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or (event.button_index == MOUSE_BUTTON_RIGHT and event.ctrl_pressed)):
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var handled: bool = _handle_pointer_touch(MOUSE_FINGER_ID, _to_local_pos(event.position), event.pressed, true)
		if handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _move_finger == MOUSE_FINGER_ID or _fire_finger == MOUSE_FINGER_ID or _look_finger == MOUSE_FINGER_ID:
			if _handle_pointer_drag(MOUSE_FINGER_ID, _to_local_pos(event.position)):
				get_viewport().set_input_as_handled()

func _release_finger(finger_id: int) -> bool:
	var consumed: bool = false
	if _finger_last_pos.has(finger_id):
		_finger_last_pos.erase(finger_id)
	if finger_id == _move_finger:
		_move_finger = -1
		_move_origin = _joy_home
		_move_knob_offset = Vector2.ZERO
		_move_vector = Vector2.ZERO
		emit_signal("move_changed", Vector2.ZERO)
		consumed = true
	if finger_id == _fire_finger:
		_fire_finger = -1
		emit_signal("fire_changed", false)
		consumed = true
	if finger_id == _look_finger:
		_look_finger = -1
		consumed = true
	if _button_fingers.has(finger_id):
		var bid: String = String(_button_fingers[finger_id])
		_button_fingers.erase(finger_id)
		_pressed_buttons[bid] = false
		consumed = true
	return consumed

func _handle_pointer_touch(finger_id: int, pos: Vector2, pressed: bool, widgets_only: bool) -> bool:
	if pressed:
		# Clear any stale state if the browser/OS reused a finger index without delivering an end event.
		if finger_id == _move_finger or finger_id == _look_finger or finger_id == _fire_finger or _button_fingers.has(finger_id):
			_release_finger(finger_id)

		if _is_over_excluded_hud(pos):
			return false

		_finger_last_pos[finger_id] = pos

		var btn_id: String = _hit_test_button(pos)
		if not btn_id.is_empty():
			_button_fingers[finger_id] = btn_id
			_pressed_buttons[btn_id] = true
			if btn_id == "fire":
				_fire_finger = finger_id
				emit_signal("fire_changed", true)
			elif btn_id == "jump":
				emit_signal("jump_pressed")
			elif btn_id == "crouch":
				_crouch_active = not _crouch_active
				emit_signal("crouch_toggled", _crouch_active)
			elif btn_id == "reload":
				emit_signal("reload_pressed")
			elif btn_id == "scope":
				emit_signal("scope_pressed")
			elif btn_id == "he":
				emit_signal("grenade_pressed", "he_grenade")
			elif btn_id == "flash":
				emit_signal("grenade_pressed", "flashbang")
			queue_redraw()
			return true

		# Left zone: strictly reserved for Movement Joystick (never falls through to look pad).
		var in_left_zone: bool = (
			pos.distance_to(_joy_home) <= _joy_radius * 1.18
			if widgets_only
			else (pos.x < _left_zone_max_x and pos.y >= _left_zone_min_y)
		)
		if in_left_zone:
			if _move_finger == -1:
				_move_finger = finger_id
				_move_origin = _joy_home if widgets_only else _clamp_joystick_origin(pos)
				_update_joystick(pos)
				queue_redraw()
				return true
			_finger_last_pos.erase(finger_id)
			return true

		# Right zone: strictly reserved for Camera Look drag pad (real touch only).
		if not widgets_only and pos.x >= _right_zone_min_x and pos.y >= _right_zone_min_y:
			if _look_finger == -1:
				_look_finger = finger_id
				return true
			_finger_last_pos.erase(finger_id)
			return true

		_finger_last_pos.erase(finger_id)
		return false
	else:
		var consumed: bool = _release_finger(finger_id)
		if consumed:
			queue_redraw()
		return consumed

func _handle_pointer_drag(finger_id: int, pos: Vector2) -> bool:
	if finger_id == _move_finger:
		_finger_last_pos[finger_id] = pos
		_update_joystick(pos)
		queue_redraw()
		return true

	# Allow smooth camera look from dedicated look finger, or from fire finger when no separate look finger is active.
	var drives_look: bool = (finger_id == _look_finger) or (finger_id == _fire_finger and _look_finger == -1)
	if drives_look:
		var prev_pos: Vector2 = _finger_last_pos.get(finger_id, pos)
		var delta: Vector2 = pos - prev_pos
		_finger_last_pos[finger_id] = pos
		if delta.length() > MAX_LOOK_STEP_PX * _scale_factor:
			# Discard anomalous touch-index teleport spikes reported by mobile browsers.
			return true
		if delta.length_squared() > 0.01:
			var vp_h: float = size.y if size.y > 1.0 else 720.0
			var norm_delta: Vector2 = delta * (720.0 / vp_h)
			emit_signal("look_dragged", norm_delta)
		return true

	if _button_fingers.has(finger_id):
		_finger_last_pos[finger_id] = pos
		return true

	return false

func _update_joystick(pos: Vector2) -> void:
	var delta: Vector2 = pos - _move_origin
	_move_knob_offset = clamp_knob_offset(delta, _joy_radius)
	var next_vec: Vector2 = compute_stick_vector(delta, _joy_radius, DEADZONE_RATIO)
	if next_vec.distance_squared_to(_move_vector) > 0.0001:
		_move_vector = next_vec
		emit_signal("move_changed", _move_vector)

func _draw() -> void:
	if not _active:
		return

	var s: float = _scale_factor
	# 1. Left Analog Joystick
	var joy_center: Vector2 = _move_origin if _move_finger != -1 else _joy_home
	var ring_alpha: float = 0.78 if _move_finger != -1 else 0.48
	draw_circle(joy_center, _joy_radius, Color(0.06, 0.055, 0.048, 0.44 if _move_finger != -1 else 0.28))
	draw_arc(joy_center, _joy_radius, 0.0, TAU, 56, Color(0.96, 0.62, 0.04, ring_alpha), 2.8 * s, true)
	draw_arc(joy_center, _joy_radius * 0.48, 0.0, TAU, 36, Color(0.96, 0.62, 0.04, 0.20), 1.4 * s, true)

	# 4-way subtle directional chevrons inside joystick ring
	var chev_dist: float = _joy_radius - 17.0 * s
	var chev_size: float = 7.0 * s
	var chev_col := Color(0.98, 0.75, 0.14, 0.50)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var fwd := Vector2(cos(angle), sin(angle))
		var perp := Vector2(-fwd.y, fwd.x)
		var tip: Vector2 = joy_center + fwd * (chev_dist + chev_size * 0.55)
		var base: Vector2 = joy_center + fwd * (chev_dist - chev_size * 0.45)
		draw_polyline(
			PackedVector2Array([base - perp * chev_size, tip, base + perp * chev_size]),
			chev_col,
			2.2 * s,
			true
		)

	# Thumb knob
	var knob_pos: Vector2 = joy_center + _move_knob_offset
	var knob_col: Color = Color(0.96, 0.62, 0.04, 0.90) if _move_finger != -1 else Color(0.85, 0.47, 0.02, 0.62)
	draw_circle(knob_pos, _knob_radius, knob_col)
	draw_arc(knob_pos, _knob_radius, 0.0, TAU, 36, Color(0.99, 0.90, 0.54, 0.92), 2.4 * s, true)
	draw_arc(knob_pos, _knob_radius * 0.56, 0.0, TAU, 28, Color(1.0, 0.96, 0.85, 0.35), 1.4 * s, true)

	# 2. Vector-Icon Tactical Action Buttons (no text words)
	_draw_action_button("fire", Color(0.84, 0.24, 0.10, 0.58), Color(0.98, 0.65, 0.14, 0.94), true, -1)
	_draw_action_button("jump", Color(0.08, 0.075, 0.065, 0.58), Color(0.85, 0.60, 0.20, 0.78), false, -1)
	_draw_action_button(
		"crouch",
		Color(0.85, 0.47, 0.02, 0.72) if _crouch_active else Color(0.08, 0.075, 0.065, 0.58),
		Color(0.99, 0.85, 0.35, 0.96) if _crouch_active else Color(0.85, 0.60, 0.20, 0.78),
		_crouch_active,
		-1
	)
	_draw_action_button("reload", Color(0.08, 0.075, 0.065, 0.58), Color(0.85, 0.60, 0.20, 0.78), false, -1)
	if _is_reloading and _buttons.has("reload"):
		var rb: Dictionary = _buttons["reload"]
		draw_arc(
			rb["center"],
			float(rb["radius"]) + 5.0 * s,
			-PI * 0.5,
			-PI * 0.5 + TAU * clampf(_reload_progress, 0.0, 1.0),
			36,
			Color("#38bdf8"),
			3.6 * s,
			true
		)

	if _can_scope:
		_draw_action_button(
			"scope",
			Color(0.06, 0.36, 0.46, 0.76) if _is_scoped else Color(0.08, 0.075, 0.065, 0.58),
			Color("#38bdf8") if _is_scoped else Color(0.49, 0.83, 0.99, 0.84),
			_is_scoped,
			-1
		)

	if _he_count > 0:
		_draw_action_button("he", Color(0.32, 0.14, 0.06, 0.64), Color("#f59e0b"), false, _he_count)
	if _flash_count > 0:
		_draw_action_button("flash", Color(0.06, 0.20, 0.30, 0.64), Color("#38bdf8"), false, _flash_count)

func _draw_action_button(btn_id: String, fill_col: Color, border_col: Color, emphasized: bool, badge_count: int) -> void:
	if not _buttons.has(btn_id):
		return
	var b: Dictionary = _buttons[btn_id]
	var center: Vector2 = b["center"]
	var r: float = float(b["radius"])
	var is_down: bool = bool(_pressed_buttons.get(btn_id, false))
	var draw_fill: Color = fill_col.lightened(0.22) if is_down else fill_col
	if is_down:
		draw_fill.a = minf(0.92, draw_fill.a + 0.24)
	var draw_border: Color = border_col.lightened(0.18) if is_down else border_col

	draw_circle(center, r, draw_fill)
	draw_arc(center, r, 0.0, TAU, 44, draw_border, (3.4 if (emphasized or is_down) else 2.4) * _scale_factor, true)

	var icon_col := Color("#faf5eb")
	_draw_button_icon(btn_id, center, r, icon_col, draw_border)

	if badge_count > 0:
		var badge_r: float = 12.0 * _scale_factor
		var badge_pos := center + Vector2(r * 0.68, r * 0.64)
		draw_circle(badge_pos, badge_r, Color(0.07, 0.06, 0.05, 0.94))
		draw_arc(badge_pos, badge_r, 0.0, TAU, 24, draw_border, 1.8 * _scale_factor, true)
		var font: Font = _font_bold if _font_bold != null else ThemeDB.fallback_font
		if font != null:
			var fsize: int = maxi(10, int(round(13.0 * _scale_factor)))
			var btxt: String = str(badge_count)
			var tsize: Vector2 = font.get_string_size(btxt, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
			draw_string(font, Vector2(badge_pos.x - tsize.x * 0.5, badge_pos.y + tsize.y * 0.28), btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, icon_col)

func _draw_button_icon(btn_id: String, c: Vector2, r: float, col: Color, accent: Color) -> void:
	var lw: float = maxf(2.0, 2.8 * _scale_factor)
	match btn_id:
		"fire":
			# Inner reticle ring + 4 tactical notches + stylized diagonal bullet silhouette
			draw_arc(c, r * 0.72, 0.0, TAU, 36, Color(1.0, 0.92, 0.75, 0.34), 1.6 * _scale_factor, true)
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				var dir := Vector2(cos(angle), sin(angle))
				draw_line(c + dir * (r * 0.58), c + dir * (r * 0.80), Color(1.0, 0.92, 0.75, 0.68), 2.2 * _scale_factor, true)
			# Angled bullet (top-right nose, bottom-left casing)
			var u := Vector2(0.7071, -0.7071)
			var v := Vector2(0.7071, 0.7071)
			var tip: Vector2 = c + u * (r * 0.44)
			var sh_l: Vector2 = c + u * (r * 0.14) - v * (r * 0.16)
			var sh_r: Vector2 = c + u * (r * 0.14) + v * (r * 0.16)
			var mid_l: Vector2 = c - u * (r * 0.24) - v * (r * 0.16)
			var mid_r: Vector2 = c - u * (r * 0.24) + v * (r * 0.16)
			var rim_l: Vector2 = c - u * (r * 0.36) - v * (r * 0.18)
			var rim_r: Vector2 = c - u * (r * 0.36) + v * (r * 0.18)
			draw_colored_polygon(PackedVector2Array([tip, sh_r, mid_r, mid_l, sh_l]), col)
			draw_line(c + u * (r * 0.10) - v * (r * 0.15), c + u * (r * 0.10) + v * (r * 0.15), Color(0.84, 0.24, 0.10, 0.85), 2.2 * _scale_factor, true)
			draw_line(rim_l, rim_r, col, 3.6 * _scale_factor, true)
		"jump":
			# Upward double chevron + ground bar
			var w: float = r * 0.36
			var base_y: float = c.y + r * 0.34
			draw_line(Vector2(c.x - w, base_y), Vector2(c.x + w, base_y), accent, lw * 1.15, true)
			var top1 := Vector2(c.x, c.y - r * 0.36)
			draw_polyline(
				PackedVector2Array([Vector2(c.x - w * 0.88, c.y - r * 0.04), top1, Vector2(c.x + w * 0.88, c.y - r * 0.04)]),
				col,
				lw * 1.25,
				true
			)
			var top2 := Vector2(c.x, c.y - r * 0.08)
			draw_polyline(
				PackedVector2Array([Vector2(c.x - w * 0.70, c.y + r * 0.18), top2, Vector2(c.x + w * 0.70, c.y + r * 0.18)]),
				col.darkened(0.08),
				lw,
				true
			)
		"crouch":
			# Downward double chevron pointing toward ground bar
			var w: float = r * 0.36
			var base_y: float = c.y + r * 0.36
			draw_line(Vector2(c.x - w, base_y), Vector2(c.x + w, base_y), accent, lw * 1.2, true)
			var tip1 := Vector2(c.x, c.y + r * 0.18)
			draw_polyline(
				PackedVector2Array([Vector2(c.x - w * 0.88, c.y - r * 0.12), tip1, Vector2(c.x + w * 0.88, c.y - r * 0.12)]),
				col,
				lw * 1.25,
				true
			)
			var tip2 := Vector2(c.x, c.y - r * 0.10)
			draw_polyline(
				PackedVector2Array([Vector2(c.x - w * 0.70, c.y - r * 0.36), tip2, Vector2(c.x + w * 0.70, c.y - r * 0.36)]),
				col.darkened(0.08),
				lw,
				true
			)
		"reload":
			# Dual circular reload arrows
			var ar: float = r * 0.42
			var head: float = r * 0.18
			draw_arc(c, ar, -PI * 0.82, -PI * 0.10, 20, col, lw * 1.1, true)
			draw_arc(c, ar, PI * 0.18, PI * 0.90, 20, col, lw * 1.1, true)
			var tip_a: Vector2 = c + Vector2(cos(-PI * 0.10), sin(-PI * 0.10)) * ar
			draw_colored_polygon(PackedVector2Array([
				tip_a + Vector2(head * 0.15, head * 0.55),
				tip_a + Vector2(head * 0.55, -head * 0.65),
				tip_a + Vector2(-head * 0.70, -head * 0.25),
			]), col)
			var tip_b: Vector2 = c + Vector2(cos(PI * 0.90), sin(PI * 0.90)) * ar
			draw_colored_polygon(PackedVector2Array([
				tip_b + Vector2(-head * 0.15, -head * 0.55),
				tip_b + Vector2(-head * 0.55, head * 0.65),
				tip_b + Vector2(head * 0.70, head * 0.25),
			]), col)
		"scope":
			# Precision sniper optic reticle
			var sr: float = r * 0.44
			draw_arc(c, sr, 0.0, TAU, 32, col, lw, true)
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				var dir := Vector2(cos(angle), sin(angle))
				draw_line(c + dir * (sr * 0.42), c + dir * (sr * 1.28), col, lw * 0.9, true)
			draw_circle(c, maxf(2.4, 3.0 * _scale_factor), accent)
		"he":
			# Stylized frag grenade (body + collar + safety ring)
			var gr: float = r * 0.34
			var body_c := c + Vector2(0.0, r * 0.10)
			draw_circle(body_c, gr, col)
			draw_line(body_c + Vector2(-gr * 0.85, 0.0), body_c + Vector2(gr * 0.85, 0.0), Color(0.24, 0.10, 0.04, 0.9), lw * 0.85, true)
			draw_line(body_c + Vector2(0.0, -gr * 0.85), body_c + Vector2(0.0, gr * 0.85), Color(0.24, 0.10, 0.04, 0.9), lw * 0.85, true)
			var neck := Rect2(c.x - gr * 0.36, body_c.y - gr - r * 0.14, gr * 0.72, r * 0.18)
			draw_rect(neck, col, true)
			# Pin pull ring on top-right
			draw_arc(Vector2(c.x + gr * 0.66, body_c.y - gr - r * 0.08), r * 0.13, 0.0, TAU, 16, accent, lw * 0.85, true)
		"flash":
			# Crisp 8-ray flashbang starburst icon
			var inner_r: float = r * 0.16
			for i in range(8):
				var ang: float = float(i) * (TAU / 8.0)
				var outer_r: float = r * (0.50 if (i % 2 == 0) else 0.33)
				var dir := Vector2(cos(ang), sin(ang))
				draw_line(c + dir * inner_r, c + dir * outer_r, col, lw * (1.1 if (i % 2 == 0) else 0.85), true)
			draw_circle(c, inner_r * 0.85, col)
			draw_arc(c, inner_r * 1.15, 0.0, TAU, 20, accent, 1.6 * _scale_factor, true)

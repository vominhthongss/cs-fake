class_name TouchControls
extends Control

## Multi-touch FPS virtual joycon & tactical action overlay for Native Mobile & Mobile Web.
## Tracks independent finger indices so movement, camera look, firing, and actions work simultaneously.

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
const BASE_JOYSTICK_RADIUS: float = 74.0
const BASE_KNOB_RADIUS: float = 30.0
const MOUSE_FINGER_ID: int = -100

var _font_bold: Font
var _active: bool = false
var _excluded_controls: Array[Control] = []

# Dynamic HUD state synced from FpsGameController snapshot
var _can_scope: bool = false
var _is_scoped: bool = false
var _is_reloading: bool = false
var _reload_progress: float = 0.0
var _he_count: int = 0
var _flash_count: int = 0
var _crouch_active: bool = false

# Localized short labels
var _lbl_fire: String = "FIRE"
var _lbl_jump: String = "JUMP"
var _lbl_crouch: String = "CROUCH"
var _lbl_reload: String = "RELOAD"
var _lbl_scope: String = "SCOPE"
var _lbl_he: String = "HE"
var _lbl_flash: String = "FLASH"

# Multi-touch tracking state
var _move_finger: int = -1
var _move_origin: Vector2 = Vector2.ZERO
var _move_knob_offset: Vector2 = Vector2.ZERO
var _move_vector: Vector2 = Vector2.ZERO

var _look_finger: int = -1
var _fire_finger: int = -1
var _button_fingers: Dictionary = {} # finger_id -> button_id
var _pressed_buttons: Dictionary = {} # button_id -> bool

# Computed layout geometry (recomputed on viewport resize)
var _scale_factor: float = 1.0
var _joy_home: Vector2 = Vector2(132.0, 580.0)
var _joy_radius: float = BASE_JOYSTICK_RADIUS
var _knob_radius: float = BASE_KNOB_RADIUS
var _left_zone_max_x: float = 560.0
var _left_zone_min_y: float = 190.0
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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_recompute_layout)
	_recompute_layout()

func set_fonts(bold_font: Font) -> void:
	_font_bold = bold_font
	queue_redraw()

func set_excluded_controls(controls: Array[Control]) -> void:
	_excluded_controls = controls

func set_labels(fire_lbl: String, jump_lbl: String, crouch_lbl: String, reload_lbl: String, scope_lbl: String, he_lbl: String, flash_lbl: String) -> void:
	_lbl_fire = fire_lbl
	_lbl_jump = jump_lbl
	_lbl_crouch = crouch_lbl
	_lbl_reload = reload_lbl
	_lbl_scope = scope_lbl
	_lbl_he = he_lbl
	_lbl_flash = flash_lbl
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
	_move_knob_offset = Vector2.ZERO
	_move_vector = Vector2.ZERO
	_look_finger = -1
	_fire_finger = -1
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

	var s: float = clampf(minf(vp.x / 1280.0, vp.y / 720.0), 0.72, 1.35)
	_scale_factor = s
	_joy_radius = BASE_JOYSTICK_RADIUS * s
	_knob_radius = BASE_KNOB_RADIUS * s

	_joy_home = Vector2(safe_l + 132.0 * s, vp.y - safe_b - 140.0 * s)
	if _move_finger == -1:
		_move_origin = _joy_home

	_left_zone_max_x = vp.x * 0.44
	_left_zone_min_y = vp.y * 0.28

	var fire_center := Vector2(vp.x - safe_r - 126.0 * s, vp.y - safe_b - 150.0 * s)
	_buttons = {
		"fire": {"center": fire_center, "radius": 54.0 * s},
		"jump": {"center": fire_center + Vector2(46.0 * s, -112.0 * s), "radius": 32.0 * s},
		"scope": {"center": fire_center + Vector2(-52.0 * s, -108.0 * s), "radius": 31.0 * s},
		"reload": {"center": fire_center + Vector2(-114.0 * s, -34.0 * s), "radius": 30.0 * s},
		"crouch": {"center": fire_center + Vector2(-102.0 * s, 54.0 * s), "radius": 30.0 * s},
		"he": {"center": Vector2(safe_l + 68.0 * s, vp.y - safe_b - 274.0 * s), "radius": 27.0 * s},
		"flash": {"center": Vector2(safe_l + 136.0 * s, vp.y - safe_b - 274.0 * s), "radius": 27.0 * s},
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
		var hit_r: float = float(b["radius"]) * 1.18
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

func _clamp_joystick_origin(pos: Vector2) -> Vector2:
	var vp: Vector2 = size if size.x > 1.0 else Vector2(1280.0, 720.0)
	var insets: Dictionary = get_safe_insets()
	var margin: float = _joy_radius + 14.0 * _scale_factor
	return Vector2(
		clampf(pos.x, float(insets["left"]) + margin, _left_zone_max_x - _joy_radius * 0.5),
		clampf(pos.y, _left_zone_min_y + _joy_radius * 0.4, vp.y - float(insets["bottom"]) - margin)
	)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		emit_signal("touch_input_detected")

	if not _active or not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		var handled: bool = _handle_pointer_touch(event.index, event.position, event.pressed, false)
		if handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var handled: bool = _handle_pointer_drag(event.index, event.position, event.relative)
		if handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or (event.button_index == MOUSE_BUTTON_RIGHT and event.ctrl_pressed)):
		# Ignore emulated mouse events synthesized from touch to prevent double input on mobile/web.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var handled: bool = _handle_pointer_touch(MOUSE_FINGER_ID, event.position, event.pressed, true)
		if handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _move_finger == MOUSE_FINGER_ID or _fire_finger == MOUSE_FINGER_ID or _look_finger == MOUSE_FINGER_ID:
			if _handle_pointer_drag(MOUSE_FINGER_ID, event.position, event.relative):
				get_viewport().set_input_as_handled()

func _handle_pointer_touch(finger_id: int, pos: Vector2, pressed: bool, widgets_only: bool) -> bool:
	if pressed:
		if _is_over_excluded_hud(pos):
			return false

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

		# Joystick press (desktop preview mode requires pressing inside the joystick ring)
		var in_left_zone: bool = (
			pos.distance_to(_joy_home) <= _joy_radius * 1.25
			if widgets_only
			else (pos.x < _left_zone_max_x and pos.y >= _left_zone_min_y)
		)
		if in_left_zone and _move_finger == -1:
			_move_finger = finger_id
			_move_origin = _joy_home if widgets_only else _clamp_joystick_origin(pos)
			_update_joystick(pos)
			queue_redraw()
			return true

		# Free right-side / upper-side look pad (real touch only so desktop preview doesn't hijack mouse)
		if not widgets_only and _look_finger == -1:
			_look_finger = finger_id
			return true

		return false
	else:
		var consumed: bool = false
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
		if consumed:
			queue_redraw()
		return consumed

func _handle_pointer_drag(finger_id: int, pos: Vector2, relative: Vector2) -> bool:
	if finger_id == _move_finger:
		_update_joystick(pos)
		queue_redraw()
		return true
	if finger_id == _look_finger or finger_id == _fire_finger:
		# Allow dragging while holding FIRE so mobile players can track moving targets smoothly.
		emit_signal("look_dragged", relative)
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
	var ring_alpha: float = 0.72 if _move_finger != -1 else 0.42
	draw_circle(joy_center, _joy_radius, Color(0.06, 0.055, 0.048, 0.46 if _move_finger != -1 else 0.28))
	draw_arc(joy_center, _joy_radius, 0.0, TAU, 48, Color(0.96, 0.62, 0.04, ring_alpha), 2.2 * s, true)
	draw_arc(joy_center, _joy_radius * 0.46, 0.0, TAU, 32, Color(0.96, 0.62, 0.04, 0.18), 1.2 * s, true)

	# Cardinal directional ticks
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(
			joy_center + dir * (_joy_radius - 10.0 * s),
			joy_center + dir * (_joy_radius - 3.0 * s),
			Color(0.98, 0.75, 0.14, 0.45),
			2.0 * s,
			true
		)

	# Thumb knob
	var knob_pos: Vector2 = joy_center + _move_knob_offset
	var knob_col: Color = Color(0.96, 0.62, 0.04, 0.88) if _move_finger != -1 else Color(0.85, 0.47, 0.02, 0.58)
	draw_circle(knob_pos, _knob_radius, knob_col)
	draw_arc(knob_pos, _knob_radius, 0.0, TAU, 32, Color(0.99, 0.90, 0.54, 0.9), 2.0 * s, true)

	# 2. Tactical Action Buttons
	_draw_action_button("fire", _lbl_fire, Color(0.86, 0.28, 0.12, 0.55), Color(0.98, 0.65, 0.14, 0.92), true, 16)
	_draw_action_button("jump", _lbl_jump, Color(0.09, 0.08, 0.07, 0.56), Color(0.85, 0.60, 0.20, 0.72), false, 11)
	_draw_action_button(
		"crouch",
		_lbl_crouch,
		Color(0.85, 0.47, 0.02, 0.68) if _crouch_active else Color(0.09, 0.08, 0.07, 0.56),
		Color(0.99, 0.85, 0.35, 0.95) if _crouch_active else Color(0.85, 0.60, 0.20, 0.72),
		_crouch_active,
		10
	)
	_draw_action_button("reload", _lbl_reload, Color(0.09, 0.08, 0.07, 0.56), Color(0.85, 0.60, 0.20, 0.72), false, 10)
	if _is_reloading and _buttons.has("reload"):
		var rb: Dictionary = _buttons["reload"]
		draw_arc(
			rb["center"],
			float(rb["radius"]) + 4.0 * s,
			-PI * 0.5,
			-PI * 0.5 + TAU * clampf(_reload_progress, 0.0, 1.0),
			32,
			Color("#38bdf8"),
			3.0 * s,
			true
		)

	if _can_scope:
		_draw_action_button(
			"scope",
			_lbl_scope,
			Color(0.06, 0.36, 0.46, 0.74) if _is_scoped else Color(0.09, 0.08, 0.07, 0.56),
			Color("#38bdf8") if _is_scoped else Color(0.49, 0.83, 0.99, 0.78),
			_is_scoped,
			10
		)

	if _he_count > 0:
		_draw_action_button("he", "%s %d" % [_lbl_he, _he_count], Color(0.32, 0.14, 0.06, 0.62), Color("#f59e0b"), false, 10)
	if _flash_count > 0:
		_draw_action_button("flash", "%s %d" % [_lbl_flash, _flash_count], Color(0.06, 0.20, 0.30, 0.62), Color("#38bdf8"), false, 10)

func _draw_action_button(btn_id: String, text: String, fill_col: Color, border_col: Color, emphasized: bool, base_font_px: int) -> void:
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
	draw_arc(center, r, 0.0, TAU, 36, draw_border, (3.0 if (emphasized or is_down) else 2.0) * _scale_factor, true)

	if btn_id == "fire":
		# Inner tactical reticle ring on fire trigger
		draw_arc(center, r * 0.68, 0.0, TAU, 28, Color(1.0, 0.92, 0.75, 0.32), 1.4 * _scale_factor, true)

	var font: Font = _font_bold if _font_bold != null else ThemeDB.fallback_font
	if font != null:
		var fsize: int = maxi(9, int(round(float(base_font_px) * _scale_factor)))
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
		var text_pos := Vector2(center.x - text_size.x * 0.5, center.y + text_size.y * 0.28)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color("#faf5eb"))

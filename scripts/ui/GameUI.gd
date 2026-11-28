class_name GameUI
extends CanvasLayer

## Complete bilingual (VI/EN) tactical UI layer with visual Weapon Icon Buy Menu cards

var game: FpsGameController
var selected_difficulty: GameTypes.BotDifficulty = GameTypes.BotDifficulty.TACTICAL
var selected_bot_count: int = 4
var buy_open: bool = false
var muted: bool = false
var _last_hud: Dictionary = {}

var _font_regular: Font
var _font_bold: Font

# Top-level containers
var _title_root: Control
var _hud_root: Control
var _buy_root: Control
var _pause_root: Control
var _gameover_root: Control

# Title controls
var _title_margin: MarginContainer
var _title_sub_lbl: Label
var _title_diff_lbl: Label
var _title_cnt_lbl: Label
var _title_lang_lbl: Label
var _title_touch_lbl: Label
var _title_deploy_btn: Button
var _title_info_lbl: Label
var _title_privacy_btn: Button
var _title_ad_privacy_btn: Button
var _title_meta_lbl: Label
var _title_hint_lbl: Label
var _diff_buttons: Dictionary = {}
var _count_buttons: Dictionary = {}
var _lang_buttons_title: Dictionary = {}
var _lang_buttons_pause: Dictionary = {}
var _touch_buttons_title: Dictionary = {}
var _touch_buttons_pause: Dictionary = {}

# HUD references
var _crosshair: CrosshairControl
var _touch_controls: TouchControls
var _radar_panel: PanelContainer
var _radar: RadarControl
var _radar_title_lbl: Label
var _bots_label: Label
var _score_panel: PanelContainer
var _score_you_tag: Label
var _score_you_label: Label
var _round_label: Label
var _score_bot_label: Label
var _score_bot_tag: Label
var _cash_btn: Button
var _banner_panel: PanelContainer
var _banner_label: Label
var _top_right_box: VBoxContainer
var _util_row: HBoxContainer
var _hud_buy_btn: Button
var _mute_btn: Button
var _hud_pause_btn: Button
var _killfeed_box: VBoxContainer
var _vit_panel: PanelContainer
var _hp_label: Label
var _hp_tag_label: Label
var _armor_label: Label
var _armor_tag_label: Label
var _br_box: VBoxContainer
var _slots_row: HBoxContainer
var _ammo_panel: PanelContainer
var _slot_buttons: Dictionary = {}
var _weapon_name_label: Label
var _reload_bar: ProgressBar
var _ammo_label: Label
var _pointer_hint: PanelContainer
var _pointer_hint_lbl: Label

var _touch_mode: String = "auto"
var _touch_device_detected: bool = false
var _touch_active: bool = false

# Buy menu references
var _buy_title_lbl: Label
var _buy_sub_lbl: Label
var _buy_cash_label: Label
var _buy_footer_lbl: Label
var _buy_ad_bonus_btn: Button
var _buy_done_btn: Button
var _buy_cards: Dictionary = {}
var _buy_armor_card: Dictionary = {}

# Pause & GameOver references
var _pause_sub_lbl: Label
var _pause_title_lbl: Label
var _pause_lang_lbl: Label
var _pause_touch_lbl: Label
var _pause_score_title: Label
var _pause_kills_title: Label
var _pause_acc_title: Label
var _pause_score_val: Label
var _pause_kills_val: Label
var _pause_acc_val: Label
var _pause_resume_btn: Button
var _pause_restart_btn: Button
var _pause_menu_btn: Button
var _pause_privacy_btn: Button
var _pause_ad_privacy_btn: Button

var _go_subtitle: Label
var _go_title: Label
var _go_summary: Label
var _go_kills_title: Label
var _go_hs_title: Label
var _go_acc_title: Label
var _go_dmg_title: Label
var _go_kills_val: Label
var _go_hs_val: Label
var _go_acc_val: Label
var _go_dmg_val: Label
var _go_replay_btn: Button
var _go_menu_btn: Button

var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: float = 0.0

func _ready() -> void:
	Localization.ensure_loaded()
	_touch_mode = Localization.get_touch_mode()
	_touch_device_detected = TouchControls.detect_touch_device()
	_load_fonts()
	game = get_parent() as FpsGameController
	_build_title_screen()
	_build_hud()
	_build_buy_menu()
	_build_pause_modal()
	_build_gameover_modal()
	_build_toast()
	_wire_touch_controls()
	_apply_localization()
	_update_touch_controls_state()

	if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply_hud_layout):
		get_viewport().size_changed.connect(_apply_hud_layout)

	var ad := _ad_manager()
	if ad != null and not ad.status_message.is_connected(_show_toast):
		ad.status_message.connect(_show_toast)

	if game != null:
		game.hud_updated.connect(_on_hud_updated)
		game.phase_changed.connect(_on_phase_changed)
		_on_phase_changed(game.phase)
		_on_hud_updated(game.get_hud_snapshot())

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_panel != null:
			_toast_panel.visible = false

func _ad_manager() -> AdManagerNode:
	return get_node_or_null("/root/AdManager") as AdManagerNode

func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 0.0
	_toast_panel.anchor_bottom = 0.0
	_toast_panel.offset_left = -260
	_toast_panel.offset_right = 260
	_toast_panel.offset_top = 68
	_toast_panel.offset_bottom = 104
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.065, 0.05, 0.95), Color("#f59e0b"), 6, 1, 16, 8))
	_toast_label = _make_label("", 13, Color("#fde68a"), true)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false
	add_child(_toast_panel)

func _show_toast(msg: String) -> void:
	if _toast_panel == null or _toast_label == null or msg.is_empty():
		return
	_toast_label.text = msg
	_toast_panel.visible = true
	_toast_timer = 2.8

func _open_privacy_policy() -> void:
	OS.shell_open(AppInfo.privacy_url())

func _open_ad_privacy_options() -> void:
	var ad := _ad_manager()
	if ad != null:
		ad.show_privacy_options()

func _request_ad_bonus_cash() -> void:
	var ad := _ad_manager()
	if ad == null:
		_show_toast(Localization.tr_key("ad_not_ready"))
		return
	ad.show_rewarded("buy_bonus_cash", _on_ad_bonus_cash_reward)

func _on_ad_bonus_cash_reward(earned: bool) -> void:
	if not earned or game == null:
		return
	game.grant_ad_bonus_cash(1500)
	_show_toast(Localization.tr_key("ad_bonus_granted"))

func _load_fonts() -> void:
	if ResourceLoader.exists("res://assets/fonts/ui_font.ttf"):
		_font_regular = load("res://assets/fonts/ui_font.ttf")
	if ResourceLoader.exists("res://assets/fonts/ui_font_bold.ttf"):
		_font_bold = load("res://assets/fonts/ui_font_bold.ttf")

func _apply_font(ctrl: Control, bold: bool = false) -> void:
	var f: Font = _font_bold if (bold and _font_bold != null) else _font_regular
	if f != null:
		ctrl.add_theme_font_override("font", f)

func _unhandled_input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: Key = event.physical_keycode
		if game.phase == GameTypes.GamePhase.TITLE:
			if kc == KEY_ENTER or kc == KEY_SPACE:
				_start_match()
				get_viewport().set_input_as_handled()
			return

		if kc == KEY_M:
			_toggle_mute()
			get_viewport().set_input_as_handled()
			return

		if game.phase == GameTypes.GamePhase.PLAYING:
			if kc == KEY_B:
				_set_buy_open(not buy_open)
				get_viewport().set_input_as_handled()
				return
			if kc == KEY_ESCAPE or kc == KEY_P:
				if buy_open:
					_set_buy_open(false)
				else:
					game.set_phase(GameTypes.GamePhase.PAUSED)
				get_viewport().set_input_as_handled()
				return
		elif game.phase == GameTypes.GamePhase.PAUSED:
			if kc == KEY_ESCAPE or kc == KEY_P:
				game.set_phase(GameTypes.GamePhase.PLAYING)
				get_viewport().set_input_as_handled()

func _style_box(bg: Color, border: Color, radius: int = 4, border_w: int = 1, pad_h: int = 10, pad_v: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

func _style_button(btn: Button, bg: Color, hover_bg: Color, border: Color, text_col: Color, bold: bool = true) -> void:
	_apply_font(btn, bold)
	btn.add_theme_stylebox_override("normal", _style_box(bg, border, 5, 1, 12, 7))
	btn.add_theme_stylebox_override("hover", _style_box(hover_bg, border.lightened(0.22), 5, 1, 12, 7))
	btn.add_theme_stylebox_override("pressed", _style_box(hover_bg.darkened(0.1), border, 5, 1, 12, 7))
	btn.add_theme_stylebox_override("disabled", _style_box(Color(0.08, 0.07, 0.06, 0.65), Color(0.2, 0.19, 0.18, 0.5), 5, 1, 12, 7))
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", Color("#6b7280"))
	btn.focus_mode = Control.FOCUS_NONE

func _make_label(text: String, size_px: int, col: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	_apply_font(l, bold)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l

func set_language(lang: String) -> void:
	Localization.set_language(lang)
	_apply_localization()
	if not _last_hud.is_empty():
		_on_hud_updated(_last_hud)

func set_touch_mode(mode: String) -> void:
	if not (mode in ["auto", "on", "off"]):
		return
	_touch_mode = mode
	Localization.set_touch_mode(mode)
	_update_touch_controls_state()
	_refresh_title_buttons()
	_apply_localization()
	if not _last_hud.is_empty():
		_on_hud_updated(_last_hud)

func is_touch_controls_active() -> bool:
	return _touch_active

func _wire_touch_controls() -> void:
	if _touch_controls == null:
		return
	_touch_controls.set_fonts(_font_bold if _font_bold != null else _font_regular)
	var excluded: Array[Control] = []
	if _score_panel != null:
		excluded.append(_score_panel)
	if _util_row != null:
		excluded.append(_util_row)
	if _slots_row != null:
		excluded.append(_slots_row)
	_touch_controls.set_excluded_controls(excluded)
	_touch_controls.move_changed.connect(func(v: Vector2):
		if game != null:
			game.set_virtual_move(v)
	)
	_touch_controls.look_dragged.connect(func(delta_px: Vector2):
		if game != null:
			game.apply_virtual_look(delta_px)
	)
	_touch_controls.fire_changed.connect(func(pressed: bool):
		if game != null:
			game.set_virtual_fire(pressed)
	)
	_touch_controls.jump_pressed.connect(func():
		if game != null:
			game.trigger_virtual_jump()
	)
	_touch_controls.crouch_toggled.connect(func(active: bool):
		if game != null:
			game.set_virtual_crouch(active)
	)
	_touch_controls.reload_pressed.connect(func():
		if game != null:
			game.trigger_virtual_reload()
	)
	_touch_controls.scope_pressed.connect(func():
		if game != null:
			game.trigger_virtual_scope()
	)
	_touch_controls.grenade_pressed.connect(func(kind: String):
		if game != null:
			game.trigger_virtual_grenade(kind)
	)
	_touch_controls.touch_input_detected.connect(_on_touch_input_detected)

func _on_touch_input_detected() -> void:
	if _touch_device_detected:
		return
	_touch_device_detected = true
	if _touch_mode == "auto":
		_update_touch_controls_state()
		_apply_localization()

func _update_touch_controls_state() -> void:
	var want_touch: bool = false
	if _touch_mode == "on":
		want_touch = true
	elif _touch_mode == "auto":
		want_touch = _touch_device_detected

	_touch_active = want_touch
	if game != null:
		game.set_touch_controls_enabled(want_touch)

	var show_overlay: bool = (
		want_touch
		and game != null
		and game.phase == GameTypes.GamePhase.PLAYING
		and not buy_open
	)
	if _touch_controls != null:
		_touch_controls.set_controls_active(show_overlay)
	_apply_hud_layout()

func _apply_hud_layout() -> void:
	if _vit_panel == null or _br_box == null or _radar_panel == null or _top_right_box == null:
		return
	var insets: Dictionary = _touch_controls.get_safe_insets() if _touch_controls != null else {"left": 0.0, "right": 0.0, "top": 0.0, "bottom": 0.0}
	var safe_l: float = float(insets["left"])
	var safe_r: float = float(insets["right"])
	var safe_t: float = float(insets["top"])
	var safe_b: float = float(insets["bottom"])

	_radar_panel.position = Vector2(16.0 + safe_l, 16.0 + safe_t)
	_top_right_box.offset_left = -340.0 - safe_r
	_top_right_box.offset_right = -16.0 - safe_r
	_top_right_box.offset_top = 16.0 + safe_t

	if _touch_active:
		# Move HP/Armor under Radar (top-left) so bottom-left stays completely clear for the Joycon.
		_vit_panel.anchor_left = 0.0
		_vit_panel.anchor_right = 0.0
		_vit_panel.anchor_top = 0.0
		_vit_panel.anchor_bottom = 0.0
		_vit_panel.offset_left = 16.0 + safe_l
		_vit_panel.offset_right = 216.0 + safe_l
		_vit_panel.offset_top = 188.0 + safe_t
		_vit_panel.offset_bottom = 240.0 + safe_t

		# Move weapon slots & ammo to bottom-center so bottom-right stays clear for Fire/Jump/Crouch/Reload.
		_br_box.anchor_left = 0.5
		_br_box.anchor_right = 0.5
		_br_box.anchor_top = 1.0
		_br_box.anchor_bottom = 1.0
		_br_box.offset_left = -230.0
		_br_box.offset_right = 230.0
		_br_box.offset_top = -114.0 - safe_b
		_br_box.offset_bottom = -12.0 - safe_b
		if _slots_row != null:
			_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
		if _ammo_panel != null:
			_ammo_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		# Desktop default HUD anchors
		_vit_panel.anchor_left = 0.0
		_vit_panel.anchor_right = 0.0
		_vit_panel.anchor_top = 1.0
		_vit_panel.anchor_bottom = 1.0
		_vit_panel.offset_left = 16.0
		_vit_panel.offset_right = 216.0
		_vit_panel.offset_top = -72.0
		_vit_panel.offset_bottom = -16.0

		_br_box.anchor_left = 1.0
		_br_box.anchor_right = 1.0
		_br_box.anchor_top = 1.0
		_br_box.anchor_bottom = 1.0
		_br_box.offset_left = -460.0
		_br_box.offset_right = -16.0
		_br_box.offset_top = -114.0
		_br_box.offset_bottom = -16.0
		if _slots_row != null:
			_slots_row.alignment = BoxContainer.ALIGNMENT_END
		if _ammo_panel != null:
			_ammo_panel.size_flags_horizontal = Control.SIZE_SHRINK_END

	for s in _slot_buttons.keys():
		var sb: Button = _slot_buttons[s]
		sb.custom_minimum_size = Vector2(0, 34) if _touch_active else Vector2.ZERO

func _build_title_screen() -> void:
	_title_root = Control.new()
	_title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_title_root)

	var scrim := ColorRect.new()
	scrim.color = Color(0.06, 0.055, 0.047, 0.74)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	scrim.offset_right = 590
	_title_root.add_child(scrim)

	_title_margin = MarginContainer.new()
	_title_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_margin.add_theme_constant_override("margin_left", 48)
	_title_margin.add_theme_constant_override("margin_top", 44)
	_title_margin.add_theme_constant_override("margin_right", 48)
	_title_margin.add_theme_constant_override("margin_bottom", 30)
	_title_root.add_child(_title_margin)

	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_BEGIN
	_title_margin.add_child(outer)

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 6)
	outer.add_child(header_box)

	var title_lbl := _make_label("CS-PROTOCOL", 46, Color("#faf5eb"), true)
	header_box.add_child(title_lbl)

	var accent_bar := ColorRect.new()
	accent_bar.color = Color("#d97706")
	accent_bar.custom_minimum_size = Vector2(220, 4)
	accent_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header_box.add_child(accent_bar)

	_title_sub_lbl = _make_label("", 13, Color("#d6c7b2"))
	header_box.add_child(_title_sub_lbl)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size.y = 20
	outer.add_child(spacer1)

	var setup_panel := PanelContainer.new()
	setup_panel.custom_minimum_size.x = 500
	setup_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	setup_panel.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.07, 0.06, 0.90), Color(0.85, 0.47, 0.02, 0.35), 6, 1, 18, 16))
	outer.add_child(setup_panel)

	var setup_v := VBoxContainer.new()
	setup_v.add_theme_constant_override("separation", 12)
	setup_panel.add_child(setup_v)

	# Language row
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 10)
	setup_v.add_child(lang_row)
	_title_lang_lbl = _make_label("", 13, Color("#fde68a"), true)
	_title_lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(_title_lang_lbl)

	for pair in [["vi", "Tiếng Việt"], ["en", "English"]]:
		var lbtn := Button.new()
		lbtn.text = pair[1]
		var code: String = pair[0]
		lbtn.pressed.connect(func(): set_language(code))
		lang_row.add_child(lbtn)
		_lang_buttons_title[code] = lbtn

	# Bot AI Tier row
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	setup_v.add_child(diff_row)
	_title_diff_lbl = _make_label("", 13, Color("#fde68a"), true)
	_title_diff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_row.add_child(_title_diff_lbl)

	for d_val in [GameTypes.BotDifficulty.RECRUIT, GameTypes.BotDifficulty.TACTICAL, GameTypes.BotDifficulty.ELITE]:
		var btn := Button.new()
		var dv: GameTypes.BotDifficulty = d_val
		btn.pressed.connect(func():
			selected_difficulty = dv
			_refresh_title_buttons()
		)
		diff_row.add_child(btn)
		_diff_buttons[dv] = btn

	# Bot count row
	var cnt_row := HBoxContainer.new()
	cnt_row.add_theme_constant_override("separation", 8)
	setup_v.add_child(cnt_row)
	_title_cnt_lbl = _make_label("", 13, Color("#fde68a"), true)
	_title_cnt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cnt_row.add_child(_title_cnt_lbl)

	for cnt in [3, 4, 5]:
		var btn := Button.new()
		var c_val: int = cnt
		btn.pressed.connect(func():
			selected_bot_count = c_val
			_refresh_title_buttons()
		)
		cnt_row.add_child(btn)
		_count_buttons[c_val] = btn

	# Touch Joycon row
	var touch_row := HBoxContainer.new()
	touch_row.add_theme_constant_override("separation", 8)
	setup_v.add_child(touch_row)
	_title_touch_lbl = _make_label("", 13, Color("#fde68a"), true)
	_title_touch_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	touch_row.add_child(_title_touch_lbl)

	for m in ["auto", "on", "off"]:
		var tbtn := Button.new()
		var mode_val: String = m
		tbtn.pressed.connect(func(): set_touch_mode(mode_val))
		touch_row.add_child(tbtn)
		_touch_buttons_title[mode_val] = tbtn

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 18
	outer.add_child(spacer2)

	_title_deploy_btn = Button.new()
	_title_deploy_btn.custom_minimum_size = Vector2(260, 48)
	_title_deploy_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_title_deploy_btn.add_theme_font_size_override("font_size", 16)
	_style_button(_title_deploy_btn, Color("#d97706"), Color("#f59e0b"), Color("#fbbf24"), Color("#0c0a09"))
	_title_deploy_btn.pressed.connect(_start_match)
	outer.add_child(_title_deploy_btn)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size.y = 14
	outer.add_child(spacer3)
	_title_info_lbl = _make_label("", 13, Color("#d6d3d1"))
	outer.add_child(_title_info_lbl)

	var legal_row := HBoxContainer.new()
	legal_row.add_theme_constant_override("separation", 8)
	outer.add_child(legal_row)

	_title_privacy_btn = Button.new()
	_title_privacy_btn.add_theme_font_size_override("font_size", 11)
	_style_button(_title_privacy_btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#d6d3d1"), false)
	_title_privacy_btn.pressed.connect(_open_privacy_policy)
	legal_row.add_child(_title_privacy_btn)

	_title_ad_privacy_btn = Button.new()
	_title_ad_privacy_btn.add_theme_font_size_override("font_size", 11)
	_style_button(_title_ad_privacy_btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#fde68a"), false)
	_title_ad_privacy_btn.pressed.connect(_open_ad_privacy_options)
	_title_ad_privacy_btn.visible = false
	legal_row.add_child(_title_ad_privacy_btn)

	_title_meta_lbl = _make_label("v%s · %s" % [AppInfo.version(), AppInfo.developer()], 11, Color("#a8a29e"))
	legal_row.add_child(_title_meta_lbl)

	var flex := Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(flex)

	_title_hint_lbl = _make_label("", 13, Color("#e7e5e4"))
	outer.add_child(_title_hint_lbl)

func _refresh_title_buttons() -> void:
	var lang: String = Localization.get_language()
	for code in _lang_buttons_title.keys():
		var btn: Button = _lang_buttons_title[code]
		if code == lang:
			_style_button(btn, Color("#d97706"), Color("#f59e0b"), Color("#fbbf24"), Color("#0c0a09"))
		else:
			_style_button(btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#d6d3d1"))
	for code in _lang_buttons_pause.keys():
		var btn: Button = _lang_buttons_pause[code]
		if code == lang:
			_style_button(btn, Color("#d97706"), Color("#f59e0b"), Color("#fbbf24"), Color("#0c0a09"))
		else:
			_style_button(btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#d6d3d1"))
	for d in _diff_buttons.keys():
		var btn: Button = _diff_buttons[d]
		btn.text = Localization.difficulty_label(d)
		if d == selected_difficulty:
			_style_button(btn, Color("#d97706"), Color("#f59e0b"), Color("#fbbf24"), Color("#0c0a09"))
		else:
			_style_button(btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#d6d3d1"))
	for c in _count_buttons.keys():
		var btn: Button = _count_buttons[c]
		btn.text = Localization.tr_key("bots_count") % c
		if c == selected_bot_count:
			_style_button(btn, Color("#d97706"), Color("#f59e0b"), Color("#fbbf24"), Color("#0c0a09"))
		else:
			_style_button(btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#d6d3d1"))
	var touch_label_keys: Dictionary = {
		"auto": "touch_mode_auto",
		"on": "touch_mode_on",
		"off": "touch_mode_off",
	}
	for m in _touch_buttons_title.keys():
		var btn: Button = _touch_buttons_title[m]
		btn.text = Localization.tr_key(String(touch_label_keys[m]))
		if m == _touch_mode:
			_style_button(btn, Color("#d97706"), Color("#f59e0b"), Color("#fbbf24"), Color("#0c0a09"))
		else:
			_style_button(btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#d6d3d1"))
	for m in _touch_buttons_pause.keys():
		var btn: Button = _touch_buttons_pause[m]
		btn.text = Localization.tr_key(String(touch_label_keys[m]))
		if m == _touch_mode:
			_style_button(btn, Color("#d97706"), Color("#f59e0b"), Color("#fbbf24"), Color("#0c0a09"))
		else:
			_style_button(btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#d6d3d1"))

func _build_hud() -> void:
	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	_crosshair = CrosshairControl.new()
	_hud_root.add_child(_crosshair)

	_touch_controls = TouchControls.new()
	_hud_root.add_child(_touch_controls)

	# TOP-LEFT: Radar
	_radar_panel = PanelContainer.new()
	_radar_panel.position = Vector2(16, 16)
	_radar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radar_panel.add_theme_stylebox_override("panel", _style_box(Color(0.07, 0.06, 0.05, 0.85), Color(0.96, 0.62, 0.04, 0.4), 4, 1, 6, 6))
	_hud_root.add_child(_radar_panel)

	var radar_v := VBoxContainer.new()
	radar_v.add_theme_constant_override("separation", 4)
	_radar_panel.add_child(radar_v)
	_radar = RadarControl.new()
	radar_v.add_child(_radar)
	var radar_foot := HBoxContainer.new()
	radar_v.add_child(radar_foot)
	_radar_title_lbl = _make_label("", 10, Color("#fde68a"), true)
	_radar_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radar_foot.add_child(_radar_title_lbl)
	_bots_label = _make_label("", 10, Color("#fde68a"), true)
	radar_foot.add_child(_bots_label)

	# TOP-CENTER: Score Strip + Round Banner
	var top_center := VBoxContainer.new()
	top_center.anchor_left = 0.5
	top_center.anchor_right = 0.5
	top_center.offset_left = -250
	top_center.offset_right = 250
	top_center.offset_top = 16
	top_center.alignment = BoxContainer.ALIGNMENT_CENTER
	top_center.add_theme_constant_override("separation", 8)
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(top_center)

	_score_panel = PanelContainer.new()
	_score_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_score_panel.add_theme_stylebox_override("panel", _style_box(Color(0.07, 0.06, 0.05, 0.88), Color(0.96, 0.62, 0.04, 0.4), 4, 1, 16, 6))
	top_center.add_child(_score_panel)

	var score_h := HBoxContainer.new()
	score_h.add_theme_constant_override("separation", 14)
	_score_panel.add_child(score_h)
	_score_you_tag = _make_label("", 12, Color("#34d399"), true)
	score_h.add_child(_score_you_tag)
	_score_you_label = _make_label("0", 22, Color("#f5f5f4"), true)
	score_h.add_child(_score_you_label)
	_round_label = _make_label("", 13, Color("#fbbf24"), true)
	score_h.add_child(_round_label)
	_score_bot_label = _make_label("0", 22, Color("#f5f5f4"), true)
	score_h.add_child(_score_bot_label)
	_score_bot_tag = _make_label("", 12, Color("#fb7185"), true)
	score_h.add_child(_score_bot_tag)
	_cash_btn = Button.new()
	_cash_btn.text = "$3500 [B]"
	_style_button(_cash_btn, Color("#1c1917"), Color("#292524"), Color("#34d399"), Color("#34d399"))
	_cash_btn.pressed.connect(func(): _set_buy_open(true))
	score_h.add_child(_cash_btn)

	_banner_panel = PanelContainer.new()
	_banner_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_banner_panel.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.06, 0.04, 0.92), Color(0.98, 0.75, 0.14, 0.65), 4, 1, 18, 6))
	_banner_label = _make_label("", 13, Color("#fde68a"), true)
	_banner_panel.add_child(_banner_label)
	_banner_panel.visible = false
	top_center.add_child(_banner_panel)

	# TOP-RIGHT: Utility buttons + Killfeed
	_top_right_box = VBoxContainer.new()
	_top_right_box.anchor_left = 1.0
	_top_right_box.anchor_right = 1.0
	_top_right_box.offset_left = -340
	_top_right_box.offset_right = -16
	_top_right_box.offset_top = 16
	_top_right_box.add_theme_constant_override("separation", 8)
	_top_right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_top_right_box)

	_util_row = HBoxContainer.new()
	_util_row.alignment = BoxContainer.ALIGNMENT_END
	_util_row.add_theme_constant_override("separation", 6)
	_top_right_box.add_child(_util_row)

	_hud_buy_btn = Button.new()
	_style_button(_hud_buy_btn, Color(0.07, 0.06, 0.05, 0.88), Color("#292524"), Color(0.96, 0.62, 0.04, 0.4), Color("#fde68a"))
	_hud_buy_btn.pressed.connect(func(): _set_buy_open(true))
	_util_row.add_child(_hud_buy_btn)

	_mute_btn = Button.new()
	_style_button(_mute_btn, Color(0.07, 0.06, 0.05, 0.88), Color("#292524"), Color(0.96, 0.62, 0.04, 0.4), Color("#fde68a"))
	_mute_btn.pressed.connect(_toggle_mute)
	_util_row.add_child(_mute_btn)

	_hud_pause_btn = Button.new()
	_style_button(_hud_pause_btn, Color(0.07, 0.06, 0.05, 0.88), Color("#292524"), Color(0.96, 0.62, 0.04, 0.4), Color("#fde68a"))
	_hud_pause_btn.pressed.connect(func(): game.set_phase(GameTypes.GamePhase.PAUSED))
	_util_row.add_child(_hud_pause_btn)

	_killfeed_box = VBoxContainer.new()
	_killfeed_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_killfeed_box.add_theme_constant_override("separation", 4)
	_killfeed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_right_box.add_child(_killfeed_box)

	# BOTTOM-LEFT: HP & Armor
	_vit_panel = PanelContainer.new()
	_vit_panel.anchor_top = 1.0
	_vit_panel.anchor_bottom = 1.0
	_vit_panel.offset_left = 16
	_vit_panel.offset_top = -72
	_vit_panel.offset_bottom = -16
	_vit_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vit_panel.add_theme_stylebox_override("panel", _style_box(Color(0.07, 0.06, 0.05, 0.88), Color(0.96, 0.62, 0.04, 0.4), 4, 1, 16, 8))
	_hud_root.add_child(_vit_panel)

	var vit_h := HBoxContainer.new()
	vit_h.add_theme_constant_override("separation", 12)
	_vit_panel.add_child(vit_h)
	_hp_label = _make_label("100", 28, Color("#f5f5f4"), true)
	vit_h.add_child(_hp_label)
	_hp_tag_label = _make_label("", 12, Color("#a8a29e"), true)
	vit_h.add_child(_hp_tag_label)
	var sep := VSeparator.new()
	vit_h.add_child(sep)
	_armor_label = _make_label("100", 24, Color("#7dd3fc"), true)
	vit_h.add_child(_armor_label)
	_armor_tag_label = _make_label("", 12, Color("#a8a29e"), true)
	vit_h.add_child(_armor_tag_label)

	# BOTTOM-RIGHT: Slots & Ammo
	_br_box = VBoxContainer.new()
	_br_box.anchor_left = 1.0
	_br_box.anchor_right = 1.0
	_br_box.anchor_top = 1.0
	_br_box.anchor_bottom = 1.0
	_br_box.offset_left = -460
	_br_box.offset_right = -16
	_br_box.offset_top = -114
	_br_box.offset_bottom = -16
	_br_box.alignment = BoxContainer.ALIGNMENT_END
	_br_box.add_theme_constant_override("separation", 6)
	_br_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_br_box)

	_slots_row = HBoxContainer.new()
	_slots_row.alignment = BoxContainer.ALIGNMENT_END
	_slots_row.add_theme_constant_override("separation", 6)
	_br_box.add_child(_slots_row)
	for s in [1, 2, 3, 4, 5]:
		var sb := Button.new()
		sb.text = "[%d]" % s
		sb.add_theme_font_size_override("font_size", 11)
		var slot_idx: int = s
		sb.pressed.connect(func(): game.select_slot(slot_idx))
		_slots_row.add_child(sb)
		_slot_buttons[s] = sb

	_ammo_panel = PanelContainer.new()
	_ammo_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_ammo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_panel.add_theme_stylebox_override("panel", _style_box(Color(0.07, 0.06, 0.05, 0.88), Color(0.96, 0.62, 0.04, 0.4), 4, 1, 16, 8))
	_br_box.add_child(_ammo_panel)

	var ammo_h := HBoxContainer.new()
	ammo_h.add_theme_constant_override("separation", 16)
	_ammo_panel.add_child(ammo_h)

	var w_info := VBoxContainer.new()
	w_info.alignment = BoxContainer.ALIGNMENT_CENTER
	ammo_h.add_child(w_info)
	_weapon_name_label = _make_label("M4A1-S", 13, Color("#fcd34d"), true)
	w_info.add_child(_weapon_name_label)
	_reload_bar = ProgressBar.new()
	_reload_bar.min_value = 0.0
	_reload_bar.max_value = 100.0
	_reload_bar.show_percentage = false
	_reload_bar.custom_minimum_size = Vector2(110, 6)
	_reload_bar.visible = false
	w_info.add_child(_reload_bar)

	_ammo_label = _make_label("20 / 80", 26, Color("#f5f5f4"), true)
	ammo_h.add_child(_ammo_label)

	# BOTTOM-CENTER: Pointer lock hint
	_pointer_hint = PanelContainer.new()
	_pointer_hint.anchor_left = 0.5
	_pointer_hint.anchor_right = 0.5
	_pointer_hint.anchor_top = 1.0
	_pointer_hint.anchor_bottom = 1.0
	_pointer_hint.offset_left = -260
	_pointer_hint.offset_right = 260
	_pointer_hint.offset_top = -44
	_pointer_hint.offset_bottom = -16
	_pointer_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer_hint.add_theme_stylebox_override("panel", _style_box(Color(0.07, 0.06, 0.05, 0.82), Color(0.3, 0.28, 0.25, 0.7), 4, 1, 12, 4))
	_pointer_hint_lbl = _make_label("", 11, Color("#d6d3d1"))
	_pointer_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pointer_hint.add_child(_pointer_hint_lbl)
	_hud_root.add_child(_pointer_hint)

func _create_buy_card(item_id: String, on_click: Callable) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(262, 134)
	btn.pressed.connect(on_click)
	btn.focus_mode = Control.FOCUS_NONE

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	btn.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Header: Weapon Name + Price/Status
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(head)

	var name_lbl := _make_label(item_id.to_upper(), 13, Color("#f5f5f4"), true)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(name_lbl)

	var price_lbl := _make_label("$0", 13, Color("#34d399"), true)
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(price_lbl)

	# Weapon Thumbnail showcase strip
	var icon_bg := PanelContainer.new()
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_bg.add_theme_stylebox_override("panel", _style_box(Color(0.05, 0.045, 0.04, 0.72), Color(0.28, 0.25, 0.22, 0.55), 4, 1, 6, 4))
	vbox.add_child(icon_bg)

	var tex_rect := TextureRect.new()
	tex_rect.texture = WeaponIcons.get_icon(item_id)
	tex_rect.custom_minimum_size = Vector2(0, 56)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_bg.add_child(tex_rect)

	# Hint & Stats
	var hint_lbl := _make_label("", 10, Color("#d6d3d1"))
	hint_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hint_lbl)

	var stat_lbl := _make_label("", 10, Color("#fbbf24"), true)
	stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stat_lbl)

	return {
		"button": btn,
		"name_lbl": name_lbl,
		"price_lbl": price_lbl,
		"icon_rect": tex_rect,
		"hint_lbl": hint_lbl,
		"stat_lbl": stat_lbl,
	}

func _build_buy_menu() -> void:
	_buy_root = ColorRect.new()
	_buy_root.color = Color(0.04, 0.035, 0.03, 0.82)
	_buy_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buy_root.visible = false
	add_child(_buy_root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_buy_root.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(856, 560)
	card.add_theme_stylebox_override("panel", _style_box(Color(0.09, 0.075, 0.06, 0.97), Color(0.96, 0.62, 0.04, 0.5), 8, 1, 22, 18))
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	var title_v := VBoxContainer.new()
	title_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_title_lbl = _make_label("", 22, Color("#f5f5f4"), true)
	title_v.add_child(_buy_title_lbl)
	_buy_sub_lbl = _make_label("", 12, Color("#a8a29e"))
	title_v.add_child(_buy_sub_lbl)
	top.add_child(title_v)
	_buy_cash_label = _make_label("$3500", 24, Color("#34d399"), true)
	top.add_child(_buy_cash_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	for wid in GameTypes.BUYABLE_WEAPON_IDS:
		var item_id: String = wid
		var cdict := _create_buy_card(item_id, func(): game.buy_item(item_id))
		grid.add_child(cdict["button"])
		_buy_cards[item_id] = cdict

	_buy_armor_card = _create_buy_card("kevlar_helmet", func(): game.buy_item("kevlar_helmet"))
	grid.add_child(_buy_armor_card["button"])

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	_buy_footer_lbl = _make_label("", 12, Color("#a8a29e"))
	_buy_footer_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_buy_footer_lbl)

	_buy_ad_bonus_btn = Button.new()
	_style_button(_buy_ad_bonus_btn, Color(0.06, 0.25, 0.16, 0.95), Color(0.08, 0.34, 0.22, 0.98), Color("#34d399"), Color("#d1fae5"))
	_buy_ad_bonus_btn.pressed.connect(_request_ad_bonus_cash)
	foot.add_child(_buy_ad_bonus_btn)

	_buy_done_btn = Button.new()
	_style_button(_buy_done_btn, Color("#d97706"), Color("#f59e0b"), Color("#fbbf24"), Color("#0c0a09"))
	_buy_done_btn.pressed.connect(func(): _set_buy_open(false))
	foot.add_child(_buy_done_btn)

func _build_pause_modal() -> void:
	_pause_root = ColorRect.new()
	_pause_root.color = Color(0.04, 0.035, 0.03, 0.80)
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.visible = false
	add_child(_pause_root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(430, 360)
	card.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.067, 0.055, 0.97), Color(0.96, 0.62, 0.04, 0.5), 8, 1, 24, 22))
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	_pause_sub_lbl = _make_label("", 12, Color("#fbbf24"), true)
	v.add_child(_pause_sub_lbl)
	_pause_title_lbl = _make_label("", 24, Color("#f5f5f4"), true)
	v.add_child(_pause_title_lbl)

	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	v.add_child(lang_row)
	_pause_lang_lbl = _make_label("", 12, Color("#fde68a"), true)
	_pause_lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(_pause_lang_lbl)
	for pair in [["vi", "Tiếng Việt"], ["en", "English"]]:
		var lbtn := Button.new()
		lbtn.text = pair[1]
		var code: String = pair[0]
		lbtn.pressed.connect(func(): set_language(code))
		lang_row.add_child(lbtn)
		_lang_buttons_pause[code] = lbtn

	var pause_touch_row := HBoxContainer.new()
	pause_touch_row.add_theme_constant_override("separation", 6)
	v.add_child(pause_touch_row)
	_pause_touch_lbl = _make_label("", 12, Color("#fde68a"), true)
	_pause_touch_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_touch_row.add_child(_pause_touch_lbl)
	for m in ["auto", "on", "off"]:
		var ptbtn := Button.new()
		var mode_val: String = m
		ptbtn.pressed.connect(func(): set_touch_mode(mode_val))
		pause_touch_row.add_child(ptbtn)
		_touch_buttons_pause[mode_val] = ptbtn

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	v.add_child(stats)
	var sb_score := _add_stat_box(stats, "", "0 - 0", Color("#f5f5f4"))
	_pause_score_title = sb_score["title"]
	_pause_score_val = sb_score["val"]
	var sb_kills := _add_stat_box(stats, "", "0", Color("#34d399"))
	_pause_kills_title = sb_kills["title"]
	_pause_kills_val = sb_kills["val"]
	var sb_acc := _add_stat_box(stats, "", "0%", Color("#fcd34d"))
	_pause_acc_title = sb_acc["title"]
	_pause_acc_val = sb_acc["val"]

	_pause_resume_btn = Button.new()
	_pause_resume_btn.custom_minimum_size.y = 42
	_style_button(_pause_resume_btn, Color("#d97706"), Color("#f59e0b"), Color("#fbbf24"), Color("#0c0a09"))
	_pause_resume_btn.pressed.connect(func(): game.set_phase(GameTypes.GamePhase.PLAYING))
	v.add_child(_pause_resume_btn)

	_pause_restart_btn = Button.new()
	_pause_restart_btn.custom_minimum_size.y = 38
	_style_button(_pause_restart_btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#e7e5e4"))
	_pause_restart_btn.pressed.connect(_start_match)
	v.add_child(_pause_restart_btn)

	_pause_menu_btn = Button.new()
	_pause_menu_btn.custom_minimum_size.y = 38
	_style_button(_pause_menu_btn, Color("#0c0a09"), Color("#1c1917"), Color("#292524"), Color("#a8a29e"))
	_pause_menu_btn.pressed.connect(func(): game.set_phase(GameTypes.GamePhase.TITLE))
	v.add_child(_pause_menu_btn)

	var pause_legal := HBoxContainer.new()
	pause_legal.add_theme_constant_override("separation", 8)
	v.add_child(pause_legal)

	_pause_privacy_btn = Button.new()
	_pause_privacy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_privacy_btn.add_theme_font_size_override("font_size", 11)
	_style_button(_pause_privacy_btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#d6d3d1"), false)
	_pause_privacy_btn.pressed.connect(_open_privacy_policy)
	pause_legal.add_child(_pause_privacy_btn)

	_pause_ad_privacy_btn = Button.new()
	_pause_ad_privacy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_ad_privacy_btn.add_theme_font_size_override("font_size", 11)
	_style_button(_pause_ad_privacy_btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#fde68a"), false)
	_pause_ad_privacy_btn.pressed.connect(_open_ad_privacy_options)
	_pause_ad_privacy_btn.visible = false
	pause_legal.add_child(_pause_ad_privacy_btn)

func _build_gameover_modal() -> void:
	_gameover_root = ColorRect.new()
	_gameover_root.color = Color(0.04, 0.035, 0.03, 0.82)
	_gameover_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameover_root.visible = false
	add_child(_gameover_root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameover_root.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(450, 390)
	card.add_theme_stylebox_override("panel", _style_box(Color(0.08, 0.067, 0.055, 0.97), Color(0.96, 0.62, 0.04, 0.5), 8, 1, 24, 22))
	center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	_go_subtitle = _make_label("", 12, Color("#34d399"), true)
	v.add_child(_go_subtitle)
	_go_title = _make_label("", 28, Color("#f5f5f4"), true)
	v.add_child(_go_title)
	_go_summary = _make_label("", 12, Color("#a8a29e"))
	v.add_child(_go_summary)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var b1 := _add_stat_box(grid, "", "0", Color("#f5f5f4"))
	_go_kills_title = b1["title"]
	_go_kills_val = b1["val"]
	var b2 := _add_stat_box(grid, "", "0%", Color("#fbbf24"))
	_go_hs_title = b2["title"]
	_go_hs_val = b2["val"]
	var b3 := _add_stat_box(grid, "", "0%", Color("#7dd3fc"))
	_go_acc_title = b3["title"]
	_go_acc_val = b3["val"]
	var b4 := _add_stat_box(grid, "", "0", Color("#34d399"))
	_go_dmg_title = b4["title"]
	_go_dmg_val = b4["val"]

	_go_replay_btn = Button.new()
	_go_replay_btn.custom_minimum_size.y = 42
	_style_button(_go_replay_btn, Color("#d97706"), Color("#f59e0b"), Color("#fbbf24"), Color("#0c0a09"))
	_go_replay_btn.pressed.connect(func():
		var ad := _ad_manager()
		if ad != null:
			ad.maybe_show_interstitial("match_replay")
		_start_match()
	)
	v.add_child(_go_replay_btn)

	_go_menu_btn = Button.new()
	_go_menu_btn.custom_minimum_size.y = 38
	_style_button(_go_menu_btn, Color("#1c1917"), Color("#292524"), Color("#44403c"), Color("#d6d3d1"))
	_go_menu_btn.pressed.connect(func():
		var ad := _ad_manager()
		if ad != null:
			ad.maybe_show_interstitial("match_menu")
		game.set_phase(GameTypes.GamePhase.TITLE)
	)
	v.add_child(_go_menu_btn)

func _add_stat_box(parent: Control, title: String, val: String, val_col: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_box(Color("#1c1917"), Color("#292524"), 4, 1, 10, 8))
	var v := VBoxContainer.new()
	var tl := _make_label(title, 10, Color("#a8a29e"), true)
	v.add_child(tl)
	var vl := _make_label(val, 20, val_col, true)
	v.add_child(vl)
	panel.add_child(v)
	parent.add_child(panel)
	return {"title": tl, "val": vl}

func _apply_localization() -> void:
	_title_sub_lbl.text = Localization.tr_key("title_sub")
	_title_lang_lbl.text = Localization.tr_key("language_label")
	_title_diff_lbl.text = Localization.tr_key("bot_ai_tier")
	_title_cnt_lbl.text = Localization.tr_key("hostile_squad")
	_title_touch_lbl.text = Localization.tr_key("touch_controls_label")
	_title_deploy_btn.text = Localization.tr_key("deploy_match")
	_title_info_lbl.text = Localization.tr_key("title_features")
	_title_privacy_btn.text = Localization.tr_key("privacy_policy_btn")
	_title_ad_privacy_btn.text = Localization.tr_key("ad_privacy_btn")
	_title_hint_lbl.text = Localization.tr_key("controls_hint_touch") if _touch_active else Localization.tr_key("controls_hint")

	if _touch_controls != null:
		_touch_controls.set_labels(
			Localization.tr_key("touch_fire"),
			Localization.tr_key("touch_jump"),
			Localization.tr_key("touch_crouch"),
			Localization.tr_key("touch_reload"),
			Localization.tr_key("touch_scope"),
			Localization.tr_key("touch_he"),
			Localization.tr_key("touch_flash")
		)

	_radar_title_lbl.text = Localization.tr_key("radar")
	_score_you_tag.text = Localization.tr_key("you")
	_score_bot_tag.text = Localization.tr_key("bot")
	_hud_buy_btn.text = Localization.tr_key("buy_btn")
	_mute_btn.text = Localization.tr_key("muted") if muted else Localization.tr_key("sfx_on")
	_hud_pause_btn.text = Localization.tr_key("pause_btn")
	_hp_tag_label.text = Localization.tr_key("hp")
	_pointer_hint_lbl.text = Localization.tr_key("pointer_hint")

	_buy_title_lbl.text = Localization.tr_key("armory_title")
	_buy_sub_lbl.text = Localization.tr_key("armory_sub")
	_buy_footer_lbl.text = Localization.tr_key("armory_footer")
	_buy_ad_bonus_btn.text = Localization.tr_key("ad_bonus_cash_btn")
	_buy_done_btn.text = Localization.tr_key("done")

	_pause_sub_lbl.text = Localization.tr_key("pause_sub")
	_pause_title_lbl.text = Localization.tr_key("pause_title")
	_pause_lang_lbl.text = Localization.tr_key("language_label")
	_pause_touch_lbl.text = Localization.tr_key("touch_controls_label")
	_pause_score_title.text = Localization.tr_key("score")
	_pause_kills_title.text = Localization.tr_key("kills")
	_pause_acc_title.text = Localization.tr_key("accuracy")
	_pause_resume_btn.text = Localization.tr_key("resume_match")
	_pause_restart_btn.text = Localization.tr_key("restart_match")
	_pause_menu_btn.text = Localization.tr_key("main_menu")
	_pause_privacy_btn.text = Localization.tr_key("privacy_policy_btn")
	_pause_ad_privacy_btn.text = Localization.tr_key("ad_privacy_btn")

	_go_kills_title.text = Localization.tr_key("eliminations")
	_go_hs_title.text = Localization.tr_key("headshots")
	_go_acc_title.text = Localization.tr_key("accuracy")
	_go_dmg_title.text = Localization.tr_key("total_damage")
	_go_menu_btn.text = Localization.tr_key("main_menu")

	_refresh_title_buttons()

func _localize_token(tok: String) -> String:
	match tok:
		"__YOU__":
			return Localization.tr_key("you")
		"__BOT_SQUAD__":
			return Localization.tr_key("bot_squad")
		"__RIFLE__":
			return Localization.tr_key("weapon_rifle")
		"__HE_FRAG__":
			return Localization.tr_key("weapon_he_frag")
		"__KNIFE__":
			return Localization.tr_key("slot_knife")
		"__HE__":
			return Localization.tr_key("slot_he")
		"__FLASH__":
			return Localization.tr_key("slot_flash")
	return tok

func _start_match() -> void:
	buy_open = false
	_buy_root.visible = false
	game.start_new_match(selected_difficulty, selected_bot_count)

func _set_buy_open(open_state: bool) -> void:
	buy_open = open_state
	_buy_root.visible = open_state and game.phase == GameTypes.GamePhase.PLAYING
	game.set_buy_menu_open(open_state)
	_update_touch_controls_state()
	if open_state and not _last_hud.is_empty():
		_refresh_buy_menu(_last_hud)

func _toggle_mute() -> void:
	muted = not muted
	var audio := get_node_or_null("/root/TacticalAudio") as TacticalAudioManager
	if audio != null:
		audio.set_muted(muted)
	_mute_btn.text = Localization.tr_key("muted") if muted else Localization.tr_key("sfx_on")

func _on_phase_changed(p: GameTypes.GamePhase) -> void:
	_title_root.visible = (p == GameTypes.GamePhase.TITLE)
	_hud_root.visible = (p == GameTypes.GamePhase.PLAYING)
	_pause_root.visible = (p == GameTypes.GamePhase.PAUSED)
	_gameover_root.visible = (p == GameTypes.GamePhase.GAMEOVER)
	if p != GameTypes.GamePhase.PLAYING:
		buy_open = false
		_buy_root.visible = false
	_update_touch_controls_state()

	var ad := _ad_manager()
	if ad != null:
		var show_gdpr: bool = ad.privacy_options_required()
		if _title_ad_privacy_btn != null:
			_title_ad_privacy_btn.visible = show_gdpr
		if _pause_ad_privacy_btn != null:
			_pause_ad_privacy_btn.visible = show_gdpr
		if p == GameTypes.GamePhase.TITLE:
			ad.show_banner()
			if _title_margin != null:
				_title_margin.add_theme_constant_override("margin_bottom", 30 + int(ceilf(ad.banner_reserved_height())))
		else:
			ad.hide_banner()

func _on_hud_updated(hud: Dictionary) -> void:
	_last_hud = hud
	_crosshair.update_state(hud)
	if _touch_controls != null:
		_touch_controls.update_hud_state(hud)
	_radar.update_state(hud["radar_blips"], float(hud["player_x"]), float(hud["player_z"]), float(hud["player_yaw"]))

	_bots_label.text = Localization.tr_key("bots_alive") % [int(hud["bots_alive"]), int(hud["total_bots"])]
	_score_you_label.text = str(int(hud["player_score"]))
	_round_label.text = Localization.tr_key("round_short") % [int(hud["round"]), int(hud["max_rounds"])]
	_score_bot_label.text = str(int(hud["bot_score"]))
	_cash_btn.text = "$%d [B]" % int(hud["cash"])

	var banner_key: String = String(hud.get("round_banner_key", ""))
	var banner_arg: int = int(hud.get("round_banner_arg", 0))
	var banner: String = Localization.format_banner(banner_key, banner_arg)
	if banner.is_empty():
		banner = String(hud.get("round_banner", ""))
	_banner_panel.visible = not banner.is_empty()
	_banner_label.text = banner

	# Killfeed
	for child in _killfeed_box.get_children():
		child.queue_free()
	for k in hud["killfeed"]:
		var kp := PanelContainer.new()
		kp.size_flags_horizontal = Control.SIZE_SHRINK_END
		kp.add_theme_stylebox_override("panel", _style_box(Color(0.07, 0.06, 0.05, 0.86), Color("#44403c"), 3, 1, 8, 3))
		var hs_tag: String = " [HS]" if bool(k["headshot"]) else ""
		var killer_str: String = _localize_token(String(k["killer"]))
		var victim_str: String = _localize_token(String(k["victim"]))
		var weap_str: String = _localize_token(String(k["weapon"]))
		var kl := _make_label("%s  [%s]%s  %s" % [killer_str, weap_str, hs_tag, victim_str], 11, Color("#e7e5e4"))
		kp.add_child(kl)
		_killfeed_box.add_child(kp)

	var hp_val: int = int(hud["hp"])
	_hp_label.text = str(hp_val)
	_hp_label.add_theme_color_override("font_color", Color("#fb7185") if hp_val <= 25 else Color("#f5f5f4"))
	_armor_label.text = str(int(hud["armor"]))
	_armor_tag_label.text = Localization.tr_key("kevlar_plus") if bool(hud["has_helmet"]) else Localization.tr_key("armor")

	var active_s: int = int(hud["active_slot"])
	var hud_slots: Dictionary = hud["slots"]
	for s in [1, 2, 3, 4, 5]:
		var btn: Button = _slot_buttons[s]
		var item = hud_slots.get(s, null)
		btn.disabled = (item == null)
		var s_name: String = _localize_token(String(item["name"])) if item != null else "—"
		btn.text = "[%d] %s" % [s, s_name]
		if s == active_s:
			_style_button(btn, Color("#d97706"), Color("#f59e0b"), Color("#fcd34d"), Color("#0c0a09"))
		else:
			_style_button(btn, Color(0.07, 0.06, 0.05, 0.85), Color("#292524"), Color("#44403c"), Color("#e7e5e4"))

	_weapon_name_label.text = Localization.weapon_display_name(String(hud["active_weapon_id"])).to_upper()
	_reload_bar.visible = bool(hud["is_reloading"])
	_reload_bar.value = float(hud["reload_progress"]) * 100.0

	if active_s <= 2:
		_ammo_label.text = "%d / %d" % [int(hud["ammo_in_mag"]), int(hud["reserve_ammo"])]
	elif active_s == 3:
		_ammo_label.text = Localization.tr_key("melee")
	elif active_s == 4:
		_ammo_label.text = "x%d" % int(hud["he_count"])
	else:
		_ammo_label.text = "x%d" % int(hud["flash_count"])

	_pointer_hint.visible = not bool(hud["pointer_locked"]) and not buy_open and not _touch_active

	if buy_open:
		_refresh_buy_menu(hud)

	# Update Pause & GameOver stats
	var shots_f: int = int(hud["shots_fired"])
	var shots_h: int = int(hud["shots_hit"])
	var k_cnt: int = int(hud["kills"])
	var hs_cnt: int = int(hud["headshots"])
	var acc: int = int(round((float(shots_h) / float(shots_f)) * 100.0)) if shots_f > 0 else 0
	var hs_rate: int = int(round((float(hs_cnt) / float(k_cnt)) * 100.0)) if k_cnt > 0 else 0

	_pause_score_val.text = "%d - %d" % [int(hud["player_score"]), int(hud["bot_score"])]
	_pause_kills_val.text = str(k_cnt)
	_pause_acc_val.text = "%d%%" % acc

	var victory: bool = bool(hud["is_victory"])
	_go_subtitle.text = Localization.tr_key("mission_accomplished") if victory else Localization.tr_key("squad_eliminated")
	_go_subtitle.add_theme_color_override("font_color", Color("#34d399") if victory else Color("#fb7185"))
	_go_title.text = Localization.tr_key("match_victory") if victory else Localization.tr_key("defeat")
	_go_summary.text = Localization.tr_key("final_summary") % [
		int(hud["player_score"]),
		int(hud["bot_score"]),
		Localization.difficulty_label(hud["difficulty"]),
	]
	_go_kills_val.text = str(k_cnt)
	_go_hs_val.text = "%d%%" % hs_rate
	_go_acc_val.text = "%d%%" % acc
	_go_dmg_val.text = str(int(hud["damage_dealt"]))
	_go_replay_btn.text = Localization.tr_key("play_again") if victory else Localization.tr_key("try_again")

func _refresh_buy_menu(hud: Dictionary) -> void:
	var cash: int = int(hud["cash"])
	_buy_cash_label.text = "$%d" % cash
	var hud_slots: Dictionary = hud["slots"]

	for wid in GameTypes.BUYABLE_WEAPON_IDS:
		var spec: Dictionary = GameTypes.WEAPONS[wid]
		var cdict: Dictionary = _buy_cards[wid]
		var btn: Button = cdict["button"]
		var name_lbl: Label = cdict["name_lbl"]
		var price_lbl: Label = cdict["price_lbl"]
		var icon_rect: TextureRect = cdict["icon_rect"]
		var hint_lbl: Label = cdict["hint_lbl"]
		var stat_lbl: Label = cdict["stat_lbl"]

		var s_idx: int = int(spec["slot"])
		var owned: bool = (
			(s_idx == 1 and hud_slots.get(1, null) != null and hud_slots[1]["id"] == wid)
			or (s_idx == 2 and hud_slots.get(2, null) != null and hud_slots[2]["id"] == wid)
		)
		var price: int = int(spec["price"])
		var can_afford: bool = cash >= price
		btn.disabled = owned or not can_afford

		name_lbl.text = Localization.weapon_display_name(wid).to_upper()
		price_lbl.text = Localization.tr_key("equipped") if owned else "$%d" % price
		hint_lbl.text = Localization.weapon_role_hint(wid)
		if spec["category"] == GameTypes.WeaponCategory.GRENADE:
			stat_lbl.text = Localization.tr_key("stat_grenade") % int(round(float(spec["range"])))
		else:
			stat_lbl.text = Localization.tr_key("stat_dmg_mag") % [int(spec["damage"]), maxi(1, int(spec["magazine_size"]))]

		if owned:
			_style_button(btn, Color(0.03, 0.17, 0.11, 0.90), Color(0.03, 0.17, 0.11, 0.90), Color("#10b981"), Color("#d1fae5"))
			name_lbl.add_theme_color_override("font_color", Color("#d1fae5"))
			price_lbl.add_theme_color_override("font_color", Color("#34d399"))
			icon_rect.modulate = Color(1, 1, 1, 1.0)
		elif can_afford:
			_style_button(btn, Color("#1a1715"), Color("#292421"), Color("#57534e"), Color("#f5f5f4"))
			name_lbl.add_theme_color_override("font_color", Color("#f5f5f4"))
			price_lbl.add_theme_color_override("font_color", Color("#34d399"))
			icon_rect.modulate = Color(1, 1, 1, 1.0)
		else:
			_style_button(btn, Color("#0d0b0a"), Color("#0d0b0a"), Color("#292524"), Color("#78716c"))
			name_lbl.add_theme_color_override("font_color", Color("#78716c"))
			price_lbl.add_theme_color_override("font_color", Color("#78716c"))
			icon_rect.modulate = Color(0.55, 0.55, 0.55, 0.65)

	# Kevlar + Helmet card
	var armor_val: int = int(hud["armor"])
	var has_h: bool = bool(hud["has_helmet"])
	var armor_cost: int = 0 if (armor_val >= 100 and has_h) else (350 if armor_val > 0 else 1000)
	var abtn: Button = _buy_armor_card["button"]
	var aname: Label = _buy_armor_card["name_lbl"]
	var aprice: Label = _buy_armor_card["price_lbl"]
	var aicon: TextureRect = _buy_armor_card["icon_rect"]
	var ahint: Label = _buy_armor_card["hint_lbl"]
	var astat: Label = _buy_armor_card["stat_lbl"]

	abtn.disabled = (armor_cost == 0 or cash < armor_cost)
	aname.text = Localization.tr_key("kevlar_helmet_title")
	aprice.text = Localization.tr_key("full") if armor_cost == 0 else "$%d" % armor_cost
	ahint.text = Localization.tr_key("kevlar_helmet_desc")
	astat.text = "%s: %d / 100" % [Localization.tr_key("kevlar_plus") if has_h else Localization.tr_key("armor"), armor_val]

	if armor_cost == 0:
		_style_button(abtn, Color(0.05, 0.14, 0.22, 0.88), Color(0.05, 0.14, 0.22, 0.88), Color("#38bdf8"), Color("#e0f2fe"))
		aname.add_theme_color_override("font_color", Color("#e0f2fe"))
		aprice.add_theme_color_override("font_color", Color("#7dd3fc"))
		aicon.modulate = Color(1, 1, 1, 1.0)
	elif cash >= armor_cost:
		_style_button(abtn, Color("#1a1715"), Color("#292421"), Color("#38bdf8"), Color("#f5f5f4"))
		aname.add_theme_color_override("font_color", Color("#f5f5f4"))
		aprice.add_theme_color_override("font_color", Color("#7dd3fc"))
		aicon.modulate = Color(1, 1, 1, 1.0)
	else:
		_style_button(abtn, Color("#0d0b0a"), Color("#0d0b0a"), Color("#292524"), Color("#78716c"))
		aname.add_theme_color_override("font_color", Color("#78716c"))
		aprice.add_theme_color_override("font_color", Color("#78716c"))
		aicon.modulate = Color(0.55, 0.55, 0.55, 0.65)

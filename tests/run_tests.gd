extends SceneTree

## Headless GDScript test suite porting src/game/rules.test.ts + Godot scene, localization, icon, lighting & model tests

var _passed: int = 0
var _failed: int = 0
var _ran: bool = false

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		push_error("ASSERT FAILED: " + msg)
		print("[FAIL] " + msg)

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("=== CS-PROTOCOL Godot 4 Test Suite ===")

	_test_ak47_headshots()
	_test_awp_wallbang()
	_test_recoil_pattern()
	_test_dynamic_spread()
	_test_buy_economy()
	_test_horizontal_collision()
	_test_segment_aabb()
	_test_bot_utility_ai()
	_test_localization_vi_en()
	_test_weapon_icons()
	_test_admob_and_release_config()
	_test_touch_joycon_math_and_controls()
	_test_scene_lighting_models_and_match()

	print("=== RESULTS: %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
	return true

func _test_ak47_headshots() -> void:
	var unhelmeted := GameRules.calculate_ballistic_damage("ak47", GameTypes.HitRegion.HEAD, 15.0, 0.0, false, 0)
	_assert(int(unhelmeted["hp_damage"]) >= 100, "AK-47 unhelmeted headshot >= 100")
	_assert(bool(unhelmeted["is_headshot"]) == true, "AK-47 headshot flag true")

	var helmeted := GameRules.calculate_ballistic_damage("ak47", GameTypes.HitRegion.HEAD, 15.0, 100.0, true, 0)
	_assert(int(helmeted["hp_damage"]) >= 100, "AK-47 helmeted headshot >= 100")
	_assert(int(helmeted["armor_damage"]) > 0, "AK-47 damages armor on helmeted headshot")

func _test_awp_wallbang() -> void:
	var wb := GameRules.calculate_ballistic_damage("awp", GameTypes.HitRegion.CHEST, 25.0, 100.0, true, 1)
	_assert(int(wb["hp_damage"]) >= 80, "AWP wallbang chest damage >= 80")

func _test_recoil_pattern() -> void:
	var first := GameRules.get_recoil_for_shot("ak47", 0)
	var seventh := GameRules.get_recoil_for_shot("ak47", 6)
	_assert(seventh.y > first.y, "AK-47 7th shot pitch > 1st shot pitch")
	_assert(seventh.x != 0.0, "AK-47 7th shot yaw != 0")

func _test_dynamic_spread() -> void:
	var still := GameRules.compute_dynamic_spread("ak47", 0.0, true, false, false, 0.0)
	var running := GameRules.compute_dynamic_spread("ak47", 5.5, true, false, false, 0.0)
	var crouch := GameRules.compute_dynamic_spread("ak47", 0.0, true, true, false, 0.0)
	_assert(running > still, "Running spread > still spread")
	_assert(crouch < still, "Crouch spread < still spread")

	var awp_hip := GameRules.compute_dynamic_spread("awp", 0.0, true, false, false, 0.0)
	var awp_scoped := GameRules.compute_dynamic_spread("awp", 0.0, true, false, true, 0.0)
	_assert(awp_hip > awp_scoped * 10.0, "Unscoped AWP spread > 10x scoped spread")

func _test_buy_economy() -> void:
	var cant := GameRules.evaluate_purchase("awp", 2500, 0.0, false, 0, 0, "", "usps")
	_assert(bool(cant["ok"]) == false, "Cannot afford AWP with $2500")

	var can := GameRules.evaluate_purchase("ak47", 3000, 0.0, false, 0, 0, "", "usps")
	_assert(bool(can["ok"]) == true, "Can afford AK-47 with $3000")
	_assert(int(can["cost"]) == 2700, "AK-47 costs $2700")

func _test_horizontal_collision() -> void:
	var wall := {
		"id": "wall1",
		"min_x": 2.0,
		"max_x": 4.0,
		"min_y": 0.0,
		"max_y": 3.0,
		"min_z": -2.0,
		"max_z": 2.0,
		"material_type": "concrete",
		"penetrable": false,
	}
	var resolved := GameRules.resolve_horizontal_collision(Vector3(1.8, 0.0, 0.0), 0.45, 1.8, [wall])
	_assert(resolved.x <= 2.0 - 0.449, "Horizontal AABB pushes player outside wall")

func _test_segment_aabb() -> void:
	var crate := {
		"id": "crate",
		"min_x": -1.0,
		"max_x": 1.0,
		"min_y": 0.0,
		"max_y": 2.0,
		"min_z": 4.0,
		"max_z": 6.0,
		"material_type": "wood",
		"penetrable": true,
	}
	var hit := GameRules.intersect_segment_aabb(Vector3(0, 1, 0), Vector3(0, 1, 10), crate)
	_assert(hit > 0.35 and hit < 0.45, "Segment-AABB hits crate at t ~ 0.4")
	var miss := GameRules.intersect_segment_aabb(Vector3(3, 1, 0), Vector3(3, 1, 10), crate)
	_assert(miss < 0.0, "Segment-AABB misses crate when offset")

func _test_bot_utility_ai() -> void:
	var blinded := GameRules.evaluate_bot_next_state(100.0, 100.0, 20, 1.5, true, 10.0, 0.0, true, GameTypes.BotArchetype.ANCHOR, GameTypes.BotDifficulty.TACTICAL)
	_assert(blinded == GameTypes.BotAIState.BLINDED, "Bot transitions to BLINDED")

	var reload := GameRules.evaluate_bot_next_state(100.0, 100.0, 0, 0.0, true, 10.0, 0.0, true, GameTypes.BotArchetype.ENTRY, GameTypes.BotDifficulty.TACTICAL)
	_assert(reload == GameTypes.BotAIState.RELOAD, "Bot transitions to RELOAD")

	var cover := GameRules.evaluate_bot_next_state(20.0, 100.0, 15, 0.0, true, 12.0, 0.0, true, GameTypes.BotArchetype.ANCHOR, GameTypes.BotDifficulty.TACTICAL)
	_assert(cover == GameTypes.BotAIState.TAKE_COVER, "Wounded Anchor transitions to TAKE_COVER")

	var flank := GameRules.evaluate_bot_next_state(100.0, 100.0, 25, 0.0, false, 20.0, 1.5, true, GameTypes.BotArchetype.ENTRY, GameTypes.BotDifficulty.TACTICAL)
	_assert(flank == GameTypes.BotAIState.FLANK, "Entry bot hearing distant player transitions to FLANK")

func _test_localization_vi_en() -> void:
	Localization.set_language("vi")
	_assert(Localization.get_language() == "vi", "Localization switches to Vietnamese")
	_assert(Localization.tr_key("armory_title").find("VŨ KHÍ") >= 0, "Vietnamese armory title has Vietnamese diacritics")
	_assert(Localization.difficulty_label(GameTypes.BotDifficulty.ELITE) == "TINH NHUỆ", "Vietnamese elite difficulty translated")
	_assert(Localization.format_banner("banner_round_n", 3).find("HIỆP 3") >= 0, "Vietnamese round banner formats cleanly")

	Localization.set_language("en")
	_assert(Localization.get_language() == "en", "Localization switches to English")
	_assert(Localization.tr_key("armory_title") == "TACTICAL ARMORY", "English armory title matches")
	_assert(Localization.difficulty_label(GameTypes.BotDifficulty.ELITE) == "ELITE", "English elite difficulty matches")

	# Restore default Vietnamese
	Localization.set_language("vi")

func _test_weapon_icons() -> void:
	var ids: Array[String] = []
	for w in GameTypes.BUYABLE_WEAPON_IDS:
		ids.append(w)
	ids.append("kevlar_helmet")
	for item_id in ids:
		var tex := WeaponIcons.get_icon(item_id)
		_assert(tex != null and tex.get_width() >= 100 and tex.get_height() >= 40, "Weapon icon rendered for " + item_id)

func _test_admob_and_release_config() -> void:
	_assert(AppInfo.developer() == "vominhthongss", "AppInfo reads developer from project.godot")
	_assert(AppInfo.website() == "https://vominhthongss.github.io", "AppInfo reads website from project.godot")
	_assert(AppInfo.privacy_url() == "https://vominhthongss.github.io/cs-protocol/policy.html", "AppInfo builds privacy URL cleanly")
	_assert(AppInfo.version() == "1.0.0", "AppInfo reads app version")

	_assert(AdManagerNode.PROD_IDS.has("Android") and AdManagerNode.PROD_IDS.has("iOS"), "ad_manager defines Android & iOS PROD_IDS")
	_assert(String(AdManagerNode.PROD_IDS["Android"]["banner"]).begins_with("ca-app-pub-"), "Android banner unit ID configured")
	_assert(String(AdManagerNode.PROD_IDS["iOS"]["rewarded"]).begins_with("ca-app-pub-"), "iOS rewarded unit ID configured")
	_assert(AdManagerNode.use_test_ids() == true, "Debug build uses Google test Ad Unit IDs safely")

	# Verify snake_case lofi-garden naming + no leftover .env/AdConfig
	_assert(FileAccess.file_exists("res://scripts/autoload/ad_manager.gd"), "ad_manager.gd uses lofi-garden naming")
	_assert(FileAccess.file_exists("res://scripts/util/app_info.gd"), "app_info.gd uses lofi-garden naming")
	_assert(not FileAccess.file_exists("res://.env") and not FileAccess.file_exists("res://scripts/autoload/AdConfig.gd"), "No .env or AdConfig.gd left behind")

	# Verify baked PNG icons & store assets exist with required formats
	var required_files: Array[String] = [
		"res://assets/icons/icon_1024.png",
		"res://assets/icons/icon_192.png",
		"res://assets/icons/adaptive_foreground_432.png",
		"res://assets/icons/adaptive_background_432.png",
		"res://assets/icons/adaptive_monochrome_432.png",
		"res://assets/icons/ios_appstore_1024.png",
		"res://assets/icons/logo_splash.png",
		"res://store/play_store_icon_512.png",
		"res://store/feature_graphic_1024x500.png",
		"res://store/app-ads.txt",
		"res://addons/admob/plugin.cfg",
	]
	for fp in required_files:
		_assert(FileAccess.file_exists(fp), "Release asset exists: " + fp)

	var ios_icon := Image.load_from_file(ProjectSettings.globalize_path("res://assets/icons/ios_appstore_1024.png"))
	_assert(ios_icon != null and ios_icon.get_width() == 1024 and ios_icon.get_height() == 1024 and ios_icon.get_format() == Image.FORMAT_RGB8, "iOS App Store icon is 1024x1024 RGB8 (no alpha)")

	var presets_txt: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	_assert(presets_txt.find('platform="Android"') >= 0 and presets_txt.find('package/unique_name="com.vominhthongss.csprotocol"') >= 0, "Android Google Play preset configured")
	_assert(presets_txt.find('platform="iOS"') >= 0 and presets_txt.find('application/bundle_identifier="com.vominhthongss.csprotocol"') >= 0, "iOS App Store preset configured")
	_assert(presets_txt.find('platform="Web"') >= 0 and presets_txt.find('export_path="build/web/index.html"') >= 0, "Web export preset configured")
	_assert(presets_txt.find("touch-action: none") >= 0, "Web export preset disables browser touch scrolling/zooming")

func _test_touch_joycon_math_and_controls() -> void:
	# Deadzone & directional mapping tests
	var dead := TouchControls.compute_stick_vector(Vector2(5.0, -4.0), 74.0, 0.12)
	_assert(dead == Vector2.ZERO, "Joystick deadzone ignores micro-jitter")

	var up := TouchControls.compute_stick_vector(Vector2(0.0, -74.0), 74.0, 0.12)
	_assert(absf(up.x) < 0.001 and absf(up.y - 1.0) < 0.001, "Joystick upward drag maps to +1 forward")

	var right := TouchControls.compute_stick_vector(Vector2(74.0, 0.0), 74.0, 0.12)
	_assert(absf(right.x - 1.0) < 0.001 and absf(right.y) < 0.001, "Joystick rightward drag maps to +1 strafe right")

	var diag := TouchControls.compute_stick_vector(Vector2(150.0, -150.0), 108.0, 0.12)
	_assert(absf(diag.length() - 1.0) < 0.01, "Joystick diagonal magnitude clamps cleanly to 1.0")

	var clamped := TouchControls.clamp_knob_offset(Vector2(200.0, 0.0), 108.0)
	_assert(absf(clamped.length() - 108.0) < 0.01, "Joystick knob offset clamps to enlarged max radius")
	_assert(TouchControls.BASE_JOYSTICK_RADIUS >= 100.0, "Enlarged mobile joystick radius is comfortable for phone screens")

	# Touch mode persistence
	Localization.set_touch_mode("on")
	_assert(Localization.get_touch_mode() == "on", "Localization persists touch_mode = on")
	Localization.set_touch_mode("off")
	_assert(Localization.get_touch_mode() == "off", "Localization persists touch_mode = off")
	Localization.set_touch_mode("auto")
	_assert(Localization.get_touch_mode() == "auto", "Localization restores touch_mode = auto")

func _count_box_meshes(node: Node) -> int:
	var count: int = 0
	if node is MeshInstance3D and node.mesh is BoxMesh:
		count += 1
	for child in node.get_children():
		count += _count_box_meshes(child)
	return count

func _test_scene_lighting_models_and_match() -> void:
	var audio_mgr := TacticalAudioManager.new()
	audio_mgr.name = "TacticalAudio"
	root.add_child(audio_mgr)
	_assert(audio_mgr._streams.size() == 16, "All 16 procedural WAV sound effects synthesized")
	audio_mgr.set_ad_mute(true)
	_assert(audio_mgr._ad_muted == true, "TacticalAudio supports ad mute")
	audio_mgr.set_ad_mute(false)

	var ad_mgr := AdManagerNode.new()
	ad_mgr.name = "AdManager"
	root.add_child(ad_mgr)
	_assert(ad_mgr.ads_enabled_for_user() == true, "AdManager active by default")
	_assert(ad_mgr.maybe_show_interstitial("test") == false, "Interstitial safely skipped on headless/desktop")

	var packed: PackedScene = load("res://scenes/Main.tscn")
	_assert(packed != null, "Main.tscn loads cleanly")
	if packed == null:
		return

	var main_node := packed.instantiate() as FpsGameController
	_assert(main_node != null, "Main.tscn instantiates FpsGameController")
	root.add_child(main_node)

	# Verify realistic non-glaring sky & lighting setup
	var arena := main_node.get_node_or_null("Arena")
	_assert(arena != null, "Arena built")
	var we := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := arena.get_node_or_null("SunLight") as DirectionalLight3D
	_assert(we != null and we.environment.background_mode == Environment.BG_SKY, "Arena uses natural ProceduralSkyMaterial background")
	_assert(we != null and we.environment.tonemap_exposure <= 0.95, "Arena exposure balanced to prevent glare")
	_assert(sun != null and sun.light_energy <= 1.25 and sun.shadow_enabled, "Sun light energy realistic with shadows enabled")

	# Verify all 10 viewmodels & bots use smooth rounded meshes (zero sharp raw BoxMesh primitives)
	_assert(main_node.view_models.size() == 10, "All 10 procedural weapon viewmodels built")
	var vm_box_count: int = 0
	for wid in main_node.view_models.keys():
		vm_box_count += _count_box_meshes(main_node.view_models[wid]["root"])
	_assert(vm_box_count == 0, "All 10 weapon viewmodels use smooth rounded/curved meshes (0 raw BoxMesh)")

	_assert(main_node.bots.size() == 4, "Default 4 tactical bots spawned")
	var bot_box_count: int = 0
	for b in main_node.bots:
		bot_box_count += _count_box_meshes(b["rig"]["root"])
	_assert(bot_box_count == 0, "All bot rigs use smooth rounded/curved meshes (0 raw BoxMesh)")

	# Verify UI language switch + Buy Menu icons
	var ui := main_node.get_node_or_null("GameUI") as GameUI
	_assert(ui != null, "GameUI attached")
	if ui != null:
		_assert(ui._buy_cards.size() == GameTypes.BUYABLE_WEAPON_IDS.size(), "Buy menu has visual card for every buyable weapon")
		_assert(ui._buy_ad_bonus_btn != null and ui._title_privacy_btn != null and ui._pause_privacy_btn != null, "Ad bonus and privacy buttons wired into GameUI")
		ui.set_language("en")
		_assert(ui._buy_title_lbl.text == "TACTICAL ARMORY", "GameUI live-switches to English")
		_assert(ui._buy_ad_bonus_btn.text.find("+$1500") >= 0, "Ad bonus button localized in English")
		ui.set_language("vi")
		_assert(ui._buy_title_lbl.text.find("VŨ KHÍ") >= 0, "GameUI live-switches to Vietnamese")
		_assert(ui._title_privacy_btn.text.find("BẢO MẬT") >= 0, "Privacy button localized in Vietnamese")

	main_node.start_new_match(GameTypes.BotDifficulty.ELITE, 5)
	_assert(main_node.phase == GameTypes.GamePhase.PLAYING, "Match transitions to PLAYING")
	_assert(main_node.bots.size() == 5, "Elite match spawns 5 bots")

	var buy_res := main_node.buy_item("ak47")
	_assert(bool(buy_res["ok"]) == true, "Buying AK-47 succeeds with starting $3500")
	_assert(main_node.player_cash == 800, "Cash deducted to $800 after AK-47 purchase")
	_assert(main_node.get_active_weapon_id() == "ak47", "Active weapon switched to AK-47")

	if ui != null:
		ui._request_ad_bonus_cash()
		_assert(main_node.player_cash == 2300, "Rewarded ad bonus grants +$1500 cash")

	for _step in range(10):
		main_node.step_simulation(0.016)

	var snap := main_node.get_hud_snapshot()
	_assert(int(snap["bots_alive"]) == 5, "HUD snapshot reports 5 bots alive")
	_assert(String(snap["active_weapon_id"]) == "ak47", "HUD snapshot reports AK-47 active")

	# Verify Touch Joycon integration & HUD layout adaptation
	if ui != null:
		ui.set_touch_mode("on")
		_assert(ui.is_touch_controls_active() == true, "GameUI activates touch joycon when mode is ON")
		_assert(ui._touch_controls != null and ui._touch_controls.visible == true, "TouchControls overlay visible during PLAYING")
		_assert(ui._pointer_hint.visible == false, "Desktop pointer lock hint hidden in touch mode")
		_assert(ui._vit_panel.anchor_top == 0.0, "Vitals panel repositions clear of left joycon in touch mode")

		# Verify desktop keyboard hints ([B], [Esc], [1]..[5], RMB) are hidden in mobile/touch mode
		_assert(ui._hud_buy_btn.text.find("[B]") == -1, "HUD buy button hides [B] shortcut in touch mode")
		_assert(ui._cash_btn.text.find("[B]") == -1, "HUD cash button hides [B] shortcut in touch mode")
		_assert(ui._buy_footer_lbl.text.find("[B]") == -1 and ui._buy_footer_lbl.text.find("[Esc]") == -1, "Buy footer hides desktop key hints in touch mode")
		_assert(ui._slot_buttons[1].text.find("[1]") == -1, "Weapon slot buttons hide [1]-[5] key prefixes in touch mode")
		ui._refresh_buy_menu(main_node.get_hud_snapshot())
		var awp_hint_touch: String = ui._buy_cards["awp"]["hint_lbl"].text
		_assert(awp_hint_touch.find("RMB") == -1 and awp_hint_touch.find("Chuột phải") == -1, "AWP buy hint hides mouse button mention in touch mode")

		# Verify enlarged mobile buttons & simultaneous multi-touch move + look without interference
		var tc: TouchControls = ui._touch_controls
		tc._recompute_layout()
		_assert(float(tc._buttons["fire"]["radius"]) >= 68.0, "Fire touch button enlarged for mobile screens")
		_assert(float(tc._buttons["jump"]["radius"]) >= 42.0, "Action touch buttons enlarged for mobile screens")

		var mt_yaw_before: float = main_node.player_yaw
		var mt_ammo_before: int = int(main_node.slots[1]["ammo_in_mag"])

		# Finger 0 presses left joystick & drags forward
		var f0_down := InputEventScreenTouch.new()
		f0_down.index = 0
		f0_down.position = Vector2(160.0, 560.0)
		f0_down.pressed = true
		tc._input(f0_down)
		var f0_drag := InputEventScreenDrag.new()
		f0_drag.index = 0
		f0_drag.position = Vector2(160.0, 470.0)
		tc._input(f0_drag)
		_assert(tc._move_finger == 0 and main_node._virtual_move.y > 0.5, "Finger 0 drives left joystick movement")

		# Finger 1 presses right look pad & drags horizontally while Finger 0 stays active
		var f1_down := InputEventScreenTouch.new()
		f1_down.index = 1
		f1_down.position = Vector2(820.0, 340.0)
		f1_down.pressed = true
		tc._input(f1_down)
		var f1_drag := InputEventScreenDrag.new()
		f1_drag.index = 1
		f1_drag.position = Vector2(880.0, 340.0)
		f1_drag.relative = Vector2(-500.0, 400.0) # Deliberately bogus relative to confirm manual per-finger tracking
		tc._input(f1_drag)
		_assert(tc._move_finger == 0 and tc._look_finger == 1, "Simultaneous multi-touch tracks move (0) and look (1) independently")
		_assert(main_node.player_yaw < mt_yaw_before - 0.15, "Right-side drag rotates camera using per-finger delta (ignoring bogus event.relative)")

		# Finger 2 touching left side must NOT hijack look finger
		var f2_left := InputEventScreenTouch.new()
		f2_left.index = 2
		f2_left.position = Vector2(300.0, 500.0)
		f2_left.pressed = true
		tc._input(f2_left)
		_assert(tc._look_finger == 1 and tc._move_finger == 0, "Extra left-zone touch never hijacks move or look fingers")

		# Synthetic mobile mouse click/motion must NOT fire or spin camera in touch mode
		var synth_click := InputEventMouseButton.new()
		synth_click.button_index = MOUSE_BUTTON_LEFT
		synth_click.pressed = true
		synth_click.position = Vector2(700.0, 300.0)
		tc._input(synth_click)
		main_node._unhandled_input(synth_click)
		main_node.step_simulation(0.016)
		_assert(main_node._mouse_down == false and int(main_node.slots[1]["ammo_in_mag"]) == mt_ammo_before, "Synthetic mouse click blocked during touch mode")

		# Release fingers cleanly
		var f0_up := InputEventScreenTouch.new()
		f0_up.index = 0
		f0_up.pressed = false
		tc._input(f0_up)
		var f1_up := InputEventScreenTouch.new()
		f1_up.index = 1
		f1_up.pressed = false
		tc._input(f1_up)
		_assert(tc._move_finger == -1 and tc._look_finger == -1 and main_node._virtual_move == Vector2.ZERO, "Releasing multi-touch fingers resets movement and look cleanly")

		var start_pos: Vector3 = main_node.player_pos
		var start_yaw: float = main_node.player_yaw
		var ammo_before: int = int(main_node.slots[1]["ammo_in_mag"])

		main_node.set_virtual_move(Vector2(0.0, 1.0))
		main_node.apply_virtual_look(Vector2(50.0, -20.0))
		main_node.set_virtual_crouch(true)
		main_node.set_virtual_fire(true)
		for _tstep in range(8):
			main_node.step_simulation(0.016)
		main_node.set_virtual_fire(false)

		_assert(main_node.player_pos.distance_to(start_pos) > 0.05, "Virtual joycon movement moves player")
		_assert(absf(main_node.player_yaw - start_yaw) > 0.05, "Virtual touch drag rotates player yaw")
		_assert(int(main_node.slots[1]["ammo_in_mag"]) < ammo_before, "Virtual fire button fires weapon")
		_assert(bool(main_node.get_hud_snapshot()["is_crouching"]) == true, "Virtual crouch updates HUD snapshot")

		main_node.trigger_virtual_reload()
		_assert(main_node.is_reloading == true, "Virtual reload starts reloading")

		main_node.set_virtual_crouch(false)
		main_node.trigger_virtual_jump()
		main_node.step_simulation(0.016)
		_assert(main_node.player_grounded == false, "Virtual jump launches player off ground")

		var he_before: int = main_node.he_count
		main_node.trigger_virtual_grenade("he_grenade")
		_assert(main_node.he_count == he_before - 1, "Virtual grenade button throws HE grenade")

		ui._set_buy_open(true)
		_assert(ui._touch_controls.visible == false, "TouchControls hides when Buy Menu opens")
		_assert(main_node._virtual_move == Vector2.ZERO, "Buy Menu resets virtual joycon move input")
		ui._set_buy_open(false)
		_assert(ui._touch_controls.visible == true, "TouchControls re-appears when Buy Menu closes")

		ui.set_touch_mode("off")
		_assert(ui.is_touch_controls_active() == false, "GameUI disables touch joycon when mode is OFF")
		_assert(ui._vit_panel.anchor_top == 1.0, "Vitals panel restores desktop bottom-left anchor")
		_assert(ui._hud_buy_btn.text.find("[B]") >= 0, "HUD buy button restores [B] shortcut on desktop")
		_assert(ui._cash_btn.text.find("[B]") >= 0, "HUD cash button restores [B] shortcut on desktop")
		_assert(ui._slot_buttons[1].text.find("[1]") >= 0, "Weapon slot buttons restore [1]-[5] shortcuts on desktop")
		ui.set_touch_mode("auto")

	# Verify crouching before firing works (including macOS Ctrl+Click remapped to MOUSE_BUTTON_RIGHT)
	main_node.start_new_match(GameTypes.BotDifficulty.TACTICAL, 3)
	main_node.set_touch_controls_enabled(false)
	main_node._macos_checked = true
	main_node._is_macos_cached = true
	main_node.set_virtual_crouch(true)
	var ammo_crouch_before: int = int(main_node.slots[1]["ammo_in_mag"])

	var ctrl_click_down := InputEventMouseButton.new()
	ctrl_click_down.button_index = MOUSE_BUTTON_RIGHT
	ctrl_click_down.ctrl_pressed = true
	ctrl_click_down.pressed = true
	main_node._unhandled_input(ctrl_click_down)
	main_node.step_simulation(0.016)
	_assert(main_node._mouse_down == true, "macOS Ctrl+Click while crouched sets _mouse_down = true")
	_assert(int(main_node.slots[1]["ammo_in_mag"]) < ammo_crouch_before, "Crouching with Ctrl before clicking fires weapon")

	var ctrl_click_up := InputEventMouseButton.new()
	ctrl_click_up.button_index = MOUSE_BUTTON_RIGHT
	ctrl_click_up.ctrl_pressed = true
	ctrl_click_up.pressed = false
	main_node._unhandled_input(ctrl_click_up)
	_assert(main_node._mouse_down == false, "Releasing macOS Ctrl+Click clears _mouse_down cleanly")

	# Verify genuine Right-Click without Ctrl still scopes AWP while crouched (e.g., via C key)
	main_node.player_cash = 5000
	main_node.buy_item("awp")
	var rmb_scope := InputEventMouseButton.new()
	rmb_scope.button_index = MOUSE_BUTTON_RIGHT
	rmb_scope.ctrl_pressed = false
	rmb_scope.pressed = true
	main_node._unhandled_input(rmb_scope)
	_assert(main_node.is_scoped == true, "Right-click without Ctrl while crouched still toggles AWP scope")

	# Verify no stuck _mouse_down if LMB was pressed then released via RMB
	var lmb_down := InputEventMouseButton.new()
	lmb_down.button_index = MOUSE_BUTTON_LEFT
	lmb_down.pressed = true
	main_node._unhandled_input(lmb_down)
	var rmb_up := InputEventMouseButton.new()
	rmb_up.button_index = MOUSE_BUTTON_RIGHT
	rmb_up.pressed = false
	main_node._unhandled_input(rmb_up)
	_assert(main_node._mouse_down == false, "Releasing RMB after LMB-then-Ctrl does not leave _mouse_down stuck")

	main_node.free()
	ad_mgr.free()
	audio_mgr.free()

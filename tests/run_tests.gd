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
		ui.set_language("en")
		_assert(ui._buy_title_lbl.text == "TACTICAL ARMORY", "GameUI live-switches to English")
		ui.set_language("vi")
		_assert(ui._buy_title_lbl.text.find("VŨ KHÍ") >= 0, "GameUI live-switches to Vietnamese")

	main_node.start_new_match(GameTypes.BotDifficulty.ELITE, 5)
	_assert(main_node.phase == GameTypes.GamePhase.PLAYING, "Match transitions to PLAYING")
	_assert(main_node.bots.size() == 5, "Elite match spawns 5 bots")

	var buy_res := main_node.buy_item("ak47")
	_assert(bool(buy_res["ok"]) == true, "Buying AK-47 succeeds with starting $3500")
	_assert(main_node.player_cash == 800, "Cash deducted to $800 after AK-47 purchase")
	_assert(main_node.get_active_weapon_id() == "ak47", "Active weapon switched to AK-47")

	for _step in range(10):
		main_node.step_simulation(0.016)

	var snap := main_node.get_hud_snapshot()
	_assert(int(snap["bots_alive"]) == 5, "HUD snapshot reports 5 bots alive")
	_assert(String(snap["active_weapon_id"]) == "ak47", "HUD snapshot reports AK-47 active")

	main_node.free()
	audio_mgr.free()

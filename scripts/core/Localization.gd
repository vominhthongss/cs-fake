class_name Localization
extends RefCounted

## Bilingual Vietnamese (vi) & English (en) string manager

const SETTINGS_PATH: String = "user://settings.cfg"

static var current_lang: String = "vi"
static var touch_mode: String = "auto"
static var _loaded: bool = false

const STRINGS: Dictionary = {
	"en": {
		"title_sub": "DUST SECTOR // BOT OPS · GODOT 4 EDITION",
		"bot_ai_tier": "BOT AI TIER",
		"diff_recruit": "RECRUIT",
		"diff_tactical": "TACTICAL",
		"diff_elite": "ELITE",
		"hostile_squad": "HOSTILE SQUAD",
		"bots_count": "%d BOTS",
		"language_label": "LANGUAGE",
		"deploy_match": "▶  DEPLOY MATCH",
		"title_features": "8 CS-Class Weapons · Ballistic Penetration · Utility AI Bots",
		"controls_hint": "WASD Move · Mouse / Arrows Aim · LMB Fire · RMB Scope · 1-5 Weapons · G/F Grenades · B Buy · Esc Pause",
		"radar": "RADAR",
		"bots_alive": "%d/%d BOTS",
		"you": "YOU",
		"bot": "BOT",
		"bot_squad": "BOT SQUAD",
		"round_short": "R%d/%d",
		"buy_btn": "BUY [B]",
		"sfx_on": "SFX ON",
		"muted": "MUTED",
		"pause_btn": "PAUSE",
		"hp": "HP",
		"kevlar_plus": "KEVLAR+",
		"armor": "ARMOR",
		"melee": "MELEE",
		"slot_knife": "KNIFE",
		"slot_he": "HE",
		"slot_flash": "FLASH",
		"weapon_rifle": "RIFLE",
		"weapon_he_frag": "HE FRAG",
		"pointer_hint": "Click Arena to Lock Mouse · Arrows to Look · B to Buy",
		"armory_title": "TACTICAL ARMORY",
		"armory_sub": "Purchase Rifles, SMGs, Sniper, Sidearms, Grenades & Armor",
		"armory_footer": "Press [B] or [Esc] to return to combat",
		"done": "DONE",
		"equipped": "EQUIPPED",
		"full": "FULL",
		"stat_dmg_mag": "DMG %d · MAG %d",
		"stat_grenade": "RADIUS %dm · UTILITY",
		"kevlar_helmet_title": "KEVLAR + HELMET",
		"kevlar_helmet_desc": "Reduces torso & headshot damage",
		"pause_sub": "TACTICAL PAUSE",
		"pause_title": "MATCH PAUSED",
		"score": "SCORE",
		"kills": "KILLS",
		"accuracy": "ACCURACY",
		"resume_match": "RESUME MATCH",
		"restart_match": "RESTART MATCH",
		"main_menu": "MAIN MENU",
		"mission_accomplished": "MISSION ACCOMPLISHED",
		"squad_eliminated": "SQUAD ELIMINATED",
		"match_victory": "MATCH VICTORY",
		"defeat": "DEFEAT",
		"final_summary": "Final Score %d – %d · Difficulty: %s",
		"eliminations": "ELIMINATIONS",
		"headshots": "HEADSHOTS",
		"total_damage": "TOTAL DAMAGE",
		"play_again": "PLAY AGAIN",
		"try_again": "TRY AGAIN",
		"banner_round_1": "ROUND 1 · ELIMINATE HOSTILES",
		"banner_round_n": "ROUND %d · DEPLOY",
		"banner_round_won": "ROUND WON · ALL HOSTILES ELIMINATED",
		"banner_round_lost": "ROUND LOST · REGROUPING",
		"hint_ak47": "1-Tap Headshot · Heavy 7-Pattern",
		"hint_m4a1s": "Suppressed Precision · Tight Spray",
		"hint_awp": "RMB Scope · 1-Shot Torso/Head",
		"hint_p90": "50-Rd Rush SMG · High Mobility",
		"hint_nova": "8-Pellet Buckshot · $900 Kill Bonus",
		"hint_deagle": ".50 AE Hand Cannon · 1-Tap Head",
		"hint_usps": "Silenced Sidearm · Crisp Accuracy",
		"hint_karambit": "+15% Sprint Speed · $1500 Bonus",
		"hint_he_grenade": "Bouncing Frag · Radial Blast",
		"hint_flashbang": "Tactical Blind · Stuns Bots",
		"name_he_grenade": "HE Grenade",
		"name_flashbang": "Flashbang",
		"name_karambit": "Karambit",
		"ad_bonus_cash_btn": "WATCH AD · +$1500",
		"ad_bonus_granted": "+$1500 TACTICAL SUPPLY GRANTED",
		"ad_simulated": "SIMULATED AD (DEBUG MODE)...",
		"ad_loading": "Loading ad, please try again...",
		"ad_not_ready": "Ads are not available on this platform",
		"privacy_policy_btn": "PRIVACY POLICY",
		"ad_privacy_btn": "AD PRIVACY OPTIONS",
		"ad_privacy_mobile_only": "Ad privacy options are only available on mobile",
		"ad_privacy_failed": "Unable to open ad privacy options right now",
		"touch_controls_label": "TOUCH JOYCON",
		"touch_mode_auto": "AUTO",
		"touch_mode_on": "ON",
		"touch_mode_off": "OFF",
		"touch_fire": "FIRE",
		"touch_jump": "JUMP",
		"touch_crouch": "CROUCH",
		"touch_reload": "RELOAD",
		"touch_scope": "SCOPE",
		"touch_he": "HE",
		"touch_flash": "FLASH",
		"controls_hint_touch": "Left Joycon Move · Right Drag Aim · Hold Fire & Drag to Track · Tap 1-5 Weapons · Tap BUY/PAUSE",
	},
	"vi": {
		"title_sub": "KHU VỰC SA MẠC // TÁC CHIẾN BOT · BẢN GODOT 4",
		"bot_ai_tier": "ĐỘ KHÓ BOT AI",
		"diff_recruit": "TÂN BINH",
		"diff_tactical": "CHIẾN THUẬT",
		"diff_elite": "TINH NHUỆ",
		"hostile_squad": "QUÂN SỐ ĐỊCH",
		"bots_count": "%d BOT",
		"language_label": "NGÔN NGỮ",
		"deploy_match": "▶  BẮT ĐẦU TRẬN ĐẤU",
		"title_features": "8 Vũ Khí Chuẩn CS · Bắn Xuyên Tường · Bot AI Chiến Thuật",
		"controls_hint": "WASD Di chuyển · Chuột/Mũi tên Ngắm · Trái Bắn · Phải Ống ngắm · 1-5 Đổi súng · G/F Lựu đạn · B Mua đồ · Esc Tạm dừng",
		"radar": "RA-ĐA",
		"bots_alive": "%d/%d BOT",
		"you": "BẠN",
		"bot": "BOT",
		"bot_squad": "ĐỘI BOT",
		"round_short": "HIỆP %d/%d",
		"buy_btn": "MUA [B]",
		"sfx_on": "ÂM: BẬT",
		"muted": "ÂM: TẮT",
		"pause_btn": "TẠM DỪNG",
		"hp": "MÁU",
		"kevlar_plus": "GIÁP+MŨ",
		"armor": "GIÁP",
		"melee": "CẬN CHIẾN",
		"slot_knife": "DAO",
		"slot_he": "LỰU NỔ",
		"slot_flash": "CHOÁNG",
		"weapon_rifle": "SÚNG TRƯỜNG",
		"weapon_he_frag": "LỰU NỔ",
		"pointer_hint": "Nhấn vào màn hình để khóa chuột · Mũi tên để xoay · B để mua đồ",
		"armory_title": "KHO VŨ KHÍ CHIẾN THUẬT",
		"armory_sub": "Mua Súng Trường, Tiểu Liên, Bắn Tỉa, Súng Lục, Lựu Đạn & Giáp",
		"armory_footer": "Nhấn [B] hoặc [Esc] để quay lại chiến đấu",
		"done": "XONG",
		"equipped": "ĐANG DÙNG",
		"full": "ĐẦY GIÁP",
		"stat_dmg_mag": "SÁT THƯƠNG %d · BĂNG %d",
		"stat_grenade": "BÁN KÍNH %dm · CHIẾN THUẬT",
		"kevlar_helmet_title": "GIÁP KEVLAR + MŨ",
		"kevlar_helmet_desc": "Giảm sát thương thân & đầu",
		"pause_sub": "TẠM DỪNG CHIẾN THUẬT",
		"pause_title": "ĐANG TẠM DỪNG",
		"score": "TỈ SỐ",
		"kills": "HẠ GỤC",
		"accuracy": "CHÍNH XÁC",
		"resume_match": "TIẾP TỤC TRẬN ĐẤU",
		"restart_match": "CHƠI LẠI TỪ ĐẦU",
		"main_menu": "MENU CHÍNH",
		"mission_accomplished": "HOÀN THÀNH NHIỆM VỤ",
		"squad_eliminated": "BẠN ĐÃ BỊ HẠ GỤC",
		"match_victory": "CHIẾN THẮNG",
		"defeat": "THẤT BẠI",
		"final_summary": "Tỉ số chung cuộc %d – %d · Độ khó: %s",
		"eliminations": "MẠNG HẠ GỤC",
		"headshots": "BẮN TRÚNG ĐẦU",
		"total_damage": "TỔNG SÁT THƯƠNG",
		"play_again": "CHƠI LẠI",
		"try_again": "THỬ LẠI",
		"banner_round_1": "HIỆP 1 · TIÊU DIỆT TOÀN BỘ ĐỊCH",
		"banner_round_n": "HIỆP %d · TRIỂN KHAI",
		"banner_round_won": "THẮNG HIỆP · ĐÃ HẠ TOÀN BỘ ĐỊCH",
		"banner_round_lost": "THUA HIỆP · CHUẨN BỊ HIỆP MỚI",
		"hint_ak47": "1 viên trúng đầu · Giật mạnh hình số 7",
		"hint_m4a1s": "Giảm thanh chuẩn xác · Đạn chụm ổn định",
		"hint_awp": "Chuột phải ngắm · 1 viên hạ ngực/đầu",
		"hint_p90": "Tiểu liên 50 viên · Cơ động cực cao",
		"hint_nova": "8 viên đạn ghém · Thưởng $900/mạng",
		"hint_deagle": "Súng lục hạng nặng · 1 viên trúng đầu",
		"hint_usps": "Súng phụ giảm thanh · Độ chính xác cao",
		"hint_karambit": "+15% tốc chạy · Thưởng $1500/mạng",
		"hint_he_grenade": "Lựu đạn nảy tường · Nổ sát thương vùng",
		"hint_flashbang": "Gây chói chiến thuật · Làm mù Bot địch",
		"name_he_grenade": "Lựu Đạn Nổ",
		"name_flashbang": "Lựu Đạn Choáng",
		"name_karambit": "Dao Karambit",
		"ad_bonus_cash_btn": "XEM QC · +$1500",
		"ad_bonus_granted": "ĐÃ NHẬN +$1500 TIẾP TẾ CHIẾN THUẬT",
		"ad_simulated": "QUẢNG CÁO GIẢ LẬP (CHẾ ĐỘ DEBUG)...",
		"ad_loading": "Đang tải quảng cáo, vui lòng thử lại...",
		"ad_not_ready": "Quảng cáo chưa sẵn sàng trên nền tảng này",
		"privacy_policy_btn": "CHÍNH SÁCH BẢO MẬT",
		"ad_privacy_btn": "TÙY CHỌN QUẢNG CÁO",
		"ad_privacy_mobile_only": "Tùy chọn quảng cáo chỉ khả dụng trên điện thoại",
		"ad_privacy_failed": "Không mở được tùy chọn quảng cáo lúc này",
		"touch_controls_label": "TAY CẦM CẢM ỨNG",
		"touch_mode_auto": "TỰ ĐỘNG",
		"touch_mode_on": "BẬT",
		"touch_mode_off": "TẮT",
		"touch_fire": "BẮN",
		"touch_jump": "NHẢY",
		"touch_crouch": "NGỒI",
		"touch_reload": "NẠP",
		"touch_scope": "NGẮM",
		"touch_he": "NỔ",
		"touch_flash": "CHÓI",
		"controls_hint_touch": "Joycon trái Di chuyển · Vuốt phải Ngắm · Giữ Bắn + Kéo để lia tâm · Chạm 1-5 Đổi súng",
	},
}

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var saved: String = String(cfg.get_value("ui", "language", current_lang))
		if STRINGS.has(saved):
			current_lang = saved
		var saved_touch: String = String(cfg.get_value("input", "touch_mode", touch_mode))
		if saved_touch in ["auto", "on", "off"]:
			touch_mode = saved_touch

static func set_language(lang: String) -> void:
	if not STRINGS.has(lang):
		return
	ensure_loaded()
	current_lang = lang
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "language", lang)
	cfg.set_value("input", "touch_mode", touch_mode)
	cfg.save(SETTINGS_PATH)

static func get_language() -> String:
	ensure_loaded()
	return current_lang

static func set_touch_mode(mode: String) -> void:
	if not (mode in ["auto", "on", "off"]):
		return
	ensure_loaded()
	touch_mode = mode
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "language", current_lang)
	cfg.set_value("input", "touch_mode", mode)
	cfg.save(SETTINGS_PATH)

static func get_touch_mode() -> String:
	ensure_loaded()
	return touch_mode

static func tr_key(key: String) -> String:
	ensure_loaded()
	var table: Dictionary = STRINGS.get(current_lang, STRINGS["en"])
	if table.has(key):
		return String(table[key])
	return String(STRINGS["en"].get(key, key))

static func difficulty_label(diff: GameTypes.BotDifficulty) -> String:
	match diff:
		GameTypes.BotDifficulty.RECRUIT:
			return tr_key("diff_recruit")
		GameTypes.BotDifficulty.TACTICAL:
			return tr_key("diff_tactical")
		GameTypes.BotDifficulty.ELITE:
			return tr_key("diff_elite")
	return tr_key("diff_tactical")

static func weapon_display_name(weapon_id: String) -> String:
	var key := "name_" + weapon_id
	var table: Dictionary = STRINGS.get(get_language(), STRINGS["en"])
	if table.has(key):
		return String(table[key])
	if GameTypes.WEAPONS.has(weapon_id):
		return String(GameTypes.WEAPONS[weapon_id]["name"])
	return weapon_id.to_upper()

static func weapon_role_hint(weapon_id: String) -> String:
	var key := "hint_" + weapon_id
	return tr_key(key)

static func format_banner(banner_key: String, banner_arg: int) -> String:
	if banner_key.is_empty():
		return ""
	if banner_key == "banner_round_n":
		return tr_key("banner_round_n") % banner_arg
	return tr_key(banner_key)

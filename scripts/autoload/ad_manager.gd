class_name AdManagerNode
extends Node

## Lớp bọc Google AdMob (plugin "AdMob" của Poing Studios v5.1.0, Godot 4.5+; nằm ở addons/admob).
##
## Thiết kế (theo chuẩn lofi-garden):
## - KHÔNG tham chiếu trực tiếp class của plugin => project vẫn chạy/biên dịch sạch
##   khi chưa cài plugin hoặc bản Web (bỏ addons/). Các class được nạp động qua global class list.
## - Chưa có plugin + bản debug: giả lập quảng cáo để test luồng thưởng.
## - Quảng cáo phù hợp game FPS chiến thuật:
##     * Rewarded (người chơi tự chọn bấm): nhận tiếp tế +$1500 trong Kho Vũ Khí (Buy Menu).
##     * Interstitial: chỉ ở điểm dừng tự nhiên sau thao tác người chơi (Chơi lại / Về menu từ Game Over),
##       giới hạn tần suất chặt (3 phút đầu không hiện, cách nhau >= 4 phút, tối đa 6 lần/phiên).
##     * Banner: chỉ ở màn hình chính (Title), ẩn hoàn toàn khi vào trận (PLAYING) để không che HUD/ngắm bắn.
## - Xin consent (UMP / GDPR) trước khi khởi tạo SDK.

signal rewarded_finished(tag: String, earned: bool)
signal status_message(message: String)

## ID quảng cáo test hay thật: tự chọn theo loại bản build (xem use_test_ids()).
##   - Chạy trong editor / bản export có tick "Export With Debug" -> quảng cáo TEST (an toàn khi tự chơi thử,
##     bấm nhầm không sao; AdMob có thể khóa tài khoản nếu bấm quảng cáo thật của chính mình).
##   - Bản export release (bỏ tick "Export With Debug", bản nộp store) -> quảng cáo THẬT trong PROD_IDS.
## Muốn bản release vẫn chạy quảng cáo test (vd gửi bạn bè thử qua TestFlight / thử nghiệm kín) thì đổi thành true.
const FORCE_TEST_IDS: bool = false
const BANNER_ENABLED: bool = true
const BANNER_GAP: float = 24.0
const BANNER_FALLBACK_DP: Vector2 = Vector2(320, 50)
const SIMULATE_BANNER_IN_DEBUG: bool = false
## Mức nội dung quảng cáo cao nhất được phép: "G", "PG", "T" (thiếu niên — hợp FPS chiến thuật), "MA".
const MAX_AD_CONTENT_RATING: String = "T"
const INTERSTITIAL_MIN_INTERVAL: float = 240.0 # giây giữa 2 lần interstitial
const INTERSTITIAL_SESSION_GRACE: float = 180.0 # 3 phút đầu phiên không hiện interstitial
const INTERSTITIAL_MAX_PER_SESSION: int = 6

const SETTINGS_PATH: String = "user://settings.cfg"

const TEST_IDS: Dictionary = {
	"Android": {
		"banner": "ca-app-pub-3940256099942544/6300978111",
		"interstitial": "ca-app-pub-3940256099942544/1033173712",
		"rewarded": "ca-app-pub-3940256099942544/5224354917",
	},
	"iOS": {
		"banner": "ca-app-pub-3940256099942544/2934735716",
		"interstitial": "ca-app-pub-3940256099942544/4411468910",
		"rewarded": "ca-app-pub-3940256099942544/1712485313",
	},
}

## Ad Unit ID thật trong AdMob console (bản release dùng bảng này).
## Hiện đang để tạm Google Test ID để không bị lỗi khi thử; thay bằng ID thật của CS-PROTOCOL trước khi nộp Store!
const PROD_IDS: Dictionary = {
	"Android": {
		"banner": "ca-app-pub-3940256099942544/6300978111",
		"interstitial": "ca-app-pub-3940256099942544/1033173712",
		"rewarded": "ca-app-pub-3940256099942544/5224354917",
	},
	"iOS": {
		"banner": "ca-app-pub-3940256099942544/2934735716",
		"interstitial": "ca-app-pub-3940256099942544/4411468910",
		"rewarded": "ca-app-pub-3940256099942544/1712485313",
	},
}


## true = dùng TEST_IDS. Bản debug (editor, "Export With Debug") luôn dùng quảng cáo test.
static func use_test_ids() -> bool:
	return FORCE_TEST_IDS or OS.is_debug_build()


var ads_removed: bool = false
var _classes: Dictionary = {}
var _plugin_ok: bool = false
var _initialized: bool = false
var _sdk_ready: bool = false
var _interstitial: Variant = null
var _rewarded: Variant = null
var _banner: Variant = null
var _banner_wanted: bool = false
var _loading_interstitial: bool = false
var _loading_rewarded: bool = false
var _reward_tag: String = ""
var _reward_earned: bool = false
var _reward_callback: Callable = Callable()
var _session_start: float = 0.0
var _last_interstitial: float = -99999.0
var _interstitial_count: int = 0
var _consent_form: Variant = null
var _keep_alive: Array = []
var _banner_dp: Vector2 = Vector2.ZERO
var _fake_banner: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_saved_flags()
	_session_start = _t()
	_plugin_ok = _detect_plugin()
	if _plugin_ok:
		_request_consent()
	else:
		if DisplayServer.get_name() != "headless":
			print("[AdManager] Chưa có plugin AdMob hoặc không chạy trên mobile -> chế độ giả lập.")


func _load_saved_flags() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		ads_removed = bool(cfg.get_value("ads", "removed", false))


func _t() -> float:
	return Time.get_ticks_msec() / 1000.0


func _audio() -> TacticalAudioManager:
	return get_node_or_null("/root/TacticalAudio") as TacticalAudioManager


func _set_ad_audio_mute(muted_for_ad: bool) -> void:
	var a := _audio()
	if a != null:
		a.set_ad_mute(muted_for_ad)


func _detect_plugin() -> bool:
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return false
	for c in ProjectSettings.get_global_class_list():
		_classes[String(c["class"])] = String(c["path"])
	return _classes.has("MobileAds") and _classes.has("AdRequest") and _classes.has("RewardedAdLoader")


func _cls(cls_name: String) -> Variant:
	if not _classes.has(cls_name):
		return null
	return load(String(_classes[cls_name]))


func _unit_id(kind: String) -> String:
	var table: Dictionary = TEST_IDS if use_test_ids() else PROD_IDS
	var os_name: String = OS.get_name()
	if not table.has(os_name):
		return ""
	return String(table[os_name].get(kind, ""))


func ads_enabled_for_user() -> bool:
	return not ads_removed


func _script_has(cls: Variant, fn_name: String) -> bool:
	if not (cls is Script):
		return false
	for m in (cls as Script).get_script_method_list():
		if String(m.get("name", "")) == fn_name:
			return true
	return false


# ================================================================ Consent (UMP)
func _request_consent() -> void:
	var ump: Variant = _cls("UserMessagingPlatform")
	var params_cls: Variant = _cls("ConsentRequestParameters")
	if ump == null or params_cls == null:
		_init_sdk()
		return
	var params: Variant = params_cls.new()
	params.set("tag_for_under_age_of_consent", false)
	var info: Variant = ump.get("consent_information")
	if info == null:
		_init_sdk()
		return
	info.update(params, _on_consent_updated, _on_consent_failed)


func _on_consent_updated() -> void:
	var ump: Variant = _cls("UserMessagingPlatform")
	var info: Variant = ump.get("consent_information") if ump != null else null
	_init_sdk_if_allowed()
	if info != null and info.has_method("get_is_consent_form_available") and info.get_is_consent_form_available():
		ump.load_consent_form(_on_form_loaded, _on_consent_failed)


func _on_form_loaded(form: Variant) -> void:
	_consent_form = form
	if _consent_status_is("REQUIRED"):
		form.show(_on_form_dismissed)
	else:
		_init_sdk_if_allowed()


func _on_form_dismissed(_err: Variant = null) -> void:
	_init_sdk_if_allowed()


func _on_consent_failed(_err: Variant = null) -> void:
	_init_sdk_if_allowed()


func _init_sdk_if_allowed() -> void:
	if can_request_ads():
		_init_sdk()


func can_request_ads() -> bool:
	if not _plugin_ok:
		return false
	var ump: Variant = _cls("UserMessagingPlatform")
	if ump == null:
		return true
	var info: Variant = ump.get("consent_information")
	if info == null:
		return true
	for fn in ["get_can_request_ads", "can_request_ads"]:
		if info.has_method(fn):
			return bool(info.call(fn))
	if _consent_status_known():
		return _consent_status_is("OBTAINED") or _consent_status_is("NOT_REQUIRED")
	return true


func _consent_status_known() -> bool:
	return _consent_status_is("OBTAINED") or _consent_status_is("NOT_REQUIRED") \
		or _consent_status_is("REQUIRED") or _consent_status_is("UNKNOWN")


func _consent_status_is(status_name: String) -> bool:
	var ump: Variant = _cls("UserMessagingPlatform")
	if ump == null:
		return false
	var info: Variant = ump.get("consent_information")
	if info == null or not info.has_method("get_consent_status"):
		return false
	var script: Script = info.get_script()
	if script == null:
		return false
	var consts: Dictionary = script.get_script_constant_map()
	if not consts.has("ConsentStatus"):
		return false
	var enum_map: Dictionary = consts["ConsentStatus"]
	return enum_map.has(status_name) and int(info.get_consent_status()) == int(enum_map[status_name])


func privacy_options_required() -> bool:
	if not _plugin_ok:
		return false
	var ump: Variant = _cls("UserMessagingPlatform")
	var info: Variant = ump.get("consent_information") if ump != null else null
	if info == null:
		return false
	if info.has_method("get_privacy_options_requirement_status"):
		var script: Script = info.get_script()
		var consts: Dictionary = script.get_script_constant_map() if script else {}
		var enum_map: Dictionary = consts.get("PrivacyOptionsRequirementStatus", {})
		if enum_map.has("REQUIRED"):
			return int(info.call("get_privacy_options_requirement_status")) == int(enum_map["REQUIRED"])
	if _consent_status_known():
		return not _consent_status_is("NOT_REQUIRED")
	return true


func show_privacy_options() -> void:
	if not _plugin_ok:
		status_message.emit(Localization.tr_key("ad_privacy_mobile_only"))
		return
	var ump: Variant = _cls("UserMessagingPlatform")
	if ump == null:
		return
	if _script_has(ump, "show_privacy_options_form"):
		ump.call("show_privacy_options_form", _on_privacy_dismissed)
		return
	ump.load_consent_form(_on_privacy_form_loaded, _on_privacy_form_failed)


func _on_privacy_form_loaded(form: Variant) -> void:
	_consent_form = form
	form.show(_on_privacy_dismissed)


func _on_privacy_form_failed(_e: Variant = null) -> void:
	status_message.emit(Localization.tr_key("ad_privacy_failed"))


func _on_privacy_dismissed(_e: Variant = null) -> void:
	pass


# ================================================================ Khởi tạo SDK
func _init_sdk() -> void:
	if _initialized:
		return
	_initialized = true
	var mobile_ads: Variant = _cls("MobileAds")
	if mobile_ads == null:
		return
	_apply_request_configuration(mobile_ads)
	var listener_cls: Variant = _cls("OnInitializationCompleteListener")
	if listener_cls == null:
		mobile_ads.initialize()
		_on_sdk_ready()
		return
	var listener: Variant = listener_cls.new()
	listener.set("on_initialization_complete", _on_sdk_ready)
	_keep_alive.append(listener)
	mobile_ads.initialize(listener)


func _on_sdk_ready(_status: Variant = null) -> void:
	if _sdk_ready:
		return
	_sdk_ready = true
	_load_rewarded()
	if ads_enabled_for_user():
		_load_interstitial()
	if _banner_wanted:
		show_banner()


func _apply_request_configuration(mobile_ads: Variant) -> void:
	var cfg_cls: Variant = _cls("RequestConfiguration")
	if cfg_cls == null or not _script_has(mobile_ads, "set_request_configuration"):
		return
	var cfg: Variant = cfg_cls.new()
	var consts: Dictionary = (cfg_cls as Script).get_script_constant_map() if cfg_cls is Script else {}
	var rating: Variant = consts.get("MAX_AD_CONTENT_RATING_" + MAX_AD_CONTENT_RATING)
	if rating != null:
		cfg.set("max_ad_content_rating", rating)
	mobile_ads.call("set_request_configuration", cfg)


# ================================================================ Rewarded
func is_rewarded_ready() -> bool:
	if not _plugin_ok:
		return OS.is_debug_build() and not OS.has_feature("web")
	return _rewarded != null


func _load_rewarded() -> void:
	if not _plugin_ok or not _sdk_ready or _loading_rewarded or _rewarded != null:
		return
	var loader_cls: Variant = _cls("RewardedAdLoader")
	var cb_cls: Variant = _cls("RewardedAdLoadCallback")
	var req_cls: Variant = _cls("AdRequest")
	if loader_cls == null or cb_cls == null or req_cls == null:
		return
	_loading_rewarded = true
	var cb: Variant = cb_cls.new()
	cb.set("on_ad_failed_to_load", _on_rewarded_failed)
	cb.set("on_ad_loaded", _on_rewarded_loaded)
	_keep_alive.append(cb)
	var loader: Variant = loader_cls.new()
	_keep_alive.append(loader)
	loader.load(_unit_id("rewarded"), req_cls.new(), cb)


func _on_rewarded_failed(_e: Variant = null) -> void:
	_loading_rewarded = false
	if is_inside_tree():
		get_tree().create_timer(30.0).timeout.connect(_load_rewarded)


func _on_rewarded_loaded(ad: Variant) -> void:
	_loading_rewarded = false
	_rewarded = ad
	ad.set("full_screen_content_callback", _make_fullscreen_cb(true))


func _on_user_earned(_item: Variant = null) -> void:
	_reward_earned = true


func show_rewarded(tag: String, callback: Callable = Callable()) -> void:
	_reward_tag = tag
	_reward_earned = false
	_reward_callback = callback
	if not _plugin_ok:
		if OS.is_debug_build() and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
			_simulate_rewarded()
		elif DisplayServer.get_name() == "headless":
			_reward_earned = true
			_finish_reward(true)
		else:
			status_message.emit(Localization.tr_key("ad_not_ready"))
			_finish_reward(false)
		return
	if _rewarded == null:
		status_message.emit(Localization.tr_key("ad_loading"))
		_load_rewarded()
		_finish_reward(false)
		return
	var listener_cls: Variant = _cls("OnUserEarnedRewardListener")
	var listener: Variant = listener_cls.new() if listener_cls != null else null
	if listener != null:
		listener.set("on_user_earned_reward", _on_user_earned)
		_keep_alive.append(listener)
	_set_ad_audio_mute(true)
	_rewarded.show(listener)


func _finish_reward(earned: bool) -> void:
	_set_ad_audio_mute(false)
	var cb: Callable = _reward_callback
	_reward_callback = Callable()
	rewarded_finished.emit(_reward_tag, earned)
	if cb.is_valid():
		cb.call(earned)


func _simulate_rewarded() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.055, 0.05, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var lbl := Label.new()
	lbl.text = Localization.tr_key("ad_simulated")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color("#fde68a"))
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(lbl)
	layer.add_child(bg)
	get_tree().root.add_child(layer)
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(layer):
		layer.queue_free()
	_reward_earned = true
	_finish_reward(true)


# ================================================================ Interstitial
func _load_interstitial() -> void:
	if not _plugin_ok or not _sdk_ready or _loading_interstitial or _interstitial != null or not ads_enabled_for_user():
		return
	var loader_cls: Variant = _cls("InterstitialAdLoader")
	var cb_cls: Variant = _cls("InterstitialAdLoadCallback")
	var req_cls: Variant = _cls("AdRequest")
	if loader_cls == null or cb_cls == null or req_cls == null:
		return
	_loading_interstitial = true
	var cb: Variant = cb_cls.new()
	cb.set("on_ad_failed_to_load", _on_interstitial_failed)
	cb.set("on_ad_loaded", _on_interstitial_loaded)
	_keep_alive.append(cb)
	var loader: Variant = loader_cls.new()
	_keep_alive.append(loader)
	loader.load(_unit_id("interstitial"), req_cls.new(), cb)


func _on_interstitial_failed(_e: Variant = null) -> void:
	_loading_interstitial = false
	if is_inside_tree():
		get_tree().create_timer(60.0).timeout.connect(_load_interstitial)


func _on_interstitial_loaded(ad: Variant) -> void:
	_loading_interstitial = false
	_interstitial = ad
	ad.set("full_screen_content_callback", _make_fullscreen_cb(false))


func maybe_show_interstitial(_placement: String = "") -> bool:
	if not ads_enabled_for_user() or not _plugin_ok or _interstitial == null:
		return false
	var t: float = _t()
	if t - _session_start < INTERSTITIAL_SESSION_GRACE:
		return false
	if t - _last_interstitial < INTERSTITIAL_MIN_INTERVAL:
		return false
	if _interstitial_count >= INTERSTITIAL_MAX_PER_SESSION:
		return false
	_last_interstitial = t
	_interstitial_count += 1
	_set_ad_audio_mute(true)
	_interstitial.show()
	return true


func _make_fullscreen_cb(is_reward: bool) -> Variant:
	var cls: Variant = _cls("FullScreenContentCallback")
	if cls == null:
		return null
	var cb: Variant = cls.new()
	cb.set("on_ad_dismissed_full_screen_content", _on_fs_dismissed.bind(is_reward))
	cb.set("on_ad_failed_to_show_full_screen_content", _on_fs_failed.bind(is_reward))
	_keep_alive.append(cb)
	return cb


func _on_fs_dismissed(is_reward: bool) -> void:
	_on_fullscreen_closed(is_reward)


func _on_fs_failed(_e: Variant, is_reward: bool) -> void:
	_on_fullscreen_closed(is_reward)


func _on_fullscreen_closed(is_reward: bool) -> void:
	_set_ad_audio_mute(false)
	if is_reward:
		if _rewarded != null:
			_rewarded.destroy()
		_rewarded = null
		call_deferred("_finish_reward", _reward_earned)
		_load_rewarded()
	else:
		if _interstitial != null:
			_interstitial.destroy()
		_interstitial = null
		_load_interstitial()


# ================================================================ Banner
func _simulating_banner() -> bool:
	return SIMULATE_BANNER_IN_DEBUG and not _plugin_ok and OS.is_debug_build() and not OS.has_feature("web") and DisplayServer.get_name() != "headless"


func _screen_width_dp() -> float:
	var dpi: float = float(DisplayServer.screen_get_dpi())
	var px: float = float(DisplayServer.window_get_size().x)
	return px * 160.0 / maxf(dpi, 120.0)


func banner_size_dp() -> Vector2:
	if _banner_dp != Vector2.ZERO:
		return _banner_dp
	var w: float = _screen_width_dp()
	return Vector2(w, clampf(roundf(w * 0.12), 50.0, 90.0))


func _dp_to_virtual(dp: float) -> float:
	var dpi: float = float(DisplayServer.screen_get_dpi())
	var px: float = dp * maxf(dpi, 120.0) / 160.0
	var win: float = float(DisplayServer.window_get_size().x)
	var vp: float = get_viewport().get_visible_rect().size.x if get_viewport() else 1280.0
	return px * vp / maxf(win, 1.0)


func banner_reserved_height() -> float:
	if not BANNER_ENABLED or not ads_enabled_for_user():
		return 0.0
	if not _plugin_ok and not _simulating_banner():
		return 0.0
	return _dp_to_virtual(banner_size_dp().y) + BANNER_GAP


func show_banner() -> void:
	_banner_wanted = true
	if _simulating_banner() and ads_enabled_for_user():
		_show_fake_banner()
		return
	if not BANNER_ENABLED or not _plugin_ok or not _sdk_ready or not ads_enabled_for_user():
		return
	if _banner != null:
		if _banner.has_method("show"):
			_banner.show()
		return
	var view_cls: Variant = _cls("AdView")
	var size_cls: Variant = _cls("AdSize")
	var pos_cls: Variant = _cls("AdPosition")
	var req_cls: Variant = _cls("AdRequest")
	if view_cls == null or size_cls == null or pos_cls == null or req_cls == null:
		return
	var ad_size: Variant = null
	if _script_has(size_cls, "get_current_orientation_anchored_adaptive_banner_ad_size"):
		ad_size = size_cls.call("get_current_orientation_anchored_adaptive_banner_ad_size", int(_screen_width_dp()))
	if ad_size == null:
		ad_size = size_cls.get("BANNER")
	if ad_size == null:
		ad_size = size_cls.new(int(BANNER_FALLBACK_DP.x), int(BANNER_FALLBACK_DP.y))
	var ad_pos: Variant = pos_cls.get("BOTTOM")
	if ad_pos == null:
		var values: Variant = pos_cls.get("Values")
		if values is Dictionary:
			ad_pos = (values as Dictionary).get("BOTTOM")
	if ad_size == null or ad_pos == null:
		return
	if ad_size is Object and (ad_size as Object).get("height") != null:
		_banner_dp = Vector2(float((ad_size as Object).get("width")), float((ad_size as Object).get("height")))
	_banner = view_cls.new(_unit_id("banner"), ad_size, ad_pos)
	_banner.load_ad(req_cls.new())


func hide_banner() -> void:
	_banner_wanted = false
	if _fake_banner and is_instance_valid(_fake_banner):
		_fake_banner.queue_free()
		_fake_banner = null
	if _banner == null:
		return
	if _banner.has_method("hide"):
		_banner.hide()
	else:
		_banner.destroy()
		_banner = null


func _show_fake_banner() -> void:
	if _fake_banner and is_instance_valid(_fake_banner):
		return
	var layer := CanvasLayer.new()
	layer.layer = 96
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var h: float = _dp_to_virtual(banner_size_dp().y)
	var bar := ColorRect.new()
	bar.color = Color(0.14, 0.12, 0.10, 0.88)
	bar.position = Vector2(0, vs.y - h)
	bar.size = Vector2(vs.x, h)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lb := Label.new()
	lb.text = "Banner AdMob (giả lập) %dx%d dp" % [int(banner_size_dp().x), int(banner_size_dp().y)]
	lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	lb.add_theme_font_size_override("font_size", 16)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.size = bar.size
	bar.add_child(lb)
	layer.add_child(bar)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(layer)
	add_child(holder)
	_fake_banner = holder


## Gọi khi người chơi mua gói "Gỡ quảng cáo" (IAP).
func set_ads_removed(removed: bool) -> void:
	ads_removed = removed
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ads", "removed", removed)
	cfg.save(SETTINGS_PATH)
	if removed:
		hide_banner()
		if _banner != null:
			_banner.destroy()
			_banner = null

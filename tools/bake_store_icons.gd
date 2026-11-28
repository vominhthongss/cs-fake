extends SceneTree

## Headless icon baker for Google Play, Apple App Store, Android Adaptive Icons, and Boot Splash.
## Run:
##   godot --headless --path . --script tools/bake_store_icons.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://store"))

	# 1. Square opaque icon (1024x1024) -> iOS App Store (RGB8, NO ALPHA) + Google Play (512x512 opaque) + Icon 192
	var full_svg: String = _make_full_icon_svg(false)
	_render_svg_png(full_svg, 1024, 1024, "res://assets/icons/ios_appstore_1024.png", false)
	_render_svg_png(full_svg, 1024, 1024, "res://assets/icons/icon_1024.png", true)
	_render_svg_png(full_svg, 192, 192, "res://assets/icons/icon_192.png", true)
	_render_svg_png(full_svg, 512, 512, "res://store/play_store_icon_512.png", false)

	# 2. Android Adaptive Icons (432x432)
	_render_svg_png(_make_adaptive_fg_svg(), 432, 432, "res://assets/icons/adaptive_foreground_432.png", true)
	_render_svg_png(_make_adaptive_bg_svg(), 432, 432, "res://assets/icons/adaptive_background_432.png", false)
	_render_svg_png(_make_adaptive_mono_svg(), 432, 432, "res://assets/icons/adaptive_monochrome_432.png", true)

	# 3. Boot Splash Logo (512x512 RGBA)
	_render_svg_png(_make_splash_logo_svg(), 512, 512, "res://assets/icons/logo_splash.png", true)

	# 4. Google Play Feature Graphic (1024x500 RGB8)
	_render_svg_png(_make_feature_graphic_svg(), 1024, 500, "res://store/feature_graphic_1024x500.png", false)

	print("[bake_store_icons] Generated all Android, iOS, Play Store, and Splash PNG assets.")
	quit(0)


func _render_svg_png(svg: String, w: int, h: int, res_path: String, keep_alpha: bool) -> void:
	var img := Image.new()
	var err: Error = img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("Failed to rasterize SVG for %s (err=%d)" % [res_path, err])
		return
	if img.get_width() != w or img.get_height() != h:
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	if not keep_alpha:
		img.convert(Image.FORMAT_RGB8)
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var save_err: Error = img.save_png(abs_path)
	if save_err != OK:
		push_error("Failed to save PNG %s (err=%d)" % [abs_path, save_err])


func _make_full_icon_svg(rounded: bool) -> String:
	var rx: String = "180" if rounded else "0"
	return """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bg" cx="50%" cy="42%" r="65%">
      <stop offset="0%" stop-color="#29221b"/>
      <stop offset="100%" stop-color="#0f0c09"/>
    </radialGradient>
    <linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#fbbf24"/>
      <stop offset="100%" stop-color="#b45309"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="{RX}" fill="url(#bg)"/>
  <polygon points="512,108 864,284 804,724 512,922 220,724 160,284" fill="#181411" stroke="url(#gold)" stroke-width="34" stroke-linejoin="round"/>
  <polygon points="512,196 774,328 728,662 512,818 296,662 250,328" fill="none" stroke="#f59e0b" stroke-opacity="0.45" stroke-width="14"/>
  <circle cx="512" cy="500" r="142" fill="none" stroke="#fef3c7" stroke-width="28"/>
  <circle cx="512" cy="500" r="32" fill="#f59e0b"/>
  <line x1="512" y1="264" x2="512" y2="392" stroke="#f59e0b" stroke-width="30" stroke-linecap="round"/>
  <line x1="512" y1="608" x2="512" y2="736" stroke="#f59e0b" stroke-width="30" stroke-linecap="round"/>
  <line x1="276" y1="500" x2="404" y2="500" stroke="#f59e0b" stroke-width="30" stroke-linecap="round"/>
  <line x1="620" y1="500" x2="748" y2="500" stroke="#f59e0b" stroke-width="30" stroke-linecap="round"/>
</svg>""".replace("{RX}", rx)


func _make_adaptive_fg_svg() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 432 432">
  <polygon points="216,86 334,145 314,292 216,356 118,292 98,145" fill="#181411" stroke="#f59e0b" stroke-width="14" stroke-linejoin="round"/>
  <circle cx="216" cy="216" r="48" fill="none" stroke="#fef3c7" stroke-width="11"/>
  <circle cx="216" cy="216" r="12" fill="#f59e0b"/>
  <line x1="216" y1="134" x2="216" y2="178" stroke="#f59e0b" stroke-width="12" stroke-linecap="round"/>
  <line x1="216" y1="254" x2="216" y2="298" stroke="#f59e0b" stroke-width="12" stroke-linecap="round"/>
  <line x1="134" y1="216" x2="178" y2="216" stroke="#f59e0b" stroke-width="12" stroke-linecap="round"/>
  <line x1="254" y1="216" x2="298" y2="216" stroke="#f59e0b" stroke-width="12" stroke-linecap="round"/>
</svg>"""


func _make_adaptive_bg_svg() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 432 432">
  <defs>
    <radialGradient id="bg" cx="50%" cy="42%" r="68%">
      <stop offset="0%" stop-color="#2c231a"/>
      <stop offset="100%" stop-color="#0f0c09"/>
    </radialGradient>
  </defs>
  <rect width="432" height="432" fill="url(#bg)"/>
</svg>"""


func _make_adaptive_mono_svg() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 432 432">
  <polygon points="216,90 330,147 310,290 216,350 122,290 102,147" fill="none" stroke="#ffffff" stroke-width="16" stroke-linejoin="round"/>
  <circle cx="216" cy="216" r="46" fill="none" stroke="#ffffff" stroke-width="12"/>
  <circle cx="216" cy="216" r="12" fill="#ffffff"/>
  <line x1="216" y1="138" x2="216" y2="178" stroke="#ffffff" stroke-width="12" stroke-linecap="round"/>
  <line x1="216" y1="254" x2="216" y2="294" stroke="#ffffff" stroke-width="12" stroke-linecap="round"/>
  <line x1="138" y1="216" x2="178" y2="216" stroke="#ffffff" stroke-width="12" stroke-linecap="round"/>
  <line x1="254" y1="216" x2="294" y2="216" stroke="#ffffff" stroke-width="12" stroke-linecap="round"/>
</svg>"""


func _make_splash_logo_svg() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <polygon points="256,42 440,134 408,364 256,466 104,364 72,134" fill="#171310" stroke="#f59e0b" stroke-width="18" stroke-linejoin="round"/>
  <polygon points="256,88 394,158 370,334 256,414 142,334 118,158" fill="none" stroke="#fbbf24" stroke-opacity="0.45" stroke-width="7"/>
  <circle cx="256" cy="252" r="74" fill="none" stroke="#fef3c7" stroke-width="14"/>
  <circle cx="256" cy="252" r="16" fill="#f59e0b"/>
  <line x1="256" y1="126" x2="256" y2="194" stroke="#f59e0b" stroke-width="15" stroke-linecap="round"/>
  <line x1="256" y1="310" x2="256" y2="378" stroke="#f59e0b" stroke-width="15" stroke-linecap="round"/>
  <line x1="130" y1="252" x2="198" y2="252" stroke="#f59e0b" stroke-width="15" stroke-linecap="round"/>
  <line x1="314" y1="252" x2="382" y2="252" stroke="#f59e0b" stroke-width="15" stroke-linecap="round"/>
</svg>"""


func _make_feature_graphic_svg() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500" viewBox="0 0 1024 500">
  <defs>
    <linearGradient id="fbg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1c1611"/>
      <stop offset="55%" stop-color="#110e0b"/>
      <stop offset="100%" stop-color="#271c12"/>
    </linearGradient>
    <linearGradient id="accent" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#d97706"/>
      <stop offset="100%" stop-color="#fbbf24"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="500" fill="url(#fbg)"/>
  <rect x="0" y="0" width="1024" height="10" fill="url(#accent)"/>
  <rect x="0" y="490" width="1024" height="10" fill="url(#accent)"/>
  <!-- Emblem on left -->
  <g transform="translate(88, 70) scale(0.70)">
    <polygon points="256,42 440,134 408,364 256,466 104,364 72,134" fill="#171310" stroke="#f59e0b" stroke-width="18" stroke-linejoin="round"/>
    <circle cx="256" cy="252" r="74" fill="none" stroke="#fef3c7" stroke-width="14"/>
    <circle cx="256" cy="252" r="16" fill="#f59e0b"/>
    <line x1="256" y1="126" x2="256" y2="194" stroke="#f59e0b" stroke-width="15" stroke-linecap="round"/>
    <line x1="256" y1="310" x2="256" y2="378" stroke="#f59e0b" stroke-width="15" stroke-linecap="round"/>
    <line x1="130" y1="252" x2="198" y2="252" stroke="#f59e0b" stroke-width="15" stroke-linecap="round"/>
    <line x1="314" y1="252" x2="382" y2="252" stroke="#f59e0b" stroke-width="15" stroke-linecap="round"/>
  </g>
  <!-- Tactical bars & typography -->
  <rect x="440" y="138" width="140" height="8" rx="4" fill="#f59e0b"/>
  <text x="440" y="232" font-family="Arial, Helvetica, sans-serif" font-weight="bold" font-size="68" fill="#faf5eb" letter-spacing="4">CS-PROTOCOL</text>
  <text x="442" y="286" font-family="Arial, Helvetica, sans-serif" font-weight="bold" font-size="24" fill="#fbbf24" letter-spacing="3">TACTICAL 3D BOT FPS · DUST SECTOR</text>
  <text x="442" y="340" font-family="Arial, Helvetica, sans-serif" font-size="20" fill="#d6c7b2">10 Tactical Weapons · Wall Penetration · Smart Utility AI Bots</text>
</svg>"""

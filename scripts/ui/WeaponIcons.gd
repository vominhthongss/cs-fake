class_name WeaponIcons
extends RefCounted

## Generates crisp tactical SVG weapon & gear thumbnails for the Buy Menu

static var _cache: Dictionary = {}

static func get_icon(item_id: String) -> Texture2D:
	if _cache.has(item_id):
		return _cache[item_id]
	var svg: String = _svg_for_item(item_id)
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 2.0)
	if err != OK or img.is_empty():
		img = Image.create_empty(160, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.2, 0.2, 0.22, 0.35))
	var tex := ImageTexture.create_from_image(img)
	_cache[item_id] = tex
	return tex

static func _svg_for_item(item_id: String) -> String:
	var body: String = ""
	match item_id:
		"ak47":
			body = """
			<!-- Wood stock -->
			<path d="M12,44 L52,37 L54,48 L16,59 Q11,59 11,53 Z" fill="#8f532b" stroke="#3d2210" stroke-width="1.6"/>
			<!-- Receiver & dust cover -->
			<rect x="51" y="31" width="54" height="17" rx="4" fill="#2c3138" stroke="#111418" stroke-width="1.5"/>
			<path d="M55,31 Q78,26 102,31 Z" fill="#525a64"/>
			<!-- Pistol grip -->
			<path d="M62,48 L72,48 L67,67 Q64,70 59,68 L57,64 Z" fill="#8f532b" stroke="#3d2210" stroke-width="1.5"/>
			<!-- Curved banana magazine -->
			<path d="M84,48 L98,48 Q103,64 114,74 L102,77 Q90,65 84,48 Z" fill="#464d56" stroke="#181b20" stroke-width="1.6"/>
			<!-- Wooden handguard -->
			<rect x="104" y="32" width="38" height="14" rx="5" fill="#9a5b30" stroke="#3d2210" stroke-width="1.5"/>
			<!-- Gas tube & barrel -->
			<rect x="108" y="27" width="36" height="5" rx="2" fill="#434b54"/>
			<rect x="142" y="34" width="46" height="6" rx="2.5" fill="#6d7682" stroke="#22262b" stroke-width="1.2"/>
			<!-- Front sight & muzzle brake -->
			<path d="M170,34 L174,23 L179,23 L180,34 Z" fill="#2c3138"/>
			<rect x="186" y="33" width="9" height="8" rx="2" fill="#3a4048"/>
			<!-- Highlight -->
			<line x1="57" y1="35" x2="100" y2="35" stroke="#85909d" stroke-width="1.5" stroke-linecap="round" opacity="0.65"/>
			"""
		"m4a1s":
			body = """
			<!-- Collapsible stock -->
			<path d="M12,34 L46,34 L46,47 L22,52 L12,50 Z" fill="#24282e" stroke="#0d0f12" stroke-width="1.5"/>
			<rect x="20" y="39" width="16" height="5" rx="2" fill="#14161a"/>
			<!-- Receiver & top rail -->
			<rect x="46" y="31" width="52" height="17" rx="4" fill="#2c3138" stroke="#101216" stroke-width="1.5"/>
			<rect x="49" y="28" width="84" height="4" rx="1.5" fill="#4a525c"/>
			<!-- Red-dot optic -->
			<rect x="64" y="18" width="22" height="11" rx="3" fill="#23272d" stroke="#101216" stroke-width="1.3"/>
			<circle cx="83" cy="23.5" r="3" fill="#38bdf8"/>
			<!-- Grip -->
			<path d="M56,48 L66,48 L61,67 Q58,70 54,67 Z" fill="#1f2328" stroke="#0d0f12" stroke-width="1.5"/>
			<!-- Magazine -->
			<path d="M80,48 L93,48 L96,71 Q90,73 83,71 Z" fill="#525b66" stroke="#181b20" stroke-width="1.5"/>
			<!-- Handguard -->
			<rect x="98" y="32" width="40" height="14" rx="5" fill="#252930" stroke="#0e1014" stroke-width="1.5"/>
			<line x1="104" y1="39" x2="132" y2="39" stroke="#4b535e" stroke-width="2" stroke-dasharray="4 3"/>
			<!-- Suppressor -->
			<rect x="138" y="32" width="56" height="12" rx="5.5" fill="#5b6570" stroke="#1f2329" stroke-width="1.5"/>
			<line x1="146" y1="35" x2="188" y2="35" stroke="#9ca7b4" stroke-width="1.6" stroke-linecap="round" opacity="0.7"/>
			"""
		"awp":
			body = """
			<!-- Olive thumbhole chassis & buttstock -->
			<path d="M8,36 L118,33 L122,47 L66,49 L58,64 L48,64 L52,50 L26,56 L10,55 Q7,54 7,49 Z" fill="#4f673d" stroke="#23301a" stroke-width="1.6"/>
			<rect x="20" y="42" width="20" height="7" rx="3.5" fill="#17191c"/>
			<!-- Receiver & bolt -->
			<rect x="54" y="29" width="46" height="10" rx="3" fill="#272b31" stroke="#101216" stroke-width="1.3"/>
			<circle cx="67" cy="36" r="3.4" fill="#d4dde6" stroke="#30363e" stroke-width="1.2"/>
			<!-- Magazine -->
			<rect x="78" y="47" width="16" height="12" rx="2.5" fill="#2c3138"/>
			<!-- Sniper scope + rings -->
			<rect x="64" y="21" width="5" height="9" fill="#1e2228"/>
			<rect x="90" y="21" width="5" height="9" fill="#1e2228"/>
			<path d="M52,15 L106,15 L116,12 L118,24 L106,22 L52,22 Z" fill="#23272d" stroke="#0d0f12" stroke-width="1.4"/>
			<ellipse cx="117" cy="18" rx="2.5" ry="5.5" fill="#38bdf8"/>
			<!-- Long barrel + muzzle brake -->
			<rect x="118" y="33" width="66" height="6" rx="2.5" fill="#6a7480" stroke="#1d2126" stroke-width="1.2"/>
			<rect x="181" y="31" width="14" height="10" rx="2.5" fill="#2a2f36" stroke="#101216" stroke-width="1.2"/>
			<line x1="185" y1="33" x2="185" y2="39" stroke="#7a8490" stroke-width="1.5"/>
			<line x1="190" y1="33" x2="190" y2="39" stroke="#7a8490" stroke-width="1.5"/>
			"""
		"p90":
			body = """
			<!-- Futuristic rounded bullpup frame -->
			<path d="M24,33 Q32,26 52,26 L138,26 Q152,26 154,37 L154,48 Q154,54 144,54 L126,54 L118,64 L104,64 L108,52 L74,52 L66,64 L40,64 Q24,62 22,48 Z" fill="#262a31" stroke="#0f1115" stroke-width="1.7"/>
			<!-- Ergonomic thumbhole cutouts -->
			<rect x="42" y="42" width="24" height="12" rx="6" fill="#121417"/>
			<rect x="82" y="40" width="22" height="10" rx="5" fill="#121417"/>
			<!-- Top horizontal magazine -->
			<rect x="44" y="21" width="76" height="8" rx="3.5" fill="#64707d" stroke="#22262c" stroke-width="1.3"/>
			<line x1="54" y1="25" x2="112" y2="25" stroke="#d97706" stroke-width="2" stroke-dasharray="5 3" opacity="0.8"/>
			<!-- Reflex sight -->
			<path d="M122,16 L142,16 L146,26 L120,26 Z" fill="#353b44" stroke="#111418" stroke-width="1.3"/>
			<circle cx="139" cy="21" r="2.6" fill="#38bdf8"/>
			<!-- Compact barrel -->
			<rect x="154" y="34" width="24" height="7" rx="3" fill="#707a86" stroke="#22262c" stroke-width="1.2"/>
			"""
		"nova":
			body = """
			<!-- Angled shotgun stock -->
			<path d="M10,44 L54,36 L58,47 L20,62 Q11,62 10,55 Z" fill="#292d34" stroke="#101216" stroke-width="1.6"/>
			<!-- Receiver -->
			<rect x="52" y="32" width="44" height="16" rx="5" fill="#363c45" stroke="#14171b" stroke-width="1.5"/>
			<!-- Top barrel & under tube -->
			<rect x="95" y="33" width="94" height="6.5" rx="3" fill="#6b7582" stroke="#1f2329" stroke-width="1.2"/>
			<rect x="95" y="41" width="76" height="5.5" rx="2.5" fill="#464e58"/>
			<!-- Ribbed pump forend -->
			<rect x="112" y="39" width="42" height="12" rx="5" fill="#23272e" stroke="#0d0f12" stroke-width="1.5"/>
			<line x1="120" y1="41" x2="120" y2="49" stroke="#525b66" stroke-width="2"/>
			<line x1="128" y1="41" x2="128" y2="49" stroke="#525b66" stroke-width="2"/>
			<line x1="136" y1="41" x2="136" y2="49" stroke="#525b66" stroke-width="2"/>
			<line x1="144" y1="41" x2="144" y2="49" stroke="#525b66" stroke-width="2"/>
			<!-- Bead sight -->
			<circle cx="186" cy="32" r="2.2" fill="#f59e0b"/>
			"""
		"deagle":
			body = """
			<!-- Heavy Chrome Slide -->
			<path d="M52,20 L146,20 Q154,20 156,28 L156,37 L50,37 L50,24 Q50,20 52,20 Z" fill="#cbd5e1" stroke="#334155" stroke-width="1.7"/>
			<line x1="58" y1="24.5" x2="144" y2="24.5" stroke="#ffffff" stroke-width="2" stroke-linecap="round" opacity="0.8"/>
			<!-- Frame & Trigger Guard -->
			<path d="M52,37 L148,37 L142,46 L98,46 Q94,55 82,55 L74,55 L64,74 Q58,76 50,72 L58,46 L52,44 Z" fill="#282d34" stroke="#0f1216" stroke-width="1.6"/>
			<rect x="78" y="44" width="14" height="7" rx="3.5" fill="#131519"/>
			<!-- Grip panel -->
			<path d="M58,48 L72,48 L63,70 L53,68 Z" fill="#1c1f24"/>
			<!-- Front sight -->
			<path d="M142,20 L148,15 L152,20 Z" fill="#334155"/>
			"""
		"he_grenade":
			body = """
			<!-- Fuse & Spoon Lever -->
			<rect x="92" y="14" width="16" height="12" rx="3" fill="#6b7582" stroke="#1e2228" stroke-width="1.4"/>
			<path d="M107,18 Q126,20 128,44 L123,54 L118,52 L122,42 Q121,26 107,23 Z" fill="#828d9a" stroke="#22262c" stroke-width="1.3"/>
			<!-- Pull ring -->
			<circle cx="83" cy="20" r="7" fill="none" stroke="#cbd5e1" stroke-width="2.4"/>
			<!-- Rounded Ovoid Frag Body -->
			<ellipse cx="100" cy="49" rx="22" ry="26" fill="#475b3d" stroke="#1e2919" stroke-width="1.8"/>
			<!-- Segmentation ribs -->
			<ellipse cx="100" cy="49" rx="21" ry="8" fill="none" stroke="#2a3823" stroke-width="1.6"/>
			<line x1="100" y1="24" x2="100" y2="74" stroke="#2a3823" stroke-width="1.5" opacity="0.6"/>
			<!-- Amber explosive band -->
			<rect x="79" y="43" width="42" height="8" rx="3" fill="#d97706" opacity="0.92"/>
			<ellipse cx="92" cy="36" rx="4" ry="8" fill="#84a374" opacity="0.45"/>
			"""
		"flashbang":
			body = """
			<!-- Fuse & Lever -->
			<rect x="92" y="13" width="16" height="11" rx="3" fill="#525b66" stroke="#1c2026" stroke-width="1.4"/>
			<path d="M107,17 Q125,19 126,44 L121,55 L117,53 L121,42 Q120,25 107,22 Z" fill="#7c8794" stroke="#22262c" stroke-width="1.3"/>
			<circle cx="82" cy="19" r="7" fill="none" stroke="#e2e8f0" stroke-width="2.4"/>
			<!-- Cylindrical Stun Body -->
			<rect x="82" y="23" width="36" height="52" rx="11" fill="#a8b3bf" stroke="#323842" stroke-width="1.8"/>
			<!-- Top & bottom caps -->
			<rect x="84" y="24" width="32" height="8" rx="4" fill="#64707d"/>
			<rect x="84" y="66" width="32" height="8" rx="4" fill="#64707d"/>
			<!-- Tactical band & vent holes -->
			<rect x="82" y="42" width="36" height="10" fill="#f59e0b"/>
			<circle cx="92" cy="35" r="2.4" fill="#1e2228"/>
			<circle cx="100" cy="35" r="2.4" fill="#1e2228"/>
			<circle cx="108" cy="35" r="2.4" fill="#1e2228"/>
			<circle cx="92" cy="59" r="2.4" fill="#1e2228"/>
			<circle cx="100" cy="59" r="2.4" fill="#1e2228"/>
			<circle cx="108" cy="59" r="2.4" fill="#1e2228"/>
			"""
		"kevlar_helmet":
			body = """
			<!-- Tactical Kevlar Vest (Left) -->
			<path d="M44,24 L58,20 L66,30 L78,30 L86,20 L100,24 L104,40 L98,71 Q72,76 46,71 L40,40 Z" fill="#2c445c" stroke="#111d29" stroke-width="1.8"/>
			<rect x="52" y="37" width="40" height="24" rx="5" fill="#3a5978" stroke="#1b2d3f" stroke-width="1.4"/>
			<line x1="56" y1="45" x2="88" y2="45" stroke="#7dd3fc" stroke-width="2" opacity="0.7"/>
			<line x1="56" y1="53" x2="88" y2="53" stroke="#7dd3fc" stroke-width="2" opacity="0.7"/>
			<!-- Ballistic Rounded Helmet (Right) -->
			<path d="M116,52 C116,24 166,24 166,52 L168,61 Q154,66 138,63 L122,63 Q115,61 116,52 Z" fill="#313944" stroke="#11151b" stroke-width="1.8"/>
			<!-- Glowing Curved Visor -->
			<path d="M126,46 Q146,42 162,48 L161,56 Q144,52 126,54 Z" fill="#f59e0b" stroke="#92400e" stroke-width="1.3"/>
			<path d="M128,34 Q142,27 156,34" fill="none" stroke="#94a3b8" stroke-width="2" stroke-linecap="round" opacity="0.55"/>
			"""
		_:
			body = """
			<rect x="40" y="30" width="120" height="24" rx="8" fill="#525b66" stroke="#1e2228" stroke-width="1.6"/>
			"""

	return '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="84" viewBox="0 0 200 84">' + body + '</svg>'

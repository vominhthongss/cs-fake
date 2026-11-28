class_name ProceduralTextures
extends RefCounted

## Generates realistic matte procedural textures balanced for natural desert daylight

static func create_texture_set() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42017

	# 1. Sandstone Dust Courtyard Floor (grounded matte sandstone, avoids bright washout)
	var sand_img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	sand_img.fill(Color("#a88e68"))
	for _i in range(950):
		var x: int = rng.randi_range(0, 126)
		var y: int = rng.randi_range(0, 126)
		var col: Color = Color(0.86, 0.78, 0.64, 0.16) if rng.randf() > 0.5 else Color(0.36, 0.27, 0.18, 0.18)
		_blend_rect(sand_img, x, y, 2, 2, col)
	for g in range(0, 128, 32):
		_blend_rect(sand_img, g, 0, 1, 128, Color(0.30, 0.23, 0.16, 0.36))
		_blend_rect(sand_img, 0, g, 128, 1, Color(0.30, 0.23, 0.16, 0.36))

	# 2. Weathered Concrete / Sandstone Wall
	var wall_img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	wall_img.fill(Color("#9e8667"))
	for y in range(0, 128, 16):
		var band_col: Color = Color(0.45, 0.37, 0.27, 0.16) if (y / 16) % 2 == 0 else Color(0.84, 0.77, 0.65, 0.10)
		_blend_rect(wall_img, 0, y, 128, 15, band_col)
		_blend_rect(wall_img, 0, y + 15, 128, 1, Color(0.24, 0.19, 0.13, 0.32))
	for _i in range(550):
		var x: int = rng.randi_range(0, 126)
		var y: int = rng.randi_range(0, 126)
		var col: Color = Color(0.28, 0.22, 0.15, 0.14) if rng.randf() > 0.5 else Color(0.88, 0.82, 0.72, 0.09)
		_blend_rect(wall_img, x, y, 2, 2, col)

	# 3. Tactical Wooden Supply Crate
	var wood_img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	wood_img.fill(Color("#8c6239"))
	for y in range(0, 128, 16):
		var plank_col: Color = Color("#976c40") if (y / 16) % 2 == 0 else Color("#815933")
		_fill_rect(wood_img, 8, y, 112, 15, plank_col)
		_fill_rect(wood_img, 8, y + 15, 112, 1, Color("#493119"))
	var frame_col := Color("#664424")
	_fill_rect(wood_img, 0, 0, 128, 11, frame_col)
	_fill_rect(wood_img, 0, 117, 128, 11, frame_col)
	_fill_rect(wood_img, 0, 0, 11, 128, frame_col)
	_fill_rect(wood_img, 117, 0, 11, 128, frame_col)
	for i in range(10, 118):
		_fill_rect(wood_img, maxi(0, i - 4), maxi(0, i - 4), 9, 9, frame_col)

	# 4. Corrugated Shipping Container Steel
	var metal_img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	metal_img.fill(Color("#c0cad2"))
	for x in range(0, 128, 8):
		_blend_rect(metal_img, x, 0, 3, 128, Color(1.0, 1.0, 1.0, 0.12))
		_blend_rect(metal_img, x + 4, 0, 3, 128, Color(0.0, 0.0, 0.0, 0.26))

	return {
		"sandstone": ImageTexture.create_from_image(sand_img),
		"concrete": ImageTexture.create_from_image(wall_img),
		"wood": ImageTexture.create_from_image(wood_img),
		"metal": ImageTexture.create_from_image(metal_img),
		"site_a": _create_site_decal("A", Color("#c93f32")),
		"site_b": _create_site_decal("B", Color("#d4821f")),
	}

static func _create_site_decal(letter: String, color: Color) -> ImageTexture:
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, 4, 4, 56, 4, color)
	_fill_rect(img, 4, 56, 56, 4, color)
	_fill_rect(img, 4, 4, 4, 56, color)
	_fill_rect(img, 56, 4, 4, 56, color)
	if letter == "A":
		_fill_rect(img, 20, 16, 24, 5, color)
		_fill_rect(img, 18, 21, 6, 28, color)
		_fill_rect(img, 40, 21, 6, 28, color)
		_fill_rect(img, 20, 32, 24, 5, color)
	else:
		_fill_rect(img, 18, 16, 6, 33, color)
		_fill_rect(img, 18, 16, 22, 5, color)
		_fill_rect(img, 18, 30, 22, 5, color)
		_fill_rect(img, 18, 44, 24, 5, color)
		_fill_rect(img, 38, 20, 6, 11, color)
		_fill_rect(img, 40, 34, 6, 11, color)
	return ImageTexture.create_from_image(img)

static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var max_x: int = mini(img.get_width(), x + w)
	var max_y: int = mini(img.get_height(), y + h)
	for py in range(maxi(0, y), max_y):
		for px in range(maxi(0, x), max_x):
			img.set_pixel(px, py, color)

static func _blend_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var max_x: int = mini(img.get_width(), x + w)
	var max_y: int = mini(img.get_height(), y + h)
	for py in range(maxi(0, y), max_y):
		for px in range(maxi(0, x), max_x):
			var dst: Color = img.get_pixel(px, py)
			img.set_pixel(px, py, dst.blend(color))

class_name ArenaBuilder
extends RefCounted

## Builds realistic desert daylight, Dust Sector compound geometry, watchtower landmark, decals, and canyon rocks

static func build_arena(parent: Node3D, textures: Dictionary) -> Node3D:
	var arena_root := Node3D.new()
	arena_root.name = "Arena"
	parent.add_child(arena_root)

	_setup_environment_and_lighting(arena_root)

	# Extended desert floor (240x240m) - matte earthen tone to prevent glare
	var desert_mat := StandardMaterial3D.new()
	desert_mat.albedo_color = Color("#9b8262")
	desert_mat.roughness = 0.96
	desert_mat.metallic = 0.0
	desert_mat.metallic_specular = 0.16
	_add_plane(arena_root, Vector2(240.0, 240.0), Vector3(0.0, -0.03, 0.0), desert_mat)

	# Playable Sandstone Courtyard Floor (72x72m)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = textures["sandstone"]
	floor_mat.uv1_scale = Vector3(24.0, 24.0, 1.0)
	floor_mat.roughness = 0.92
	floor_mat.metallic = 0.0
	floor_mat.metallic_specular = 0.20
	_add_plane(arena_root, Vector2(72.0, 72.0), Vector3(0.0, 0.0, 0.0), floor_mat)

	# Site Decals A & B
	_add_site_decal(arena_root, textures["site_a"], Vector3(-20.0, 0.022, -10.0))
	_add_site_decal(arena_root, textures["site_b"], Vector3(22.0, 0.022, -4.0))

	# Shared prop materials - natural physically balanced roughness & specular
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = textures["concrete"]
	wall_mat.uv1_scale = Vector3(2.0, 1.0, 1.0)
	wall_mat.roughness = 0.90
	wall_mat.metallic = 0.0
	wall_mat.metallic_specular = 0.22

	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color("#5d4b39")
	trim_mat.roughness = 0.80
	trim_mat.metallic = 0.08
	trim_mat.metallic_specular = 0.28

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_texture = textures["wood"]
	wood_mat.roughness = 0.84
	wood_mat.metallic = 0.02
	wood_mat.metallic_specular = 0.24

	var sandbag_mat := StandardMaterial3D.new()
	sandbag_mat.albedo_color = Color("#877355")
	sandbag_mat.roughness = 0.95
	sandbag_mat.metallic = 0.0
	sandbag_mat.metallic_specular = 0.14

	var barrel_mat := StandardMaterial3D.new()
	barrel_mat.albedo_color = Color("#8c2d23")
	barrel_mat.roughness = 0.50
	barrel_mat.metallic = 0.52

	for p in MapData.MAP_PROPS:
		var group := Node3D.new()
		group.name = p["id"]
		var px: float = float(p["x"])
		var py: float = float(p["y"])
		var pz: float = float(p["z"])
		var w: float = float(p["w"])
		var h: float = float(p["h"])
		var d: float = float(p["d"])
		var kind: String = p["kind"]
		group.position = Vector3(px, py, pz)

		if kind == "wall" or kind == "arch" or kind == "ramp_block":
			_add_box(group, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall_mat)
			_add_box(group, Vector3(w + 0.14, 0.14, d + 0.14), Vector3(0, h - 0.05, 0), trim_mat)
		elif kind == "crate":
			_add_box(group, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wood_mat)
			_add_box(group, Vector3(w + 0.04, 0.10, d + 0.04), Vector3(0, h * 0.5, 0), trim_mat)
		elif kind == "container":
			var c_mat := StandardMaterial3D.new()
			c_mat.albedo_color = p.get("tint", Color("#334d5c")).darkened(0.08)
			c_mat.albedo_texture = textures["metal"]
			c_mat.uv1_scale = Vector3(2.0, 1.0, 1.0)
			c_mat.roughness = 0.54
			c_mat.metallic = 0.48
			_add_box(group, Vector3(w, h, d), Vector3(0, h * 0.5, 0), c_mat)
			var corners := [
				Vector2(-w * 0.5 + 0.08, -d * 0.5 + 0.08),
				Vector2(w * 0.5 - 0.08, -d * 0.5 + 0.08),
				Vector2(-w * 0.5 + 0.08, d * 0.5 - 0.08),
				Vector2(w * 0.5 - 0.08, d * 0.5 - 0.08),
			]
			for c in corners:
				_add_box(group, Vector3(0.16, h + 0.04, 0.16), Vector3(c.x, h * 0.5, c.y), trim_mat)
		elif kind == "sandbag":
			var rows: int = 3
			var count: int = 4
			var bag_w: float = w / float(count)
			var bag_h: float = h / float(rows)
			for r in range(rows):
				for i in range(count):
					var offset_x: float = 0.05 if r % 2 == 0 else -0.05
					var bag := MeshInstance3D.new()
					var cap := CapsuleMesh.new()
					cap.radius = minf(bag_h * 0.52, d * 0.48)
					cap.height = maxf(cap.radius * 2.0 + 0.04, bag_w * 0.96)
					cap.radial_segments = 14
					cap.rings = 5
					bag.mesh = cap
					bag.material_override = sandbag_mat
					bag.position = Vector3(-w * 0.5 + bag_w * (float(i) + 0.5) + offset_x, (float(r) + 0.5) * bag_h, 0.0)
					bag.rotation.z = PI * 0.5
					group.add_child(bag)
		elif kind == "barrel":
			_add_cyl(group, w * 0.5, w * 0.5, h, Vector3(0, h * 0.5, 0), barrel_mat, 24)
			for ry in [0.35, 0.9]:
				_add_cyl(group, w * 0.53, w * 0.53, 0.08, Vector3(0, ry, 0), trim_mat, 24)

		arena_root.add_child(group)

	# Perimeter Sandstone Compound Walls
	var perim_specs := [
		[Vector3(0.0, 2.1, -34.5), Vector3(70.0, 4.2, 1.5)],
		[Vector3(0.0, 2.1, 34.5), Vector3(70.0, 4.2, 1.5)],
		[Vector3(-34.5, 2.1, 0.0), Vector3(1.5, 4.2, 70.0)],
		[Vector3(34.5, 2.1, 0.0), Vector3(1.5, 4.2, 70.0)],
	]
	for ps in perim_specs:
		_add_box(arena_root, ps[1], ps[0], wall_mat)

	# Tall North Watchtower Landmark
	var tower := Node3D.new()
	tower.name = "NorthWatchtower"
	tower.position = Vector3(-10.0, 0.0, -34.5)
	_add_box(tower, Vector3(4.5, 11.0, 4.5), Vector3(0.0, 5.5, 0.0), wall_mat)
	_add_box(tower, Vector3(5.2, 1.2, 5.2), Vector3(0.0, 11.4, 0.0), trim_mat)
	_add_cyl(tower, 0.08, 0.14, 4.5, Vector3(1.2, 13.8, 0.0), barrel_mat, 14)
	arena_root.add_child(tower)

	# Distant Sandstone Canyon Ridges & Desert Buttes (MultiMeshInstance3D)
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0
	rock_mesh.radial_segments = 10
	rock_mesh.rings = 6
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color("#927454")
	rock_mat.roughness = 0.96
	rock_mat.metallic = 0.0
	rock_mat.metallic_specular = 0.15
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "CanyonRocks"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock_mesh
	mm.instance_count = 36
	for i in range(36):
		var angle: float = (float(i) / 36.0) * TAU
		var dist: float = 52.0 + float(i % 4) * 14.0
		var pos := Vector3(cos(angle) * dist, 2.0 + float(i % 3) * 1.5, sin(angle) * dist)
		var scl := Vector3(6.0 + float(i % 5) * 2.5, 5.0 + float(i % 4) * 3.5, 6.0 + float((i + 2) % 5) * 2.2)
		var basis := Basis(Vector3.UP, angle * 1.7).scaled(scl)
		mm.set_instance_transform(i, Transform3D(basis, pos))
	mmi.multimesh = mm
	mmi.material_override = rock_mat
	arena_root.add_child(mmi)

	return arena_root

static func _setup_environment_and_lighting(parent: Node3D) -> void:
	# Realistic natural afternoon desert sky (replaces flat bright background & eliminates glare)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3e6d9c")
	sky_mat.sky_horizon_color = Color("#aebbc4")
	sky_mat.sky_curve = 0.14
	sky_mat.ground_bottom_color = Color("#544434")
	sky_mat.ground_horizon_color = Color("#8f7d66")
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 16.0
	sky_mat.sun_curve = 0.10

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_color = Color("#7c8ea2")
	env.ambient_light_energy = 0.36
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Subtle realistic distance haze without washing out mid-range visibility
	env.fog_enabled = true
	env.fog_light_color = Color("#b8ad9b")
	env.fog_light_energy = 0.65
	env.fog_density = 0.0036

	# Balanced filmic tonemapping with controlled exposure (no whiteout glare)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.88
	env.tonemap_white = 4.2
	env.glow_enabled = false

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	parent.add_child(we)

	# Natural directional afternoon sun with clear architectural shadows
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color("#fff0d8")
	sun.light_energy = 1.08
	sun.shadow_enabled = true
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 1.15
	sun.shadow_blur = 1.35
	sun.directional_shadow_max_distance = 110.0
	sun.look_at_from_position(Vector3(34.0, 36.0, 26.0), Vector3.ZERO, Vector3.UP)
	parent.add_child(sun)

	# Gentle sky-bounce fill light to keep shadow sides readable without flattening contrast
	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	rim.light_color = Color("#8fb2d4")
	rim.light_energy = 0.18
	rim.shadow_enabled = false
	rim.look_at_from_position(Vector3(-26.0, 18.0, -30.0), Vector3.ZERO, Vector3.UP)
	parent.add_child(rim)

static func _add_plane(parent: Node3D, size: Vector2, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _add_site_decal(parent: Node3D, tex: Texture2D, pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.82)
	mat.roughness = 0.92
	var mi := _add_plane(parent, Vector2(3.2, 3.2), pos, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _add_cyl(parent: Node3D, rt: float, rb: float, h: float, pos: Vector3, mat: Material, seg: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = rt
	mesh.bottom_radius = rb
	mesh.height = h
	mesh.radial_segments = seg
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

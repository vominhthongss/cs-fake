class_name ProceduralModels
extends RefCounted

## Smooth, rounded procedural 3D weapon viewmodels & sculpted tactical Bot rigs

static var _mats: Dictionary = {}
static var _rbox_cache: Dictionary = {}

static func _get_mats() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	_mats["gunmetal_dark"] = _make_mat(Color("#242930"), 0.36, 0.78)
	_mats["gunmetal_steel"] = _make_mat(Color("#5d6670"), 0.28, 0.84)
	_mats["chrome_slide"] = _make_mat(Color("#bfc8d1"), 0.20, 0.90)
	_mats["polymer_black"] = _make_mat(Color("#1b1e23"), 0.74, 0.12)
	_mats["wood_walnut"] = _make_mat(Color("#7a4625"), 0.64, 0.05)
	_mats["awp_olive"] = _make_mat(Color("#475c38"), 0.66, 0.12)
	_mats["blade_titanium"] = _make_mat(Color("#d2dbe4"), 0.16, 0.94)
	_mats["karambit_accent"] = _make_mat(Color("#d97706"), 0.32, 0.70)
	var scope_mat := _make_mat(Color("#2299cc"), 0.10, 0.85)
	scope_mat.emission_enabled = true
	scope_mat.emission = Color("#0c4a6e")
	scope_mat.emission_energy_multiplier = 0.55
	_mats["scope_glass"] = scope_mat
	_mats["glove"] = _make_mat(Color("#2b2f36"), 0.84, 0.06)
	_mats["sleeve"] = _make_mat(Color("#3a453b"), 0.88, 0.02)
	_mats["skin_shadow"] = _make_mat(Color("#20242a"), 0.90, 0.02)
	_mats["he_body"] = _make_mat(Color("#415239"), 0.58, 0.26)
	_mats["flash_body"] = _make_mat(Color("#9aa4ae"), 0.36, 0.72)
	_mats["grenade_band"] = _make_mat(Color("#d97706"), 0.42, 0.38)
	return _mats

static func _make_mat(col: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

static func _make_rounded_box_mesh(w: float, h: float, d: float, radius_frac: float = 0.32) -> ArrayMesh:
	var key := "%.4f_%.4f_%.4f_%.2f" % [w, h, d, radius_frac]
	if _rbox_cache.has(key):
		return _rbox_cache[key]

	var box := BoxMesh.new()
	box.size = Vector3(w, h, d)
	box.subdivide_width = 6
	box.subdivide_height = 6
	box.subdivide_depth = 6
	var arrays: Array = box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

	var hx: float = w * 0.5
	var hy: float = h * 0.5
	var hz: float = d * 0.5
	var r: float = minf(minf(hx, hy), hz) * clampf(radius_frac, 0.10, 0.48)
	var cx: float = maxf(0.0, hx - r)
	var cy: float = maxf(0.0, hy - r)
	var cz: float = maxf(0.0, hz - r)

	for i in range(verts.size()):
		var p: Vector3 = verts[i]
		var nx: float = p.x / maxf(hx, 0.0001)
		var ny: float = p.y / maxf(hy, 0.0001)
		var nz: float = p.z / maxf(hz, 0.0001)
		var bx: float = signf(nx) * (1.0 - pow(1.0 - minf(1.0, absf(nx)), 1.65)) * hx
		var by: float = signf(ny) * (1.0 - pow(1.0 - minf(1.0, absf(ny)), 1.65)) * hy
		var bz: float = signf(nz) * (1.0 - pow(1.0 - minf(1.0, absf(nz)), 1.65)) * hz
		var bp := Vector3(bx, by, bz)
		var q := Vector3(
			clampf(bp.x, -cx, cx),
			clampf(bp.y, -cy, cy),
			clampf(bp.z, -cz, cz)
		)
		var delta: Vector3 = bp - q
		var dlen: float = delta.length()
		var dir: Vector3 = (delta / dlen) if dlen > 0.00001 else norms[i].normalized()
		verts[i] = q + dir * r
		norms[i] = dir

	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_rbox_cache[key] = mesh
	return mesh

static func _add_rbox(
	parent: Node3D,
	w: float,
	h: float,
	d: float,
	pos: Vector3,
	mat: Material,
	rot: Vector3 = Vector3.ZERO,
	radius_frac: float = 0.34
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _make_rounded_box_mesh(w, h, d, radius_frac)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func _add_cyl(
	parent: Node3D,
	rt: float,
	rb: float,
	h: float,
	pos: Vector3,
	mat: Material,
	rx: float = PI * 0.5,
	seg: int = 24
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = rt
	mesh.bottom_radius = rb
	mesh.height = h
	mesh.radial_segments = seg
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = rx
	parent.add_child(mi)
	return mi

static func _add_capsule(
	parent: Node3D,
	radius: float,
	height: float,
	pos: Vector3,
	mat: Material,
	rot: Vector3 = Vector3.ZERO,
	radial_seg: int = 22,
	rings: int = 8
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0 + 0.002)
	mesh.radial_segments = radial_seg
	mesh.rings = rings
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func _add_sphere(
	parent: Node3D,
	radius: float,
	pos: Vector3,
	mat: Material,
	scl: Vector3 = Vector3.ONE,
	radial_seg: int = 24,
	rings: int = 14
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial_seg
	mesh.rings = rings
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func _add_torus(
	parent: Node3D,
	inner_r: float,
	outer_r: float,
	pos: Vector3,
	mat: Material,
	rot: Vector3 = Vector3.ZERO,
	rings: int = 24,
	ring_seg: int = 12
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_r
	mesh.outer_radius = outer_r
	mesh.rings = rings
	mesh.ring_segments = ring_seg
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func _add_support_hand(parent: Node3D, pos: Vector3, mats: Dictionary) -> void:
	# Rounded palm + fingers gripping handguard
	_add_capsule(parent, 0.028, 0.095, pos, mats["glove"], Vector3(PI * 0.5 + 0.08, 0.14, 0.0), 18, 6)
	_add_sphere(parent, 0.024, pos + Vector3(-0.022, 0.012, -0.015), mats["glove"], Vector3(0.9, 1.0, 1.3), 16, 10)
	_add_capsule(parent, 0.014, 0.055, pos + Vector3(0.022, 0.014, -0.01), mats["glove"], Vector3(0.15, 0.0, 0.45), 14, 5)

static func build_view_model(weapon_id: String) -> Dictionary:
	var mats := _get_mats()
	var root := Node3D.new()
	root.name = "VM_" + weapon_id
	var muzzle := Node3D.new()
	muzzle.name = "MuzzlePoint"
	muzzle.position = Vector3(0.0, 0.04, -0.78)
	root.add_child(muzzle)

	# Smooth sculpted right forearm, wrist cuff & contoured gloved hand
	_add_capsule(root, 0.042, 0.30, Vector3(0.032, -0.105, 0.23), mats["sleeve"], Vector3(PI * 0.5 + 0.18, -0.12, 0.0), 22, 8)
	_add_cyl(root, 0.041, 0.043, 0.032, Vector3(0.018, -0.072, 0.125), mats["glove"], PI * 0.5 + 0.14, 22)
	_add_capsule(root, 0.034, 0.105, Vector3(0.010, -0.056, 0.078), mats["glove"], Vector3(PI * 0.5 + 0.06, -0.04, 0.0), 20, 7)
	_add_sphere(root, 0.022, Vector3(-0.012, -0.042, 0.058), mats["glove"], Vector3(0.95, 0.85, 1.35), 16, 10)

	var slide_or_bolt: Node3D = null

	if weapon_id == "ak47":
		# Rounded receiver & domed steel dust cover
		_add_rbox(root, 0.052, 0.068, 0.34, Vector3(0, 0, -0.04), mats["gunmetal_dark"], Vector3.ZERO, 0.38)
		_add_capsule(root, 0.023, 0.27, Vector3(0, 0.032, -0.03), mats["gunmetal_steel"], Vector3(PI * 0.5, 0, 0), 22, 7)
		# Sculpted walnut buttstock with rounded buttpad
		_add_rbox(root, 0.044, 0.082, 0.24, Vector3(0, -0.02, 0.235), mats["wood_walnut"], Vector3(0.14, 0, 0), 0.44)
		_add_capsule(root, 0.022, 0.082, Vector3(0, -0.036, 0.345), mats["polymer_black"], Vector3(0.14, 0, 0), 18, 6)
		# Rounded walnut handguard (lower + upper heatshield)
		_add_capsule(root, 0.027, 0.235, Vector3(0, -0.008, -0.31), mats["wood_walnut"], Vector3(PI * 0.5, 0, 0), 24, 8)
		_add_capsule(root, 0.021, 0.185, Vector3(0, 0.024, -0.30), mats["wood_walnut"], Vector3(PI * 0.5, 0, 0), 20, 7)
		# Ergonomic rounded pistol grip
		_add_capsule(root, 0.020, 0.115, Vector3(0, -0.078, 0.048), mats["wood_walnut"], Vector3(-0.35, 0, 0), 20, 6)
		# Smooth fluted barrel, gas tube, slant brake & hooded front sight
		_add_cyl(root, 0.011, 0.0125, 0.39, Vector3(0, 0.012, -0.52), mats["gunmetal_steel"], PI * 0.5, 24)
		_add_cyl(root, 0.0095, 0.0095, 0.22, Vector3(0, 0.033, -0.36), mats["gunmetal_dark"], PI * 0.5, 20)
		_add_cyl(root, 0.015, 0.013, 0.045, Vector3(0, 0.012, -0.71), mats["gunmetal_dark"], PI * 0.5, 24)
		_add_torus(root, 0.008, 0.014, Vector3(0, 0.034, -0.65), mats["gunmetal_dark"], Vector3(PI * 0.5, 0, 0), 20, 10)
		# Smooth curved multi-segment banana magazine
		_add_rbox(root, 0.030, 0.125, 0.062, Vector3(0, -0.088, -0.108), mats["gunmetal_steel"], Vector3(0.20, 0, 0), 0.42)
		_add_rbox(root, 0.029, 0.115, 0.058, Vector3(0, -0.185, -0.148), mats["gunmetal_dark"], Vector3(0.46, 0, 0), 0.42)
		_add_support_hand(root, Vector3(-0.015, -0.042, -0.28), mats)
		muzzle.position = Vector3(0.0, 0.012, -0.73)
	elif weapon_id == "m4a1s":
		# Rounded upper/lower receiver & top rail
		_add_rbox(root, 0.050, 0.066, 0.32, Vector3(0, 0, -0.04), mats["gunmetal_dark"], Vector3.ZERO, 0.38)
		_add_rbox(root, 0.038, 0.018, 0.36, Vector3(0, 0.041, -0.14), mats["polymer_black"], Vector3.ZERO, 0.40)
		# Contoured crane stock & cylindrical buffer tube
		_add_cyl(root, 0.017, 0.017, 0.22, Vector3(0, 0.012, 0.20), mats["gunmetal_steel"], PI * 0.5, 22)
		_add_rbox(root, 0.048, 0.072, 0.20, Vector3(0, -0.012, 0.23), mats["polymer_black"], Vector3.ZERO, 0.44)
		# Cylindrical tactical handguard + barrel rings
		_add_capsule(root, 0.028, 0.245, Vector3(0, 0.004, -0.30), mats["polymer_black"], Vector3(PI * 0.5, 0, 0), 26, 8)
		_add_cyl(root, 0.031, 0.031, 0.022, Vector3(0, 0.004, -0.20), mats["gunmetal_steel"], PI * 0.5, 24)
		_add_cyl(root, 0.030, 0.030, 0.020, Vector3(0, 0.004, -0.40), mats["gunmetal_steel"], PI * 0.5, 24)
		# Ergonomic rounded grip & STANAG magazine
		_add_capsule(root, 0.019, 0.112, Vector3(0, -0.078, 0.048), mats["polymer_black"], Vector3(-0.32, 0, 0), 20, 6)
		_add_rbox(root, 0.029, 0.155, 0.056, Vector3(0, -0.108, -0.102), mats["gunmetal_steel"], Vector3(0.08, 0, 0), 0.38)
		# Tubular Red-Dot optic with glowing blue objective lens
		_add_rbox(root, 0.024, 0.022, 0.044, Vector3(0, 0.056, -0.06), mats["gunmetal_dark"], Vector3.ZERO, 0.36)
		_add_cyl(root, 0.020, 0.020, 0.084, Vector3(0, 0.076, -0.06), mats["gunmetal_dark"], PI * 0.5, 24)
		_add_cyl(root, 0.016, 0.016, 0.010, Vector3(0, 0.076, -0.10), mats["scope_glass"], PI * 0.5, 22)
		# Smooth suppressor with knurled end collar
		_add_cyl(root, 0.019, 0.019, 0.27, Vector3(0, 0.008, -0.56), mats["gunmetal_steel"], PI * 0.5, 28)
		_add_cyl(root, 0.021, 0.021, 0.026, Vector3(0, 0.008, -0.44), mats["gunmetal_dark"], PI * 0.5, 26)
		_add_support_hand(root, Vector3(-0.015, -0.042, -0.27), mats)
		muzzle.position = Vector3(0.0, 0.008, -0.71)
	elif weapon_id == "awp":
		# Sculpted rounded olive thumbhole chassis & cheek rest
		_add_rbox(root, 0.056, 0.076, 0.46, Vector3(0, -0.008, -0.06), mats["awp_olive"], Vector3.ZERO, 0.42)
		_add_rbox(root, 0.050, 0.090, 0.26, Vector3(0, -0.022, 0.24), mats["awp_olive"], Vector3.ZERO, 0.44)
		_add_capsule(root, 0.024, 0.14, Vector3(0, 0.032, 0.23), mats["polymer_black"], Vector3(PI * 0.5, 0, 0), 20, 6)
		# Cylindrical steel action & long fluted barrel + rounded brake
		_add_cyl(root, 0.024, 0.024, 0.24, Vector3(0, 0.036, -0.04), mats["gunmetal_dark"], PI * 0.5, 26)
		_add_cyl(root, 0.013, 0.016, 0.56, Vector3(0, 0.030, -0.52), mats["gunmetal_steel"], PI * 0.5, 28)
		_add_rbox(root, 0.028, 0.026, 0.058, Vector3(0, 0.030, -0.80), mats["gunmetal_dark"], Vector3.ZERO, 0.36)
		# Precision Scope with mount rings, turrets, objective bell & ocular lens
		_add_torus(root, 0.017, 0.025, Vector3(0, 0.088, -0.12), mats["gunmetal_dark"], Vector3(PI * 0.5, 0, 0), 22, 10)
		_add_torus(root, 0.017, 0.025, Vector3(0, 0.088, 0.01), mats["gunmetal_dark"], Vector3(PI * 0.5, 0, 0), 22, 10)
		_add_cyl(root, 0.018, 0.018, 0.30, Vector3(0, 0.090, -0.06), mats["gunmetal_dark"], PI * 0.5, 26)
		_add_cyl(root, 0.026, 0.018, 0.10, Vector3(0, 0.090, -0.22), mats["gunmetal_dark"], PI * 0.5, 28)
		_add_cyl(root, 0.023, 0.018, 0.07, Vector3(0, 0.090, 0.09), mats["gunmetal_dark"], PI * 0.5, 26)
		_add_cyl(root, 0.020, 0.020, 0.010, Vector3(0, 0.090, 0.125), mats["scope_glass"], PI * 0.5, 24)
		_add_cyl(root, 0.008, 0.008, 0.022, Vector3(0, 0.112, -0.06), mats["gunmetal_steel"], 0.0, 18)
		# Smooth chrome bolt stem + spherical knob
		var bolt_pivot := Node3D.new()
		bolt_pivot.position = Vector3(0.030, 0.040, 0.04)
		_add_cyl(bolt_pivot, 0.0055, 0.0055, 0.042, Vector3(0.012, 0.0, 0.0), mats["chrome_slide"], 0.0, 16).rotation.z = PI * 0.5
		_add_sphere(bolt_pivot, 0.012, Vector3(0.032, -0.006, 0.0), mats["chrome_slide"], Vector3.ONE, 18, 12)
		root.add_child(bolt_pivot)
		slide_or_bolt = bolt_pivot
		muzzle.position = Vector3(0.0, 0.030, -0.83)
	elif weapon_id == "p90":
		# Futuristic sleek rounded bullpup body
		_add_rbox(root, 0.056, 0.090, 0.42, Vector3(0, -0.012, -0.06), mats["polymer_black"], Vector3.ZERO, 0.45)
		_add_capsule(root, 0.025, 0.30, Vector3(0, 0.042, -0.04), mats["gunmetal_steel"], Vector3(PI * 0.5, 0, 0), 24, 8)
		# Rounded reflex sight hood & lens
		_add_rbox(root, 0.040, 0.038, 0.084, Vector3(0, 0.078, -0.12), mats["gunmetal_dark"], Vector3.ZERO, 0.42)
		_add_cyl(root, 0.013, 0.013, 0.010, Vector3(0, 0.080, -0.16), mats["scope_glass"], PI * 0.5, 20)
		_add_cyl(root, 0.013, 0.013, 0.15, Vector3(0, 0.008, -0.32), mats["gunmetal_steel"], PI * 0.5, 24)
		_add_support_hand(root, Vector3(-0.028, -0.046, -0.22), mats)
		muzzle.position = Vector3(0.0, 0.008, -0.41)
	elif weapon_id == "nova":
		# Rounded shotgun receiver & sculpted stock
		_add_rbox(root, 0.052, 0.068, 0.28, Vector3(0, 0, -0.02), mats["gunmetal_dark"], Vector3.ZERO, 0.42)
		_add_rbox(root, 0.044, 0.082, 0.26, Vector3(0, -0.026, 0.23), mats["polymer_black"], Vector3(0.18, 0, 0), 0.45)
		# Smooth high-segment barrel & magazine tube
		_add_cyl(root, 0.0155, 0.0155, 0.49, Vector3(0, 0.022, -0.38), mats["gunmetal_steel"], PI * 0.5, 26)
		_add_cyl(root, 0.0135, 0.0135, 0.42, Vector3(0, -0.008, -0.35), mats["gunmetal_dark"], PI * 0.5, 24)
		_add_sphere(root, 0.005, Vector3(0, 0.040, -0.61), mats["karambit_accent"], Vector3.ONE, 12, 8)
		# Rounded ribbed cylindrical pump forend
		var pump := _add_capsule(root, 0.027, 0.185, Vector3(0, -0.014, -0.32), mats["polymer_black"], Vector3(PI * 0.5, 0, 0), 24, 8)
		slide_or_bolt = pump
		_add_support_hand(root, Vector3(-0.028, -0.046, -0.32), mats)
		muzzle.position = Vector3(0.0, 0.022, -0.64)
	elif weapon_id == "deagle":
		# Rounded lower frame & heavy chamfered chrome slide
		_add_rbox(root, 0.044, 0.042, 0.24, Vector3(0, 0.008, -0.10), mats["gunmetal_dark"], Vector3.ZERO, 0.36)
		slide_or_bolt = _add_rbox(root, 0.046, 0.044, 0.275, Vector3(0, 0.036, -0.112), mats["chrome_slide"], Vector3.ZERO, 0.34)
		_add_cyl(root, 0.012, 0.012, 0.03, Vector3(0, 0.036, -0.25), mats["gunmetal_dark"], PI * 0.5, 20)
		_add_capsule(root, 0.022, 0.115, Vector3(0, -0.056, -0.012), mats["polymer_black"], Vector3(-0.28, 0, 0), 20, 6)
		_add_torus(root, 0.014, 0.020, Vector3(0, -0.020, -0.075), mats["gunmetal_dark"], Vector3(0, 0, PI * 0.5), 18, 8)
		_add_rbox(root, 0.014, 0.014, 0.018, Vector3(0, 0.062, -0.22), mats["gunmetal_dark"], Vector3.ZERO, 0.35)
		muzzle.position = Vector3(0.0, 0.036, -0.27)
	elif weapon_id == "usps":
		_add_rbox(root, 0.038, 0.034, 0.19, Vector3(0, 0.008, -0.08), mats["polymer_black"], Vector3.ZERO, 0.38)
		slide_or_bolt = _add_rbox(root, 0.040, 0.034, 0.21, Vector3(0, 0.032, -0.09), mats["gunmetal_dark"], Vector3.ZERO, 0.36)
		_add_cyl(root, 0.0155, 0.0155, 0.185, Vector3(0, 0.026, -0.28), mats["gunmetal_steel"], PI * 0.5, 26)
		_add_capsule(root, 0.019, 0.102, Vector3(0, -0.050, -0.012), mats["polymer_black"], Vector3(-0.25, 0, 0), 20, 6)
		_add_torus(root, 0.012, 0.017, Vector3(0, -0.016, -0.068), mats["polymer_black"], Vector3(0, 0, PI * 0.5), 18, 8)
		muzzle.position = Vector3(0.0, 0.026, -0.39)
	elif weapon_id == "karambit":
		# Ergonomic contoured handle + real Torus finger ring + smooth curved 5-segment talon blade
		_add_capsule(root, 0.016, 0.108, Vector3(0, -0.008, -0.048), mats["polymer_black"], Vector3(0.45, 0, 0), 20, 6)
		_add_torus(root, 0.012, 0.021, Vector3(0, -0.052, -0.018), mats["karambit_accent"], Vector3(0, 0, PI * 0.5), 24, 12)
		_add_rbox(root, 0.008, 0.065, 0.030, Vector3(0.0, 0.028, -0.092), mats["blade_titanium"], Vector3(-0.55, 0, 0), 0.42)
		_add_rbox(root, 0.007, 0.060, 0.026, Vector3(0.0, 0.054, -0.138), mats["blade_titanium"], Vector3(-0.92, 0, 0), 0.42)
		_add_rbox(root, 0.006, 0.054, 0.021, Vector3(0.0, 0.066, -0.182), mats["blade_titanium"], Vector3(-1.35, 0, 0), 0.42)
		_add_rbox(root, 0.005, 0.044, 0.014, Vector3(0.0, 0.056, -0.218), mats["blade_titanium"], Vector3(-1.82, 0, 0), 0.42)
		muzzle.position = Vector3(0.0, 0.02, -0.25)
	elif weapon_id == "he_grenade":
		# Rounded ovoid frag grenade + equatorial ribs + fuse + curved spoon + pull ring
		_add_sphere(root, 0.046, Vector3(0, 0.005, -0.10), mats["he_body"], Vector3(0.95, 1.24, 0.95), 26, 16)
		_add_torus(root, 0.040, 0.046, Vector3(0, 0.012, -0.10), mats["grenade_band"], Vector3.ZERO, 24, 10)
		_add_cyl(root, 0.015, 0.018, 0.032, Vector3(0, 0.068, -0.10), mats["gunmetal_steel"], 0.0, 20)
		_add_capsule(root, 0.007, 0.075, Vector3(0.036, 0.030, -0.10), mats["gunmetal_steel"], Vector3(0, 0, -0.35), 14, 5)
		_add_torus(root, 0.012, 0.016, Vector3(-0.024, 0.072, -0.10), mats["chrome_slide"], Vector3(PI * 0.5, 0, 0), 20, 10)
		muzzle.position = Vector3(0.0, 0.02, -0.22)
	else:
		# Sleek rounded cylindrical Flashbang stun grenade + pull ring
		_add_capsule(root, 0.040, 0.126, Vector3(0, 0.008, -0.10), mats["flash_body"], Vector3.ZERO, 26, 8)
		_add_cyl(root, 0.042, 0.042, 0.022, Vector3(0, 0.016, -0.10), mats["grenade_band"], 0.0, 26)
		_add_cyl(root, 0.016, 0.018, 0.030, Vector3(0, 0.076, -0.10), mats["gunmetal_dark"], 0.0, 20)
		_add_capsule(root, 0.007, 0.078, Vector3(0.038, 0.036, -0.10), mats["gunmetal_steel"], Vector3(0, 0, -0.18), 14, 5)
		_add_torus(root, 0.012, 0.016, Vector3(-0.024, 0.078, -0.10), mats["chrome_slide"], Vector3(PI * 0.5, 0, 0), 20, 10)
		muzzle.position = Vector3(0.0, 0.02, -0.22)

	return {
		"root": root,
		"muzzle_point": muzzle,
		"slide_or_bolt": slide_or_bolt,
	}

static func _attach_hitbox(parent: Node3D, size: Vector3, pos: Vector3, region: GameTypes.HitRegion, bot_id: String) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.position = pos
	area.set_meta("hit_region", region)
	area.set_meta("bot_id", bot_id)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	parent.add_child(area)
	return area

static func _build_bot_leg(leg: Node3D, pants_mat: Material, armor_mat: Material, boot_mat: Material) -> void:
	# Rounded thigh, knee pad, tapered calf & sculpted combat boot
	_add_capsule(leg, 0.095, 0.42, Vector3(0, -0.18, 0.0), pants_mat, Vector3.ZERO, 20, 7)
	_add_sphere(leg, 0.088, Vector3(0, -0.37, 0.045), armor_mat, Vector3(0.95, 1.05, 0.65), 18, 10)
	_add_capsule(leg, 0.082, 0.38, Vector3(0, -0.54, -0.01), pants_mat, Vector3.ZERO, 20, 7)
	_add_cyl(leg, 0.086, 0.092, 0.14, Vector3(0, -0.71, 0.0), boot_mat, 0.0, 20)
	_add_capsule(leg, 0.082, 0.27, Vector3(0, -0.785, 0.045), boot_mat, Vector3(PI * 0.5, 0, 0), 18, 6)

static func build_bot_rig(bot_id: String, archetype: GameTypes.BotArchetype) -> Dictionary:
	var mats := _get_mats()
	var root := Node3D.new()
	root.name = "Bot_" + bot_id
	var body_pivot := Node3D.new()
	body_pivot.name = "BodyPivot"
	root.add_child(body_pivot)

	var primary_col := Color("#3b4c60")
	if archetype == GameTypes.BotArchetype.ENTRY:
		primary_col = Color("#8c3e2c")
	elif archetype == GameTypes.BotArchetype.SNIPER:
		primary_col = Color("#31483b")

	var armor_mat := _make_mat(primary_col, 0.70, 0.14)
	var pants_mat := _make_mat(Color("#2d3239"), 0.84, 0.05)
	var boot_mat := _make_mat(Color("#191b1f"), 0.88, 0.08)
	var helmet_mat := _make_mat(Color("#23282e"), 0.46, 0.42)
	var visor_mat := _make_mat(Color("#f59e0b"), 0.22, 0.72)
	visor_mat.emission_enabled = true
	visor_mat.emission = Color("#d97706")
	visor_mat.emission_energy_multiplier = 0.75

	# Sculpted Legs
	var leg_l := Node3D.new()
	leg_l.position = Vector3(-0.15, 0.85, 0.0)
	_build_bot_leg(leg_l, pants_mat, helmet_mat, boot_mat)
	_attach_hitbox(leg_l, Vector3(0.22, 0.86, 0.26), Vector3(0, -0.43, 0), GameTypes.HitRegion.LIMB, bot_id)
	body_pivot.add_child(leg_l)

	var leg_r := Node3D.new()
	leg_r.position = Vector3(0.15, 0.85, 0.0)
	_build_bot_leg(leg_r, pants_mat, helmet_mat, boot_mat)
	_attach_hitbox(leg_r, Vector3(0.22, 0.86, 0.26), Vector3(0, -0.43, 0), GameTypes.HitRegion.LIMB, bot_id)
	body_pivot.add_child(leg_r)

	# Rounded Pelvis / Tactical Belt
	_add_capsule(body_pivot, 0.145, 0.44, Vector3(0, 0.89, 0), pants_mat, Vector3(0, 0, PI * 0.5), 22, 7)
	_add_rbox(body_pivot, 0.46, 0.08, 0.30, Vector3(0, 0.92, 0.0), helmet_mat, Vector3.ZERO, 0.45)

	# Sculpted Torso, Rounded Plate Carrier & Contoured Backpack
	_add_rbox(body_pivot, 0.46, 0.56, 0.28, Vector3(0, 1.20, 0.0), armor_mat, Vector3.ZERO, 0.44)
	_add_rbox(body_pivot, 0.40, 0.42, 0.33, Vector3(0, 1.22, 0.02), helmet_mat, Vector3.ZERO, 0.42)
	# Chest mag pouches (rounded)
	for px in [-0.10, 0.0, 0.10]:
		_add_rbox(body_pivot, 0.075, 0.13, 0.065, Vector3(px, 1.12, 0.175), armor_mat, Vector3.ZERO, 0.42)
	# Rounded Tactical Backpack + top roll
	_add_rbox(body_pivot, 0.32, 0.40, 0.17, Vector3(0, 1.22, -0.20), pants_mat, Vector3.ZERO, 0.45)
	_add_capsule(body_pivot, 0.055, 0.30, Vector3(0, 1.43, -0.20), armor_mat, Vector3(0, 0, PI * 0.5), 18, 6)
	# Collar / Neck
	_add_cyl(body_pivot, 0.082, 0.095, 0.13, Vector3(0, 1.52, 0.0), mats["skin_shadow"], 0.0, 20)
	_attach_hitbox(body_pivot, Vector3(0.52, 0.68, 0.38), Vector3(0, 1.18, -0.02), GameTypes.HitRegion.CHEST, bot_id)

	# Smooth Head + Rounded Ballistic Dome Helmet + Curved Glowing Visor
	var head_group := Node3D.new()
	head_group.position = Vector3(0.0, 1.66, 0.0)
	# Balaclava cranium
	_add_sphere(head_group, 0.145, Vector3(0, -0.005, 0), mats["skin_shadow"], Vector3(0.96, 1.05, 1.0), 24, 14)
	# Rounded ballistic helmet shell (ellipsoid dome + ear protectors)
	_add_sphere(head_group, 0.172, Vector3(0, 0.036, -0.012), helmet_mat, Vector3(1.02, 0.86, 1.06), 26, 16)
	_add_sphere(head_group, 0.062, Vector3(-0.155, 0.0, -0.01), helmet_mat, Vector3(0.65, 1.1, 1.0), 16, 10)
	_add_sphere(head_group, 0.062, Vector3(0.155, 0.0, -0.01), helmet_mat, Vector3(0.65, 1.1, 1.0), 16, 10)
	# Curved tactical visor goggles
	var visor_mesh := _add_capsule(head_group, 0.044, 0.245, Vector3(0, 0.012, 0.132), visor_mat, Vector3(0, 0, PI * 0.5), 22, 8)
	visor_mesh.scale = Vector3(0.85, 1.0, 0.58)
	_attach_hitbox(head_group, Vector3(0.36, 0.34, 0.36), Vector3(0, 0.02, 0), GameTypes.HitRegion.HEAD, bot_id)
	body_pivot.add_child(head_group)

	# Smooth Left Shoulder + Articulated Arm + Gloved Hand
	_add_sphere(body_pivot, 0.105, Vector3(-0.29, 1.40, 0.0), armor_mat, Vector3(1.0, 0.92, 1.0), 18, 12)
	_add_capsule(body_pivot, 0.072, 0.30, Vector3(-0.31, 1.27, 0.07), armor_mat, Vector3(-0.55, 0, 0), 18, 6)
	_add_capsule(body_pivot, 0.062, 0.24, Vector3(-0.27, 1.16, 0.21), armor_mat, Vector3(-1.05, 0.22, 0), 18, 6)
	_add_sphere(body_pivot, 0.058, Vector3(-0.18, 1.14, 0.34), mats["glove"], Vector3.ONE, 16, 10)
	_attach_hitbox(body_pivot, Vector3(0.18, 0.48, 0.22), Vector3(-0.32, 1.22, 0.10), GameTypes.HitRegion.LIMB, bot_id)

	# Smooth Right Shoulder + Arm + Rounded Weapon (faces +Z in bot local space)
	var arm_r := Node3D.new()
	arm_r.position = Vector3(0.29, 1.38, 0.04)
	_add_sphere(arm_r, 0.105, Vector3(0.0, 0.02, -0.04), armor_mat, Vector3(1.0, 0.92, 1.0), 18, 12)
	_add_capsule(arm_r, 0.070, 0.34, Vector3(0.0, -0.05, 0.12), armor_mat, Vector3(PI * 0.5 + 0.12, 0, 0), 18, 6)
	_add_capsule(arm_r, 0.060, 0.24, Vector3(-0.02, -0.05, 0.32), armor_mat, Vector3(PI * 0.5, -0.10, 0), 18, 6)
	_add_sphere(arm_r, 0.056, Vector3(-0.05, -0.04, 0.44), mats["glove"], Vector3.ONE, 16, 10)

	# Rounded Bot Rifle / Sniper
	var is_sniper := (archetype == GameTypes.BotArchetype.SNIPER)
	_add_rbox(arm_r, 0.062, 0.088, 0.56, Vector3(-0.05, -0.015, 0.46), mats["awp_olive"] if is_sniper else mats["gunmetal_dark"], Vector3.ZERO, 0.40)
	_add_rbox(arm_r, 0.036, 0.14, 0.068, Vector3(-0.05, -0.10, 0.56), mats["gunmetal_steel"], Vector3(-0.18, 0, 0), 0.38)
	_add_cyl(arm_r, 0.015, 0.017, 0.58 if is_sniper else 0.38, Vector3(-0.05, 0.005, 0.92 if is_sniper else 0.82), mats["gunmetal_steel"], PI * 0.5, 22)
	if is_sniper:
		_add_cyl(arm_r, 0.024, 0.020, 0.28, Vector3(-0.05, 0.065, 0.48), mats["gunmetal_dark"], PI * 0.5, 22)
		_add_cyl(arm_r, 0.020, 0.020, 0.012, Vector3(-0.05, 0.065, 0.62), mats["scope_glass"], PI * 0.5, 18)
	var muzzle_point := Node3D.new()
	muzzle_point.position = Vector3(-0.05, 0.005, 1.22 if is_sniper else 1.02)
	arm_r.add_child(muzzle_point)
	body_pivot.add_child(arm_r)

	# Grounded contact shadow disc
	var contact_shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.55
	disc.height = 0.01
	disc.radial_segments = 24
	contact_shadow.mesh = disc
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.04, 0.035, 0.03, 0.40)
	contact_shadow.material_override = shadow_mat
	contact_shadow.position = Vector3(0.0, 0.015, 0.0)
	contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(contact_shadow)

	return {
		"root": root,
		"body_pivot": body_pivot,
		"leg_l": leg_l,
		"leg_r": leg_r,
		"arm_r": arm_r,
		"head_group": head_group,
		"visor_mesh": visor_mesh,
		"visor_mat": visor_mat,
		"armor_mat": armor_mat,
		"muzzle_point": muzzle_point,
		"contact_shadow": contact_shadow,
	}

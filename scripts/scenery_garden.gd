extends Node3D
## Original, collision-free outdoor scenery. Repeated plants and rocks are
## batched with MultiMesh; the native course colliders stay in CourseView3D.

const TURF = preload("res://shaders/turf.gdshader")
const WATER = preload("res://shaders/lagoon_water.gdshader")
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var _meshes: Dictionary = {}
var _random := RandomNumberGenerator.new()
var _theme := 0
var _water_materials: Array[ShaderMaterial] = []


func build(theme: int) -> void:
	_theme = theme
	_random.seed = 83117 + theme * 1307
	_build_landscape()
	_build_garden_edge()
	_build_distant_landmarks()
	_flush_batches()
	name = "OriginalOutdoorScenery"


func animate(elapsed: float) -> void:
	for material in _water_materials:
		material.set_shader_parameter("water_time", elapsed)


func turf_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TURF
	material.set_shader_parameter("turf_color", color)
	material.set_shader_parameter("stripe_phase", float(_theme) * 0.74)
	return material


func water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER
	_water_materials.append(material)
	return material


func _build_landscape() -> void:
	# The landscape rises only outside the playable rectangle. It carries no
	# physics shape and cannot change a ramp, a jump or a saved ball position.
	var noise := FastNoiseLite.new()
	noise.seed = 7189 + _theme * 541
	noise.frequency = 0.075
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for z in range(-24, 24, 2):
		for x in range(-24, 24, 2):
			var corners: Array[Vector3] = []
			for offset: Vector2 in [Vector2(0, 0), Vector2(2, 0), Vector2(0, 2), Vector2(2, 2)]:
				var point := Vector2(x, z) + offset
				var separation := maxf(absf(point.x) - 3.7, absf(point.y) - 5.3)
				var height := -0.38
				if _theme == 2:
					# A narrow sandy island gives way to the visible lagoon rather
					# than burying the water beneath a continuous flat ground mesh.
					height = lerpf(-0.23, -0.85, clampf((separation - 0.35) / 1.35, 0.0, 1.0))
				if separation > 0.0:
					height += maxf(noise.get_noise_2d(point.x, point.y) + 0.3, 0.0) * minf(separation * 0.48, 3.7)
				corners.append(Vector3(point.x, height, point.y))
			var base := Color("607e44") if _theme == 0 else (Color("99774b") if _theme == 1 else Color("a99968"))
			var shade := _random.randf_range(0.89, 1.09)
			surface.set_color(Color(base.r * shade, base.g * shade, base.b * shade))
			for index: int in [0, 1, 2, 1, 3, 2]:
				surface.add_vertex(corners[index])
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	_mesh_instance(surface.commit(), material)
	if _theme == 2:
		var lake := PlaneMesh.new()
		lake.size = Vector2(40.0, 42.0)
		var lake_instance := _mesh_instance(lake, water_material())
		lake_instance.position = Vector3(0.0, -0.29, -1.0)


func _build_garden_edge() -> void:
	# Low ground cover keeps the tee and fairway readable in a low camera.
	for side: float in [-1.0, 1.0]:
		for index in range(12):
			var z := -4.75 + float(index) * 0.87
			var x := side * _random.randf_range(3.45, 4.08)
			var point := Vector3(x, -0.24, z)
			if _theme == 0:
				_bush(point, _random.randf_range(0.28, 0.48))
				if index % 2 == 0:
					_flowers(point + Vector3(side * 0.28, 0.03, -0.28), 5)
			elif _theme == 1:
				_rock(point, Vector3(0.25, 0.26, 0.29), Color("bc9264"))
				if index % 3 == 0:
					_grass(point + Vector3(side * 0.2, 0, 0.26), 0.45)
			else:
				_rock(point, Vector3(0.23, 0.20, 0.35), Color("a9b5a0"))
				_grass(point + Vector3(side * 0.24, 0, 0.18), 0.50)
			if index % 3 == 0:
				var taller := Vector3(side * _random.randf_range(5.0, 6.7), -0.18, z - 0.35)
				if _theme == 0:
					_tree(taller, _random.randf_range(0.85, 1.25))
				elif _theme == 1:
					_cedar(taller, _random.randf_range(0.85, 1.35))
				else:
					_palm(taller, _random.randf_range(0.85, 1.25))
	for index in range(9):
		var point := Vector3(-6.5 + index * 1.65, -0.25, -6.5 - _random.randf_range(0.0, 2.0))
		if _theme == 0:
			_pine(point, _random.randf_range(1.0, 1.65))
		elif _theme == 1:
			_rock(point, Vector3(1.15, 1.2 + index % 3 * 0.4, 1.0), Color("c59461"))
		else:
			_palm(point, _random.randf_range(0.8, 1.4))
	# Original course entrance: stepping stones and a wooden arch well behind
	# the tee, outside the ball's collision mask and view of the putting line.
	for index in range(4):
		_add("flat_rock", Vector3(-0.25 + (index % 2) * 0.44, -0.28, 5.05 + index * 0.44), Vector3(0.33, 0.055, 0.27), Color("d8c8a8"), float(index) * 0.31)
	_box_part(Vector3(-1.10, 0.42, 6.65), Vector3(0.15, 1.45, 0.15), Color("68533f"))
	_box_part(Vector3(1.10, 0.42, 6.65), Vector3(0.15, 1.45, 0.15), Color("68533f"))
	_box_part(Vector3(0, 1.17, 6.65), Vector3(2.55, 0.15, 0.2), Color("ad8759"))
	for side: float in [-1.0, 1.0]:
		_bush(Vector3(side * 1.46, -0.24, 6.4), 0.62)


func _build_distant_landmarks() -> void:
	if _theme == 0:
		# A small pergola and winding edge stones give the garden a destination.
		for x: float in [-1.4, 1.4]:
			for z: float in [-10.0, -11.6]:
				_box_part(Vector3(x, 0.68, z), Vector3(0.18, 2.0, 0.18), Color("90704c"))
		for index in range(7):
			_box_part(Vector3(-1.62 + index * 0.54, 1.76, -10.8), Vector3(0.17, 0.13, 2.35), Color("b59161"))
		for index in range(7):
			_bush(Vector3(-2.1 + index * 0.7, 1.45, -11.9), 0.44)
		for index in range(9):
			_rock(Vector3(7.0 + sin(index * 0.7) * 0.5, -0.22, -5.0 + index * 0.8), Vector3(0.5, 0.3, 0.4), Color("bdc5ab"))
	elif _theme == 1:
		# Warm terraces: staggered natural slabs instead of copied canyon assets.
		for side: float in [-1.0, 1.0]:
			for index in range(4):
				var point := Vector3(side * (7.0 + index * 0.7), -0.23, -6.5 + index * 2.0)
				for level in range(3):
					_box_part(point + Vector3(0.0, level * 0.58, 0.0), Vector3(2.15 - level * 0.25, 0.62, 1.6 - level * 0.22), Color("bf925b").lightened(level * 0.04), side * (0.11 + level * 0.02))
		for index in range(5):
			_cedar(Vector3(-8.0 + index * 4.0, -0.24, -13.0), 1.25)
	else:
		# A lagoon jetty with lanterns, shells and lush palms.
		for index in range(12):
			_box_part(Vector3(5.8, -0.07, 0.8 + index * 0.33), Vector3(1.6, 0.11, 0.27), Color("b18d60"))
		for side: float in [-1.0, 1.0]:
			for index in range(3):
				_box_part(Vector3(5.8 + side * 0.88, -0.18, 0.7 + index * 1.83), Vector3(0.13, 0.78, 0.13), Color("705942"))
		for index in range(14):
			var angle := float(index) * TAU / 14.0
			_rock(Vector3(cos(angle) * 9.0, -0.28, sin(angle) * 11.0), Vector3(0.65, 0.42, 0.52), Color("b9c4b5"))


func _tree(point: Vector3, scale_factor: float) -> void:
	_add("trunk", point + Vector3(0, 0.78, 0) * scale_factor, Vector3(0.15, 1.65, 0.15) * scale_factor, Color("8a6744"))
	for offset: Vector3 in [Vector3(-0.40, 1.95, 0.10), Vector3(0.46, 2.0, -0.03), Vector3(0.03, 2.45, 0.09)]:
		_add("leaf", point + offset * scale_factor, Vector3(0.85, 0.72, 0.78) * scale_factor, Color("4f7f40").lightened(_random.randf_range(0.0, 0.13)), _random.randf() * TAU)
	_add("leaf", point + Vector3(0, 1.70, -0.20) * scale_factor, Vector3(0.95, 0.55, 0.82) * scale_factor, Color("3e703c"))


func _pine(point: Vector3, scale_factor: float) -> void:
	_add("trunk", point + Vector3(0, 0.48, 0) * scale_factor, Vector3(0.12, 1.2, 0.12) * scale_factor, Color("805b3d"))
	for index in range(3):
		var width := 1.08 - index * 0.22
		_add("cone", point + Vector3(0, 0.92 + index * 0.64, 0) * scale_factor, Vector3(width, 1.25, width) * scale_factor, Color("3e7350").lightened(index * 0.045))


func _cedar(point: Vector3, scale_factor: float) -> void:
	_add("trunk", point + Vector3(0, 0.86, 0) * scale_factor, Vector3(0.11, 1.88, 0.11) * scale_factor, Color("826345"))
	for index in range(4):
		_add("leaf", point + Vector3(sin(index * 2.8) * 0.23, 1.65 + index * 0.2, cos(index * 2.8) * 0.16) * scale_factor, Vector3(0.78, 0.23, 0.61) * scale_factor, Color("668553").lightened(index * 0.025), index * 0.6)


func _palm(point: Vector3, scale_factor: float) -> void:
	var trunk_basis := Basis(Vector3.FORWARD, 0.11)
	_add("trunk", point + Vector3(-0.11, 1.06, 0) * scale_factor, Vector3(0.10, 2.30, 0.10) * scale_factor, Color("b49863"), 0.0, trunk_basis)
	for index in range(7):
		var angle := float(index) * TAU / 7.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var basis := Basis(Vector3.UP, -angle) * Basis(Vector3.FORWARD, -0.12)
		_add("palm_leaf", point + (Vector3(-0.20, 2.17, 0) + direction * 0.61) * scale_factor, Vector3(1.60, 0.13, 0.38) * scale_factor, Color("4e9a64").lightened(index % 2 * 0.06), 0.0, basis)
	_add("leaf", point + Vector3(-0.20, 2.14, 0) * scale_factor, Vector3(0.23, 0.18, 0.23) * scale_factor, Color("607b45"))


func _bush(point: Vector3, size: float) -> void:
	for index in range(3):
		_add("leaf", point + Vector3((index - 1) * size * 0.43, size * 0.44, sin(index * 2.0) * size * 0.20), Vector3(size * 0.64, size * 0.54, size * 0.66), Color("4e7b43").lightened(index * 0.05), index * 0.4)


func _rock(point: Vector3, size: Vector3, color: Color) -> void:
	_add("rock", point + Vector3(0, size.y * 0.52, 0), size, color.lightened(_random.randf_range(-0.03, 0.05)), _random.randf() * TAU)


func _flowers(point: Vector3, count: int) -> void:
	var colors: Array[Color] = [Color("eecb62"), Color("f1b497"), Color("bfa9d1")]
	for index in range(count):
		var offset := Vector3(_random.randf_range(-0.20, 0.20), 0, _random.randf_range(-0.18, 0.18))
		_add("trunk", point + offset + Vector3(0, 0.095, 0), Vector3(0.012, 0.20, 0.012), Color("578b48"))
		_add("flower", point + offset + Vector3(0, 0.21, 0), Vector3(0.06, 0.035, 0.06), colors[index % colors.size()])


func _grass(point: Vector3, height: float) -> void:
	for index in range(5):
		var angle := float(index) * TAU / 5.0
		var basis := Basis(Vector3.UP, angle) * Basis(Vector3.FORWARD, 0.20)
		_add("cone", point + Vector3(cos(angle) * 0.055, height * 0.47, sin(angle) * 0.055), Vector3(0.035, height, 0.07), Color("7f9f53"), 0, basis)


func _box_part(point: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	_add("box", point, size, color, yaw)


func _add(kind: String, point: Vector3, size: Vector3, color: Color, yaw: float = 0.0, orientation: Basis = Basis.IDENTITY) -> void:
	# Quantize palettes so repeated objects share draw calls rather than one
	# material and one Node per leaf. All parts are small, bounded static data.
	var palette := Color(snappedf(color.r, 0.04), snappedf(color.g, 0.04), snappedf(color.b, 0.04))
	var key := kind + palette.to_html(false)
	if not _batches.has(key):
		_batches[key] = {"kind": kind, "color": palette, "transforms": []}
	var basis := Basis(Vector3.UP, yaw) * orientation
	_batches[key]["transforms"].append(Transform3D(basis.scaled(size), point))


func _flush_batches() -> void:
	for key: String in _batches:
		var batch: Dictionary = _batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _shape(batch["kind"])
		var transforms: Array = batch["transforms"]
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _material(batch["color"])
		instance.name = "Scenery_" + batch["kind"]
		add_child(instance)
	_batches.clear()


func _shape(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mesh: Mesh
	if kind in ["trunk", "cone"]:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.0 if kind == "cone" else 1.0
		cylinder.bottom_radius = 1.0
		cylinder.height = 1.0
		cylinder.radial_segments = 7
		mesh = cylinder
	elif kind == "box":
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		mesh = box
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 7 if kind == "rock" or kind == "flat_rock" else 9
		sphere.rings = 3 if kind == "rock" or kind == "flat_rock" else 4
		mesh = sphere
	_meshes[kind] = mesh
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	_materials[key] = material
	return material


func _mesh_instance(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	return instance

class_name CourseView3D
extends Node3D

## A real 3D diorama. The original course coordinates are retained as an
## X/Z navigation grid; elevation, collisions and camera projection are 3D.
const Session = preload("res://scripts/golf_session.gd")
const Config = preload("res://scripts/game_config.gd")
const Scenery = preload("res://scripts/scenery_garden.gd")
const WORLD_SCALE := 0.01
const MAP_CENTER := Vector2(360.0, 650.0)
const BALL_RADIUS := 0.14
const FLOOR_LAYER := 1
const WALL_LAYER := 2

var ball: CharacterBody3D
var camera: Camera3D
var _session
var _course_index := -1
var _terrain: Node3D
var _ball_mesh: MeshInstance3D
var _ball_shadow: MeshInstance3D
var _ready_ring: MeshInstance3D
var _aim: Node3D
var _flag: Node3D
var _last_position := Vector3.ZERO
var _camera_fitted := false
var _aim_cache := Vector4(INF, INF, INF, INF)
var _scenery
var _trail: Array[MeshInstance3D] = []
var _trail_times: PackedFloat32Array = []
var _trail_cursor := 0
var _trail_previous := Vector3.ZERO
var _capture_rings: Array[MeshInstance3D] = []
var _capture_started := -1.0
var _last_state := -1
var _aim_segments: Array[MeshInstance3D] = []
var _aim_dots: Array[MeshInstance3D] = []
var _aim_pull: MeshInstance3D
var _aim_handle: MeshInstance3D
var _aim_material: StandardMaterial3D


func _ready() -> void:
	_build_scene()


func setup(session) -> void:
	if ball == null:
		_build_scene()
	_session = session
	_build_course(session.course_index)
	sync(session, 0.0)


func map_to_world(point: Vector2, elevation: float = BALL_RADIUS) -> Vector3:
	return Vector3((point.x - MAP_CENTER.x) * WORLD_SCALE, elevation, (point.y - MAP_CENTER.y) * WORLD_SCALE)


func world_to_map(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z) / WORLD_SCALE + MAP_CENTER


func terrain_height(point: Vector2) -> float:
	# These heights describe the same surfaces used to build the static meshes.
	match _course_index:
		0:
			if point.x >= 480.0 and point.x <= 620.0:
				if point.y >= 400.0 and point.y <= 520.0:
					return 0.30
				if point.y > 520.0 and point.y <= 740.0:
					return (740.0 - point.y) / 220.0 * 0.30
		1:
			return clampf((700.0 - point.y) / 250.0, 0.0, 1.0) * 0.60
		2:
			if point.x >= 520.0 and point.x <= 646.0 and point.y >= 640.0 and point.y <= 740.0:
				return (740.0 - point.y) / 100.0 * 0.34
	return 0.0


func hole_world_position() -> Vector3:
	if _session == null:
		return Vector3.ZERO
	var point: Vector2 = _session.current_course()["hole"]
	return map_to_world(point, support_height(point))


func terrain_normal(point: Vector2) -> Vector3:
	if _course_index == 0 and point.x >= 480.0 and point.x <= 620.0 and point.y > 520.0 and point.y < 740.0:
		return Vector3(0.0, 1.0, 0.30 / 2.20).normalized()
	if _course_index == 1 and point.y > 450.0 and point.y < 700.0:
		return Vector3(0.0, 1.0, 0.60 / 2.50).normalized()
	if _course_index == 2 and point.x >= 520.0 and point.x <= 646.0 and point.y > 640.0 and point.y < 740.0:
		return Vector3(0.0, 1.0, 0.34).normalized()
	return Vector3.UP


func support_height(point: Vector2) -> float:
	# A sphere's center is R / normal.y above a sloped surface at the same X/Z.
	return terrain_height(point) + BALL_RADIUS / terrain_normal(point).y


func hole_worldpoint() -> Vector3:
	return hole_world_position()


func project_map(point: Vector2, elevation: float = -1.0) -> Vector2:
	if camera == null:
		return Vector2(INF, INF)
	if elevation < 0.0:
		elevation = support_height(point)
		if _session != null and point.distance_to(_session.position) < 0.1:
			elevation = ball.position.y
	return camera.unproject_position(map_to_world(point, elevation))


func unproject_map(pixel: Vector2, elevation: float = -1.0) -> Vector2:
	if camera == null or not pixel.is_finite():
		return Vector2(INF, INF)
	if elevation < 0.0:
		elevation = ball.position.y
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	if absf(direction.y) < 0.00001:
		return Vector2(INF, INF)
	var distance := (elevation - origin.y) / direction.y
	if distance < 0.0:
		return Vector2(INF, INF)
	return world_to_map(origin + direction * distance)


func sync(session, elapsed: float) -> void:
	_session = session
	if ball == null:
		_build_scene()
	if _course_index != session.course_index:
		_build_course(session.course_index)
	# NativePhysics3D owns the body's full 3D position while it is moving.
	if session.state != Session.State.MOVING:
		var point: Vector2 = session.position
		if session.state == Session.State.MENU or session.state == Session.State.RESULT:
			point = session.current_course()["start"]
		var height := support_height(point)
		if session.state in [Session.State.READY, Session.State.AIMING] and "elevation" in session:
			if world_to_map(ball.position).distance_to(point) < 0.01 and is_finite(session.elevation):
				height = session.elevation
		ball.position = map_to_world(point, height)
		ball.velocity = Vector3.ZERO
		if "elevation" in session:
			session.elevation = ball.position.y
		if "vertical_velocity" in session:
			session.vertical_velocity = 0.0
	var displacement := ball.position - _last_position
	if displacement.length() > 0.00001 and displacement.length() < 0.5:
		var axis := Vector3(displacement.z, 0.0, -displacement.x).normalized()
		if axis.length_squared() > 0.0:
			_ball_mesh.rotate(axis, Vector2(displacement.x, displacement.z).length() / BALL_RADIUS)
	_last_position = ball.position
	var captured: bool = session.state == Session.State.CAPTURED
	_ball_mesh.scale = Vector3.ONE * (0.62 if captured else 1.0)
	_ball_shadow.position = Vector3(ball.position.x, terrain_height(world_to_map(ball.position)) + 0.008, ball.position.z)
	_ball_shadow.visible = ball.position.y < terrain_height(world_to_map(ball.position)) + 1.5
	_ready_ring.position = Vector3(ball.position.x, terrain_height(world_to_map(ball.position)) + 0.018, ball.position.z)
	_ready_ring.visible = session.state == Session.State.READY and not session.is_paused()
	_ready_ring.scale = Vector3.ONE * (1.0 + sin(elapsed * 3.0) * 0.06)
	_update_aim(session)
	if _flag != null:
		_flag.rotation.y = sin(elapsed * 1.1) * 0.08
	if _scenery != null:
		_scenery.animate(elapsed)
	_update_effects(session, elapsed)
	if not _camera_fitted and is_inside_tree():
		_fit_camera()


func _build_scene() -> void:
	if ball != null:
		return
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("8bc5e7")
	sky_material.sky_horizon_color = Color("e8edcf")
	sky_material.ground_bottom_color = Color("738758")
	sky_material.ground_horizon_color = Color("e8edcf")
	sky_material.sky_curve = 0.18
	sky_material.sky_energy_multiplier = 0.70
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d4e4c8")
	settings.ambient_light_energy = 0.40
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47.0, -35.0, 0.0)
	sun.light_color = Color("ffefd0")
	sun.light_energy = 0.90
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-4.0, 5.0, 2.0)
	fill.light_color = Color("c8e9d1")
	fill.light_energy = 0.22
	fill.omni_range = 14.0
	add_child(fill)
	camera = Camera3D.new()
	camera.name = "CourseCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 14.0
	camera.near = 0.1
	camera.far = 60.0
	# A small yaw preserves depth while using the vertical phone layout well.
	camera.position = Vector3(0.85, 12.5, 8.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.25, 0.0))
	camera.current = true
	ball = CharacterBody3D.new()
	ball.name = "Ball3D"
	ball.collision_layer = 4
	ball.collision_mask = FLOOR_LAYER | WALL_LAYER
	ball.safe_margin = 0.00001
	ball.floor_stop_on_slope = false
	ball.floor_snap_length = 0.035
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = BALL_RADIUS
	var sphere_collider := CollisionShape3D.new()
	sphere_collider.shape = sphere_shape
	ball.add_child(sphere_collider)
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_ball_mesh = _mesh(sphere, _material(Color("f3f6fa"), 0.3), ball)
	_ball_mesh.name = "BallMesh"
	var stripe := TorusMesh.new()
	stripe.inner_radius = BALL_RADIUS - 0.004
	stripe.outer_radius = BALL_RADIUS + 0.001
	stripe.rings = 32
	stripe.ring_segments = 8
	var band := _mesh(stripe, _material(Color("50d9d0"), 0.4), _ball_mesh)
	band.rotation_degrees.z = 32.0
	add_child(ball)
	_ball_shadow = _disc(0.19, 0.006, Color("102d2d"), self)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.31
	ring.outer_radius = 0.33
	ring.rings = 48
	ring.ring_segments = 8
	_ready_ring = _mesh(ring, _material(Color("50d9d0"), 0.9, true), self)
	_aim = Node3D.new()
	_aim.name = "AimArrow3D"
	add_child(_aim)
	_build_aim_pool()
	_build_effect_pool()


func _build_course(index: int) -> void:
	if _terrain != null:
		remove_child(_terrain)
		_terrain.queue_free()
	_course_index = index
	_terrain = Node3D.new()
	_terrain.name = "CourseGeometry3D"
	add_child(_terrain)
	_scenery = Scenery.new()
	_terrain.add_child(_scenery)
	_scenery.build(index)
	var course: Dictionary = _session.current_course()
	var bounds: Rect2 = course["bounds"]
	var earth := Color("9a9b6a") if index == 0 else (Color("bd9a67") if index == 1 else Color("c5b68b"))
	_box(map_to_world(bounds.get_center(), -0.30), Vector3(bounds.size.x * WORLD_SCALE + 0.12, 0.38, bounds.size.y * WORLD_SCALE + 0.12), earth, _terrain)
	match index:
		0:
			_floor_patch(bounds, 0.0, 0.0, Color("70a047"))
			_floor_patch(Rect2(480, 520, 140, 220), 0.30, 0.0, Color("78a64d"))
			_floor_patch(Rect2(480, 400, 140, 120), 0.30, 0.30, Color("78a64d"))
		1:
			_floor_patch(Rect2(64, 700, 592, 400), 0.0, 0.0, Color("7fa348"))
			_floor_patch(Rect2(64, 450, 592, 250), 0.60, 0.0, Color("87ab4f"))
			_floor_patch(Rect2(64, 200, 592, 250), 0.60, 0.60, Color("7b9e48"))
		2:
			_floor_patch(Rect2(64, 640, 592, 460), 0.0, 0.0, Color("64a467"))
			_floor_patch(Rect2(64, 200, 592, 260), 0.0, 0.0, Color("64a467"))
			_floor_patch(Rect2(64, 460, 456, 180), 0.0, 0.0, Color("64a467"))
			_floor_patch(Rect2(520, 640, 126, 100), 0.34, 0.0, Color("72b16d"))
			_build_water(course["hazard"])
	_build_rails(bounds)
	for wall: Rect2 in course["walls"]:
		_wall(wall)
	_build_hole(course["hole"])
	var start: Vector2 = course["start"]
	var start_mark := _disc(0.27, 0.006, Color("acc883"), _terrain)
	start_mark.position = map_to_world(start, terrain_height(start) + 0.01)
	for side: float in [-1.0, 1.0]:
		var tee := _disc(0.038, 0.048, Color("f0ddaf"), _terrain)
		tee.position = map_to_world(start + Vector2(side * 35.0, 0), terrain_height(start) + 0.028)
	_last_position = map_to_world(start, terrain_height(start) + BALL_RADIUS)
	_camera_fitted = false
	_trail_previous = Vector3.ZERO
	for trail in _trail:
		trail.visible = false
	_capture_started = -1.0
	_last_state = -1


func _floor_patch(rect: Rect2, top_height: float, bottom_height: float, color: Color) -> void:
	# An extruded prism gives ramps a real sloped collision surface and sides.
	var corners: Array[Vector3] = [
		map_to_world(rect.position, top_height),
		map_to_world(Vector2(rect.end.x, rect.position.y), top_height),
		map_to_world(rect.end, bottom_height),
		map_to_world(Vector2(rect.position.x, rect.end.y), bottom_height),
	]
	var vertices := PackedVector3Array()
	for point in corners:
		vertices.append(point)
	for point in corners:
		vertices.append(Vector3(point.x, -0.16, point.z))
	var indices := PackedInt32Array([0, 3, 1, 1, 3, 2, 0, 1, 4, 1, 5, 4, 1, 2, 5, 2, 6, 5, 2, 3, 6, 3, 7, 6, 3, 0, 7, 0, 4, 7])
	var faces := PackedVector3Array()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for offset in range(0, indices.size(), 3):
		# Godot renders clockwise faces. Physics triangle normals use the
		# mathematical winding, so the visible and collider lists differ.
		for triangle_index: int in [0, 2, 1]:
			surface.add_vertex(vertices[indices[offset + triangle_index]])
		for triangle_index: int in [0, 1, 2]:
			faces.append(vertices[indices[offset + triangle_index]])
	surface.generate_normals()
	var patch_mesh := surface.commit()
	_mesh(patch_mesh, _scenery.turf_material(color), _terrain)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.collision_layer = FLOOR_LAYER
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	_terrain.add_child(body)


func _build_rails(bounds: Rect2) -> void:
	var width := 16.0
	_wall(Rect2(bounds.position.x - width, bounds.position.y - width, bounds.size.x + width * 2.0, width))
	_wall(Rect2(bounds.position.x - width, bounds.end.y, bounds.size.x + width * 2.0, width))
	# Segment the side rails so the upper terrace and ramp are enclosed at their
	# actual height. Logical inner boundaries remain unchanged.
	for y in range(int(bounds.position.y), int(bounds.end.y), 25):
		_wall(Rect2(bounds.position.x - width, y, width, minf(25.0, bounds.end.y - y)))
		_wall(Rect2(bounds.end.x, y, width, minf(25.0, bounds.end.y - y)))


func _wall(rect: Rect2) -> void:
	var ground := terrain_height(rect.get_center())
	var size := Vector3(rect.size.x * WORLD_SCALE, 0.42, rect.size.y * WORLD_SCALE)
	var position_3d := map_to_world(rect.get_center(), ground + size.y * 0.5)
	var timber := Color("82613f") if _course_index != 1 else Color("ba9564")
	var cap := Color("b49261") if _course_index != 1 else Color("dfc294")
	_box(position_3d, size, timber, _terrain, WALL_LAYER)
	_box(position_3d + Vector3(0, size.y * 0.5 + 0.016, 0), Vector3(size.x + 0.022, 0.032, size.z + 0.022), cap, _terrain)
	# Fine inset bands make each rail read as worked timber/stone at a close
	# camera, without adding any new collider or changing the playable bounds.
	var horizontal := size.x > size.z
	var trim_size := Vector3(size.x + 0.003, 0.024, size.z + 0.003)
	for height: float in [-0.10, 0.07]:
		_box(position_3d + Vector3(0, height, 0), trim_size, timber.darkened(0.14), _terrain)
	if maxf(size.x, size.z) > 0.6:
		var length := maxf(size.x, size.z)
		for offset in range(1, int(length / 0.55) + 1):
			var along := float(offset) * 0.55 - length * 0.5
			var joint_position := position_3d + (Vector3(along, 0.0, 0.0) if horizontal else Vector3(0.0, 0.0, along))
			var joint_size := Vector3(0.012, size.y + 0.005, size.z + 0.006) if horizontal else Vector3(size.x + 0.006, size.y + 0.005, 0.012)
			_box(joint_position, joint_size, timber.darkened(0.25), _terrain)


func _build_water(hazard: Rect2) -> void:
	var water := PlaneMesh.new()
	water.size = hazard.size * WORLD_SCALE
	var water_instance := _mesh(water, _scenery.water_material(), _terrain)
	water_instance.position = map_to_world(hazard.get_center(), -0.095)
	var lip := Rect2(hazard.position.x - 4.0, hazard.position.y, 4.0, hazard.size.y)
	_box(map_to_world(lip.get_center(), -0.055), Vector3(0.04, 0.10, lip.size.y * WORLD_SCALE), Color("c3b18b"), _terrain)
	for index in range(7):
		var foam := _disc(0.021 + index % 3 * 0.005, 0.002, Color("addfce"), _terrain)
		foam.position = map_to_world(Vector2(hazard.position.x + 10.0, hazard.position.y + 14.0 + index * 23.0), -0.086)


func _build_hole(point: Vector2) -> void:
	var height := terrain_height(point)
	var hole := _disc(0.22, 0.012, Color("0b1823"), _terrain)
	hole.position = map_to_world(point, height + 0.006)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.22
	rim.outer_radius = 0.25
	rim.rings = 48
	rim.ring_segments = 8
	var rim_instance := _mesh(rim, _material(Color("f0dfaa"), 0.6), _terrain)
	rim_instance.position = map_to_world(point, height + 0.014)
	_flag = Node3D.new()
	_flag.position = map_to_world(point, height)
	_terrain.add_child(_flag)
	_segment(Vector3(0.12, 0.0, 0.0), Vector3(0.12, 1.17, 0.0), 0.014, Color("ece2c1"), _flag)
	for index in range(3):
		_segment(Vector3(0.12, 0.08 + index * 0.25, 0.0), Vector3(0.12, 0.18 + index * 0.25, 0.0), 0.015, Color("7a8664"), _flag)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex: Vector3 in [Vector3(0.12, 1.14, 0), Vector3(0.64, 1.09, 0), Vector3(0.12, 0.83, 0), Vector3(0.64, 1.09, 0), Vector3(0.56, 0.86, 0), Vector3(0.12, 0.83, 0)]:
		surface.add_vertex(vertex)
	surface.generate_normals()
	var flag_material := _material(Color("f7a546"), 0.8)
	flag_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(surface.commit(), flag_material, _flag)


func _update_aim(session) -> void:
	var show_aim: bool = session.state == Session.State.AIMING and not session.is_paused()
	_aim.visible = show_aim
	if not show_aim:
		_aim_cache = Vector4(INF, INF, INF, INF)
		return
	var direction: Vector2 = session.aim_direction()
	var cache := Vector4(direction.x, direction.y, session.power(), ball.position.y)
	if _aim_cache.is_equal_approx(cache):
		return
	_aim_cache = cache
	if session.power() <= 0.0:
		_aim.visible = false
		return
	var origin: Vector3 = ball.position + Vector3(0, 0.03, 0)
	var direction_3d := Vector3(direction.x, 0.0, direction.y)
	var length: float = 0.45 + session.power() * 1.25
	var color: Color = Color("50d9d0").lerp(Color("f7a546"), session.power())
	_aim_material.albedo_color = color
	_aim_material.emission = color
	var tip: Vector3 = origin + direction_3d * length
	_position_segment(_aim_segments[0], origin, tip)
	var side := Vector3(-direction_3d.z, 0.0, direction_3d.x)
	_position_segment(_aim_segments[1], tip, tip - direction_3d * 0.21 + side * 0.14)
	_position_segment(_aim_segments[2], tip, tip - direction_3d * 0.21 - side * 0.14)
	for index in range(_aim_dots.size()):
		var distance := (float(index) + 1.0) * 0.22
		_aim_dots[index].position = origin + direction_3d * distance + Vector3(0, -0.08, 0)
		_aim_dots[index].visible = distance > length * 0.82
	var pulled: Vector3 = origin - direction_3d * (0.36 + session.power() * 0.70)
	_aim_handle.position = pulled
	_aim_handle.scale = Vector3.ONE * (1.0 + session.power() * 0.25)
	_position_segment(_aim_pull, origin - direction_3d * 0.16, pulled)


func _build_aim_pool() -> void:
	_aim_material = _material(Color("50d9d0"), 0.65, true)
	for index in range(3):
		var segment := _segment(Vector3.ZERO, Vector3.UP, 0.018, Color.WHITE, _aim)
		segment.material_override = _aim_material
		_aim_segments.append(segment)
	for index in range(11):
		var dot := _disc(0.035, 0.008, Color("d5f3ce"), _aim)
		_aim_dots.append(dot)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.12
	handle.outer_radius = 0.155
	handle.rings = 24
	handle.ring_segments = 6
	_aim_handle = _mesh(handle, _aim_material, _aim)
	_aim_pull = _segment(Vector3.ZERO, Vector3.UP, 0.012, Color("e7f1d3"), _aim)


func _position_segment(instance: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var direction := (end - start).normalized()
	var basis := Basis.IDENTITY
	if absf(direction.dot(Vector3.UP)) < 0.999:
		basis = Basis(Quaternion(Vector3.UP, direction))
	instance.transform = Transform3D(basis.scaled(Vector3(1, start.distance_to(end), 1)), (start + end) * 0.5)


func _build_effect_pool() -> void:
	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = 0.035
	trail_mesh.height = 0.07
	trail_mesh.radial_segments = 8
	trail_mesh.rings = 4
	var trail_material := _material(Color("d1f4de"), 0.8, true)
	for index in range(28):
		var stamp := _mesh(trail_mesh, trail_material, self)
		stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stamp.visible = false
		_trail.append(stamp)
		_trail_times.append(-10.0)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.23
	ring_mesh.outer_radius = 0.246
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 6
	for index in range(3):
		var ring := _mesh(ring_mesh, _material(Color("efda87") if index == 1 else Color("b8edc1"), 0.8, true), self)
		ring.visible = false
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_capture_rings.append(ring)


func _update_effects(session, elapsed: float) -> void:
	if session.state != _last_state:
		if session.state == Session.State.CAPTURED:
			_capture_started = elapsed
		elif session.state in [Session.State.MENU, Session.State.RESULT, Session.State.RETURNING]:
			for stamp in _trail:
				stamp.visible = false
		_last_state = session.state
	if session.state == Session.State.MOVING and not session.is_paused():
		if _trail_previous.distance_to(ball.position) > 0.10:
			var stamp := _trail[_trail_cursor]
			stamp.position = ball.position
			stamp.visible = true
			stamp.scale = Vector3.ONE
			_trail_times[_trail_cursor] = elapsed
			_trail_cursor = (_trail_cursor + 1) % _trail.size()
			_trail_previous = ball.position
	else:
		_trail_previous = ball.position
	for index in range(_trail.size()):
		if _trail[index].visible:
			var age := elapsed - _trail_times[index]
			_trail[index].visible = age < 0.46
			_trail[index].scale = Vector3.ONE * maxf(0.05, 1.0 - age / 0.46)
	for index in range(_capture_rings.size()):
		var age := elapsed - _capture_started - float(index) * 0.09
		var active: bool = _capture_started >= 0.0 and session.state == Session.State.CAPTURED and age >= 0.0 and age < 0.65
		_capture_rings[index].visible = active
		if active:
			_capture_rings[index].position = hole_world_position() + Vector3(0, 0.02 + age * 0.24, 0)
			_capture_rings[index].scale = Vector3.ONE * (1.0 + age * 4.0)


func _fit_camera() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var projected := Rect2()
	var first := true
	for x: float in [48.0, 672.0]:
		for y: float in [184.0, 1116.0]:
			for elevation: float in [-0.5, 1.65]:
				var point := camera.unproject_position(map_to_world(Vector2(x, y), elevation))
				if first:
					projected = Rect2(point, Vector2.ZERO)
					first = false
				else:
					projected = projected.expand(point)
	var factor := maxf(projected.size.x / (viewport_size.x * 0.92), projected.size.y / (viewport_size.y * 0.90))
	camera.size *= factor
	_camera_fitted = true


func _material(color: Color, roughness: float = 0.8, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.35
	return material


func _mesh(mesh: Mesh, material: Material, parent: Node3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(center: Vector3, size: Vector3, color: Color, parent: Node3D, collision_layer: int = 0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh(mesh, _material(color), parent)
	instance.position = center
	if collision_layer != 0:
		var body := StaticBody3D.new()
		body.position = center
		body.collision_layer = collision_layer
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		parent.add_child(body)
	return instance


func _disc(radius: float, height: float, color: Color, parent: Node3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	return _mesh(mesh, _material(color), parent)


func _segment(start: Vector3, end: Vector3, radius: float, color: Color, parent: Node3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 8
	var instance := _mesh(mesh, _material(color), parent)
	instance.position = (start + end) * 0.5
	var direction := (end - start).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		instance.basis = Basis(Quaternion(Vector3.UP, direction))
	return instance

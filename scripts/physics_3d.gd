class_name NativePhysics3D
extends RefCounted

## The live game uses the actual sphere and collision surfaces in CourseView3D.
## Map coordinates are retained only for session rules, input and scorekeeping.
const Config = preload("res://scripts/game_config.gd")
const SCALE := Config.WORLD_SCALE
const MAP_CENTER := Vector2(360.0, 650.0)
const RADIUS := Config.BALL_RADIUS * SCALE
const GRAVITY := Config.GRAVITY_3D
const GROUND_DRAG := Config.DECELERATION * SCALE
const SUPPORT_SLOP := 0.008
const MIN_FLOOR_NORMAL := 0.55
const MAX_CONTACTS := 12
const FALL_DEPTH := -1.5

var view: Node3D
var grounded := false
var ground_normal := Vector3.UP
var _last_course := -1
var _last_state := -1
var _last_position := Vector2(INF, INF)
var _last_elevation := INF
var _bounds := Rect2(64.0, 200.0, 592.0, 900.0)
var _hazard := Rect2()


func _init(course_view: Node3D) -> void:
	view = course_view


func reset(session) -> void:
	var body: CharacterBody3D = view.ball
	_bounds = session.current_course()["bounds"]
	_hazard = session.current_course()["hazard"]
	var center_height: float = session.elevation
	if session.state in [session.State.READY, session.State.AIMING]:
		var terrain_support := float(view.support_height(session.position))
		# A resting shot may begin on a wall roof, above the terrain sampled for
		# decoration. Preserve that supported height when restoring a safe shot.
		center_height = maxf(terrain_support, center_height) if is_safe_position(session.position, center_height) else terrain_support
	body.global_position = _world_position(session.position, center_height)
	body.velocity = _world_velocity(session) if session.state == session.State.MOVING else Vector3.ZERO
	grounded = false
	ground_normal = Vector3.UP
	# A sphere resting on an incline has its centre slightly higher than its
	# radius above the vertically sampled floor. Resolve that geometric offset.
	var floor := _support(body, body.velocity)
	if not floor.is_empty():
		var normal: Vector3 = floor["normal"]
		var contact: Vector3 = floor["position"]
		body.global_position.y = maxf(body.global_position.y, contact.y + RADIUS / normal.y)
		grounded = true
		ground_normal = normal
	_sync(session, body)


func is_safe_position(point: Vector2, elevation: float) -> bool:
	if not point.is_finite() or not is_finite(elevation) or view.ball == null:
		return false
	if not _contains_closed(_bounds.grow(-Config.BALL_RADIUS), point):
		return false
	if _hazard.has_area() and _contains_closed(_hazard, point) and elevation <= RADIUS + 0.06:
		return false
	var body: CharacterBody3D = view.ball
	return not _query_support(body, _world_position(point, elevation), Vector3.ZERO).is_empty()


func step(session, delta: float) -> void:
	var body: CharacterBody3D = view.ball
	if session.state != session.State.MOVING:
		_last_state = session.state
		return
	if not _finite_session(session):
		_return_ball(session)
		return
	if _last_course != session.course_index or _last_state != session.State.MOVING or not session.position.is_equal_approx(_last_position) or not is_equal_approx(session.elevation, _last_elevation):
		reset(session)
	body.velocity = _world_velocity(session)
	if not _inside_bounds(session, body.global_position) or body.global_position.y < FALL_DEPTH:
		_return_ball(session)
		return
	var support := _support(body, body.velocity)
	grounded = not support.is_empty()
	ground_normal = support["normal"] if grounded else Vector3.UP
	if _hazard_at_rest(session) or _capture_allowed(session, body):
		if _hazard_at_rest(session):
			_return_ball(session)
		else:
			_capture_ball(session)
		return
	if delta <= 0.0:
		_sync(session, body)
		return
	if grounded:
		# Contact redirects motion along an uphill surface. Its upward component
		# remains when the sphere leaves a ramp lip, producing a natural jump.
		body.velocity = body.velocity.slide(ground_normal)
		body.velocity += (Vector3.DOWN * GRAVITY).slide(ground_normal) * delta
		var horizontal_speed := Vector2(body.velocity.x, body.velocity.z).length()
		if horizontal_speed > 0.000001:
			body.velocity *= maxf(horizontal_speed - GROUND_DRAG * delta, 0.0) / horizontal_speed
		else:
			body.velocity = Vector3.ZERO
	else:
		body.velocity.y -= GRAVITY * delta
	_move_sphere(body, delta)
	if not body.global_position.is_finite() or not body.velocity.is_finite() or not _inside_bounds(session, body.global_position) or body.global_position.y < FALL_DEPTH:
		_return_ball(session)
		return
	support = _support(body, body.velocity)
	grounded = not support.is_empty()
	ground_normal = support["normal"] if grounded else Vector3.UP
	_sync(session, body)
	if _hazard_at_rest(session):
		_return_ball(session)
		return
	if _capture_allowed(session, body):
		_capture_ball(session)
		return
	# An airborne ball can have no horizontal speed (including at its apex),
	# but only a supported ball can finish a shot.
	var horizontal_speed := Vector2(body.velocity.x, body.velocity.z).length()
	if grounded and horizontal_speed < Config.STOP_SPEED * SCALE and absf(body.velocity.dot(ground_normal)) <= 0.15:
		session.resting_time += delta
	else:
		session.resting_time = 0.0
	if session.resting_time + 0.00001 >= Config.STOP_CONFIRM_TIME:
		body.velocity = Vector3.ZERO
		session.velocity = Vector2.ZERO
		session.vertical_velocity = 0.0
		session.state = session.State.READY
		_last_state = session.state


func _move_sphere(body: CharacterBody3D, delta: float) -> void:
	var remaining_time := delta
	for _contact in MAX_CONTACTS:
		if remaining_time <= 0.000001 or body.velocity.length_squared() <= 0.000000001:
			break
		var motion := body.velocity * remaining_time
		var hit := body.move_and_collide(motion, false, 0.00001)
		if hit == null:
			break
		var travelled_fraction := clampf(hit.get_travel().length() / motion.length(), 0.0, 1.0)
		remaining_time *= 1.0 - travelled_fraction
		var normal := hit.get_normal()
		if normal.y >= MIN_FLOOR_NORMAL:
			# Landing and floor contacts slide; there is no artificial bounce.
			body.velocity = body.velocity.slide(normal)
		else:
			var normal_speed := body.velocity.dot(normal)
			if normal_speed < 0.0:
				body.velocity -= normal * ((1.0 + Config.RESTITUTION) * normal_speed)
		# Separate by a microscopic distance so the next sweep can use the
		# remaining time rather than repeatedly encountering the same contact.
		body.global_position += normal * 0.00001


func _support(body: CharacterBody3D, velocity: Vector3) -> Dictionary:
	return _query_support(body, body.global_position, velocity)


func _query_support(body: CharacterBody3D, center: Vector3, velocity: Vector3) -> Dictionary:
	if not body.is_inside_tree() or not center.is_finite():
		return {}
	# Wall roofs are legitimate supporting surfaces too. Side contacts fail
	# the upward-normal test below, so this never grounds a ball against a wall.
	var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 0.005, center + Vector3.DOWN * 0.27, 3, [body.get_rid()])
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var normal: Vector3 = hit["normal"]
	var point: Vector3 = hit["position"]
	if normal.y < MIN_FLOOR_NORMAL:
		return {}
	var plane_distance := (center - point).dot(normal)
	# Ray intersection alone is insufficient: an airborne ball still sees a
	# floor below it, and an upward takeoff must never get snapped back down.
	if plane_distance > RADIUS + SUPPORT_SLOP or plane_distance < RADIUS - 0.03 or velocity.dot(normal) > 0.15:
		return {}
	return hit


func _capture_allowed(session, body: CharacterBody3D) -> bool:
	if not grounded:
		return false
	var hole: Vector2 = session.current_course()["hole"]
	var hole_height := float(view.terrain_height(hole)) + RADIUS
	return session.position.distance_to(hole) <= Config.CAPTURE_RADIUS + 0.00001 and Vector2(body.velocity.x, body.velocity.z).length() <= Config.CAPTURE_SPEED * SCALE + 0.00001 and absf(body.global_position.y - hole_height) <= 0.035 and absf(body.velocity.y) <= 0.35


func _hazard_at_rest(session) -> bool:
	var hazard: Rect2 = session.current_course()["hazard"]
	# The takeoff lip borders the water rectangle but stands above it. A real
	# elevated floor there is safe; a falling sphere returns on touching water.
	if not hazard.has_area() or not _contains_closed(hazard, session.position):
		return false
	return session.elevation <= RADIUS - 0.10 or (grounded and session.elevation <= RADIUS + 0.06)


func _inside_bounds(session, point: Vector3) -> bool:
	if not point.is_finite():
		return false
	var bounds: Rect2 = session.current_course()["bounds"]
	return _contains_closed(bounds.grow(-Config.BALL_RADIUS), _map_position(point))


func _finite_session(session) -> bool:
	return session.position.is_finite() and session.velocity.is_finite() and is_finite(session.elevation) and is_finite(session.vertical_velocity)


func _return_ball(session) -> void:
	view.ball.velocity = Vector3.ZERO
	session.velocity = Vector2.ZERO
	session.vertical_velocity = 0.0
	grounded = false
	if session.state == session.State.MOVING:
		session._begin_return()
	_last_state = session.state


func _capture_ball(session) -> void:
	view.ball.velocity = Vector3.ZERO
	session.vertical_velocity = 0.0
	if session.state == session.State.MOVING:
		session._capture()
	session.elevation = float(view.terrain_height(session.position)) + RADIUS
	_last_state = session.state


func _sync(session, body: CharacterBody3D) -> void:
	session.position = _map_position(body.global_position)
	session.velocity = Vector2(body.velocity.x, body.velocity.z) / SCALE
	session.elevation = body.global_position.y
	session.vertical_velocity = body.velocity.y
	_last_course = session.course_index
	_last_state = session.state
	_last_position = session.position
	_last_elevation = session.elevation


static func _world_position(point: Vector2, center_height: float) -> Vector3:
	return Vector3((point.x - MAP_CENTER.x) * SCALE, center_height, (point.y - MAP_CENTER.y) * SCALE)


static func _map_position(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z) / SCALE + MAP_CENTER


static func _world_velocity(session) -> Vector3:
	return Vector3(session.velocity.x * SCALE, session.vertical_velocity, session.velocity.y * SCALE)


static func _contains_closed(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x - 0.0001 and point.x <= rect.end.x + 0.0001 and point.y >= rect.position.y - 0.0001 and point.y <= rect.end.y + 0.0001

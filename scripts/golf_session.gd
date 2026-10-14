class_name GolfSession
extends RefCounted

## Session and deterministic continuous collision physics, with no rendering
## or persistence dependency. Time and input stop whenever any pause is active.
const Config = preload("res://scripts/game_config.gd")
const Courses = preload("res://scripts/courses.gd")
const NO_POINTER := -2147483648
const EPSILON := 0.00001
const CONTACT_SLOP := 0.0001
const MAX_IMPACTS_PER_STEP := 16

enum State { MENU, READY, AIMING, MOVING, RETURNING, CAPTURED, RESULT }

var state: State = State.MENU
var course_index := 0
var position := Vector2.ZERO
var velocity := Vector2.ZERO
var previous_position := Vector2.ZERO
var aim_start := Vector2.ZERO
var aim_current := Vector2.ZERO
var active_pointer := NO_POINTER
var current_strokes := 0
var results: Array[int] = []
var captured_strokes := 0
var remaining := 0.0
var resting_time := 0.0
var pause_reasons: Dictionary = {}


func start_session() -> void:
	pause_reasons.erase("modal")
	course_index = 0
	current_strokes = 0
	results.clear()
	captured_strokes = 0
	_load_course()


func current_course() -> Dictionary:
	return Courses.ALL[course_index]


func total() -> int:
	var value := current_strokes
	for strokes in results:
		value += strokes
	return value


func begin_aim(point: Vector2, pointer_id: int) -> bool:
	if state != State.READY or is_paused() or not point.is_finite():
		return false
	if point.distance_to(position) > Config.TOUCH_RADIUS:
		return false
	velocity = Vector2.ZERO
	aim_start = point
	aim_current = point
	active_pointer = pointer_id
	state = State.AIMING
	return true


func drag_aim(point: Vector2, pointer_id: int) -> void:
	if state == State.AIMING and not is_paused() and pointer_id == active_pointer and point.is_finite():
		aim_current = point


func release_aim(point: Vector2, pointer_id: int) -> bool:
	if state != State.AIMING or is_paused() or pointer_id != active_pointer:
		return false
	if not point.is_finite():
		cancel_aim()
		return false
	aim_current = point
	var intensity := power()
	var direction := aim_direction()
	_clear_pointer()
	if intensity <= 0.0:
		state = State.READY
		return false
	previous_position = position
	velocity = direction * intensity * Config.MAX_SPEED
	current_strokes += 1
	resting_time = 0.0
	state = State.MOVING
	return true


func cancel_aim() -> void:
	_clear_pointer()
	if state == State.AIMING:
		velocity = Vector2.ZERO
		state = State.READY


func power() -> float:
	if state != State.AIMING:
		return 0.0
	return clampf((aim_current.distance_to(aim_start) - Config.DEAD_ZONE) / (Config.MAX_DRAG - Config.DEAD_ZONE), 0.0, 1.0)


func aim_direction() -> Vector2:
	return (aim_start - aim_current).normalized() if state == State.AIMING else Vector2.ZERO


func set_paused(reason: String, enabled: bool) -> void:
	if enabled:
		pause_reasons[reason] = true
		cancel_aim()
	else:
		pause_reasons.erase(reason)


func is_paused() -> bool:
	return not pause_reasons.is_empty()


func request_menu() -> bool:
	if is_paused() or state not in [State.READY, State.AIMING, State.MOVING]:
		return false
	set_paused("modal", true)
	return true


func continue_session() -> void:
	set_paused("modal", false)


func abandon_session() -> void:
	pause_reasons.erase("modal")
	state = State.MENU
	course_index = 0
	current_strokes = 0
	results.clear()
	captured_strokes = 0
	remaining = 0.0
	resting_time = 0.0
	velocity = Vector2.ZERO
	position = Vector2.ZERO
	previous_position = Vector2.ZERO
	_clear_pointer()


func update(delta: float) -> void:
	if is_paused() or not is_finite(delta) or delta < 0.0:
		return
	# A zero-time update still validates a moving ball and the exact capture
	# boundary; it never advances a transition or a confirmation timer.
	if delta == 0.0:
		if state == State.MOVING:
			_validate_moving_position()
		return
	var time_left := delta
	while time_left > EPSILON:
		var step := minf(time_left, Config.PHYSICS_STEP)
		time_left -= step
		match state:
			State.MOVING:
				_update_motion(step)
			State.RETURNING, State.CAPTURED:
				remaining = maxf(remaining - step, 0.0)
				if remaining <= EPSILON:
					_finish_transition()
			_:
				break


static func reflected_velocity(incoming: Vector2, normal: Vector2) -> Vector2:
	var normal_speed := incoming.dot(normal)
	if normal_speed >= 0.0:
		return incoming
	return incoming - normal * ((1.0 + Config.RESTITUTION) * normal_speed)


func _clear_pointer() -> void:
	active_pointer = NO_POINTER
	aim_start = Vector2.ZERO
	aim_current = Vector2.ZERO


func _load_course() -> void:
	position = current_course()["start"]
	previous_position = position
	velocity = Vector2.ZERO
	remaining = 0.0
	resting_time = 0.0
	_clear_pointer()
	state = State.READY


func _capture() -> void:
	if state != State.MOVING:
		return
	position = current_course()["hole"]
	velocity = Vector2.ZERO
	captured_strokes = current_strokes
	results.append(current_strokes)
	current_strokes = 0
	resting_time = 0.0
	_clear_pointer()
	remaining = Config.CAPTURE_TIME
	state = State.CAPTURED


func _begin_return() -> void:
	velocity = Vector2.ZERO
	resting_time = 0.0
	_clear_pointer()
	remaining = Config.RETURN_TIME
	state = State.RETURNING


func _finish_transition() -> void:
	if state == State.RETURNING:
		position = previous_position if _valid_position(previous_position) else current_course()["start"]
		previous_position = position
		velocity = Vector2.ZERO
		state = State.READY
	elif state == State.CAPTURED:
		if course_index + 1 >= Courses.ALL.size():
			state = State.RESULT
		else:
			course_index += 1
			_load_course()


func _validate_moving_position() -> bool:
	if not velocity.is_finite() or not _valid_position(position):
		_begin_return()
		return false
	if _can_capture():
		_capture()
		return false
	return true


func _can_capture() -> bool:
	var hole: Vector2 = current_course()["hole"]
	return position.distance_to(hole) <= Config.CAPTURE_RADIUS + EPSILON and velocity.length() <= Config.CAPTURE_SPEED + EPSILON


func _valid_position(point: Vector2) -> bool:
	if not point.is_finite():
		return false
	var bounds: Rect2 = current_course()["bounds"]
	var inner := bounds.grow(-Config.BALL_RADIUS)
	if not _rect_contains_closed(inner, point):
		return false
	var hazard: Rect2 = current_course()["hazard"]
	if hazard.has_area() and _rect_contains_closed(hazard, point):
		return false
	for wall: Rect2 in current_course()["walls"]:
		var nearest := Vector2(clampf(point.x, wall.position.x, wall.end.x), clampf(point.y, wall.position.y, wall.end.y))
		if point.distance_squared_to(nearest) < Config.BALL_RADIUS * Config.BALL_RADIUS - EPSILON:
			return false
	return true


static func _rect_contains_closed(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x - EPSILON and point.x <= rect.end.x + EPSILON and point.y >= rect.position.y - EPSILON and point.y <= rect.end.y + EPSILON


func _update_motion(delta: float) -> void:
	if not _validate_moving_position():
		return
	var time_left := delta
	var impact_count := 0
	while time_left > EPSILON and state == State.MOVING:
		var speed := velocity.length()
		if speed <= EPSILON:
			velocity = Vector2.ZERO
			resting_time += time_left
			time_left = 0.0
			break
		var direction := velocity / speed
		var moving_time := minf(time_left, speed / Config.DECELERATION)
		var distance := speed * moving_time - 0.5 * Config.DECELERATION * moving_time * moving_time
		var wall_hit := _sweep_walls(position, direction, distance)
		var wall_distance: float = wall_hit["distance"]
		var hazard_distance := _hazard_distance(position, direction, distance)
		var capture_distance := _capture_distance(position, direction, speed, distance)
		var event_distance := minf(wall_distance, minf(hazard_distance, capture_distance))
		if is_inf(event_distance):
			position += direction * distance
			var new_speed := maxf(speed - Config.DECELERATION * moving_time, 0.0)
			velocity = direction * new_speed
			_accumulate_rest(speed, new_speed, moving_time)
			time_left = maxf(time_left - moving_time, 0.0)
			if _can_capture():
				_capture()
				return
			continue
		var event_time := _time_for_distance(speed, event_distance)
		position += direction * event_distance
		var event_speed := maxf(speed - Config.DECELERATION * event_time, 0.0)
		velocity = direction * event_speed
		_accumulate_rest(speed, event_speed, event_time)
		time_left = maxf(time_left - event_time, 0.0)
		if hazard_distance <= event_distance + EPSILON:
			_begin_return()
			return
		if capture_distance <= event_distance + EPSILON:
			_capture()
			return
		for normal: Vector2 in wall_hit["normals"]:
			velocity = reflected_velocity(velocity, normal)
			position += normal * CONTACT_SLOP
		impact_count += 1
		if impact_count >= MAX_IMPACTS_PER_STEP:
			# Recovery is preferable to discarding motion or crossing a wall if
			# externally supplied geometry traps the circle at a contact.
			_begin_return()
			return
	if state == State.MOVING and _can_capture():
		_capture()
	elif state == State.MOVING and resting_time + EPSILON >= Config.STOP_CONFIRM_TIME:
		velocity = Vector2.ZERO
		state = State.READY


func _accumulate_rest(old_speed: float, new_speed: float, delta: float) -> void:
	if old_speed >= Config.STOP_SPEED:
		resting_time = 0.0
		if new_speed < Config.STOP_SPEED:
			var crossing_time := (old_speed - Config.STOP_SPEED) / Config.DECELERATION
			resting_time += maxf(delta - crossing_time, 0.0)
	else:
		resting_time += delta


static func _time_for_distance(speed: float, distance: float) -> float:
	# Stable equivalent of (speed - sqrt(speed² - 2*a*d)) / a.
	var final_speed := sqrt(maxf(speed * speed - 2.0 * Config.DECELERATION * distance, 0.0))
	return 2.0 * distance / (speed + final_speed) if speed + final_speed > EPSILON else 0.0


func _capture_distance(origin: Vector2, direction: Vector2, speed: float, max_distance: float) -> float:
	var hole: Vector2 = current_course()["hole"]
	var offset := origin - hole
	var projected := offset.dot(direction)
	var discriminant := projected * projected - (offset.length_squared() - Config.CAPTURE_RADIUS * Config.CAPTURE_RADIUS)
	if discriminant < 0.0:
		return INF
	var root := sqrt(discriminant)
	var near_distance := maxf(-projected - root, 0.0)
	var far_distance := -projected + root
	var slow_distance := maxf((speed * speed - Config.CAPTURE_SPEED * Config.CAPTURE_SPEED) / (2.0 * Config.DECELERATION), 0.0)
	var hit_distance := maxf(near_distance, slow_distance)
	if hit_distance <= far_distance + EPSILON and hit_distance <= max_distance + EPSILON:
		return clampf(hit_distance, 0.0, max_distance)
	return INF


func _hazard_distance(origin: Vector2, direction: Vector2, max_distance: float) -> float:
	var hazard: Rect2 = current_course()["hazard"]
	if not hazard.has_area():
		return INF
	var near_distance := 0.0
	var far_distance := max_distance
	for axis in [0, 1]:
		var component: float = direction[axis]
		if absf(component) <= EPSILON:
			if origin[axis] < hazard.position[axis] or origin[axis] > hazard.end[axis]:
				return INF
			continue
		var entry: float = (hazard.position[axis] - origin[axis]) / component
		var exit: float = (hazard.end[axis] - origin[axis]) / component
		near_distance = maxf(near_distance, minf(entry, exit))
		far_distance = minf(far_distance, maxf(entry, exit))
		if near_distance > far_distance + EPSILON:
			return INF
	return maxf(near_distance, 0.0)


func _sweep_walls(origin: Vector2, direction: Vector2, max_distance: float) -> Dictionary:
	var hit := {"distance": INF, "normals": []}
	var bounds: Rect2 = current_course()["bounds"]
	var inner := bounds.grow(-Config.BALL_RADIUS)
	if direction.x < -EPSILON:
		_add_collision(hit, (inner.position.x - origin.x) / direction.x, Vector2.RIGHT, max_distance)
	elif direction.x > EPSILON:
		_add_collision(hit, (inner.end.x - origin.x) / direction.x, Vector2.LEFT, max_distance)
	if direction.y < -EPSILON:
		_add_collision(hit, (inner.position.y - origin.y) / direction.y, Vector2.DOWN, max_distance)
	elif direction.y > EPSILON:
		_add_collision(hit, (inner.end.y - origin.y) / direction.y, Vector2.UP, max_distance)
	for wall: Rect2 in current_course()["walls"]:
		_sweep_circle_rect(hit, origin, direction, max_distance, wall)
	return hit


static func _add_collision(hit: Dictionary, distance: float, normal: Vector2, max_distance: float) -> void:
	if distance < -EPSILON or distance > max_distance + EPSILON:
		return
	distance = clampf(distance, 0.0, max_distance)
	if distance < float(hit["distance"]) - EPSILON:
		hit["distance"] = distance
		hit["normals"] = [normal]
	elif absf(distance - float(hit["distance"])) <= EPSILON:
		if not hit["normals"].has(normal):
			hit["normals"].append(normal)


static func _sweep_circle_rect(hit: Dictionary, origin: Vector2, direction: Vector2, max_distance: float, wall: Rect2) -> void:
	var radius: float = Config.BALL_RADIUS
	# Minkowski boundary: four flat faces plus four quarter circles. An
	# expanded AABB alone would create false collisions near the corners.
	if direction.x > EPSILON:
		var distance := (wall.position.x - radius - origin.x) / direction.x
		var along := origin.y + direction.y * distance
		if along >= wall.position.y - EPSILON and along <= wall.end.y + EPSILON:
			_add_collision(hit, distance, Vector2.LEFT, max_distance)
	elif direction.x < -EPSILON:
		var distance := (wall.end.x + radius - origin.x) / direction.x
		var along := origin.y + direction.y * distance
		if along >= wall.position.y - EPSILON and along <= wall.end.y + EPSILON:
			_add_collision(hit, distance, Vector2.RIGHT, max_distance)
	if direction.y > EPSILON:
		var distance := (wall.position.y - radius - origin.y) / direction.y
		var along := origin.x + direction.x * distance
		if along >= wall.position.x - EPSILON and along <= wall.end.x + EPSILON:
			_add_collision(hit, distance, Vector2.UP, max_distance)
	elif direction.y < -EPSILON:
		var distance := (wall.end.y + radius - origin.y) / direction.y
		var along := origin.x + direction.x * distance
		if along >= wall.position.x - EPSILON and along <= wall.end.x + EPSILON:
			_add_collision(hit, distance, Vector2.DOWN, max_distance)
	for signs: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
		var corner := Vector2(wall.position.x if signs.x < 0.0 else wall.end.x, wall.position.y if signs.y < 0.0 else wall.end.y)
		var offset := origin - corner
		var projected := offset.dot(direction)
		var discriminant := projected * projected - (offset.length_squared() - radius * radius)
		if discriminant < 0.0:
			continue
		var distance := -projected - sqrt(discriminant)
		if distance < -EPSILON or distance > max_distance + EPSILON:
			continue
		var relative := origin + direction * maxf(distance, 0.0) - corner
		if relative.x * signs.x < -EPSILON or relative.y * signs.y < -EPSILON:
			continue
		var normal := relative.normalized()
		if direction.dot(normal) < -EPSILON:
			_add_collision(hit, distance, normal, max_distance)

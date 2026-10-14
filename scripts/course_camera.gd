class_name CourseCamera
extends RefCounted

## A close portrait camera over the real 3D course. Call setup() after
## CourseView3D.setup(), then update() after its visual sync in _process().
## The fitted overview is retained for the menu, result and the map button.
## Cancel the current aim before changing overview: the camera itself stays
## completely still throughout a drag and while any pause is active.
const Session = preload("res://scripts/golf_session.gd")
const FOLLOW_OFFSET := Vector3(1.4, 6.5, 5.8)
const FOLLOW_FOV := 56.0
const FOLLOW_RESPONSE := 8.0
const FORWARD_BIAS := Vector3(0.0, 0.0, -0.65)
const MENU_POSITION := Vector3(7.5, 10.5, 11.0)
const MENU_TARGET := Vector3(0.0, 0.25, 0.0)
const MENU_SIZE := 11.3

var overview := false
var _world
var _camera: Camera3D
var _overview_transform := Transform3D.IDENTITY
var _overview_size := 14.0
var _overview_aspect := Camera3D.KEEP_WIDTH
var _anchor := Vector3.ZERO
var _course_index := -1
var _showing_overview := true
var _showing_menu := false
var _follow_initialized := false


func setup(world, session) -> void:
	_world = world
	_camera = world.camera
	_overview_transform = _camera.transform
	_overview_size = _camera.size
	_overview_aspect = _camera.keep_aspect
	_course_index = session.course_index
	_follow_initialized = false
	_showing_overview = true
	if session.state == Session.State.MENU:
		_apply_menu()
	elif session.state == Session.State.RESULT or overview:
		_apply_overview()
	else:
		snap_for_course(session)


func set_overview(enabled: bool) -> void:
	# Apply on the next update, after the caller has invalidated any old drag.
	overview = enabled


func snap_for_course(session) -> void:
	if _camera == null or session.is_paused() or session.state == Session.State.AIMING:
		return
	_course_index = session.course_index
	_anchor = _desired_anchor(session)
	_follow_initialized = true
	if session.state == Session.State.MENU:
		_apply_menu()
	elif session.state == Session.State.RESULT or overview:
		_apply_overview()
	else:
		_apply_follow()


func update(session, delta: float, _elapsed: float = 0.0) -> void:
	if _camera == null or not is_finite(delta) or delta < 0.0:
		return
	# The same projection must interpret the press, drag and release. Freeze
	# the full camera transform and projection, including a pending map toggle.
	if session.state == Session.State.AIMING or session.is_paused():
		return
	if session.state == Session.State.MENU:
		if not _showing_menu:
			_apply_menu()
		_course_index = session.course_index
		return
	var needs_overview: bool = overview or session.state in [Session.State.MENU, Session.State.RESULT]
	if needs_overview:
		if not _showing_overview or _showing_menu:
			_apply_overview()
		_course_index = session.course_index
		return
	var course_changed: bool = session.course_index != _course_index
	if course_changed or not _follow_initialized or _showing_overview:
		snap_for_course(session)
		return
	# Wait for the restored safe position before following a water return.
	if session.state == Session.State.RETURNING:
		return
	var weight := 1.0 - exp(-FOLLOW_RESPONSE * minf(delta, 0.1))
	_anchor = _anchor.lerp(_desired_anchor(session), weight)
	_apply_follow()


func _desired_anchor(session) -> Vector3:
	var point: Vector3 = _world.ball.position
	var anticipation := Vector3.ZERO
	if session.state == Session.State.MOVING:
		# A short lead keeps the landing area visible without swinging the view
		# around whenever the ball rebounds against a side wall.
		anticipation = Vector3(session.velocity.x, 0.0, session.velocity.y) * 0.0009
		anticipation = anticipation.limit_length(0.75)
	point.y = maxf(point.y, 0.14) + 0.1
	return point + FORWARD_BIAS + anticipation


func _apply_follow() -> void:
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	# Retaining the vertical FOV in a portrait viewport brings the ball closer.
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.fov = FOLLOW_FOV
	_camera.position = _anchor + FOLLOW_OFFSET
	_camera.look_at(_anchor, Vector3.UP)
	_showing_overview = false
	_showing_menu = false


func _apply_menu() -> void:
	# The menu uses the middle of the portrait viewport as a landscape card.
	# A wider yaw and lower angle reveal the garden, rail depth and the ramp,
	# with the full fairway centered inside that crop.
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = MENU_SIZE
	_camera.position = MENU_POSITION
	_camera.look_at(MENU_TARGET, Vector3.UP)
	_showing_overview = true
	_showing_menu = true


func _apply_overview() -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = _overview_aspect
	_camera.size = _overview_size
	_camera.transform = _overview_transform
	_showing_overview = true
	_showing_menu = false

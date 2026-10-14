extends Node2D
## Native application: input ownership, safe-area layout and model/view integration.

const Session = preload("res://scripts/golf_session.gd")
const Records = preload("res://scripts/record_store.gd")
const Painter = preload("res://scripts/game_painter.gd")
const Config = preload("res://scripts/game_config.gd")
const WorldScene = preload("res://scenes/course_3d.tscn")
const Physics3D = preload("res://scripts/physics_3d.gd")
const MOUSE_POINTER := -2

var session = Session.new()
var store
var painter = Painter.new()
var record_path: String = Config.RECORD_PATH_3D
var use_3d: bool = true
var world
var world_viewport: SubViewport
var ui_presses: Dictionary = {}
var layout: Dictionary = {}
var visual_time: float = 0.0
var result_recorded: bool = false
var initialized: bool = false


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--record-path="):
			record_path = argument.trim_prefix("--record-path=")
	store = Records.new(record_path)
	if use_3d:
		world_viewport = SubViewport.new()
		world_viewport.name = "Mapa3D"
		world_viewport.size = Vector2i(592, 900)
		world_viewport.own_world_3d = true
		world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(world_viewport)
		world = WorldScene.instantiate()
		world_viewport.add_child(world)
		world.setup(session)
		session.motion_adapter = Physics3D.new(world)
	initialized = true
	_update_layout()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if world != null:
		world.sync(session, visual_time)
	session.update(delta)
	if world != null:
		world.sync(session, visual_time)
	if session.state == Session.State.RESULT and not result_recorded:
		result_recorded = true
		store.complete_session(session.total())


func _process(delta: float) -> void:
	if not session.is_paused():
		visual_time += delta
	_update_layout()
	if world != null:
		world.sync(session, visual_time)
	queue_redraw()


func _draw() -> void:
	if initialized:
		painter.paint(self, session, store, buttons(), visual_time)


static func layout_for(viewport_size: Vector2, safe_area: Rect2 = Rect2()) -> Dictionary:
	var area := Rect2(Vector2.ZERO, viewport_size)
	if safe_area.has_area():
		area = area.intersection(safe_area)
	if not area.has_area():
		area = Rect2(Vector2.ZERO, viewport_size)
	var fit: float = minf(area.size.x / Config.LOGICAL_SIZE.x, area.size.y / Config.LOGICAL_SIZE.y)
	return {"scale": fit, "offset": area.position + (area.size - Config.LOGICAL_SIZE * fit) / 2.0, "area": area}


func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var safe := Rect2()
	if OS.has_feature("mobile"):
		var raw_safe := Rect2(DisplayServer.get_display_safe_area())
		var window_size := Vector2(DisplayServer.window_get_size())
		if raw_safe.has_area() and window_size.x > 0 and window_size.y > 0:
			var ratio := viewport_size / window_size
			safe = Rect2((raw_safe.position - Vector2(DisplayServer.window_get_position())) * ratio, raw_safe.size * ratio)
	_apply_layout(layout_for(viewport_size, safe))


func _apply_layout(new_layout: Dictionary) -> void:
	if not layout.is_empty():
		var offset_changed := not Vector2(layout["offset"]).is_equal_approx(Vector2(new_layout["offset"]))
		var scale_changed := not is_equal_approx(float(layout["scale"]), float(new_layout["scale"]))
		if offset_changed or scale_changed:
			# A held screen position has different logical coordinates after resize.
			# Invalidate the old gesture before accepting another release.
			session.cancel_aim()
			ui_presses.clear()
	layout = new_layout
	position = layout["offset"]
	scale = Vector2.ONE * layout["scale"]


func to_logical(screen_point: Vector2) -> Vector2:
	return (screen_point - Vector2(layout["offset"])) / float(layout["scale"])


func to_screen(logical_point: Vector2) -> Vector2:
	return Vector2(layout["offset"]) + logical_point * float(layout["scale"])


func game_to_ui(map_point: Vector2) -> Vector2:
	if world == null:
		return map_point
	return Vector2(64, 200) + world.project_map(map_point, session.elevation)


func game_to_screen(map_point: Vector2) -> Vector2:
	return to_screen(game_to_ui(map_point))


func _map_input(ui_point: Vector2) -> Vector2:
	if world == null:
		return ui_point
	return world.unproject_map(ui_point - Vector2(64, 200), session.elevation)


func buttons() -> Array[Dictionary]:
	if session.pause_reasons.has("modal"):
		return [
			_button("continue", Rect2(112, 650, 496, 66), "Continuar", "primary"),
			_button("abandon", Rect2(112, 734, 496, 62), "Voltar ao menu", "secondary")
		]
	if session.state == Session.State.MENU:
		return [_button("play", Rect2(100, 870, 520, 76), "Jogar", "primary")]
	if session.state == Session.State.RESULT:
		return [
			_button("play", Rect2(100, 960, 520, 76), "Jogar novamente", "primary"),
			_button("home", Rect2(100, 1055, 520, 70), "Menu", "secondary")
		]
	var allowed: bool = session.state in [Session.State.READY, Session.State.AIMING, Session.State.MOVING]
	return [_button("menu", Rect2(548, 44, 108, 58), "Menu", "quiet", allowed)]


func _button(id: String, rect: Rect2, text: String, style: String, enabled: bool = true) -> Dictionary:
	return {"id": id, "rect": rect, "text": text, "style": style, "enabled": enabled}


func _input(event: InputEvent) -> void:
	if not initialized:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			if session.pause_reasons.has("modal"):
				_action("continue")
			else:
				_action("menu")
			get_viewport().set_input_as_handled()
		return
	# Touch is handled directly. Ignore synthetic mouse events for the same gesture.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.canceled:
			if session.active_pointer == event.index:
				session.cancel_aim()
			ui_presses.erase(event.index)
		elif event.pressed:
			pointer_down(to_logical(event.position), event.index)
		else:
			pointer_up(to_logical(event.position), event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		session.drag_aim(_map_input(to_logical(event.position)), event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down(to_logical(event.position), MOUSE_POINTER)
		else:
			pointer_up(to_logical(event.position), MOUSE_POINTER)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		session.drag_aim(_map_input(to_logical(event.position)), MOUSE_POINTER)


func pointer_down(point: Vector2, pointer_id: int) -> void:
	if _application_paused():
		return
	if session.state == Session.State.AIMING and session.active_pointer == pointer_id:
		return
	for button in buttons():
		if button["enabled"] and Rect2(button["rect"]).has_point(point):
			if button["id"] == "menu":
				_action("menu")
			else:
				ui_presses[pointer_id] = button["id"]
			return
	session.begin_aim(_map_input(point), pointer_id)


func pointer_up(point: Vector2, pointer_id: int) -> void:
	if _application_paused():
		ui_presses.erase(pointer_id)
		return
	if session.state == Session.State.AIMING and session.active_pointer == pointer_id:
		session.release_aim(_map_input(point), pointer_id)
		return
	if not ui_presses.has(pointer_id):
		return
	var pressed_id: String = ui_presses[pointer_id]
	ui_presses.erase(pointer_id)
	for button in buttons():
		if button["id"] == pressed_id and button["enabled"] and Rect2(button["rect"]).has_point(point):
			_action(pressed_id)
			return


func _application_paused() -> bool:
	for reason in session.pause_reasons:
		if reason != "modal":
			return true
	return false


func _action(id: String) -> void:
	ui_presses.clear()
	match id:
		"play":
			session.start_session()
			result_recorded = false
		"menu":
			session.request_menu()
		"continue":
			session.continue_session()
		"abandon", "home":
			session.abandon_session()
	queue_redraw()


func _notification(what: int) -> void:
	if not initialized:
		return
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			set_application_pause("focus", true)
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			set_application_pause("focus", false)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			set_application_pause("app_focus", true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			set_application_pause("app_focus", false)
		NOTIFICATION_APPLICATION_PAUSED:
			set_application_pause("suspend", true)
		NOTIFICATION_APPLICATION_RESUMED:
			set_application_pause("suspend", false)


func set_application_pause(reason: String, paused: bool) -> void:
	ui_presses.clear()
	session.set_paused(reason, paused)
	queue_redraw()

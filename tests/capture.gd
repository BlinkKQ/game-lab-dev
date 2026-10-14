extends SceneTree
## Native render smoke test. Requires a graphical display; no headless screenshots.

const Session = preload("res://scripts/golf_session.gd")
const Config = preload("res://scripts/game_config.gd")

var output_directory := OS.get_cache_dir().path_join("gamelab-captures")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("A captura requer um display gráfico, como Xvfb.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output_directory = argument.trim_prefix("--capture-dir=")
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		quit(1)
		return
	var app = load("res://scenes/main.tscn").instantiate()
	var record := output_directory.path_join("record-%d.json" % OS.get_process_id())
	app.record_path = record
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	await _snapshot(app, "01-menu")
	await _click(app, Vector2(360, 908))
	_expect(app.session.state == Session.State.READY, "Menu inicia sessão")
	await _snapshot(app, "02-percurso-01")
	await _mouse(app, app.session.position, true)
	await _motion(app, app.session.position + Vector2(0, 96))
	await _snapshot(app, "03-mira")
	await _mouse(app, app.session.position, false)
	await _click(app, Vector2(602, 73))
	await _snapshot(app, "04-confirmacao")
	await _click(app, Vector2(360, 683))
	await _shoot(app, Vector2(360, 260))
	_expect(app.session.state == Session.State.CAPTURED, "Primeiro buraco capturado")
	await _snapshot(app, "05-captura")
	_advance_feedback(app)
	await _snapshot(app, "06-percurso-02")
	for target in [Vector2(540, 760), Vector2(540, 440), Vector2(260, 280)]:
		await _shoot(app, target)
	_advance_feedback(app)
	await _snapshot(app, "07-percurso-03")
	for target in [Vector2(170, 780), Vector2(170, 460), Vector2(360, 280)]:
		await _shoot(app, target)
	_advance_feedback(app)
	_expect(app.session.state == Session.State.RESULT, "Sessão nativa chegou ao resultado")
	_expect(app.session.results == [1, 3, 3] and app.store.persisted_best == 7, "Resultado e recorde confirmados")
	await _snapshot(app, "08-resultado")
	var store_reload = load("res://scripts/record_store.gd").new(record)
	_expect(store_reload.persisted_best == 7, "Recorde lido de volta do arquivo")
	app.queue_free()
	await process_frame
	if FileAccess.file_exists(record):
		DirAccess.remove_absolute(record)
	print("Renderização nativa: 8 capturas, sessão [1, 3, 3], %d falhas." % failures.size())
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _snapshot(app, name: String) -> void:
	app.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(not image.is_empty(), "Imagem disponível: " + name)
	_expect(image.save_png(output_directory.path_join(name + ".png")) == OK, "PNG salvo: " + name)


func _shoot(app, target: Vector2) -> void:
	if app.session.state != Session.State.READY:
		failures.append("Tacada preparada fora de READY: " + str(app.session.state))
		return
	var start: Vector2 = app.session.position
	var speed := sqrt(2.0 * Config.DECELERATION * start.distance_to(target))
	var drag_length: float = Config.DEAD_ZONE + (Config.MAX_DRAG - Config.DEAD_ZONE) * speed / Config.MAX_SPEED
	var release: Vector2 = start - start.direction_to(target) * drag_length
	await _mouse(app, start, true)
	await _motion(app, release)
	await _mouse(app, release, false)
	for frame in range(360):
		app._physics_process(Config.PHYSICS_STEP)
		if app.session.state != Session.State.MOVING:
			break
	_expect(app.session.state in [Session.State.READY, Session.State.CAPTURED], "Tacada terminou em estado válido")


func _advance_feedback(app) -> void:
	for frame in range(60):
		if app.session.state != Session.State.CAPTURED:
			break
		app._physics_process(Config.PHYSICS_STEP)


func _click(app, point: Vector2) -> void:
	await _mouse(app, point, true)
	await _mouse(app, point, false)


func _mouse(app, logical: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = app.to_screen(logical)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _motion(app, logical: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = app.to_screen(logical)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

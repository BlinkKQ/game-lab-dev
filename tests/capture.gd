extends SceneTree
## Graphical 3D smoke test: actual camera input, terrain, native physics and records.

const Session = preload("res://scripts/golf_session.gd")
var output_directory := OS.get_cache_dir().path_join("gamelab-captures-3d")
var driver_path := "res://tests/test_3d.gd"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("A captura 3D requer um display gráfico.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output_directory = argument.trim_prefix("--capture-dir=")
		if argument.begins_with("--driver-path="):
			driver_path = argument.trim_prefix("--driver-path=")
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		quit(1)
		return
	var driver_script = load(driver_path)
	if driver_script == null or not driver_script.can_instantiate():
		printerr("Driver de teste 3D indisponível: ", driver_path)
		quit(1)
		return
	var driver = driver_script.new()
	var app = load("res://scenes/main.tscn").instantiate()
	var record := output_directory.path_join("record-3d-%d.json" % OS.get_process_id())
	app.record_path = record
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	await _snapshot(app, "01-menu")
	await driver._ui_click(app, Vector2(360, 908))
	await physics_frame
	_expect(app.session.state == Session.State.READY, "Menu inicia sessão 3D")
	await _snapshot(app, "02-percurso-01")
	var start: Vector2 = app.session.position
	await driver._mouse_game(app, start, true)
	await driver._motion_game(app, start + Vector2(0, 96))
	await _snapshot(app, "03-mira")
	await driver._mouse_game(app, start, false)
	await driver._ui_click(app, Vector2(602, 73))
	await _snapshot(app, "04-confirmacao")
	await driver._ui_click(app, Vector2(360, 683))
	_expect(await driver.reach_target(app, Vector2(360, 260), true), "Concluir primeiro buraco")
	await _snapshot(app, "05-captura")
	await driver.finish_capture(app)
	await _snapshot(app, "06-percurso-02")
	for target in [Vector2(550, 990), Vector2(550, 350), Vector2(260, 350)]:
		_expect(await driver.reach_target(app, target), "Rota elevada: " + str(target))
	_expect(await driver.reach_target(app, Vector2(260, 280), true), "Concluir buraco elevado")
	await driver.finish_capture(app)
	await _snapshot(app, "07-percurso-03")
	for target in [Vector2(160, 850), Vector2(160, 500), Vector2(360, 500)]:
		_expect(await driver.reach_target(app, target), "Rota segura: " + str(target))
	_expect(await driver.reach_target(app, Vector2(360, 280), true), "Concluir terceiro buraco")
	await driver.finish_capture(app)
	_expect(app.session.state == Session.State.RESULT and app.session.results.size() == 3, "Sessão 3D completa")
	_expect(app.store.persisted_best == app.session.total(), "Recorde 3D confirmado")
	await _snapshot(app, "08-resultado")
	var store_reload = load("res://scripts/record_store.gd").new(record)
	_expect(store_reload.persisted_best == app.session.total(), "Recorde 3D relido do arquivo")
	print("Renderização 3D: 8 capturas, resultados %s, %d falhas." % [str(app.session.results), failures.size()])
	app.queue_free()
	await process_frame
	if FileAccess.file_exists(record):
		DirAccess.remove_absolute(record)
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _snapshot(app, name: String) -> void:
	app.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_expect(not frame.is_empty(), "Imagem disponível: " + name)
	_expect(frame.save_png(output_directory.path_join(name + ".png")) == OK, "PNG salvo: " + name)

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

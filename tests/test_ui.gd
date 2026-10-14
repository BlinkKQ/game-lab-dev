extends RefCounted
## Real scene/input integration. No player data is used by this suite.

const Main = preload("res://scripts/main.gd")
const Session = preload("res://scripts/golf_session.gd")


func run(check: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var app = load("res://scenes/main.tscn").instantiate()
	# Shared UI/state regressions use the preserved planar adapter. Native 3D
	# collision, camera mapping and terrain are exercised by test_3d.gd.
	app.use_3d = false
	var path := OS.get_cache_dir().path_join("gamelab-ui-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	app.record_path = path
	tree.root.add_child(app)
	await tree.process_frame
	app.set_physics_process(false)
	app.set_process(false)
	check.call("Cena nativa abre o menu com recorde isolado", app.session.state == Session.State.MENU and app.store.persisted_best == null)
	await _mouse(app, Vector2(360, 908), true)
	await _mouse(app, Vector2(360, 908), false)
	check.call("Botão Jogar recebe eventos reais do viewport", app.session.state == Session.State.READY and app.session.total() == 0)

	var ball: Vector2 = app.session.position
	await _mouse(app, ball + Vector2(73, 0), true)
	await _mouse(app, ball + Vector2(73, 0), false)
	check.call("Conversão da tela respeita raio de toque fora de 72", app.session.state == Session.State.READY)
	await _mouse(app, ball, true)
	await _motion(app, ball + Vector2(0, 96))
	check.call("Mouse real prepara potência de 50%", app.session.state == Session.State.AIMING and is_equal_approx(app.session.power(), 0.5))
	await _mouse(app, ball + Vector2(0, 96), false)
	check.call("Soltura real lança uma única tacada", app.session.state == Session.State.MOVING and app.session.current_strokes == 1)
	await _mouse(app, ball + Vector2(0, 96), false)
	check.call("Soltura repetida não duplica tacada na cena", app.session.current_strokes == 1)

	app.session.start_session()
	ball = app.session.position
	await _mouse(app, ball, true, InputEvent.DEVICE_ID_EMULATION)
	await _mouse(app, ball + Vector2(0, 96), false, InputEvent.DEVICE_ID_EMULATION)
	check.call("Mouse emulado por toque é ignorado na aplicação", app.session.state == Session.State.READY and app.session.current_strokes == 0)
	await _touch(app, ball, 0, true)
	await _touch(app, ball, 1, true)
	await _drag(app, ball + Vector2(0, 96), 1)
	check.call("Segundo dedo não assume a mira na cena", app.session.active_pointer == 0 and app.session.power() == 0.0)
	await _drag(app, ball + Vector2(0, 96), 0)
	await _touch(app, ball + Vector2(0, 96), 1, false)
	check.call("Soltura do segundo dedo não dispara", app.session.state == Session.State.AIMING and app.session.current_strokes == 0)
	await _touch(app, ball + Vector2(0, 96), 0, false)
	check.call("Toque direto completo registra um lançamento", app.session.state == Session.State.MOVING and app.session.current_strokes == 1)

	app.session.start_session()
	ball = app.session.position
	await _mouse(app, ball, true)
	await _motion(app, Vector2(602, 73))
	await _mouse(app, Vector2(602, 73), false)
	check.call("Arraste sobre Menu mantém propriedade do gesto", app.session.state == Session.State.MOVING and not app.session.pause_reasons.has("modal"))
	app.session.start_session()
	ball = app.session.position
	await _touch(app, ball, 0, true)
	await _drag(app, ball + Vector2(0, 96), 0)
	await _touch(app, Vector2(602, 73), 1, true)
	check.call("Nova ação de Menu cancela mira e abre confirmação", app.session.state == Session.State.READY and app.session.pause_reasons.has("modal"))
	await _touch(app, Vector2(602, 73), 1, false)
	await _touch(app, ball + Vector2(0, 96), 0, false)
	check.call("Solturas antigas não ativam modal nem lançam", app.session.pause_reasons.has("modal") and app.session.current_strokes == 0)
	await _mouse(app, Vector2(360, 683), true)
	await _mouse(app, Vector2(360, 683), false)
	check.call("Continuar remove apenas pausa modal", app.session.state == Session.State.READY and not app.session.is_paused())

	await _mouse(app, ball, true)
	await _motion(app, ball + Vector2(0, 96))
	app.set_application_pause("focus", true)
	app.set_application_pause("focus", false)
	await _mouse(app, ball + Vector2(0, 96), false)
	check.call("Perda de foco invalida soltura na camada real de entrada", app.session.state == Session.State.READY and app.session.current_strokes == 0)
	await _mouse(app, ball, true)
	await _mouse(app, ball + Vector2(0, 96), false)
	await _mouse(app, Vector2(602, 73), true)
	app.set_application_pause("focus", true)
	app.set_application_pause("focus", false)
	check.call("Recuperar foco conserva confirmação aberta", app.session.pause_reasons.has("modal") and app.session.is_paused())
	var frozen: Vector2 = app.session.position
	app._physics_process(0.5)
	check.call("Confirmação congela movimento na aplicação", app.session.position == frozen)
	await _mouse(app, Vector2(360, 683), true)
	await _mouse(app, Vector2(360, 683), false)
	app._physics_process(1.0 / 60.0)
	check.call("Continuar retoma movimento sem impulso extra", app.session.state == Session.State.MOVING and app.session.position != frozen and app.session.current_strokes == 1)

	app.session.state = Session.State.RESULT
	app.session.results.assign([3, 4, 5])
	app.session.current_strokes = 0
	app.result_recorded = false
	app._physics_process(0.0)
	check.call("Transição para resultado grava total completo", app.store.persisted_best == 12 and FileAccess.file_exists(path))
	app.store.failure_stage = "replace"
	app._physics_process(0.0)
	check.call("Renderizar resultado novamente não repete gravação", app.store.last_error.is_empty() and app.store.persisted_best == 12)
	app.store.failure_stage = ""
	await _mouse(app, Vector2(360, 1090), true)
	await _mouse(app, Vector2(360, 1090), false)
	check.call("Botão Menu do resultado volta sem apagar recorde", app.session.state == Session.State.MENU and app.store.persisted_best == 12)
	await _mouse(app, Vector2(360, 908), true)
	await _mouse(app, Vector2(360, 908), false)
	await _mouse(app, Vector2(602, 73), true)
	await _mouse(app, Vector2(360, 765), true)
	await _mouse(app, Vector2(360, 765), false)
	check.call("Abandono real descarta sessão e preserva recorde", app.session.state == Session.State.MENU and app.session.results.is_empty() and app.store.persisted_best == 12)

	for size in [Vector2(390, 844), Vector2(432, 768), Vector2(1024, 768), Vector2(720, 1440)]:
		var fit: Dictionary = Main.layout_for(size)
		var rect := Rect2(fit.offset, Vector2(720, 1280) * float(fit.scale))
		check.call("Campo lógico inteiro cabe em %s" % str(size), rect.position.x >= -0.001 and rect.position.y >= -0.001 and rect.end.x <= size.x + 0.001 and rect.end.y <= size.y + 0.001)
	var safe := Rect2(0, 48, 390, 744)
	var fit: Dictionary = Main.layout_for(Vector2(390, 844), safe)
	var logical := Vector2(360, 990)
	var screen := Vector2(fit.offset) + logical * float(fit.scale)
	check.call("Área segura conserva escala uniforme e coordenadas de toque", ((screen - Vector2(fit.offset)) / float(fit.scale)).is_equal_approx(logical) and Vector2(fit.offset).y >= safe.position.y)
	check.call("Projeto desativa emulação redundante de mouse e toque", not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch") and not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"))
	# Reproduce a real resize while holding the mouse, then release at the
	# identical physical point: resize must not fabricate a power/direction.
	var original_size: Vector2i = tree.root.size
	tree.root.size = Vector2i(432, 768)
	await tree.process_frame
	app._update_layout()
	app.session.start_session()
	var held_screen: Vector2 = app.to_screen(app.session.position)
	await _mouse(app, app.session.position, true)
	tree.root.size = Vector2i(864, 768)
	await tree.process_frame
	app._update_layout()
	check.call("Redimensionar a janela cancela a mira ativa", app.session.state == Session.State.READY and app.session.current_strokes == 0)
	await _mouse(app, app.to_logical(held_screen), false)
	check.call("Soltura imóvel após redimensionar não inventa tacada", app.session.state == Session.State.READY and app.session.current_strokes == 0 and app.session.velocity == Vector2.ZERO)
	tree.root.size = original_size
	await tree.process_frame
	app._update_layout()
	app.queue_free()
	await tree.process_frame
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _mouse(app, logical: Vector2, pressed: bool, device: int = 0) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.device = device
	event.position = app.to_screen(logical)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _motion(app, logical: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = app.to_screen(logical)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _touch(app, logical: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = app.to_screen(logical)
	event.index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _drag(app, logical: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = app.to_screen(logical)
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame

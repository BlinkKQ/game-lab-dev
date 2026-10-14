extends RefCounted
## Integration checks for camera changes that can alter a real input gesture.
## Native terrain and scoring remain covered by test_3d.gd.

const Session = preload("res://scripts/golf_session.gd")
const STEP := 1.0 / 60.0
const CAMERA_BUTTON := Vector2(461, 73)
const SOUND_BUTTON := Vector2(602, 1251)

var completed := false


func run(check: Callable) -> void:
	completed = false
	var tree := Engine.get_main_loop() as SceneTree
	var app = load("res://scenes/main.tscn").instantiate()
	var path := OS.get_cache_dir().path_join("gamelab-presentation-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	app.record_path = path
	tree.root.add_child(app)
	await tree.process_frame
	app.set_physics_process(false)
	app.set_process(false)
	var cues: Array[StringName] = []
	app.audio_feedback.cue_played.connect(func(cue: StringName) -> void: cues.append(cue))
	app._process(STEP)
	check.call("Apresentação: menu mostra o percurso em visão geral", app.session.state == Session.State.MENU and app.world.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	await _mouse_ui(app, Vector2(360, 908), true)
	await _mouse_ui(app, Vector2(360, 908), false)
	_tick(app, STEP)
	await tree.physics_frame
	check.call("Apresentação: Jogar inicia câmera de perspectiva que segue a bola", app.camera_controller != null and not app.camera_controller.overview and app.world.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and app.session.state == Session.State.READY)
	check.call("Apresentação: enquadramento de jogo mantém a bola dentro do campo visível", _ball_visible(app))
	check.call("Apresentação: perspectiva recupera pontos próximos no plano da bola", _round_trip(app))

	# Hold actual screen coordinates while time advances. A camera that drifts
	# here would silently change launch direction or power for a stationary hand.
	var start: Vector2 = app.session.position
	var release_screen: Vector2 = app.game_to_screen(start + Vector2(0, 96))
	await _mouse_world(app, start, true)
	await _motion_screen(release_screen)
	check.call("Apresentação: gesto real prepara meia potência em perspectiva", app.session.state == Session.State.AIMING and absf(app.session.power() - 0.5) < 0.002)
	var frozen_camera := _camera_pose(app)
	for delta in [0.008, STEP, 0.1, 0.4, 0.05]:
		_tick(app, delta)
	check.call("Apresentação: câmera e lente ficam exatamente fixas durante a mira", _camera_pose(app) == frozen_camera)
	await _motion_screen(release_screen)
	check.call("Apresentação: repetir o mesmo pixel após a espera mantém direção e potência", app.session.aim_direction().distance_to(Vector2.UP) < 0.002 and absf(app.session.power() - 0.5) < 0.002)
	await _mouse_screen(release_screen, false)
	check.call("Apresentação: soltura em perspectiva registra somente uma tacada", app.session.state == Session.State.MOVING and app.session.current_strokes == 1)
	var before_motion := _camera_pose(app)
	var before_ball: Vector2 = app.session.position
	for frame in range(15):
		_tick(app, STEP)
		if frame % 5 == 0:
			await tree.physics_frame
	check.call("Apresentação: câmera acompanha o deslocamento físico após a soltura", app.session.position.distance_to(before_ball) > 10.0 and _camera_pose(app) != before_motion)
	check.call("Áudio: uma tacada real emite um único som de lançamento", cues.count(&"launch") == 1)

	# Independent focus/suspend reasons must freeze the camera until all clear.
	frozen_camera = _camera_pose(app)
	var frozen_ball: Vector2 = app.session.position
	app.set_application_pause("focus", true)
	app.set_application_pause("suspend", true)
	var cues_before_pause := cues.size()
	for delta in [STEP, 0.1, 0.4]:
		_tick(app, delta)
	check.call("Apresentação: pausa congela câmera em movimento e a posição física", _camera_pose(app) == frozen_camera and app.session.position == frozen_ball)
	check.call("Áudio: pausa interrompe as vozes e não agenda novos sons", not _has_playing_voice(app) and cues.size() == cues_before_pause)
	app.set_application_pause("focus", false)
	_tick(app, 0.2)
	check.call("Apresentação: recuperar foco ainda respeita suspensão pendente", app.session.is_paused() and _camera_pose(app) == frozen_camera and app.session.position == frozen_ball)
	app.set_application_pause("suspend", false)
	_tick(app, STEP)
	check.call("Apresentação: retomada continua seguindo sem criar nova tacada", not app.session.is_paused() and app.session.position != frozen_ball and _camera_pose(app) != frozen_camera and app.session.current_strokes == 1)
	check.call("Áudio: retomada não repete o som da tacada interrompida", cues.count(&"launch") == 1)
	await _settle(app)
	check.call("Apresentação: movimento chega ao repouso com enquadramento utilizável", app.session.state == Session.State.READY and _ball_visible(app))

	await _mouse_ui(app, CAMERA_BUTTON, true)
	await _mouse_ui(app, CAMERA_BUTTON, false)
	app._process(STEP)
	check.call("Apresentação: botão real muda para visão geral sem contar tacada", app.camera_controller.overview and app.world.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and app.session.current_strokes == 1)
	await _mouse_ui(app, CAMERA_BUTTON, true)
	await _mouse_ui(app, CAMERA_BUTTON, false)
	app._process(STEP)
	check.call("Apresentação: botão retorna à perspectiva e mantém projeção correta", not app.camera_controller.overview and app.world.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and _round_trip(app))

	# A second finger can change the camera while the first owns an aim. Both
	# releases become harmless after the projection change invalidates the aim.
	app.session.start_session()
	_tick(app, STEP)
	await tree.physics_frame
	start = app.session.position
	var stale_release: Vector2 = app.game_to_screen(start + Vector2(0, 96))
	await _touch_screen(app.game_to_screen(start), 0, true)
	await _drag_screen(stale_release, 0)
	check.call("Apresentação: primeiro dedo inicia mira antes da troca de câmera", app.session.state == Session.State.AIMING and app.session.active_pointer == 0)
	await _touch_screen(app.to_screen(CAMERA_BUTTON), 1, true)
	await _touch_screen(app.to_screen(CAMERA_BUTTON), 1, false)
	app._process(STEP)
	check.call("Apresentação: segundo dedo troca a câmera cancelando a mira", app.camera_controller.overview and app.session.state == Session.State.READY and app.session.current_strokes == 0)
	await _touch_screen(stale_release, 0, false)
	await _touch_screen(app.to_screen(CAMERA_BUTTON), 1, false)
	app._process(STEP)
	check.call("Apresentação: solturas antigas não disparam nem repetem a troca", app.camera_controller.overview and app.session.state == Session.State.READY and app.session.current_strokes == 0 and app.ui_presses.is_empty())

	# The new projection must accept a new gesture after the old one was invalidated.
	await _mouse_world(app, start, true)
	await _motion_screen(app.game_to_screen(start + Vector2(0, 96)))
	await _mouse_world(app, start + Vector2(0, 96), false)
	check.call("Apresentação: nova mira em visão geral continua lançando pelo mouse", app.session.state == Session.State.MOVING and app.session.current_strokes == 1)
	await _settle(app)
	await _mouse_ui(app, CAMERA_BUTTON, true)
	await _mouse_ui(app, CAMERA_BUTTON, false)
	app._process(STEP)
	await _mouse_ui(app, SOUND_BUTTON, true)
	await _mouse_ui(app, SOUND_BUTTON, false)
	check.call("Áudio: botão real silencia o jogo e para qualquer voz ativa", not app.audio_feedback.enabled and not _has_playing_voice(app))
	cues.clear()

	# Move to the real raised plateau. This is a camera/input fixture, not a
	# substitute for native movement through the ramp in the 3D physics suite.
	app.session.start_session()
	app.session.course_index = 1
	app.session.position = Vector2(550, 420)
	app.session.previous_position = app.session.position
	app.session.elevation = 0.74
	app.session.previous_elevation = 0.74
	app._physics_process(0.0)
	await tree.physics_frame
	app.session.motion_adapter.reset(app.session)
	app._process(STEP)
	check.call("Apresentação: mudar de percurso reenquadra a bola no patamar elevado", app.world.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and _ball_visible(app) and absf(app.session.elevation - 0.74) < 0.025)
	check.call("Apresentação: perspectiva usa a altura elevada para projetar e recuperar a mira", _round_trip(app))
	start = app.session.position
	await _touch_screen(app.game_to_screen(start), 0, true)
	var elevated_release: Vector2 = app.game_to_screen(start + Vector2(96, 0))
	await _drag_screen(elevated_release, 0)
	frozen_camera = _camera_pose(app)
	_tick(app, 0.4)
	await _drag_screen(elevated_release, 0)
	check.call("Apresentação: toque elevado mantém câmera, altura e potência durante a mira", app.session.state == Session.State.AIMING and _camera_pose(app) == frozen_camera and absf(app.session.elevation - 0.74) < 0.025 and absf(app.session.power() - 0.5) < 0.002)
	await _touch_screen(elevated_release, 0, false)
	check.call("Apresentação: toque no patamar lança uma única tacada na direção escolhida", app.session.state == Session.State.MOVING and app.session.current_strokes == 1 and app.session.velocity.distance_to(Vector2(-500, 0)) < 0.1)
	_tick(app, STEP)
	_tick(app, STEP)
	check.call("Áudio: nova tacada com som desligado não emite sons", cues.is_empty() and not _has_playing_voice(app))
	await _mouse_ui(app, SOUND_BUTTON, true)
	await _mouse_ui(app, SOUND_BUTTON, false)
	_tick(app, STEP)
	check.call("Áudio: reativar o som não reproduz tacadas antigas", app.audio_feedback.enabled and cues.is_empty())

	app.session.state = Session.State.RESULT
	app.session.results.assign([1, 2, 3])
	app.session.current_strokes = 0
	app._process(STEP)
	check.call("Apresentação: resultado retorna à visão geral do percurso", app.world.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	await _mouse_ui(app, Vector2(360, 1090), true)
	await _mouse_ui(app, Vector2(360, 1090), false)
	app._process(STEP)
	await _mouse_ui(app, Vector2(360, 908), true)
	await _mouse_ui(app, Vector2(360, 908), false)
	_tick(app, STEP)
	check.call("Apresentação: nova sessão após resultado volta à perspectiva sem estado antigo", app.session.state == Session.State.READY and app.session.course_index == 0 and app.session.current_strokes == 0 and app.world.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and _ball_visible(app))
	start = app.session.position
	await _mouse_world(app, start, true)
	await _motion_screen(app.game_to_screen(start + Vector2(0, 96)))
	await _mouse_world(app, start + Vector2(0, 96), false)
	_tick(app, STEP)
	_tick(app, STEP)
	check.call("Áudio: som reativado reproduz somente a próxima tacada", cues.count(&"launch") == 1 and app.session.current_strokes == 1)

	app.audio_feedback.set_enabled(false)
	await tree.process_frame
	app.queue_free()
	await tree.process_frame
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	completed = true


func _tick(app, delta: float) -> void:
	app._physics_process(delta)
	app._process(delta)


func _settle(app) -> void:
	for frame in range(240):
		if app.session.state != Session.State.MOVING:
			return
		_tick(app, STEP)
		if frame % 20 == 0:
			await (Engine.get_main_loop() as SceneTree).physics_frame


func _camera_pose(app) -> Array:
	var camera: Camera3D = app.world.camera
	return [camera.transform, camera.projection, camera.fov, camera.size, camera.frustum_offset]


func _has_playing_voice(app) -> bool:
	for child in app.audio_feedback.get_children():
		if child is AudioStreamPlayer and child.playing:
			return true
	return false


func _ball_visible(app) -> bool:
	var camera: Camera3D = app.world.camera
	var pixel: Vector2 = app.world.project_map(app.session.position, app.session.elevation)
	return pixel.is_finite() and Rect2(Vector2.ZERO, Vector2(app.world_viewport.size)).has_point(pixel) and not camera.is_position_behind(app.world.ball.global_position)


func _round_trip(app) -> bool:
	for offset in [Vector2.ZERO, Vector2(-48, 0), Vector2(0, 48)]:
		var point: Vector2 = app.session.position + offset
		var projected: Vector2 = app.world.project_map(point, app.session.elevation)
		var recovered: Vector2 = app.world.unproject_map(projected, app.session.elevation)
		if not recovered.is_finite() or recovered.distance_to(point) > 0.05:
			return false
	return true


func _mouse_ui(app, point: Vector2, pressed: bool) -> void:
	await _mouse_screen(app.to_screen(point), pressed)


func _mouse_world(app, point: Vector2, pressed: bool) -> void:
	await _mouse_screen(app.game_to_screen(point), pressed)


func _mouse_screen(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _motion_screen(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _touch_screen(point: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _drag_screen(point: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = point
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame

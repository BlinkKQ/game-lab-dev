extends RefCounted
## Native 3D integration tests. Fixtures use the actual scene and colliders;
## complete sessions launch exclusively through camera-projected mouse events.

const Session = preload("res://scripts/golf_session.gd")
const Config = preload("res://scripts/game_config.gd")
const Records = preload("res://scripts/record_store.gd")
const STEP := 1.0 / 60.0
const RADIUS_METERS := 0.14

var completed := false


func run(check: Callable) -> void:
	completed = false
	var tree := Engine.get_main_loop() as SceneTree
	var app = load("res://scenes/main.tscn").instantiate()
	var path := OS.get_cache_dir().path_join("gamelab-native3d-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	app.record_path = path
	tree.root.add_child(app)
	await tree.process_frame
	app.set_physics_process(false)
	app.set_process(false)
	await _ui_click(app, Vector2(360, 908))
	await tree.physics_frame
	check.call("3D: Jogar cria esfera e câmera nativas", app.world.ball is CharacterBody3D and app.world.camera is Camera3D and app.session.state == Session.State.READY)
	check.call("3D: esfera usa shape esférico e colide com terreno e paredes", _has_sphere_shape(app.world.ball) and (app.world.ball.collision_mask & 3) == 3)
	var map_point := Vector2(360, 990)
	var projected: Vector2 = app.world.project_map(map_point, RADIUS_METERS)
	var unprojected: Vector2 = app.world.unproject_map(projected, RADIUS_METERS)
	check.call("3D: câmera projeta e recupera coordenadas do campo", projected.is_finite() and unprojected.distance_to(map_point) < 0.05)

	# A real falling sphere must meet the real floor, rather than a visual height.
	await _fixture(app, 0, Vector2(360, 990), 1.4, Vector2.ZERO)
	var initial_height: float = app.session.elevation
	for frame in range(120):
		app._physics_process(STEP)
		if frame % 20 == 0:
			await tree.physics_frame
	check.call("3D: gravidade derruba a esfera até o piso real", initial_height > app.session.elevation + 1.0 and absf(app.session.elevation - RADIUS_METERS) < 0.04)
	check.call("3D: contato com o piso confirma repouso sem atravessá-lo", app.session.motion_adapter.grounded and app.session.state == Session.State.READY and absf(app.world.ball.position.y - app.session.elevation) < 0.001)

	# Wall collision is exercised at the maximum launch speed, with native casts.
	await _fixture(app, 0, Vector2(600, 990), RADIUS_METERS, Vector2(Config.MAX_SPEED, 0))
	var bounced := false
	var contained := true
	for frame in range(90):
		app._physics_process(STEP)
		bounced = bounced or app.session.velocity.x < -1.0
		contained = contained and app.session.position.x <= 642.1 and app.session.position.x >= 77.9
		if frame % 20 == 0:
			await tree.physics_frame
	check.call("3D: parede nativa rebate a esfera em velocidade máxima", bounced and contained and app.session.current_strokes == 1)

	# An obstacle top is a valid horizontal support after a vertical landing.
	var wall_top_point := Vector2(260, 564)
	await _fixture(app, 1, wall_top_point, 1.4, Vector2.ZERO)
	var wall_top_height: float = app.world.terrain_height(wall_top_point) + 0.42 + RADIUS_METERS
	for frame in range(120):
		app._physics_process(STEP)
		if frame % 20 == 0:
			await tree.physics_frame
		if app.session.state == Session.State.READY:
			break
	check.call("3D: aterrissar sobre obstáculo confirma repouso sem travar a partida", app.session.state == Session.State.READY and app.session.motion_adapter.grounded and absf(app.session.elevation - wall_top_height) < 0.025 and absf(app.world.ball.position.y - wall_top_height) < 0.025)
	await _mouse_game(app, wall_top_point, true)
	check.call("3D: nova mira sobre obstáculo mantém a altura física alcançada", app.session.state == Session.State.AIMING and absf(app.world.ball.position.y - wall_top_height) < 0.025)
	await _mouse_game(app, wall_top_point, false)

	# Ramp two occupies the full width; its top is 60 cm above the lower floor.
	var ramp_start := Vector2(550, 735)
	await _fixture(app, 1, ramp_start, RADIUS_METERS, Vector2(0, -840))
	var climbed := false
	var reached_plateau := false
	for frame in range(180):
		app._physics_process(STEP)
		climbed = climbed or (app.session.position.y < 575 and app.session.elevation > 0.35)
		reached_plateau = reached_plateau or (app.session.position.y < 440 and app.session.elevation > 0.69)
		if frame % 20 == 0:
			await tree.physics_frame
		if app.session.state != Session.State.MOVING:
			break
	check.call("3D: esfera sobe a rampa com ganho real de altura", climbed)
	check.call("3D: esfera alcança e permanece sobre o patamar de 60 cm", reached_plateau and app.session.state == Session.State.READY and absf(app.session.elevation - 0.74) < 0.05)
	var elevated_start: Vector2 = app.session.position
	await _touch_game(app, elevated_start, 0, true)
	await _drag_game(app, elevated_start + Vector2(96, 0), 0)
	check.call("3D: toque no patamar elevado usa o plano de altura da esfera", app.session.state == Session.State.AIMING and absf(app.session.power() - 0.5) < 0.002)
	await _touch_game(app, elevated_start + Vector2(96, 0), 0, false)
	check.call("3D: soltura de toque elevado lança uma única tacada", app.session.state == Session.State.MOVING and app.session.current_strokes == 2)

	# The launch ramp crosses an actual missing-floor pit, then lands on turf.
	var jump_start := Vector2(580, 780)
	await _fixture(app, 2, jump_start, -1.0, Vector2(0, -800))
	var airborne_above_pit := false
	var landed_beyond_pit := false
	var survived_pit := true
	var maximum_height: float = app.session.elevation
	for frame in range(180):
		app._physics_process(STEP)
		maximum_height = maxf(maximum_height, app.session.elevation)
		var in_pit: bool = Rect2(520, 460, 136, 180).has_point(app.session.position)
		airborne_above_pit = airborne_above_pit or (in_pit and not app.session.motion_adapter.grounded and app.session.elevation > 0.18)
		landed_beyond_pit = landed_beyond_pit or (app.session.position.y < 460 and app.session.motion_adapter.grounded and app.session.elevation < 0.2)
		survived_pit = survived_pit and app.session.state != Session.State.RETURNING
		if frame % 20 == 0:
			await tree.physics_frame
		if app.session.state != Session.State.MOVING:
			break
	check.call("3D: rampa de salto lança a esfera sobre o vão", airborne_above_pit and maximum_height > 0.4)
	check.call("3D: salto aterrissa no piso além do vão sem retorno indevido", landed_beyond_pit and survived_pit)

	# Being above the hole cannot score until the sphere lands at its elevation.
	await _fixture(app, 0, Vector2(360, 260), 1.4, Vector2.ZERO)
	app._physics_process(STEP)
	check.call("3D: passar por cima do buraco no ar não registra ponto", app.session.state == Session.State.MOVING and app.session.results.is_empty() and app.session.elevation > 1.0)
	var frozen_air_body: Vector3 = app.world.ball.position
	var frozen_vertical_speed: float = app.session.vertical_velocity
	app.set_application_pause("focus", true)
	for frame in range(30):
		app._physics_process(STEP)
	check.call("3D: pausa no ar congela altura e gravidade do corpo real", app.world.ball.position.is_equal_approx(frozen_air_body) and app.session.vertical_velocity == frozen_vertical_speed)
	app.set_application_pause("focus", false)
	app._physics_process(STEP)
	check.call("3D: retomar no ar continua a queda sem captura antecipada", app.session.state == Session.State.MOVING and app.session.elevation < frozen_air_body.y and app.session.current_strokes == 1)
	for frame in range(90):
		app._physics_process(STEP)
		if frame % 20 == 0:
			await tree.physics_frame
		if app.session.state == Session.State.CAPTURED:
			break
	check.call("3D: aterrissar devagar no buraco registra uma tacada", app.session.state == Session.State.CAPTURED and app.session.results == [1] and app.session.current_strokes == 0)

	# The hazard triggers on falling into the pit, with a safe position restored.
	await _fixture(app, 2, Vector2(580, 560), 1.2, Vector2.ZERO)
	var return_start := Vector2(580, 710)
	app.session.previous_position = return_start
	app.session.previous_elevation = app.world.terrain_height(return_start) + RADIUS_METERS
	app._physics_process(STEP)
	check.call("3D: estar acima do vão não aciona retorno imediato", app.session.state == Session.State.MOVING and app.session.elevation > 1.0)
	var fell_into_pit := false
	for frame in range(150):
		app._physics_process(STEP)
		fell_into_pit = fell_into_pit or app.session.state == Session.State.RETURNING
		if frame % 20 == 0:
			await tree.physics_frame
		if fell_into_pit and app.session.state == Session.State.READY:
			break
	check.call("3D: cair no vão dispara retorno e conserva a tacada", fell_into_pit and app.session.state == Session.State.READY and app.session.current_strokes == 1)
	check.call("3D: retorno restaura posição e altura segura da rampa", app.session.position.distance_to(return_start) < 0.1 and absf(app.session.elevation - (app.world.terrain_height(return_start) + RADIUS_METERS)) < 0.04)

	# The elevated launch lip shares the pit's inclusive map boundary, but its
	# native support makes it a safe previous position instead of a water tile.
	await _fixture(app, 2, Vector2(580, 560), 1.2, Vector2.ZERO)
	var lip_start := Vector2(580, 640)
	var lip_height: float = app.world.support_height(lip_start)
	app.session.previous_position = lip_start
	app.session.previous_elevation = lip_height
	var returned_to_lip := false
	for frame in range(150):
		app._physics_process(STEP)
		returned_to_lip = returned_to_lip or app.session.state == Session.State.RETURNING
		if frame % 20 == 0:
			await tree.physics_frame
		if returned_to_lip and app.session.state == Session.State.READY:
			break
	check.call("3D: retorno aceita borda elevada da rampa junto ao vão", returned_to_lip and app.session.state == Session.State.READY and app.session.position.distance_to(lip_start) < 0.1 and absf(app.session.elevation - lip_height) < 0.025 and app.session.current_strokes == 1)

	# Pause freezes the physical body too, and preserves the launch velocity.
	await _fixture(app, 0, Vector2(360, 990), RADIUS_METERS, Vector2(0, -500))
	for frame in range(12):
		app._physics_process(STEP)
	var frozen_body: Vector3 = app.world.ball.position
	var frozen_velocity: Vector2 = app.session.velocity
	app.set_application_pause("focus", true)
	for frame in range(60):
		app._physics_process(STEP)
	check.call("3D: pausa congela corpo nativo e sua velocidade", app.world.ball.position.is_equal_approx(frozen_body) and app.session.velocity == frozen_velocity)
	app.set_application_pause("focus", false)
	app._physics_process(STEP)
	check.call("3D: retomar move o corpo sem criar tacada adicional", not app.world.ball.position.is_equal_approx(frozen_body) and app.session.current_strokes == 1 and app.session.velocity.length() <= frozen_velocity.length())

	# This final flow uses real viewport events for every stroke and menu action.
	app._action("home")
	await _ui_click(app, Vector2(360, 908))
	await tree.physics_frame
	var input_start: Vector2 = app.session.position
	await _mouse_game(app, input_start, true)
	await _motion_game(app, input_start + Vector2(0, 96))
	check.call("3D: mouse projetado na câmera prepara 50% de potência", app.session.state == Session.State.AIMING and absf(app.session.power() - 0.5) < 0.002)
	app.set_application_pause("focus", true)
	app.set_application_pause("focus", false)
	await _mouse_game(app, input_start + Vector2(0, 96), false)
	check.call("3D: perda de foco cancela a mira com projeção 3D", app.session.state == Session.State.READY and app.session.current_strokes == 0)

	var first_complete: bool = await reach_target(app, Vector2(360, 260), true)
	check.call("3D: eventos de mouse concluem o primeiro percurso", first_complete and app.session.results.size() == 1)
	await finish_capture(app)
	var second_complete := false
	if first_complete:
		var second_route := [Vector2(550, 990), Vector2(550, 350), Vector2(260, 350)]
		var route_ok := true
		for target in second_route:
			route_ok = await reach_target(app, target, false) and route_ok
			if not route_ok:
				break
		if route_ok:
			second_complete = await reach_target(app, Vector2(260, 280), true)
	check.call("3D: mouse conclui percurso com rampa e patamar elevados", second_complete and app.session.results.size() == 2)
	await finish_capture(app)
	var third_complete := false
	if second_complete:
		var third_route := [Vector2(160, 850), Vector2(160, 500), Vector2(360, 500)]
		var route_ok := true
		for target in third_route:
			route_ok = await reach_target(app, target, false) and route_ok
			if not route_ok:
				break
		if route_ok:
			third_complete = await reach_target(app, Vector2(360, 280), true)
	check.call("3D: mouse conclui percurso contornando obstáculos e vão", third_complete and app.session.results.size() == 3)
	await finish_capture(app)
	check.call("3D: fluxo nativo completo chega ao resultado com três buracos", app.session.state == Session.State.RESULT and app.session.results.size() == 3 and app.session.total() > 0)
	var reloaded = Records.new(path)
	check.call("3D: resultado real salva recorde relido do arquivo", app.session.state == Session.State.RESULT and reloaded.persisted_best == app.session.total() and FileAccess.file_exists(path))
	if app.session.state == Session.State.RESULT:
		print("Sessão nativa 3D concluída: ", app.session.results, "; total ", app.session.total(), ".")
	app.queue_free()
	await tree.process_frame
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	completed = true


func play_full_session(app) -> bool:
	var routes := [
		[Vector2(360, 260)],
		[Vector2(550, 990), Vector2(550, 350), Vector2(260, 350), Vector2(260, 280)],
		[Vector2(160, 850), Vector2(160, 500), Vector2(360, 500), Vector2(360, 280)],
	]
	for route in routes:
		for index in range(route.size()):
			if not await reach_target(app, route[index], index == route.size() - 1):
				return false
		await finish_capture(app)
	return app.session.state == Session.State.RESULT and app.session.results.size() == 3


func _fixture(app, course: int, point: Vector2, height: float, velocity: Vector2) -> void:
	app.session.pause_reasons.clear()
	app.session.start_session()
	app.session.course_index = course
	app.session.position = point
	app.session.previous_position = point
	app.session.elevation = height
	app.session.previous_elevation = height
	app.session.vertical_velocity = 0.0
	app.session.velocity = Vector2.ZERO
	app.session.state = Session.State.READY
	app._physics_process(0.0)
	await (Engine.get_main_loop() as SceneTree).physics_frame
	if height < 0.0:
		height = app.world.terrain_height(point) + RADIUS_METERS
	app.session.position = point
	app.session.elevation = height
	app.session.current_strokes = 1
	app.session.velocity = velocity
	app.session.state = Session.State.MOVING
	app.session.resting_time = 0.0
	app.session.motion_adapter.reset(app.session)


func _has_sphere_shape(body: Node) -> bool:
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is SphereShape3D:
			return true
	return false


func reach_target(app, target: Vector2, final_hole: bool = false) -> bool:
	for attempt in range(6):
		if app.session.state == Session.State.CAPTURED:
			return final_hole
		if app.session.state != Session.State.READY:
			print("Rota 3D: estado inesperado ", app.session.state, " rumo a ", target)
			return false
		var start: Vector2 = app.session.position
		var distance := start.distance_to(target)
		if not final_hole and distance < 25.0:
			return true
		var height_gain: float = maxf(app.world.terrain_height(target) - app.world.terrain_height(start), 0.0)
		var launch_speed := minf(sqrt(2.0 * Config.DECELERATION * distance + 196000.0 * height_gain), Config.MAX_SPEED)
		var drag := Config.DEAD_ZONE + (Config.MAX_DRAG - Config.DEAD_ZONE) * launch_speed / Config.MAX_SPEED
		var release := start - start.direction_to(target) * drag
		await _mouse_game(app, start, true)
		await _motion_game(app, release)
		await _mouse_game(app, release, false)
		if app.session.state != Session.State.MOVING:
			print("Rota 3D: entrada não lançou esfera em ", start, "; alvo ", target, "; estado ", app.session.state)
			return false
		for frame in range(360):
			app._physics_process(STEP)
			if frame % 20 == 0:
				await (Engine.get_main_loop() as SceneTree).physics_frame
			if app.session.state != Session.State.MOVING:
				break
	if final_hole and app.session.state == Session.State.CAPTURED:
		return true
	if not final_hole and app.session.position.distance_to(target) < 25.0:
		return true
	print("Rota 3D não alcançou ", target, "; esfera ", app.session.position, "; altura ", app.session.elevation, "; estado ", app.session.state)
	return false


func finish_capture(app) -> void:
	for frame in range(60):
		if app.session.state != Session.State.CAPTURED:
			break
		app._physics_process(STEP)
	await (Engine.get_main_loop() as SceneTree).physics_frame


func _ui_click(app, point: Vector2) -> void:
	await _mouse_screen(app.to_screen(point), true)
	await _mouse_screen(app.to_screen(point), false)


func _mouse_game(app, point: Vector2, pressed: bool) -> void:
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


func _motion_game(app, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = app.game_to_screen(point)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _touch_game(app, point: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = app.game_to_screen(point)
	event.index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame


func _drag_game(app, point: Vector2, index: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = app.game_to_screen(point)
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await (Engine.get_main_loop() as SceneTree).process_frame

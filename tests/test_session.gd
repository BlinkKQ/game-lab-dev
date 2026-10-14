extends RefCounted

const Session = preload("res://scripts/golf_session.gd")
const STEP := 1.0 / 60.0


func run(check: Callable) -> void:
	_test_input(check)
	_test_free_motion(check)
	_test_collisions(check)
	_test_capture_and_totals(check)
	_test_pauses(check)
	_test_recovery(check)
	_test_complete_routes(check)


func _new_session():
	var session = Session.new()
	session.start_session()
	return session


func _test_input(check: Callable) -> void:
	var session = Session.new()
	check.call("AC-01 estado inicial é menu", session.state == Session.State.MENU)
	check.call("Menu não permite preparar tacada", not session.begin_aim(Vector2.ZERO, 0))
	session.start_session()
	check.call("AC-01 primeira sessão inicia mapa 01 e pontuação zero", session.state == Session.State.READY and session.course_index == 0 and session.current_strokes == 0 and session.results.is_empty() and session.total() == 0)
	var origin: Vector2 = session.position
	check.call("AC-26 toque a 72 unidades é aceito", session.begin_aim(origin + Vector2(72, 0), 7))
	session.cancel_aim()
	check.call("Toque além de 72 unidades é ignorado", not session.begin_aim(origin + Vector2(72.01, 0), 7))
	check.call("AC-02 toque na bola começa mira", session.begin_aim(origin, 7))
	for drag in [0.0, 12.0, 54.0, 96.0, 138.0, 180.0, 250.0]:
		session.drag_aim(origin + Vector2(0, drag), 7)
		var expected_power := clampf((drag - 12.0) / 168.0, 0.0, 1.0)
		check.call("AC-02/05/26 potência para arraste %.0f" % drag, is_equal_approx(session.power(), expected_power))
		check.call("Bola permanece parada durante mira %.0f" % drag, session.position == origin and session.velocity == Vector2.ZERO)
	session.drag_aim(origin + Vector2(0, 96), 7)
	check.call("Direção aponta contra o arraste", session.aim_direction().is_equal_approx(Vector2.UP))
	check.call("AC-06 segundo dedo não inicia outra mira", not session.begin_aim(origin, 8))
	session.drag_aim(origin + Vector2(180, 0), 8)
	check.call("AC-06 segundo dedo não move a mira", is_equal_approx(session.power(), 0.5) and session.aim_direction().is_equal_approx(Vector2.UP))
	check.call("AC-06 soltura do segundo dedo não lança", not session.release_aim(origin + Vector2(180, 0), 8) and session.state == Session.State.AIMING and session.current_strokes == 0)
	session.cancel_aim()
	session.begin_aim(origin, 7)
	check.call("AC-03/26 soltura em 12 cancela sem tacada", not session.release_aim(origin + Vector2(0, 12), 7) and session.state == Session.State.READY and session.current_strokes == 0 and session.velocity == Vector2.ZERO)
	session.begin_aim(origin, 7)
	check.call("AC-04 lançamento válido aceito", session.release_aim(origin + Vector2(0, 96), 7))
	check.call("AC-04 meia potência conta uma tacada e aplica velocidade 500", session.state == Session.State.MOVING and session.current_strokes == 1 and session.velocity.is_equal_approx(Vector2(0, -500)) and session.previous_position == origin)
	check.call("AC-06 movimento bloqueia novo toque", not session.begin_aim(session.position, 8))
	check.call("AC-04/27 soltura duplicada não aplica segundo impulso", not session.release_aim(origin + Vector2(0, 180), 7) and session.current_strokes == 1 and session.velocity.is_equal_approx(Vector2(0, -500)))
	session.start_session()
	for drag in [180.0, 300.0]:
		session.begin_aim(session.position, 1)
		var start: Vector2 = session.position
		session.release_aim(start + Vector2(drag, 0), 1)
		check.call("AC-05 velocidade limitada a 1000 para arraste %.0f" % drag, session.velocity.is_equal_approx(Vector2.LEFT * 1000.0))
		session.start_session()


func _test_free_motion(check: Callable) -> void:
	var distances: Array[float] = []
	for power in [0.25, 0.5, 0.75]:
		var session = _new_session()
		session.position = Vector2(360, 1020)
		var start: Vector2 = session.position
		var drag: float = 12.0 + 168.0 * power
		session.begin_aim(start, 1)
		session.release_aim(start + Vector2(0, drag), 1)
		check.call("AC-07 velocidade inicial a %.0f%%" % (power * 100), is_equal_approx(session.velocity.length(), 1000.0 * power))
		_advance_until_stable(session)
		var distance := start.distance_to(session.position)
		distances.append(distance)
		var nominal: float = pow(1000.0 * power, 2.0) / 1000.0
		check.call("AC-07 distância física a %.0f%% próxima da previsão contínua" % (power * 100), absf(distance - nominal) < 1.0)
		check.call("AC-09 repouso elimina velocidade residual", session.state == Session.State.READY and session.velocity == Vector2.ZERO)
	check.call("AC-07 distâncias de parada crescem com potência", distances[0] < distances[1] and distances[1] < distances[2])
	var resting = _new_session()
	resting.state = Session.State.MOVING
	resting.velocity = Vector2(11, 0)
	resting.update(0.06)
	check.call("AC-09 repouso não é confirmado antes de 0,12 s", resting.state == Session.State.MOVING)
	resting.update(0.059)
	check.call("AC-09 bola continua bloqueada em 0,119 s", resting.state == Session.State.MOVING)
	resting.update(0.002)
	check.call("AC-09 bola pronta após confirmação de 0,12 s", resting.state == Session.State.READY and resting.velocity == Vector2.ZERO)
	resting = _new_session()
	resting.state = Session.State.MOVING
	resting.velocity = Vector2(11, 0)
	resting.update(0.06)
	resting.velocity = Vector2(13, 0)
	resting.update(0.0001)
	check.call("Velocidade acima do limiar reinicia confirmação de repouso", is_zero_approx(resting.resting_time))
	resting.velocity = Vector2(11, 0)
	resting.update(0.06)
	check.call("Confirmação de repouso reiniciada precisa novamente de 0,12 s", resting.state == Session.State.MOVING)


func _test_collisions(check: Callable) -> void:
	var reflected: Vector2 = Session.reflected_velocity(Vector2(800, -600), Vector2.LEFT)
	check.call("AC-29 rebote reflete normal com coeficiente 0,78", is_equal_approx(reflected.x, -624.0))
	check.call("AC-29 rebote conserva componente tangencial", is_equal_approx(reflected.y, -600.0))
	var session = _new_session()
	session.position = Vector2(641, 800)
	session.state = Session.State.MOVING
	session.velocity = Vector2(800, -600)
	session.update(STEP)
	check.call("AC-08/29 impacto oblíquo na parede não atravessa limite", session.position.x <= 642.001 and session.position.x >= 78.0 and session.velocity.x < 0.0)
	check.call("AC-29 integração conserva razão entre normal refletida e tangente", absf(absf(session.velocity.x / session.velocity.y) - 1.04) < 0.0001)
	check.call("Desaceleração permanece ativa após rebote", session.velocity.length() < reflected.length())
	var corner = _new_session()
	corner.position = Vector2(641, 215)
	corner.state = Session.State.MOVING
	corner.velocity = Vector2(1, -1).normalized() * 1000.0
	corner.update(STEP)
	check.call("AC-29 canto externo resolve ambas as componentes", corner.velocity.x < 0.0 and corner.velocity.y > 0.0 and corner.position.x <= 642.001 and corner.position.y >= 213.999)
	var internal = _new_session()
	internal.course_index = 1
	internal.position = Vector2(300, 610)
	internal.state = Session.State.MOVING
	internal.velocity = Vector2(0, -1000)
	internal.update(0.2)
	check.call("AC-08 parede interna não é atravessada em passo longo na potência máxima", internal.position.y >= 591.999 and internal.velocity.y > 0.0)
	var rounded_corner = _new_session()
	rounded_corner.course_index = 1
	rounded_corner.position = Vector2(444, 592)
	rounded_corner.state = Session.State.MOVING
	rounded_corner.velocity = Vector2(-1, -1).normalized() * 1000.0
	var sweep: Dictionary = rounded_corner._sweep_walls(rounded_corner.position, rounded_corner.velocity.normalized(), 20.0)
	check.call("AC-29 canto interno usa contato circular exato", absf(float(sweep["distance"]) - (sqrt(392.0) - 14.0)) < 0.001)
	rounded_corner.update(STEP)
	check.call("AC-29 canto interno rebate sem penetrar retângulo", rounded_corner.velocity.x > 0.0 and rounded_corner.velocity.y > 0.0 and rounded_corner.position.distance_to(Vector2(430, 578)) >= 13.999)
	var horizontal = _new_session()
	horizontal.position = Vector2(360, 800)
	horizontal.state = Session.State.MOVING
	horizontal.velocity = Vector2(1000, 0)
	var contained := true
	for index in range(180):
		horizontal.update(STEP)
		contained = contained and horizontal.position.x >= 77.999 and horizontal.position.x <= 642.001
	check.call("AC-08 sucessivos rebotes na potência máxima ficam dentro do campo", contained and horizontal.state == Session.State.READY)


func _test_capture_and_totals(check: Callable) -> void:
	for boundary in [[22.0, 150.0, true], [23.0, 150.0, false], [22.0, 151.0, false]]:
		var session = _new_session()
		session.state = Session.State.MOVING
		session.current_strokes = 1
		session.position = session.current_course()["hole"] + Vector2(float(boundary[0]), 0)
		session.velocity = Vector2(0, float(boundary[1]))
		session.update(0.0)
		check.call("AC-10/11/26 captura em distância %.0f e velocidade %.0f" % [boundary[0], boundary[1]], (session.state == Session.State.CAPTURED) == bool(boundary[2]))
	var fast_pass = _new_session()
	fast_pass.state = Session.State.MOVING
	fast_pass.current_strokes = 1
	var hole: Vector2 = fast_pass.current_course()["hole"]
	fast_pass.position = hole + Vector2(0, 30)
	fast_pass.velocity = Vector2(0, -500)
	fast_pass.update(0.1)
	check.call("AC-10 passagem real acima de 150 não captura buraco", fast_pass.state == Session.State.MOVING and fast_pass.results.is_empty() and fast_pass.position.y < hole.y)
	var stopping_on_hole = _new_session()
	stopping_on_hole.state = Session.State.MOVING
	stopping_on_hole.current_strokes = 2
	stopping_on_hole.position = stopping_on_hole.current_course()["hole"] + Vector2(0, 20)
	stopping_on_hole.velocity = Vector2.ZERO
	stopping_on_hole.resting_time = 0.119
	stopping_on_hole.update(STEP)
	check.call("AC-09/11 captura tem prioridade sobre liberar bola no mesmo passo", stopping_on_hole.state == Session.State.CAPTURED and stopping_on_hole.results == [2])
	var scoring = _new_session()
	var expected_totals := [3, 7, 12]
	var strokes := [3, 4, 5]
	for index in range(3):
		_force_capture(scoring, strokes[index])
		check.call("AC-23 captura atômica do mapa %d" % (index + 1), scoring.state == Session.State.CAPTURED and scoring.current_strokes == 0 and scoring.captured_strokes == strokes[index] and scoring.results.size() == index + 1 and scoring.total() == expected_totals[index])
		check.call("AC-11 captura bloqueia novos lançamentos", not scoring.begin_aim(scoring.position, 99))
		check.call("Menu indisponível durante feedback", not scoring.request_menu())
		scoring.update(0.0)
		scoring.update(0.0)
		check.call("AC-11/23 eventos repetidos não duplicam resultado", scoring.results.size() == index + 1 and scoring.total() == expected_totals[index])
		var remaining: float = scoring.remaining
		scoring.update(remaining * 0.5)
		check.call("Feedback mantém total sem duplicação", scoring.state == Session.State.CAPTURED and scoring.total() == expected_totals[index])
		scoring.update(scoring.remaining + 0.001)
		if index < 2:
			check.call("AC-13 avanço ordenado e contador zero", scoring.state == Session.State.READY and scoring.course_index == index + 1 and scoring.current_strokes == 0 and scoring.position == scoring.current_course()["start"])
		else:
			check.call("AC-13/14 resultado somente após terceiro mapa, total 12", scoring.state == Session.State.RESULT and scoring.total() == 12 and scoring.results == [3, 4, 5])
	var old_results: Array = scoring.results.duplicate()
	scoring.update(10.0)
	check.call("Resultado não registra novamente a sessão", scoring.results == old_results and scoring.state == Session.State.RESULT)
	scoring.start_session()
	check.call("AC-15 repetir reinicia pontuação, estados e percurso", scoring.state == Session.State.READY and scoring.course_index == 0 and scoring.current_strokes == 0 and scoring.results.is_empty() and scoring.total() == 0 and scoring.velocity == Vector2.ZERO)


func _test_pauses(check: Callable) -> void:
	var aiming = _new_session()
	var origin: Vector2 = aiming.position
	aiming.begin_aim(origin, 42)
	aiming.drag_aim(origin + Vector2(0, 180), 42)
	aiming.set_paused("app", true)
	check.call("AC-19 suspensão cancela mira e mantém bola pronta", aiming.state == Session.State.READY and aiming.is_paused() and aiming.current_strokes == 0 and aiming.velocity == Vector2.ZERO)
	aiming.set_paused("app", false)
	check.call("AC-19/27 soltura tardia após retomar não lança", not aiming.release_aim(origin + Vector2(0, 180), 42) and aiming.current_strokes == 0)
	var moving = _new_session()
	moving.begin_aim(moving.position, 1)
	moving.release_aim(moving.position + Vector2(0, 96), 1)
	var position_before: Vector2 = moving.position
	var velocity_before: Vector2 = moving.velocity
	check.call("AC-21 menu disponível durante movimento", moving.request_menu())
	moving.set_paused("app", true)
	moving.update(2.0)
	check.call("AC-25 pausas sobrepostas congelam posição e velocidade", moving.position == position_before and moving.velocity == velocity_before and moving.state == Session.State.MOVING)
	moving.continue_session()
	check.call("AC-25 continuar remove apenas pausa da confirmação", moving.is_paused())
	moving.update(2.0)
	check.call("AC-25 aplicativo inativo ainda impede física", moving.position == position_before and moving.velocity == velocity_before)
	moving.set_paused("app", false)
	moving.update(STEP)
	check.call("AC-25 remoção da última causa retoma uma vez", not moving.is_paused() and moving.position != position_before and moving.velocity.length() < velocity_before.length() and moving.current_strokes == 1)
	var modal_aim = _new_session()
	modal_aim.begin_aim(modal_aim.position, 1)
	modal_aim.drag_aim(modal_aim.position + Vector2(0, 180), 1)
	check.call("AC-21/27 menu cancela mira e abre confirmação", modal_aim.request_menu() and modal_aim.state == Session.State.READY and modal_aim.is_paused())
	modal_aim.continue_session()
	check.call("AC-21 continuar conserva sessão sem restaurar gesto", modal_aim.state == Session.State.READY and not modal_aim.is_paused() and not modal_aim.release_aim(modal_aim.position + Vector2(0, 180), 1) and modal_aim.total() == 0)
	var resting = _new_session()
	resting.state = Session.State.MOVING
	resting.velocity = Vector2(11, 0)
	resting.update(0.04)
	var rest_before: float = resting.resting_time
	resting.set_paused("app", true)
	resting.update(2.0)
	check.call("AC-25 pausa congela confirmação de repouso", is_equal_approx(resting.resting_time, rest_before) and resting.state == Session.State.MOVING)
	resting.set_paused("app", false)
	resting.update(0.081)
	check.call("AC-25 confirmação de repouso continua do tempo preservado", resting.state == Session.State.READY)
	var captured = _new_session()
	_force_capture(captured, 3)
	var captured_remaining: float = captured.remaining
	captured.set_paused("app", true)
	captured.update(2.0)
	check.call("AC-25 pausa congela feedback de captura sem duplicar total", captured.state == Session.State.CAPTURED and is_equal_approx(captured.remaining, captured_remaining) and captured.results == [3] and captured.total() == 3)
	captured.set_paused("app", false)
	captured.update(captured_remaining + 0.001)
	check.call("AC-25 captura retomada avança uma vez", captured.course_index == 1 and captured.state == Session.State.READY and captured.results == [3] and captured.total() == 3)
	var returning = _new_session()
	returning.state = Session.State.MOVING
	returning.position = Vector2(0, 0)
	returning.update(0.0)
	var returning_remaining: float = returning.remaining
	returning.set_paused("app", true)
	returning.update(2.0)
	check.call("AC-25 pausa congela temporizador de reposicionamento", returning.state == Session.State.RETURNING and is_equal_approx(returning.remaining, returning_remaining))
	returning.set_paused("app", false)
	returning.update(returning_remaining + 0.001)
	check.call("AC-25 retorno retomado libera bola uma única vez", returning.state == Session.State.READY and returning.position == returning.current_course()["start"])
	var abandoned = _new_session()
	abandoned.current_strokes = 4
	abandoned.results.append(3)
	abandoned.request_menu()
	abandoned.abandon_session()
	check.call("AC-15/21 abandono descarta sessão parcial", abandoned.state == Session.State.MENU and abandoned.results.is_empty() and abandoned.current_strokes == 0 and abandoned.total() == 0 and abandoned.velocity == Vector2.ZERO)
	abandoned.start_session()
	check.call("AC-15 partida após abandono inicia limpa", abandoned.state == Session.State.READY and abandoned.course_index == 0 and abandoned.total() == 0 and not abandoned.is_paused())


func _test_recovery(check: Callable) -> void:
	var hazard = _new_session()
	hazard.course_index = 2
	hazard.position = Vector2(550, 500)
	hazard.previous_position = Vector2(170, 780)
	hazard.current_strokes = 2
	hazard.state = Session.State.MOVING
	hazard.velocity = Vector2(500, 0)
	hazard.update(0.0)
	check.call("AC-12 área fora de jogo inicia reposicionamento", hazard.state == Session.State.RETURNING and hazard.current_strokes == 2 and hazard.results.is_empty())
	check.call("Reposicionamento bloqueia menu e nova tacada", not hazard.request_menu() and not hazard.begin_aim(hazard.position, 1))
	hazard.update(hazard.remaining + 0.001)
	check.call("AC-12 retorno à posição anterior sem penalidade", hazard.state == Session.State.READY and hazard.position == Vector2(170, 780) and hazard.velocity == Vector2.ZERO and hazard.current_strokes == 2)
	for invalid in [Vector2(0, 0), Vector2(360, 660), Vector2(550, 500), Vector2(70, 900)]:
		var fallback = _new_session()
		fallback.course_index = 2
		fallback.position = Vector2(550, 500)
		fallback.previous_position = invalid
		fallback.current_strokes = 4
		fallback.state = Session.State.MOVING
		fallback.update(0.0)
		fallback.update(fallback.remaining + 0.001)
		check.call("AC-30 posição anterior inválida %s usa início do mapa" % invalid, fallback.state == Session.State.READY and fallback.position == fallback.current_course()["start"] and fallback.current_strokes == 4 and fallback.velocity == Vector2.ZERO)
	var escaped = _new_session()
	escaped.position = Vector2(60, 900)
	escaped.previous_position = Vector2(360, 900)
	escaped.current_strokes = 1
	escaped.state = Session.State.MOVING
	escaped.update(0.0)
	check.call("AC-30 escape dos limites inicia recuperação", escaped.state == Session.State.RETURNING)
	escaped.update(escaped.remaining + 0.001)
	check.call("AC-30 escape restaura posição válida e conserva tacada", escaped.state == Session.State.READY and escaped.position == Vector2(360, 900) and escaped.current_strokes == 1)


func _test_complete_routes(check: Callable) -> void:
	# All seven shots use actual input and model updates at 60 Hz. No ball
	# position or score is injected here; analytic stopping distance only
	# supplies a reproducible drag for the documented reference routes.
	var session = _new_session()
	var routes := [
		[Vector2(360, 260)],
		[Vector2(540, 760), Vector2(540, 440), Vector2(260, 280)],
		[Vector2(170, 780), Vector2(170, 460), Vector2(360, 280)],
	]
	for course_index in range(routes.size()):
		check.call("Rota jogada abre mapa %d na ordem" % (course_index + 1), session.course_index == course_index and session.state == Session.State.READY)
		for target_index in range(routes[course_index].size()):
			var target: Vector2 = routes[course_index][target_index]
			var displacement: Vector2 = target - session.position
			var speed := sqrt(2.0 * 500.0 * displacement.length())
			var drag: Vector2 = -displacement.normalized() * (12.0 + 168.0 * speed / 1000.0)
			var launched: bool = session.begin_aim(session.position, 0)
			launched = session.release_aim(session.position + drag, 0) and launched
			check.call("Rota mapa %d segmento %d lança pelo controle real" % [course_index + 1, target_index + 1], launched)
			_advance_until_stable(session)
			if target_index + 1 < routes[course_index].size():
				check.call("Rota mapa %d segmento %d chega livre ao ponto intermediário" % [course_index + 1, target_index + 1], session.state == Session.State.READY and session.position.distance_to(target) < 1.0)
			else:
				check.call("AC-13 rota física captura mapa %d" % (course_index + 1), session.state == Session.State.CAPTURED and session.results.size() == course_index + 1)
		if session.state == Session.State.CAPTURED:
			session.update(session.remaining + 0.001)
	check.call("AC-13 sessão completa pelas sete tacadas das rotas", session.state == Session.State.RESULT and session.results == [1, 3, 3] and session.total() == 7 and session.current_strokes == 0)


func _advance_until_stable(session) -> void:
	for frame in range(1200):
		if session.state != Session.State.MOVING:
			return
		session.update(STEP)


func _force_capture(session, strokes: int) -> void:
	# Isolate atomic bookkeeping and timer boundaries; route tests separately
	# validate capture as the outcome of complete, physically simulated shots.
	session.state = Session.State.MOVING
	session.position = session.current_course()["hole"]
	session.velocity = Vector2.ZERO
	session.current_strokes = strokes
	session.update(0.0)

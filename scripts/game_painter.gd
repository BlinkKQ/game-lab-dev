class_name GamePainter
extends RefCounted

## Original vector artwork. All positions use the project's 720 × 1280 space.

const Session = preload("res://scripts/golf_session.gd")
const BG = Color("#101827")
const FIELD = Color("#183e35")
const WHITE = Color("#f3f6fa")
const CYAN = Color("#50d9d0")
const AMBER = Color("#f7a546")
const YELLOW = Color("#efd26b")
const MUTED = Color("#a7b9c5")
const PANEL = Color("#1b293a")
const EDGE = Color("#395f56")

var _canvas: Node2D
var _font: Font


func paint(canvas: Node2D, session, store, buttons: Array[Dictionary], time: float) -> void:
	_canvas = canvas
	if _font == null:
		_font = ThemeDB.fallback_font
	_background()
	match session.state:
		Session.State.MENU:
			_menu(store, time)
		Session.State.RESULT:
			_result(session, store)
		_:
			_game(session, time)
	var modal: bool = session.pause_reasons.has("modal")
	if modal:
		_modal()
	for button in buttons:
		var is_modal_button: bool = str(button.id) in ["continue", "abandon"]
		if modal and not is_modal_button:
			continue
		_button(button)


func _background() -> void:
	_canvas.draw_rect(Rect2(0, 0, 720, 1280), BG)
	_canvas.draw_circle(Vector2(702, 86), 230, _alpha(CYAN, 0.022))
	_canvas.draw_circle(Vector2(18, 1175), 240, _alpha(CYAN, 0.02))
	_canvas.draw_line(Vector2(36, 44), Vector2(36, 1236), _alpha(WHITE, 0.035), 1)
	_canvas.draw_line(Vector2(684, 44), Vector2(684, 1236), _alpha(WHITE, 0.035), 1)


func _menu(store, time: float) -> void:
	_text("UM JOGO DE PRECISÃO", Vector2(100, 112), 18, CYAN)
	_text("GameLab", Vector2(96, 191), 64, WHITE)
	_text("Minigolfe", Vector2(96, 269), 74, WHITE)
	_canvas.draw_line(Vector2(100, 304), Vector2(174, 304), CYAN, 4, true)
	_menu_course(time)
	_center("Três percursos. Um bom toque.", 757, 26, WHITE)
	_center("Toque perto da bola, puxe e solte para lançar.", 802, 22, MUTED)
	_center("Puxe mais para aumentar a força.", 833, 21, MUTED)
	_records(store, 976, 32, 20)
	_center("Volte ao início do toque para cancelar.", 1121, 18, MUTED)
	_center("PUXE  ·  MIRE  ·  SOLTE", 1206, 16, _alpha(WHITE, 0.48))


func _menu_course(time: float) -> void:
	_panel(Rect2(82, 348, 556, 342), Color("#0b121e"), Color("#243747"), 26, 2)
	_panel(Rect2(96, 362, 528, 314), FIELD, EDGE, 17, 2)
	for x in range(127, 624, 48):
		_canvas.draw_line(Vector2(x, 379), Vector2(x, 659), _alpha(WHITE, 0.025), 1)
	for y in range(391, 672, 48):
		_canvas.draw_line(Vector2(112, y), Vector2(608, y), _alpha(WHITE, 0.025), 1)
	_panel(Rect2(304, 469, 30, 162), Color("#42635b"), Color("#68887e"), 4, 2)
	_canvas.draw_line(Vector2(310, 475), Vector2(310, 625), _alpha(WHITE, 0.18), 2)
	_dashed(Vector2(169, 608), Vector2(245, 423), _alpha(CYAN, 0.6), 2, 9, 8)
	_dashed(Vector2(245, 423), Vector2(530, 423), _alpha(CYAN, 0.6), 2, 9, 8)
	_canvas.draw_circle(Vector2(245, 423), 5, CYAN)
	_hole(Vector2(534, 423), time)
	_ball(Vector2(169, 608), 16)
	_canvas.draw_arc(Vector2(169, 608), 34, 0, TAU, 48, _alpha(CYAN, 0.2), 2, true)
	_text("01", Vector2(121, 399), 16, _alpha(WHITE, 0.38))
	_text("TRÊS PERCURSOS", Vector2(391, 648), 15, _alpha(WHITE, 0.58))


func _game(session, time: float) -> void:
	var course: Dictionary = session.current_course()
	_text("PERCURSO %02d / 03" % (session.course_index + 1), Vector2(64, 67), 17, CYAN)
	_text(str(course.name), Vector2(64, 114), 31, WHITE)
	_panel(Rect2(64, 135, 280, 45), PANEL, Color.TRANSPARENT, 9, 0)
	_panel(Rect2(360, 135, 296, 45), PANEL, Color.TRANSPARENT, 9, 0)
	_text("TACADAS", Vector2(82, 165), 16, MUTED)
	_text(str(session.current_strokes), Vector2(313, 167), 27, WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_text("TOTAL", Vector2(380, 165), 16, MUTED)
	_text(str(session.total()), Vector2(633, 167), 27, WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_field(course, time)
	if session.state == Session.State.READY:
		_touch_ring(session.position)
	if session.state == Session.State.AIMING:
		_aim(session, course.bounds)
	_ball(session.position)
	match session.state:
		Session.State.READY:
			_center("Toque perto da bola e puxe", 1158, 23, WHITE)
			_center("Solte para lançar · Volte ao início para cancelar", 1195, 18, MUTED)
		Session.State.AIMING:
			_power(session)
		Session.State.MOVING:
			_center("Bola em movimento", 1158, 23, WHITE)
			_center("Aguarde a bola parar", 1195, 18, MUTED)
		Session.State.RETURNING:
			_center("Voltando à posição segura", 1158, 23, AMBER)
			_center("A tacada continua contada", 1195, 18, MUTED)
		Session.State.CAPTURED:
			_capture(session)
			_center("Próximo percurso em instantes", 1158, 21, MUTED)


func _field(course: Dictionary, time: float) -> void:
	var bounds: Rect2 = course.bounds
	_canvas.draw_rect(Rect2(bounds.position + Vector2(0, 7), bounds.size), Color("#080f18"))
	_canvas.draw_rect(bounds, FIELD)
	for x in range(int(bounds.position.x + 37), int(bounds.end.x), 74):
		_canvas.draw_line(Vector2(x, bounds.position.y + 8), Vector2(x, bounds.end.y - 8), _alpha(WHITE, 0.025), 1)
	for y in range(int(bounds.position.y + 37), int(bounds.end.y), 74):
		_canvas.draw_line(Vector2(bounds.position.x + 8, y), Vector2(bounds.end.x - 8, y), _alpha(WHITE, 0.025), 1)
	_canvas.draw_rect(bounds, EDGE, false, 5)
	_canvas.draw_rect(bounds.grow(-7), _alpha(CYAN, 0.08), false, 1)
	var hazard: Rect2 = course.hazard
	if hazard.has_area():
		_hazard(hazard)
	for wall: Rect2 in course.walls:
		_canvas.draw_rect(Rect2(wall.position + Vector2(0, 5), wall.size), Color("#0e2723"))
		_canvas.draw_rect(wall, Color("#48675e"))
		_canvas.draw_rect(wall, Color("#78988c"), false, 2)
		_canvas.draw_line(wall.position + Vector2(3, 3), Vector2(wall.end.x - 3, wall.position.y + 3), _alpha(WHITE, 0.22), 2)
	_hole(course.hole, time)
	# A small, separate tee marker is purely visual; the ball remains the input target.
	_canvas.draw_arc(course.start, 25, 0, TAU, 40, _alpha(WHITE, 0.11), 1, true)


func _hazard(rect: Rect2) -> void:
	_canvas.draw_rect(rect, Color("#493829"))
	for offset in range(-int(rect.size.y), int(rect.size.x), 23):
		var a := Vector2(rect.position.x + offset, rect.end.y)
		var b := a + Vector2(rect.size.y, -rect.size.y)
		# Clip diagonal stripe ends to the hazard rectangle.
		if a.x < rect.position.x:
			a.y -= rect.position.x - a.x
			a.x = rect.position.x
		if b.x > rect.end.x:
			b.y += b.x - rect.end.x
			b.x = rect.end.x
		if a.y >= rect.position.y and b.y <= rect.end.y:
			_canvas.draw_line(a, b, _alpha(AMBER, 0.24), 5, true)
	_canvas.draw_rect(rect, AMBER, false, 2)
	var center := rect.get_center()
	_canvas.draw_circle(center, 22, Color("#493829"))
	_canvas.draw_line(center + Vector2(-8, -8), center + Vector2(8, 8), AMBER, 4, true)
	_canvas.draw_line(center + Vector2(8, -8), center + Vector2(-8, 8), AMBER, 4, true)


func _hole(position: Vector2, time: float) -> void:
	_canvas.draw_circle(position + Vector2(0, 3), 25, _alpha(Color.BLACK, 0.3))
	_canvas.draw_circle(position, 24, _alpha(CYAN, 0.1 + 0.025 * sin(time * 2.0)))
	_canvas.draw_arc(position, 22, 0, TAU, 60, CYAN, 3, true)
	_canvas.draw_circle(position, 15, Color("#081f1c"))
	_canvas.draw_arc(position, 16, 0.0, PI, 30, _alpha(WHITE, 0.1), 1.5, true)
	var pole := position + Vector2(0, -5)
	_canvas.draw_line(pole, pole + Vector2(0, -46), WHITE, 2, true)
	_canvas.draw_polygon(PackedVector2Array([pole + Vector2(1, -46), pole + Vector2(29, -37), pole + Vector2(1, -28)]), PackedColorArray([CYAN]))


func _ball(position: Vector2, radius: float = 14) -> void:
	_canvas.draw_circle(position + Vector2(0, 4), radius + 2, _alpha(Color.BLACK, 0.3))
	_canvas.draw_circle(position, radius, WHITE)
	_canvas.draw_arc(position, radius - 2, 0.2, PI - 0.2, 24, Color("#cddbe2"), 2, true)
	_canvas.draw_circle(position + Vector2(-4, -4), 4, Color.WHITE)


func _touch_ring(position: Vector2) -> void:
	for segment in range(24):
		var angle: float = TAU * segment / 24.0
		_canvas.draw_arc(position, 72, angle, angle + 0.13, 4, _alpha(CYAN, 0.16), 1.5, true)


func _aim(session, bounds: Rect2) -> void:
	var power: float = session.power()
	if power <= 0.0:
		_touch_ring(session.position)
		return
	var direction: Vector2 = session.aim_direction()
	var color := _power_color(power)
	var length: float = _ray_length(session.position, direction, bounds.grow(-24), 83.0 + power * 112.0)
	if length < 32:
		return
	var tip: Vector2 = session.position + direction * length
	_dashed(session.position + direction * 23, tip - direction * 11, color, 3, 11, 7)
	var normal := Vector2(-direction.y, direction.x)
	_canvas.draw_polygon(PackedVector2Array([tip, tip - direction * 17 + normal * 9, tip - direction * 17 - normal * 9]), PackedColorArray([color]))


func _power(session) -> void:
	var power: float = session.power()
	var percent: int = roundi(power * 100.0)
	var color := _power_color(power)
	_center("Solte para lançar" if percent > 0 else "Puxe para escolher a força", 1150, 23, WHITE)
	_text("FORÇA", Vector2(72, 1189), 16, MUTED)
	_text("%d%%" % percent, Vector2(648, 1190), 24, color, HORIZONTAL_ALIGNMENT_RIGHT)
	_panel(Rect2(72, 1205, 576, 12), Color("#2b3948"), Color.TRANSPARENT, 6, 0)
	if power > 0.0:
		_panel(Rect2(72, 1205, maxf(12, 576 * power), 12), color, Color.TRANSPARENT, 6, 0)
	_center("Volte ao início do toque para cancelar", 1247, 17, MUTED)


func _capture(session) -> void:
	_panel(Rect2(117, 488, 486, 206), Color("#142c2b"), CYAN, 20, 2)
	_check(Vector2(360, 537), CYAN, 20)
	_center("Buraco concluído", 601, 32, WHITE)
	var count: int = session.captured_strokes
	_center("%d %s" % [count, "tacada" if count == 1 else "tacadas"], 649, 25, CYAN)


func _result(session, store) -> void:
	_canvas.draw_circle(Vector2(360, 105), 31, _alpha(CYAN, 0.12))
	_check(Vector2(360, 102), CYAN, 18)
	_center("PERCURSOS CONCLUÍDOS", 174, 18, CYAN)
	_center("Boa partida.", 248, 56, WHITE)
	if store.new_achieved_best:
		_center("Novo melhor total!", 292, 23, CYAN)
	var names := ["Linha livre", "Volta pela lateral", "Passagem estreita"]
	for index in range(3):
		var y: float = 354 + index * 96
		_panel(Rect2(100, y, 520, 76), PANEL, Color("#2c3d4c"), 13, 1)
		_canvas.draw_circle(Vector2(136, y + 38), 20, _alpha(CYAN, 0.11))
		_text("%02d" % (index + 1), Vector2(136, y + 45), 18, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
		_text(names[index], Vector2(172, y + 45), 23, WHITE)
		var score: int = int(session.results[index]) if session.results.size() > index else 0
		_text(str(score), Vector2(589, y + 49), 34, WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_center("TOTAL DE TACADAS", 691, 18, MUTED)
	_center(str(session.total()), 778, 78, WHITE)
	_records(store, 836, 31, 20, true)
	_center("Uma tacada de cada vez.", 1206, 18, MUTED)


func _records(store, y: float, spacing: float, size: int, result: bool = false) -> void:
	if store.persisted_best != null:
		var saved_label: String = "Recorde salvo: %d" if result and store.last_saved else "Melhor total salvo: %d"
		_center(saved_label % int(store.persisted_best), y, size, CYAN if result and store.last_saved else MUTED)
	else:
		_center("Ainda sem recorde salvo", y, size, MUTED)
	if store.has_unsaved_best():
		_center("Melhor total nesta execução: %d — não salvo" % int(store.best_this_execution), y + spacing, size, AMBER)
		if not str(store.last_error).is_empty():
			_center(str(store.last_error), y + spacing * 2, size - 1, AMBER)
		if store.write_blocked:
			_center("Formato do recorde desconhecido.", y + spacing * 3, size - 3, MUTED)
	elif store.write_blocked:
		_center("O recorde não foi salvo.", y + spacing, size - 1, AMBER)
		_center("Formato do recorde desconhecido.", y + spacing * 2, size - 3, MUTED)
	elif not str(store.last_error).is_empty():
		_center("Recorde indisponível; você pode jogar.", y + spacing, size - 1, AMBER)


func _modal() -> void:
	_canvas.draw_rect(Rect2(0, 0, 720, 1280), _alpha(BG, 0.82))
	_panel(Rect2(76, 445, 568, 390), PANEL, Color("#465a68"), 24, 2)
	_center("Voltar ao menu?", 511, 35, WHITE)
	_center("A partida atual será encerrada.", 565, 23, MUTED)
	_canvas.draw_line(Vector2(112, 610), Vector2(608, 610), _alpha(WHITE, 0.1), 1)


func _button(button: Dictionary) -> void:
	var rect: Rect2 = button.rect
	var style: String = str(button.style)
	var enabled: bool = bool(button.enabled)
	var fill := CYAN if style == "primary" else PANEL
	var edge := Color.TRANSPARENT if style == "primary" else Color("#415464")
	var text_color := BG if style == "primary" else WHITE
	if style == "quiet":
		fill = _alpha(PANEL, 0.8)
		edge = Color("#354857")
		text_color = MUTED
	if not enabled:
		fill = _alpha(fill, 0.26)
		edge = _alpha(edge, 0.35)
		text_color = _alpha(text_color, 0.42)
	if style == "primary" and enabled:
		_panel(Rect2(rect.position + Vector2(0, 5), rect.size), Color("#0b302e"), Color.TRANSPARENT, 14, 0)
	_panel(rect, fill, edge, 14 if rect.size.x > 180 else 11, 1)
	var size: int = 26 if rect.size.x > 180 else 21
	var baseline: float = rect.get_center().y + (_font.get_ascent(size) - _font.get_descent(size)) / 2.0
	_text(str(button.text), Vector2(rect.get_center().x, baseline), size, text_color, HORIZONTAL_ALIGNMENT_CENTER)


func _panel(rect: Rect2, color: Color, border: Color, radius: int, width: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_corner_radius_all(radius)
	box.set_border_width_all(width)
	box.anti_aliasing = true
	_canvas.draw_style_box(box, rect)


func _text(value: String, position: Vector2, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var location := position
	var width: float = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		location.x -= width / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		location.x -= width
	_canvas.draw_string(_font, location, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _center(value: String, y: float, size: int, color: Color) -> void:
	_text(value, Vector2(360, y), size, color, HORIZONTAL_ALIGNMENT_CENTER)


func _check(center: Vector2, color: Color, size: float) -> void:
	_canvas.draw_polyline(PackedVector2Array([center + Vector2(-size, 0), center + Vector2(-size * 0.3, size * 0.6), center + Vector2(size, -size * 0.7)]), color, 4, true)


func _dashed(start: Vector2, end: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
	var length := start.distance_to(end)
	if length <= 0.01:
		return
	var direction := (end - start) / length
	var cursor: float = 0.0
	while cursor < length:
		_canvas.draw_line(start + direction * cursor, start + direction * minf(cursor + dash, length), color, width, true)
		cursor += dash + gap


func _ray_length(origin: Vector2, direction: Vector2, bounds: Rect2, maximum: float) -> float:
	var length: float = maximum
	if direction.x > 0.001:
		length = minf(length, (bounds.end.x - origin.x) / direction.x)
	elif direction.x < -0.001:
		length = minf(length, (bounds.position.x - origin.x) / direction.x)
	if direction.y > 0.001:
		length = minf(length, (bounds.end.y - origin.y) / direction.y)
	elif direction.y < -0.001:
		length = minf(length, (bounds.position.y - origin.y) / direction.y)
	return maxf(length, 0.0)


func _power_color(power: float) -> Color:
	var percent: int = roundi(power * 100.0)
	if percent <= 33:
		return CYAN
	if percent <= 66:
		return YELLOW
	return AMBER


func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)

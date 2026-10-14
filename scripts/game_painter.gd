class_name GamePainter
extends RefCounted

## Original outdoor artwork. All positions use the project's 720 × 1280 space.

const Session = preload("res://scripts/golf_session.gd")
const Courses = preload("res://scripts/courses.gd")
const BG = Color("#f5f1e5")
const FIELD = Color("#183e35")
const WHITE = Color("#fbfaf4")
const CYAN = Color("#236b56")
const AMBER = Color("#ac6226")
const YELLOW = Color("#c69b38")
const MUTED = Color("#758071")
const PANEL = Color("#fffdf7")
const EDGE = Color("#d9ddcc")
const INK = Color("#264c3d")
const SOFT = Color("#e9eddd")
const WATER = Color("#3c8b98")

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
	_canvas.draw_circle(Vector2(700, 12), 186, Color("#e8edde"))
	_canvas.draw_circle(Vector2(12, 1260), 205, Color("#ece8d8"))
	_canvas.draw_arc(Vector2(692, 52), 229, 0.8, 3.0, 60, _alpha(CYAN, 0.08), 1.5, true)
	_canvas.draw_arc(Vector2(34, 1210), 268, 3.9, 6.0, 60, _alpha(CYAN, 0.06), 1.5, true)
	_sprig(Vector2(11, 285), 0.35, 55.0, _alpha(CYAN, 0.07))
	_sprig(Vector2(705, 1142), PI + 0.2, 76.0, _alpha(CYAN, 0.065))


func _menu(store, time: float) -> void:
	_leaf(Vector2(75, 81), 17.0, -0.5, CYAN)
	_text("GAMELAB  /  MINIGOLFE 3D", Vector2(103, 87), 17, CYAN)
	_text("Uma boa tacada.", Vector2(96, 164), 56, INK)
	_text("Três trilhas. Um novo jeito de explorar.", Vector2(100, 205), 23, MUTED)
	_menu_course(time)
	_center("Toque na bola, puxe e solte.", 805, 25, INK)
	_center("Sua mira. Seu ritmo.", 836, 20, MUTED)
	_panel(Rect2(100, 973, 520, 144), _alpha(PANEL, 0.76), _alpha(EDGE, 0.7), 18, 1)
	_records(store, 1005, 29, 19)
	_center("Volte ao início do toque para cancelar.", 1152, 18, MUTED)
	_center("Uma tacada de cada vez.", 1205, 18, INK)


func _menu_course(time: float) -> void:
	var hero := Rect2(64, 248, 592, 510)
	_panel(Rect2(hero.position + Vector2(0, 10), hero.size), _alpha(INK, 0.12), Color.TRANSPARENT, 24, 0)
	_panel(hero, PANEL, Color.TRANSPARENT, 24, 0)
	if _canvas.get("world_viewport") != null:
		var texture: Texture2D = _canvas.world_viewport.get_texture()
		var destination := hero.grow(-8)
		# The scenic preview fills its card without stretching the 3D artwork.
		# Gameplay below still displays the entire viewport for precise aiming.
		var source_height: float = texture.get_width() * destination.size.y / destination.size.x
		var source := Rect2(0, (texture.get_height() - source_height) * 0.52, texture.get_width(), source_height)
		_canvas.draw_texture_rect_region(texture, destination, source)
		_preview_labels()
		return
	_panel(hero.grow(-8), Color("#8fba71"), Color.TRANSPARENT, 17, 0)
	for x in range(96, 648, 60):
		for y in range(273, 744, 60):
			if (x / 60 + y / 60) % 2 == 0:
				_canvas.draw_rect(Rect2(x, y, 60, 60), _alpha(CYAN, 0.035))
	_panel(Rect2(304, 455, 30, 162), Color("#ad845c"), Color("#d2b084"), 4, 2)
	_dashed(Vector2(169, 642), Vector2(245, 395), _alpha(WHITE, 0.65), 3, 9, 8)
	_dashed(Vector2(245, 395), Vector2(530, 395), _alpha(WHITE, 0.65), 3, 9, 8)
	_hole(Vector2(534, 395), time)
	_ball(Vector2(169, 642), 16)
	_preview_labels()


func _preview_labels() -> void:
	var labels := ["Rampas", "Alturas", "Saltos"]
	for index in range(3):
		var x: float = 92 + index * 172
		_panel(Rect2(x, 278, 160, 39), _alpha(PANEL, 0.92), Color.TRANSPARENT, 12, 0)
		_course_icon(Vector2(x + 23, 298), index, 10.0, CYAN)
		_text(labels[index], Vector2(x + 44, 304), 18, INK)
	_panel(Rect2(91, 669, 538, 61), _alpha(INK, 0.91), Color.TRANSPARENT, 16, 0)
	_text("3 trilhas para explorar", Vector2(113, 707), 24, WHITE)
	for index in range(3):
		_canvas.draw_circle(Vector2(560 + index * 16, 699), 4, _alpha(WHITE, 0.72 if index == 0 else 0.3))


func _game(session, time: float) -> void:
	var course: Dictionary = session.current_course()
	_text("TRILHA %02d / 03" % (session.course_index + 1), Vector2(64, 67), 16, CYAN)
	_fit_text(str(course.name), Vector2(64, 114), 34, INK, 584)
	_panel(Rect2(64, 135, 186, 45), PANEL, EDGE, 12, 1)
	_panel(Rect2(262, 135, 186, 45), PANEL, EDGE, 12, 1)
	_panel(Rect2(460, 135, 196, 45), SOFT, Color.TRANSPARENT, 12, 0)
	_text("TACADAS", Vector2(80, 165), 15, MUTED)
	_text(str(session.current_strokes), Vector2(232, 167), 27, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_text("TOTAL", Vector2(279, 165), 15, MUTED)
	_text(str(session.total()), Vector2(430, 167), 27, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_progress(session.course_index)
	_panel(Rect2(60, 203, 600, 907), _alpha(INK, 0.11), Color.TRANSPARENT, 15, 0)
	if _canvas.get("world_viewport") != null:
		_canvas.draw_texture_rect(_canvas.world_viewport.get_texture(), Rect2(64, 200, 592, 900), false)
	else:
		_field(course, time)
		if session.state == Session.State.READY:
			_touch_ring(session.position)
		if session.state == Session.State.AIMING:
			_aim(session, course.bounds)
		_ball(session.position)
	_canvas.draw_rect(Rect2(64, 200, 592, 900), _alpha(INK, 0.16), false, 1)
	_panel(Rect2(64, 1121, 592, 105), PANEL, EDGE, 18, 1)
	match session.state:
		Session.State.READY:
			_canvas.draw_circle(Vector2(111, 1157), 18, SOFT)
			_canvas.draw_arc(Vector2(111, 1157), 9, 0, TAU, 24, CYAN, 2, true)
			_canvas.draw_circle(Vector2(111, 1157), 3.5, CYAN)
			_text("Toque na bola e puxe", Vector2(142, 1165), 25, INK)
			_center("Solte para lançar · Volte ao início para cancelar", 1203, 18, MUTED)
		Session.State.AIMING:
			_power(session)
		Session.State.MOVING:
			_center("Acompanhe sua tacada", 1167, 25, INK)
			_center("A próxima começa quando a bola parar.", 1203, 18, MUTED)
		Session.State.RETURNING:
			_center("Voltando à posição segura", 1167, 24, AMBER)
			_center("A tacada continua contada", 1203, 18, MUTED)
		Session.State.CAPTURED:
			_capture(session, time)
			_center("Próxima trilha em instantes", 1181, 23, INK)


func _progress(course_index: int) -> void:
	_canvas.draw_line(Vector2(491, 158), Vector2(627, 158), _alpha(CYAN, 0.19), 2, true)
	for index in range(3):
		var center := Vector2(492 + index * 67, 158)
		var current: bool = index == course_index
		_canvas.draw_circle(center, 14 if current else 11, CYAN if index <= course_index else Color("#d6ddca"))
		if index < course_index:
			_check(center, WHITE, 5)
		else:
			_text(str(index + 1), center + Vector2(0, 5), 15 if current else 13, WHITE if current else MUTED, HORIZONTAL_ALIGNMENT_CENTER)


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
	_text("Solte para lançar" if percent > 0 else "Puxe para escolher a força", Vector2(84, 1158), 23, INK)
	_text("%d%%" % percent, Vector2(636, 1160), 27, color, HORIZONTAL_ALIGNMENT_RIGHT)
	var segment_width: float = 22.0
	for index in range(22):
		var rect := Rect2(84 + index * 25, 1178, segment_width, 12)
		_panel(rect, color if power >= (index + 1) / 22.0 else SOFT, Color.TRANSPARENT, 4, 0)
	_center("Volte ao início do toque para cancelar", 1212, 17, MUTED)
	if _canvas.get("world_viewport") != null and _canvas.has_method("game_to_ui"):
		var ball_ui: Vector2 = _canvas.game_to_ui(session.position)
		var center := ball_ui + Vector2(0, -77)
		center.x = clampf(center.x, 145, 575)
		center.y = clampf(center.y, 239, 1056)
		_panel(Rect2(center - Vector2(74, 21), Vector2(148, 42)), _alpha(INK, 0.91), Color.TRANSPARENT, 16, 0)
		_text("FORÇA  %d%%" % percent, center + Vector2(0, 7), 19, WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _capture(session, time: float) -> void:
	var progress: float = clampf(1.0 - float(session.remaining) / 0.7, 0.0, 1.0)
	var rise: float = (1.0 - minf(progress * 5.0, 1.0)) * 14.0
	_canvas.draw_rect(Rect2(64, 200, 592, 900), _alpha(INK, 0.18))
	for index in range(12):
		var angle: float = TAU * index / 12.0 + time * 0.1
		var point := Vector2(360, 565) + Vector2(cos(angle), sin(angle)) * (108 + progress * 73)
		_canvas.draw_circle(point, 2.5 + index % 3, _alpha(YELLOW if index % 2 else WHITE, 0.72))
	_panel(Rect2(112, 482 + rise, 496, 215), _alpha(INK, 0.15), Color.TRANSPARENT, 24, 0)
	_panel(Rect2(112, 475 + rise, 496, 215), PANEL, Color("#dfdfc4"), 24, 1)
	_canvas.draw_circle(Vector2(360, 522 + rise), 26, SOFT)
	_check(Vector2(360, 522 + rise), CYAN, 15)
	_center("Bela tacada!", 590 + rise, 37, INK)
	var count: int = session.captured_strokes
	_center("Trilha concluída em %d %s" % [count, "tacada" if count == 1 else "tacadas"], 636 + rise, 23, MUTED)


func _result(session, store) -> void:
	_canvas.draw_circle(Vector2(360, 110), 48, SOFT)
	_medal(Vector2(360, 102), 26.0)
	_sprig(Vector2(313, 132), -0.67, 35.0, _alpha(CYAN, 0.55))
	_sprig(Vector2(407, 132), PI + 0.67, 35.0, _alpha(CYAN, 0.55))
	_center("AS TRÊS TRILHAS CONCLUÍDAS", 196, 17, CYAN)
	_center("Boa partida.", 270, 56, INK)
	if store.new_achieved_best:
		_center("Seu melhor total até agora!", 309, 22, CYAN)
	for index in range(3):
		var y: float = 354 + index * 96
		_panel(Rect2(100, y, 520, 76), PANEL, EDGE, 16, 1)
		_canvas.draw_circle(Vector2(139, y + 38), 24, SOFT)
		_course_icon(Vector2(139, y + 38), index, 15.0, [CYAN, AMBER, WATER][index])
		_fit_text(str(Courses.ALL[index].name), Vector2(181, y + 46), 24, INK, 333)
		var score: int = int(session.results[index]) if session.results.size() > index else 0
		_text(str(score), Vector2(589, y + 50), 34, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_panel(Rect2(100, 659, 520, 137), INK, Color.TRANSPARENT, 20, 0)
	_center("TOTAL DE TACADAS", 695, 17, _alpha(WHITE, 0.7))
	_center(str(session.total()), 773, 74, WHITE)
	_records(store, 833, 29, 19, true)
	_center("Cada partida é um novo caminho.", 1206, 18, MUTED)


func _records(store, y: float, spacing: float, size: int, result: bool = false) -> void:
	if store.persisted_best != null:
		var saved_label: String = "Recorde salvo: %d" if result and store.last_saved else "Melhor total salvo: %d"
		_center(saved_label % int(store.persisted_best), y, size, CYAN if result and store.last_saved else INK)
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
	_canvas.draw_rect(Rect2(0, 0, 720, 1280), _alpha(INK, 0.64))
	_panel(Rect2(76, 453, 568, 390), _alpha(Color.BLACK, 0.12), Color.TRANSPARENT, 24, 0)
	_panel(Rect2(76, 445, 568, 390), PANEL, EDGE, 24, 1)
	_center("Voltar ao menu?", 511, 35, INK)
	_center("A partida atual será encerrada.", 565, 23, MUTED)
	_canvas.draw_line(Vector2(112, 610), Vector2(608, 610), EDGE, 1)


func _button(button: Dictionary) -> void:
	var rect: Rect2 = button.rect
	var style: String = str(button.style)
	var enabled: bool = bool(button.enabled)
	var fill := CYAN if style == "primary" else PANEL
	var edge := Color.TRANSPARENT if style == "primary" else EDGE
	var text_color := WHITE if style == "primary" else INK
	if style == "quiet":
		fill = _alpha(PANEL, 0.88)
		edge = EDGE
		text_color = INK
	if not enabled:
		fill = _alpha(fill, 0.55)
		edge = _alpha(edge, 0.5)
		text_color = _alpha(text_color, 0.4)
	var pressed: bool = false
	if _canvas.get("ui_presses") is Dictionary:
		pressed = _canvas.ui_presses.values().has(str(button.id))
	if style == "primary" and enabled:
		_panel(Rect2(rect.position + Vector2(0, 5), rect.size), Color("#174837"), Color.TRANSPARENT, 17, 0)
	if pressed:
		rect.position.y += 2
	_panel(rect, fill, edge, 17 if rect.size.x > 180 else 12, 1)
	var size: int = 26 if rect.size.x > 180 else 21
	if str(button.id) == "camera":
		size = 17
	if rect.size.y <= 36:
		size = 16
	var available_width: float = rect.size.x - 22
	while _font.get_string_size(str(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > available_width and size > 13:
		size -= 1
	var baseline: float = rect.get_center().y + (_font.get_ascent(size) - _font.get_descent(size)) / 2.0
	_text(str(button.text), Vector2(rect.get_center().x, baseline), size, text_color, HORIZONTAL_ALIGNMENT_CENTER)
	if style == "primary" and enabled and rect.size.x > 180:
		var point := Vector2(rect.end.x - 33, rect.get_center().y)
		_canvas.draw_polyline(PackedVector2Array([point + Vector2(-5, -7), point + Vector2(2, 0), point + Vector2(-5, 7)]), _alpha(WHITE, 0.85), 2.5, true)


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


func _fit_text(value: String, position: Vector2, size: int, color: Color, maximum_width: float) -> void:
	var fitted: int = size
	while _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > maximum_width and fitted > 15:
		fitted -= 1
	_text(value, position, fitted, color)


func _leaf(center: Vector2, size: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point in [Vector2(-1, 0), Vector2(-0.5, -0.52), Vector2(0.35, -0.61), Vector2(1, 0), Vector2(0.35, 0.61), Vector2(-0.5, 0.52)]:
		points.append(center + (point * size).rotated(angle))
	_canvas.draw_polygon(points, PackedColorArray([color]))
	_canvas.draw_line(center + Vector2(-size * 0.73, 0).rotated(angle), center + Vector2(size * 0.72, 0).rotated(angle), _alpha(WHITE, color.a * 0.48), 1.2, true)


func _sprig(origin: Vector2, angle: float, length: float, color: Color) -> void:
	var direction := Vector2(0, -1).rotated(angle)
	_canvas.draw_line(origin, origin + direction * length, color, 1.5, true)
	for index in range(3):
		var branch := origin + direction * length * (0.28 + index * 0.26)
		for side in [-1, 1]:
			var offset := Vector2(side * length * 0.12, -length * 0.04).rotated(angle)
			_leaf(branch + offset, length * 0.16, angle - side * 0.7, color)


func _course_icon(center: Vector2, index: int, size: float, color: Color) -> void:
	match index:
		0:
			_leaf(center, size, -0.67, color)
		1:
			_canvas.draw_polygon(PackedVector2Array([center + Vector2(-size, size * 0.6), center + Vector2(-size * 0.2, -size * 0.8), center + Vector2(size * 0.6, size * 0.6)]), PackedColorArray([color]))
			_canvas.draw_polyline(PackedVector2Array([center + Vector2(size * 0.1, -size * 0.1), center + Vector2(size * 0.55, -size * 0.68), center + Vector2(size * 1.12, size * 0.6)]), color, 2.3, true)
		_:
			for line in range(3):
				var points := PackedVector2Array()
				for step in range(13):
					var x: float = -size + step * size / 6.0
					points.append(center + Vector2(x, (line - 1) * size * 0.6 + sin(step * PI / 6.0) * size * 0.19))
				_canvas.draw_polyline(points, color, 2, true)


func _medal(center: Vector2, size: float) -> void:
	_canvas.draw_polygon(PackedVector2Array([center + Vector2(-size * 0.7, size * 0.3), center + Vector2(-size * 0.66, size * 1.57), center + Vector2(0, size * 1.2), center + Vector2(size * 0.66, size * 1.57), center + Vector2(size * 0.7, size * 0.3)]), PackedColorArray([CYAN]))
	_canvas.draw_circle(center, size, Color("#d1aa56"))
	_canvas.draw_arc(center, size - 5, 0, TAU, 48, Color("#f5df98"), 2, true)
	var star := PackedVector2Array()
	for index in range(10):
		var radius: float = size * (0.55 if index % 2 == 0 else 0.26)
		star.append(center + Vector2(0, -radius).rotated(index * TAU / 10.0))
	_canvas.draw_polygon(star, PackedColorArray([WHITE]))


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

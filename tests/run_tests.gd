extends SceneTree

var checks := 0
var failures: Array[String] = []
var temporary_directory := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	temporary_directory = OS.get_cache_dir().path_join("gamelab-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var directory_error := DirAccess.make_dir_recursive_absolute(temporary_directory)
	_check("Criar diretório isolado para registros de teste", directory_error == OK)
	var session_tests = load("res://tests/test_session.gd").new()
	session_tests.run(_check)
	var records_tests = load("res://tests/test_records.gd").new()
	records_tests.run(_check, temporary_directory)
	if FileAccess.file_exists("res://tests/test_ui.gd"):
		var checks_before_ui := checks
		var ui_tests = load("res://tests/test_ui.gd").new()
		await ui_tests.run(_check)
		if checks - checks_before_ui < 20:
			failures.append("Suíte de interface interrompida ou incompleta")
	if FileAccess.file_exists("res://tests/test_3d.gd"):
		var checks_before_3d := checks
		var three_d_tests = load("res://tests/test_3d.gd").new()
		await three_d_tests.run(_check)
		print("3D nativo: %d verificações específicas." % (checks - checks_before_3d))
		if checks - checks_before_3d < 20 or not three_d_tests.completed:
			failures.append("Suíte 3D interrompida ou incompleta")
	if FileAccess.file_exists("res://tests/test_presentation.gd"):
		var checks_before_presentation := checks
		var presentation_tests = load("res://tests/test_presentation.gd").new()
		await presentation_tests.run(_check)
		print("Apresentação e câmera: %d verificações específicas." % (checks - checks_before_presentation))
		if checks - checks_before_presentation < 20 or not presentation_tests.completed:
			failures.append("Suíte de apresentação interrompida ou incompleta")
	_remove_test_directory(temporary_directory)
	# Freed AudioStreamPlayers leave release commands for the mixer. Drain
	# them before quitting this short-lived harness, including cold imports.
	await create_timer(0.15).timeout
	print("\nGameLab: %d verificações; %d falhas." % [checks, failures.size()])
	for failure in failures:
		printerr("FALHOU: ", failure)
	quit(0 if failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _remove_test_directory(path: String) -> void:
	# Restrict cleanup to this runner's unique directory, including files the
	# persistence tests create when simulating invalid paths and failed writes.
	if temporary_directory.is_empty() or not path.begins_with(temporary_directory):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name in directory.get_directories():
		_remove_test_directory(path.path_join(name))
	directory = null
	DirAccess.remove_absolute(path)

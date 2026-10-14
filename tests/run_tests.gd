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
		var ui_tests = load("res://tests/test_ui.gd").new()
		await ui_tests.run(_check)
	_remove_test_directory(temporary_directory)
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

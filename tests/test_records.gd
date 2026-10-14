extends RefCounted

const Store = preload("res://scripts/record_store.gd")


func run(check: Callable, temp_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(temp_dir)
	var path := temp_dir.path_join("records.json")
	_remove(path)
	var store = Store.new(path)
	check.call("Recorde ausente não cria arquivo nem recorde", store.persisted_best == null and not FileAccess.file_exists(path))
	check.call("Total incompleto rejeitado sem gravação", not store.complete_session(2) and not FileAccess.file_exists(path))
	check.call("Primeira sessão completa grava 12", store.complete_session(12) and store.last_saved and store.new_best)
	check.call("Recorde salvo e melhor da execução separados", store.persisted_best == 12 and store.best_this_execution == 12 and not store.has_unsaved_best())
	var reloaded = Store.new(path)
	check.call("Nova instância restaura apenas arquivo persistido", reloaded.persisted_best == 12 and reloaded.best_this_execution == 12)
	var original := _read(path)
	reloaded.failure_stage = "replace"
	check.call("Empate não regrava arquivo", not reloaded.complete_session(12) and _read(path) == original and not reloaded.new_best and reloaded.last_error.is_empty())
	check.call("Resultado pior não regrava arquivo", not reloaded.complete_session(15) and _read(path) == original and reloaded.persisted_best == 12 and reloaded.last_error.is_empty())
	reloaded.failure_stage = ""
	check.call("Menor total válido 3 grava", reloaded.complete_session(3) and Store.new(path).persisted_best == 3)
	var saved_format: Variant = JSON.parse_string(_read(path))
	check.call("Grava formato canônico schema_version sem campo legado", saved_format.has("schema_version") and not saved_format.has("schema") and saved_format["schema_version"] == 1)
	_write(path, "{\"schema_version\":1,\"best_total\":3}")
	check.call("Lê exemplo inteiro documentado no GDD", Store.new(path).persisted_best == 3)

	_write(path, "{\"schema_version\":1,\"best_total\":3.0}\n")
	check.call("Número JSON integral 3.0 aceito", Store.new(path).persisted_best == 3)
	_write(path, "{\"schema_version\":1.0,\"best_total\":null}")
	check.call("Esquema integral e ausência null aceitos", Store.new(path).persisted_best == null and not Store.new(path).write_blocked)
	for source in [
		"{\"schema_version\":1,\"best_total\":true}",
		"{\"schema_version\":1,\"best_total\":false}",
		"{\"schema_version\":1,\"best_total\":3.5}",
		"{\"schema_version\":1,\"best_total\":2}",
		"{\"schema_version\":1,\"best_total\":\"3\"}",
		"{\"schema_version\":1}",
		"{\"best_total\":3}",
		"{\"schema_version\":true,\"best_total\":3}",
		"{\"schema_version\":1.5,\"best_total\":3}",
		"{\"schema_version\":\"1\",\"best_total\":3}",
		"{\"schema\":1,\"best_total\":3}",
		"[]",
		"{broken"
	]:
		_write(path, source)
		var invalid = Store.new(path)
		check.call("JSON inválido fica sem recorde: " + source, invalid.persisted_best == null and invalid.best_this_execution == null)
		check.call("Leitura inválida preserva bytes: " + source, _read(path) == source)

	var future := "{\"schema_version\":2,\"best_total\":7,\"future_field\":\"preserve me\"}\n"
	_write(path, future)
	var unknown = Store.new(path)
	check.call("Formato desconhecido bloqueia escrita", unknown.write_blocked and unknown.persisted_best == null)
	check.call("Formato desconhecido mantém resultado em memória", not unknown.complete_session(9) and unknown.best_this_execution == 9 and unknown.has_unsaved_best())
	check.call("Formato desconhecido mantém arquivo byte a byte", _read(path) == future and unknown.last_error == "O recorde não foi salvo." and not unknown.last_saved)
	_write(path, "{\"schema_version\":1,\"best_total\":12}")
	unknown.load_record()
	check.call("Bloqueio dura a execução mesmo após reler esquema conhecido", unknown.write_blocked and not unknown.complete_session(9) and _read(path) == "{\"schema_version\":1,\"best_total\":12}")

	for stage in ["open", "write", "replace"]:
		_write(path, "{\"schema_version\":1,\"best_total\":12}\n")
		var before := _read(path)
		var failing = Store.new(path)
		failing.failure_stage = stage
		check.call("Falha " + stage + " não confirma recorde", not failing.complete_session(9) and not failing.last_saved and not failing.new_best)
		check.call("Falha " + stage + " reconhece melhor alcançado sem anunciar gravação", failing.new_achieved_best and not failing.new_best)
		check.call("Falha " + stage + " preserva recorde anterior", failing.persisted_best == 12 and _read(path) == before)
		check.call("Falha " + stage + " preserva melhor somente em memória", failing.best_this_execution == 9 and failing.has_unsaved_best() and failing.last_error == "O recorde não pôde ser salvo.")
		check.call("Reinício após falha " + stage + " restaura 12", Store.new(path).persisted_best == 12)
		check.call("Falha " + stage + " limpa seus arquivos temporários", _temporary_count(temp_dir, "records.json.tmp-") == 0)
		failing.failure_stage = ""
		check.call("Outra sessão de 10 repete melhor de 9 após " + stage, failing.complete_session(10) and failing.persisted_best == 9 and failing.best_this_execution == 9 and not failing.has_unsaved_best())
		check.call("Nova tentativa " + stage + " anuncia só novo recorde salvo", failing.new_best and not failing.new_achieved_best)
		check.call("Recorde 9 confirmado após " + stage + " sobrevive reinício", Store.new(path).persisted_best == 9)

	var missing_parent := temp_dir.path_join("absent-parent/records.json")
	var unavailable = Store.new(missing_parent)
	check.call("Diretório ausente falha sem interromper resultado", not unavailable.complete_session(8) and unavailable.best_this_execution == 8 and unavailable.persisted_best == null and unavailable.last_error == "O recorde não pôde ser salvo.")
	check.call("Só construir e destruir instância não grava", not FileAccess.file_exists(missing_parent))
	var readonly_parent := temp_dir.path_join("readonly-parent")
	DirAccess.make_dir_recursive_absolute(readonly_parent)
	var readonly_path := readonly_parent.path_join("records.json")
	_write(readonly_path, "{\"schema_version\":1,\"best_total\":12}")
	var readonly_store = Store.new(readonly_path)
	var permission_error := FileAccess.set_unix_permissions(readonly_parent, 320) # owner r-x
	if permission_error == OK:
		var saved_despite_permissions: bool = readonly_store.complete_session(9)
		FileAccess.set_unix_permissions(readonly_parent, 448) # restore owner rwx
		check.call("Diretório sem escrita retorna erro de E/S sem travar", not saved_despite_permissions and readonly_store.last_error == "O recorde não pôde ser salvo.")
		check.call("Permissão de diretório não altera recorde anterior", _read(readonly_path) == "{\"schema_version\":1,\"best_total\":12}" and readonly_store.persisted_best == 12 and readonly_store.best_this_execution == 9)
	_remove(readonly_path)
	DirAccess.remove_absolute(readonly_parent)
	_remove(path)


static func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


static func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	var contents := file.get_as_text()
	file.close()
	return contents


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _temporary_count(directory: String, prefix: String) -> int:
	var count := 0
	for name in DirAccess.get_files_at(directory):
		if name.begins_with(prefix):
			count += 1
	return count

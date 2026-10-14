class_name RecordStore
extends RefCounted

## Only completed, three-hole sessions are sent to this store by the session UI.
## Reading and destroying the store never write a record.
var persisted_best: Variant = null
var best_this_execution: Variant = null
var write_blocked: bool = false
var last_error: String = ""
var last_saved: bool = false
var new_best: bool = false
var new_achieved_best: bool = false

# Deliberately narrow test seam. The game never changes this property.
var failure_stage: String = ""

var _path: String
static var _temporary_serial: int = 0


func _init(path: String = "user://record.json") -> void:
	_path = ProjectSettings.globalize_path(path)
	load_record()


func load_record() -> void:
	persisted_best = null
	best_this_execution = null
	last_saved = false
	new_best = false
	new_achieved_best = false
	last_error = "O recorde não foi salvo." if write_blocked else ""
	if not FileAccess.file_exists(_path):
		return
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		last_error = "O recorde não pôde ser salvo."
		return
	var contents := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		last_error = "O recorde não pôde ser salvo."
		return
	var parser := JSON.new()
	if parser.parse(contents) != OK:
		return
	var data: Variant = parser.data
	if not data is Dictionary or not data.has("schema_version"):
		return
	var schema: Variant = data["schema_version"]
	if not _is_integral_number(schema):
		return
	if schema != 1:
		# This latch survives explicit reloads: future formats remain untouched.
		write_blocked = true
		last_error = "O recorde não foi salvo."
		return
	if not data.has("best_total"):
		return
	var best: Variant = data["best_total"]
	if best == null:
		return
	if not _is_integral_number(best) or best < 3:
		return
	persisted_best = best
	best_this_execution = best


func complete_session(total: int) -> bool:
	last_saved = false
	new_best = false
	new_achieved_best = false
	last_error = ""
	if total < 3:
		return false
	if best_this_execution == null or total < best_this_execution:
		best_this_execution = total
		new_achieved_best = true
	if write_blocked:
		last_error = "O recorde não foi salvo."
		return false
	if not has_unsaved_best():
		return false
	# A later, worse session still retries the best previously held in memory.
	if not _write_atomically(best_this_execution):
		last_error = "O recorde não pôde ser salvo."
		return false
	persisted_best = best_this_execution
	last_saved = true
	new_best = true
	return true


func has_unsaved_best() -> bool:
	return best_this_execution != null and (
		persisted_best == null or best_this_execution < persisted_best
	)


static func _is_integral_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and value == floor(value)
	return false


func _write_atomically(best: Variant) -> bool:
	if failure_stage == "open":
		return false
	_temporary_serial += 1
	var temporary := "%s.tmp-%d-%d-%d" % [
		_path, OS.get_process_id(), Time.get_ticks_usec(), _temporary_serial
	]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	var contents := JSON.stringify({"schema_version": 1, "best_total": best}) + "\n"
	if failure_stage == "write":
		file.store_string(contents.substr(0, contents.length() / 2))
	else:
		file.store_string(contents)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or failure_stage == "write":
		_remove_temporary(temporary)
		return false
	# Check the bytes in addition to the stream error before touching the old file.
	var verification := FileAccess.open(temporary, FileAccess.READ)
	if verification == null:
		_remove_temporary(temporary)
		return false
	var actual := verification.get_as_text()
	var verification_error := verification.get_error()
	verification.close()
	if actual != contents or (verification_error != OK and verification_error != ERR_FILE_EOF):
		_remove_temporary(temporary)
		return false
	if failure_stage == "replace":
		_remove_temporary(temporary)
		return false
	# Same-directory replacement is atomic on the tested desktop filesystem.
	# Never delete the persisted file first: a failed rename preserves it.
	var replace_error := DirAccess.rename_absolute(temporary, _path)
	if replace_error != OK:
		_remove_temporary(temporary)
		return false
	return true


static func _remove_temporary(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

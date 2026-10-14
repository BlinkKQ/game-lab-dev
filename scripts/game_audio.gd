extends Node

## Original, offline sound cues synthesized once into short mono WAV streams.
## This node observes the session; it never changes its input, score or motion.
signal cue_played(cue: StringName)

const SAMPLE_RATE := 22050
const VOICE_COUNT := 4
const CUES := [&"launch", &"wall", &"landing", &"capture", &"return", &"click"]
const DURATIONS := [0.10, 0.075, 0.12, 0.44, 0.27, 0.055]

var enabled := true
var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next_voice := 0
var _last_state := -1
var _last_total := 0
var _last_feedback_sequence := -1
var _last_adapter_id := 0
var _paused := false
var _initialized := false


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	_stop_all()


func setup(session = null) -> void:
	if _streams.is_empty():
		for index in CUES.size():
			_streams[CUES[index]] = _synthesize(CUES[index], DURATIONS[index], 7319 + index)
	if _voices.is_empty():
		for index in VOICE_COUNT:
			var player := AudioStreamPlayer.new()
			player.name = "SoundVoice%d" % index
			player.max_polyphony = 1
			add_child(player)
			_voices.append(player)
	if session != null:
		_snapshot(session)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_stop_all()


func update(session) -> void:
	if _voices.is_empty():
		setup()
	if not _initialized:
		_snapshot(session)
		return
	var state: int = session.state
	var total: int = session.total()
	var paused: bool = session.is_paused()
	var feedback := _contact_feedback(session)
	if not enabled or paused:
		_stop_all()
	else:
		if total > _last_total and state in [session.State.MOVING, session.State.CAPTURED, session.State.RETURNING]:
			_play(&"launch", 0.85)
		if state != _last_state:
			if state == session.State.CAPTURED:
				_play(&"capture")
			elif state == session.State.RETURNING:
				_play(&"return", 0.85)
		if feedback["fresh"] and state == session.State.MOVING:
			var wall: float = feedback["wall"]
			var landing: float = feedback["landing"]
			# Ignore tiny support corrections, which would otherwise buzz on a
			# resting slope. Levels depend only on measured contact speed in m/s.
			if wall >= 0.25:
				_play(&"wall", clampf(wall / 5.0, 0.25, 1.0))
			if landing >= 0.35:
				_play(&"landing", clampf(landing / 3.0, 0.25, 1.0))
	_paused = paused
	_last_state = state
	_last_total = total


func play_ui_click() -> void:
	if enabled and not _paused:
		if _voices.is_empty():
			setup()
		_play(&"click", 0.65)


func _snapshot(session) -> void:
	_last_state = session.state
	_last_total = session.total()
	_paused = session.is_paused()
	_contact_feedback(session)
	_initialized = true


func _contact_feedback(session) -> Dictionary:
	var adapter: RefCounted = session.motion_adapter
	if adapter == null:
		_last_adapter_id = 0
		_last_feedback_sequence = -1
		return {"fresh": false, "wall": 0.0, "landing": 0.0}
	var sequence = adapter.get("feedback_sequence")
	if sequence == null:
		return {"fresh": false, "wall": 0.0, "landing": 0.0}
	var adapter_id := adapter.get_instance_id()
	var fresh: bool = adapter_id == _last_adapter_id and sequence != _last_feedback_sequence
	_last_adapter_id = adapter_id
	_last_feedback_sequence = sequence
	return {
		"fresh": fresh,
		"wall": float(adapter.get("feedback_wall_impact")),
		"landing": float(adapter.get("feedback_landing_impact")),
	}


func _play(cue: StringName, strength := 1.0) -> void:
	if not enabled or not is_inside_tree() or not _streams.has(cue):
		return
	var player := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	player.stop()
	player.stream = _streams[cue]
	player.volume_db = -10.0 + linear_to_db(clampf(strength, 0.05, 1.0))
	player.play()
	cue_played.emit(cue)


func _stop_all() -> void:
	for player in _voices:
		player.stop()
		player.stream = null


func _synthesize(cue: StringName, duration: float, seed_value: int) -> AudioStreamWAV:
	var frame_count := int(duration * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var phase := 0.0
	var smooth_noise := 0.0
	for index in frame_count:
		var time := float(index) / SAMPLE_RATE
		var progress := time / duration
		var noise := random.randf_range(-1.0, 1.0)
		smooth_noise = smooth_noise * 0.92 + noise * 0.08
		var attack := minf(time / 0.003, 1.0)
		var tail := minf((duration - time) / 0.012, 1.0)
		var sample := 0.0
		match cue:
			&"launch":
				phase += TAU * lerpf(610.0, 230.0, progress) / SAMPLE_RATE
				sample = (sin(phase) * 0.72 + noise * 0.16) * exp(-progress * 7.0)
			&"wall":
				phase += TAU * 790.0 / SAMPLE_RATE
				sample = (sin(phase) * 0.45 + sin(phase * 1.47) * 0.25 + noise * 0.28) * exp(-progress * 8.0)
			&"landing":
				phase += TAU * lerpf(160.0, 85.0, progress) / SAMPLE_RATE
				sample = (sin(phase) * 0.68 + smooth_noise * 0.55) * exp(-progress * 6.0)
			&"capture":
				# Three gentle major-triad notes have their own short envelopes.
				for note in 3:
					var note_time := time - float(note) * 0.09
					if note_time >= 0.0:
						var frequency: float = [523.25, 659.25, 783.99][note]
						var envelope := minf(note_time / 0.004, 1.0) * exp(-note_time * 12.0)
						sample += (sin(TAU * frequency * note_time) + sin(TAU * frequency * 2.0 * note_time) * 0.12) * envelope * 0.40
			&"return":
				phase += TAU * lerpf(470.0, 110.0, progress) / SAMPLE_RATE
				sample = (sin(phase + smooth_noise * 4.0) * 0.45 + smooth_noise * 0.70) * exp(-progress * 3.6)
			&"click":
				phase += TAU * lerpf(1150.0, 750.0, progress) / SAMPLE_RATE
				sample = sin(phase) * exp(-progress * 9.0) * 0.5
		var value := int(clampf(sample * attack * tail * 0.65, -1.0, 1.0) * 32767.0)
		pcm.encode_u16(index * 2, value & 0xffff)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream

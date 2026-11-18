class_name Sfx
## Plays the synthesised sound effects of assets/sfx/. A sound given a
## position is heard from that spot (quieter when far from the camera).

static var _cache := {}

static func stream(name: String) -> AudioStream:
	if not _cache.has(name):
		_cache[name] = load("res://assets/sfx/%s.wav" % name)
	return _cache[name]

static func play(from: Node, name: String, pos: Variant = null, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	if from == null or not from.is_inside_tree():
		return
	var p: Node
	if pos is Vector2:
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = 520.0
		p2.attenuation = 1.5
		p2.position = pos
		p = p2
	else:
		p = AudioStreamPlayer.new()
	p.stream = stream(name)
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	from.get_tree().current_scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## A looping background sound (the wind).
static func loop(from: Node, name: String, volume_db: float) -> AudioStreamPlayer:
	var s: AudioStreamWAV = stream(name).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	from.add_child(p)
	p.play()
	return p

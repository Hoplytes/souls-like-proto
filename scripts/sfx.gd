class_name Sfx
## Sound effects. Two sets can be compared in game with the N key:
## - "recorded": real recordings from assets/sfx_cc0/ (see CREDITS-AUDIO.md),
##   falling back to the synthesised sound when there is no recording;
## - "synth": every sound synthesised by tools/make_sfx.py (assets/sfx/).
## A sound given a position is heard from that spot.

const RECORDED := {
	"swing_light": ["whoosh_small_1", "whoosh_small_2", "whoosh_small_3"],
	"swing_heavy": ["whoosh_medium_1", "whoosh_medium_2", "whoosh_medium_3"],
	"thrust": ["swoosh_1", "swoosh_2", "swoosh_3"],
	"hit_flesh": ["punch_1", "punch_2", "punch_3"],
	"hit_heavy": ["punch_hard_1", "punch_hard_2", "punch_hardest"],
	"hit_bone": ["wood_light_1", "wood_light_2", "wood_light_3"],
	"block": ["plate_heavy_1", "plate_heavy_2", "plate_heavy_3"],
	"parry": ["bell_heavy_1", "bell_heavy_2"],
	"guard_break": ["metal_heavy_1", "metal_heavy_2"],
	"roll": ["cloth_gear_1", "cloth_gear_2"],
	"step": ["step_dirt_1", "step_dirt_2", "step_dirt_3", "step_dirt_4", "step_dirt_5"],
	"player_hurt": ["male_hurt_1", "male_hurt_2", "male_hurt_3"],
	"player_death": ["male_death"],
	"player_effort": ["male_effort"],
	"skeleton_swing": ["whoosh_small_1", "whoosh_small_2", "whoosh_small_3"],
	"skeleton_death": ["bones_break_1", "bones_break_2"],
	"boss_roar": ["giant_effort"],
	"boss_rage": ["troll_scream"],
	"boss_effort": ["ogre_effort"],
	"boss_hurt": ["ogre_hurt_1", "ogre_hurt_2", "ogre_hurt_3"],
	"boss_death": ["ogre_death_scream"],
	"rocks": ["mining_1", "mining_2"],
	"you_died": ["sting_loss"],
	"victory": ["sting_victory"],
	"ambience": ["forest_night_loop"],
}
const SYNTH := {"step": ["step_0", "step_1", "step_2"], "ambience": ["wind_loop"]}

static var use_recorded := true
static var _cache := {}
static var _ambience: AudioStreamPlayer

static func _path(name: String) -> String:
	if use_recorded and RECORDED.has(name):
		return "res://assets/sfx_cc0/%s.ogg" % RECORDED[name].pick_random()
	var synth: String = SYNTH[name].pick_random() if SYNTH.has(name) else name
	var p := "res://assets/sfx/%s.wav" % synth
	return p if ResourceLoader.exists(p) else ""

static func stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

static func play(from: Node, name: String, pos: Variant = null, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	if from == null or not from.is_inside_tree():
		return
	var path := _path(name)
	if path == "":
		return  # this sound only exists in the other set
	var p: Node
	if pos is Vector2:
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = 520.0
		p2.attenuation = 1.5
		p2.position = pos
		p = p2
	else:
		p = AudioStreamPlayer.new()
	p.stream = stream(path)
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	from.get_tree().current_scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## Background ambience (forest at night, or synthesised wind), looping.
static func start_ambience(from: Node) -> void:
	if _ambience == null or not is_instance_valid(_ambience):
		_ambience = AudioStreamPlayer.new()
		from.add_child(_ambience)
	var s: AudioStream = stream(_path("ambience")).duplicate()
	if s is AudioStreamOggVorbis:
		s.loop = true
		_ambience.volume_db = -6.0
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
		_ambience.volume_db = -14.0
	_ambience.stream = s
	_ambience.play()

static func toggle_set(from: Node) -> String:
	use_recorded = not use_recorded
	start_ambience(from)
	return "Sons : enregistrés" if use_recorded else "Sons : synthèse"

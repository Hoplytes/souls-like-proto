class_name Music
extends Node
## Background music with cross-fades: silence while exploring, the boss
## theme when the fight starts, a heavier track in the boss's second phase.

const TRACKS := {
	"boss_phase1": "res://assets/music/boss_phase1.ogg",
	"boss_phase2": "res://assets/music/boss_phase2.ogg",
}
const VOLUME_DB := -8.0

var _players: Array[AudioStreamPlayer] = []
var _current := -1

func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)

func play(track: String, fade: float = 1.5) -> void:
	var s: AudioStreamOggVorbis = load(TRACKS[track]).duplicate()
	s.loop = true
	s.resource_name = track
	var nxt := 0 if _current != 0 else 1
	var p := _players[nxt]
	p.stream = s
	p.volume_db = -40.0
	p.play()
	var t := create_tween().set_parallel(true)
	t.tween_property(p, "volume_db", VOLUME_DB, fade)
	if _current >= 0:
		_fade_out(_players[_current], fade)
	_current = nxt

func stop(fade: float = 2.0) -> void:
	if _current >= 0:
		_fade_out(_players[_current], fade)
	_current = -1

func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	var t := create_tween()
	t.tween_property(p, "volume_db", -60.0, fade)
	t.tween_callback(p.stop)

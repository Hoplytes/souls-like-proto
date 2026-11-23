class_name Music
extends Node
## Background music with cross-fades: one theme per biome while exploring
## (Flare, CC-BY-SA 3.0), the boss theme during a fight, a heavier track in
## the boss's second phase.

const TRACKS := {
	"boss_phase1": "res://assets/music/boss_phase1.ogg",
	"boss_phase2": "res://assets/music/boss_phase2.ogg",
}
const FLARE := "res://assets/flare_audio/music/%s.ogg"

var current_track := ""
const VOLUME_DB := -8.0

var _players: Array[AudioStreamPlayer] = []
var _current := -1
var _tweens := [null, null]  # the fade running on each player

func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)

func play(track: String, fade: float = 1.5, volume_db: float = VOLUME_DB) -> void:
	if track == current_track:
		return
	current_track = track
	var s: AudioStreamOggVorbis = load(TRACKS[track] if TRACKS.has(track) else FLARE % track).duplicate()
	s.loop = true
	s.resource_name = track
	var nxt := 0 if _current != 0 else 1
	var p := _players[nxt]
	p.stream = s
	p.volume_db = -40.0
	p.play()
	_fade(nxt, volume_db, fade, false)
	if _current >= 0:
		_fade_out(_players[_current], fade)
	_current = nxt

func stop(fade: float = 2.0) -> void:
	current_track = ""
	if _current >= 0:
		_fade_out(_players[_current], fade)
	_current = -1

func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	_fade(_players.find(p), -60.0, fade, true)

## One fade at a time per player: a new one cancels the old (otherwise an
## old fade-out could stop a track that has just started again).
func _fade(k: int, to_db: float, fade: float, then_stop: bool) -> void:
	if _tweens[k]:
		_tweens[k].kill()
	var p := _players[k]
	var t := create_tween()
	t.tween_property(p, "volume_db", to_db, fade)
	if then_stop:
		t.tween_callback(p.stop)
	_tweens[k] = t

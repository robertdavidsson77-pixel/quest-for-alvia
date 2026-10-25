## Music and sound effects. Loaded as the autoload "Sound", so any script can
## call Sound.play("door"). Each sound name has a few takes; one is picked at
## random so repeated sounds don't feel mechanical.
## Music has three layers: the cave ambience always plays underneath, and an
## exploring track crossfades to a combat track while Sound.set_combat(true).
## Sound effects are CC0; the two music tracks are CC-BY, see audio/CREDITS.md.
extends Node

const SFX_DIR := "res://audio/sfx/"
const AMBIENCE_FILE := "res://audio/music/dungeon-ambience.ogg"
const EXPLORE_FILE := "res://audio/music/dark-quest.ogg"
const COMBAT_FILE := "res://audio/music/dark-descent.mp3"

## Sound name -> [file names, volume in dB].
const SOUNDS := {
	"door": [["door-2-open.ogg", "door-4-heavy.wav"], 0.0],
	"door_creak": [["door-3-creak.ogg"], -2.0],
	"dice_shake": [["dice-1-shake.ogg"], -4.0],
	"dice_land": [["dice-2-throw.ogg"], -2.0],
	"die_land": [["dice-3-single.ogg"], -2.0],
	"step": [["step-1-stone.ogg", "step-2-stone.ogg", "step-3-boot.ogg"], -8.0],
	"hit": [["sword-hit-1-metal.ogg", "sword-hit-2-armour.ogg", "sword-hit-3-chop.ogg"], -2.0],
	"crit": [["sword-hit-4-slice.ogg"], 0.0],
	"miss": [["miss-1-swish.wav", "miss-2-swish.wav", "miss-3-swing.wav"], -2.0],
	"goblin": [["goblin-1.wav", "goblin-2.wav", "goblin-3.wav"], -3.0],
	"goblin_wake": [["goblin-5-beast.wav"], 0.0],
}
const AMBIENCE_DB := -16.0
const MUSIC_DB := -10.0
const SILENT_DB := -60.0
const CROSSFADE_TIME := 2.0
const VOICES := 8  # how many sounds can play at once

var volume := 0.8:  # 0..1, the slider value
	set(value):
		volume = clampf(value, 0.0, 1.0)
		_apply_volume()
var muted := false:
	set(value):
		muted = value
		_apply_volume()

var _streams := {}  # sound name -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _explore: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _in_combat := false
var _fade: Tween


func _ready() -> void:
	for sound_name in SOUNDS:
		var takes: Array[AudioStream] = []
		for file in SOUNDS[sound_name][0]:
			takes.append(load(SFX_DIR + file))
		_streams[sound_name] = takes
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	_make_music(AMBIENCE_FILE, AMBIENCE_DB).play()
	_explore = _make_music(EXPLORE_FILE, MUSIC_DB)
	_explore.play()
	_combat = _make_music(COMBAT_FILE, SILENT_DB)
	_apply_volume()


## Plays one random take of `sound_name`. Does nothing for an unknown name,
## so a unit without a voice can simply be silent.
func play(sound_name: String, pitch_jitter := 0.08) -> void:
	if not _streams.has(sound_name):
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _streams[sound_name].pick_random()
	p.volume_db = SOUNDS[sound_name][1]
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()


## Crossfades to the combat track (true) or back to the exploring track (false).
## Each track starts from the beginning when it fades in.
func set_combat(on: bool) -> void:
	if on == _in_combat:
		return
	_in_combat = on
	var fade_in := _combat if on else _explore
	var fade_out := _explore if on else _combat
	if _fade:
		_fade.kill()
	fade_in.play()
	_fade = create_tween().set_parallel()
	_fade.tween_property(fade_in, "volume_db", MUSIC_DB, CROSSFADE_TIME)
	_fade.tween_property(fade_out, "volume_db", SILENT_DB, CROSSFADE_TIME)
	_fade.chain().tween_callback(fade_out.stop)


func toggle_mute() -> void:
	muted = not muted


func _make_music(file: String, volume_db: float) -> AudioStreamPlayer:
	var stream: AudioStream = load(file).duplicate()
	stream.set("loop", true)  # both AudioStreamOggVorbis and AudioStreamMP3 have it
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, muted or volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))

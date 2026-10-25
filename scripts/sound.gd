## Music and sound effects. Loaded as the autoload "Sound", so any script can
## call Sound.play("door"). Each sound name has a few takes; one is picked at
## random so repeated sounds don't feel mechanical. All files are CC0, see
## audio/CREDITS.md.
extends Node

const SFX_DIR := "res://audio/sfx/"
const MUSIC_FILE := "res://audio/music/dungeon-ambience.ogg"

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
const MUSIC_DB := -14.0
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
var _music: AudioStreamPlayer


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

	var music := (load(MUSIC_FILE) as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
	music.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = music
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_music.play()
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


func toggle_mute() -> void:
	muted = not muted


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, muted or volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))

class_name Soundscape
extends Node

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var phase := 0.0
var pulse := 0.0
var cue := ""
var cue_left := 0.0
var tension := 0.0
var powered := false
var music_level := 0.4
var effects_level := 0.75
const RATE := 22050.0

func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = RATE
	stream.buffer_length = 0.22
	player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback

func event(name: String) -> void:
	cue = name
	match name:
		"pellet": cue_left = 0.045
		"power": cue_left = 0.32
		"ghost": cue_left = 0.22
		"hurt": cue_left = 0.46
		"fruit": cue_left = 0.3
		"clear": cue_left = 0.8
		_: cue_left = 0.12

func _process(delta: float) -> void:
	if playback == null:
		return
	var frames: int = mini(playback.get_frames_available(), 1500)
	for i in frames:
		var dt := 1.0 / RATE
		phase += dt
		pulse += dt
		cue_left = maxf(0.0, cue_left - dt)
		# Original layered synthesizer: quiet minor drones, sparse notes, and rising unease.
		var fundamental := 110.0 if not powered else 146.83
		var drone := sin(phase * TAU * fundamental) * 0.35 + sin(phase * TAU * (fundamental * 1.498)) * 0.2
		var tremolo := 0.75 + 0.25 * sin(phase * (1.3 + tension * 4.0))
		var beat := fmod(pulse, 1.6 - tension * 0.6)
		var note := 0.0
		if beat < 0.15:
			note = sin(phase * TAU * (220.0 if powered else 164.81)) * (1.0 - beat / 0.15) * 0.15
		var music := (drone * tremolo * 0.11 + note) * music_level
		var effect := 0.0
		if cue_left > 0.0:
			match cue:
				"pellet": effect = sin(phase * TAU * 520.0) * cue_left * 3.4
				"power": effect = sin(phase * TAU * (230.0 + cue_left * 300.0)) * cue_left * 0.65
				"ghost": effect = sin(phase * TAU * (360.0 + cue_left * 600.0)) * cue_left * 0.65
				"hurt": effect = (sin(phase * TAU * 75.0) + sin(phase * TAU * 82.0)) * cue_left * 0.65
				"fruit": effect = sin(phase * TAU * (420.0 - cue_left * 340.0)) * cue_left * 0.6
				"clear": effect = sin(phase * TAU * (330.0 + (0.8 - cue_left) * 240.0)) * cue_left * 0.35
		var sample := clampf(music + effect * effects_level, -0.9, 0.9)
		playback.push_frame(Vector2(sample, sample))

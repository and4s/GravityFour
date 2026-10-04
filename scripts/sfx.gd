extends Node

var enabled := true
var volume := 0.65
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0

func _ready() -> void:
	for sound in ["drop", "click", "start", "victory", "defeat", "draw", "connect"]:
		streams[sound] = load("res://audio/" + sound + ".wav")
	for i in 4:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func play(sound: String) -> void:
	if not enabled or volume <= 0.001 or voices.is_empty() or not streams.has(sound):
		return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = streams[sound]
	voice.volume_db = linear_to_db(volume)
	voice.play()

func stop_all() -> void:
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null

func _exit_tree() -> void:
	stop_all()
	streams.clear()

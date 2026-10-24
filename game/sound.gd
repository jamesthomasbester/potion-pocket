extends Node
var muted := false
var ambient: AudioStreamPlayer
var clips: Dictionary = {}

func _ready():
	for kind in ["harvest","brew","stock","sale","dream_sale","upgrade","tap"]:
		clips[kind]=load("res://game/audio/"+kind+".wav")
	ambient=AudioStreamPlayer.new()
	add_child(ambient)
	ambient.stream=preload("res://game/audio/ambience.wav")
	# Replay a finished non-looped imported WAV. Avoid raw PCM loop boundaries.
	ambient.finished.connect(func():
		if not muted: ambient.play())
	ambient.play()

func set_muted(value: bool):
	muted=value
	if ambient:
		if muted: ambient.stop()
		elif not ambient.playing: ambient.play()

func play(kind: String):
	if muted: return
	var player:=AudioStreamPlayer.new()
	add_child(player)
	player.stream=clips.get(kind,clips.get("tap"))
	player.finished.connect(player.queue_free)
	player.play()

func _exit_tree():
	for player in get_children():
		if player is AudioStreamPlayer: player.stop()

# Igor's guitar: press E and he plays the solo. He cannot move while it plays,
# and when it ends he has a thought about it. Level music pauses meanwhile.
extends Area2D

@export var song: AudioStream
@export_multiline var thought_after: String = "Incredible how I still suck at this!"

var interact_priority: int = 10
var _playing: bool = false

@onready var _song_player: AudioStreamPlayer = $SongPlayer
@onready var _bubble: ThoughtBubble = $ThoughtBubble

func _ready():
	add_to_group("interactable")
	_song_player.finished.connect(_on_song_finished)

# Not while already playing, and not mid-jump.
func can_interact_with(player) -> bool:
	return not _playing and player.is_on_floor()

func interact(_player):
	if _playing:
		return
	_playing = true
	Global.block_player_movement("guitar")
	_pause_level_music(true)
	_song_player.stream = song
	_song_player.play()

func is_playing() -> bool:
	return _playing

func _on_song_finished():
	_playing = false
	Global.unblock_player_movement("guitar")
	_pause_level_music(false)
	_bubble.think([thought_after])

func _pause_level_music(paused: bool):
	if Global.main == null:
		return
	Global.main.backgroundMusicPlayer.stream_paused = paused

# Leaving the level mid-song must not leave the player frozen.
func _exit_tree():
	if _playing:
		Global.unblock_player_movement("guitar")

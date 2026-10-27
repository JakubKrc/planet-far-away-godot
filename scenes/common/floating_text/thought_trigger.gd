# Walk into this area and Igor thinks the lines. Plays once unless told otherwise.
extends Area2D

@export_multiline var lines: Array[String] = []
@export var seconds_per_line: float = 3.0
@export var fade_seconds: float = 0.4
@export var once: bool = true
@export var max_width: float = 140.0

# Saved with the level, so a thought that has played stays played after Continue.
var was_used: bool = false

var _bubble: ThoughtBubble

func _ready():
	add_to_group("save")
	body_entered.connect(_on_body_entered)
	_bubble = ThoughtBubble.new()
	_bubble.seconds_per_line = seconds_per_line
	_bubble.fade_seconds = fade_seconds
	_bubble.max_width = max_width
	add_child(_bubble)

func _on_body_entered(body: Node):
	if body != Global.controlled_char:
		return
	if once and was_used:
		return
	if lines.is_empty():
		return
	was_used = true
	play()

func play():
	_bubble.think(lines)

func stop():
	_bubble.stop()

func is_showing() -> bool:
	return _bubble.is_showing()

func current_text() -> String:
	return _bubble.current_text()

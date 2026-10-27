# Igor's thoughts on screen: each line floats above whoever the player controls,
# fades in, stays a while, fades out, then the next one comes. Only one thought is
# on screen at a time. Used by thought triggers, the guitar, and anything else.
class_name ThoughtBubble
extends Node

@export var seconds_per_line: float = 3.0
@export var fade_seconds: float = 0.4
@export var max_width: float = 140.0

var _label: FloatingTextLabel
var _tween: Tween
# Bumped by every think() and stop(); a run that sees it change has been replaced.
var _run: int = 0

func _ready():
	add_to_group("thought_bubble")
	_label = FloatingTextLabel.new()
	_label.setup(max_width)
	_label.modulate.a = 0.0
	_label.visible = false
	add_child(_label)

func think(lines: Array):
	for other in get_tree().get_nodes_in_group("thought_bubble"):
		if other != self:
			other.stop()
	_run += 1
	var this_run = _run
	_label.visible = true
	for line in lines:
		_label.text = line
		await _fade_to(1.0)
		if this_run != _run:
			return
		await get_tree().create_timer(seconds_per_line).timeout
		if this_run != _run:
			return
		await _fade_to(0.0)
		if this_run != _run:
			return
	_hide()

func stop():
	_run += 1
	_hide()

func is_showing() -> bool:
	return _label.visible

func current_text() -> String:
	return _label.text if _label.visible else ""

func _hide():
	if _tween:
		_tween.kill()
	_label.modulate.a = 0.0
	_label.visible = false

func _fade_to(alpha: float):
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", alpha, fade_seconds)
	await _tween.finished

# High enough above the head to clear the "E" interact icon (30 px above things).
func _process(_delta):
	if not _label.visible:
		return
	var character = Global.controlled_char
	if character == null or not is_instance_valid(character):
		return
	_label.place_bottom_centre_at(character.global_position + Vector2(0, -44))

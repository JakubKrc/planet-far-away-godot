# A text that belongs to a spot in the world, The Way style: fully visible when the
# player is close, fading out with distance, gone beyond fade_distance.
extends Node2D

@export_multiline var text: String = ""
@export var visible_distance: float = 24.0
@export var fade_distance: float = 96.0
@export var max_width: float = 120.0

var _label: FloatingTextLabel

func _ready():
	_label = FloatingTextLabel.new()
	_label.setup(max_width)
	_label.text = text
	_label.modulate.a = 0.0
	add_child(_label)

func _process(_delta):
	if _label.text != text:
		_label.text = text
	_label.place_bottom_centre_at(global_position)
	_label.modulate.a = visibility()

# 1 within visible_distance, 0 beyond fade_distance, a straight blend between.
func visibility() -> float:
	var character = Global.controlled_char
	if character == null or not is_instance_valid(character):
		return 0.0
	var distance = character.global_position.distance_to(global_position)
	var fade_range = maxf(fade_distance - visible_distance, 1.0)
	return clampf((fade_distance - distance) / fade_range, 0.0, 1.0)

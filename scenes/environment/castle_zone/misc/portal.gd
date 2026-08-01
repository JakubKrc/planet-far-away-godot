extends Area2D

@export var door_name: String = "portal_1"
@export_file var level_to_load: String = ""
@export var door_to_spam: String = ""
@export var need_to_interact: bool = true
@export var direction_vector: Vector2 = Vector2.RIGHT
@export var interactable: bool = true

var need_to_be_exited_before_activating = false
var interact_priority: int = 0

func _ready():
	if interactable:
		add_to_group("interactable")

# Portals that fire on touch are not interact targets, so no icon appears.
func can_interact_with(_player) -> bool:
	return need_to_interact

func interact(_player):
	Global.main.load_level(level_to_load, door_to_spam)

func _on_body_entered(body):
	if need_to_interact:
		return

	if(body.is_in_group('player') && !need_to_be_exited_before_activating):
		Global.main.load_level(level_to_load, door_to_spam);


func _on_body_exited(body):
	if need_to_interact:
		return

	if(body.is_in_group('player') && need_to_be_exited_before_activating):
		need_to_be_exited_before_activating = false
	

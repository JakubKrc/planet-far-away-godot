extends Node

@export_file("*.json") var dialogue_file: String = ""
@export var add_to_interactable: bool = true
@export var auto_trigger: bool = false

var interact_priority: int = 10

func _ready():
	if add_to_interactable:
		get_parent().add_to_group("interactable")
	get_parent().body_entered.connect(_on_body_entered)

# Talking mid-jump looks wrong, so the icon waits until the player lands.
func can_interact_with(player) -> bool:
	return player.is_on_floor()

func interact(_player):
	Global.dialogue.start(dialogue_file)

func _on_body_entered(body):
	if body.is_in_group("player") and auto_trigger:
		Global.dialogue.start(dialogue_file)

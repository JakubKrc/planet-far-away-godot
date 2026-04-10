extends Node

@export_file("*.json") var dialogue_file: String = ""
@export var add_to_interactable: bool = true
@export var auto_trigger: bool = false

var player_inside: bool = false

func _ready():
	if add_to_interactable:
		get_parent().add_to_group("interactable")
	get_parent().body_entered.connect(_on_body_entered)
	get_parent().body_exited.connect(_on_body_exited)

func _input(event):
	if player_inside and event.is_action_pressed("use") and Global.can_player_move:
		var player = get_tree().get_first_node_in_group("player")
		if player and not player.is_on_floor():
			return
		get_viewport().set_input_as_handled()
		Global.dialogue.start(dialogue_file)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_inside = true
		if auto_trigger:
			Global.dialogue.start(dialogue_file)

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false

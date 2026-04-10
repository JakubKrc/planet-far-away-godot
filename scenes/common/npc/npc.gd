extends Area2D

@export_file("*.json") var dialogue_file: String = ""
@export var interactable: bool = true

var player_inside: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if interactable:
		add_to_group("interactable")

func _input(event):
	if player_inside and event.is_action_pressed("use") and Global.can_player_move:
		Global.dialogue.start(dialogue_file)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false

extends Area2D

@onready var sprite_empty = $Checkpoint
@onready var sprite_full = $CheckpointFull

var player_inside: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var is_active = Global.active_checkpoint_position.distance_to(global_position) < 8.0
	sprite_empty.visible = not is_active
	sprite_full.visible = is_active

func _input(event):
	if player_inside and event.is_action_pressed("use") and Global.can_player_move:
		Global.save_game(Global.controlled_char.global_position, global_position)
		print("Checkpoint saved at ", global_position)
		sprite_empty.visible = false
		sprite_full.visible = true

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_inside = true

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_inside = false

extends Area2D

@onready var sprite_empty = $Checkpoint
@onready var sprite_full = $CheckpointFull

var interact_priority: int = 10

func _ready():
	var is_active = Global.active_checkpoint_position.distance_to(global_position) < 8.0
	sprite_empty.visible = not is_active
	sprite_full.visible = is_active

func interact(player):
	Global.save_game(player.global_position, global_position)
	sprite_empty.visible = false
	sprite_full.visible = true

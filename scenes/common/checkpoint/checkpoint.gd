extends Area2D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		Global.save_game(body.global_position)
		print("Checkpoint saved at ", body.global_position)

extends Node
class_name idle

@onready var parent = get_parent()

func idle():
	pass
	
func _on_direction_change_timer_timeout():
	$"../DirectionTimer".wait_time = 3 + randi()%5
	if Global.controlled_char == parent:
		return
	if parent.get_component(Sight).target_position == Vector2.ZERO:
		parent.direction = Vector2.RIGHT if randi() % 2 == 0 else Vector2.LEFT
		parent.get_component(Sight).set_raycast_direction()
		parent.velocity.x = 0
 

extends Node

@onready var parent = get_parent()

func fall():
		
	if not parent.is_on_floor():
		return

	var collision = parent.get_last_slide_collision()
	if collision == null:
		return

	var collider = collision.get_collider()
	print(collider)
	if not collider.is_in_group("fall_through_platform"):
		return

	parent.set_collision_mask_value(1, false)
	parent.velocity.y = 50

	await parent.get_tree().create_timer(0.15).timeout
	parent.set_collision_mask_value(1, true)

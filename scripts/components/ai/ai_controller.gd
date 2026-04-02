extends Node
class_name AIController

@onready var parent = get_parent()

func _physics_process(_delta):
	if Global.controlled_char == parent or parent.components.get("State").state == Global.States.DEATH:
		return
		
	if(parent.components.get("Sight").can_see_target_around(75)):
		parent.components.get("Sight").target_position.x = parent.components.get("Sight").target_node.global_position.x
	
	if parent.components.get("Sight").target_position == Vector2.ZERO:
		if (!parent.components.get("Sight").is_near_wall() and !parent.components.get("Sight").is_near_group("simple_robot",20) and !parent.components.get("Sight").is_near_edge()):
			parent.components.get("MovexControlled").move({'x_axis_input':parent.direction.normalized().x})
		else:
			parent.velocity.x = -parent.velocity.x
			parent.direction.x = -parent.direction.x
			parent.components.get("Sight").set_raycast_direction()
	
	if parent.components.get("Sight").can_see_target():
		if (!parent.components.get("Sight").is_near_wall() and !parent.components.get("Sight").is_near_edge()):
			var how_far_from_target=parent.components.get("Sight").target_position - parent.global_position
			if abs(how_far_from_target.x)>40:
				parent.components.get("MovexControlled").move({'x_axis_input':(how_far_from_target).normalized().x})
			else:
				parent.components.get("MovexControlled").stop_moving()
		else:
			parent.components.get("MovexControlled").stop_moving()
		parent.components.get("Shoot").attack()

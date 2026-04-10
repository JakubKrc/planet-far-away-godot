extends Node
class_name AIController

@onready var parent = get_parent()

func _physics_process(_delta):
	if Global.controlled_char == parent or parent.get_component(State).state == Global.States.DEATH:
		return
		
	if(parent.get_component(Sight).can_see_target_around(75)):
		parent.get_component(Sight).target_position.x = parent.get_component(Sight).target_node.global_position.x
	
	if parent.get_component(Sight).target_position == Vector2.ZERO:
		if (!parent.get_component(Sight).is_near_wall() and !parent.get_component(Sight).is_near_group("simple_robot",20) and !parent.get_component(Sight).is_near_edge()):
			parent.get_component(MovexControlled).move({'x_axis_input':parent.direction.normalized().x})
		else:
			parent.velocity.x = -parent.velocity.x
			parent.direction.x = -parent.direction.x
			parent.get_component(Sight).set_raycast_direction()
	
	if parent.get_component(Sight).can_see_target():
		if (!parent.get_component(Sight).is_near_wall() and !parent.get_component(Sight).is_near_edge()):
			var how_far_from_target=parent.get_component(Sight).target_position - parent.global_position
			if abs(how_far_from_target.x)>40:
				parent.get_component(MovexControlled).move({'x_axis_input':(how_far_from_target).normalized().x})
			else:
				parent.get_component(MovexControlled).stop_moving()
		else:
			parent.get_component(MovexControlled).stop_moving()
		parent.get_component(Shoot).attack()

extends Node
class_name Sight

@onready var parent = get_parent()

@onready var rayCastSight = $"../RayCastSight"
@onready var rayCastEdges = $"../RayCastEdges"

@onready var forget_target_timer  = $"../ForgetTargetTimer"

var target_position : Vector2 = Vector2.ZERO
var target_node : Node = null
func can_see_target():

	if rayCastSight.is_colliding():
		var collider = rayCastSight.get_collider()
		if collider.is_in_group('player') and !collider.is_in_group('simple_robot'):
			target_node = collider
			target_position = rayCastSight.get_collision_point()
			forget_target_timer.start()
			return true
	
	if !forget_target_timer.is_stopped():
		return true
	else:
		target_position = Vector2.ZERO
		target_node = null
		
	return false

func is_near_wall():
	if rayCastSight.is_colliding():
		if rayCastSight.get_collider().is_in_group('world'):
			if rayCastSight.global_position.distance_to(rayCastSight.get_collision_point())<=50:
				return true
		
	return false
	
func is_near_group(group:String, how_far:int):
	if rayCastSight.is_colliding():
		if rayCastSight.get_collider().is_in_group(group):
			if rayCastSight.global_position.distance_to(rayCastSight.get_collision_point())<=how_far:
				return true
		
	return false

func is_near_edge():
	if rayCastEdges.is_colliding():
		if rayCastEdges.get_collider().is_in_group('world'):
			return false
			
	return true

func set_raycast_direction():
	if parent.direction!=Vector2.ZERO:
		rayCastSight.target_position.x = (parent.direction.normalized() * abs(rayCastSight.target_position.x)).x
		rayCastEdges.target_position.x = (parent.direction.normalized() * abs(rayCastEdges.target_position.x)).x

func can_see_target_around(how_far: int) -> bool:
		
	if target_node==null:
		return false
		
	if parent.global_position.distance_to(target_node.global_position) > how_far:
		return false
				
	var space_state := get_viewport().get_world_2d().direct_space_state

	var query := PhysicsRayQueryParameters2D.create(
		parent.global_position,
		target_node.global_position
	)

	query.exclude = [self]
	query.collision_mask = Global.CollisionLayer.WORLD | Global.CollisionLayer.PLAYER

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return false

	return result.collider == target_node

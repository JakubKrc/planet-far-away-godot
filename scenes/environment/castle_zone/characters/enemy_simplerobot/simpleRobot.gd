extends CharacterBody2D

class_name simpleRobot

@onready var state = $State
@onready var shoot = $shoot

@onready var rayCastSight = $RayCastSight
@onready var rayCastEdges = $RayCastEdges
@onready var player = get_tree().get_first_node_in_group('player')

var speed = 1200
var is_robot_chase: bool = false

var healt = 80
var health_max = 80
var health_min = 0
var dead: bool = false
var taking_damage:bool = false
var damage_to_deal = 20
var is_dealing_damage: bool = false

var direction: Vector2 = Vector2.LEFT : set = _set_direction,  get = _get_direction
var _direction: Vector2 = Vector2.LEFT
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var knockback_force = -20
var is_roaming: bool = true

var player_in_area = false

func _ready():
	pass
	#self.current_state = 0#States.IDLE

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.x = 0
	ai(delta)
	collisions()
	shoot.shoot()
	handle_animation()
	move_and_slide()
	
func collisions():
	if !rayCastEdges.is_colliding() and !is_robot_chase:
		direction = direction.normalized() * -1
		velocity.x=0
		return
		
	if rayCastSight.is_colliding():
		
		if rayCastSight.get_collider().is_in_group('player'):
			is_robot_chase = true
			state.current_state = Global.States.CHASING
			$CanSeePlayerTimer.stop()
			return
		if rayCastSight.get_collider().is_in_group('world'):
			if rayCastSight.global_position.distance_to(rayCastSight.get_collision_point())<=50:
				direction = direction.normalized() * -1
				velocity.x=0
				return
		
	if is_robot_chase and $CanSeePlayerTimer.is_stopped():
		$CanSeePlayerTimer.start()
	
func ai(delta):
	if !dead:
		if !is_robot_chase:
			#velocity += direction * speed * delta
			velocity = direction * speed * delta
		elif is_robot_chase and !taking_damage:
			var dir_x = sign(position.direction_to(player.position).normalized()).x
			if abs(dir_x) > 0.1:
				direction.x = dir_x
			#else:
				#direction.x = 0 
			if !rayCastEdges.is_colliding():
				velocity.x = 0
			else:
				#velocity.x = direction.x * speed * delta
				velocity = direction * speed * delta
		elif taking_damage:
			var knockback_dir = position.direction_to(player.position) * knockback_force
			velocity.x = knockback_dir.x
		is_roaming = true
	else:
		velocity.x = 0
		
func handle_animation():
	var anim_sprite = $AnimatedSprite2D
	if !dead and !taking_damage and !is_dealing_damage:
		anim_sprite.play('walk')
		if direction.x == -1:
			anim_sprite.flip_h = true
		elif direction.x == 1:
			anim_sprite.flip_h = false
	elif !dead and taking_damage and !is_dealing_damage:
		anim_sprite.play('hurt')
	elif dead and is_roaming:
		is_roaming = false
		anim_sprite.play('death')
		
func _set_direction(_value: Vector2):
	_direction = _value;
	rayCastSight.target_position = direction.normalized() * abs(rayCastSight.target_position.x)
	rayCastEdges.target_position.x = (direction.normalized() * abs(rayCastEdges.target_position.x)).x
	
func _get_direction() -> Vector2:
	return _direction;
		
func _on_direction_change_timer_timeout():
	$DirectionTimer.wait_time = 3 + randi()%5
	if !is_robot_chase:
		direction = Vector2.RIGHT if randi() % 2 == 0 else Vector2.LEFT
		velocity.x = 0

func _on_animated_sprite_2d_animation_finished(anim_name):
	print("animacia sa skoncila",anim_name)
	if anim_name == 'hurt':
		taking_damage =false
	if anim_name == 'death':
		set_physics_process(false) 


func _on_can_see_player_timer_timeout():
	is_robot_chase = false

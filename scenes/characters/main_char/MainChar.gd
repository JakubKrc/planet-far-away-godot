extends CharacterBody2D


@export var SPEED = 120.0
@export var JUMP_VELOCITY = -300.0
@export var FRAMES_TO_REMEMBER_GROUND = 6

@onready var player = $AnimationPlayer
@onready var healthbar = $CanvasLayer/HealthBar
@onready var camera = $Camera2D

var health = 100 : set = _set_health	

func _set_health(new_health):
	
	if new_health <= 0:
		die()
	
	health = new_health
	healthbar.health = health
	
var direction = "right"
var isRigid = false

var timer

var wasOnGround = []

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	healthbar.init_health(health)
	timer = Timer.new()
	add_child(timer)
	timer.connect("timeout", Callable(self,"_on_timer_timeout_play_idle"))
	
func _on_timer_timeout_play_idle():
	if (velocity.x == 0 and is_on_floor()):
		player.play("idle")
		
func setDefaultSprite():
	if (direction == "right"):
			player.play("walk_right")
	else:
		player.play("walk_left")
					
	player.stop()
	
func get_gravity2(velocity_player: Vector2):
	if velocity_player.y<=0:
		return gravity
	else:
		return gravity * 1.5
		
func addToWasOnGround(whatToAdd):
	if wasOnGround.size() >= FRAMES_TO_REMEMBER_GROUND:
		wasOnGround.pop_front()
	wasOnGround.append(whatToAdd)

func _physics_process(delta):
	
	if not is_on_floor():
		velocity.y += get_gravity2(velocity) * delta
		addToWasOnGround(false)
	else:
		addToWasOnGround(true)

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and true in wasOnGround:
		setDefaultSprite()
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y = JUMP_VELOCITY / 4

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var immediateDirection = Input.get_axis("ui_left", "ui_right")
	if immediateDirection:
		isRigid = false
		velocity.x = immediateDirection * SPEED
		if immediateDirection==1:
			player.play("walk_right")
			direction = "right"
		if immediateDirection==-1:
			player.play("walk_left")
			direction = "left"
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED/2)
		
		if (velocity.x == 0):
			if (isRigid == false):
				isRigid=true
				timer.wait_time = 3 + randi()%5 
				timer.start()
				setDefaultSprite()				

	move_and_slide()
	
func die():
	Global.death_menu.visible = true
	Global.game_state = Global.GameState.GAME_OVER
	get_tree().paused = true

func _on_animation_player_animation_finished(anim_name):
	if(anim_name == "idle"):
		isRigid = false

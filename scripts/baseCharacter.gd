extends CharacterBody2D

@onready var animation_player = $AnimationPlayer
@onready var state = $State
@onready var falling = $Falling

var health = 100 : set = _set_health	
func _set_health(new_health):
	
	health = new_health
	
	if new_health <= 0:
		Global.call_method_on_target(components, 'die')
	
var components = []
func _ready():
	components = get_tree().get_nodes_in_group('component')
	if Global.isTest == true:
		$"TestStatus".visible = true

func _physics_process(delta):
	
	if (Global.is_method_on_target(components, 'idle')):
		Global.call_method_on_target(components, 'idle', {'delta':delta} )
	if (Global.is_method_on_target(components, 'falling_and_floor_memory')):
		Global.call_method_on_target(components, 'falling_and_floor_memory', {'delta':delta} )
	move_and_slide()

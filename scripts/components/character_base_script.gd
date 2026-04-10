class_name CharacterBase
extends CharacterBody2D

@onready var animation_player = $AnimationPlayer
@onready var interact_area: Area2D = $InteractArea

@export var health = 100 : set = _set_health
@export var max_health = 100

var direction : Vector2 = Vector2.ZERO

var can_interact := false

func _set_health(new_health):
	
	health = new_health
	
	if new_health <= 0:
		Global.call_method_on_target(components, 'die')
		
	if health>max_health:
		health=max_health
	
var home_level: String = ""
var is_default_char: bool = false

var components = {}
func _ready():
	for c in get_children():
		if c.is_in_group("component"):
			components[c.get_script()] = c
	if Global.isTest == true:
		$"TestStatus".visible = true

func _physics_process(delta):
	
	move_and_slide()
		
	if Global.controlled_char != self:
		return
	
	if (Global.is_method_on_target(components, 'idle_anim')):
		Global.call_method_on_target(components, 'idle_anim', {'delta':delta} )
	if (Global.is_method_on_target(components, 'falling_and_floor_memory')):
		Global.call_method_on_target(components, 'falling_and_floor_memory', {'delta':delta} )

	can_interact = false
	
	for area in interact_area.get_overlapping_areas():
		if area.is_in_group("interactable") && !area.is_in_group("dont_interact"):
			can_interact = true
			Global.main.interact_icon.get_node("Icon").position = area.global_position - Vector2(0, 30)
			break
			
	Global.main.interact_icon.get_node("Icon").visible = can_interact

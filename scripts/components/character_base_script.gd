class_name CharacterBase
extends CharacterBody2D

@onready var animation_player = $AnimationPlayer
@onready var interact_area: Area2D = $InteractArea

@export var health = 100 : set = _set_health
@export var max_health = 100
@export var starting_items: Array[ItemData] = []

var direction : Vector2 = Vector2.ZERO

var can_interact := false

func _set_health(new_health):
	
	health = new_health
	
	if new_health <= 0:
		do('die')
		
	if health>max_health:
		health=max_health
	
var home_level: String = ""
var is_default_char: bool = false

var components = {}
var method_cache: Dictionary = {}  # method_name -> [component, ...]

func _ready():
	for c in get_children():
		if c.is_in_group("component"):
			components[c.get_script()] = c
	_build_method_cache()
	if starting_items.size() > 0:
		var inv = get_node_or_null("InventoryComponent") as InventoryComponent
		if inv:
			for item in starting_items:
				if item:
					var pos = inv.find_free_slot(item)
					if pos != Vector2i(-1, -1):
						inv.place(item, pos)
	if Global.isTest == true:
		$"TestStatus".visible = true

func _build_method_cache():
	method_cache.clear()
	for c in components.values():
		var script = c.get_script()
		while script != null:
			for method in script.get_script_method_list():
				var mn: String = method["name"]
				if not method_cache.has(mn):
					method_cache[mn] = []
				if not method_cache[mn].has(c):
					method_cache[mn].append(c)
			script = script.get_base_script()

func can_do(method_name: String) -> bool:
	return method_cache.has(method_name)

func do(method_name: String, params: Dictionary = {}):
	for c in method_cache.get(method_name, []):
		if params.is_empty():
			c.call(method_name)
		else:
			c.call(method_name, params)

func get_component(cls) -> Node:
	var c = components.get(cls)
	if c == null:
		push_error("%s: missing component %s" % [name, cls])
	return c

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

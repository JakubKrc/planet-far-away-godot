class_name CharacterBase
extends CharacterBody2D

@onready var animation_player = $AnimationPlayer
@onready var interact_area: Area2D = $InteractArea

@export var health = 100 : set = _set_health
@export var max_health = 100

var direction : Vector2 = Vector2.ZERO

var can_interact := false

# The one thing a `use` press acts on. Interactables no longer listen for input
# themselves — several of them used to overlap and all fire at once, in an order
# decided by the scene tree. Now the character picks a single target and the
# interact icon points at exactly the node that will respond.
var interact_target: Node = null
var _interact_anchor: Node2D = null

func _set_health(new_health):
	var was_alive: bool = health > 0
	# Test helper: the player shrugs off damage but can still be healed, so combat
	# stops derailing runs that are really testing saves or possession.
	if Global.test_invulnerable and int(new_health) < health and is_in_group("player"):
		return
	# Clamp before reacting: health used to be stored raw, so it drifted negative
	# and the max_health cap was applied after die() had already run.
	health = clampi(int(new_health), 0, int(max_health))
	# Only on the transition, or every further hit would re-trigger the death
	# animation and menu.
	if health == 0 and was_alive:
		do('die')

# Stable identity, unique across the whole game. Node names are NOT unique —
# rooms 1, 4 and 7 each contain a node called "PlayableRobot" — and using the
# name as identity let a character carried into a room delete the one already
# living there, taking its inventory with it.
@export var character_id: String = ""

# True when this character is the one its level hands you on arrival, false when
# you are wearing it through possession. Switches read it to decide whether to
# show their "possessed" animation. Nothing to do with being the main character —
# any level's declared character sets this.
var is_level_default_character: bool = false

var components = {}
var method_cache: Dictionary = {}  # method_name -> [component, ...]

func _ready():
	for c in get_children():
		if c.is_in_group("component"):
			components[c.get_script()] = c
	_build_method_cache()
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

# Read by godot-mcp's runtime-state digest. Identifies characters by scene path
# rather than node name: possession reparents characters into /root/main, where a
# name collision silently renames one to "@CharacterBody2D@40", and counting by
# name then misses the duplicate entirely.
func _mcp_state() -> Dictionary:
	var state = {
		"scene": scene_file_path,
		"character_id": character_id,
		"node_name": str(name),
		"health": health,
		"max_health": max_health,
		"is_controlled": Global.controlled_char == self,
		"is_player": is_in_group("player"),
		"roster_level": Global.character_level(character_id),
		"position": [global_position.x, global_position.y],
		"on_floor": is_on_floor(),
		"interact_target": str(interact_target.name) if interact_target != null else "",
	}
	var state_component := get_node_or_null("State") as State
	if state_component != null:
		state["state"] = Global.States.keys()[state_component.state]
	var inventory := get_node_or_null("InventoryComponent") as InventoryComponent
	if inventory != null:
		var carried = []
		for item in inventory.all_items():
			carried.append(item.id)
		state["inventory"] = carried
	return state

func do(method_name: String, params: Dictionary = {}):
	for c in method_cache.get(method_name, []):
		if params.is_empty():
			c.call(method_name)
		else:
			c.call(method_name, params)

# Picks the interactable to act on: highest interact_priority wins, nearest wins
# ties. Anything that declines via can_interact_with() is skipped, so the icon
# never appears over something that would do nothing.
func _update_interact_target():
	interact_target = null
	_interact_anchor = null
	var best_priority := -1
	var best_distance := INF

	for area in interact_area.get_overlapping_areas():
		if not area.is_in_group("interactable") or area.is_in_group("dont_interact"):
			continue
		var handler = _interact_handler(area)
		if handler == null:
			continue
		if handler.has_method("can_interact_with") and not handler.can_interact_with(self):
			continue
		var priority: int = handler.interact_priority if "interact_priority" in handler else 0
		var distance := global_position.distance_squared_to(area.global_position)
		if priority < best_priority:
			continue
		if priority == best_priority and distance >= best_distance:
			continue
		best_priority = priority
		best_distance = distance
		interact_target = handler
		_interact_anchor = area

	can_interact = interact_target != null
	var icon = Global.main.interact_icon.get_node("Icon")
	icon.visible = can_interact
	if _interact_anchor != null:
		icon.position = _interact_anchor.global_position - Vector2(0, 30)

# The node implementing interact(). The "interactable" group sits on the Area2D,
# which depending on the scene is the script's own node, its parent (switches) or
# its child (dialogue triggers).
func _interact_handler(area: Area2D) -> Node:
	if area.has_method("interact"):
		return area
	var parent = area.get_parent()
	if parent != null and parent.has_method("interact"):
		return parent
	for child in area.get_children():
		if child.has_method("interact"):
			return child
	return null

func _unhandled_input(event: InputEvent):
	if Global.controlled_char != self or not Global.can_player_move:
		return
	if not event.is_action_pressed("use") or interact_target == null:
		return
	get_viewport().set_input_as_handled()
	interact_target.interact(self)

func get_component(cls) -> Node:
	var c = components.get(cls)
	if c == null:
		push_error("%s: missing component %s" % [name, cls])
	return c

func _physics_process(delta):
	
	move_and_slide()
		
	if Global.controlled_char != self:
		return
	
	# do() is a no-op when no component implements the method, so characters
	# without these components need no guard here.
	do('idle_anim', {'delta': delta})
	do('falling_and_floor_memory', {'delta': delta})

	_update_interact_target()

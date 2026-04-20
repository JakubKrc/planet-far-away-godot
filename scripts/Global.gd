extends Node

var G_STAT_TestLabel
var isTest = false

signal level_transition_started
signal level_transition_finished

enum GameState {
	MAIN_MENU, 
	PLAYING, 
	PAUSE_MENU, 
	GAME_OVER,
}
const game_state_names = ['MAIN_MENU','PLAYING','PAUSE_MENU','GAME_OVER']

enum States {
	IDLE,
	MOVING_RIGHT,
	MOVING_LEFT,
	JUMPING,
	FALLING,
	SHOOTING,
	CHASING,
	FLYING,
	DEATH,
}
const states_names = ['IDLE','MOVING_RIGHT','MOVING_LEFT','JUMPING','FALLING','SHOOTING','CHASING','FLYING','DEATH']
	
enum BehaviorStates {
	IDLE,
	CHASE,
}
const behavior_states_names = ['IDLE','CHASE']

enum ActionStates {
	ATTACK,
}
const action_states_names = ['ATTACK']

enum CollisionLayer {
	WORLD = 1,
	PLAYER = 2,
	PORTAL = 3,
	ENEMY = 4,
	DECORATION = 5,
}
	
var main
var game_state = GameState.MAIN_MENU :
	set (value):
		game_state = value
		if G_STAT_TestLabel != null:
			G_STAT_TestLabel.text = game_state_names[game_state]
	get:
		return game_state
var main_menu
var pause_menu
var death_menu
var camera
var can_player_move = true

var controlled_char : Node
var current_level : String

var per_level_save : Dictionary
var active_checkpoint_position: Vector2 = Vector2(INF, INF)

var inventory: Dictionary = {}
var dialogue
var inventory_ui

var _saved_inventory_data: Array = []
var _saved_equipment_data: Array = []

const SAVE_PATH = "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(spawn_position: Vector2, checkpoint_position: Vector2 = Vector2(INF, INF)):
	active_checkpoint_position = checkpoint_position if checkpoint_position != Vector2(INF, INF) else spawn_position
	var char_home_level := ""
	if controlled_char != null and "home_level" in controlled_char:
		char_home_level = str(controlled_char.home_level)
	var inv_data = []
	var equip_data = []
	if controlled_char != null:
		var inv_comp = controlled_char.get_node_or_null("InventoryComponent")
		if inv_comp:
			inv_data = inv_comp.serialize()
		var eq_comp = controlled_char.get_node_or_null("EquipmentComponent")
		if eq_comp:
			equip_data = eq_comp.serialize()
	var data = {
		"current_level": current_level,
		"spawn_position": [spawn_position.x, spawn_position.y],
		"checkpoint_position": [active_checkpoint_position.x, active_checkpoint_position.y],
		"possessed_char_name": str(controlled_char.name) if controlled_char != null else "",
		"possessed_char_home_level": char_home_level,
		"per_level_save": _serialize_save(per_level_save),
		"inventory": inventory,
		"inventory_component": inv_data,
		"equipment_component": equip_data,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("Module['FS'].syncfs(false, function(err) {})")

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	if result == null:
		return {}
	per_level_save = _deserialize_save(result.get("per_level_save", {}))
	var cp = result.get("checkpoint_position", null)
	if cp != null:
		active_checkpoint_position = Vector2(cp[0], cp[1])
	var raw_inv = result.get("inventory", {})
	inventory = {}
	for key in raw_inv:
		inventory[key] = int(raw_inv[key])
	# Stash component data; applied in apply_inventory_save() after char is in scene
	_saved_inventory_data  = result.get("inventory_component", [])
	_saved_equipment_data  = result.get("equipment_component", [])
	return result

func apply_inventory_save():
	if controlled_char == null:
		return
	var inv_comp = controlled_char.get_node_or_null("InventoryComponent")
	if inv_comp and _saved_inventory_data.size() > 0:
		inv_comp.deserialize(_saved_inventory_data)
		_saved_inventory_data = []
	var eq_comp = controlled_char.get_node_or_null("EquipmentComponent")
	if eq_comp and _saved_equipment_data.size() > 0:
		eq_comp.deserialize(_saved_equipment_data)
		_saved_equipment_data = []

func notify(text: String, duration: float = 2.5):
	if main:
		main.notify(text, duration)

func inv_add(id: String, amount: int = 1):
	inventory[id] = inventory.get(id, 0) + amount
	print("[INV] +%d %s  (total: %d)" % [amount, id, inventory[id]])

func inv_remove(id: String, amount: int = 1):
	inventory[id] = max(0, inventory.get(id, 0) - amount)
	print("[INV] -%d %s  (total: %d)" % [amount, id, inventory[id]])
	if inventory[id] == 0:
		inventory.erase(id)

func inv_has(id: String, amount: int = 1) -> bool:
	return inventory.get(id, 0) >= amount

func _serialize_save(dict: Dictionary) -> Dictionary:
	var out = {}
	for level in dict:
		out[level] = {}
		for node_name in dict[level]:
			var d: Dictionary = dict[level][node_name].duplicate()
			if d.has("position"):
				d["position"] = [d["position"].x, d["position"].y]
			out[level][node_name] = d
	return out

func _deserialize_save(dict: Dictionary) -> Dictionary:
	var out = {}
	for level in dict:
		out[level] = {}
		for node_name in dict[level]:
			var d: Dictionary = dict[level][node_name].duplicate()
			if d.has("position"):
				var p = d["position"]
				d["position"] = Vector2(p[0], p[1])
			out[level][node_name] = d
	return out

func _ready():
	level_transition_started.connect(_on_transition_started)
	level_transition_finished.connect(_on_transition_finished)

func _on_transition_started():
	can_player_move = false

func _on_transition_finished():
	can_player_move = true

func _process(_delta):
	handle_ingame_input()

func handle_ingame_input():

	if (controlled_char == null):
		return

	if (!can_player_move):
		controlled_char.velocity = Vector2.ZERO
		controlled_char.animation_player.stop()
		return

	if controlled_char.can_do('jump'):
		if Input.is_action_just_pressed("jump"):
			controlled_char.do('jump')
		if Input.is_action_just_released("jump"):
			controlled_char.do('stop_jump')

	if controlled_char.can_do('move'):
		var x_axis_input = Input.get_axis("left", "right")
		if x_axis_input != 0:
			controlled_char.do('move', {'x_axis_input': x_axis_input})
		else:
			controlled_char.do('stop_moving')

	if controlled_char.can_do('fall'):
		if Input.is_action_just_pressed("down"):
			controlled_char.do('fall')

	if controlled_char.can_do('attack'):
		if Input.is_action_pressed("attack"):
			controlled_char.do('attack')
	
func call_method_on_target(components, method_name, params: Dictionary = {}):
	var has_component:bool = false
	for component in components.values():
		if component.has_method(method_name):
			has_component = true
			if params.is_empty():
				component.call(method_name)
			else:
				component.call(method_name, params)
	if !has_component:
		push_error('Component dont have method %s' % method_name)
			
func is_method_on_target(components: Dictionary, method_name: String) -> bool:
	for component in components.values():
		if component.has_method(method_name):
			return true
		
	return false

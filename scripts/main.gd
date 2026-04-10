extends Node2D

@onready var main2D = $main2D
@onready var spawn = $Spawn
@onready var OStestLabel = $CanvasLayerForTestLabel/OSTestLabel
@onready var backgroundMusicPlayer = $AudioManager/BackgroundMusicPlayer
@onready var interact_icon = $InteractIcon

var level_instance = null
const GROUND_ITEM_SCENE = preload("res://scenes/common/items/ground_item.tscn")

func _ready():
	Global.main = self
	$InventoryUI.item_thrown.connect(_on_item_thrown)
	if Global.isTest==true:
		OStestLabel.visible = true
		OStestLabel.text = OS.get_name()
		Global.G_STAT_TestLabel = $CanvasLayerForTestLabel/G_STAT_TestLabel
		Global.G_STAT_TestLabel.visible = true
		Global.G_STAT_TestLabel.text = Global.game_state_names[Global.game_state]

func _on_item_thrown(item: ItemData, world_pos: Vector2):
	var gi = GROUND_ITEM_SCENE.instantiate()
	gi.item = item
	gi.position = world_pos
	main2D.add_child(gi)

func _process(_delta):
	if Input.is_action_just_pressed("escape")  or Input.is_action_just_pressed("pause"):
		if Global.game_state == Global.GameState.MAIN_MENU:
			return;
		if Input.is_key_pressed(KEY_ESCAPE) and OS.get_name() == "Web":
			return;
		await get_tree().process_frame;
		Global.pause_menu.selection = 0;
		Global.pause_menu.show();
		Global.game_state = Global.GameState.PAUSE_MENU
		get_tree().paused = true;
	
func load_mainchar(where_to_set_character: Vector2, direction_vector: Vector2):
	var character = get_tree().get_first_node_in_group("player")
	if character == null:
		return
	Global.controlled_char = character
	enable_node(character)
	character.global_position = where_to_set_character
	character.velocity = direction_vector
	Global.camera.position_smoothing_enabled = false
	Global.camera.global_position = where_to_set_character
	await get_tree().process_frame
	Global.camera.position_smoothing_enabled = true
	Global.apply_inventory_save()

func load_level(level_path : String, door_name : String, fadeIn: float = 1, fadeOut: float = 1, initial_possess_group: String = "", spawn_override: Vector2 = Vector2.ZERO):
	# Normalize UID paths to file paths so keys are consistent
	if level_path.begins_with("uid://"):
		var uid_int = ResourceUID.text_to_id(level_path)
		if ResourceUID.has_id(uid_int):
			level_path = ResourceUID.get_id_path(uid_int)

	if level_path=='':
		return

	if not ResourceLoader.exists(level_path):
		push_error("Level %s dont exist." % level_path)
		return
		
	save_current_level()
						
	Global.level_transition_started.emit()
	
	var didFadeInTransitionHappened = TransitionScreen.transition(fadeIn, fadeOut)
	if didFadeInTransitionHappened:
		await TransitionScreen.on_transition_finished
		
	Global.level_transition_finished.emit()
		
	var level_resource := load(level_path)
	if (level_resource):
		unload_level()
		level_instance = level_resource.instantiate()
		main2D.call_deferred("add_child",level_instance)
		await get_tree().process_frame
				
	Global.current_level = level_path
	for node in get_tree().get_nodes_in_group("save"):
		if str(node.get_path()).contains("/main2D/") and "home_level" in node:
			node.home_level = level_path

	if initial_possess_group != "":
		var char_to_possess = get_tree().get_first_node_in_group(initial_possess_group)
		# Fallback: find by node name in the save group (in case char isn't in a named group)
		if char_to_possess == null:
			for node in get_tree().get_nodes_in_group("save"):
				if str(node.name) == initial_possess_group:
					char_to_possess = node
					break
		if char_to_possess:
			if not "is_default_char" in char_to_possess:
				push_error("load_level: found '%s' for group '%s' but it is not a character (type: %s). Check the scene — InventoryComponent/EquipmentComponent children must be plain Node, not CharacterBody2D." % [char_to_possess.name, initial_possess_group, char_to_possess.get_class()])
				char_to_possess = null
			else:
				char_to_possess.add_to_group("player")
				char_to_possess.is_default_char = true
				Global.controlled_char = char_to_possess
				char_to_possess.get_parent().remove_child(char_to_possess)
				add_child(char_to_possess)

	restore_current_level()

	var levelMusic = get_tree().get_nodes_in_group('backgroundmusic')
	if levelMusic.size() == 0:
		backgroundMusicPlayer.playMusic(null, 0)
	else:
		backgroundMusicPlayer.playMusic(levelMusic[0].song, 0)

	var spawn_position := spawn_override
	if spawn_position == Vector2.ZERO:
		var print_warning: bool = true
		for door in get_tree().get_nodes_in_group("door"):
			if door.door_name == door_name:
				door.need_to_be_exited_before_activating = true
				spawn_position = door.global_position
				print_warning = false
				break
		if print_warning:
			print("Portal %s are not in the level %s" % [door_name, level_path])

	await load_mainchar(spawn_position, Vector2.ZERO)
	
func save_current_level():
	var level_path = Global.current_level
	if level_path == "":
		return

	# Save all alive ground items (dynamic + scene-placed)
	var ground_items_data: Array = []
	for node in get_tree().get_nodes_in_group("ground_item"):
		if node.item and node.item.resource_path != "":
			ground_items_data.append({"path": node.item.resource_path, "pos": [node.global_position.x, node.global_position.y]})
	if not Global.per_level_save.has(level_path):
		Global.per_level_save[level_path] = {}
	Global.per_level_save[level_path]["__ground_items__"] = ground_items_data

	for node in get_tree().get_nodes_in_group("save"):
		if node.is_in_group("player"):
			continue

		var node_path = str(node.get_path())
		var target_level: String

		if node_path.contains("/main2D/"):
			target_level = level_path
		elif "home_level" in node and node.home_level != "":
			target_level = node.home_level
		else:
			continue

		if not Global.per_level_save.has(target_level):
			Global.per_level_save[target_level] = {}

		var data = {"position": node.global_position, "disabled": !node.visible}
		if "health" in node:         data["health"]         = node.health
		if "switch_state" in node:   data["switch_state"]   = node.switch_state
		if "was_used" in node:       data["was_used"]       = node.was_used
		if "activated" in node:      data["activated"]      = node.activated
		if "current_index" in node:  data["current_index"]  = node.current_index

		Global.per_level_save[target_level][node.name] = data
	
func restore_current_level():
	var level_path = Global.current_level

	# Free fresh-scene duplicates of characters already at /root/main/
	for node in get_tree().get_nodes_in_group("save"):
		if not str(node.get_path()).contains("/main2D/"):
			continue
		if not ("home_level" in node):
			continue
		if get_node_or_null("/root/main/" + node.name) != null:
			node.remove_from_group("player")
			node.get_parent().remove_child(node)
			node.queue_free()

	var level_data = Global.per_level_save.get(level_path, {})

	# Restore level-local nodes (enemies, switches, platforms)
	if not level_data.is_empty():
		for node in get_tree().get_nodes_in_group("save"):
			if node.is_in_group("player") or not node.is_inside_tree():
				continue
			if not str(node.get_path()).contains("/main2D/"):
				continue
			if not level_data.has(node.name):
				continue
			var data = level_data[node.name]
			if data["disabled"]:
				disable_node(node)
			else:
				enable_node(node)
				node.global_position = data["position"]
				if data.has("health"):       node.health      = data["health"]
				if data.has("switch_state"):
					node.switch_state = data["switch_state"]
					if node.has_method("which_anim_to_play"): node.which_anim_to_play()
				if data.has("was_used"):      node.was_used      = data["was_used"]
				if data.has("activated"):     node.activated     = data["activated"]
				if data.has("current_index"): node.current_index = data["current_index"]

	# Restore ground items — only when level has been visited before
	if level_data.has("__ground_items__"):
		# Free scene-placed items; saved list is authoritative
		for node in get_tree().get_nodes_in_group("ground_item"):
			node.queue_free()
		for entry in level_data["__ground_items__"]:
			var it = load(entry["path"]) as ItemData
			if it:
				var gi = GROUND_ITEM_SCENE.instantiate()
				gi.item = it
				gi.position = Vector2(entry["pos"][0], entry["pos"][1])
				main2D.add_child(gi)

	# Show/hide unpossessed chars at /root/main/ based on their home level
	for node in get_tree().get_nodes_in_group("save"):
		if node.is_in_group("player"):
			continue
		if str(node.get_path()).contains("/main2D/"):
			continue
		if not ("home_level" in node) or node.home_level == "":
			continue
		if node.home_level != level_path:
			disable_node(node)
			continue
		# Belongs to this level — restore using saved state
		var char_data = level_data.get(node.name, {})
		if char_data.get("disabled", false):
			disable_node(node)
		else:
			enable_node(node)
			if char_data.has("position"): node.global_position = char_data["position"]
			if char_data.has("health"):   node.health = char_data["health"]

func unload_level():
	for child in main2D.get_children():
		if not child.is_in_group("player"):
			main2D.remove_child(child)
			child.queue_free()

func disable_node(node: Node):
	node.visible = false
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)

	for child in node.get_children():
		if child is CollisionShape2D:
			child.disabled = true


func enable_node(node: Node):
	node.visible = true
	node.set_process(true)
	node.set_physics_process(true)
	node.set_process_input(true)
	node.set_process_unhandled_input(true)

	for child in node.get_children():
		if child is CollisionShape2D:
			child.disabled = false

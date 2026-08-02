extends Node2D

@onready var main2D = $main2D
@onready var spawn = $Spawn
@onready var OStestLabel = $CanvasLayerForTestLabel/OSTestLabel
@onready var backgroundMusicPlayer = $AudioManager/BackgroundMusicPlayer
@onready var interact_icon = $InteractIcon

var level_instance = null
const GROUND_ITEM_SCENE = preload("res://scenes/common/items/ground_item.tscn")

@onready var _notification_label: Label = $NotificationLayer/NotificationLabel
var _notify_tween: Tween

func notify(text: String, duration: float = 2.5):
	_notification_label.text = text
	_notification_label.modulate.a = 1.0
	_notification_label.show()
	if _notify_tween:
		_notify_tween.kill()
	_notify_tween = create_tween()
	_notify_tween.tween_interval(duration)
	_notify_tween.tween_property(_notification_label, "modulate:a", 0.0, 0.4)
	_notify_tween.tween_callback(_notification_label.hide)
	if Global.dialogue:
		Global.dialogue.append_notification(text)

func set_ingame_ui_visible(v: bool):
	$CanvasLayerForUi.visible = v
	$InteractIcon.visible = v

func _ready():
	Global.main = self
	$InventoryUI.item_thrown.connect(_on_item_thrown)
	set_ingame_ui_visible(false)
	Global.ui_text_settings_changed.connect(_apply_notification_font)
	_apply_notification_font()
	_setup_test_hud()

func _apply_notification_font():
	Global.apply_to_label(_notification_label, 10)

# The debug HUD in the top corner: OS name and current game state. Set up once,
# not on every font change — it used to live inside _apply_notification_font(),
# which re-ran it each time the player touched the text settings.
func _setup_test_hud():
	if not Global.isTest:
		return
	OStestLabel.visible = true
	OStestLabel.text = OS.get_name()
	Global.G_STAT_TestLabel = $CanvasLayerForTestLabel/G_STAT_TestLabel
	Global.G_STAT_TestLabel.visible = true
	Global.G_STAT_TestLabel.text = Global.GameState.keys()[Global.game_state]

func _on_item_thrown(item: ItemData, world_pos: Vector2):
	var gi = GROUND_ITEM_SCENE.instantiate()
	gi.item = item
	gi.position = world_pos
	main2D.add_child(gi)

func _toggle_fullscreen():
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(_delta):
	if Input.is_action_just_pressed("fullscreen"):
		_toggle_fullscreen()
	
# Places whoever is currently the player — not necessarily the main character.
func place_controlled_character(where_to_set_character: Vector2, direction_vector: Vector2):
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

# Portals may store their target as a uid:// reference. Level keys in the save
# are plain res:// paths, so everything is normalized to those.
func _resolve_level_path(level_path: String) -> String:
	if not level_path.begins_with("uid://"):
		return level_path
	var uid_int = ResourceUID.text_to_id(level_path)
	if not ResourceUID.has_id(uid_int):
		return level_path
	return ResourceUID.get_id_path(uid_int)

func load_level(level_path : String, door_name : String, fadeIn: float = 1, fadeOut: float = 1, initial_possess_group: String = "", spawn_override: Vector2 = Vector2.ZERO):
	# Normalize UID paths to file paths so keys are consistent
	level_path = _resolve_level_path(level_path)

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

	# A level may declare who you control here and where you arrive. The caller
	# still wins — a save restores as the character it recorded, not the level's
	# default — and a level that declares nothing keeps whoever walked in.
	if initial_possess_group == "":
		initial_possess_group = _level_declares("default_character")
	if door_name == "":
		door_name = _level_declares("default_spawn_door")

	if initial_possess_group != "":
		# Accepts a group name, a character_id, or (for saves written before ids
		# existed) a node name.
		var char_to_possess = get_tree().get_first_node_in_group(initial_possess_group)
		if char_to_possess == null:
			char_to_possess = _find_character_by_id(initial_possess_group)
		if char_to_possess == null:
			for node in get_tree().get_nodes_in_group("save"):
				if str(node.name) == initial_possess_group:
					char_to_possess = node
					break
		if char_to_possess:
			if not char_to_possess is CharacterBase:
				push_error("load_level: found '%s' for '%s' but it is not a character (type: %s). Check the scene — InventoryComponent/EquipmentComponent children must be plain Node, not CharacterBody2D." % [char_to_possess.name, initial_possess_group, char_to_possess.get_class()])
				char_to_possess = null
			else:
				char_to_possess.add_to_group("player")
				char_to_possess.is_level_default_character = true
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
		var door_found: bool = false
		for door in get_tree().get_nodes_in_group("door"):
			if door.door_name == door_name:
				door.need_to_be_exited_before_activating = true
				spawn_position = door.global_position
				door_found = true
				break
		if not door_found:
			push_warning("Portal %s is not in the level %s" % [door_name, level_path])

	await place_controlled_character(spawn_position, Vector2.ZERO)
	
# Per-node state carried in the save, beyond position and visibility.
const SAVED_PROPERTIES = ["health", "switch_state", "was_used", "activated", "current_index"]

# Deliberately not the `in` operator: `"activated" in switch` is TRUE because
# switch.gd declares an `activated` SIGNAL, and that would store a Signal object
# in the save and then try to assign to a signal on restore. get_property_list()
# reports only real properties.
func _has_property(node: Node, property_name: String) -> bool:
	for property in node.get_property_list():
		if property["name"] == property_name:
			return true
	return false

# What a node is filed under in per_level_save. Characters use their stable
# character_id; everything else — switches, platforms, chests — uses its node
# name, which is unique within its own level.
func _save_key(node: Node) -> String:
	if _has_property(node, "character_id") and node.character_id != "":
		return node.character_id
	return str(node.name)

func _character_id_of(node: Node) -> String:
	if _has_property(node, "character_id"):
		return node.character_id
	return ""

# The already-carried copy of the same character, if one is parked at /root/main.
# Matched on character_id, falling back to node name only for characters that
# have not been given an id yet.
func _carried_copy_of(level_character: Node) -> Node:
	var wanted_id := _character_id_of(level_character)
	for child in get_children():
		if child == level_character:
			continue
		if wanted_id != "":
			if _character_id_of(child) == wanted_id:
				return child
		elif str(child.name) == str(level_character.name):
			return child
	return null

# Reads a declaration off the loaded level. Duck-typed rather than requiring the
# Level base script, so a room that has nothing to declare needs no script at all.
func _level_declares(property_name: String) -> String:
	if level_instance == null:
		return ""
	if not _has_property(level_instance, property_name):
		return ""
	return str(level_instance.get(property_name))

func _find_character_by_id(character_id: String) -> Node:
	if character_id == "":
		return null
	for node in get_tree().get_nodes_in_group("save"):
		if _character_id_of(node) == character_id:
			return node
	return null

func save_current_level():
	var level_path = Global.current_level
	if level_path == "":
		return

	# Save all alive ground items (dynamic + scene-placed)
	var ground_items_data: Array = []
	for node in get_tree().get_nodes_in_group("ground_item"):
		if node.item == null:
			continue
		var item_path = node.item.get_source_path()
		if item_path != "":
			ground_items_data.append({"path": item_path, "pos": [node.global_position.x, node.global_position.y]})
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
		for property_name in SAVED_PROPERTIES:
			if _has_property(node, property_name):
				data[property_name] = node.get(property_name)
		var inv = node.get_node_or_null("InventoryComponent") as InventoryComponent
		if inv:                      data["inventory"]      = inv.serialize()
		# Only the controlled character's equipment reaches the save file via
		# Global.save_game, so without this anyone you are not currently playing
		# loses what they had equipped.
		var equipment = node.get_node_or_null("EquipmentComponent") as EquipmentComponent
		if equipment:                data["equipment"]      = equipment.serialize()

		Global.per_level_save[target_level][_save_key(node)] = data
	
func restore_current_level():
	var level_path = Global.current_level

	# Free fresh-scene duplicates of characters already at /root/main/
	for node in get_tree().get_nodes_in_group("save"):
		if not str(node.get_path()).contains("/main2D/"):
			continue
		if not ("home_level" in node):
			continue
		if _carried_copy_of(node) != null:
			node.remove_from_group("player")
			node.get_parent().remove_child(node)
			node.queue_free()

	var level_data = Global.per_level_save.get(level_path, {})

	# Restore level-local nodes (enemies, switches, platforms)
	if not level_data.is_empty():
		for node in get_tree().get_nodes_in_group("save"):
			if not node.is_inside_tree():
				continue
			if not str(node.get_path()).contains("/main2D/"):
				continue
			if not level_data.has(_save_key(node)):
				continue
			var data = level_data[_save_key(node)]
			# The controlled character takes its position and enabled state from the
			# spawn/possession path, not from here. Its bag still lives in this record
			# though, and skipping the whole entry used to throw the items away — you
			# would walk back into a room possessing someone else and find it empty.
			if node.is_in_group("player"):
				if data.has("inventory"):
					var player_inv = node.get_node_or_null("InventoryComponent") as InventoryComponent
					if player_inv: player_inv.deserialize(data["inventory"])
				if data.has("equipment"):
					var player_eq = node.get_node_or_null("EquipmentComponent") as EquipmentComponent
					if player_eq: player_eq.deserialize(data["equipment"])
				continue
			if data.get("disabled", false):
				disable_node(node)
			else:
				enable_node(node)
				if data.has("position"):     node.global_position = data["position"]
				if data.has("health"):       node.health      = data["health"]
				if data.has("inventory"):
					var inv = node.get_node_or_null("InventoryComponent") as InventoryComponent
					if inv: inv.deserialize(data["inventory"])
				if data.has("equipment"):
					var equipment = node.get_node_or_null("EquipmentComponent") as EquipmentComponent
					if equipment: equipment.deserialize(data["equipment"])
				for property_name in SAVED_PROPERTIES:
					if property_name == "health":
						continue   # already applied above
					if data.has(property_name) and _has_property(node, property_name):
						node.set(property_name, data[property_name])
				if data.has("switch_state") and node.has_method("which_anim_to_play"):
					node.which_anim_to_play()

	# Restore ground items — only when level has been visited before
	if level_data.has("__ground_items__"):
		# Free scene-placed items; saved list is authoritative
		for node in get_tree().get_nodes_in_group("ground_item"):
			node.queue_free()
		for entry in level_data["__ground_items__"]:
			var stored_item = load(entry["path"]) as ItemData
			if stored_item:
				var gi = GROUND_ITEM_SCENE.instantiate()
				gi.item = stored_item.make_unique_copy()
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
		var char_data = level_data.get(_save_key(node), {})
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

# Characters that were possessed or carried between levels are reparented to
# /root/main, so unload_level() never touches them. Starting or resuming a run
# while one is still there leaves it behind, and the incoming level's own copy of
# the same character is then added alongside it under an auto-generated name
# ("@CharacterBody2D@27") — the stray duplicate standing at the level's spawn.
func clear_persistent_characters():
	for child in get_children():
		if not child.is_in_group("save"):
			continue
		if not ("home_level" in child):
			continue
		child.remove_from_group("player")
		remove_child(child)
		child.queue_free()
	Global.controlled_char = null

# ── Test helpers ──────────────────────────────────────────────────
# Unreachable during normal play: nothing binds input to them and every one
# refuses unless test mode is on (`--testmode`). They exist so an automated
# run can reach a place the way the game itself would, rather than assigning
# global_position by hand — which drops the character inside the tilemap, where
# move_and_slide cannot free it and gravity piles up until it falls through.

func _test_mode_guard(helper_name: String) -> bool:
	if not Global.isTest:
		push_error("%s is a test helper; launch with --testmode to use it." % helper_name)
		return false
	return true

func test_find_door(door_name: String) -> Node:
	for door in get_tree().get_nodes_in_group("door"):
		if door.door_name == door_name:
			return door
	return null

# Doors in the room right now: which name to hand test_goto_level, and where each
# one leads.
func test_list_doors() -> Array:
	var doors = []
	for door in get_tree().get_nodes_in_group("door"):
		doors.append({
			"door_name": door.door_name,
			"position": [door.global_position.x, door.global_position.y],
			"leads_to": door.level_to_load if "level_to_load" in door else "",
			"arrives_at_door": door.door_to_spam if "door_to_spam" in door else "",
		})
	return doors

# Every room's doors and where they lead, read from the scene files rather than a
# hand-kept list so it cannot drift. Lets a test plan a route instead of walking
# into rooms to discover their exits.
func test_level_map() -> Dictionary:
	if not _test_mode_guard("test_level_map"):
		return {}
	var rooms_dir = "res://scenes/environment/castle_zone/rooms"
	var listing = DirAccess.open(rooms_dir)
	if listing == null:
		push_error("test_level_map: cannot open %s" % rooms_dir)
		return {}
	var map = {}
	for file_name in listing.get_files():
		if not file_name.ends_with(".tscn"):
			continue
		var room_path = "%s/%s" % [rooms_dir, file_name]
		var room_scene = load(room_path) as PackedScene
		if room_scene == null:
			continue
		var room = room_scene.instantiate()
		var exits = []
		for node in _collect_descendants(room):
			if "door_name" in node and "level_to_load" in node:
				exits.append({
					"door_name": node.door_name,
					"leads_to": _resolve_level_path(str(node.level_to_load)).get_file(),
					"arrives_at_door": node.door_to_spam if "door_to_spam" in node else "",
				})
		map[file_name] = exits
		room.free()
	return map

func _collect_descendants(root_node: Node) -> Array:
	var found = []
	var pending = [root_node]
	while pending.size() > 0:
		var node = pending.pop_back()
		found.append(node)
		for child in node.get_children():
			pending.append(child)
	return found

# Stops enemies and hazards killing the player mid-run. Healing still applies, and
# only the "player" group is shielded so enemy deaths remain testable.
func test_set_invulnerable(enabled: bool) -> bool:
	if not _test_mode_guard("test_set_invulnerable"):
		return false
	Global.test_invulnerable = enabled
	return true

# Moves the controlled character, clearing the fall speed it had built up so it
# does not arrive already punching through the floor.
func test_teleport(target: Vector2) -> bool:
	if not _test_mode_guard("test_teleport"):
		return false
	var character = Global.controlled_char
	if character == null:
		push_warning("test_teleport: no controlled character yet.")
		return false
	character.velocity = Vector2.ZERO
	character.global_position = target
	Global.camera.global_position = target
	return true

# Doors are the positions the game itself spawns players on, so they are the
# safest teleport targets in any room.
func test_teleport_to_door(door_name: String) -> bool:
	if not _test_mode_guard("test_teleport_to_door"):
		return false
	var door = test_find_door(door_name)
	if door == null:
		push_error("test_teleport_to_door: no door '%s' in %s" % [door_name, Global.current_level])
		return false
	return test_teleport(door.global_position)

# Level change equivalent to walking through a portal. A door name is required:
# load_level() falls back to Vector2.ZERO without one, which in most rooms is
# solid tile.
func test_goto_level(level_path: String, door_name: String) -> bool:
	if not _test_mode_guard("test_goto_level"):
		return false
	if door_name == "":
		push_error("test_goto_level: a door name is required, or the character spawns inside the tilemap.")
		return false
	load_level(level_path, door_name)
	return true

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

extends Node

var G_STAT_TestLabel

# Test mode. Always off for players — launch with `--testmode` to turn it on. It
# enables the state HUD, unlocks the test_* helpers on main, and stops the focus
# watcher pausing a run that nobody is sitting in front of. It can also be set at
# runtime from a debug console, which is how a live editor session enables it.
# The flag is spelled --testmode rather than --test because Godot reserves
# --test for its own unit-test runner and aborts before the project ever loads.
var isTest: bool = false

# Set by main.test_set_invulnerable(). Only shields whoever is currently in the
# "player" group, so enemy deaths can still be tested while it is on.
var test_invulnerable: bool = false

func _detect_test_mode() -> bool:
	for arg in OS.get_cmdline_args():
		if arg == "--testmode":
			return true
	# Args after a bare `--` land here instead of in get_cmdline_args().
	for arg in OS.get_cmdline_user_args():
		if arg == "--testmode":
			return true
	return false

# ── Playing any level ─────────────────────────────────────────────
# Three ways in, all ending in menu.start_new_game(): F6 on a room in the editor,
# `-- --level=room4 --door=portal_2` on the command line, and the menu's Levels list.

const MAIN_SCENE = "res://scripts/main.tscn"
const LEVELS_FOLDER = "res://scenes"

# Set from --level / --door; the menu starts this level instead of showing itself.
var requested_level: String = ""
var requested_door: String = ""

func _read_level_arguments():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			requested_level = arg.trim_prefix("--level=")
		elif arg.begins_with("--door="):
			requested_door = arg.trim_prefix("--door=")

# Called by a level that was run on its own: swaps in the main scene and opens the
# level from there, so it plays exactly as if the player had walked in.
func play_level_standalone(level_path: String):
	get_tree().change_scene_to_file(MAIN_SCENE)
	while menu == null or main == null:
		await get_tree().process_frame
	menu.start_new_game(level_path)

# Every scene whose root script is a Level, sorted by path. Read from the scene
# files, so a new room shows up without being registered anywhere.
func find_levels() -> Array:
	var level_paths = []
	_collect_levels(LEVELS_FOLDER, level_paths)
	level_paths.sort()
	return level_paths

func _collect_levels(dir_path: String, level_paths: Array):
	for sub_dir in DirAccess.get_directories_at(dir_path):
		_collect_levels(dir_path.path_join(sub_dir), level_paths)
	for file_name in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".tscn"):
			continue
		var scene_path = dir_path.path_join(file_name)
		if _is_level_scene(load(scene_path) as PackedScene):
			level_paths.append(scene_path)

# Reads the root node's script from the packed scene without instancing it.
func _is_level_scene(scene: PackedScene) -> bool:
	if scene == null:
		return false
	var state = scene.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) != "script":
			continue
		var script = state.get_node_property_value(0, i) as Script
		while script != null:
			if script.get_global_name() == "Level":
				return true
			script = script.get_base_script()
	return false

# Accepts a full res:// path or a file name like "room4" / "room4.tscn".
func find_level(name_or_path: String) -> String:
	if name_or_path.begins_with("res://"):
		return name_or_path
	var wanted = name_or_path.trim_suffix(".tscn")
	for level_path in find_levels():
		if level_path.get_file().get_basename() == wanted:
			return level_path
	return ""

signal level_transition_started
signal level_transition_finished

# The test HUD prints these enums by name. Use EnumName.keys()[value] rather than
# a hand-written name list — the lists silently drifted out of order whenever a
# state was inserted rather than appended.
enum GameState {
	MAIN_MENU,
	PLAYING,
	PAUSE_MENU,
	GAME_OVER,
}

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

enum BehaviorStates {
	IDLE,
	CHASE,
}

enum ActionStates {
	ATTACK,
}

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
			G_STAT_TestLabel.text = GameState.keys()[game_state]
	get:
		return game_state
var menu

# ── Text / font settings ──────────────────────────────────────────
var ui_font_name: String = "press_start_2p"  # "default" | "open_sans" | "press_start_2p"
var ui_font_size_scale: float = 1.0
signal ui_text_settings_changed

func get_current_font() -> Font:
	var path := ""
	match ui_font_name:
		"open_sans":      path = "res://fonts/open_sans.ttf"
		"press_start_2p": path = "res://fonts/press_start_2p.ttf"
		_:                return null
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Font

func apply_to_label(label: Label, base_size: int):
	var f = get_current_font()
	if f:
		label.add_theme_font_override("font", f)
	else:
		label.remove_theme_font_override("font")
	label.add_theme_font_size_override("font_size", maxi(1, int(base_size * ui_font_size_scale)))

# Same as apply_to_label for text with BBCode. Bold uses the same font, since the
# pixel font has no bold face.
func apply_to_rich_text(label: RichTextLabel, base_size: int):
	var font = get_current_font()
	var size = maxi(1, int(base_size * ui_font_size_scale))
	for font_name in ["normal_font", "bold_font", "italics_font"]:
		if font:
			label.add_theme_font_override(font_name, font)
		else:
			label.remove_theme_font_override(font_name)
	for size_name in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		label.add_theme_font_size_override(size_name, size)
var death_menu
var camera
# Everything that currently wants the player held still, keyed by reason.
# Several systems overlap — a level transition can be running while the inventory
# is open — so movement resumes only once every one of them has let go. Writing
# a plain bool here meant whichever system closed last freed the player, even if
# another still wanted them frozen.
var _movement_blockers: Dictionary = {}

var can_player_move: bool:
	get:
		return _movement_blockers.is_empty()

func block_player_movement(reason: String):
	_movement_blockers[reason] = true

func unblock_player_movement(reason: String):
	_movement_blockers.erase(reason)

# Drops every blocker at once. For hard state changes (new game, quit to menu)
# where a system may have been torn down before it could release its own.
func clear_movement_blockers():
	_movement_blockers.clear()

var controlled_char : Node
var current_level : String

var per_level_save : Dictionary
var active_checkpoint_position: Vector2 = Vector2(INF, INF)

var dialogue
var inventory_ui
var encyclopedia

const SAVE_PATH = "user://save.json"
const TEST_SAVE_PATH = "user://save_test.json"

# Test runs write their own slot so an automated save/load never overwrites the
# player's real progress.
func save_path() -> String:
	return TEST_SAVE_PATH if isTest else SAVE_PATH

func has_save() -> bool:
	return FileAccess.file_exists(save_path())

func _controlled_character_id() -> String:
	# The node can already be freed when a level was torn down under us.
	if controlled_char == null or not is_instance_valid(controlled_char):
		return ""
	if "character_id" in controlled_char:
		return str(controlled_char.character_id)
	return ""

# ── Character roster ──────────────────────────────────────────────
# Where every character is and what state it is in, keyed by character_id.
# Characters are data here rather than nodes kept alive across level changes:
# a level instantiates whoever the roster says belongs to it, and nobody is ever
# reparented. That is what lets two rooms each hold a node called
# "PlayableRobot" without one silently deleting the other.
var character_roster: Dictionary = {}

# Story state that is not an item: "talked to X", "gave the key card". Belongs to
# the run rather than a character, so possession and dropped items cannot reset it.
var quest_flags: Dictionary = {}

func set_quest_flag(flag_name: String):
	quest_flags[flag_name] = true

func has_quest_flag(flag_name: String) -> bool:
	return quest_flags.get(flag_name, false) == true

# Encyclopedia entries the player has come across, by entry id. Like quest flags,
# they belong to the run and are saved with it.
var known_entries: Dictionary = {}

# Returns true the first time an entry is learned, so callers can announce it.
func learn_entry(entry_id: String) -> bool:
	if known_entries.has(entry_id):
		return false
	known_entries[entry_id] = true
	return true

func character_record(character_id: String) -> Dictionary:
	return character_roster.get(character_id, {})

func character_level(character_id: String) -> String:
	return str(character_record(character_id).get("level", ""))

# Copies a live character into its roster record. Stored JSON-ready so the roster
# can go straight into the save file.
func write_character_record(character: Node, level_path: String):
	if character.character_id == "":
		push_warning("Character '%s' has no character_id and cannot be tracked." % character.name)
		return
	var record: Dictionary = character_roster.get(character.character_id, {})
	record["scene"] = character.scene_file_path
	record["level"] = level_path
	record["position"] = [character.global_position.x, character.global_position.y]
	record["health"] = character.health
	record["disabled"] = not character.visible
	record["is_level_default_character"] = character.is_level_default_character
	var inventory = character.get_node_or_null("InventoryComponent")
	if inventory:
		record["inventory"] = inventory.serialize()
	var equipment = character.get_node_or_null("EquipmentComponent")
	if equipment:
		record["equipment"] = equipment.serialize()
	character_roster[character.character_id] = record

func apply_character_record(character: Node, record: Dictionary):
	if record.has("position"):
		var stored_position = record["position"]
		character.global_position = Vector2(stored_position[0], stored_position[1])
	if record.has("health"):
		character.health = record["health"]
	if record.has("is_level_default_character"):
		character.is_level_default_character = record["is_level_default_character"]
	if record.has("inventory"):
		var inventory = character.get_node_or_null("InventoryComponent")
		if inventory:
			inventory.deserialize(record["inventory"])
	if record.has("equipment"):
		var equipment = character.get_node_or_null("EquipmentComponent")
		if equipment:
			equipment.deserialize(record["equipment"])

# Called when the controlled character walks into another level.
func move_character_to_level(character_id: String, level_path: String):
	if character_id == "" or not character_roster.has(character_id):
		return
	character_roster[character_id]["level"] = level_path

func save_game(spawn_position: Vector2, checkpoint_position: Vector2 = Vector2(INF, INF)):
	# Snapshot the room the player is standing in first. per_level_save is only
	# refreshed when a level is left, so without this a checkpoint stores the room
	# as it was on entry and everything done since — items dropped, enemies killed,
	# chests filled, platforms moved — is silently lost on reload.
	if main != null:
		main.save_current_level()
	# Characters live in the roster, so their state is captured there rather than
	# alongside the level's switches and platforms.
	#
	# Not during a level transition: load_level has already moved the travelling
	# character's record to the level being entered, while the tree still holds the
	# old level's copies. Capturing then writes the stale ones back over it, and the
	# traveller is never spawned in the level you arrive at.
	if main != null and not _movement_blockers.has("level_transition"):
		main.capture_characters_to_roster()
	active_checkpoint_position = checkpoint_position if checkpoint_position != Vector2(INF, INF) else spawn_position
	var data = {
		"current_level": current_level,
		"spawn_position": [spawn_position.x, spawn_position.y],
		"checkpoint_position": [active_checkpoint_position.x, active_checkpoint_position.y],
		"possessed_character_id": _controlled_character_id(),
		"character_roster": character_roster,
		"quest_flags": quest_flags,
		"known_entries": known_entries,
		"per_level_save": _serialize_save(per_level_save),
	}
	var path := save_path()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file %s (error %d)" % [path, FileAccess.get_open_error()])
		notify("Saving failed!")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("Module['FS'].syncfs(false, function(err) {})")

func load_game() -> Dictionary:
	var path := save_path()
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not read save file %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	if not result is Dictionary:
		push_error("Save file %s is not valid JSON — ignoring it." % path)
		return {}
	per_level_save = _deserialize_save(result.get("per_level_save", {}))
	character_roster = result.get("character_roster", {})
	quest_flags = result.get("quest_flags", {})
	known_entries = result.get("known_entries", {})
	var cp = result.get("checkpoint_position", null)
	if cp != null:
		active_checkpoint_position = Vector2(cp[0], cp[1])
	return result

func notify(text: String, duration: float = 2.5):
	if main:
		main.notify(text, duration)

# Read by godot-mcp's runtime-state digest, so a test can pull global state in
# one call instead of scripting a tree walk for every question.
func _mcp_state() -> Dictionary:
	# An unset checkpoint is (INF, INF), which JSON renders as null — report the
	# flag instead so "no checkpoint yet" is not mistaken for a broken value.
	var checkpoint_set: bool = active_checkpoint_position != Vector2(INF, INF)
	return {
		"game_state": GameState.keys()[game_state],
		"current_level": current_level,
		"controlled_char": str(controlled_char.name) if controlled_char != null else "",
		"can_player_move": can_player_move,
		"movement_blockers": _movement_blockers.keys(),
		"checkpoint_set": checkpoint_set,
		"checkpoint": [active_checkpoint_position.x, active_checkpoint_position.y] if checkpoint_set else [],
		"is_test": isTest,
		"test_invulnerable": test_invulnerable,
		"save_path": save_path(),
		"has_save": has_save(),
	}

func _serialize_save(dict: Dictionary) -> Dictionary:
	var out = {}
	for level in dict:
		out[level] = {}
		for node_name in dict[level]:
			var entry = dict[level][node_name]
			# Not every entry is a per-node record: "__ground_items__" holds a plain
			# array that is already JSON-ready. Only node records carry a Vector2.
			if not entry is Dictionary:
				out[level][node_name] = entry
				continue
			var d: Dictionary = entry.duplicate()
			if d.has("position"):
				d["position"] = [d["position"].x, d["position"].y]
			out[level][node_name] = d
	return out

func _deserialize_save(dict: Dictionary) -> Dictionary:
	var out = {}
	for level in dict:
		out[level] = {}
		for node_name in dict[level]:
			var entry = dict[level][node_name]
			if not entry is Dictionary:
				out[level][node_name] = entry
				continue
			var d: Dictionary = entry.duplicate()
			if d.has("position"):
				var p = d["position"]
				d["position"] = Vector2(p[0], p[1])
			out[level][node_name] = d
	return out

func _ready():
	isTest = _detect_test_mode()
	_read_level_arguments()
	if isTest:
		# Loud on purpose: test mode changes pause behaviour and unlocks the
		# teleport helpers, so it should never be a surprise.
		print("[PlanetFarAway] TEST MODE ON — test_* helpers unlocked, focus pausing disabled.")
	level_transition_started.connect(_on_transition_started)
	level_transition_finished.connect(_on_transition_finished)

func _on_transition_started():
	block_player_movement("level_transition")

func _on_transition_finished():
	unblock_player_movement("level_transition")

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
	

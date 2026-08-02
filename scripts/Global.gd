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

var _saved_inventory_data: Array = []
var _saved_equipment_data: Array = []

const SAVE_PATH = "user://save.json"
const TEST_SAVE_PATH = "user://save_test.json"

# Test runs write their own slot so an automated save/load never overwrites the
# player's real progress.
func save_path() -> String:
	return TEST_SAVE_PATH if isTest else SAVE_PATH

func has_save() -> bool:
	return FileAccess.file_exists(save_path())

func _controlled_character_id() -> String:
	if controlled_char == null:
		return ""
	if "character_id" in controlled_char:
		return str(controlled_char.character_id)
	return ""

func save_game(spawn_position: Vector2, checkpoint_position: Vector2 = Vector2(INF, INF)):
	# Snapshot the room the player is standing in first. per_level_save is only
	# refreshed when a level is left, so without this a checkpoint stores the room
	# as it was on entry and everything done since — items dropped, enemies killed,
	# chests filled, platforms moved — is silently lost on reload.
	if main != null:
		main.save_current_level()
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
		"possessed_character_id": _controlled_character_id(),
		"possessed_char_name": str(controlled_char.name) if controlled_char != null else "",
		"possessed_char_home_level": char_home_level,
		"per_level_save": _serialize_save(per_level_save),
		"inventory_component": inv_data,
		"equipment_component": equip_data,
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
	var cp = result.get("checkpoint_position", null)
	if cp != null:
		active_checkpoint_position = Vector2(cp[0], cp[1])
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
	

# Does what F6 does in the editor: runs one room on its own, without main.tscn,
# and checks that the room boots the game around itself.
#   godot --headless --path . -s res://tests/standalone_level.gd -- --testmode
extends SceneTree

const ROOM = "res://scenes/environment/castle_zone/rooms/room4.tscn"

var failures: int = 0
var checks: int = 0

func _initialize():
	_run()

func _run():
	var global = root.get_node("Global")
	change_scene_to_file(ROOM)
	var booted = false
	for i in 600:
		await process_frame
		var has_character = global.controlled_char != null and is_instance_valid(global.controlled_char)
		var transition_running = global._movement_blockers.has("level_transition")
		if global.main != null and global.current_level == ROOM and has_character and not transition_running:
			booted = true
			break
	_check("room booted the game around itself", booted)
	if booted:
		_check("main scene is running", current_scene.scene_file_path == global.MAIN_SCENE, current_scene.scene_file_path)
		_check("playing as main_char", global._controlled_character_id() == "main_char", global._controlled_character_id())
		_check("game state is playing", global.game_state == global.GameState.PLAYING)
		var on_a_door = false
		for door in get_nodes_in_group("door"):
			if door.global_position.distance_to(global.controlled_char.global_position) < 32:
				on_a_door = true
		_check("placed at a door, not inside the tiles", on_a_door, str(global.controlled_char.global_position))
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(label: String, ok: bool, detail: String = ""):
	checks += 1
	if ok:
		print("  PASS ", label)
		return
	failures += 1
	print("  FAIL ", label, "  ", detail)

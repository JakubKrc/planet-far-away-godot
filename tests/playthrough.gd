# Headless playthrough: drives the real game code through new game, possession,
# doors, inventory, dialogue, save and Continue, and reports PASS/FAIL per check.
#
# Run from the project folder:
#   godot --headless --path . -s res://tests/playthrough.gd -- --testmode
# Exit code is 0 when every check passes. Only ever touches the test save slot.
#
# Doors, switches and dialogue are triggered by calling their interact() directly,
# not by walking up to them, so this checks game logic rather than level layout.
extends SceneTree

const TEST_SAVE = "user://save_test.json"
const ROOMS = "res://scenes/environment/castle_zone/rooms/"
const MAIN_CHAR_SCENE = "res://scenes/common/characters/main_char/main_char.tscn"
const KEY_CARD_DIALOGUE = "res://dialogue/give_keycard.json"

var Global: Node
var failures: int = 0
var checks: int = 0

func _initialize():
	_run()

func _run():
	Global = root.get_node("Global")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	change_scene_to_file("res://scripts/main.tscn")
	await _frames(20)
	# Combat would derail runs that are really testing saves and possession.
	Global.test_invulnerable = true

	await _new_game_starts_as_main_char()
	await _technician_remembers_the_key_card()
	var possessed_id = await _possession_switch_in_room1()
	await _inventory_screen_fits_its_panel()
	await _possessed_character_walks_to_room2(possessed_id)
	await _ground_items_survive_continue(possessed_id)
	await _back_to_room1_without_duplicates(possessed_id)
	await _new_game_resets_the_run()
	await _room7_key_switch_opens_the_blocker()
	await _possession_chain_through_rooms_4_to_6()

	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# ── Sections ──────────────────────────────────────────────────────

func _new_game_starts_as_main_char():
	_section("new game")
	Global.menu._act_new_game()
	_check("level settles", await _wait_until_settled())
	_check("in room1", Global.current_level == ROOMS + "room1.tscn", Global.current_level)
	_check("controlling main_char", _controlled_id() == "main_char", _controlled_id())
	_check("main_char is the level's own character", Global.controlled_char.is_level_default_character)
	_check("exactly one MainChar", _count_main_chars() == 1)
	_check("one node in player group", get_nodes_in_group("player").size() == 1)

func _technician_remembers_the_key_card():
	_section("quest flags: technician key card")
	await _talk(KEY_CARD_DIALOGUE)
	_check("offer shown before", _choice_texts().has("Yes, can you help?"), str(_choice_texts()))
	_pick("Yes, can you help?")
	_pick("Thanks!")
	await _frames(2)
	_check("got key card", _bag().has_id("blue_key"))
	_check("flag set", Global.has_quest_flag("technician_gave_keycard"))
	_end_dialogue()

	_bag().remove_by_id("blue_key")
	await _talk(KEY_CARD_DIALOGUE)
	_check("no second card after dropping it", not _choice_texts().has("Yes, can you help?"), str(_choice_texts()))
	_check("'already have' shown instead", _choice_texts().has("I already have your card."))
	_pick("Just browsing.")
	await _frames(2)
	_check("movement unblocked after dialogue", Global.can_player_move)

func _possession_switch_in_room1() -> String:
	_section("possession via switch")
	await _use_switch("Switch")
	var possessed_id = _controlled_id()
	_check("now controlling room1_robot", possessed_id == "room1_robot", possessed_id)
	_check("still one player", get_nodes_in_group("player").size() == 1)
	_check("marked as possessed", not Global.controlled_char.is_level_default_character)
	return possessed_id

func _inventory_screen_fits_its_panel():
	_section("inventory screen layout")
	var bag = _bag()
	_check("possessed character has a bag", bag != null)
	Global.inventory_ui.give_or_drop(load("res://items/test_potion.tres").make_unique_copy())
	Global.inventory_ui.give_or_drop(load("res://items/blue_key.tres").make_unique_copy())
	_check("bag holds potion and key", bag.has_id("test_potion") and bag.has_id("blue_key"))

	var ui = Global.inventory_ui
	ui.open(bag)
	await _frames(3)
	var panel: Rect2 = ui._panel
	var grid = Rect2(ui._pri_origin, Vector2(bag.cols, bag.rows) * ui.CELL)
	var hint_width = ui._font().get_string_size(ui.HINT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, ui.TEXT_SIZE).x
	var hint_end = ui._drop_rect.end.x + ui.HINT_GAP + hint_width
	_check("drop strip inside panel", panel.encloses(ui._drop_rect))
	_check("key hints inside panel", hint_end <= panel.end.x + 0.5, "%s > %s" % [hint_end, panel.end.x])
	_check("grid inside panel", panel.encloses(grid))
	_check("grid between title and drop strip", grid.position.y >= panel.position.y + ui.TITLE_H and grid.end.y <= ui._drop_rect.position.y)
	ui.close()

	var chest = Global.main.level_instance.get_node_or_null("Chest")
	_check("room1 has a chest", chest != null)
	var chest_bag = chest.get_node("InventoryComponent")
	ui.open(bag, chest_bag)
	await _frames(3)
	var chest_grid = Rect2(ui._sec_origin, Vector2(chest_bag.cols, chest_bag.rows) * ui.CELL)
	var viewport = Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_check("chest grid inside panel", ui._panel.encloses(chest_grid))
	_check("room for lane headers", ui._pri_origin.y - ui.LANE_H >= ui._panel.position.y + ui.TITLE_H)
	_check("dual panel fits the screen", viewport.encloses(ui._panel), str(ui._panel))
	ui.close()
	_check("movement unblocked after closing", Global.can_player_move)

func _possessed_character_walks_to_room2(possessed_id: String):
	_section("walk to room2 as " + possessed_id)
	_check("arrived", await _use_door_to("room2.tscn"))
	_check("in room2", Global.current_level == ROOMS + "room2.tscn", Global.current_level)
	_check("still controlling " + possessed_id, _controlled_id() == possessed_id, _controlled_id())
	_check("still marked as possessed", not Global.controlled_char.is_level_default_character)
	_check("main_char stayed in room1", Global.character_level("main_char") == ROOMS + "room1.tscn", Global.character_level("main_char"))
	_check("no MainChar in room2", _count_main_chars() == 0)
	_check("bag travelled along", _bag().has_id("blue_key"))

func _ground_items_survive_continue(possessed_id: String):
	_section("drop item, save, quit to menu, continue")
	var potion = _first_item_with_id(_bag(), "test_potion")
	_bag().remove(potion)
	Global.inventory_ui._throw(potion)
	await _frames(5)
	var items_on_ground = get_nodes_in_group("ground_item").size()
	_check("potion lies on the ground", items_on_ground >= 1)

	_check("resume settles", await _save_and_continue())
	_check("resumed in room2", Global.current_level == ROOMS + "room2.tscn", Global.current_level)
	_check("resumed as " + possessed_id, _controlled_id() == possessed_id, _controlled_id())
	_check("still marked as possessed", not Global.controlled_char.is_level_default_character)
	_check("key still in bag", _bag().has_id("blue_key"))
	_check("potion not in bag", not _bag().has_id("test_potion"))
	await _frames(5)
	var restored = get_nodes_in_group("ground_item").size()
	_check("ground items restored", restored == items_on_ground, "%d vs %d" % [restored, items_on_ground])
	_check("quest flag survived", Global.has_quest_flag("technician_gave_keycard"))
	_check("one player after resume", get_nodes_in_group("player").size() == 1)

func _back_to_room1_without_duplicates(possessed_id: String):
	_section("back to room1")
	_check("arrived", await _use_door_to("room1.tscn"))
	_check("still " + possessed_id, _controlled_id() == possessed_id, _controlled_id())
	_check("exactly one MainChar", _count_main_chars() == 1)
	var ids = _ids_in_tree()
	_check("possessed character not duplicated", ids.count(possessed_id) == 1, str(ids))
	await _frames(3)
	_check("still marked as possessed", not Global.controlled_char.is_level_default_character)
	await _use_switch("Switch2")
	_check("switch back to main_char", _controlled_id() == "main_char", _controlled_id())

func _new_game_resets_the_run():
	_section("new game resets the run")
	Global.menu._act_new_game()
	_check("settles", await _wait_until_settled())
	_check("main_char again", _controlled_id() == "main_char")
	_check("quest flags cleared", Global.quest_flags.is_empty(), str(Global.quest_flags))
	_check("one MainChar", _count_main_chars() == 1)

func _room7_key_switch_opens_the_blocker():
	_section("room7: key switch and blocker")
	# Rooms 4-7 have no door from rooms 1-3, so the test enters through a door helper.
	Global.main.test_goto_level(ROOMS + "room7.tscn", "portal_2")
	_check("arrived", await _wait_until_settled())
	_check("controlling main_char", _controlled_id() == "main_char", _controlled_id())
	_check("exactly one MainChar", _count_main_chars() == 1)

	var blocker = Global.main.level_instance.get_node("Blocker")
	await _use_switch("Switch")
	_check("blocker stays shut without the key", blocker.visible)
	Global.inventory_ui.give_or_drop(load("res://items/blue_key.tres").make_unique_copy())
	await _use_switch("Switch")
	_check("key switch opens the blocker", not blocker.visible)

	var robot_only_switch = Global.main.level_instance.get_node("Switch2")
	_check("robot-only switch refuses main_char", not robot_only_switch.can_interact_with(Global.controlled_char))

	_check("resume settles", await _save_and_continue())
	blocker = Global.main.level_instance.get_node("Blocker")
	_check("blocker still open after continue", not blocker.visible)
	_check("key switch still spent", Global.main.level_instance.get_node("Switch").was_used)

func _possession_chain_through_rooms_4_to_6():
	_section("possession chain: room7 -> 4 -> 5 -> 6")
	await _use_switch("Switch3")
	_check("possessed room7_robot", _controlled_id() == "room7_robot", _controlled_id())

	_check("to room4", await _use_door_to("room_4.tscn"))
	_check("room7_robot came along", _controlled_id() == "room7_robot", _controlled_id())
	_check("main_char stayed in room7", Global.character_level("main_char") == ROOMS + "room7.tscn")

	var platform = Global.main.level_instance.get_node("Platform")
	var start_position = platform.global_position
	await _use_switch("Switch")
	await _frames(90)
	_check("switch starts the platform", platform.activated)
	_check("platform moved", platform.global_position.distance_to(start_position) > 1.0)
	var moved_position = platform.global_position

	_check("resume settles", await _save_and_continue())
	var saved_platform = Global.per_level_save[ROOMS + "room_4.tscn"].get("Platform", {})
	var saved_position = saved_platform.get("position", Vector2.INF)
	_check("platform position was saved", saved_position.distance_to(moved_position) < 1.0, "%s vs %s" % [saved_position, moved_position])
	platform = Global.main.level_instance.get_node("Platform")
	_check("platform still running after continue", platform.activated)
	_check("waypoint index restored as an int", typeof(platform.current_index) == TYPE_INT)
	_check("platform switch still spent", Global.main.level_instance.get_node("Switch").was_used)

	await _use_switch("Switch2")
	_check("possessed room4_robot", _controlled_id() == "room4_robot", _controlled_id())
	_check("to room5", await _use_door_to("room_5.tscn"))
	_check("to room6", await _use_door_to("room_6.tscn"))
	_check("room4_robot came along", _controlled_id() == "room4_robot", _controlled_id())
	await _use_switch("Switch2")
	_check("possessed room6_enemy2", _controlled_id() == "room6_enemy2", _controlled_id())

	_check("resume settles", await _save_and_continue())
	_check("resumed as room6_enemy2", _controlled_id() == "room6_enemy2", _controlled_id())
	_check("room4_robot left in room6", Global.character_level("room4_robot") == ROOMS + "room_6.tscn", Global.character_level("room4_robot"))
	_check("room7_robot left in room4", Global.character_level("room7_robot") == ROOMS + "room_4.tscn", Global.character_level("room7_robot"))
	_check("main_char left in room7", Global.character_level("main_char") == ROOMS + "room7.tscn", Global.character_level("main_char"))

	_check("back to room4", await _use_door_to("room_4.tscn"))
	var ids = _ids_in_tree()
	_check("room7_robot is waiting in room4", ids.has("room7_robot"), str(ids))
	_check("room4_robot is not in room4", not ids.has("room4_robot"), str(ids))

# ── Helpers ───────────────────────────────────────────────────────

func _section(title: String):
	print("== ", title)

func _check(label: String, ok: bool, detail: String = ""):
	checks += 1
	if ok:
		print("  PASS ", label)
		return
	failures += 1
	print("  FAIL ", label, "  ", detail)

func _frames(count: int):
	for i in count:
		await process_frame

# Level loads are asynchronous: wait until the transition is over and someone is
# under control, then a little longer for physics to settle.
func _wait_until_settled() -> bool:
	for i in 600:
		await process_frame
		var transition_running = Global._movement_blockers.has("level_transition")
		var has_character = Global.controlled_char != null and is_instance_valid(Global.controlled_char)
		if not transition_running and has_character:
			await _frames(30)
			return true
	return false

func _save_and_continue() -> bool:
	Global.save_game(Global.controlled_char.global_position)
	Global.menu._act_main_menu()
	await _frames(20)
	Global.menu._act_continue()
	return await _wait_until_settled()

# Goes through whichever door in the current room leads to the given scene file.
func _use_door_to(scene_file: String) -> bool:
	for door in get_nodes_in_group("door"):
		var target = Global.main._resolve_level_path(door.level_to_load)
		if target.ends_with("/" + scene_file):
			door.interact(Global.controlled_char)
			return await _wait_until_settled()
	print("  !! no door to ", scene_file, " in ", Global.current_level)
	return false

func _use_switch(node_name: String):
	var switch = Global.main.level_instance.get_node_or_null(node_name)
	if switch == null:
		print("  !! no switch ", node_name, " in ", Global.current_level)
		return
	switch.interact(Global.controlled_char)
	await _frames(10)

func _talk(dialogue_path: String):
	Global.dialogue.start(dialogue_path)
	await _frames(3)

func _choice_texts() -> Array:
	var texts = []
	for choice in Global.dialogue._choices:
		texts.append(choice["text"])
	return texts

func _pick(choice_text: String):
	var choices = Global.dialogue._choices
	for i in choices.size():
		if choices[i]["text"] == choice_text:
			Global.dialogue._selection = i
			Global.dialogue._advance()
			return
	print("  !! no choice '", choice_text, "' in ", _choice_texts())

func _end_dialogue():
	if Global.dialogue._in_dialogue:
		Global.dialogue._end()

func _controlled_id() -> String:
	return Global._controlled_character_id()

func _bag() -> InventoryComponent:
	return Global.controlled_char.get_node_or_null("InventoryComponent")

func _first_item_with_id(bag: InventoryComponent, item_id: String) -> ItemData:
	for item in bag.all_items():
		if item.id == item_id:
			return item
	return null

func _ids_in_tree() -> Array:
	var ids = []
	for character in Global.main.characters_in_tree():
		ids.append(character.character_id)
	return ids

func _count_main_chars() -> int:
	var count = 0
	for character in Global.main.characters_in_tree():
		if character.scene_file_path == MAIN_CHAR_SCENE:
			count += 1
	return count

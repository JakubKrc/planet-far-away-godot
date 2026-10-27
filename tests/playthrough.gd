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
const LOBBY = "res://scenes/environment/apartment_zone/arcology_lobby.tscn"
const APARTMENT = "res://scenes/environment/apartment_zone/igor_apartment.tscn"
const MAIN_CHAR_SCENE = "res://scenes/common/characters/main_char/main_char.tscn"
const KEY_CARD_DIALOGUE = "res://data/dialogue/technician_keycard.json"
const FIXTURE_VAULT = "res://tests/fixtures/vault"
const FIXTURE_DATA = "user://vault_export_playthrough"

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
	await _dialogue_links_unlock_encyclopedia_entries()
	var possessed_id = await _possession_switch_in_room1()
	await _inventory_screen_fits_its_panel()
	await _possessed_character_walks_to_room2(possessed_id)
	await _ground_items_survive_continue(possessed_id)
	await _back_to_room1_without_duplicates(possessed_id)
	await _new_game_resets_the_run()
	await _room7_key_switch_opens_the_blocker()
	await _possession_chain_through_rooms_4_to_6()
	await _any_level_can_be_started()
	await _lobby_leads_home()
	await _memory_of_home()

	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# ── Sections ──────────────────────────────────────────────────────

func _new_game_starts_as_main_char():
	_section("new game")
	Global.menu._act_new_game()
	_check("level settles", await _wait_until_settled())
	_check("in the ruins, room4", Global.current_level == ROOMS + "room4.tscn", Global.current_level)
	_check("not in a memory yet", not Global.is_in_memory())
	_check("controlling main_char", _controlled_id() == "main_char", _controlled_id())
	_check("main_char is the level's own character", Global.controlled_char.is_level_default_character)
	_check("exactly one MainChar", _count_main_chars() == 1)
	_check("one node in player group", get_nodes_in_group("player").size() == 1)

	# The castle test rooms come next; they start the old way, from room1.
	Global.menu.start_new_game(ROOMS + "room1.tscn")
	_check("room1 settles", await _wait_until_settled())
	_check("in room1", Global.current_level == ROOMS + "room1.tscn", Global.current_level)

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

func _dialogue_links_unlock_encyclopedia_entries():
	_section("encyclopedia: links in dialogue")
	var exporter = VaultExporter.new()
	var exported = exporter.export_vault(ProjectSettings.globalize_path(FIXTURE_VAULT), FIXTURE_DATA)
	_check("fixture vault exports", exported, str(exporter.errors))
	var encyclopedia = Global.encyclopedia
	encyclopedia.load_entries(FIXTURE_DATA + "/encyclopedia.json")

	await _talk(FIXTURE_DATA + "/dialogue/guard.json")
	_check("linked entry discovered", Global.known_entries.has("old tower"))
	_check("entry not linked yet stays unknown", not Global.known_entries.has("guard captain"))
	_check("discovery announced in the log", _log_contains("New in encyclopedia: Old Tower"))

	Global.dialogue._on_link_clicked("old tower")
	await _frames(2)
	_check("clicking a link opens the encyclopedia", encyclopedia.visible)
	_check("it shows the clicked entry", encyclopedia._current_id == "old tower", encyclopedia._current_id)
	_check("#known_at_start entry listed from the start", encyclopedia._listed_ids == ["old tower", "world"], str(encyclopedia._listed_ids))
	_check("entry not revealed yet", not Global.known_entries.has("tower key"))
	_check("link to an undiscovered entry is plain text", not encyclopedia._text.text.contains("[url=guard captain]"))
	encyclopedia._on_link_clicked("guard captain")
	_check("clicking it does not discover it", not Global.known_entries.has("guard captain"))
	encyclopedia.close()
	_check("dialogue still holds the player", not Global.can_player_move)

	_pick("Tell me about the tower.")
	await _frames(2)
	_check("discovered from the next line", Global.known_entries.has("guard captain"))
	_check("choice reveals an entry", Global.known_entries.has("tower key"))
	_check("revealed entry announced", _log_contains("New in encyclopedia: Tower Key"))
	_check("known-at-start entry not announced", not _log_contains("New in encyclopedia: World"))
	encyclopedia.open("old tower")
	_check("the link is active once discovered", encyclopedia._text.text.contains("[url=guard captain]"))
	encyclopedia.close()
	Global.dialogue._advance()
	await _frames(2)
	_check("movement unblocked", Global.can_player_move)

	_press_key(KEY_J)
	await _frames(3)
	_check("J opens the encyclopedia", encyclopedia.visible)
	_check("encyclopedia blocks movement", not Global.can_player_move)
	_press_key(KEY_ESCAPE)
	await _frames(3)
	_check("Esc closes it", not encyclopedia.visible)
	_check("Esc did not open the pause menu", Global.game_state == Global.GameState.PLAYING)
	_check("movement back after closing", Global.can_player_move)

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
	_check("encyclopedia discoveries survived", Global.known_entries.has("old tower"))
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

func _lobby_leads_home():
	_section("the arcology lobby")
	Global.menu.start_new_game(LOBBY)
	_check("lobby settles", await _wait_until_settled())
	var level = Global.main.level_instance
	var walker = Global.controlled_char
	_check("standing on the lobby floor", walker.is_on_floor(), str(walker.global_position))
	await _frames(20)
	var entrance_thought = level.get_node("ThoughtAtEntrance")
	Global.main.test_teleport(Vector2(72, 208))
	await _frames(20)
	_check("coming in, Igor thinks of his day", entrance_thought.current_text() == "Another shift done.", entrance_thought.current_text())
	entrance_thought.stop()

	var bot = level.get_node("Residents/CleaningBot")
	var bot_x = bot.position.x
	var view = level.get_node("AtriumView")
	await _hold_until("right", func(): return walker.global_position.x > 300)
	await _wait_seconds(1.5)
	_check("walked into the atrium", view.is_active(), str(walker.global_position))
	_check("the camera pulls back to show the floors above", Global.camera.zoom.x < 0.7, str(Global.camera.zoom))
	_check("the cleaning robot is on its rounds", not is_equal_approx(bot.position.x, bot_x))
	var garden_thought = level.get_node("ThoughtInGarden")
	_check("the garden starts its own thought", garden_thought.was_used)
	garden_thought.stop()

	var gardener_text = level.get_node("Residents/Gardener/PlaceText")
	Global.main.test_teleport(Vector2(470, 208))
	await _frames(5)
	_check("near the racks, the gardener greets Igor", gardener_text.visibility() > 0.9, str(gardener_text.visibility()))
	var zoom = Global.camera.zoom.x
	_check("with the camera pulled back, text keeps its size on screen", is_equal_approx(gardener_text._label.scale.x * zoom, 1.0), "%s at zoom %s" % [gardener_text._label.scale.x, zoom])
	_check("the man at the lift keeps to himself", level.get_node_or_null("Residents/Commuter/PlaceText") == null)

	var gardener_talk = level.get_node("Residents/Gardener/Talk/DialogueTrigger")
	_check("the gardener can be talked to", gardener_talk.can_interact_with(walker))
	gardener_talk.interact(walker)
	await _frames(3)
	var steps = 0
	while Global.dialogue._in_dialogue and steps < 20:
		_pick_first_choice()
		await _frames(2)
		steps += 1
	_check("the gardener's talk ends", not Global.dialogue._in_dialogue)
	_check("and Igor learns about arcologies", Global.known_entries.has("arcology"), str(Global.known_entries))
	Global.main.test_teleport_to_door("lobby_elevator")
	await _wait_seconds(1.5)
	_check("out of the atrium, the camera is back to normal", Global.camera.zoom.is_equal_approx(Vector2.ONE), str(Global.camera.zoom))

	_check("the lift goes up to the apartment", await _use_door_to("igor_apartment.tscn"))
	_check("arriving at the apartment door", _standing_at_door("apartment_door"))
	_check("the apartment door goes back down to the lobby", await _use_door_to("arcology_lobby.tscn"))
	_check("arriving at the lift", _standing_at_door("lobby_elevator"))

func _memory_of_home():
	_section("a memory of home")
	Global.menu._act_new_game()
	_check("new game settles in room4", await _wait_until_settled())
	var walker = Global.controlled_char
	var trigger = Global.main.level_instance.get_node("MemoryOfHome")
	var exit_door = Global.main.test_find_door("portal_2")
	_check("the memory waits just before the exit door", trigger.global_position.distance_to(exit_door.global_position) < 48, str(trigger.global_position))
	# Up on the ledge, a few steps from the door, walking toward it.
	Global.main.test_teleport(trigger.global_position + Vector2(48, 8))
	await _frames(10)
	await _hold_until("left", func(): return _thought_on_screen() != "")
	_check("in the ruins Igor stops to think", _thought_on_screen() == "Why do I even do this?", _thought_on_screen())
	_check("and cannot walk on while he thinks", not Global.can_player_move)
	var stood_at = walker.global_position
	_check("then he remembers home: the lobby", await _wait_for_level(LOBBY, 15.0), Global.current_level)
	_check("the lobby settles", await _wait_until_settled())
	_check("in a memory", Global.is_in_memory())
	_check("arriving at the lobby entrance", _standing_at_door("lobby_entrance"))

	_check("up the lift to the apartment", await _use_door_to("igor_apartment.tscn"))
	var kristin = Global.main.level_instance.get_node("Kristin")
	var kristin_talk = kristin.get_node("DialogueTrigger")
	_check("Kristin has something to say", kristin_talk.dialogue_file == "res://data/dialogue/kristin.json", kristin_talk.dialogue_file)
	kristin_talk.interact(Global.controlled_char)
	await _frames(3)
	_check("talking to Kristin", Global.dialogue._in_dialogue)
	var steps = 0
	while Global.dialogue._in_dialogue and steps < 20:
		_pick_first_choice()
		await _frames(2)
		steps += 1
	_check("the talk ends", not Global.dialogue._in_dialogue)
	_check("and the memory ends with it", not Global.is_in_memory())
	_check("back in the ruins", await _wait_for_level(ROOMS + "room4.tscn", 15.0), Global.current_level)
	_check("room4 settles", await _wait_until_settled())
	var back_at = Global.controlled_char.global_position
	_check("right where the memory began", back_at.distance_to(stood_at) < 16, "%s vs %s" % [back_at, stood_at])
	await _wait_seconds(2.0)
	_check("the memory does not start again", Global.current_level == ROOMS + "room4.tscn" and _thought_on_screen() == "")
	_check("and the exit door is right there", await _use_door_to("room5.tscn"))

	_section("a memory started from code")
	Global.menu.start_new_game(ROOMS + "room1.tscn")
	_check("room1 settles", await _wait_until_settled())
	Global.remember(["Test thought."], LOBBY, "lobby_entrance")
	await _frames(20)
	_check("Global.remember thinks first", _thought_on_screen() == "Test thought.", _thought_on_screen())
	_check("then goes into the memory", await _wait_for_level(LOBBY, 15.0), Global.current_level)
	_check("which knows its way back", Global.is_in_memory() and Global.memory_return["level"] == ROOMS + "room1.tscn", str(Global.memory_return))
	_check("the lobby settles", await _wait_until_settled())
	Global.end_memory()
	_check("Global.end_memory goes back", await _wait_for_level(ROOMS + "room1.tscn", 15.0), Global.current_level)
	_check("room1 settles again", await _wait_until_settled())

# Whatever thought is on screen right now, from any thought bubble.
func _thought_on_screen() -> String:
	for bubble in get_nodes_in_group("thought_bubble"):
		if bubble.is_showing():
			return bubble.current_text()
	return ""

func _pick_first_choice():
	if Global.dialogue._choices.is_empty():
		Global.dialogue._advance()
		return
	Global.dialogue._selection = 0
	Global.dialogue._advance()

func _wait_for_level(level_path: String, seconds: float) -> bool:
	var frames = int(seconds * 60)
	for i in frames:
		if Global.current_level == level_path:
			return true
		await process_frame
	return false

func _standing_at_door(door_name: String) -> bool:
	var door = Global.main.test_find_door(door_name)
	return Global.controlled_char.global_position.distance_to(door.global_position) < 32

func _new_game_resets_the_run():
	_section("new game resets the run")
	Global.menu._act_new_game()
	_check("settles", await _wait_until_settled())
	_check("main_char again", _controlled_id() == "main_char")
	_check("quest flags cleared", Global.quest_flags.is_empty(), str(Global.quest_flags))
	_check("encyclopedia discoveries cleared", Global.known_entries.is_empty(), str(Global.known_entries))
	_check("known-at-start entry still known", Global.encyclopedia.is_known("world"))
	_check("discovered entry forgotten", not Global.encyclopedia.is_known("old tower"))
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

	_check("to room4", await _use_door_to("room4.tscn"))
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
	var saved_platform = Global.per_level_save[ROOMS + "room4.tscn"].get("Platform", {})
	var saved_position = saved_platform.get("position", Vector2.INF)
	_check("platform position was saved", saved_position.distance_to(moved_position) < 1.0, "%s vs %s" % [saved_position, moved_position])
	platform = Global.main.level_instance.get_node("Platform")
	_check("platform still running after continue", platform.activated)
	_check("waypoint index restored as an int", typeof(platform.current_index) == TYPE_INT)
	_check("platform switch still spent", Global.main.level_instance.get_node("Switch").was_used)

	await _use_switch("Switch2")
	_check("possessed room4_robot", _controlled_id() == "room4_robot", _controlled_id())
	_check("to room5", await _use_door_to("room5.tscn"))
	_check("to room6", await _use_door_to("room6.tscn"))
	_check("room4_robot came along", _controlled_id() == "room4_robot", _controlled_id())
	await _use_switch("Switch2")
	_check("possessed room6_enemy2", _controlled_id() == "room6_enemy2", _controlled_id())

	_check("resume settles", await _save_and_continue())
	_check("resumed as room6_enemy2", _controlled_id() == "room6_enemy2", _controlled_id())
	_check("room4_robot left in room6", Global.character_level("room4_robot") == ROOMS + "room6.tscn", Global.character_level("room4_robot"))
	_check("room7_robot left in room4", Global.character_level("room7_robot") == ROOMS + "room4.tscn", Global.character_level("room7_robot"))
	_check("main_char left in room7", Global.character_level("main_char") == ROOMS + "room7.tscn", Global.character_level("main_char"))

	_check("back to room4", await _use_door_to("room4.tscn"))
	var ids = _ids_in_tree()
	_check("room7_robot is waiting in room4", ids.has("room7_robot"), str(ids))
	_check("room4_robot is not in room4", not ids.has("room4_robot"), str(ids))

func _any_level_can_be_started():
	_section("starting any level")
	var levels = Global.find_levels()
	var names = []
	for level_path in levels:
		names.append(level_path.get_file().get_basename())
	var expected = ["arcology_lobby", "igor_apartment", "room1", "room2", "room3", "room4", "room5", "room6", "room7"]
	_check("every room is found, platforms are not", names == expected, str(names))
	_check("a level can be named without its path", Global.find_level("room4") == ROOMS + "room4.tscn")

	Global.menu.start_new_game(ROOMS + "room4.tscn")
	_check("room4 starts", await _wait_until_settled())
	_check("main_char created where nobody was placed", _controlled_id() == "main_char", _controlled_id())
	_check("exactly one MainChar", _count_main_chars() == 1)
	_check("standing at a door", _distance_to_nearest_door() < 32, str(_distance_to_nearest_door()))

	Global.menu.start_new_game(Global.find_level("igor_apartment"))
	_check("Igor's apartment starts", await _wait_until_settled())
	_check("as main_char", _controlled_id() == "main_char", _controlled_id())
	_check("at the apartment door", Global.controlled_char.global_position.distance_to(Global.main.test_find_door("apartment_door").global_position) < 32)
	_check("standing on the tiled floor", Global.controlled_char.is_on_floor(), str(Global.controlled_char.global_position))
	var level = Global.main.level_instance
	var door_thought = level.get_node("ThoughtAtDoor")
	await _frames(20)
	_check("arriving at the door starts Igor's thought", door_thought.is_showing() and door_thought.current_text() == "Home.", door_thought.current_text())
	await _wait_seconds(9.0)
	_check("the thought has played all its lines and gone", not door_thought.is_showing())
	_check("and is remembered as played", door_thought.was_used)
	Global.main.test_teleport(Vector2(200, 192))
	await _frames(10)
	Global.main.test_teleport(Vector2(40, 192))
	await _frames(20)
	_check("walking back to the door does not repeat it", not door_thought.is_showing())

	var couch_thought = level.get_node("ThoughtAtCouch")
	Global.main.test_teleport(Vector2(110, 192))
	await _frames(20)
	_check("passing the couch, Igor thinks of Kristin", couch_thought.current_text() == "Kristin is probably out on the balcony.", couch_thought.current_text())
	couch_thought.stop()

	# The apartment has no place text any more, so test one placed by the test.
	var guitar_text = load("res://scenes/common/floating_text/place_text.tscn").instantiate()
	guitar_text.position = Vector2(158, 98)
	guitar_text.text = "Test text"
	level.add_child(guitar_text)
	Global.main.test_teleport(Vector2(158, 112))
	await _frames(5)
	_check("place text fully visible up close", is_equal_approx(guitar_text.visibility(), 1.0), str(guitar_text.visibility()))
	Global.main.test_teleport(Vector2(100, 112))
	await _frames(5)
	var middle = guitar_text.visibility()
	_check("place text half faded at mid distance", middle > 0.1 and middle < 0.9, str(middle))
	Global.main.test_teleport(Vector2(290, 192))
	await _frames(5)
	_check("place text invisible far away", guitar_text.visibility() == 0.0, str(guitar_text.visibility()))
	guitar_text.queue_free()
	Global.main.test_teleport(Vector2(28, 192))
	await _frames(20)

	var walker = Global.controlled_char
	await _hold_until("right", func(): return walker.global_position.x > 292)
	_check("walked under the shelves to the far side", walker.global_position.y > 180, str(walker.global_position))
	await _hold_until("left", func(): return walker.global_position.x < 274)
	await _jump_towards("", walker, 0)
	_check("jumped up through the lower shelf onto it", absf(walker.global_position.y - 160) < 3 and walker.is_on_floor(), str(walker.global_position))
	await _jump_towards("left", walker, 18)
	_check("jumped onto the upper shelf", absf(walker.global_position.y - 128) < 3 and walker.is_on_floor(), str(walker.global_position))
	await _jump_towards("left", walker, 120)
	_check("jumped up to the upper floor", absf(walker.global_position.y - 112) < 3 and walker.global_position.x < 208, str(walker.global_position))

	var outside_cover = Global.main.level_instance.get_node("OutsideCover")
	_check("from inside, the balcony is hidden behind the building", is_equal_approx(outside_cover.modulate.a, 1.0))
	var apartment_cover = Global.main.level_instance.get_node("ApartmentCover")
	_check("from inside, the apartment is not covered", is_zero_approx(apartment_cover.modulate.a))
	var front_drones = Global.main.level_instance.get_node("CityBackground/FrontDrones")
	_check("from inside, no drone flies in front of the room", is_zero_approx(front_drones.modulate.a))
	var far_drone = Global.main.level_instance.get_node("CityBackground/CityFar/Drone1")
	var far_drone_x = far_drone.position.x
	await _hold_until("left", func(): return walker.global_position.x < -100)
	_check("walked out through the wall onto the balcony", walker.global_position.x < -100 and walker.is_on_floor(), str(walker.global_position))
	await _wait_seconds(1.5)
	_check("the camera pulls back over the city", Global.camera.zoom.x < 0.8, str(Global.camera.zoom))
	_check("on the balcony, the cover has faded away", outside_cover.modulate.a < 0.05, str(outside_cover.modulate.a))
	_check("and the apartment is seen from outside, as facade", apartment_cover.modulate.a > 0.95, str(apartment_cover.modulate.a))
	_check("outside, the front drone can pass by", front_drones.modulate.a > 0.95, str(front_drones.modulate.a))
	var kristin = Global.main.level_instance.get_node("Kristin")
	_check("Kristin stands out on the balcony", kristin.global_position.x < 0 and kristin.global_position.x > -128, str(kristin.global_position))
	_check("background drones are flying", not is_equal_approx(far_drone.position.x, far_drone_x))
	await _hold_until("left", func(): return false)
	_check("the end of the balcony stops Igor", walker.global_position.x > -135 and walker.is_on_floor(), str(walker.global_position))
	await _hold_until("right", func(): return walker.global_position.x > 40)
	await _wait_seconds(1.5)
	_check("back inside, the camera returns to normal", Global.camera.zoom.is_equal_approx(Vector2.ONE) and Global.camera.offset.is_zero_approx(), str(Global.camera.zoom, Global.camera.offset))
	_check("and the balcony is hidden again", is_equal_approx(outside_cover.modulate.a, 1.0), str(outside_cover.modulate.a))
	_check("and the apartment is open again", is_zero_approx(apartment_cover.modulate.a), str(apartment_cover.modulate.a))

	var guitar = Global.main.level_instance.get_node("GuitarPlay")
	Global.main.test_teleport(Vector2(158, 112))
	await _frames(10)
	_send_action("use", true)
	await _frames(2)
	_send_action("use", false)
	await _frames(5)
	_check("E at the guitar starts the solo", guitar.is_playing() and guitar.get_node("SongPlayer").playing)
	var x_before = walker.global_position.x
	await _hold_until("right", func(): return false)
	_check("Igor cannot move while playing", absf(walker.global_position.x - x_before) < 1.0, str(walker.global_position.x - x_before))
	_check("the guitar cannot be started again mid-song", not guitar.can_interact_with(walker))
	guitar._on_song_finished()   # the song is 37 s long; skip to its end
	await _frames(30)
	_check("after the song Igor can move again", Global.can_player_move)
	_check("and thinks about how it went", guitar.get_node("ThoughtBubble").current_text() == "Incredible how I still suck at this!", guitar.get_node("ThoughtBubble").current_text())

	Global.requested_level = "room5"
	Global.requested_door = "portal_2"
	Global.menu._start_requested_level()
	_check("--level=room5 starts", await _wait_until_settled())
	_check("in room5", Global.current_level == ROOMS + "room5.tscn", Global.current_level)
	var door = Global.main.test_find_door("portal_2")
	_check("at the --door it named", Global.controlled_char.global_position.distance_to(door.global_position) < 32)
	Global.requested_level = ""
	Global.requested_door = ""

	Global.menu.open_levels()
	var rows = Global.menu.items.get_children()
	_check("Levels list shows every level plus Back", rows.size() == levels.size() + 1, str(rows.size()))
	Global.menu._selection = names.find("room6")
	Global.menu._activate(rows)
	_check("picking room6 starts it", await _wait_until_settled())
	_check("in room6", Global.current_level == ROOMS + "room6.tscn", Global.current_level)
	_check("menu closed", not Global.menu.visible)

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

# Holds a movement action like a player would, until the condition holds or 6 s pass.
func _hold_until(action: String, condition: Callable):
	Input.action_press(action)
	for i in 360:
		await physics_frame
		if condition.call():
			break
	Input.action_release(action)

# A full jump, steering in a direction ("" for straight up) for the given number
# of physics frames, until the character lands. Sent as input events, because the
# jump only reacts to a fresh press, as with real keys.
func _jump_towards(direction: String, character: Node, steer_frames: int):
	if direction != "":
		_send_action(direction, true)
	_send_action("jump", true)
	for i in 120:
		await physics_frame
		if i == 20:
			_send_action("jump", false)
		if direction != "" and i == steer_frames:
			_send_action(direction, false)
		if i > 10 and character.is_on_floor():
			break
	_send_action("jump", false)
	if direction != "":
		_send_action(direction, false)
	await _frames(10)

func _wait_seconds(seconds: float):
	await create_timer(seconds).timeout

func _send_action(action: String, pressed: bool):
	var event = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)

func _log_contains(fragment: String) -> bool:
	for line in Global.dialogue.log_box.get_children():
		var text = ""
		if line is Label:
			text = line.text
		elif line is RichTextLabel:
			text = line.get_parsed_text()
		if text.contains(fragment):
			return true
	return false

# A real key press and release, delivered through the normal input path.
func _press_key(keycode: Key):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)

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

func _distance_to_nearest_door() -> float:
	var nearest = INF
	for door in get_nodes_in_group("door"):
		nearest = minf(nearest, door.global_position.distance_to(Global.controlled_char.global_position))
	return nearest

func _count_main_chars() -> int:
	var count = 0
	for character in Global.main.characters_in_tree():
		if character.scene_file_path == MAIN_CHAR_SCENE:
			count += 1
	return count

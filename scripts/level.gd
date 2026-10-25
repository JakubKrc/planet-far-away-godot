class_name Level
extends Node2D

# Who the player controls when this level opens cold — nobody walked in, as on a
# new game. A character_id or a group name.
#
# Anyone who travels here keeps control, and an explicit character passed to
# load_level() beats both, so a save restores as the character it recorded. To
# force a specific character on a player who arrived with someone else — a
# scripted stretch where you play as somebody different — pass it to load_level()
# rather than declaring it here. Left empty, the player gets main_char.
@export var default_character: String = ""

# Where the player appears when the caller did not name a door. Lets a level be
# opened with just its path. Left empty, the level's first door is used.
@export var default_spawn_door: String = ""

func _ready():
	# Run on its own (F6 in the editor) a level has no camera, UI or player around
	# it, so it starts the whole game and opens itself the normal way.
	if Global.main == null:
		Global.play_level_standalone.call_deferred(scene_file_path)

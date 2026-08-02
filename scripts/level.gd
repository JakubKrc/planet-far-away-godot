class_name Level
extends Node2D

# Who the player controls when this level opens cold — nobody walked in, as on a
# new game. A character_id or a group name.
#
# Anyone who travels here keeps control, and an explicit character passed to
# load_level() beats both, so a save restores as the character it recorded. To
# force a specific character on a player who arrived with someone else — a
# scripted stretch where you play as somebody different — pass it to load_level()
# rather than declaring it here.
@export var default_character: String = ""

# Where the player appears when the caller did not name a door. Lets a level be
# opened with just its path — the menu no longer has to know which portal to use.
@export var default_spawn_door: String = ""

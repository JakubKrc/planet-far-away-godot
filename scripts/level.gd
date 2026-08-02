class_name Level
extends Node2D

# Who the player controls on arrival, as a character_id or a group name.
#
# Empty means "keep whoever walked in", which is the normal case for a level you
# reach through a portal. Set it when the level should hand you a specific
# character: the opening level, or a scripted stretch where you play as someone
# else. A character_override passed to load_level() still beats this, so a save
# restores as the character it recorded rather than the level's default.
@export var default_character: String = ""

# Where the player appears when the caller did not name a door. Lets a level be
# opened with just its path — the menu no longer has to know which portal to use.
@export var default_spawn_door: String = ""

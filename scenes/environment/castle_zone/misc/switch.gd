extends Node2D

@export var interact_group: String = "player"
@export var animation_active: String = "active"
@export var animation_not_active: String = "not_active"
@export var switch_state: bool = false
@export var repeatable_action: bool = true
@export var what_to_posses: String = ""
@export var use_signal: bool = false
@export var requires_item_id: String = ""
@export var requires_message: String = ""

@onready var area2d = $Switch_area

var player_inside: bool = false
# Saved and restored, so the setter — not switch_switch() — owns keeping the
# interact prompt in sync. Restoring the flag alone would leave a spent one-shot
# switch still advertising an "E" that does nothing, because switch_switch()
# bails on `!repeatable_action && was_used` before it can hide anything.
var was_used: bool = false : set = _set_was_used
var interact_priority: int = 0   # lowest: anything lying on a switch is taken first
# Re-entrancy guard. Switches and platforms are wired in a loop: the switch emits
# `activated` -> Platform.activate() -> the platform emits `started_running` ->
# back into this switch's _on_platform_running() -> switch_switch() again. This
# flag is raised around the emit so that second pass updates state and animation
# without emitting again. It is cleared at the end of every switch_switch(), so
# it guards one call rather than latching.
var signal_was_used = false

# Declared without parameters, but possession switches emit one extra String
# ("posesujem") to tell a receiving switch the activation came from a possession
# switch. Godot allows emitting more arguments than are declared; every receiver
# takes an optional parameter, so both shapes work through the same connection.
signal activated
signal deactivated

func _set_was_used(value: bool):
	was_used = value
	# The setter runs before _ready() when the scene sets the value, and the area
	# is not available yet; _ready() syncs once it is.
	if is_node_ready():
		_sync_interact_prompt()

# A one-shot switch that has already fired stops offering an interact prompt.
func _sync_interact_prompt():
	var area = get_node_or_null("Switch_area")
	if area == null:
		return
	if was_used and not repeatable_action:
		area.remove_from_group("interactable")
	elif not area.is_in_group("interactable"):
		area.add_to_group("interactable")

func _ready():
	area2d.body_entered.connect(_on_body_entered)
	area2d.body_exited.connect(_on_body_exited)
	which_anim_to_play()
	_sync_interact_prompt()
	if use_signal && switch_state:
		call_deferred("_emit_initial")

func _emit_initial():
	emit_signal("activated")

func _process(_delta):
	if what_to_posses != "":
		which_anim_to_play()

func _on_body_entered(body):
	if body.is_in_group(interact_group):  
		player_inside = true

func _on_body_exited(body):
	if body.is_in_group(interact_group):
		player_inside = false

# Only a character in interact_group may work this switch — room7 uses it to
# restrict one switch to the playable robot.
func can_interact_with(player) -> bool:
	return player.is_in_group(interact_group)

func interact(player):
	if requires_item_id != "":
		var inv = player.get_node_or_null("InventoryComponent") as InventoryComponent
		# No bag at all means the player cannot be carrying the key item.
		var has_it = inv.has_id(requires_item_id) if inv else false
		if not has_it:
			Global.notify(requires_message if requires_message != "" else "Required item missing")
			return
	if what_to_posses != "":
		switch_switch(true)
	elif switch_state:
		switch_switch(false)
	else:
		switch_switch(true)

func switch_switch(set_to: bool):
	if !repeatable_action && was_used:
		return
	if what_to_posses != "" and set_to:
		var target = get_tree().get_first_node_in_group(what_to_posses)
		if target != null and target.is_in_group("player"):
			return
	was_used = true   # the setter hides the prompt on one-shot switches

	if set_to==true:
		switch_state=true
		which_anim_to_play()
		if (!signal_was_used):
			signal_was_used=true
			
			if what_to_posses != "":
				emit_signal("activated","posesujem")
			else:
				emit_signal("activated")

			change_controlled_char()
			
	if set_to==false:
		switch_state=false
		which_anim_to_play()
		if (!signal_was_used):
			signal_was_used=true
			if what_to_posses != "":
				emit_signal("deactivated","posesujem")
			else:
				emit_signal("deactivated")
			change_controlled_char()

	signal_was_used = false

# Read by godot-mcp's runtime-state digest: enough to tell why a switch did or
# did not fire without scripting a probe for each field.
func _mcp_state() -> Dictionary:
	return {
		"switch_state": switch_state,
		"what_to_posses": what_to_posses,
		"interact_group": interact_group,
		"requires_item_id": requires_item_id,
		"repeatable_action": repeatable_action,
		"was_used": was_used,
		"player_inside": player_inside,
		"position": [global_position.x, global_position.y],
	}

func play_animation(anim_name: String):
	if has_node("AnimationPlayer"):
		var anim = get_node("AnimationPlayer")
		if anim.has_animation(anim_name):
			anim.play(anim_name)
			
func change_controlled_char():
	if what_to_posses == "":
		return
	var old_char = Global.controlled_char
	old_char.remove_from_group("player")
	old_char.velocity = Vector2.ZERO
	await get_tree().process_frame
	var what_possesing = get_tree().get_first_node_in_group(what_to_posses)
	if what_possesing == null:
		push_warning("Switch %s: no node in group '%s' to possess." % [name, what_to_posses])
		old_char.add_to_group("player")
		return
	# The character stays where it is in the level; only who the player wears
	# changes. Possession used to reparent it to /root/main, which is what let two
	# same-named characters collide.
	Global.main._give_control_to(what_possesing)
	what_possesing.is_level_default_character = false
	which_anim_to_play()

func which_anim_to_play():
	if what_to_posses != "":
		var in_possession_mode = Global.controlled_char != null and not Global.controlled_char.is_level_default_character
		if in_possession_mode:
			play_animation(animation_active)
		else:
			play_animation(animation_not_active)
	elif switch_state:
		play_animation(animation_active)
	else:
		play_animation(animation_not_active)

func _on_platform_running(posesujem: String = "neposesujem"):
	if posesujem == "posesujem":
		signal_was_used = true
	switch_switch(true)
	if posesujem == "posesujem":
		signal_was_used = false
	
func _on_platform_disabled(posesujem: String = "neposesujem"):
	if posesujem == "posesujem":
		signal_was_used = true
	switch_switch(false)
	if posesujem == "posesujem":
		signal_was_used = false

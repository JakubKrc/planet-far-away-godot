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
var was_used: bool = false
var signal_was_used = false

signal activated
signal deactivated

func _ready():
	area2d.connect("body_entered", Callable(self, "_on_body_entered"))
	area2d.connect("body_exited", Callable(self, "_on_body_exited"))
	which_anim_to_play()
	if use_signal && switch_state:
		call_deferred("_emit_initial")

func _emit_initial():
	emit_signal("activated")

func _process(_delta):
	if what_to_posses:
		which_anim_to_play()

func _on_body_entered(body):
	if body.is_in_group(interact_group):  
		player_inside = true

func _on_body_exited(body):
	if body.is_in_group(interact_group):
		player_inside = false

func _input(event):

	if player_inside and event.is_action_pressed("use"):
		for body in area2d.get_overlapping_bodies():
			if body.is_in_group("player"):
				if requires_item_id != "":
					var inv = body.get_node_or_null("InventoryComponent") as InventoryComponent
					var has_it = inv.has_id(requires_item_id) if inv else Global.inv_has(requires_item_id)
					if not has_it:
						Global.notify(requires_message if requires_message != "" else "Required item missing")
						return
				if what_to_posses:
					switch_switch(true)
				elif switch_state:
					switch_switch(false)
				else:
					switch_switch(true)

func switch_switch(set_to: bool):
	if !repeatable_action && was_used:
		return
	if what_to_posses and set_to:
		var target = get_tree().get_first_node_in_group(what_to_posses)
		if target != null and target.is_in_group("player"):
			return
	was_used=true
	if !repeatable_action:
		get_node("Switch_area").remove_from_group("interactable")
	
	if set_to==true:
		switch_state=true
		which_anim_to_play()
		if (!signal_was_used):
			signal_was_used=true
			
			if (what_to_posses):
				emit_signal("activated","posesujem")
			else:
				emit_signal("activated")
				print("activated neposesujem")
							
			change_controlled_char()
			
	if set_to==false:
		switch_state=false
		which_anim_to_play()
		if (!signal_was_used):
			signal_was_used=true
			print("deaktivujem")
			if (what_to_posses):
				emit_signal("deactivated","posesujem")
			else:
				emit_signal("deactivated")
			change_controlled_char()

	signal_was_used = false

func play_animation(anim_name: String):
	if has_node("AnimationPlayer"):
		var anim = get_node("AnimationPlayer")
		if anim.has_animation(anim_name):
			anim.play(anim_name)
			
func change_controlled_char():
	if what_to_posses:
		var old_char = Global.controlled_char
		old_char.remove_from_group("player")
		old_char.velocity = Vector2.ZERO
		await get_tree().process_frame;
		var what_possesing = get_tree().get_first_node_in_group(what_to_posses)
		if what_possesing:
			Global.controlled_char = what_possesing
			Global.controlled_char.add_to_group("player")
					
		Global.controlled_char.get_parent().remove_child(Global.controlled_char)
		get_node("/root/main").add_child(Global.controlled_char)
		Global.main.enable_node(Global.controlled_char)
		which_anim_to_play()

func which_anim_to_play():
	if what_to_posses:
		var in_possession_mode = Global.controlled_char != null and not Global.controlled_char.is_default_char
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

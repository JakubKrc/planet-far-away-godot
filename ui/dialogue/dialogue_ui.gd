extends CanvasLayer

@onready var panel = $Panel
@onready var speaker_label = $Panel/Margin/VBox/Speaker
@onready var text_label = $Panel/Margin/VBox/Text
@onready var choices_container = $Panel/Margin/VBox/Choices

var _data: Dictionary = {}
var _current_id: String = ""
var _choices: Array = []
var _selection: int = 0

func _ready():
	Global.dialogue = self
	hide()

func start(json_path: String):
	if json_path == "":
		return
	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Dialogue: file not found: " + json_path)
		return
	_data = JSON.parse_string(file.get_as_text())
	file.close()
	if _data == null:
		push_error("Dialogue: invalid JSON: " + json_path)
		return
	Global.can_player_move = false
	show()
	_show_node("start")

func _show_node(id: String):
	_current_id = id
	var node: Dictionary = _data.get(id, {})
	if node.is_empty():
		_end()
		return
	speaker_label.text = node.get("speaker", "")
	text_label.text = node.get("text", "")
	# Filter choices by inventory conditions
	_choices = []
	for choice in node.get("choices", []):
		if _check_conditions(choice):
			_choices.append(choice)
	# Rebuild choice labels
	for child in choices_container.get_children():
		child.queue_free()
	if _choices.is_empty():
		var lbl = Label.new()
		lbl.text = "[ continue ]"
		lbl.add_theme_font_size_override("font_size", 7)
		choices_container.add_child(lbl)
	else:
		for choice in _choices:
			var lbl = Label.new()
			lbl.text = choice["text"]
			lbl.add_theme_font_size_override("font_size", 7)
			choices_container.add_child(lbl)
	_selection = 0
	_update_selection()

func _check_conditions(choice: Dictionary) -> bool:
	for item_id in choice.get("requires", {}):
		if not Global.inv_has(item_id, int(choice["requires"][item_id])):
			return false
	for item_id in choice.get("requires_not", {}):
		if Global.inv_has(item_id, int(choice["requires_not"][item_id])):
			return false
	return true

func _update_selection():
	var children = choices_container.get_children()
	for i in children.size():
		children[i].modulate = Color(1, 1, 0) if i == _selection else Color(1, 1, 1)

func _process(_delta):
	if not visible:
		return
	var count = choices_container.get_child_count()
	if count == 0:
		return
	if Input.is_action_just_pressed("ui_down"):
		_selection = (_selection + 1) % count
		_update_selection()
	if Input.is_action_just_pressed("ui_up"):
		_selection = (_selection - 1 + count) % count
		_update_selection()
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("use"):
		_advance()

func _advance():
	if _choices.is_empty():
		_end()
		return
	var choice = _choices[_selection]
	for item_id in choice.get("gives", {}):
		Global.inv_add(item_id, int(choice["gives"][item_id]))
	for item_id in choice.get("removes", {}):
		Global.inv_remove(item_id, int(choice["removes"][item_id]))
	var next = choice.get("next", null)
	if next == null or next == "":
		_end()
	else:
		_show_node(str(next))

func _end():
	hide()
	Global.can_player_move = true

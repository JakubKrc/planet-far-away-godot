extends CanvasLayer

# Layout
const CELL        = 16
const EQUIP_SLOT  = 32
const PAD         = 8
const EQUIP_GAP   = 4
const SEP         = 6    # gap between equip and grid; between dual grids

# Colors
const C_BG        = Color(0.08, 0.08, 0.12, 0.96)
const C_BORDER    = Color(0.45, 0.45, 0.55)
const C_CELL      = Color(0.18, 0.18, 0.25)
const C_CELL_OK   = Color(0.25, 0.40, 0.30)
const C_CELL_BAD  = Color(0.40, 0.20, 0.20)
const C_EQUIP     = Color(0.22, 0.22, 0.32)
const C_EQUIP_HOV = Color(0.32, 0.42, 0.52)
const C_ITEM      = Color(0.45, 0.65, 0.45)
const C_ITEM_DRAG = Color(0.45, 0.65, 0.45, 0.65)
const C_TXT       = Color(1.0, 1.0, 1.0)
const C_TXT_DIM   = Color(0.7, 0.7, 0.7)
const C_TIP_BG    = Color(0.06, 0.06, 0.10, 0.98)

# State
var _primary:   InventoryComponent = null
var _secondary: InventoryComponent = null   # chest / NPC (optional)
var _equipment: EquipmentComponent = null

var _drag_item:   ItemData = null
var _drag_src:    String   = ""   # "primary" | "secondary" | "equip"
var _drag_src_slot: int = -1
var _drag_offset: Vector2 = Vector2.ZERO      # pixel offset for smooth ghost drawing
var _drag_cell_offset: Vector2i = Vector2i.ZERO  # which cell of the item was grabbed

var _mouse: Vector2
var _hover_tip: ItemData = null

# Layout rects (computed in open())
var _panel:       Rect2
var _pri_origin:  Vector2
var _sec_origin:  Vector2   # valid only in dual mode
var _equip_rects: Array     # [Rect2] x 4
var _dual:        bool = false

signal item_thrown(item: ItemData, world_pos: Vector2)

var _control: Control

func _ready():
	Global.inventory_ui = self
	_control = Control.new()
	_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_control.draw.connect(_on_draw)
	add_child(_control)
	hide()

# ── Open / close ──────────────────────────────────────────────────

func open(primary: InventoryComponent, secondary: InventoryComponent = null):
	_primary   = primary
	_secondary = secondary
	var eq = primary.get_parent().get_node_or_null("EquipmentComponent") as EquipmentComponent
	_equipment = eq if (eq != null and eq.active) else null
	_dual      = secondary != null
	_compute_layout()
	show()
	Global.can_player_move = false
	_control.queue_redraw()

func close():
	if _drag_item:
		_cancel_drag()
	hide()
	Global.can_player_move = true
	_primary = null
	_secondary = null
	_equipment = null

# ── Layout ────────────────────────────────────────────────────────

func _compute_layout():
	var equip_cols = 2
	var equip_rows = 2
	var eq_w = equip_cols * EQUIP_SLOT + (equip_cols - 1) * EQUIP_GAP
	var eq_h = equip_rows * EQUIP_SLOT + (equip_rows - 1) * EQUIP_GAP
	var grid_w = _primary.cols * CELL
	var grid_h = _primary.rows * CELL
	var panel_h = max(eq_h, grid_h) + PAD * 2

	var panel_w: int
	if _dual:
		var sec_w = _secondary.cols * CELL
		panel_w = PAD + eq_w + SEP + grid_w + SEP + sec_w + PAD
	else:
		panel_w = PAD + eq_w + SEP + grid_w + PAD

	var vp = Vector2(320, 240)
	var pp = ((vp - Vector2(panel_w, panel_h)) / 2.0).floor()
	_panel = Rect2(pp, Vector2(panel_w, panel_h))

	var eq_origin = pp + Vector2(PAD, (panel_h - eq_h) / 2.0).floor()
	_equip_rects = []
	for i in 4:
		@warning_ignore("integer_division")
		var row = i / equip_cols
		var col = i % equip_cols
		_equip_rects.append(Rect2(
			eq_origin + Vector2(col * (EQUIP_SLOT + EQUIP_GAP),
								row * (EQUIP_SLOT + EQUIP_GAP)),
			Vector2(EQUIP_SLOT, EQUIP_SLOT)))

	_pri_origin = pp + Vector2(PAD + eq_w + SEP,
							   (panel_h - grid_h) / 2.0).floor()

	if _dual:
		_sec_origin = _pri_origin + Vector2(grid_w + SEP, 0.0)

# ── Pickup (from ground) ──────────────────────────────────────────

func pick_up(item: ItemData) -> bool:
	var target = _primary
	if target == null:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			target = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if target == null:
		return false
	var pos = target.find_free_slot(item)
	if pos == Vector2i(-1, -1):
		return false
	target.place(item, pos)
	if visible:
		_control.queue_redraw()
	return true

# ── Input ─────────────────────────────────────────────────────────

func _input(event: InputEvent):
	# Toggle with I / Tab even when closed
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_I or event.physical_keycode == KEY_TAB:
			if visible:
				close()
			else:
				var player = get_tree().get_first_node_in_group("player")
				if player and player.is_on_floor():
					var inv = player.get_node_or_null("InventoryComponent")
					if inv:
						open(inv)
			get_viewport().set_input_as_handled()
			return

	if not visible:
		return

	if event is InputEventMouseMotion:
		_mouse = event.position
		_update_hover()
		_control.queue_redraw()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_down(event.position)
			else:
				_lmb_up(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_rmb(event.position)

# ── Hover ─────────────────────────────────────────────────────────

func _update_hover():
	_hover_tip = null
	var gp = _grid_pos(_mouse, _primary, _pri_origin)
	if gp != Vector2i(-1, -1):
		_hover_tip = _primary.get_at(gp)
		return
	if _dual:
		var gp2 = _grid_pos(_mouse, _secondary, _sec_origin)
		if gp2 != Vector2i(-1, -1):
			_hover_tip = _secondary.get_at(gp2)
			return
	var es = _equip_slot(_mouse)
	if es >= 0 and _equipment:
		_hover_tip = _equipment.equipped[es]

# ── Drag ──────────────────────────────────────────────────────────

func _pick_from(item: ItemData, src: String, slot: int = -1):
	_drag_item     = item
	_drag_src      = src
	_drag_src_slot = slot

func _cancel_drag():
	if _drag_item == null:
		return
	# Return to source
	if _drag_src == "primary":
		var pos = _primary.find_free_slot(_drag_item)
		if pos != Vector2i(-1, -1):
			_primary.place(_drag_item, pos)
	elif _drag_src == "secondary" and _secondary:
		var pos = _secondary.find_free_slot(_drag_item)
		if pos != Vector2i(-1, -1):
			_secondary.place(_drag_item, pos)
	elif _drag_src == "equip" and _equipment:
		_equipment.equipped[_drag_src_slot] = _drag_item
	_drag_item = null
	_control.queue_redraw()

func _lmb_down(mouse: Vector2):
	# Pick from primary grid
	var gp = _grid_pos(mouse, _primary, _pri_origin)
	if gp != Vector2i(-1, -1):
		var item = _primary.get_at(gp)
		if item:
			var item_pos = _primary.get_pos(item)
			_drag_offset = mouse - (_pri_origin + Vector2(item_pos) * CELL)
			_drag_cell_offset = gp - item_pos
			_primary.remove(item)
			_pick_from(item, "primary")
			_control.queue_redraw()
			return
	# Pick from secondary grid
	if _dual:
		var gp2 = _grid_pos(mouse, _secondary, _sec_origin)
		if gp2 != Vector2i(-1, -1):
			var item = _secondary.get_at(gp2)
			if item:
				var item_pos = _secondary.get_pos(item)
				_drag_offset = mouse - (_sec_origin + Vector2(item_pos) * CELL)
				_drag_cell_offset = gp2 - item_pos
				_secondary.remove(item)
				_pick_from(item, "secondary")
				_control.queue_redraw()
				return
	# Pick from equipment slot
	var es = _equip_slot(mouse)
	if es >= 0 and _equipment:
		var item = _equipment.equipped[es]
		if item:
			_drag_offset = mouse - _equip_rects[es].position
			_drag_cell_offset = Vector2i.ZERO
			_equipment.unequip(es)
			_pick_from(item, "equip", es)
			_control.queue_redraw()

func _lmb_up(mouse: Vector2):
	if _drag_item == null:
		return
	var item = _drag_item
	_drag_item = null

	# Try drop on primary grid — cell under mouse minus which cell was grabbed
	var cell = _grid_pos(mouse, _primary, _pri_origin)
	var gp = cell - _drag_cell_offset if cell != Vector2i(-1, -1) else Vector2i(-1, -1)
	if gp != Vector2i(-1, -1):
		var target = _primary.get_at(gp)
		if target != null and target != item:
			var result = _primary.try_combine(item, target)
			if result:
				_primary.remove(target)
				var rpos = _primary.find_free_slot(result)
				if rpos != Vector2i(-1, -1):
					_primary.place(result, rpos)
			else:
				_return_or_throw(item)
		elif _primary.can_place(item, gp):
			_primary.place(item, gp)
		else:
			_return_or_throw(item)
		_control.queue_redraw()
		return

	# Try drop on secondary grid
	if _dual:
		var cell2 = _grid_pos(mouse, _secondary, _sec_origin)
		var gp2 = cell2 - _drag_cell_offset if cell2 != Vector2i(-1, -1) else Vector2i(-1, -1)
		if gp2 != Vector2i(-1, -1):
			var target = _secondary.get_at(gp2)
			if target != null and target != item:
				var result = _primary.try_combine(item, target)
				if result:
					_secondary.remove(target)
					var rpos = _primary.find_free_slot(result)
					if rpos != Vector2i(-1, -1):
						_primary.place(result, rpos)
				else:
					_return_or_throw(item)
			elif _secondary.can_place(item, gp2):
				_secondary.place(item, gp2)
			else:
				_return_or_throw(item)
			_control.queue_redraw()
			return

	# Try equipment slot
	var es = _equip_slot(mouse)
	if es >= 0 and _equipment:
		if _equipment.can_equip(item):
			var displaced = _equipment.equip(item, es)
			if displaced:
				var pos = _primary.find_free_slot(displaced)
				if pos != Vector2i(-1, -1):
					_primary.place(displaced, pos)
				else:
					_throw(displaced)
		else:
			_return_or_throw(item)
		_control.queue_redraw()
		return

	# Outside panel → throw
	if not _panel.has_point(mouse):
		_throw(item)
	else:
		_return_or_throw(item)
	_control.queue_redraw()

func _return_or_throw(item: ItemData):
	var pos = _primary.find_free_slot(item)
	if pos != Vector2i(-1, -1):
		_primary.place(item, pos)
	else:
		_throw(item)

func _throw(item: ItemData):
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		emit_signal("item_thrown", item, Vector2.ZERO)
		return
	var feet_y = 0.0
	var col = player.get_node_or_null("CollisionShape2D")
	if col and col.shape is RectangleShape2D:
		feet_y = (col.shape as RectangleShape2D).size.y / 2.0
	var item_half_h = 0.0
	var tex = item.get_world_texture()
	if tex:
		item_half_h = tex.get_height() / 2.0
	emit_signal("item_thrown", item, player.global_position + Vector2(0, feet_y - item_half_h + 2))

# Right-click: drop item to ground
func _rmb(mouse: Vector2):
	var gp = _grid_pos(mouse, _primary, _pri_origin)
	if gp != Vector2i(-1, -1):
		var item = _primary.get_at(gp)
		if item:
			_primary.remove(item)
			_throw(item)
			_control.queue_redraw()
		return
	if _dual:
		var gp2 = _grid_pos(mouse, _secondary, _sec_origin)
		if gp2 != Vector2i(-1, -1):
			var item = _secondary.get_at(gp2)
			if item:
				_secondary.remove(item)
				_throw(item)
				_control.queue_redraw()
			return
	var es = _equip_slot(mouse)
	if es >= 0 and _equipment:
		var item = _equipment.unequip(es)
		if item:
			_throw(item)
		_control.queue_redraw()

# ── Coordinate helpers ────────────────────────────────────────────

func _grid_pos(mouse: Vector2, inv: InventoryComponent, origin: Vector2) -> Vector2i:
	var rel = mouse - origin
	if rel.x < 0 or rel.y < 0:
		return Vector2i(-1, -1)
	var gx = int(rel.x / CELL)
	var gy = int(rel.y / CELL)
	if gx >= inv.cols or gy >= inv.rows:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)

func _equip_slot(mouse: Vector2) -> int:
	for i in _equip_rects.size():
		if _equip_rects[i].has_point(mouse):
			return i
	return -1

# ── Drawing ───────────────────────────────────────────────────────

func _on_draw():
	if _primary == null:
		return
	_draw_panel()
	_draw_equip_slots()
	_draw_grid(_primary, _pri_origin)
	if _dual:
		_draw_grid(_secondary, _sec_origin)
	_draw_items_in_inv(_primary, _pri_origin)
	if _dual:
		_draw_items_in_inv(_secondary, _sec_origin)
	_draw_equipped()
	_draw_drag_ghost()
	_draw_tooltip()

func _draw_panel():
	_control.draw_rect(_panel, C_BG)
	_control.draw_rect(_panel, C_BORDER, false)
	# Separator after equip area
	if _equip_rects.size() > 0:
		var sep_x = _pri_origin.x - SEP / 2.0
		_control.draw_line(
			Vector2(sep_x, _panel.position.y + PAD),
			Vector2(sep_x, _panel.end.y - PAD),
			C_BORDER)
	# Separator between dual grids
	if _dual:
		var sep_x2 = _sec_origin.x - SEP / 2.0
		_control.draw_line(
			Vector2(sep_x2, _panel.position.y + PAD),
			Vector2(sep_x2, _panel.end.y - PAD),
			C_BORDER)

func _draw_equip_slots():
	for i in _equip_rects.size():
		var eq_item = _equipment.equipped[i] if _equipment else null
		var hov = _equip_slot(_mouse) == i
		_control.draw_rect(_equip_rects[i], C_EQUIP_HOV if hov else C_EQUIP)
		_control.draw_rect(_equip_rects[i], C_BORDER, false)
		if eq_item:
			_draw_item_in_rect(eq_item, _equip_rects[i])
		else:
			_control.draw_string(ThemeDB.fallback_font,
				_equip_rects[i].position + Vector2(2, 10),
				str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
				C_TXT * Color(1, 1, 1, 0.3))

func _draw_grid(inv: InventoryComponent, origin: Vector2):
	# When dragging, top-left = cell under mouse minus which cell was grabbed
	var tl = Vector2i(-1, -1)
	if _drag_item != null:
		var c = _grid_pos(_mouse, inv, origin)
		if c != Vector2i(-1, -1):
			tl = c - _drag_cell_offset
	for gy in inv.rows:
		for gx in inv.cols:
			var rect = Rect2(origin + Vector2(gx * CELL, gy * CELL), Vector2(CELL, CELL))
			var col = C_CELL
			if _drag_item != null and tl != Vector2i(-1, -1):
				if gx >= tl.x and gx < tl.x + _drag_item.grid_size.x and \
				   gy >= tl.y and gy < tl.y + _drag_item.grid_size.y:
					col = C_CELL_OK if inv.can_place(_drag_item, tl) else C_CELL_BAD
			_control.draw_rect(rect, col)
			_control.draw_rect(rect, C_BORDER, false)

func _draw_items_in_inv(inv: InventoryComponent, origin: Vector2):
	for item in inv.all_items():
		var pos = inv.get_pos(item)
		var rect = Rect2(
			origin + Vector2(pos.x * CELL, pos.y * CELL),
			Vector2(item.grid_size.x * CELL, item.grid_size.y * CELL))
		_draw_item_in_rect(item, rect)

func _draw_equipped():
	if _equipment == null:
		return
	for i in _equipment.equipped.size():
		var item = _equipment.equipped[i]
		if item:
			_draw_item_in_rect(item, _equip_rects[i])

func _draw_item_in_rect(item: ItemData, rect: Rect2):
	var tex = item.get_icon()
	if tex:
		var icon_size = tex.get_size()
		if icon_size.x <= rect.size.x and icon_size.y <= rect.size.y:
			var pos = (rect.position + (rect.size - icon_size) / 2.0).floor()
			_control.draw_texture(tex, pos)
		else:
			_control.draw_texture_rect(tex, rect, false)
	else:
		_control.draw_rect(rect.grow(-1), C_ITEM)
	if not tex:
		var max_chars = int(rect.size.x / 5)
		var label = item.item_name.substr(0, max_chars)
		_control.draw_string(ThemeDB.fallback_font,
			rect.position + Vector2(1, 8),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, C_TXT)

func _draw_drag_ghost():
	if _drag_item == null:
		return
	var size = Vector2(_drag_item.grid_size) * CELL
	var rect = Rect2(_mouse - _drag_offset, size)
	var tex = _drag_item.get_icon()
	if tex:
		_control.draw_texture_rect(tex, rect, false, C_ITEM_DRAG)
	else:
		_control.draw_rect(rect, C_ITEM_DRAG)

func _draw_tooltip():
	var tip = _hover_tip
	if tip == null or _drag_item != null:
		return
	var lines: Array = [tip.item_name]
	if tip.is_wearable:
		var type_tag = tip.item_type if tip.item_type != "" else "wearable"
		lines.append("[" + type_tag + "]")
	if tip.description != "":
		lines.append(tip.description)
	var font = ThemeDB.fallback_font
	var fs = 7
	var lh = 9
	var max_w = 0.0
	for l in lines:
		max_w = max(max_w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var tip_size = Vector2(max_w + 6, lines.size() * lh + 4)
	var tip_pos  = _mouse + Vector2(10, -tip_size.y - 2)
	tip_pos.x = clamp(tip_pos.x, 0, 320 - tip_size.x)
	tip_pos.y = clamp(tip_pos.y, 0, 240 - tip_size.y)
	_control.draw_rect(Rect2(tip_pos, tip_size), C_TIP_BG)
	_control.draw_rect(Rect2(tip_pos, tip_size), C_BORDER, false)
	for i in lines.size():
		_control.draw_string(font,
			tip_pos + Vector2(3, (i + 1) * lh),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TXT)

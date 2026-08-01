class_name InventoryComponent
extends Node

@export var cols: int = 8
@export var rows: int = 6
@export var starting_items: Array[ItemData] = []

var _grid: Array = []        # [row][col] = ItemData or null
var _placements: Dictionary = {}  # ItemData -> Vector2i (top-left)

func _ready():
	_init_grid()
	add_starting_items(starting_items)

# Places authored items. Each one is copied so several slots can hold the same
# .tres — see ItemData.make_unique_copy().
func add_starting_items(items: Array[ItemData]):
	for item in items:
		if item == null:
			continue
		var copy = item.make_unique_copy()
		var pos = find_free_slot(copy)
		if pos == Vector2i(-1, -1):
			push_warning("%s: no room for starting item '%s'" % [get_parent().name, copy.id])
			continue
		place(copy, pos)

# Changes the grid dimensions and re-places whatever fits. Needed because a parent
# can only set cols/rows after this node's _ready() has already built the grid.
func resize_grid(new_cols: int, new_rows: int):
	var previous_items = all_items()
	cols = new_cols
	rows = new_rows
	_init_grid()
	for item in previous_items:
		var pos = find_free_slot(item)
		if pos == Vector2i(-1, -1):
			push_warning("%s: item '%s' does not fit after resize and was dropped" % [get_parent().name, item.id])
			continue
		place(item, pos)

func _init_grid():
	_grid.clear()
	_placements.clear()
	_grid.resize(rows)
	for i in rows:
		_grid[i] = []
		_grid[i].resize(cols)
		_grid[i].fill(null)

func can_place(item: ItemData, pos: Vector2i) -> bool:
	for dy in item.grid_size.y:
		for dx in item.grid_size.x:
			var gx = pos.x + dx
			var gy = pos.y + dy
			if gx < 0 or gx >= cols or gy < 0 or gy >= rows:
				return false
			var cell = _grid[gy][gx]
			if cell != null and cell != item:
				return false
	return true

func place(item: ItemData, pos: Vector2i):
	if _placements.has(item):
		_clear_cells(item)
	for dy in item.grid_size.y:
		for dx in item.grid_size.x:
			_grid[pos.y + dy][pos.x + dx] = item
	_placements[item] = pos

func remove(item: ItemData):
	_clear_cells(item)
	_placements.erase(item)

func _clear_cells(item: ItemData):
	for gy in rows:
		for gx in cols:
			if _grid[gy][gx] == item:
				_grid[gy][gx] = null

func get_at(pos: Vector2i) -> ItemData:
	if pos.x < 0 or pos.x >= cols or pos.y < 0 or pos.y >= rows:
		return null
	return _grid[pos.y][pos.x]

func get_pos(item: ItemData) -> Vector2i:
	return _placements.get(item, Vector2i(-1, -1))

func has_item(item: ItemData) -> bool:
	return _placements.has(item)

func all_items() -> Array:
	return _placements.keys()

func find_free_slot(item: ItemData) -> Vector2i:
	for gy in rows:
		for gx in cols:
			var pos = Vector2i(gx, gy)
			if can_place(item, pos):
				return pos
	return Vector2i(-1, -1)

func try_combine(item_a: ItemData, item_b: ItemData) -> ItemData:
	var recipe_result = item_a.combine_with.get(item_b.id, null)
	if recipe_result == null:
		return null
	# The recipe holds a shared resource; the crafted item needs its own copy.
	return recipe_result.make_unique_copy()

# --- Simple id-based helpers (for quest/dialogue items) ---

func has_id(id: String, amount: int = 1) -> bool:
	var count = 0
	for item in _placements:
		if item.id == id:
			count += 1
			if count >= amount:
				return true
	return false

func remove_by_id(id: String, amount: int = 1):
	var removed = 0
	for item in _placements.keys():
		if item.id == id and removed < amount:
			remove(item)
			removed += 1

# --- Serialization ---

func serialize() -> Array:
	var out = []
	for item in _placements:
		var path = item.get_source_path()
		if path != "":
			var pos = _placements[item]
			out.append({"path": path, "pos": [pos.x, pos.y]})
	return out

func deserialize(data: Array):
	_init_grid()
	for entry in data:
		var stored_item = load(entry["path"]) as ItemData
		if stored_item == null:
			continue
		var item = stored_item.make_unique_copy()
		var pos = Vector2i(entry["pos"][0], entry["pos"][1])
		# A save written when the grid was larger can point outside it.
		if not can_place(item, pos):
			pos = find_free_slot(item)
		if pos == Vector2i(-1, -1):
			push_warning("%s: saved item '%s' no longer fits and was dropped" % [get_parent().name, item.id])
			continue
		place(item, pos)

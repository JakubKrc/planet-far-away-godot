class_name EquipmentComponent
extends Node

# The inventory screen has room for at most this many equip slots.
const MAX_SLOTS = 4

@export_range(0, MAX_SLOTS) var slots: int = MAX_SLOTS
@export var active: bool = true  # false = has gear but bonuses don't apply (NPC, enemy)

var equipped: Array = []  # [ItemData or null] x slots

func _ready():
	rebuild_slots()

# Clamps `slots` to what the UI can draw and resizes the array to match, so the
# two can never disagree. Clears whatever was equipped.
func rebuild_slots():
	slots = clampi(slots, 0, MAX_SLOTS)
	equipped.resize(slots)
	equipped.fill(null)

func can_equip(item: ItemData) -> bool:
	if not item.is_wearable:
		return false
	for e in equipped:
		if e != null and e != item and e.item_type == item.item_type:
			return false
	return true

func equip(item: ItemData, slot: int) -> ItemData:
	var old = equipped[slot]
	equipped[slot] = item
	return old

func unequip(slot: int) -> ItemData:
	var item = equipped[slot]
	equipped[slot] = null
	return item

func slot_of(item: ItemData) -> int:
	for i in equipped.size():
		if equipped[i] == item:
			return i
	return -1

func first_free_slot() -> int:
	for i in equipped.size():
		if equipped[i] == null:
			return i
	return -1

func serialize() -> Array:
	var out = []
	for i in equipped.size():
		if equipped[i] == null:
			continue
		var path = equipped[i].get_source_path()
		if path != "":
			out.append({"slot": i, "path": path})
	return out

func deserialize(data: Array):
	rebuild_slots()
	for entry in data:
		var stored_item = load(entry["path"]) as ItemData
		if stored_item == null:
			continue
		var slot = int(entry["slot"])
		if slot < 0 or slot >= slots:
			continue
		equipped[slot] = stored_item.make_unique_copy()

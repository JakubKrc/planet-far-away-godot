class_name EquipmentComponent
extends Node

@export var slots: int = 4
@export var active: bool = true  # false = has gear but bonuses don't apply (NPC, enemy)

var equipped: Array = []  # [ItemData or null] x slots

func _ready():
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
	equipped.resize(slots)
	equipped.fill(null)
	for entry in data:
		var stored_item = load(entry["path"]) as ItemData
		if stored_item == null:
			continue
		var slot = int(entry["slot"])
		if slot < 0 or slot >= slots:
			continue
		equipped[slot] = stored_item.make_unique_copy()

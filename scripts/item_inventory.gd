class_name ItemInventory
extends RefCounted
signal changed
signal used(item_id: String, effect: Dictionary)
const SLOT_COUNT := 40
const HOTBAR_COUNT := 8
var database: ItemDatabase
var slots: Array[Dictionary] = []
var selected := 0
# Hotbar aliases refer to the single equipped instance; they are not item copies.
var hotbar_equipment: Dictionary = {}
var body: RefCounted
var equipment: Dictionary = {}
var equipment_slots: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment_slots.json"))
var quarantined_equipment: Dictionary = {}

func slot_key(index: int) -> String:
	var offset := index-SLOT_COUNT
	return str(equipment_slots[offset].id) if offset>=0 and offset<equipment_slots.size() else ""

func get_slot(index: int) -> Dictionary:
	if index>=0 and index<SLOT_COUNT:
		if slots[index].is_empty() and hotbar_equipment.has(str(index)):
			for value in equipment.values():
				if value.get("instance_id","")==hotbar_equipment[str(index)]: return value
		return slots[index]
	return equipment.get(slot_key(index),{})

func set_slot(index: int, value: Dictionary) -> void:
	if index<SLOT_COUNT:
		hotbar_equipment.erase(str(index))
		slots[index]=value
	else: equipment[slot_key(index)]=value

func accepts(index: int, value: Dictionary) -> bool:
	if index<0 or index>=SLOT_COUNT+equipment_slots.size(): return false
	if index<SLOT_COUNT or value.is_empty(): return true
	var d := database.item(str(value.get("item_id","")))
	return bool(d.get("equippable",false)) and d.get("equip_slot","")==slot_key(index) and equipment_slots[index-SLOT_COUNT].types.has(d.get("equipment_type","")) and int(value.get("count",0))==1

func has_capability(capability: String) -> bool:
	var held: Dictionary=equipment.get("main_hand",{})
	return not held.is_empty() and database.item(str(held.item_id)).get("capabilities",[]).has(capability)

func equip(index: int) -> bool:
	if index<0 or index>=SLOT_COUNT or get_slot(index).is_empty(): return false
	if slots[index].is_empty(): return true
	var key := str(database.item(str(slots[index].item_id)).get("equip_slot",""))
	for i in equipment_slots.size():
		if equipment_slots[i].id==key: return move_slot(index,SLOT_COUNT+i)
	return false

func unequip(index: int) -> bool:
	if index<SLOT_COUNT or get_slot(index).is_empty(): return false
	var value := get_slot(index)
	for key in hotbar_equipment.keys():
		if hotbar_equipment[key]==value.get("instance_id","") and slots[int(key)].is_empty(): return move_slot(index,int(key))
	for i in range(HOTBAR_COUNT,SLOT_COUNT):
		if slots[i].is_empty(): return move_slot(index,i)
	return false

func instance(id: String) -> Dictionary:
	return {"item_id":id,"count":1,"instance_id":str(ResourceUID.create_id()),"state":{},"durability":database.item(id).get("durability")}

func normalize_durability(value: Dictionary) -> bool:
	var maximum = database.item(str(value.get("item_id",""))).get("durability")
	if maximum==null: return true
	var current = value.get("durability")
	# Older tools explicitly stored null before durability existed.
	if current==null: value.durability=int(maximum);return true
	if not (current is int or current is float) or not is_finite(float(current)) or current!=floor(current) or current<1 or current>int(maximum): return false
	value.durability=int(current)
	return true

func wear_held(expected_id: String, capability: String) -> bool:
	var held: Dictionary=equipment.get("main_hand",{})
	if held.is_empty() or str(held.get("instance_id",""))!=expected_id or not has_capability(capability): return false
	if not normalize_durability(held): return false
	if held.get("durability")==null: return false
	held.durability=int(held.durability)-1
	if held.durability==0:
		equipment.erase("main_hand")
		for key in hotbar_equipment.keys():
			if hotbar_equipment[key]==expected_id: hotbar_equipment.erase(key)
	changed.emit()
	return true

func restore_equipment(data: Variant, quarantine: Variant = {}) -> bool:
	if not data is Dictionary or not quarantine is Dictionary: return false
	var seen := {}
	for value in slots:
		if value.has("instance_id"):
			if seen.has(str(value.instance_id)): return false
			seen[str(value.instance_id)]=true
	var next := {}
	var rejected: Dictionary=quarantine.duplicate(true)
	for key in data:
		var value = data[key]
		if not value is Dictionary: rejected[key]=value; continue
		if value.is_empty(): continue
		var index := -1
		for i in equipment_slots.size():
			if equipment_slots[i].id==key: index=SLOT_COUNT+i
		if index<0 or not accepts(index,value) or str(value.get("instance_id","")).is_empty() or not value.get("state",{}) is Dictionary:
			rejected[key]=value; continue
		if seen.has(str(value.instance_id)): return false
		seen[str(value.instance_id)]=true
		next[key]=value.duplicate(true)
		if not normalize_durability(next[key]): return false
		next[key].count=int(value.count)
	equipment=next
	quarantined_equipment=rejected
	return true

func _init(db: ItemDatabase) -> void:
	database = db
	for i in SLOT_COUNT: slots.append({})

func capacity(id: String) -> int:
	var definition := database.item(id)
	if definition.is_empty(): return 0
	var available := 0
	for i in range(SLOT_COUNT):
		var slot := slots[i]
		if i < HOTBAR_COUNT and slot.is_empty(): continue
		if slot.is_empty(): available += int(definition.max_stack)
		elif slot.item_id == id: available += int(definition.max_stack)-int(slot.count)
	return available

func count_item(id: String) -> int:
	# Physical storage only: equipped hotbar aliases never duplicate ingredients.
	var total := 0
	for value in slots:
		if value.get("item_id","")==id: total+=int(value.count)
	return total

func craft_exchange(materials: Dictionary, output_id: String, output_count: int, commit: bool = false) -> String:
	if output_count<1 or output_count>989901 or database.item(output_id).is_empty(): return "成品数量或定义无效"
	if materials.is_empty(): return "材料定义无效"
	for id in materials:
		if not materials[id] is int or materials[id]<1 or materials[id]>989901: return "材料数量无效"
		if database.item(str(id)).is_empty() or database.item(str(id)).get("equippable",false): return "材料定义无效"
		if count_item(str(id))<int(materials[id]): return "材料不足："+str(database.item(str(id)).name)
	# Entire operation is staged. No live signal/save can observe partial consumption.
	var staged := ItemInventory.new(database)
	staged.slots=slots.duplicate(true)
	for id in materials:
		var left := int(materials[id])
		for i in SLOT_COUNT:
			if staged.slots[i].get("item_id","")!=id: continue
			var take := mini(left,int(staged.slots[i].count))
			staged.slots[i].count-=take
			left-=take
			if int(staged.slots[i].count)==0: staged.slots[i]={}
			if left==0: break
	if staged.add(output_id,output_count)!=0: return "背包空间不足，无法放入全部成品"
	if commit:
		slots=staged.slots
		changed.emit()
	return ""

func add(id: String, count: int) -> int:
	if count <= 0 or database.item(id).is_empty(): return count
	var left := count
	var definition := database.item(id)
	var limit := int(definition.max_stack)
	for empty_pass in [false,true]:
		# Matching hotbar stacks first, then bag stacks; empty slots only in the bag.
		var first := HOTBAR_COUNT if empty_pass else 0
		for i in range(first,SLOT_COUNT):
			var slot := slots[i]
			if (slot.is_empty() and empty_pass) or (not empty_pass and not slot.is_empty() and slot.item_id == id):
				var amount := mini(left,limit-int(slot.get("count",0)))
				if amount > 0:
					if definition.get("equippable",false): slots[i]=instance(id)
					elif id=="field_lantern": slots[i]={"item_id":id,"count":1,"lamp_id":str(ResourceUID.create_id()),"fuel":1800.0}
					else: slots[i] = {"item_id":id,"count":int(slot.get("count",0))+amount}
				left -= amount
				if left == 0: break
		if left == 0: break
	if left != count: changed.emit()
	return left

func restore_hotbar_links(value: Variant) -> void:
	hotbar_equipment={}
	if not value is Dictionary: return
	var seen := {}
	for key in value:
		if not str(key).is_valid_int() or int(key)<0 or int(key)>=8 or not slots[int(key)].is_empty(): continue
		for item in equipment.values():
			var id := str(item.get("instance_id",""))
			if not id.is_empty() and id==str(value[key]) and not seen.has(id):
				hotbar_equipment[str(int(key))]=id;seen[id]=true

func equip_hotbar(from: int, to: int) -> bool:
	var source := slots[from]
	if source.is_empty() or not accepts(to,source): return false
	var previous := get_slot(to)
	var return_to := -1
	if not previous.is_empty():
		for key in hotbar_equipment:
			if hotbar_equipment[key]==previous.get("instance_id","") and slots[int(key)].is_empty(): return_to=int(key);break
	if not previous.is_empty() and return_to<0:
		if from>=8: return_to=from
		else:
			for i in range(8,40):
				if slots[i].is_empty(): return_to=i;break
		if return_to<0: return false
	slots[from]={}
	if not previous.is_empty(): slots[return_to]=previous
	for key in hotbar_equipment.keys():
		if hotbar_equipment[key]==previous.get("instance_id","") or int(key)==from: hotbar_equipment.erase(key)
	equipment[slot_key(to)]=source
	if from<8: hotbar_equipment[str(from)]=str(source.instance_id)
	changed.emit();return true

func move_slot(from: int, to: int) -> bool:
	if from==to or not accepts(from,{}) or not accepts(to,{}): return false
	var source := get_slot(from)
	var target := get_slot(to)
	if from<40 and not slots[from].is_empty() and to>=40 and database.item(str(source.get("item_id",""))).get("equippable",false): return equip_hotbar(from,to)
	if from<8 and slots[from].is_empty() and not source.is_empty():
		if to<8 and target.is_empty():
			hotbar_equipment.erase(str(from));hotbar_equipment[str(to)]=str(source.instance_id);changed.emit();return true
		for i in equipment_slots.size():
			if equipment.get(equipment_slots[i].id,{}).get("instance_id","")==source.get("instance_id"):
				var moved := move_slot(40+i,to)
				if moved: hotbar_equipment.erase(str(from))
				return moved
		return false
	if to<8 and slots[to].is_empty() and not target.is_empty():
		if from>=40 and source.get("instance_id","")==target.get("instance_id",""):
			hotbar_equipment.erase(str(to));slots[to]=source;equipment[slot_key(from)]={};changed.emit();return true
		return false
	if source.is_empty() or not accepts(to,source) or not accepts(from,target): return false
	if not target.is_empty() and source.item_id==target.item_id and not database.item(source.item_id).get("equippable",false):
		var amount := mini(int(source.count),int(database.item(source.item_id).max_stack)-int(target.count))
		if amount<=0: return false
		target.count+=amount
		source.count-=amount
		if int(source.count)==0: set_slot(from,{})
	else:
		set_slot(to,source)
		set_slot(from,target)
	changed.emit()
	return true

func use_slot(index: int) -> bool:
	if body!=null and body.sleep_active(): return false
	if index < 0 or index >= slots.size() or get_slot(index).is_empty(): return false
	var id := str(get_slot(index).item_id)
	if index<8 and database.item(id).get("equippable",false): return equip(index)
	var definition := database.item(id)
	if not definition.usable: return false
	if definition.use_action in ["light","place_campfire","place_sleeping_bag"]:
		used.emit(id,{"slot":index})
		return true
	if definition.use_action=="unpack":
		# Stage the complete operation; the freed source slot counts toward capacity.
		var staged := ItemInventory.new(database)
		staged.slots=slots.duplicate(true)
		staged.slots[index].count-=1
		if int(staged.slots[index].count)==0: staged.slots[index]={}
		for reward in definition.contents:
			if staged.add(reward,int(definition.contents[reward]))>0: return false
		slots=staged.slots
		changed.emit();used.emit(id,{})
		return true
	if definition.use_action != "eat": return false
	# One extensible effect contract, without hunger/health pressure.
	var effect: Dictionary = definition.get("effects",{}).duplicate(true)
	if body!=null and not body.can_eat(effect): return false
	if body!=null: body.eat(effect)
	if definition.consumable:
		slots[index].count -= 1
		if int(slots[index].count) == 0: slots[index] = {}
	changed.emit()
	used.emit(id,effect)
	return true

func split_slot(index: int, count: int) -> int:
	if index<0 or index>=slots.size() or slots[index].is_empty(): return -1
	if count<1 or count>=int(slots[index].count): return -1
	# New stacks go to bag storage; empty hotbar slots remain player-assigned.
	for target in range(HOTBAR_COUNT,SLOT_COUNT):
		if not slots[target].is_empty(): continue
		slots[target]={"item_id":slots[index].item_id,"count":count}
		slots[index].count-=count
		changed.emit()
		return target
	return -1

func destroy_slot(index: int) -> bool:
	if index<0 or index>=slots.size() or slots[index].is_empty(): return false
	# Destruction intentionally creates no world drop.
	slots[index]={}
	changed.emit()
	return true

func organized_bag_slots() -> Array[Dictionary]:
	# Only the 32 bag cells participate; hotbar assignments and equipped aliases stay put.
	var next: Array[Dictionary]=slots.duplicate(true)
	var packed: Array[Dictionary]=[]
	for i in range(HOTBAR_COUNT,SLOT_COUNT):
		if slots[i].is_empty(): continue
		var incoming: Dictionary=slots[i].duplicate(true)
		var definition := database.item(str(incoming.item_id))
		var limit := int(definition.get("max_stack",1))
		if limit>1 and not definition.get("equippable",false) and not incoming.has("instance_id") and not incoming.has("lamp_id"):
			var identity: Dictionary=incoming.duplicate(true);identity.erase("count")
			for existing in packed:
				var other: Dictionary=existing.duplicate(true);other.erase("count")
				if other!=identity: continue
				var moved := mini(int(incoming.count),limit-int(existing.count))
				existing.count+=moved;incoming.count-=moved
				if int(incoming.count)==0: break
		if int(incoming.count)>0: packed.append(incoming)
	var order := {"food":0,"material":1,"natural":2,"tool":3,"utility":4,"weapon":5,"headwear":6,"outfit":7}
	# Stable insertion sort preserves each unique instance's order within its item kind.
	for i in range(1,packed.size()):
		var current: Dictionary=packed[i]
		var key := "%02d:%s:%s"%[order.get(database.item(current.item_id).category,99),database.item(current.item_id).category,current.item_id]
		var j := i-1
		while j>=0:
			var previous: Dictionary=packed[j]
			var previous_key := "%02d:%s:%s"%[order.get(database.item(previous.item_id).category,99),database.item(previous.item_id).category,previous.item_id]
			if previous_key<=key: break
			packed[j+1]=previous;j-=1
		packed[j+1]=current
	for i in range(HOTBAR_COUNT,SLOT_COUNT): next[i]=packed[i-HOTBAR_COUNT] if i-HOTBAR_COUNT<packed.size() else {}
	return next

func restore(data: Variant) -> bool:
	if not data is Array or data.size() != SLOT_COUNT: return false
	var next: Array[Dictionary] = []
	for value in data:
		if not value is Dictionary: return false
		if value.is_empty(): next.append({}); continue
		var id := str(value.get("item_id",""))
		var definition := database.item(id)
		var count := int(value.get("count",0))
		if definition.is_empty() or count < 1 or count > int(definition.max_stack): return false
		if definition.get("equippable",false):
			var restored: Dictionary=value.duplicate(true)
			if not restored.has("instance_id"): restored=instance(id)
			if str(restored.instance_id).is_empty() or not restored.get("state",{}) is Dictionary: return false
			if not normalize_durability(restored): return false
			restored.count=count
			next.append(restored)
		elif id=="field_lantern":
			var fuel = value.get("fuel",1800.0)
			if not (fuel is float or fuel is int) or not is_finite(float(fuel)) or float(fuel)<0 or float(fuel)>1800: return false
			next.append({"item_id":id,"count":count,"lamp_id":str(value.get("lamp_id",ResourceUID.create_id())),"fuel":float(fuel)})
		else: next.append({"item_id":id,"count":count})
	slots = next
	changed.emit()
	return true

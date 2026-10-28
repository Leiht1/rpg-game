extends RefCounted
## Presentation only: no inventory, durability, depletion or persistent writes.
var pending: Dictionary={}
func begin(id: String, target: Node2D, action: String, player: Node2D) -> void:
	if not is_instance_valid(target) or target.get_meta("network_pending",false):return
	var entry:={"node":weakref(target),"modulate":target.modulate,"visible":target.visible,"action":action}
	match action:
		"chop":
			if not target.has_method("hit"):return
			target.hit()
			target.set_meta("network_preview_hits",int(target.get_meta("network_preview_hits",0))+1)
			AudioFX.play_sfx("sfx_chop_hit",target.position)
		"mine":
			if not target.has_method("feedback"):return
			target.feedback(player.position,false)
		"pickup":
			if not target.is_in_group("drops"):return
			target.hide()
		_:return
	pending[id]=entry
	if action=="pickup":target.set_meta("network_pending",true)
func finish(id: String, accepted: bool=false) -> void:
	if not pending.has(id):return
	var entry: Dictionary=pending[id];pending.erase(id)
	var target=entry.node.get_ref()
	if is_instance_valid(target):
		if entry.action=="chop" and not accepted:target.set_meta("network_preview_hits",maxi(0,int(target.get_meta("network_preview_hits",0))-1))
		target.modulate=entry.modulate
		if entry.action=="pickup":target.visible=entry.visible
		target.remove_meta("network_pending")
func clear() -> void:
	for id in pending.keys():finish(id)

extends Node
## Presentation only: CanvasItem visibility remains the authority for input/game logic.
const IN_SECONDS := 0.12
const OUT_SECONDS := 0.09
var entries: Dictionary = {}
var guarded := false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(added)

func added(node: Node) -> void:
	if node is Control or node is Window:call_deferred("watch",node)

# Deferred nodes may have been freed by an inventory UI rebuild before dispatch.
func watch(node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or node==get_tree().root:return
	if entries.has(node.get_instance_id()):return
	if node is Window:
		if node is Popup or node is AcceptDialog:
			entries[node.get_instance_id()]={"visible":node.visible,"tween":null,"alpha":1.0,"window":true}
			if not node.visibility_changed.is_connected(window_changed.bind(node)):node.visibility_changed.connect(window_changed.bind(node))
			if not node.about_to_popup.is_connected(window_open.bind(node)):node.about_to_popup.connect(window_open.bind(node))
			if not node.tree_exiting.is_connected(forget.bind(node.get_instance_id())):node.tree_exiting.connect(forget.bind(node.get_instance_id()))
		return
	# Watch local visibility, so nested sections do not animate again on ancestor changes.
	entries[node.get_instance_id()]={"visible":node.visible,"tween":null,"alpha":1.0,"window":false}
	if not node.visibility_changed.is_connected(changed.bind(node)):node.visibility_changed.connect(changed.bind(node))
	if not node.tree_exiting.is_connected(forget.bind(node.get_instance_id())):node.tree_exiting.connect(forget.bind(node.get_instance_id()))
	if (node is Panel or node is PanelContainer) and node.is_visible_in_tree():
		var ancestor: Node=node.get_parent()
		while ancestor is Control:
			if ancestor is Panel or ancestor is PanelContainer:return
			ancestor=ancestor.get_parent()
		entries[node.get_instance_id()].visible=false
		changed(node)

func forget(id: int) -> void:
	if entries.has(id):
		var tween: Tween=entries[id].tween
		if tween and tween.is_valid():tween.kill()
		entries.erase(id)

func changed(node: Control) -> void:
	var id := node.get_instance_id()
	if not entries.has(id):return
	var entry: Dictionary=entries[id]
	if entry.visible==node.visible:return
	entry.visible=node.visible
	var tween: Tween=entry.tween
	if tween and tween.is_valid():tween.kill()
	if node.visible:
		entry.alpha=0.0
		RenderingServer.canvas_item_set_modulate(node.get_canvas_item(),Color(node.modulate,0))
	else:
		# Keep only the renderer alive for the short exit; the actual Control is hidden.
		RenderingServer.canvas_item_set_visible(node.get_canvas_item(),true)
	tween=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	entry.tween=tween
	tween.tween_method(canvas_alpha.bind(node),float(entry.alpha),1.0 if node.visible else 0.0,IN_SECONDS if node.visible else OUT_SECONDS)
	tween.finished.connect(func():
		if is_instance_valid(node):
			RenderingServer.canvas_item_set_visible(node.get_canvas_item(),node.visible)
			RenderingServer.canvas_item_set_modulate(node.get_canvas_item(),node.modulate))

func canvas_alpha(value: float,node: Control) -> void:
	if not is_instance_valid(node):return
	entries[node.get_instance_id()].alpha=value
	RenderingServer.canvas_item_set_modulate(node.get_canvas_item(),Color(node.modulate,value*node.modulate.a))

func window_alpha(value: float,window: Window) -> void:
	if not is_instance_valid(window):return
	var entry: Dictionary=entries[window.get_instance_id()]
	entry.alpha=value
	if not entry.has("styles"):entry.styles={}
	if not entry.has("children"):entry.children={}
	for child in window.get_children():
		if child is CanvasItem:
			var id := child.get_instance_id()
			if not entry.children.has(id):entry.children[id]=child.modulate.a
			child.modulate.a=value*float(entry.children[id])
	# Window-owned paper (PopupMenu/ConfirmationDialog) needs the same opacity.
	for item in ["panel","embedded_border","embedded_unfocused_border"]:
		if window.has_theme_stylebox(item):
			if not entry.styles.has(item):entry.styles[item]=window.get_theme_stylebox(item).duplicate()
			var style: StyleBox=entry.styles[item].duplicate()
			if style is StyleBoxTexture:style.modulate_color.a*=value
			elif style is StyleBoxFlat:
				style.bg_color.a*=value;style.border_color.a*=value;style.shadow_color.a*=value
			window.add_theme_stylebox_override(item,style)

func window_open(window: Window) -> void:
	if guarded or not entries.has(window.get_instance_id()):return
	var entry: Dictionary=entries[window.get_instance_id()]
	entry.visible=true;entry["revision"]=int(entry.get("revision",0))+1
	call_deferred("animate_window",window,true,entry.revision)

func window_changed(window: Window) -> void:
	if guarded or not entries.has(window.get_instance_id()):return
	var entry: Dictionary=entries[window.get_instance_id()]
	var opening: bool=window.visible
	if entry.visible==opening:return
	entry.visible=opening
	entry["revision"]=int(entry.get("revision",0))+1
	call_deferred("animate_window",window,opening,entry.revision)

# A deferred reference may already be freed; validate it before typed conversion.
func animate_window(window,opening: bool,revision: int) -> void:
	if not is_instance_valid(window) or not entries.has(window.get_instance_id()):return
	var entry: Dictionary=entries[window.get_instance_id()]
	if entry.revision!=revision:return
	var tween: Tween=entry.tween
	if tween and tween.is_valid():tween.kill()
	if opening:entry.alpha=0.0
	else:
		guarded=true;window.show();guarded=false
	window.gui_disable_input=not opening
	window_alpha(float(entry.alpha),window)
	tween=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS);entry.tween=tween
	tween.tween_method(window_alpha.bind(window),float(entry.alpha),1.0 if opening else 0.0,IN_SECONDS if opening else OUT_SECONDS)
	if not opening:
		tween.finished.connect(func():
			if not is_instance_valid(window):return
			guarded=true;window.hide();guarded=false
			window.gui_disable_input=false
			window_alpha(1.0,window)
			for node in get_tree().get_nodes_in_group("ui_fade_input_owner"):node.update_input_block())

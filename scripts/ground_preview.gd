extends "res://scripts/world.gd"
var comparison_label:=Label.new()
func _ready()->void:
	super._ready()
	stream.preview_enabled=true
	stream.preview_center=generator.spawn
	stream.set_candidate(1)
	make_label(comparison_label,"",Vector2(26,82),16)
	update_comparison()
func update_comparison()->void:
	comparison_label.text="静态地面测试区 · 1 历史对照 / 2 静态地面 / 3 同版对照 · 当前：%s · 0 出生点 · 4 森林 / 5 山地 / 6 水岸"%["历史对照","静态地面（待验收）","静态地面（待验收）"][stream.candidate_mode]
func _unhandled_input(event:InputEvent)->void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
			stream.set_candidate(event.physical_keycode-KEY_1)
			update_comparison()
		if event.physical_keycode==KEY_0:
			stream.move_preview_center(generator.spawn)
			player.position=generator.spawn
			player.camera.reset_smoothing()
			stream.update_target(player.position)

		if event.physical_keycode in [KEY_4,KEY_5,KEY_6]:
			var p:=generator.spawn
			if event.physical_keycode==KEY_6:
				p=Vector2(generator.river_x(p.y)-240,p.y)
			else:
				var found:=false
				for radius in [800,1500,2500,3500,5000]:
					for i in 32:
						var q:Vector2=generator.spawn+Vector2.from_angle(i*TAU/32)*radius
						var v:=generator.sample(q)
						if v.z<.005 and ((event.physical_keycode==KEY_4 and v.x>.65) or (event.physical_keycode==KEY_5 and v.y>.55)):
							p=q;found=true;break
					if found:break
			stream.move_preview_center(p)
			player.position=p
			player.camera.reset_smoothing()
			stream.update_target(p)

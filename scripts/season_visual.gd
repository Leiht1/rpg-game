extends Node2D
## Sparse world-space flecks below sorted actors. Phase follows authority time.
const Rules=preload("res://scripts/season_rules.gd")
var world: Node2D
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
	if not is_instance_valid(world) or not world.started:return
	var sim=world.environment_view.simulation
	var date: Dictionary=sim.season_date()
	if int(date.index)==1:return
	var config: Dictionary=Rules.data.visual
	var cell := Vector2i(floor(world.player.position.x/800),floor(world.player.position.y/800))
	var phase: float=sim.season_elapsed_days()*1440
	var color := Color(Rules.data.seasons[date.index].color,float(config.ground_alpha))
	for yy in range(cell.y-1,cell.y+2):
		for xx in range(cell.x-1,cell.x+2):
			for i in int(config.ground_marks):
				var code := hash("%d:%d:%d:%d" %[world.world_seed,xx,yy,i])
				var at := Vector2(xx*800+posmod(code,800),yy*800+posmod(code/801,800))
				at+=Vector2(sin(phase*.04+i)*8,fposmod(phase*.5+i*9,60)-30)
				draw_circle(at,float(config.ground_radius)*(0.65 if int(date.index)==3 else 1.0),color)

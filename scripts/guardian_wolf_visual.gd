extends Node2D
## Presentation only: the final-chapter model owns position, combat and saves.
const WALK_SPEED := 70.0 / (0.68 * 1.9)
var animation_player: AnimationPlayer
var last_world := Vector2.ZERO
var has_world := false
var facing_right := true
var moving := false

func _ready() -> void:
	animation_player=get_node("AnimationPlayer")
	animation_player.play("side_idle")
	animation_player.advance(0)
	queue_redraw()

func update_motion(world_position: Vector2, state: Dictionary, delta: float) -> void:
	var motion := world_position-last_world if has_world else Vector2.ZERO
	var speed := motion.length()/maxf(delta,.0001) if has_world and motion.length()<128 else 0.0
	last_world=world_position;has_world=true
	var mode: String=state.get("mode","idle")
	moving=speed>1.0 and (mode=="chase" or mode=="active" and state.get("attack","")=="charge")
	if moving and absf(motion.x)>.01:
		facing_right=motion.x>0
	elif mode in ["windup","active"]:
		var direction: Dictionary=state.get("direction",{})
		var look_x: float=float(direction.get("x",0))
		if absf(look_x)>.1:facing_right=look_x>0
	scale=Vector2(1 if facing_right else -1,1)
	var clip: String="side_walk" if moving else "side_idle"
	if animation_player.current_animation!=clip:
		animation_player.play(clip)
		animation_player.advance(0)
	animation_player.speed_scale=speed/WALK_SPEED if moving else 1.0

func _draw() -> void:
	# Same ground shadow as the accepted preview, separate from the painted parts.
	draw_set_transform(Vector2(0,-2),0,Vector2(1,23.0/170.0))
	draw_circle(Vector2.ZERO,170,Color("52634c33"))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

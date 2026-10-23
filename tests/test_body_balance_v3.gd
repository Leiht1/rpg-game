extends SceneTree
func _initialize() -> void:
	var b=preload("res://scripts/body_state.gd").new()
	b.energy=0;b.sleeping=true;b.sleep_duration=240
	b.advance(1,60,false,false)
	assert(is_equal_approx(b.energy,25.0))
	b.advance(1,180,false,false)
	assert(is_equal_approx(b.energy,100))
	var c=preload("res://scripts/body_state.gd").new()
	c.health=1;c.rules=c.rules.duplicate(true);c.rules.hunger_per_day=0;c.rules.energy_per_hour=0
	c.advance(3600,3600,true,false)
	assert(c.health==100)
	var rates=preload("res://scripts/sleep_rules.gd")
	assert(rates.facility("sleeping_bag").rate==25 and rates.facility("straw_mat").rate==25.0 and rates.facility("wood_bed").rate==25.0)
	var legacy=preload("res://scripts/body_state.gd").new()
	legacy.energy=0;legacy.sleeping=true;legacy.sleep_duration=240;legacy.sleep_session={"source":"wood_bed","rate":17.0,"target":100}
	legacy.advance(1,60,false,false)
	assert(is_equal_approx(legacy.energy,25.0))
	var dead=preload("res://scripts/body_state.gd").new()
	dead.health=0;dead.down=true;dead.advance(1,1,false,false)
	assert(dead.health==0)
	print("BODY BALANCE: sleep four-hour full recovery, natural healing during activity, 2.5-day cap passed")
	quit()

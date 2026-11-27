extends SceneTree

const Match=preload("res://game/arena_match.gd")
const Arena=preload("res://game/arena.gd")
var fail:=false
func check(ok:bool,msg:String):
	if not ok:
		fail=true
		printerr("FAIL: ",msg)

func _initialize(): call_deferred("run")

func run():
	var game=load("res://game/depot.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.sound=false
	game.hud.stack.get_node("플레이").pressed.emit()
	game.hud.stack.get_node("아레나_대전").pressed.emit()
	game.hud.stack.get_node("팀_데스매치").pressed.emit()
	game.hud.cycle_map()
	game.hud.stack.get_node("대전_시작").pressed.emit()
	for i in 4: await physics_frame
	var battle=game.battle
	check(battle.rule==Match.Rule.TEAM and battle.arena.map_id==1,"menu starts chosen mode and map")
	for i in 4: battle.protection[i]=0
	battle.damage(0,1,4)
	check(battle.health[1]==4,"friendly fire disabled")
	battle.damage(0,2,4)
	check(battle.sides[0]==1 and battle.health[2]==0,"team elimination")
	battle.advance(2.6)
	check(battle.health[2]==4 and battle.protection[2]>0,"respawn and protection")
	battle.sides[0]=11
	battle.damage(0,3,4)
	check(battle.result=="청팀 승리","team target")
	for map_id in 2:
		for rule in 5:
			game.chosen_map=map_id
			game.chosen_rule=rule
			game.start_match()
			await physics_frame
			battle=game.battle
			for cell in battle.arena.open_cells:
				var walk:int=cell
				for k in 49:
					if walk==battle.arena.site: break
					walk=battle.arena.next_cell(walk,battle.arena.site)
				check(walk==battle.arena.site,"walkable routes")
			for i in 4: battle.protection[i]=0
			match rule:
				Match.Rule.DEATHMATCH:
					battle.points[2]=7
					battle.damage(2,1,4)
					check(battle.result=="드론 2 승리","individual frag limit")
				Match.Rule.CONTROL:
					game.player.global_position=battle.arena.to_global(battle.arena.point(battle.arena.site))
					battle.objective(1.01)
					check(battle.sides[0]==1,"capture score")
					battle.bodies[2].global_position=game.player.global_position+Vector3.UP
					battle.objective(1)
					check(battle.sides[0]==1,"contested zone")
				Match.Rule.DEMOLITION:
					var at:Vector3=battle.arena.to_global(battle.arena.point(battle.arena.site))
					game.player.global_position=at
					battle.objective(3.1)
					check(battle.armed and game.remaining==18,"arm core")
					battle.bodies[2].global_position=at+Vector3.UP
					game.player.position.x+=7
					battle.objective(4.01)
					check(battle.result=="코어 해제","AI disarms")
				Match.Rule.SURVIVAL:
					battle.damage(0,2,4)
					battle.advance(3)
					check(battle.health[2]==0,"survival one life")
					battle.damage(0,1,4)
					battle.damage(0,3,4)
					check(battle.result=="승리","last player wins")
	game.chosen_rule=Match.Rule.CONTROL
	game.start_match()
	for i in 720: await physics_frame
	check(game.battle.points.max()>0 or game.battle.sides.max()>0,"AI can independently fight or contest objective")
	game.home()
	game.armory()
	game.select_slot(false)
	game.select_slot(false)
	check(game.weapon==1 and game.capacity()==12,"equip Flux")
	game.start_match()
	game.swap()
	game.fire_id=1
	for i in 44: await physics_frame
	check(game.shots>=4 and game.charges<12,"hold to repeat")
	game.home()
	game.armory()
	game.select_slot(false)
	game.start_match()
	game.swap()
	game.shot_delay=0
	check(game.weapon==2 and game.charges==3,"equip Prism")
	game.fire()
	game.fire()
	check(game.shots==1 and game.shot_delay>0.7,"precision cooldown")
	var spent:int=game.charges
	game.swap()
	game.swap()
	check(game.charges==spent,"switching slots preserves ammunition")
	game.home()
	game.armory()
	for id in range(3,7):
		game.primary=id
		game.equip(id)
		check(game.pulse.get_child_count()>6 and game.weapon==id,"primary model and slot")
	game.save_prefs()
	var saved:=ConfigFile.new()
	check(saved.load("user://records.cfg")==OK and saved.get_value("settings","weapon")==2 and saved.get_value("settings","primary")==6,"independent persistent loadout")
	game.home()
	check(game.battle==null and game.player.collision_layer==1,"exit arena")
	game.queue_free()
	await process_frame
	if not fail: print("PASS: 5 arena rules on 2 maps, geometry routes, bot combat, objective interactions, armory and fire modes.")
	quit(1 if fail else 0)

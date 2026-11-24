extends Node3D

const Arena = preload("res://game/arena.gd")
const Drone = preload("res://game/duel.gd")
enum Rule { DEATHMATCH, TEAM, DEMOLITION, CONTROL, SURVIVAL }
const NAMES := ["DEATHMATCH","TEAM DEATHMATCH","DEMOLITION","CONTROL","LAST STANDING"]
const BRIEFS := [
	"Everyone for themselves. First to 8 tags.",
	"Blue vs orange, 2 on 2. First to 12 tags.",
	"Arm site A by holding it for 3s. Defend the core for 18s. Defenders can disarm in 4s.",
	"Hold the marked zone alone with your team. First to 30 control points.",
	"Four contenders, one life each. Be the last one flying."]
const COLORS := [Color("#5de0cc"),Color("#8ebaff"),Color("#ff9262"),Color("#e6a7ed")]
const HP := 4
var arena := Arena.new()
var rule: int
var game
var bodies: Array[PhysicsBody3D]=[]
var drones: Array[Drone]=[]
var teams: Array[int]=[]
var health: Array[int]=[]
var points: Array[int]=[]
var revive: Array[float]=[]
var protection: Array[float]=[]
var cells: Array[int]=[]
var next_cells: Array[int]=[]
var patrol: Array[int]=[]
var locked: Array[int]=[]
var lock_pos: Array[Vector3]=[]
var cooldown: Array[float]=[]
var windup: Array[float]=[]
var sides := [0,0]
var control_fraction := 0.0
var controlling := -1
var contested := false
var objective_progress := 0.0
var armed := false
var fuse := 18.0
var result := ""
var player_flash := 0.0
var tracers: Array[MeshInstance3D]=[]
var tracer_life: Array[float]=[]
var beam_mesh := CylinderMesh.new()

func grouped() -> bool:
	return rule in [Rule.TEAM,Rule.CONTROL,Rule.DEMOLITION]

func build(controller, chosen_rule: int, map_id: int):
	game=controller
	rule=chosen_rule
	add_child(arena)
	arena.build_map(map_id,"A" if rule==Rule.DEMOLITION else ("ZONE" if rule==Rule.CONTROL else ""))
	beam_mesh.top_radius=0.028
	beam_mesh.bottom_radius=0.028
	beam_mesh.height=1
	beam_mesh.radial_segments=6
	beam_mesh.rings=0
	for i in 4:
		teams.append(floori(i/2.0) if grouped() else i)
		var line:=MeshInstance3D.new()
		line.mesh=beam_mesh
		line.material_override=arena.material(team_color(i),false)
		line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		line.hide()
		tracers.append(line)
		tracer_life.append(0)
		health.append(HP)
		points.append(0)
		revive.append(0.0)
		protection.append(1.25)
		cells.append(Arena.SPAWNS[i])
		next_cells.append(cells[i])
		patrol.append([12,35,29,8][i])
		locked.append(-1)
		lock_pos.append(Vector3.ZERO)
		windup.append(0.0)
		cooldown.append(0.4+i*0.18)
		if i==0:
			bodies.append(game.player)
		else:
			var unit:=Drone.new()
			arena.add_child(unit)
			unit.build()
			drones.append(unit)
			bodies.append(unit.bot)
			unit.bot.position=arena.point(cells[i])+Vector3.UP*1.3
			unit.model.get_child(1).material_override.albedo_color=team_color(i)
			unit.lens.albedo_color=team_color(i)
			unit.bot.set_meta("arena_slot",i)
			var label:=Label3D.new()
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			label.text="ALLY" if grouped() and i==1 else "D-%02d"%i
			label.modulate=team_color(i)
			label.pixel_size=0.0045
			label.position.y=1.02
			unit.bot.add_child(label)

func team_color(i: int) -> Color:
	if grouped(): return COLORS[0] if teams[i]==0 else COLORS[2]
	return COLORS[i]

func spawn_player():
	game.place(arena.to_global(arena.point(cells[0])+Vector3.UP*0.04),0)
	game.player.collision_layer=1
	game.player.collision_mask=1

func chest(i: int) -> Vector3:
	if i==0: return game.eye.global_position-Vector3.UP*0.18
	return bodies[i].global_position

func can_hit(slot: int) -> bool:
	return slot>0 and health[slot]>0 and protection[slot]<=0 and teams[slot]!=teams[0]

func sight(i: int,j: int) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(chest(i),chest(j))
	query.exclude=[bodies[i].get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).get("collider")==bodies[j]

func draw_beam(i: int,start: Vector3,end: Vector3):
	var offset:=end-start
	if offset.length_squared()<0.01: return
	var basis:=Basis(Quaternion(Vector3.UP,offset.normalized())).scaled_local(Vector3(1,offset.length(),1))
	tracers[i].global_transform=Transform3D(basis,(start+end)*0.5)
	tracers[i].show()
	tracer_life[i]=0.11

func damage(attacker: int,victim: int,amount: int):
	if result!="" or health[attacker]<=0 or health[victim]<=0 or protection[victim]>0 or teams[attacker]==teams[victim]: return
	health[victim]=maxi(0,health[victim]-amount)
	if victim==0: player_flash=0.4
	if health[victim]>0: return
	points[attacker]+=1
	if rule==Rule.TEAM: sides[teams[attacker]]+=1
	revive[victim]=2.4
	bodies[victim].collision_layer=0
	if victim==0:
		game.clear_input()
		game.jump_requested=false
		game.pulse.hide()
		game.player.collision_mask=0
	else:
		drones[victim-1].bot.hide()
	windup[victim]=0
	locked[victim]=-1
	check_scores()

func check_scores():
	if rule==Rule.SURVIVAL:
		var alive: Array[int]=[]
		for i in 4:
			if health[i]>0: alive.append(i)
		if alive.size()==1: result="YOU WIN" if alive[0]==0 else "DRONE %d WINS"%alive[0]
	elif rule==Rule.DEATHMATCH and points.max()>=8: finish_time()
	elif rule==Rule.TEAM and sides.max()>=12: finish_time()
	elif rule==Rule.CONTROL and sides.max()>=30: finish_time()

func finish_time():
	if result!="": return
	if rule==Rule.DEMOLITION:
		result="CORE TRIGGERED" if armed else "DEFENDERS WIN"
	elif grouped():
		result="DRAW" if sides[0]==sides[1] else ("BLUE WINS" if sides[0]>sides[1] else "ORANGE WINS")
	else:
		var best: Array[int]=[]
		var highest:=-1
		for i in 4:
			if rule==Rule.SURVIVAL and health[i]<=0: continue
			var value:=points[i] if rule==Rule.DEATHMATCH else health[i]
			if value>highest:
				highest=value
				best.clear()
			if value==highest: best.append(i)
		result="DRAW" if best.size()!=1 else ("YOU WIN" if best[0]==0 else "DRONE %d WINS"%best[0])

func respawn(i: int):
	
	var best_distance:=-1.0
	var safe:int=Arena.SPAWNS[i]
	for home: int in Arena.SPAWNS:
		var pos:=arena.to_global(arena.point(home))
		var dist:=INF
		for j in 4:
			if i!=j and health[j]>0: dist=minf(dist,pos.distance_squared_to(bodies[j].global_position))
		if dist>best_distance:
			safe=home
			best_distance=dist
	cells[i]=safe
	next_cells[i]=safe
	health[i]=HP
	protection[i]=1.1
	bodies[i].collision_layer=1
	if i==0:
		spawn_player()
		game.charges=game.capacity()
		game.recharge=0
		game.pulse.show()
	else:
		bodies[i].position=arena.point(safe)+Vector3.UP*1.3
		bodies[i].show()

func nearest_enemy(i: int, visible_only: bool) -> int:
	var best:=-1
	var dist:=INF
	for j in 4:
		if health[j]==0 or teams[j]==teams[i]: continue
		var d:=chest(i).distance_squared_to(chest(j))
		if d>=dist: continue
		if visible_only and (protection[j]>0 or not sight(i,j)): continue
		dist=d
		best=j
	return best

func move_bot(i: int,dt: float):
	var bot:=bodies[i]
	var dest:=arena.point(next_cells[i])+Vector3.UP*1.3
	if rule in [Rule.CONTROL,Rule.DEMOLITION] and next_cells[i]==arena.site:
		var offsets: Array[Vector3]=[Vector3.ZERO,Vector3(-0.95,0,0.85),Vector3(0.95,0,-0.8),Vector3(-0.9,0,-0.85)]
		dest+=offsets[i]
	bot.position=bot.position.move_toward(dest,dt*(2.45+i*0.13))
	if bot.position.distance_squared_to(dest)>0.006: return
	cells[i]=next_cells[i]
	var goal:=arena.site
	if rule not in [Rule.CONTROL,Rule.DEMOLITION]:
		var enemy:=nearest_enemy(i,false)
		if enemy>=0: goal=arena.nearest(arena.to_local(bodies[enemy].global_position))
		if enemy<0 or cells[i]==goal:
			if patrol[i]==cells[i] or patrol[i] not in arena.open_cells:
				patrol[i]=arena.open_cells[(arena.open_cells.find(cells[i])+11+i)%arena.open_cells.size()]
			goal=patrol[i]
	next_cells[i]=arena.next_cell(cells[i],goal)

func advance_bot(i: int,dt: float):
	# Approach the objective or patrol until a visible rival can be tagged.
	move_bot(i,dt)
	var drone:=drones[i-1]
	if windup[i]>0:
		windup[i]=maxf(0,windup[i]-dt)
		if windup[i]<=0:
			var enemy:=locked[i]
			draw_beam(i,chest(i),lock_pos[i])
			if health[enemy]>0 and lock_pos[i].distance_to(chest(enemy))<1.95 and sight(i,enemy):
				damage(i,enemy,2)
			drone.lens.albedo_color=team_color(i)
			cooldown[i]=0.78+0.13*i
		return
	cooldown[i]-=dt
	if cooldown[i]>0: return
	locked[i]=nearest_enemy(i,true)
	if locked[i]<0:
		cooldown[i]=0.23
		return
	lock_pos[i]=chest(locked[i])
	var direction:=lock_pos[i]-chest(i)
	drone.model.rotation.y=atan2(direction.x,direction.z)
	drone.lens.albedo_color=Color("#fff3ba")
	windup[i]=0.52+0.09*i

func in_zone(i: int) -> bool:
	var offset:=arena.to_local(bodies[i].global_position)-arena.point(arena.site)
	return Vector2(offset.x,offset.z).length_squared()<=2.05*2.05

func objective(dt: float):
	var present: Array[int]=[0,0]
	for i in 4:
		if health[i]>0 and in_zone(i):
			present[teams[i]]+=1
	contested=present[0]>0 and present[1]>0
	var previous_owner:=controlling
	controlling=-1
	if present[0]>0 and present[1]==0: controlling=0
	if present[1]>0 and present[0]==0: controlling=1
	if rule==Rule.CONTROL:
		if previous_owner!=controlling: control_fraction=0
		if controlling<0:
			control_fraction=0
		else:
			control_fraction+=dt
			if control_fraction>=1:
				sides[controlling]+=1
				control_fraction-=1
				check_scores()
		return
	if armed:
		fuse=maxf(0,fuse-dt)
		if fuse<=0:
			result="CORE TRIGGERED"
			return
	if controlling==(1 if armed else 0): objective_progress+=dt
	else: objective_progress=0
	if armed and objective_progress>=4: result="CORE DISARMED"
	elif not armed and objective_progress>=3:
		armed=true
		game.remaining=fuse
		objective_progress=0
		arena.marker.text="CORE"

func advance(dt: float):
	player_flash=maxf(0,player_flash-dt)
	for i in 4:
		tracer_life[i]=maxf(0,tracer_life[i]-dt)
		if tracer_life[i]==0: tracers[i].hide()
		if result!="": break
		if health[i]<=0:
			if rule!=Rule.SURVIVAL:
				revive[i]-=dt
				if revive[i]<=0: respawn(i)
			continue
		protection[i]=maxf(0,protection[i]-dt)
		if i>0: advance_bot(i,dt)
	if result=="" and rule in [Rule.CONTROL,Rule.DEMOLITION]: objective(dt)

func status() -> String:
	if health[0]==0: return "SPECTATING" if rule==Rule.SURVIVAL else "RESPAWN  %.1f"%maxf(0,revive[0])
	var info:="ARMOR  %d/%d"%[health[0],HP]
	if rule==Rule.CONTROL: return info+"     ZONE  "+(["CONTESTED" if contested else "OPEN","BLUE","ORANGE"][controlling+1])
	if rule==Rule.DEMOLITION:
		return info+("     DEFEND CORE  %ds   DISARM %d%%"%[ceili(fuse),int(objective_progress*25)] if armed else "     HOLD A   %d%%"%int(objective_progress*100/3))
	if rule==Rule.SURVIVAL: return info+"     ALIVE  %d"%(4-health.count(0))
	return info

func scoreboard() -> String:
	if rule in [Rule.TEAM,Rule.CONTROL]: return "BLUE %d   /   %d ORANGE"%sides
	if rule==Rule.DEMOLITION: return "BLUE  /  ATTACK"
	return "YOU %d   /   TOP %d"%[points[0],points.max()]

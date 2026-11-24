extends Node3D

const Match = preload("res://game/arena_match.gd")
const Arena = preload("res://game/arena.gd")
const Gear = preload("res://game/loadout.gd")
var battle: Match
var chosen_rule := 0
var chosen_map := 0
var weapon := 0
var shot_delay := 0.0
var aim_end := Vector3.ZERO
var mouse_fire := false

const Depot = preload("res://game/depot.gd")
const Hud = preload("res://game/hud.gd")
const Polar = preload("res://game/polar.gd")
const Duel = preload("res://game/duel.gd")
var polar: Polar
var rival: Duel
var versus := false
var crouched := false
var zoom := false
var jump_requested := false
var body := CollisionShape3D.new()
var capsule := CapsuleShape3D.new()
var standing_probe := CapsuleShape3D.new()
const DURATION := 30.0
const CAPACITY := 5
const RECHARGE_TIME := 1.05
const POS := Vector3(0,0.03,8)
var depot := Depot.new()
var hud := Hud.new()
var player := CharacterBody3D.new()
var eye := Camera3D.new()
var pulse: Node3D
var mode := "home"
var remaining := DURATION
var shots := 0
var hits := 0
var charges := CAPACITY
var recharge := 0.0
var aimed := false
var hit_flash := 0.0
var lit := -1
var stick := Vector2.ZERO
var move_id := -1
var look_id := -1
var fire_id := -1
var mouse_look := false
var kick := 0.0
var step_phase := 0.0
var best := 0
var best_accuracy := 0
var sensitivity := 1
var sound := true
var prefs := ConfigFile.new()
var speaker := AudioStreamPlayer.new()
var tones: Array[AudioStreamWAV] = []

func _ready():
	add_child(depot)
	depot.build()
	add_child(player)
	standing_probe.radius=0.295
	standing_probe.height=1.70
	capsule.radius = 0.30
	capsule.height = 1.72
	body.shape = capsule
	body.position.y = 0.86
	player.add_child(body)
	player.add_child(eye)
	eye.position.y = 1.50
	eye.current = true
	eye.near = 0.04
	eye.far = 65
	eye.fov = 63
	
	add_child(speaker)
	tones.append(tone(220,145))
	tones.append(tone(700,1030))
	prefs.load("user://records.cfg")
	weapon=clampi(prefs.get_value("settings","weapon",0),0,Gear.NAMES.size()-1)
	pulse=Gear.make(weapon,depot,eye)
	best = prefs.get_value("records","score",0)
	best_accuracy = prefs.get_value("records","accuracy",0)
	sound = prefs.get_value("settings","sound",true)
	sensitivity = clampi(prefs.get_value("settings","look",1),0,2)
	add_child(hud)
	hud.build(self)
	get_tree().auto_accept_quit = false
	home()

func tone(start_hz: float, end_hz: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(1700*2)
	var phase := 0.0
	for i in 1700:
		var t := i/1699.0
		phase += TAU*lerpf(start_hz,end_hz,t)/stream.mix_rate
		data.encode_s16(i*2,roundi(sin(phase)*minf(t*25,1)*pow(1-t,2)*5600))
	stream.data = data
	return stream

func save_prefs():
	prefs.set_value("records","score",best)
	prefs.set_value("records","accuracy",best_accuracy)
	prefs.set_value("settings","sound",sound)
	prefs.set_value("settings","look",sensitivity)
	prefs.set_value("settings","weapon",weapon)
	prefs.save("user://records.cfg")

func toggle_sound():
	sound = not sound
	save_prefs()
	hud.show_page("settings")

func change_sensitivity():
	sensitivity = (sensitivity+1)%3
	save_prefs()
	hud.show_page("settings")

func clear_input():
	stick = Vector2.ZERO
	move_id = -1
	look_id = -1
	fire_id = -1
	mouse_look = false
	mouse_fire = false

func clear_plate():
	if lit>=0:
		depot.light_plate(lit,false)
	lit = -1
	hit_flash = 0

func reset_stance():
	crouched=false
	zoom=false
	jump_requested=false
	capsule.height=1.72
	body.position.y=0.86
	eye.position.y=1.5
	eye.fov=63

func set_crouch():
	if not crouched:
		crouched=true
	else:
		var probe:=PhysicsShapeQueryParameters3D.new()
		probe.shape=standing_probe
		probe.transform=Transform3D(Basis.IDENTITY,player.global_position+Vector3.UP*0.87)
		probe.exclude=[player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty(): return
		crouched=false
	capsule.height=1.04 if crouched else 1.72
	body.position.y=capsule.height/2

func place(at: Vector3, yaw: float):
	reset_stance()
	player.position = at
	player.rotation = Vector3(0,yaw,0)
	eye.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	clear_input()

func close_match():
	if battle:
		remove_child(battle)
		battle.queue_free()
		battle=null
	player.collision_layer=1
	player.collision_mask=1

func capacity() -> int:
	return Gear.CAPACITY[weapon]

func cycle_weapon():
	weapon=(weapon+1)%Gear.NAMES.size()
	pulse.hide()
	pulse.queue_free()
	pulse=Gear.make(weapon,depot,eye)
	save_prefs()
	if hud.page=="armory": armory()
	else: hud.show_page("arena_setup")

func start_match():
	close_match()
	battle=Match.new()
	add_child(battle)
	battle.position=Vector3(500,0,0)
	battle.build(self,chosen_rule,chosen_map)
	start_round(false)
	battle.spawn_player()
	remaining=120 if chosen_rule!=Match.Rule.SURVIVAL else 90
	hud.update_play()

func home():
	close_match()
	versus=false
	if polar: polar.hide()
	mode = "home"
	clear_plate()
	place(Vector3(-5.7,0.03,9.5),deg_to_rad(-20))
	pulse.hide()
	hud.show_page("home")

func armory():
	place(Vector3(35,0.03,0),0)
	hud.show_page("armory")
	pulse.show()
	pulse.get_node("Gloves").hide()
	pulse.scale = Vector3.ONE * 1.70
	pulse.position = Vector3(0.36,-0.055,-0.97)
	pulse.rotation_degrees = Vector3(5,119,-3)

func start_duel():
	close_match()
	if not polar:
		polar=Polar.new()
		add_child(polar)
		polar.position=Vector3(220,0,0)
		polar.build()
		rival=Duel.new()
		polar.add_child(rival)
		rival.build()
	polar.show()
	rival.reset()
	start_round(true)

func start_run():
	close_match()
	start_round(false)

func retry():
	if battle: start_match()
	elif versus: start_duel()
	else: start_run()

func start_round(is_duel: bool):
	versus=is_duel
	mode = "play"
	clear_plate()
	place(polar.to_global(Polar.YARD_SPAWN) if versus else POS,0)
	remaining = 90.0 if versus else DURATION
	charges = capacity()
	shot_delay = 0
	shots = 0
	hits = 0
	recharge = 0
	kick = 0
	step_phase = 0
	aimed = false
	pulse.show()
	pulse.get_node("Gloves").show()
	pulse.scale = Vector3.ONE * 0.84
	pose()
	hud.show_page("play")
	hud.update_play()

func pause_run():
	if mode!="play": return
	mode = "pause"
	jump_requested=false
	clear_input()
	hud.show_page("pause")

func resume_run():
	if mode!="pause": return
	mode = "play"
	clear_input()
	hud.show_page("play")
	hud.update_play()

func back():
	match hud.page:
		"play": pause_run()
		"pause": resume_run()
		"settings":
			if mode=="pause": hud.show_page("pause")
			else: home()
		"home": pass
		_: home()

func _notification(what):
	if not is_node_ready(): return
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause_run()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud.page=="home": get_tree().quit()
		else: back()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func accuracy() -> int:
	return roundi(100.0*hits/shots) if shots else 0

func look(delta: Vector2):
	var scale := deg_to_rad(62+sensitivity*24)/maxf(1,get_viewport().get_visible_rect().size.y)
	if zoom: scale *= 0.55
	player.rotate_y(-delta.x*scale)
	eye.rotation.x = clampf(eye.rotation.x-delta.y*scale, deg_to_rad(-65),deg_to_rad(68))

func move_stick(pos: Vector2):
	stick = ((pos-hud.overlay.stick_center())/42.0).limit_length(1)

func _input(event):
	if not is_node_ready(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			back()
			get_viewport().set_input_as_handled()
			return
		if mode=="play":
			match event.keycode:
				KEY_SPACE, KEY_F: fire()
				KEY_C: set_crouch()
				KEY_J: jump_requested=true
				KEY_Q: zoom=not zoom
	if mode!="play": return
	if event is InputEventScreenTouch:
		var id: int = event.index
		if not event.pressed or event.canceled:
			if move_id==id:
				move_id = -1
				stick = Vector2.ZERO
			if look_id==id: look_id = -1
			if fire_id==id: fire_id = -1
		elif hud.overlay.pause_rect().has_point(event.position):
			pause_run()
		elif press_action(event.position):
			pass
		elif event.position.distance_to(hud.overlay.fire_center())<=57 and fire_id<0:
			fire_id = id
			fire()
		elif event.position.distance_to(hud.overlay.stick_center())<=78 and move_id<0:
			move_id = id
			move_stick(event.position)
		elif event.position.x>hud.overlay.size.x*0.40 and look_id<0:
			look_id = id
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if move_id==event.index: move_stick(event.position)
		elif look_id==event.index or fire_id==event.index: look(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION and event.button_index==MOUSE_BUTTON_LEFT:
		mouse_look = false
		mouse_fire=false
		if event.pressed:
			if hud.overlay.pause_rect().has_point(event.position): pause_run()
			elif press_action(event.position): pass
			elif event.position.distance_to(hud.overlay.fire_center())<=57:
				mouse_fire=true
				fire()
			else: mouse_look=true
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mouse_look: look(event.relative)

func press_action(pos: Vector2) -> bool:
	match hud.overlay.action_at(pos):
		"AIM": zoom=not zoom
		"LOW": set_crouch()
		"JUMP": jump_requested=true
		_: return false
	return true

func aim_index() -> int:
	var from := eye.global_position
	var query := PhysicsRayQueryParameters3D.create(from,from-eye.global_basis.z*float(Gear.REACH[weapon]))
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if battle:
		aim_end=hit.get("position",query.to)
		var slot:int=hit.collider.get_meta("arena_slot",-1) if hit else -1
		return slot if battle.can_hit(slot) else -1
	if versus: return 0 if hit.get("collider")==rival.bot and rival.grace<=0 else -1
	return hit.collider.get_meta("plate",-1) if hit else -1

func fire():
	if mode!="play" or charges<=0 or shot_delay>0 or (battle and battle.health[0]<=0): return
	if battle or weapon!=0: shot_delay=Gear.INTERVAL[weapon]
	var plate := aim_index()
	if battle: battle.draw_beam(0,eye.to_global(Vector3(0.17,-0.09,-0.5)),aim_end)
	shots += 1
	charges -= 1
	kick = 1
	if charges==0: recharge = Gear.RECHARGE[weapon]
	if plate>=0:
		hits += 1
		clear_plate()
		if battle:
			battle.damage(0,plate,Gear.DAMAGE[weapon])
		elif versus:
			rival.tagged()
		else:
			lit = plate
			depot.light_plate(lit,true)
		hit_flash = 0.36
	if sound:
		speaker.stream = tones[int(plate>=0)]
		speaker.play()
	hud.update_play()
	if (battle and battle.result!="") or (versus and hits>=Duel.LIMIT): finish_round()

func pose():
	var dip := sin(PI*recharge/float(Gear.RECHARGE[weapon]))
	pulse.position = Vector3(0.225,-0.14-dip*0.14+sin(step_phase)*0.004,-0.52+kick*0.035)
	var blend:=clampf((63.0-eye.fov)/22.0,0,1)
	pulse.position=pulse.position.lerp(Vector3(0,-0.098-dip*0.12,-0.53+kick*0.018),blend)
	pulse.rotation_degrees = Vector3(kick*4-dip*18,lerpf(12,0,blend),lerpf(-3,0,blend))

func _physics_process(dt):
	if mode!="play": return
	remaining = maxf(0,remaining-dt)
	if remaining<=0.00001:
		remaining=0
		finish_round()
		return
	shot_delay=maxf(0,shot_delay-dt)
	if battle:
		battle.advance(dt)
		if battle.result!="":
			finish_round()
			return
		if battle.health[0]==0:
			for i in range(1,4):
				if battle.health[i]>0:
					eye.look_at(battle.chest(i))
					break
			hud.update_play()
			return
	if weapon==1 and (fire_id>=0 or mouse_fire or Input.is_physical_key_pressed(KEY_F)): fire()
	if mode!="play": return
	var move := stick
	move.x += int(Input.is_physical_key_pressed(KEY_D))-int(Input.is_physical_key_pressed(KEY_A))
	move.y += int(Input.is_physical_key_pressed(KEY_S))-int(Input.is_physical_key_pressed(KEY_W))
	move = move.limit_length(1)
	var speed:=2.15 if crouched else 3.8
	var planar := player.basis*Vector3(move.x,0,move.y)*speed
	player.velocity.x = planar.x
	player.velocity.z = planar.z
	player.velocity.y = -1.0 if player.is_on_floor() else maxf(-18,player.velocity.y-14*dt)
	if jump_requested and player.is_on_floor():
		if crouched: set_crouch()
		if not crouched: player.velocity.y=5.4
	jump_requested=false
	player.move_and_slide()
	eye.position.y=move_toward(eye.position.y,0.89 if crouched else 1.50,4.8*dt)
	eye.fov=move_toward(eye.fov,41.0 if zoom else 63.0,140.0*dt)
	if versus:
		rival.advance(dt,player,eye)
		if rival.bot_score>=Duel.LIMIT:
			finish_round()
			return
	if recharge>0:
		recharge = maxf(0,recharge-dt)
		if recharge==0: charges=capacity()
	if hit_flash>0:
		hit_flash = maxf(0,hit_flash-dt)
		if hit_flash==0: clear_plate()
	kick = move_toward(kick,0,dt*6)
	step_phase += move.length()*dt*8
	aimed = aim_index()>=0
	pose()
	hud.update_play()

func finish_round():
	mode="result"
	clear_input()
	if battle:
		battle.finish_time()
	elif not versus:
		best=maxi(best,hits*100)
		best_accuracy=maxi(best_accuracy,accuracy())
		save_prefs()
	hud.show_page("result")

func outcome() -> String:
	if hits==rival.bot_score: return "DRAW"
	return "YOU WIN" if hits>rival.bot_score else "DRONE WINS"

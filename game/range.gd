extends Node3D

const Depot = preload("res://game/depot.gd")
const Hud = preload("res://game/hud.gd")
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
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
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
	pulse = depot.make_pulse(eye)
	add_child(speaker)
	tones.append(tone(220,145))
	tones.append(tone(700,1030))
	prefs.load("user://records.cfg")
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

func clear_plate():
	if lit>=0:
		depot.light_plate(lit,false)
	lit = -1
	hit_flash = 0

func place(at: Vector3, yaw: float):
	player.position = at
	player.rotation = Vector3(0,yaw,0)
	eye.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	clear_input()

func home():
	mode = "home"
	clear_plate()
	place(Vector3(-5.7,0.03,9.5),deg_to_rad(-20))
	pulse.hide()
	hud.show_page("home")

func armory():
	hud.show_page("armory")
	pulse.show()
	pulse.position = Vector3(0.43,-0.015,-0.72)
	pulse.rotation_degrees = Vector3(8,65,-5)

func start_run():
	mode = "play"
	clear_plate()
	place(POS,0)
	remaining = DURATION
	charges = CAPACITY
	shots = 0
	hits = 0
	recharge = 0
	kick = 0
	step_phase = 0
	aimed = false
	pulse.show()
	pose()
	hud.show_page("play")
	hud.update_play()

func pause_run():
	if mode!="play": return
	mode = "pause"
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
		if mode=="play" and event.keycode==KEY_SPACE: fire()
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
		if event.pressed:
			if hud.overlay.pause_rect().has_point(event.position): pause_run()
			elif event.position.distance_to(hud.overlay.fire_center())<=57: fire()
			else: mouse_look=true
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mouse_look: look(event.relative)

func aim_index() -> int:
	var from := eye.global_position
	var query := PhysicsRayQueryParameters3D.create(from,from-eye.global_basis.z*55)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider.get_meta("plate",-1) if hit else -1

func fire():
	if mode!="play" or charges<=0: return
	var plate := aim_index()
	shots += 1
	charges -= 1
	kick = 1
	if charges==0: recharge = RECHARGE_TIME
	if plate>=0:
		hits += 1
		clear_plate()
		lit = plate
		depot.light_plate(lit,true)
		hit_flash = 0.36
	if sound:
		speaker.stream = tones[int(plate>=0)]
		speaker.play()
	hud.update_play()

func pose():
	var dip := sin(PI*recharge/RECHARGE_TIME)
	pulse.position = Vector3(0.23,-0.16-dip*0.14+sin(step_phase)*0.004,-0.46+kick*0.035)
	pulse.rotation_degrees = Vector3(kick*4-dip*18,6,0)

func _physics_process(dt):
	if mode!="play": return
	remaining = maxf(0,remaining-dt)
	if remaining<=0.00001:
		remaining=0
		mode="result"
		clear_input()
		best=maxi(best,hits*100)
		best_accuracy=maxi(best_accuracy,accuracy())
		save_prefs()
		hud.show_page("result")
		return
	var move := stick
	move.x += int(Input.is_physical_key_pressed(KEY_D))-int(Input.is_physical_key_pressed(KEY_A))
	move.y += int(Input.is_physical_key_pressed(KEY_S))-int(Input.is_physical_key_pressed(KEY_W))
	move = move.limit_length(1)
	var planar := player.basis*Vector3(move.x,0,move.y)*3.8
	player.velocity.x = planar.x
	player.velocity.z = planar.z
	player.velocity.y = -1.0 if player.is_on_floor() else maxf(-18,player.velocity.y-14*dt)
	player.move_and_slide()
	if recharge>0:
		recharge = maxf(0,recharge-dt)
		if recharge==0: charges=CAPACITY
	if hit_flash>0:
		hit_flash = maxf(0,hit_flash-dt)
		if hit_flash==0: clear_plate()
	kick = move_toward(kick,0,dt*6)
	step_phase += move.length()*dt*8
	aimed = aim_index()>=0
	pose()
	hud.update_play()

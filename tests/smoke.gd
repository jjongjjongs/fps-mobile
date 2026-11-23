extends SceneTree

var errors: Array[String] = []

func check(ok: bool, message: String):
	if not ok:
		errors.append(message)
		printerr("FAIL: ",message)

func _initialize():
	call_deferred("run")

func run():
	var game = load("res://game/depot.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	check(game.hud.page=="home" and game.depot.rings.size()==5,"start menu and five targets")
	game.hud.stack.get_node("PLAY").pressed.emit()
	game.hud.stack.get_node("START_RUN").pressed.emit()
	await physics_frame
	await physics_frame
	check(game.mode=="play" and game.aim_index()==0,"start button and initial sightline")
	game.fire()
	check(game.hits==1 and game.shots==1 and game.hit_flash>0,"first hit")
	game.player.rotation.y=PI
	game.fire()
	check(game.hits==1 and game.shots==2,"miss")
	game.player.rotation.y=0
	for i in 3: game.fire()
	game.fire()
	check(game.shots==5 and game.charges==0,"capacity and input during recharge")
	var clock: float = game.remaining
	game.pause_run()
	game._physics_process(5.0)
	game.fire()
	check(game.remaining==clock and game.shots==5,"pause blocks timer and shots")
	game.resume_run()
	game._physics_process(1.06)
	check(game.charges==5 and game.mode=="play","resume and auto recharge")
	var a := InputEventScreenTouch.new()
	a.index=0
	a.pressed=true
	a.position=game.hud.overlay.stick_center()+Vector2(20,-19)
	game._input(a)
	var b := InputEventScreenTouch.new()
	b.index=1
	b.pressed=true
	b.position=Vector2(600,150)
	game._input(b)
	var drag := InputEventScreenDrag.new()
	drag.index=1
	drag.relative=Vector2(26,9)
	game._input(drag)
	check(game.stick.length()>0.3 and game.player.rotation.y!=0,"independent move and look fingers")
	a.pressed=false
	game._input(a)
	check(game.stick==Vector2.ZERO and game.look_id==1,"independent finger release")
	game._physics_process(30.0)
	check(game.hud.page=="result" and game.best>=400 and game.accuracy()==80,"timeout and results")
	game.hud.stack.get_node("RETRY").pressed.emit()
	check(game.shots==0 and game.hits==0 and game.remaining==30 and game.charges==5,"retry reset")
	var blocker := StaticBody3D.new()
	game.add_child(blocker)
	blocker.position=Vector3(0,1.5,5)
	var shape := CollisionShape3D.new()
	shape.shape=BoxShape3D.new()
	blocker.add_child(shape)
	await physics_frame
	await physics_frame
	check(game.aim_index()==-1,"nearby solid prevents hits through cover")
	game.home()
	game.hud.stack.get_node("ARMORY").pressed.emit()
	check(game.pulse.visible and game.hud.page=="armory","armory preview")
	game.hud.stack.get_node("BACK").pressed.emit()
	game.hud.stack.get_node("SETTINGS").pressed.emit()
	var previous: bool=game.sound
	game.toggle_sound()
	var settings := ConfigFile.new()
	check(settings.load("user://records.cfg")==OK,"persist settings")
	check(settings.get_value("settings","sound")==not previous and settings.get_value("records","score")>=400,"record and preference saved")
	game.speaker.stop()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	if errors.is_empty(): print("PASS: Depot round, contacts, touch, recharge, pause, retry, menus and save.")
	quit(0 if errors.is_empty() else 1)

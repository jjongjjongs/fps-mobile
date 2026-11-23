extends Node3D

# A hover circuit through the Polar yard; each edge is clear at flight height.
const ROUTE := [Vector3(0,1.9,-5), Vector3(5.6,2.3,-8.8), Vector3(7.4,2.35,-1),
	Vector3(4.6,1.9,4.4), Vector3(0,1.85,2.1), Vector3(-4.6,2.1,4.4),
	Vector3(-7.3,2.35,-1), Vector3(-5.6,2.3,-8.8)]
const LIMIT := 5
var bot := StaticBody3D.new()
var lens := StandardMaterial3D.new()
var orb: MeshInstance3D
var bolt_velocity := Vector3.ZERO
var bolt_life := 0.0
var warning := 0.0
var cool := 0.0
var bot_score := 0
var grace := 0.0
var hit_feedback := 0.0
var destination := 1
var direction := 1
var elapsed := 0.0
var aim_point := Vector3.ZERO
var model := Node3D.new()

func sphere_model(parent: Node3D, size: Vector3, color: Color, offset: Vector3) -> MeshInstance3D:
	var m:=SphereMesh.new()
	m.radius=0.5
	m.height=1.0
	m.radial_segments=20
	m.rings=10
	var shape:=MeshInstance3D.new()
	shape.mesh=m
	shape.scale=size
	shape.position=offset
	var surface:=StandardMaterial3D.new()
	surface.albedo_color=color
	surface.metallic=0.36
	surface.roughness=0.35
	shape.material_override=surface
	parent.add_child(shape)
	return shape

func build():
	add_child(bot)
	bot.name="Rival"
	var collision:=CollisionShape3D.new()
	var hull:=SphereShape3D.new()
	hull.radius=0.78
	collision.shape=hull
	bot.add_child(collision)
	bot.add_child(model)
	sphere_model(model,Vector3(1.3,0.96,1.05),Color("#394854"),Vector3.ZERO)
	sphere_model(model,Vector3(1.26,0.53,1.01),Color("#f79152"),Vector3(0,0.22,0))
	var visor:=sphere_model(model,Vector3(0.83,0.45,0.24),Color.WHITE,Vector3(0,0.02,0.48))
	visor.material_override=lens
	lens.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0,1.0]:
		sphere_model(model,Vector3(0.37,0.32,0.68),Color("#dde9e5"),Vector3(side*0.66,-0.1,0))
		sphere_model(model,Vector3(0.22,0.10,0.32),Color("#ffa44a"),Vector3(side*0.66,-0.24,0))
	orb=sphere_model(self,Vector3.ONE*0.31,Color.WHITE,Vector3.ZERO)
	var glow:=StandardMaterial3D.new()
	glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color=Color("#ff753c")
	orb.material_override=glow
	reset()

func reset():
	bot.position=ROUTE[0]
	destination=1
	direction=1
	elapsed=0
	cool=1.5
	warning=0
	grace=0
	bot_score=0
	hit_feedback=0
	bolt_life=0
	orb.hide()
	lens.albedo_color=Color("#ff9152")

func tagged():
	# A pulse scores once, then the rival shifts to a different bay.
	direction=-direction
	destination=posmod(destination+4,ROUTE.size())
	bot.position=ROUTE[destination]
	destination=posmod(destination+direction,ROUTE.size())
	grace=0.48
	warning=0
	cool=1.1
	bolt_life=0
	orb.hide()

func ray(a: Vector3,b: Vector3) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(a,b)
	q.exclude=[bot.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func advance(dt: float,player: CharacterBody3D,eye: Camera3D):
	elapsed+=dt
	grace=maxf(0,grace-dt)
	hit_feedback=maxf(0,hit_feedback-dt)
	var point: Vector3=ROUTE[destination]
	bot.position=bot.position.move_toward(point,2.8*dt)
	if bot.position.distance_to(point)<0.05:
		destination=posmod(destination+direction,ROUTE.size())
	model.position.y=sin(elapsed*4.0)*0.085
	var delta:=player.global_position-bot.global_position
	model.rotation.y=atan2(delta.x,delta.z)
	if bolt_life>0:
		var next:=orb.global_position+bolt_velocity*dt
		var hit:=ray(orb.global_position,next)
		orb.global_position=next
		bolt_life=maxf(0,bolt_life-dt)
		if hit:
			if hit.collider==player:
				bot_score+=1
				hit_feedback=0.55
			bolt_life=0
		if bolt_life<=0: orb.hide()
	if warning>0:
		warning=maxf(0,warning-dt)
		if warning<=0:
			orb.global_position=bot.global_position
			bolt_velocity=(aim_point-orb.global_position).normalized()*10.5
			bolt_life=2.9
			orb.show()
			cool=2.6
	else:
		cool=maxf(0,cool-dt)
		if cool<=0 and bolt_life<=0:
			var chest:=eye.global_position-Vector3.UP*0.18
			var sight:=ray(bot.global_position,chest)
			if sight.get("collider")==player:
				aim_point=chest
				warning=0.8
			else:
				cool=0.22
	lens.albedo_color=Color("#c5ffed") if grace>0 else (Color("#fff1a9") if warning>0 else Color("#ff9152"))

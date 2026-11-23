extends Node3D

const STEEL = Color("#43545b")
const DARK = Color("#28353c")
const CONCRETE = Color("#697879")
const FLOOR = Color("#636b68")
const PAINT = Color("#efa847")
const IVORY = Color("#ebdfc3")
const MINT = Color("#56e4c6")
const GLOVE = Color("#273a3d")
var surfaces := {}
var groups := {}
var rings: Array[MeshInstance3D] = []

const SURFACE = preload("res://art/depot/surface.gdshader")
const GRAIN = preload("res://art/depot/surface-grain.jpg")
const PULSE_MODEL = preload("res://art/depot/pulse.glb")
const STRIPES = Color("#e2a644")
const SHEET = Color("#58686a")
const CRATE = Color("#606a56")

func material(color: Color, lit := true) -> Material:
	var key := color.to_html() + str(lit)
	if surfaces.has(key):
		return surfaces[key]
	if not lit:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = color
		flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		surfaces[key] = flat
	else:
		var m := ShaderMaterial.new()
		m.shader = SURFACE
		m.set_shader_parameter("tint", color)
		m.set_shader_parameter("grain", GRAIN)
		var finish := 0
		if color in [DARK, STEEL, SHEET, CRATE]: finish = 1
		elif color == PAINT: finish = 2
		elif color == FLOOR: finish = 3
		elif color == STRIPES: finish = 4
		m.set_shader_parameter("finish",finish)
		surfaces[key] = m
	return surfaces[key]

func box(center: Vector3, size: Vector3, color: Color, solid := false, unlit := false, tilt := 0.0):
	var m := material(color, not unlit)
	if not groups.has(m):
		groups[m] = []
	var basis := Basis(Vector3.FORWARD, tilt).scaled_local(size)
	groups[m].append(Transform3D(basis, center))
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var body := StaticBody3D.new()
		add_child(body)
		body.position = center
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)

func build():
	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	var daylight := ProceduralSkyMaterial.new()
	daylight.sky_top_color = Color("#688799")
	daylight.sky_horizon_color = Color("#d4d9d2")
	daylight.ground_bottom_color = Color("#2b353a")
	daylight.ground_horizon_color = Color("#77817e")
	var sky := Sky.new()
	sky.sky_material = daylight
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#aebbca")
	env.ambient_light_energy = 0.64
	ambient.environment = env
	add_child(ambient)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-32,0)
	sun.light_color = Color("#fff0ce")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_opacity = 0.60
	add_child(sun)
	architecture()
	box(Vector3(0,-0.15,-5),Vector3(20,0.3,34),FLOOR,true)
	box(Vector3(0,3,-22),Vector3(20,6,0.4),CONCRETE,true)
	box(Vector3(0,3,12),Vector3(20,6,0.4),CONCRETE,true)
	box(Vector3(0,6.15,-5),Vector3(20,0.3,34),DARK)
	for side in [-1.0,1.0]:
		box(Vector3(side*10,3,-5),Vector3(0.4,6,34),CONCRETE,true)
		box(Vector3(side*9.77,1.45,-5),Vector3(0.07,0.19,33),PAINT)
		box(Vector3(side*6.2,0.015,-5),Vector3(0.1,0.025,31),PAINT)
		box(Vector3(side*8.5,3.2,-8),Vector3(2.35,0.28,20),STEEL,true)
		box(Vector3(side*7.4,4.2,-8),Vector3(0.08,0.09,20),PAINT)
		for z in range(-18,3,3):
			box(Vector3(side*7.4,3.7,z),Vector3(0.07,1.0,0.07),PAINT)
		box(Vector3(side*3.9,0.55,-1),Vector3(2.5,1.1,1),CONCRETE,true)
		box(Vector3(side*3.9,0.71,-0.486),Vector3(2.52,0.24,0.02),STRIPES)
	for z in range(-20,12,4):
		box(Vector3(0,5.75,z),Vector3(20,0.35,0.25),STEEL)
		box(Vector3(0,5.96,z+1.6),Vector3(4.1,0.08,2.4),Color("#c8d8ce"),false,true)
		box(Vector3(0,5.86,z+1.6),Vector3(0.09,0.09,2.5),DARK)
		box(Vector3(-9.63,2.9,z),Vector3(0.35,5.8,0.45),STEEL)
		box(Vector3(9.63,2.9,z),Vector3(0.35,5.8,0.45),STEEL)
		box(Vector3(0,0.009,z),Vector3(19.4,0.013,0.035),DARK)
		box(Vector3(0,0.018,z+1.4),Vector3(0.12,0.018,1.2),PAINT)
	box(Vector3(0,2.15,-21.65),Vector3(7.8,4.3,0.25),DARK)
	for h in range(11):
		box(Vector3(0,0.3+h*0.32,-21.49),Vector3(7.3,0.045,0.06),STEEL)
	for m in groups:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = BoxMesh.new()
		mm.instance_count = groups[m].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i,groups[m][i])
		var model := MultiMeshInstance3D.new()
		model.multimesh = mm
		model.material_override = m
		# Daylight enters through the roof monitors; the industrial shell uses baked light bands.
		if m == material(DARK) or m == material(CONCRETE) or m == material(FLOOR) or m == material(SHEET):
			model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(model)
	groups.clear()
	sign_text("D E P O T      /      0 1",Vector3(0,4.75,-21.4),0.011)
	sign_text("B   0 2",Vector3(-6.8,2.9,-21.65),0.014)
	sign_text("B   0 3",Vector3(6.8,2.9,-21.65),0.014)
	for pos in [Vector3(0,1.5,-3.5),Vector3(-4.0,2.1,-8),Vector3(4.7,2.5,-10),Vector3(-2.4,1.7,-13.8),Vector3(2.2,3.1,-17)]:
		target(pos)

func beam(a: Vector3, b: Vector3, width: float, depth: float, color: Color):
	var axis := b-a
	var basis := Basis(Quaternion(Vector3.UP,axis.normalized())).scaled_local(Vector3(width,axis.length(),depth))
	var m := material(color)
	if not groups.has(m): groups[m] = []
	groups[m].append(Transform3D(basis,(a+b)*0.5))

func freight(x: float, z: float, width: float, height: float):
	box(Vector3(x,height*0.5,z),Vector3(width,height,1.15),CRATE,true)
	for side in [-1.0,1.0]:
		box(Vector3(x+side*(width*0.5-0.085),height*0.5,z),Vector3(0.11,height+0.025,1.18),STEEL)
	for y in [0.085,height-0.085]:
		box(Vector3(x,y,z),Vector3(width+0.03,0.08,1.19),DARK)
	box(Vector3(x-0.16,height*0.65,z+0.583),Vector3(0.34,0.15,0.012),IVORY)
	for i in 4:
		box(Vector3(x-0.29+i*0.055,height*0.65,z+0.593),Vector3(0.023,0.09,0.012),DARK)

func architecture():
	# An isolated inspection bay gives the armory its own lighting and silhouette.
	box(Vector3(35,0.68,-1.6),Vector3(8,0.24,3.5),STEEL)
	box(Vector3(35.34,0.86,-1.06),Vector3(1.08,0.14,0.72),DARK)
	box(Vector3(35.34,0.945,-1.06),Vector3(0.98,0.03,0.62),SHEET)
	box(Vector3(35,2.3,-2.7),Vector3(9,4.6,0.2),DARK)
	for x in range(-4,5):
		box(Vector3(35+x*0.8,2.25,-2.585),Vector3(0.76,4.3,0.04),STEEL)
		for j in 4:
			box(Vector3(35+x*0.8+0.23,1.75+j*0.085,-2.553),Vector3(0.17,0.024,0.016),DARK)
	box(Vector3(35,1.12,-2.51),Vector3(8,0.024,0.04),PAINT,false,true)
	box(Vector3(35,2.22,-2.51),Vector3(8,0.022,0.04),IVORY,false,true)
	sign_text("P U L S E    /    0 1",Vector3(36.55,2.06,-2.50),0.0026)

	for side in [-1.0,1.0]:
		for z in range(-18,10,4):
			box(Vector3(side*9.73,4.6,z),Vector3(0.14,2.4,3.8),SHEET)
			for k in 9:
				box(Vector3(side*9.62,4.6,z-1.66+k*0.41),Vector3(0.11,2.3,0.044),STEEL)
			box(Vector3(side*9.41,2.75,z),Vector3(0.23,0.13,3.95),DARK)
			box(Vector3(side*9.4,0.56,z),Vector3(0.2,0.09,3.95),STEEL)
			box(Vector3(side*8.12,3.0,z),Vector3(2.5,0.16,0.18),STEEL)
			beam(Vector3(side*9.6,1.7,z),Vector3(side*7.4,2.98,z),0.11,0.16,STEEL)
		box(Vector3(side*7.38,3.68,-8),Vector3(0.065,0.065,19.8),PAINT)
		box(Vector3(side*7.38,3.43,-8),Vector3(0.055,0.055,19.8),STEEL)
		for z in [-13.0,2.6]:
			box(Vector3(side*9.36,1.46,z),Vector3(0.18,2.83,2.0),DARK)
			box(Vector3(side*9.23,1.38,z),Vector3(0.1,2.66,1.76),SHEET)
			box(Vector3(side*9.16,1.9,z),Vector3(0.02,0.47,0.76),DARK)
			box(Vector3(side*9.11,2.95,z),Vector3(0.2,0.11,1.14),IVORY,false,true)
		for z in range(-20,10,6):
			for j in 2:
				beam(Vector3(side*(1.9+j*3.1),5.85,z),Vector3(side*(4.9+j*3.1),4.75,z),0.10,0.13,STEEL)
				beam(Vector3(side*(4.9+j*3.1),4.75,z),Vector3(side*(5.0+j*3.1),5.85,z),0.09,0.12,STEEL)
			box(Vector3(side*5.0,4.76,z),Vector3(9.9,0.14,0.19),STEEL)
	for z in range(-19,10,6):
		box(Vector3(0,5.91,z),Vector3(6.6,0.035,3.55),Color("#d7e0d8"),false,true)
		for x in range(-3,4):
			box(Vector3(x,5.86,z),Vector3(0.06,0.055,3.6),STEEL)
		box(Vector3(0,5.84,z),Vector3(6.67,0.10,0.08),STEEL)
		for x in [-5.8,5.8]:
			box(Vector3(x,4.59,z),Vector3(2.05,0.16,0.32),DARK)
			box(Vector3(x,4.49,z),Vector3(1.82,0.035,0.2),IVORY,false,true)
	freight(-7.8,-0.9,1.9,1.22)
	freight(-7.55,-2.25,1.45,1.64)
	freight(7.65,-8.6,2.15,1.30)
	freight(6.65,-15.2,1.8,1.04)
	for x in [-7.3,-6.85,6.85,7.3]:
		box(Vector3(x,1.1,-20.35),Vector3(0.14,2.2,0.14),PAINT)
	for x in [-5.2,5.2]:
		box(Vector3(x,2.55,-21.66),Vector3(1.58,3.8,0.15),STEEL)
		for y in range(9):
			box(Vector3(x,1.2+y*0.28,-21.50),Vector3(1.37,0.12,0.10),DARK)
	# Cast-in side channels frame the playable lane.
	for x in [-6.5,6.5]:
		box(Vector3(x,0.012,-4.7),Vector3(0.32,0.014,30.5),DARK)
		for z in range(-19,10):
			box(Vector3(x,0.024,z),Vector3(0.34,0.012,0.065),STEEL)

func sign_text(value: String, pos: Vector3, pixel: float):
	var label := Label3D.new()
	label.text = value
	label.font_size = 94
	label.pixel_size = pixel
	label.modulate = IVORY
	label.outline_size = 0
	label.position = pos
	add_child(label)

func part(parent: Node3D, center: Vector3, size: Vector3, color: Color, unlit := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.material_override = material(color,not unlit)
	model.position = center
	parent.add_child(model)
	return model

func disc(parent: Node3D, radius: float, z: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.035
	mesh.radial_segments = 32
	mesh.rings = 1
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.material_override = material(color,false)
	model.rotation.x = PI/2
	model.position.z = z
	parent.add_child(model)
	return model

func target(pos: Vector3):
	var body := StaticBody3D.new()
	add_child(body)
	body.position = pos
	body.set_meta("plate",rings.size())
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.72
	cylinder.height = 0.13
	var hitbox := CollisionShape3D.new()
	hitbox.shape = cylinder
	hitbox.rotation.x = PI/2
	body.add_child(hitbox)
	part(self,Vector3(pos.x,0.12,pos.z-0.10),Vector3(1.1,0.24,0.85),DARK)
	part(self,Vector3(pos.x,pos.y/2,pos.z-0.1),Vector3(0.17,pos.y,0.16),STEEL)
	disc(body,0.76,-0.05,STEEL)
	disc(body,0.74,0,DARK)
	rings.append(disc(body,0.66,0.027,MINT))
	disc(body,0.58,0.054,DARK)
	disc(body,0.47,0.067,STEEL)
	disc(body,0.35,0.081,MINT)
	disc(body,0.30,0.095,DARK)
	disc(body,0.105,0.118,IVORY)

func light_plate(index: int, enabled: bool):
	rings[index].material_override = material(PAINT if enabled else MINT,false)

func make_pulse(parent: Node3D) -> Node3D:
	var rig := PULSE_MODEL.instantiate() as Node3D
	parent.add_child(rig)
	rig.name = "ViewModel"
	return rig

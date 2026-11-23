extends Node3D

const STEEL = Color("#374c54")
const DARK = Color("#223138")
const CONCRETE = Color("#697879")
const FLOOR = Color("#576263")
const PAINT = Color("#efa847")
const IVORY = Color("#ebdfc3")
const MINT = Color("#56e4c6")
const GLOVE = Color("#273a3d")
var surfaces := {}
var groups := {}
var rings: Array[MeshInstance3D] = []

func material(color: Color, lit := true) -> StandardMaterial3D:
	var key := color.to_html() + str(lit)
	if not surfaces.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.91
		if not lit:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#62777c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#e0e9e9")
	env.ambient_light_energy = 0.75
	ambient.environment = env
	add_child(ambient)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-57,-35,-12)
	sun.light_color = Color("#fff0ce")
	sun.light_energy = 1.25
	add_child(sun)
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
		box(Vector3(side*3.9,0.71,-0.486),Vector3(2.52,0.15,0.02),PAINT)
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
		add_child(model)
	groups.clear()
	sign_text("D E P O T      /      0 1",Vector3(0,4.75,-21.4),0.011)
	sign_text("B   0 2",Vector3(-6.8,2.9,-21.65),0.014)
	sign_text("B   0 3",Vector3(6.8,2.9,-21.65),0.014)
	for pos in [Vector3(0,1.5,-3.5),Vector3(-4.0,2.1,-8),Vector3(4.7,2.5,-10),Vector3(-2.4,1.7,-13.8),Vector3(2.2,3.1,-17)]:
		target(pos)

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
	disc(body,0.74,0,DARK)
	rings.append(disc(body,0.66,0.027,MINT))
	disc(body,0.48,0.054,DARK)
	disc(body,0.31,0.081,IVORY)
	disc(body,0.13,0.108,DARK)

func light_plate(index: int, enabled: bool):
	rings[index].material_override = material(PAINT if enabled else MINT,false)

func make_pulse(parent: Node3D) -> Node3D:
	var rig := Node3D.new()
	rig.name = "ViewModel"
	parent.add_child(rig)
	var weapon := Node3D.new()
	weapon.name = "Pulse"
	rig.add_child(weapon)
	part(weapon,Vector3(0,0,-0.08),Vector3(0.145,0.13,0.34),IVORY)
	part(weapon,Vector3(0,-0.065,-0.06),Vector3(0.13,0.06,0.31),DARK)
	part(weapon,Vector3(0,0,0.09),Vector3(0.15,0.14,0.07),Color("#e77d2c"))
	part(weapon,Vector3(0,0.073,-0.08),Vector3(0.035,0.012,0.19),MINT,true)
	part(weapon,Vector3(0,0.019,0.13),Vector3(0.08,0.045,0.012),DARK)
	var hands := Node3D.new()
	hands.name = "Gloves"
	rig.add_child(hands)
	part(hands,Vector3(0,-0.1,0.05),Vector3(0.12,0.105,0.16),GLOVE)
	part(hands,Vector3(0.018,-0.15,0.15),Vector3(0.145,0.11,0.14),STEEL)
	return rig

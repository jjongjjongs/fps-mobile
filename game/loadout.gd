extends RefCounted

const NAMES := ["PULSE","FLUX","PRISM"]
const CAPACITY := [5,12,3]
const DAMAGE := [2,1,4]
const INTERVAL := [0.31,0.13,0.91]
const REACH := [55.0,17.0,65.0]
const RECHARGE := [1.05,1.3,1.7]
const INFO := ["Balanced pulse sidearm","Hold to fire  ·  Short range","Precision beam  ·  Heavy impact"]

# Tapered octagonal shells catch highlights at mobile resolution.
static func shell(parent: Node3D, depot, center: Vector3, sections: Array, color: Color):
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array]=[]
	for section: Vector3 in sections:
		var ring:=PackedVector3Array()
		for corner: Vector2 in [Vector2(-0.68,1),Vector2(0.68,1),Vector2(1,0.58),Vector2(1,-0.58),Vector2(0.68,-1),Vector2(-0.68,-1),Vector2(-1,-0.58),Vector2(-1,0.58)]:
			ring.append(center+Vector3(section.x*corner.x,section.y*corner.y,section.z))
		rings.append(ring)
	for k in rings.size()-1:
		for i in 8:
			var j:=(i+1)%8
			for v in [rings[k][i],rings[k+1][i],rings[k+1][j],rings[k][i],rings[k+1][j],rings[k][j]]:
				surface.add_vertex(v)
	for i in range(1,7):
		for v in [rings[0][0],rings[0][i],rings[0][i+1],rings[-1][0],rings[-1][i+1],rings[-1][i]]:
			surface.add_vertex(v)
	surface.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.mesh=surface.commit()
	mesh.material_override=depot.material(color)
	parent.add_child(mesh)

static func make(id: int, depot, eye: Camera3D) -> Node3D:
	if id==0: return depot.make_pulse(eye)
	var rig:=Node3D.new()
	eye.add_child(rig)
	var source=depot.PULSE_MODEL.instantiate()
	var gloves=source.get_node("Gloves")
	gloves.owner=null
	source.remove_child(gloves)
	rig.add_child(gloves)
	gloves.position=Vector3(0.018,-0.114,0.096)
	source.free()
	var color:=Color("#40d6bb") if id==1 else Color("#b99ff6")
	var length:=0.38 if id==1 else 0.62
	shell(rig,depot,Vector3.ZERO,[Vector3(0.038,0.036,0.14),Vector3(0.061,0.057,0.105),Vector3(0.061,0.057,-0.10),Vector3(0.041,0.039,-length*0.63)],depot.STEEL)
	shell(rig,depot,Vector3(0,-0.015,0),[Vector3(0.063,0.029,0.08),Vector3(0.067,0.035,0.055),Vector3(0.066,0.029,-0.044),Vector3(0.057,0.024,-0.064)],depot.IVORY)
	for i in 4:
		depot.part(rig,Vector3(0,0.056,0.045-i*0.034),Vector3(0.095,0.009,0.013),depot.DARK)
	depot.part(rig,Vector3(0,0.004,0.141),Vector3(0.053,0.029,0.006),depot.DARK)
	for i in 3:
		depot.part(rig,Vector3(-0.017+i*0.017,0.005,0.146),Vector3(0.009,0.017,0.004),color,true)
	depot.part(rig,Vector3(0,-0.075,0.07),Vector3(0.07,0.13,0.08),depot.DARK)
	for side:float in [-1.0,1.0]:
		depot.part(rig,Vector3(side*0.054,0.028,-0.045),Vector3(0.013,0.032,length*0.82),color,true)
	if id==1:
		for side:float in [-1.0,1.0]:
			depot.part(rig,Vector3(side*0.037,0,-0.23),Vector3(0.049,0.065,0.13),depot.DARK)
			depot.part(rig,Vector3(side*0.037,0,-0.30),Vector3(0.028,0.034,0.008),color,true)
	else:
		shell(rig,depot,Vector3(0,0.083,0),[Vector3(0.045,0.035,0.006),Vector3(0.034,0.031,-0.032),Vector3(0.034,0.031,-0.14),Vector3(0.045,0.040,-0.176)],depot.DARK)
		depot.part(rig,Vector3(0,0.082,0.004),Vector3(0.039,0.039,0.008),color,true)
		for n in 4:
			depot.part(rig,Vector3(0,0,-0.26-0.033*n),Vector3(0.118,0.09,0.016),depot.IVORY)
	return rig

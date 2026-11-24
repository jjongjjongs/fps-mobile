extends RefCounted
const NAMES := ["펄스","플럭스","프리즘","오로라","아틀라스","스위프트","헤일로"]
const TYPES := ["펄스 권총","연사 권총","정밀 권총","소총","기관총","기관단총","저격총"]
const CAPACITY := [5,12,3,18,36,20,4]
const DAMAGE := [2,1,4,2,2,1,4]
const INTERVAL := [0.31,0.13,0.91,0.22,0.19,0.105,1.0]
const REACH := [55.0,17.0,65.0,48.0,40.0,22.0,82.0]
const RECHARGE := [1.05,1.3,1.7,1.55,2.65,1.2,1.95]
const AUTO := [false,true,false,true,true,true,false]
const INFO := ["균형 잡힌 단발 펄스","짧은 거리에서 빠른 연사","한 발에 집중하는 정밀 사격","중거리에서 안정적인 연사","대용량 축전지로 지속 사격","가볍고 빠른 근거리 연사","고배율 조준으로 강력한 한 발"]
const ACCENTS := ["#ffc16c","#64ddd1","#bca7fc","#edbc78","#e7956a","#74dbce","#99c9f0"]
const STEEL := Color("#41505c")
const DARK := Color("#263440")
const CERAMIC := Color("#aab9b9")

static func finish(color: Color, emissive := false) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.metallic=0.52 if not emissive else 0.18
	mat.roughness=0.38
	mat.emission_enabled=emissive
	mat.emission=color
	mat.emission_energy_multiplier=0.48
	return mat

# Each station specifies the radii of an elliptical cross-section along the view axis.
static func loft(parent: Node3D, at: Vector3, stations: Array, color: Color, light:=false) -> MeshInstance3D:
	const SIDES:=32
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in stations.size():
		var section:Vector3=stations[k]
		var prev:Vector3=stations[maxi(0,k-1)]
		var next:Vector3=stations[mini(k+1,stations.size()-1)]
		for i in SIDES:
			var a:=TAU*i/SIDES
			var pos:=Vector3(section.x*cos(a),section.y*sin(a),section.z)
			var tangent:=Vector3(-section.x*sin(a),section.y*cos(a),0)
			var along:=Vector3((next.x-prev.x)*cos(a),(next.y-prev.y)*sin(a),next.z-prev.z)
			st.set_normal(along.cross(tangent).normalized())
			st.add_vertex(pos)
	for k in stations.size()-1:
		for i in SIDES:
			var a:=k*SIDES+i
			var b:=k*SIDES+(i+1)%SIDES
			for idx in [a,b,a+SIDES,b,b+SIDES,a+SIDES]: st.add_index(idx)
	for i in range(1,SIDES-1):
		for idx in [0,i+1,i]: st.add_index(idx)
		var last:=(stations.size()-1)*SIDES
		for idx in [last,last+i,last+i+1]: st.add_index(idx)
	var part:=MeshInstance3D.new()
	part.mesh=st.commit()
	part.material_override=finish(color,light)
	part.position=at
	parent.add_child(part)
	return part

# Compact curved pods are shared by the grip, optics, energy cells and illuminated inlays.
static func pod(parent:Node3D, at:Vector3, radii:Vector3, color:Color, light:=false) -> MeshInstance3D:
	var mesh:=SphereMesh.new()
	mesh.radial_segments=24
	mesh.rings=12
	mesh.radius=1
	mesh.height=2
	var item:=MeshInstance3D.new()
	item.mesh=mesh
	item.material_override=finish(color,light)
	item.position=at
	item.scale=radii
	parent.add_child(item)
	return item

static func optic(rig:Node3D,z:float,length:float,radius:float,accent:Color):
	loft(rig,Vector3(0,0.081,z),[Vector3(radius*0.83,radius*0.83,0.03),Vector3(radius,radius,0.024),Vector3(radius*0.72,radius*0.72,0),Vector3(radius*0.72,radius*0.72,-length*0.65),Vector3(radius*1.1,radius*1.1,-length),Vector3(radius,radius,-length-0.008)],DARK)
	pod(rig,Vector3(0,0.081,z+0.031),Vector3(radius*0.67,radius*0.67,0.004),accent,true)
	pod(rig,Vector3(0,0.057,z-length*0.4),Vector3(0.026,0.042,0.046),STEEL)

static func make(id: int,depot,eye: Camera3D) -> Node3D:
	if id==0: return depot.make_pulse(eye)
	var rig:=Node3D.new()
	eye.add_child(rig)
	var src=depot.PULSE_MODEL.instantiate()
	var glove=src.get_node("Gloves")
	glove.owner=null
	src.remove_child(glove)
	rig.add_child(glove)
	glove.position=Vector3(0.015,-0.10,0.083)
	src.free()
	var accent:=Color(ACCENTS[id])
	var reach:float=[0,0.18,0.28,0.43,0.47,0.25,0.59][id]
	var width:float=[0,0.046,0.047,0.049,0.067,0.046,0.044][id]
	var forward:=reach*0.56
	loft(rig,Vector3.ZERO,[Vector3(width*0.59,0.032,0.14),Vector3(width*0.90,0.049,0.125),Vector3(width,0.058,0.085),Vector3(width,0.055,-0.035),Vector3(width*0.87,0.043,-forward),Vector3(width*0.6,0.031,-forward-0.026)],STEEL)
	var grip:=pod(rig,Vector3(0,-0.079,0.063),Vector3(0.034,0.088,0.043),DARK)
	grip.rotation.x=-0.27
	for side:float in [-1.0,1.0]:
		pod(rig,Vector3(side*width*0.77,0.008,-forward*0.35),Vector3(0.018,0.037,0.064+forward*0.40),CERAMIC)
		pod(rig,Vector3(side*width*0.98,0.016,-forward*0.37),Vector3(0.01,0.007,0.053+forward*0.30),accent,true)
	var twin:=id==1 or id==4
	for lane in (2 if twin else 1):
		var x:float=(-0.022 if lane==0 else 0.022) if twin else 0.0
		var radius:=0.021 if twin else 0.026
		loft(rig,Vector3(x,0.007,0),[Vector3(radius,radius,-forward+0.024),Vector3(radius*1.22,radius*1.22,-forward),Vector3(radius*0.74,radius*0.74,-reach+0.045),Vector3(radius,radius,-reach+0.03),Vector3(radius*0.93,radius*0.93,-reach)],DARK)
		pod(rig,Vector3(x,0.007,-reach-0.002),Vector3(radius*0.62,radius*0.62,0.004),accent,true)
	if id>=3:
		var stock:=loft(rig,Vector3(0,-0.008,0),[Vector3(0.033,0.055,0.27),Vector3(0.036,0.054,0.257),Vector3(0.027,0.032,0.211),Vector3(0.022,0.023,0.153),Vector3(0.034,0.034,0.095)],DARK)
		stock.rotation.x=0.09
	if id==4:
		pod(rig,Vector3(0,-0.062,-0.088),Vector3(0.087,0.075,0.076),STEEL)
		for side:float in [-1.0,1.0]:
			pod(rig,Vector3(side*0.081,-0.062,-0.088),Vector3(0.008,0.043,0.048),accent)
	elif id in [3,5]:
		var cell:=pod(rig,Vector3(0,-0.061,-0.078),Vector3(0.032,0.067,0.04),STEEL)
		cell.rotation.x=0.28 if id==5 else -0.25
	if id in [2,6]: optic(rig,0.043,0.17 if id==6 else 0.078,0.038 if id==6 else 0.025,accent)
	elif id==3: optic(rig,0.025,0.057,0.022,accent)
	if id in [3,4,6]:
		for i in 4:
			var z:float=-forward+(i-1.5)*0.021
			loft(rig,Vector3(0,0,z),[Vector3(width*0.84,0.044,0.007),Vector3(width*0.91,0.046,0.004),Vector3(width*0.91,0.046,-0.004),Vector3(width*0.84,0.044,-0.007)],STEEL)
	return rig

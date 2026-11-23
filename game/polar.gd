extends "res://game/depot.gd"

const SNOW := Color("#d1dedf")
const WHITE := Color("#c0cfcf")
const ICE := Color("#4192a3")
const GLASS := Color("#416572")
const WINDOW := Color("#a9e9ef")
const ORANGE := Color("#de733b")
const YARD_SPAWN := Vector3(0,0.04,10)

func build():
	box(Vector3(0,-0.22,-1),Vector3(29,0.44,32),SNOW,true)
	# Low perimeter walls bound the outdoor yard, including both access lanes.
	for side in [-1.0,1.0]:
		box(Vector3(side*13.9,2.0,-1),Vector3(0.55,4.0,32),WHITE,true)
		station(side*11.3,-6.0,4.9,12.0,6.7)
		station(side*11.8,6.0,3.9,6.0,3.7)
		for z in range(-14,14,4):
			box(Vector3(side*13.55,2.5,z),Vector3(0.19,3.1,0.14),STEEL)
	for z in [-16.7,14.7]:
		box(Vector3(0,1.65,z),Vector3(28.3,3.3,0.5),WHITE,true)
		box(Vector3(0,3.34,z),Vector3(28.4,0.14,0.66),SNOW)
	station(0,-15.4,12.0,2.8,4.9)
	sign_text("P O L A R      /      0 2",Vector3(0,3.05,-13.96),0.0068)
	# Elevated enclosed gallery; floor and side frames do not obstruct the aisle.
	box(Vector3(0,4.72,-7.1),Vector3(19,0.44,2.8),STEEL,true)
	box(Vector3(0,6.75,-7.1),Vector3(19.4,0.24,3.0),SNOW)
	for z in [-8.35,-5.85]:
		box(Vector3(0,5.0,z),Vector3(19.0,0.22,0.13),ORANGE)
		for x in range(-9,10,2):
			box(Vector3(x,5.8,z),Vector3(0.12,1.9,0.15),DARK)
			beam(Vector3(x,5.0,z),Vector3(x+1.85,6.65,z),0.058,0.09,STEEL)
	for x in [-7.8,7.8]:
		box(Vector3(x,2.4,-7.1),Vector3(0.5,4.8,1.4),STEEL,true)
		box(Vector3(x,2.5,-6.37),Vector3(0.51,0.54,0.05),STRIPES)
	# Jumpable sampling platforms and a low open service passage.
	for side in [-1.0,1.0]:
		var x: float=side*4.4
		box(Vector3(x,0.33,3.8),Vector3(2.9,0.66,2),STEEL,true)
		box(Vector3(x,0.66,3.8),Vector3(2.95,0.07,2.05),SNOW,true)
		box(Vector3(x,0.47,4.82),Vector3(2.6,0.11,0.035),ORANGE)
		box(Vector3(side*5.0,0.99,-3.2),Vector3(2.3,1.98,1.8),WHITE,true)
		box(Vector3(side*5.0,1.42,-2.28),Vector3(2.15,0.16,0.03),ICE)
		for k in 4:
			box(Vector3(side*5.0-0.75+k*0.48,0.76,-2.28),Vector3(0.22,0.45,0.04),STEEL)
	for x in [-8.5,-6.1]:
		box(Vector3(x,0.61,8.0),Vector3(0.20,1.22,3.15),DARK,true)
	box(Vector3(-7.3,1.37,8.0),Vector3(2.64,0.26,3.15),WHITE,true)
	box(Vector3(-7.3,1.36,9.59),Vector3(2.62,0.12,0.03),STRIPES)
	for x in [-3.0,3.0]:
		for z in range(-12,13,3):
			box(Vector3(x,0.014,z),Vector3(0.09,0.02,1.0),ICE)
	for x in [-11.5,10.5]:
		box(Vector3(x,8,-9),Vector3(0.18,4,0.18),STEEL)
		for k in 3:
			box(Vector3(x,8.35+k*0.56,-9),Vector3(1.55-k*0.31,0.07,0.1),STEEL)
	var dome := SphereMesh.new()
	dome.radius=1.67
	dome.height=3.34
	dome.radial_segments=16
	dome.rings=8
	var radome:=MeshInstance3D.new()
	radome.mesh=dome
	radome.material_override=material(WHITE)
	radome.position=Vector3(10.6,7.5,-6.7)
	add_child(radome)
	bake_geometry()
	mountains()

func station(x: float,z: float,w: float,d: float,h: float):
	box(Vector3(x,h/2,z),Vector3(w,h,d),WHITE,true)
	box(Vector3(x,h+0.07,z),Vector3(w+0.35,0.16,d+0.4),SNOW)
	box(Vector3(x,h-0.45,z),Vector3(w+0.10,0.20,d+0.10),ICE)
	for side in [-1.0,1.0]:
		var edge: float = x+side*(w*0.5+0.03)
		for i in maxi(1,int(d/1.5)):
			var pz := z-d*0.5+0.78+i*1.48
			box(Vector3(edge,h*0.62,pz),Vector3(0.09,1.05,1.31),DARK)
			box(Vector3(edge+side*0.056,h*0.62,pz),Vector3(0.03,0.90,1.16),GLASS)
			box(Vector3(edge+side*0.077,h*0.68,pz),Vector3(0.022,0.05,1.07),WINDOW,false,true)
	for i in maxi(1,int(w/1.8)):
		box(Vector3(x-w/2+0.98+i*1.75,h*0.72,z+d/2+0.038),Vector3(1.39,0.74,0.075),GLASS)

func mountains():
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock := StandardMaterial3D.new()
	rock.vertex_color_use_as_albedo=true
	rock.cull_mode=BaseMaterial3D.CULL_DISABLED
	rock.roughness=1
	mesh.set_material(rock)
	var rng:=RandomNumberGenerator.new()
	rng.seed=2302
	var rows: Array[PackedVector3Array]=[]
	for r in 4:
		var points:=PackedVector3Array()
		for i in 80:
			var a:=TAU*i/80.0
			var dist:=32.0+r*8.0+rng.randf_range(-1.6,1.6)
			var profile:=3.8+3.2*cos(7*a)+2.2*cos(13*a+0.7)
			var h: float=[-1.5,3.3,7.5,10.2][r]+profile*r/3.0+rng.randf_range(-1.0,2.8)
			points.append(Vector3(cos(a)*dist,h,sin(a)*dist))
		rows.append(points)
	for r in 3:
		for i in 80:
			var j:=(i+1)%80
			for tri in [[rows[r][i],rows[r+1][i],rows[r+1][j]],[rows[r][i],rows[r+1][j],rows[r][j]]]:
				var normal: Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
				if normal.y<0: normal=-normal
				var color:=Color("#c8d9df") if normal.y>0.68 else Color("#748993")
				color=color.darkened(rng.randf_range(0,0.13))
				for v in tri:
					mesh.set_color(color)
					mesh.set_normal(normal)
					mesh.add_vertex(v)
	var peaks:=MeshInstance3D.new()
	peaks.mesh=mesh.commit()
	add_child(peaks)

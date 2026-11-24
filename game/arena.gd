extends "res://game/depot.gd"

const NAMES := ["타이드 부두", "사프란 중정"]
const LAYOUTS := [
	[".......", ".##..#.", "...#...", ".#...#.", "..#....", ".#..##.", "......."],
	[".......", "..##.#.", ".#.....", "...#...", ".....#.", ".#.##..", "......."]]
const STEP := 4.0
const SPAWNS := [43, 47, 5, 1]
var map_id := 0
var open_cells: Array[int] = []
var links := {}
var site: int
var marker: Label3D

func point(cell: int) -> Vector3:
	return Vector3(cell%7-3,0,floori(cell/7.0)-3)*STEP

func nearest(pos: Vector3) -> int:
	var pick:=open_cells[0]
	for cell in open_cells:
		if point(cell).distance_squared_to(pos)<point(pick).distance_squared_to(pos): pick=cell
	return pick

func next_cell(start: int, goal: int) -> int:
	if start==goal: return start
	var queue: Array[int]=[start]
	var first: Dictionary={start:start}
	for cell in queue:
		for dest: int in links[cell]:
			if first.has(dest): continue
			first[dest]=dest if cell==start else first[cell]
			if dest==goal: return first[dest]
			queue.append(dest)
	return start

func build_map(id: int, objective: String):
	map_id=id
	var dock:=id==0
	var stone:=Color("#c88c60")
	var darkstone:=Color("#884f3c")
	var teal:=Color("#257a79")
	var floor_color:=FLOOR if dock else Color("#e1b781")
	box(Vector3(0,-0.25,0),Vector3(29,0.5,29),floor_color,true)
	for cell in 49:
		var pos:=point(cell)
		if LAYOUTS[id][floori(cell/7.0)][cell%7]==".":
			open_cells.append(cell)
			continue
		if dock:
			var metal:Color=[teal,Color("#bd5d40"),Color("#536f9c")][cell%3]
			var tall:=4.8 if cell%3==0 else 2.6
			box(pos+Vector3.UP*tall/2,Vector3(3.7,tall,3.7),metal,true)
			for k in 9:
				for side:float in [-1.0,1.0]:
					box(pos+Vector3(-1.62+k*0.4,tall/2,side*1.86),Vector3(0.08,tall-0.14,0.06),metal.darkened(0.17))
					box(pos+Vector3(side*1.86,tall/2,-1.62+k*0.4),Vector3(0.06,tall-0.14,0.08),metal.darkened(0.17))
			box(pos+Vector3.UP*tall,Vector3(3.76,0.11,3.76),STEEL)
		else:
			var height:=3.5+cell%3*0.7
			box(pos+Vector3.UP*height/2,Vector3(3.85,height,3.85),stone,true)
			box(pos+Vector3.UP*(height-0.18),Vector3(4.02,0.22,4.02),darkstone)
			box(pos+Vector3.UP*(height+0.07),Vector3(4.08,0.18,4.08),IVORY)
			for face:float in [-1.0,1.0]:
				box(pos+Vector3(0,1.15,face*1.94),Vector3(1.02,2.30,0.06),teal)
				for dx in [-1,1]:
					box(pos+Vector3(dx*1.2,height-1.1,face*1.94),Vector3(0.51,0.65,0.06),darkstone)
	for cell in open_cells:
		links[cell]=[]
		for step in [-7,7,-1,1]:
			var next:int=cell+step
			if next in open_cells and point(cell).distance_to(point(next))<STEP+0.1: links[cell].append(next)
	for side:float in [-1.0,1.0]:
		for axis in 2:
			var xwall:=axis==0
			var pos:=Vector3(side*14.2,1.8,0) if xwall else Vector3(0,1.8,side*14.2)
			var shape:=Vector3(0.4,3.6,28.8) if xwall else Vector3(28.8,3.6,0.4)
			box(pos,shape,STEEL if dock else stone,true)
			box(pos+Vector3.UP*1.8,Vector3(shape.x+0.1,0.18,shape.z+0.1),PAINT if dock else darkstone)
	if dock:
		for x in [-10,10]:
			box(Vector3(x,4.7,-15.8),Vector3(0.9,9.4,1.1),PAINT)
			beam(Vector3(x,5,-15.8),Vector3(x*0.58,9,-15.8),0.24,0.24,PAINT)
		box(Vector3(0,9.3,-15.8),Vector3(23,0.85,1.05),PAINT)
		for z in range(-12,13,3):
			box(Vector3(-0.4,0.013,z),Vector3(0.15,0.02,1.3),PAINT)
	else:
		# A roofed colonnade connects both ends of the western perimeter lane.
		for z in range(-12,13,4):
			box(Vector3(-13.25,1.9,z),Vector3(0.44,3.8,0.5),darkstone,true)
		box(Vector3(-12.6,3.95,0),Vector3(2.6,0.3,27),stone,true)
		for x in [-10,-3,8]:
			box(Vector3(x,3.3,-16.6),Vector3(3.7,6.6,3.8),stone)
			box(Vector3(x,6.8,-16.6),Vector3(3.9,0.3,4.0),darkstone)
			box(Vector3(x,7.4,-16.6),Vector3(1.9,1.2,2.0),IVORY)
	site=24 if dock else 25
	if objective!="":
		var pos:=point(site)
		for d:float in [-1.0,1.0]:
			box(pos+Vector3(d*1.75,0.022,0),Vector3(0.12,0.04,3.6),MINT,false,true)
			box(pos+Vector3(0,0.022,d*1.75),Vector3(3.6,0.04,0.12),MINT,false,true)
		marker=Label3D.new()
		marker.text=objective
		marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		marker.pixel_size=0.010
		marker.modulate=MINT
		marker.position=pos+Vector3.UP*2.8
		add_child(marker)
	sign_text(NAMES[id],Vector3(0,2.8,-13.95),0.006)
	bake_geometry()

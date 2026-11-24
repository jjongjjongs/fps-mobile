extends Control

const MINT := Color("#73edd1")
const AMBER := Color("#ffb54d")
const CREAM := Color("#fff0d5")
const INK := Color("#11242be5")
var stick := Vector2.ZERO
var charges := 5
var recharge := 0.0
var flash := false
var aimed := false
var score := 0
var seconds := 30
var arena_status := ""
var beacon := ""
var arena_score := ""
var health_flash := false
var tool_name := "PULSE"
var capacity := 5
var charge_time := 1.05
var insets := Vector4.ZERO

var duel := false
var opponent := 0
var warning := false
var tagged := false
var zoom := false
var low := false
const ACTIONS := {"AIM":Vector2(0,-136),"LOW":Vector2(-102,12),"JUMP":Vector2(-92,-67)}

func action_center(action: String) -> Vector2:
	return fire_center()+Vector2(ACTIONS[action])

func action_at(point: Vector2) -> String:
	for action in ACTIONS:
		if point.distance_to(action_center(action))<=34: return action
	return ""

func stick_center() -> Vector2:
	return Vector2(100+insets.x,size.y-85-insets.w)
func fire_center() -> Vector2:
	return Vector2(size.x-88-insets.z,size.y-82-insets.w)
func pause_rect() -> Rect2:
	return Rect2(size.x-83-insets.z,15+insets.y,63,48)

func caption(text: String, point: Vector2, width: float, pixels: int, color: Color):
	draw_string(ThemeDB.fallback_font,point,text,HORIZONTAL_ALIGNMENT_CENTER,width,pixels,color)

func _draw():
	var t := insets.y
	var cx := size.x/2
	draw_rect(Rect2(cx-118,13+t,236,42),INK)
	draw_rect(Rect2(cx-118,13+t,4,42),AMBER)
	caption("%02d:%02d" % [floori(seconds/60.0),seconds%60],Vector2(cx-108,42+t),96,23,CREAM)
	if arena_score!="":
		caption(arena_score,Vector2(cx-9,40+t),124,12,AMBER)
		draw_rect(Rect2(cx-150,57+t,300,27),INK)
		caption(arena_status,Vector2(cx-148,76+t),296,14,MINT)
		if beacon!="":
			draw_rect(Rect2(insets.x+16,t+18,161,33),INK)
			caption(beacon,Vector2(insets.x+16,t+40),161,14,CREAM)
		if health_flash: draw_rect(Rect2(Vector2.ZERO,size),Color("#ed8055"),false,6)
	else: caption(("%d : %d" % [score,opponent]) if duel else "%04d" % score,Vector2(cx+4,42+t),100,23,AMBER)
	var pr := pause_rect()
	draw_rect(pr,INK)
	draw_rect(Rect2(pr.get_center()-Vector2(8,8),Vector2(5,16)),CREAM)
	draw_rect(Rect2(pr.get_center()+Vector2(3,-8),Vector2(5,16)),CREAM)
	var s := stick_center()
	draw_circle(s,60,INK,true,-1,true)
	draw_arc(s,60,0,TAU,60,Color("#efdcc59c"),2,true)
	draw_circle(s+stick*36,22,Color("#e7ded2bd"),true,-1,true)
	var f := fire_center()
	draw_circle(f,48,INK,true,-1,true)
	draw_arc(f,48,-PI/2,TAU-PI/2,60,CREAM,2,true)
	if recharge>0:
		draw_arc(f,48,-PI/2,-PI/2+TAU*clampf(1-recharge/charge_time,0.001,1),48,MINT,5,true)
	caption(tool_name,f+Vector2(-45,6),90,18,AMBER)
	caption("CHARGING" if recharge>0 else "%d  /  %d" % [charges,capacity],f+Vector2(-58,-61),116,15,CREAM)
	for action in ACTIONS:
		var point:=action_center(action)
		var active: bool=(action=="AIM" and zoom) or (action=="LOW" and low)
		draw_circle(point,29,INK,true,-1,true)
		draw_arc(point,29,0,TAU,40,MINT if active else CREAM,2,true)
		caption(action,point+Vector2(-28,5),56,14,MINT if active else CREAM)
	if warning or tagged:
		caption("DRONE +1" if tagged else "INCOMING PULSE",Vector2(cx-106,81+t),212,16,AMBER)
	var c := size/2
	var color := MINT if aimed else CREAM
	draw_circle(c,2.7,color)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c+d*6,c+d*10,color,1.4,true)
	if flash:
		caption("HIT" if arena_score!="" else ("+1" if duel else "+100"),c+Vector2(9,-13),77,21,AMBER)

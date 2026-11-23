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
var insets := Vector4.ZERO

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
	caption("00:%02d" % seconds,Vector2(cx-108,42+t),96,23,CREAM)
	caption("%04d" % score,Vector2(cx+4,42+t),100,23,AMBER)
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
		draw_arc(f,48,-PI/2,-PI/2+TAU*clampf(1-recharge/1.05,0.001,1),48,MINT,5,true)
	caption("PULSE",f+Vector2(-45,6),90,18,AMBER)
	caption("CHARGING" if recharge>0 else "%d  /  5" % charges,f+Vector2(-58,-61),116,15,CREAM)
	var c := size/2
	var color := MINT if aimed else CREAM
	draw_circle(c,2.7,color)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c+d*6,c+d*10,color,1.4,true)
	if flash:
		caption("+100",c+Vector2(9,-13),77,21,AMBER)

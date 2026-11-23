extends CanvasLayer

const Overlay = preload("res://game/overlay.gd")
const INK := Color("#11242bf2")
const MINT := Color("#75e6c8")
const CREAM := Color("#f4edda")
const AMBER := Color("#ffae42")
var root := Control.new()
var safe := Control.new()
var overlay := Overlay.new()
var card: PanelContainer
var stack: VBoxContainer
var game
var page := ""
var old_safe := Rect2()

func build(owner_game):
	game = owner_game
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.hide()
	refresh_safe_area()
	root.resized.connect(refresh_safe_area)
	show_page("home")

func refresh_safe_area():
	var rect := Rect2(Vector2.ZERO, root.size)
	if OS.get_name() == "Android":
		var area := Rect2(DisplayServer.get_display_safe_area())
		var inverse := root.get_viewport().get_screen_transform().affine_inverse()
		var adjusted := Rect2(inverse*area.position,Vector2.ZERO).expand(inverse*area.end)
		if adjusted.has_area():
			rect = rect.intersection(adjusted)
	safe.position = rect.position
	safe.size = rect.size
	overlay.insets = Vector4(rect.position.x,rect.position.y,root.size.x-rect.end.x,root.size.y-rect.end.y)
	if card:
		card.position = Vector2(36,round((safe.size.y-card.size.y)/2))

func style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

func label(value: String, px: int, color: Color):
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size",px)
	item.add_theme_color_override("font_color",color)
	stack.add_child(item)

func button(value: String, callback: Callable, primary := false):
	var b := Button.new()
	b.text = value
	b.name = value.replace(" ","_")
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 44
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var normal := AMBER if primary else Color("#30484e")
	var ink := INK if primary else CREAM
	b.add_theme_stylebox_override("normal",style(normal))
	b.add_theme_stylebox_override("hover",style(normal.lightened(0.12)))
	b.add_theme_stylebox_override("pressed",style(normal.darkened(0.13)))
	for attr in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
		b.add_theme_color_override(attr,ink)
	b.add_theme_font_size_override("font_size",18)
	b.pressed.connect(callback)
	stack.add_child(b)

func show_page(next: String):
	if is_instance_valid(card):
		card.hide()
		card.queue_free()
		card = null
	page = next
	overlay.visible = next=="play"
	if overlay.visible:
		return
	card = PanelContainer.new()
	safe.add_child(card)
	var skin := style(INK)
	skin.border_width_left = 5
	skin.border_color = AMBER
	skin.content_margin_left = 25
	skin.content_margin_right = 25
	skin.content_margin_top = 20
	skin.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel",skin)
	card.custom_minimum_size.x = 335
	stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	card.add_child(stack)
	match next:
		"home":
			label("DEPOT     /     TRAINING HALL",15,MINT)
			label("VECTOR RANGE",40,CREAM)
			button("PLAY",func(): show_page("setup"),true)
			button("ARMORY",func(): game.armory())
			button("RECORDS",func(): show_page("records"))
			button("SETTINGS",func(): show_page("settings"))
		"setup":
			label("PLAY     /     DEPOT",15,MINT)
			label("TIME ATTACK",38,CREAM)
			label("30 SEC     /     +100 PER HIT",18,AMBER)
			label("Equipment    /    PULSE",18,CREAM)
			button("START RUN",game.start_run,true)
			button("BACK",game.home)
		"armory":
			label("ARMORY     /     EQUIPPED",15,MINT)
			label("PULSE",40,CREAM)
			label("5 charges    /    Auto recharge",17,CREAM)
			button("BACK",game.home)
		"records":
			label("DEPOT     /     RECORDS",15,MINT)
			label("PERSONAL BEST",34,CREAM)
			label("Top score     %d" % game.best,22,AMBER)
			label("Best accuracy     %d%%" % game.best_accuracy,18,CREAM)
			button("BACK",game.home)
		"settings":
			label("PREFERENCES",15,MINT)
			label("SETTINGS",38,CREAM)
			button("SOUND     "+("ON" if game.sound else "OFF"),game.toggle_sound)
			button("LOOK     "+["LOW","NORMAL","HIGH"][game.sensitivity],game.change_sensitivity)
			button("BACK",game.back)
		"pause":
			label("DEPOT     /     TIME ATTACK",15,MINT)
			label("PAUSED",40,CREAM)
			button("RESUME",game.resume_run,true)
			button("SETTINGS",func(): show_page("settings"))
			button("HOME",game.home)
		"result":
			label("DEPOT     /     TIME ATTACK",15,MINT)
			label("RUN COMPLETE",36,CREAM)
			label("Score      %d" % (game.hits*100),24,AMBER)
			label("Hits   %d / %d     ·     %d%%" % [game.hits,game.shots,game.accuracy()],18,CREAM)
			button("RETRY",game.start_run,true)
			button("HOME",game.home)
	card.reset_size()
	refresh_safe_area()
	card.resized.connect(refresh_safe_area)

func update_play():
	overlay.stick = game.stick
	overlay.score = game.hits*100
	overlay.seconds = ceili(game.remaining)
	overlay.charges = game.charges
	overlay.recharge = game.recharge
	overlay.aimed = game.aimed
	overlay.flash = game.hit_flash>0
	overlay.queue_redraw()

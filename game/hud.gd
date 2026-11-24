extends CanvasLayer

const Updater = preload("res://game/updater.gd")
const Match = preload("res://game/arena_match.gd")
const Arena = preload("res://game/arena.gd")
const Gear = preload("res://game/loadout.gd")
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
	game.updates.changed.connect(update_changed)
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
			label("벡터 기지    /    훈련 센터",15,MINT)
			label("벡터 레인지",40,CREAM)
			button("플레이",func(): show_page("setup"),true)
			button("무기고",func(): game.armory())
			button("기록",func(): show_page("records"))
			button("설정",func(): show_page("settings"))
			button("업데이트",open_updates)
		"update":
			draw_update()
		"setup":
			label("플레이    /    모드 선택",15,MINT)
			button("아레나 대전",func(): show_page("arena_modes"),true)
			button("극지 드론 대결",func(): show_page("duel_setup"))
			label("시간 도전",38,CREAM)
			label("30초    /    명중당 100점",18,AMBER)
			label("훈련 장비    /    "+Gear.NAMES[game.secondary],18,CREAM)
			button("훈련 시작",game.start_run)
			button("뒤로",game.home)
		"arena_modes":
			label("아레나    /    모드 선택",15,MINT)
			for i in Match.NAMES.size():
				button(Match.NAMES[i],select_rule.bind(i))
			button("뒤로",func(): show_page("setup"))
		"arena_setup":
			label("오프라인 아레나    /    4인",15,MINT)
			label(Match.NAMES[game.chosen_rule],29,CREAM)
			label(Match.BRIEFS[game.chosen_rule].replace(". ", ".\n"),16,CREAM)
			button("전장   "+Arena.NAMES[game.chosen_map],cycle_map)
			button("주무기   "+Gear.NAMES[game.primary],game.select_slot.bind(true))
			button("보조무기   "+Gear.NAMES[game.secondary],game.select_slot.bind(false))
			button("대전 시작",game.start_match,true)
			button("뒤로",func(): show_page("arena_modes"))
		"duel_setup":
			label("극지 연구소    /    1 대 1",15,MINT)
			label("드론 대결",38,CREAM)
			label("90초   ·   5점 선취",18,AMBER)
			label("화면을 밀어 둘러보고 조준을 눌러 확대하세요.\n낮은 통로에서 앉거나 발판 위로 점프해\n드론의 공격을 피하세요.",16,CREAM)
			button("대결 시작",game.start_duel,true)
			button("뒤로",func(): show_page("setup"))
		"armory":
			label(("주무기" if game.weapon>=3 else "보조무기")+"    /    "+Gear.TYPES[game.weapon],15,MINT)
			label(Gear.NAMES[game.weapon],40,CREAM)
			label(Gear.INFO[game.weapon],17,MINT)
			label("충전량 %d발    /    자동 충전"%game.capacity(),17,CREAM)
			button("주무기   "+Gear.NAMES[game.primary],game.select_slot.bind(true),game.weapon>=3)
			button("보조무기   "+Gear.NAMES[game.secondary],game.select_slot.bind(false),game.weapon<3)
			label("같은 슬롯을 한 번 더 누르면 무기가 바뀝니다.",15,CREAM)
			button("뒤로",game.home)
		"records":
			label("훈련장    /    기록",15,MINT)
			label("개인 최고 기록",34,CREAM)
			label("최고 점수    %d점" % game.best,22,AMBER)
			label("최고 명중률    %d%%" % game.best_accuracy,18,CREAM)
			button("뒤로",game.home)
		"settings":
			label("환경 설정",15,MINT)
			label("설정",38,CREAM)
			button("소리    "+("켜짐" if game.sound else "꺼짐"),game.toggle_sound)
			button("시점 감도    "+["낮음","보통","높음"][game.sensitivity],game.change_sensitivity)
			button("뒤로",game.back)
		"pause":
			label(round_title(),15,MINT)
			label("일시 정지",40,CREAM)
			button("계속하기",game.resume_run,true)
			button("설정",func(): show_page("settings"))
			button("메인으로",game.home)
		"result":
			label(round_title(),15,MINT)
			label(game.battle.result if game.battle else (game.outcome() if game.versus else "훈련 완료"),36,CREAM)
			label(game.battle.scoreboard() if game.battle else ("나  %d     드론  %d" % [game.hits,game.rival.bot_score]) if game.versus else "점수    %d" % (game.hits*100),24,AMBER)
			label("명중   %d / %d    ·    %d%%" % [game.hits,game.shots,game.accuracy()],18,CREAM)
			button("다시 도전",game.retry,true)
			button("메인으로",game.home)
	card.reset_size()
	refresh_safe_area()
	card.resized.connect(refresh_safe_area)

func open_updates():
	show_page("update")
	if game.updates.stage in [Updater.Stage.IDLE,Updater.Stage.CURRENT,Updater.Stage.FAILED]:
		game.updates.check()

func update_changed():
	if page=="update": show_page("update")

func draw_update():
	var u=game.updates
	label("설치된 버전   "+str(ProjectSettings.get_setting("application/config/version")),16,MINT)
	label("게임 업데이트",32,CREAM)
	var tip:=Label.new()
	tip.text=u.message
	tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x=300
	stack.add_child(tip)
	match u.stage:
		Updater.Stage.AVAILABLE: button("내려받기",u.download,true)
		Updater.Stage.READY: button("업데이트 설치",u.install,true)
		Updater.Stage.CURRENT,Updater.Stage.FAILED: button("다시 확인",u.check)
		Updater.Stage.DOWNLOADING:
			var progress:=ProgressBar.new()
			progress.name="DownloadProgress"
			progress.max_value=u.size_bytes
			stack.add_child(progress)
	button("뒤로",game.home)

func _process(_delta):
	if page=="update" and game.updates.stage==Updater.Stage.DOWNLOADING:
		var progress=stack.get_node_or_null("DownloadProgress")
		if progress: progress.value=game.updates.transfer.get_downloaded_bytes()

func select_rule(value: int):
	game.chosen_rule=value
	show_page("arena_setup")

func cycle_map():
	game.chosen_map=(game.chosen_map+1)%Arena.NAMES.size()
	show_page("arena_setup")

func round_title() -> String:
	if game.battle: return Arena.NAMES[game.chosen_map]+"  /  "+Match.NAMES[game.chosen_rule]
	return "극지 연구소  /  드론 대결" if game.versus else "훈련장  /  시간 도전"

func update_play():
	overlay.arena_status=game.battle.status() if game.battle else ""
	overlay.beacon=""
	if game.battle and game.battle.arena.marker and game.battle.health[0]>0:
		var target:Vector3=game.battle.arena.marker.global_position
		var local:Vector3=game.player.to_local(target)
		var angle:=rad_to_deg(atan2(local.x,-local.z))
		var arrow:="앞" if absf(angle)<25 else ("뒤" if absf(angle)>145 else ("오른쪽" if angle>0 else "왼쪽"))
		overlay.beacon="%s   %s   %dm"%[game.battle.arena.marker.text,arrow,roundi(Vector2(local.x,local.z).length())]
	overlay.arena_score=game.battle.scoreboard() if game.battle else ""
	overlay.health_flash=game.battle!=null and game.battle.player_flash>0
	overlay.tool_name=Gear.NAMES[game.weapon]
	overlay.slot_text="보조로" if game.weapon==game.primary else "주무기로"
	overlay.capacity=game.capacity()
	overlay.charge_time=Gear.RECHARGE[game.weapon]
	overlay.stick = game.stick
	overlay.duel = game.versus
	overlay.score = game.hits if game.versus else game.hits*100
	overlay.opponent = game.rival.bot_score if game.versus else 0
	overlay.warning = game.versus and game.rival.warning>0
	overlay.tagged = game.versus and game.rival.hit_feedback>0
	overlay.zoom = game.zoom
	overlay.low = game.crouched
	overlay.seconds = ceili(game.remaining)
	overlay.charges = game.charges
	overlay.recharge = game.recharge
	overlay.aimed = game.aimed
	overlay.flash = game.hit_flash>0
	overlay.queue_redraw()

class_name BallTable
extends Node2D
## スマートボール台・パチンコ台の共通基盤。
## 持ち玉・玉貸し・払い出し・景品交換 UI と、釘や壁の当たり判定生成を受け持つ。

signal exit_requested()

const PANEL_W: float = 300.0
const SYNC_INTERVAL: float = 5.0

var shop_id: String = ""
var shop_title: String = ""
var shop_subtitle: String = ""
var balls_per_rent: int = 25
var rent_price: int = 100
var ball_is_glass: bool = false
var accent: Color = Color(0.8, 0.1, 0.1)

var held_balls: int = 0
var total_out: int = 0

var board: Node2D
var pins_body: StaticBody2D
var walls_body: StaticBody2D
var balls: Array = []

var _balls_label: Label
var _money_label: Label
var _info_label: Label
var _rent_button: Button
var _exit_button: Button
var _exchange_panel: PanelContainer
var _exchange_balls_label: Label
var _exchange_buttons: Array = []
var _float_texts: Array = []
var _sync_timer: float = 0.0
var _balls_tween: Tween
var _exchanging: bool = false


## サブクラスは _setup_table() で盤面を組み立てる
func _ready() -> void:
	held_balls = GameManager.get_stored_balls(shop_id)
	board = Node2D.new()
	add_child(board)
	pins_body = StaticBody2D.new()
	board.add_child(pins_body)
	walls_body = StaticBody2D.new()
	board.add_child(walls_body)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.45
	pm.friction = 0.1
	pins_body.physics_material_override = pm
	var pm2 := PhysicsMaterial.new()
	pm2.bounce = 0.3
	pm2.friction = 0.05
	walls_body.physics_material_override = pm2
	_setup_table()
	_build_ui()
	_update_labels()


func _setup_table() -> void:
	pass


func _exit_tree() -> void:
	GameManager.set_stored_balls(shop_id, held_balls)


# ---------------------------------------------------------------- 当たり判定

func add_pin(pos: Vector2, r: float = 2.5) -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = r
	cs.shape = c
	cs.position = pos
	pins_body.add_child(cs)


func add_wall_chain(points: PackedVector2Array, closed: bool = false) -> void:
	var n: int = points.size()
	var count: int = n if closed else n - 1
	for i: int in count:
		var cs := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = points[i]
		seg.b = points[(i + 1) % n]
		cs.shape = seg
		walls_body.add_child(cs)


static func arc_points(center: Vector2, radius: float, from_deg: float, to_deg: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in segments + 1:
		var a: float = deg_to_rad(lerpf(from_deg, to_deg, float(i) / float(segments)))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


func spawn_ball(pos: Vector2, vel: Vector2, r: float, color: Color, bounce: float, grav_scale: float) -> TableBall:
	var b := TableBall.new()
	b.setup(r, ball_is_glass, color, bounce, grav_scale)
	b.position = pos
	b.linear_velocity = vel
	board.add_child(b)
	balls.append(b)
	return b


func remove_ball(b: TableBall) -> void:
	balls.erase(b)
	if is_instance_valid(b):
		b.queue_free()


# ---------------------------------------------------------------- 玉の増減

func use_ball() -> bool:
	if held_balls <= 0:
		_flash_info("玉がありません。[B] で玉を借りよう")
		return false
	held_balls -= 1
	_update_labels()
	return true


func payout(count: int, at_board_pos: Vector2, big: bool = false) -> void:
	held_balls += count
	total_out += count
	Sound.play("bigchime" if big else "chime", -6.0)
	Sound.play("pour", -8.0)
	_spawn_float_text("+%d" % count, board.to_global(at_board_pos), big)
	_update_labels()
	_bump_balls_label()


func rent_balls() -> void:
	if _exchanging:
		return
	if not GameManager.can_pay(rent_price):
		_flash_info("お金が足りません")
		return
	GameManager.add_money(-rent_price)
	held_balls += balls_per_rent
	Sound.play("pour", -4.0)
	_update_labels()
	_bump_balls_label()


func _process(delta: float) -> void:
	_sync_timer += delta
	if _sync_timer >= SYNC_INTERVAL:
		_sync_timer = 0.0
		GameManager.set_stored_balls(shop_id, held_balls)
	_update_float_texts(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.keycode == KEY_B:
			rent_balls()
		elif k.keycode == KEY_ESCAPE:
			if _exchanging:
				_close_exchange()
			else:
				_open_exchange()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size = Vector2(PANEL_W - 28, 690)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.13, 0.08, 0.92)
	style.border_color = Color(0.95, 0.78, 0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = shop_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", GameManager.font_pop)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.add_theme_color_override("font_outline_color", accent.darkened(0.3))
	title.add_theme_constant_override("outline_size", 8)
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = shop_subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", GameManager.font_sign)
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.98, 0.95, 0.85))
	vbox.add_child(sub)

	vbox.add_child(_make_counter_box())

	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 18)
	_money_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8))
	vbox.add_child(_money_label)

	_rent_button = _make_button("玉を借りる  [B]\n%d円 → %d玉" % [rent_price, balls_per_rent], Color(0.2, 0.45, 0.25))
	_rent_button.pressed.connect(rent_balls)
	vbox.add_child(_rent_button)
	_exit_button = _make_button("景品と交換して出る  [Esc]", Color(0.6, 0.15, 0.1))
	_exit_button.pressed.connect(_open_exchange)
	vbox.add_child(_exit_button)

	var help := Label.new()
	help.text = _help_text()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = PANEL_W - 60
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8))
	vbox.add_child(help)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size.x = PANEL_W - 60
	_info_label.add_theme_font_size_override("font_size", 17)
	_info_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	vbox.add_child(_info_label)

	_build_exchange_panel(layer)


func _help_text() -> String:
	return ""


func _make_counter_box() -> Control:
	var box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.12, 0.25)
	st.border_color = Color(0.5, 0.65, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(8)
	box.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	box.add_child(v)
	var cap := Label.new()
	cap.text = "持ち玉"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 16)
	cap.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	v.add_child(cap)
	_balls_label = Label.new()
	_balls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balls_label.add_theme_font_size_override("font_size", 44)
	_balls_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_balls_label.pivot_offset = Vector2(120, 28)
	v.add_child(_balls_label)
	return box


func _make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(PANEL_W - 60, 56)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		match state:
			"hover":
				s.bg_color = color.lightened(0.15)
			"pressed":
				s.bg_color = color.darkened(0.2)
			"disabled":
				s.bg_color = Color(0.4, 0.4, 0.4, 0.6)
			_:
				s.bg_color = color
		s.border_color = Color(1.0, 0.9, 0.6)
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", Color(1, 1, 0.95))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 0.8))
	return b


func _update_labels() -> void:
	if _balls_label == null:
		return
	_balls_label.text = "%d" % held_balls
	_money_label.text = "おこづかい  %d 円" % GameManager.money
	if _exchange_balls_label:
		_exchange_balls_label.text = "持ち玉  %d 玉" % held_balls
		for eb: Dictionary in _exchange_buttons:
			(eb["button"] as Button).disabled = held_balls < int(eb["cost"])


func _bump_balls_label() -> void:
	if _balls_tween and _balls_tween.is_valid():
		_balls_tween.kill()
	_balls_label.scale = Vector2(1.25, 1.25)
	_balls_tween = create_tween()
	_balls_tween.tween_property(_balls_label, "scale", Vector2.ONE, 0.25)


func _flash_info(text: String) -> void:
	_info_label.text = text
	Sound.play("click", -10.0)


func _spawn_float_text(text: String, at_global: Vector2, big: bool) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", GameManager.font_pop)
	l.add_theme_font_size_override("font_size", 46 if big else 32)
	l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	l.add_theme_color_override("font_outline_color", Color(0.6, 0.05, 0.05))
	l.add_theme_constant_override("outline_size", 10)
	l.position = at_global - Vector2(30, 30)
	l.z_index = 50
	add_child(l)
	_float_texts.append({"label": l, "t": 0.0})


func _update_float_texts(delta: float) -> void:
	for i: int in range(_float_texts.size() - 1, -1, -1):
		var ft: Dictionary = _float_texts[i]
		var l: Label = ft["label"]
		ft["t"] = float(ft["t"]) + delta
		l.position.y -= 40.0 * delta
		l.modulate.a = clampf(1.6 - float(ft["t"]), 0.0, 1.0)
		if float(ft["t"]) > 1.6:
			l.queue_free()
			_float_texts.remove_at(i)


# ---------------------------------------------------------------- 景品交換

func _build_exchange_panel(layer: CanvasLayer) -> void:
	_exchange_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.97, 0.93, 0.82)
	st.border_color = Color(0.55, 0.12, 0.08)
	st.set_border_width_all(4)
	st.set_corner_radius_all(12)
	st.set_content_margin_all(22)
	_exchange_panel.add_theme_stylebox_override("panel", st)
	_exchange_panel.anchor_left = 0.5
	_exchange_panel.anchor_right = 0.5
	_exchange_panel.anchor_top = 0.5
	_exchange_panel.anchor_bottom = 0.5
	_exchange_panel.offset_left = -260
	_exchange_panel.offset_right = 260
	_exchange_panel.offset_top = -300
	_exchange_panel.offset_bottom = 300
	_exchange_panel.visible = false
	layer.add_child(_exchange_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_exchange_panel.add_child(v)
	var t := Label.new()
	t.text = "景品交換所"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", GameManager.font_sign)
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", Color(0.55, 0.1, 0.05))
	v.add_child(t)
	_exchange_balls_label = Label.new()
	_exchange_balls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exchange_balls_label.add_theme_font_size_override("font_size", 22)
	_exchange_balls_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.1))
	v.add_child(_exchange_balls_label)
	for p: Dictionary in GameManager.PRIZES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_l := Label.new()
		name_l.text = "%s" % p["label"]
		name_l.custom_minimum_size.x = 250
		name_l.add_theme_font_size_override("font_size", 20)
		name_l.add_theme_color_override("font_color", Color(0.2, 0.12, 0.08))
		row.add_child(name_l)
		var btn: Button = _make_button("%d玉で交換" % int(p["cost"]), Color(0.75, 0.35, 0.1))
		btn.custom_minimum_size = Vector2(190, 40)
		var pid: String = p["id"]
		var cost: int = p["cost"]
		btn.pressed.connect(func() -> void: _exchange(pid, cost))
		row.add_child(btn)
		v.add_child(row)
		_exchange_buttons.append({"button": btn, "cost": cost})
	var note := Label.new()
	note.text = "残った玉は貯玉として預かります"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.4, 0.3, 0.25))
	v.add_child(note)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	v.add_child(hb)
	var back: Button = _make_button("まだ遊ぶ", Color(0.2, 0.4, 0.6))
	back.custom_minimum_size = Vector2(200, 50)
	back.pressed.connect(_close_exchange)
	hb.add_child(back)
	var leave: Button = _make_button("店を出る", Color(0.6, 0.15, 0.1))
	leave.custom_minimum_size = Vector2(200, 50)
	leave.pressed.connect(_leave)
	hb.add_child(leave)


func _open_exchange() -> void:
	_exchanging = true
	_exchange_panel.visible = true
	get_tree().paused = false
	_set_board_paused(true)
	_update_labels()
	Sound.play("click", -6.0)


func _close_exchange() -> void:
	_exchanging = false
	_exchange_panel.visible = false
	_set_board_paused(false)
	Sound.play("click", -6.0)


func _set_board_paused(p: bool) -> void:
	board.process_mode = Node.PROCESS_MODE_DISABLED if p else Node.PROCESS_MODE_INHERIT


func _exchange(prize_id: String, cost: int) -> void:
	if held_balls < cost:
		return
	held_balls -= cost
	GameManager.add_prize(prize_id)
	Sound.play("chime", -6.0)
	_update_labels()
	_flash_info("%s をもらった！" % GameManager.get_prize_label(prize_id))


func _leave() -> void:
	# 盤面に残っている玉は持ち玉に戻す
	held_balls += balls.size()
	for b: TableBall in balls.duplicate():
		remove_ball(b)
	GameManager.set_stored_balls(shop_id, held_balls)
	exit_requested.emit()

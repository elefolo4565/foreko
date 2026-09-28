extends Node
## スマートボール台の調整モード（F2）。
## 釘の移動・追加・削除、穴の移動と点数切り替え、穴の入りやすさ等のパラメータ調整を行い、
## user://smartball_layout.json に保存する。

enum Mode { MOVE, ADD, DELETE }

const PICK_HOLE_PX: float = 28.0
const PICK_PIN_PX: float = 12.0
const GRID_PX: float = 5.0

var table: SmartBall3D

var _mode: Mode = Mode.MOVE
var _sel_kind: String = ""  # "pin" / "hole" / ""
var _sel_index: int = -1
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _snap: bool = false
var _reset_armed: bool = false

var _layer: CanvasLayer
var _open_button: Button
var _panel: PanelContainer
var _mode_buttons: Array = []
var _info_label: Label
var _value_button: Button
var _delete_button: Button
var _reset_button: Button
var _sliders: Dictionary = {}  # name -> {slider, label, fmt}
var _highlight: MeshInstance3D
var _highlight_mat: StandardMaterial3D


func _ready() -> void:
	_build_ui()
	_build_highlight()
	_set_panel_visible(false)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 11
	add_child(_layer)

	_open_button = _make_button("台を調整  [F2]", Color(0.25, 0.3, 0.45))
	_open_button.anchor_left = 1.0
	_open_button.anchor_right = 1.0
	_open_button.anchor_top = 1.0
	_open_button.anchor_bottom = 1.0
	_open_button.offset_left = -230
	_open_button.offset_right = -14
	_open_button.offset_top = -60
	_open_button.offset_bottom = -14
	_open_button.pressed.connect(toggle)
	_layer.add_child(_open_button)

	_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.13, 0.2, 1.0)
	st.border_color = Color(0.5, 0.7, 1.0)
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", st)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -330
	_panel.offset_right = -10
	_panel.offset_top = 10
	_layer.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)

	var title := Label.new()
	title.text = "台の調整モード"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	v.add_child(title)

	# ツール切り替え
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	v.add_child(tools)
	var names: Array = ["選択・移動", "釘を追加", "釘を削除"]
	for i: int in names.size():
		var b: Button = _make_button(names[i], Color(0.2, 0.3, 0.5))
		b.custom_minimum_size = Vector2(96, 34)
		b.toggle_mode = true
		var mode_i: int = i
		b.pressed.connect(func() -> void: _set_mode(mode_i as Mode))
		tools.add_child(b)
		_mode_buttons.append(b)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(300, 44)
	_info_label.add_theme_font_size_override("font_size", 15)
	_info_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	v.add_child(_info_label)

	var sel_row := HBoxContainer.new()
	sel_row.add_theme_constant_override("separation", 4)
	v.add_child(sel_row)
	_value_button = _make_button("穴の点数 5⇔15 [V]", Color(0.55, 0.3, 0.15))
	_value_button.custom_minimum_size = Vector2(150, 32)
	_value_button.pressed.connect(_toggle_hole_value)
	sel_row.add_child(_value_button)
	_delete_button = _make_button("釘を消す [Del]", Color(0.55, 0.15, 0.15))
	_delete_button.custom_minimum_size = Vector2(142, 32)
	_delete_button.pressed.connect(_delete_selected)
	sel_row.add_child(_delete_button)

	var snap := CheckBox.new()
	snap.text = "グリッドに吸着（5px）"
	snap.focus_mode = Control.FOCUS_NONE
	snap.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	snap.add_theme_font_size_override("font_size", 15)
	snap.toggled.connect(func(on: bool) -> void: _snap = on)
	v.add_child(snap)

	var sep := HSeparator.new()
	v.add_child(sep)
	var ptitle := Label.new()
	ptitle.text = "穴の入りやすさ・釘"
	ptitle.add_theme_font_size_override("font_size", 16)
	ptitle.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	v.add_child(ptitle)
	_add_slider(v, "capture_r", "落ちる範囲（穴の中心から）", 2.0, 20.0, 0.1, "%.1f px")
	_add_slider(v, "capture_speed", "落ちる速さの上限", 0.3, 8.0, 0.05, "%.2f")
	_add_slider(v, "pull", "くぼみの引き込み", 0.0, 10.0, 0.1, "%.1f")
	_add_slider(v, "bounce", "釘の反発", 0.05, 0.95, 0.01, "%.2f")

	var sep2 := HSeparator.new()
	v.add_child(sep2)
	var cam_row := HBoxContainer.new()
	cam_row.add_theme_constant_override("separation", 4)
	v.add_child(cam_row)
	var top_btn: Button = _make_button("真上から見る", Color(0.2, 0.35, 0.3))
	top_btn.custom_minimum_size = Vector2(146, 32)
	top_btn.pressed.connect(func() -> void: table.set_camera_view(0.0, -1.5, 8.6))
	cam_row.add_child(top_btn)
	var norm_btn: Button = _make_button("いつもの視点", Color(0.2, 0.35, 0.3))
	norm_btn.custom_minimum_size = Vector2(146, 32)
	norm_btn.pressed.connect(func() -> void: table.set_camera_view(0.0, -1.0, 9.2))
	cam_row.add_child(norm_btn)

	var file_row := HBoxContainer.new()
	file_row.add_theme_constant_override("separation", 4)
	v.add_child(file_row)
	var save_btn: Button = _make_button("保存 [Ctrl+S]", Color(0.15, 0.45, 0.25))
	save_btn.custom_minimum_size = Vector2(146, 34)
	save_btn.pressed.connect(_save)
	file_row.add_child(save_btn)
	_reset_button = _make_button("初期配置に戻す", Color(0.45, 0.2, 0.2))
	_reset_button.custom_minimum_size = Vector2(146, 34)
	_reset_button.pressed.connect(_on_reset_pressed)
	file_row.add_child(_reset_button)

	var done: Button = _make_button("調整を終えて遊ぶ  [F2]", Color(0.6, 0.45, 0.1))
	done.custom_minimum_size = Vector2(296, 38)
	done.pressed.connect(toggle)
	v.add_child(done)

	var help := Label.new()
	help.text = "左クリック：選ぶ／ドラッグで移動\n矢印キー：1px 移動（Shift で 5px）\n右ドラッグ：視点　ホイール：ズーム"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	v.add_child(help)


func _add_slider(parent: Control, key: String, caption: String, min_v: float, max_v: float, step: float, fmt: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var cap := Label.new()
	cap.text = caption
	cap.custom_minimum_size.x = 190
	cap.add_theme_font_size_override("font_size", 14)
	cap.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	row.add_child(cap)
	var val := Label.new()
	val.custom_minimum_size.x = 70
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	row.add_child(val)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.custom_minimum_size = Vector2(296, 20)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(x: float) -> void: _on_slider(key, x))
	parent.add_child(slider)
	_sliders[key] = {"slider": slider, "label": val, "fmt": fmt}


func _make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		match state:
			"hover":
				s.bg_color = color.lightened(0.15)
			"pressed":
				s.bg_color = color.lightened(0.35)
			"disabled":
				s.bg_color = Color(0.3, 0.3, 0.3, 0.6)
			_:
				s.bg_color = color
		s.border_color = Color(0.85, 0.9, 1.0, 0.8)
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		s.set_content_margin_all(5)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 0.7))
	b.add_theme_color_override("font_hover_pressed_color", Color(1, 1, 0.7))
	return b


func _build_highlight() -> void:
	_highlight = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.05
	tm.outer_radius = 0.07
	tm.rings = 24
	tm.ring_segments = 6
	_highlight.mesh = tm
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.albedo_color = Color(1.0, 0.95, 0.2)
	_highlight_mat.emission_enabled = true
	_highlight_mat.emission = Color(1.0, 0.9, 0.2)
	_highlight_mat.emission_energy_multiplier = 3.0
	_highlight_mat.no_depth_test = true
	_highlight.material_override = _highlight_mat
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_highlight.visible = false
	table.board.add_child(_highlight)


# ---------------------------------------------------------------- 状態

func toggle() -> void:
	var on: bool = not table.editing
	table.set_editing(on)
	_set_panel_visible(on)
	if on:
		_sync_sliders()
		_set_mode(Mode.MOVE)
		_select("", -1)
	else:
		_dragging = false
		_highlight.visible = false
		_save()
	Sound.play("click", -6.0)


func _set_panel_visible(on: bool) -> void:
	_panel.visible = on
	_open_button.visible = not on


func _set_mode(m: Mode) -> void:
	_mode = m
	for i: int in _mode_buttons.size():
		(_mode_buttons[i] as Button).button_pressed = i == int(m)
	_update_info()


func _sync_sliders() -> void:
	_set_slider("capture_r", table.capture_r_px)
	_set_slider("capture_speed", table.capture_speed)
	_set_slider("pull", table.pull)
	_set_slider("bounce", table.pin_bounce)


func _set_slider(key: String, value: float) -> void:
	var e: Dictionary = _sliders[key]
	(e["slider"] as HSlider).set_value_no_signal(value)
	(e["label"] as Label).text = String(e["fmt"]) % value


func _on_slider(key: String, x: float) -> void:
	match key:
		"capture_r":
			table.capture_r_px = x
		"capture_speed":
			table.capture_speed = x
		"pull":
			table.pull = x
		"bounce":
			table.set_pin_bounce(x)
	var e: Dictionary = _sliders[key]
	(e["label"] as Label).text = String(e["fmt"]) % x


func _select(kind: String, index: int) -> void:
	_sel_kind = kind
	_sel_index = index
	_update_highlight()
	_update_info()


func _selected_pos() -> Vector2:
	if _sel_kind == "pin":
		return table.get_pin_positions()[_sel_index]
	if _sel_kind == "hole":
		return table.holes[_sel_index]["pos"]
	return Vector2.ZERO


func _update_highlight() -> void:
	if _sel_kind == "":
		_highlight.visible = false
		return
	_highlight.visible = true
	var r: float = 1.0 if _sel_kind == "pin" else 5.0
	_highlight.scale = Vector3(r, 1.0, r)
	_highlight.position = table.p3(_selected_pos(), 0.24 if _sel_kind == "pin" else 0.05)


func _update_info() -> void:
	var mode_text: Array = ["選択・移動", "釘を追加（盤面をクリック）", "釘を削除（釘をクリック）"]
	var t: String = "ツール：%s\n釘 %d 本" % [mode_text[int(_mode)], table.get_pin_positions().size()]
	if _sel_kind == "pin":
		var p: Vector2 = _selected_pos()
		t += "　選択：釘 #%d (%.0f, %.0f)" % [_sel_index, p.x, p.y]
	elif _sel_kind == "hole":
		var hp: Vector2 = _selected_pos()
		t += "　選択：穴 #%d [%d点] (%.0f, %.0f)" % [_sel_index, int(table.holes[_sel_index]["value"]), hp.x, hp.y]
	_info_label.text = t
	_value_button.disabled = _sel_kind != "hole"
	_delete_button.disabled = _sel_kind != "pin"


# ---------------------------------------------------------------- 入力

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F2:
		toggle()
		return
	if not table.editing:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_left_press(mb.position)
			else:
				_dragging = false
				_update_info()
	elif event is InputEventMouseMotion and _dragging:
		_on_drag((event as InputEventMouseMotion).position)
	elif event is InputEventKey and event.pressed:
		_on_key(event as InputEventKey)


func _on_key(k: InputEventKey) -> void:
	if k.keycode == KEY_S and k.ctrl_pressed:
		_save()
		return
	if k.echo and k.keycode not in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		return
	match k.keycode:
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selected()
		KEY_V:
			_toggle_hole_value()
		KEY_1:
			_set_mode(Mode.MOVE)
		KEY_2:
			_set_mode(Mode.ADD)
		KEY_3:
			_set_mode(Mode.DELETE)
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if _sel_kind == "":
				return
			var step: float = 5.0 if k.shift_pressed else 1.0
			var d := Vector2.ZERO
			match k.keycode:
				KEY_LEFT:
					d.x = -step
				KEY_RIGHT:
					d.x = step
				KEY_UP:
					d.y = -step
				KEY_DOWN:
					d.y = step
			_move_selected(_selected_pos() + d)


## 画面座標 → 盤面のピクセル座標（盤面の平面との交点）
func _screen_to_px(screen_pos: Vector2) -> Variant:
	var cam: Camera3D = table.camera
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var plane := Plane(table.board.global_basis.y.normalized(), table.board.global_position)
	var hit: Variant = plane.intersects_ray(from, dir)
	if hit == null:
		return null
	return table.to_px(table.board.to_local(hit as Vector3))


func _on_left_press(screen_pos: Vector2) -> void:
	var hit: Variant = _screen_to_px(screen_pos)
	if hit == null:
		return
	var px: Vector2 = hit
	match _mode:
		Mode.ADD:
			var p: Vector2 = _snapped(px)
			if table.is_on_field(p):
				var idx: int = table.add_pin(p)
				_select("pin", idx)
				Sound.play("clack", -10.0)
		Mode.DELETE:
			var pi: int = _nearest_pin(px)
			if pi >= 0:
				table.remove_pin(pi)
				_select("", -1)
				Sound.play("click", -8.0)
		Mode.MOVE:
			var hi: int = _nearest_hole(px)
			var pin_i: int = _nearest_pin(px)
			# 釘が近ければ釘を優先（穴を囲む釘を掴めるように）
			if pin_i >= 0:
				_select("pin", pin_i)
			elif hi >= 0:
				_select("hole", hi)
			else:
				_select("", -1)
				return
			_dragging = true
			_drag_offset = _selected_pos() - px
			Sound.play("click", -12.0)


func _on_drag(screen_pos: Vector2) -> void:
	var hit: Variant = _screen_to_px(screen_pos)
	if hit == null or _sel_kind == "":
		return
	_move_selected(_snapped((hit as Vector2) + _drag_offset))


func _move_selected(px: Vector2) -> void:
	if not table.is_on_field(px):
		return
	if _sel_kind == "pin":
		table.move_pin(_sel_index, px)
	elif _sel_kind == "hole":
		table.set_hole_pos(_sel_index, px)
	_update_highlight()
	_update_info()


func _snapped(px: Vector2) -> Vector2:
	if _snap:
		return px.snapped(Vector2(GRID_PX, GRID_PX))
	return px


func _nearest_pin(px: Vector2) -> int:
	var best: int = -1
	var best_d: float = PICK_PIN_PX
	var pins: Array = table.get_pin_positions()
	for i: int in pins.size():
		var d: float = px.distance_to(pins[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func _nearest_hole(px: Vector2) -> int:
	var best: int = -1
	var best_d: float = PICK_HOLE_PX
	for i: int in table.holes.size():
		var d: float = px.distance_to(table.holes[i]["pos"])
		if d < best_d:
			best_d = d
			best = i
	return best


# ---------------------------------------------------------------- 操作

func _toggle_hole_value() -> void:
	if _sel_kind != "hole":
		return
	var cur: int = table.holes[_sel_index]["value"]
	table.set_hole_value(_sel_index, 15 if cur == 5 else 5)
	_update_info()
	Sound.play("click", -8.0)


func _delete_selected() -> void:
	if _sel_kind != "pin":
		return
	table.remove_pin(_sel_index)
	_select("", -1)
	Sound.play("click", -8.0)


func _save() -> void:
	table.save_layout()
	if SmartBall3D.is_dev_project():
		GameManager.toast_requested.emit("台の設計を保存しました（本体にも反映）")
	else:
		GameManager.toast_requested.emit("台の配置を保存しました")


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "本当に戻す？"
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			_reset_armed = false
			_reset_button.text = "初期配置に戻す"
		)
		return
	_reset_armed = false
	_reset_button.text = "初期配置に戻す"
	table.reset_layout()
	_select("", -1)
	_sync_sliders()
	GameManager.toast_requested.emit("初期配置に戻しました")

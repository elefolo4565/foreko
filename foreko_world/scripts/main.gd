extends Node
## ルートノード。町と遊技台の切り替え、フェード、トーストを担当する。

const TownScript: GDScript = preload("res://scripts/world/town.gd")
## 店 ID → ミニゲームの入口シーン。
## ミニゲームは別プロジェクト（D:/gameProject/foreko_smartball 等）で開発し、
## res://minigames/<id>/ に取り込む。入口のルートノードは exit_requested シグナルを持つこと
const MINIGAMES: Dictionary = {
	"smartball": "res://minigames/smartball/smartball.tscn",
	"pachinko": "res://minigames/pachinko/pachinko.tscn",
}

var _current: Node = null
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _fade_tween: Tween
var _toast_label: Label
var _toast_tween: Tween
var _is_switching: bool = false


func _ready() -> void:
	_setup_theme()
	_build_overlay()
	GameManager.toast_requested.connect(show_toast)
	_show_town()
	_fade_rect.color.a = 1.0
	_fade_to(0.0, 0.8)
	_debug_capture()


## 開発用：`-- --shot=<town|smartball|pachinko> --out=<png>` で自動撮影して終了
func _debug_capture() -> void:
	var mode: String = ""
	var out_path: String = ""
	var wait: float = 3.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			mode = a.substr(7)
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--wait="):
			wait = float(a.substr(7))
	if mode == "":
		return
	if mode.begins_with("sim_"):
		_debug_simulate(mode.substr(4), wait)
		return
	if mode == "char" or mode == "charwalk" or mode == "charside":
		var pl: ForekoPlayer = _current.get("_player")
		pl.set("_cam_yaw", PI)
		pl.set("_cam_dist", 2.6)
		pl.set("_cam_pitch", -0.1)
		if mode == "charwalk":
			Input.action_press("move_back")
		elif mode == "charside":
			pl.global_position = Vector3(-3.5, 0.1, -20.0)
			Input.action_press("move_left")
	elif mode == "smartball_edit":
		_show_game("smartball")
		_fade_rect.color.a = 0.0
		var ed: Node = _current.get("_editor")
		ed.call("toggle")
		ed.call("_select", "hole", 4)
		_current.call("set_camera_view", 0.0, -1.5, 8.6)
	elif mode != "town":
		_show_game(mode)
		_fade_rect.color.a = 0.0
		var game: BallTable = _table_of(_current)
		game.held_balls += 30
		for i: int in 12:
			get_tree().create_timer(0.3 + i * 0.9).timeout.connect(func() -> void:
				Input.action_press("shoot")
				get_tree().create_timer(0.3 + (i % 4) * 0.15).timeout.connect(func() -> void:
					Input.action_release("shoot")
				)
			)
	await get_tree().create_timer(wait).timeout
	if out_path == "":
		get_tree().quit()
		return
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(out_path)
	get_tree().quit()


## 開発用：出玉バランスの検証。`-- --shot=sim_pachinko:0.6 --wait=60`
func _debug_simulate(spec: String, seconds: float) -> void:
	var parts: PackedStringArray = spec.split(":")
	var game_id: String = parts[0]
	var power: float = float(parts[1]) if parts.size() > 1 else -1.0
	_show_game(game_id)
	var game: BallTable = _table_of(_current)
	game.held_balls = 100000
	var start_balls: int = game.held_balls
	# 物理の1ステップを実機（1/120 秒）と同じにしたまま4倍速で回す
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 32
	var t: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	while t < seconds:
		if game_id == "pachinko":
			game.set("_power", power if power >= 0.0 else rng.randf())
			Input.action_press("shoot")
			await get_tree().create_timer(0.2).timeout
			t += 0.2
		else:
			var hold: float = rng.randf_range(0.3, 1.2) if power < 0.0 else power / 0.9
			Input.action_press("shoot")
			await get_tree().create_timer(hold).timeout
			Input.action_release("shoot")
			await get_tree().create_timer(0.6).timeout
			t += hold + 0.6
	Input.action_release("shoot")
	await get_tree().create_timer(12.0).timeout
	var on_board: Array = _current.get("balls")
	var used: int = start_balls - game.held_balls + game.total_out - on_board.size()
	print("SIM %s power=%s used=%d out=%d rate=%.1f%% hits=%s" % [game_id, power, used, game.total_out,
		100.0 * float(game.total_out) / maxf(1.0, float(used)), game.get("_hit_counts") if game_id == "pachinko" else str(_current.get("line_lit"))])
	GameManager.set_stored_balls(game_id, 0)
	game.held_balls = 0
	get_tree().quit()


## 遊技台ノードから持ち玉管理（BallTable）を取り出す。3D スマートボールは hud に持つ
func _table_of(node: Node) -> BallTable:
	if node is BallTable:
		return node
	return node.get("hud")


func _setup_theme() -> void:
	var theme := Theme.new()
	theme.default_font = GameManager.font_ui
	theme.default_font_size = 18
	get_tree().root.theme = theme


func _build_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.05, 0.03, 0.02, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

	_toast_label = Label.new()
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_label.position = Vector2(-400, 90)
	_toast_label.size = Vector2(800, 60)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 30)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_toast_label.add_theme_color_override("font_outline_color", Color(0.35, 0.1, 0.05))
	_toast_label.add_theme_constant_override("outline_size", 10)
	_toast_label.modulate.a = 0.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_toast_label)


func show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)


func _fade_to(alpha: float, duration: float) -> Tween:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, "color:a", alpha, duration)
	return _fade_tween


func _replace_current(node: Node) -> void:
	if _current:
		_current.queue_free()
	_current = node
	add_child(node)
	move_child(node, 0)


func _show_town() -> void:
	var town: Node3D = TownScript.new()
	town.shop_entered.connect(_on_shop_entered)
	_replace_current(town)
	Sound.play_town()
	GameManager.check_allowance()


func _show_game(shop_id: String) -> void:
	var scene: PackedScene = load(String(MINIGAMES.get(shop_id, "")))
	if scene == null:
		push_error("ミニゲームが見つかりません: %s" % shop_id)
		return
	var game: Node = scene.instantiate()
	if not game.has_signal("exit_requested"):
		push_error("ミニゲーム %s のルートに exit_requested シグナルがありません" % shop_id)
	game.connect("exit_requested", _on_game_exit)
	_replace_current(game)
	Sound.play_march()


func _on_shop_entered(shop_id: String) -> void:
	if _is_switching:
		return
	_is_switching = true
	Sound.play("door")
	GameManager.return_shop = shop_id
	var tw: Tween = _fade_to(1.0, 0.5)
	tw.tween_callback(func() -> void:
		_show_game(shop_id)
		_fade_to(0.0, 0.5)
		_is_switching = false
	)


func _on_game_exit() -> void:
	if _is_switching:
		return
	_is_switching = true
	Sound.play("door")
	var tw: Tween = _fade_to(1.0, 0.5)
	tw.tween_callback(func() -> void:
		_show_town()
		_fade_to(0.0, 0.6)
		_is_switching = false
	)

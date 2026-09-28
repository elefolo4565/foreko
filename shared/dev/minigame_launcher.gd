extends Node
## ミニゲーム開発用プロジェクトの起動シーン。
## project.godot の [foreko] minigame_scene に書かれたミニゲームをすぐに起動する。
## 「店を出る」（exit_requested）で町の代わりにミニゲームを作り直す。
## 本体（foreko_world）では使わない。

const SETTING_SCENE: String = "foreko/minigame_scene"

var _current: Node = null
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = GameManager.font_ui
	theme.default_font_size = 18
	get_tree().root.theme = theme
	_build_toast()
	GameManager.toast_requested.connect(_show_toast)
	_start_game()


func _start_game() -> void:
	var path: String = ProjectSettings.get_setting(SETTING_SCENE, "")
	var scene: PackedScene = load(path) if path != "" else null
	if scene == null:
		push_error("[foreko] minigame_scene が正しく設定されていません: %s" % path)
		return
	if _current:
		_current.queue_free()
	_current = scene.instantiate()
	if _current.has_signal("exit_requested"):
		_current.connect("exit_requested", _on_exit_requested)
	else:
		push_error("ミニゲームのルートに exit_requested シグナルがありません")
	add_child(_current)
	move_child(_current, 0)
	Sound.play_march()


func _on_exit_requested() -> void:
	Sound.play("door")
	_show_toast("（開発用）店を出た → 台を作り直します")
	_start_game.call_deferred()


func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
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
	layer.add_child(_toast_label)


func _show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)

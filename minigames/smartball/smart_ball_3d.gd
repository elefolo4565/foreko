class_name SmartBall3D
extends Node3D
## 3D のスマートボール台。傾いた盤面の上をガラス玉が転がる。
## 盤面レイアウトは 2D のピクセル座標（幅 500 × 高さ 660）で定義し、p3() で 3D に変換する。
## 持ち玉・玉貸し・景品交換の UI は BallTable（SmartHud）を流用する。

signal exit_requested()


## 画面 UI と持ち玉管理（BallTable の盤面機能は使わない）
class SmartHud extends BallTable:
	func _init() -> void:
		shop_id = "smartball"
		shop_title = "スマートボール"
		shop_subtitle = "〜 金 星 〜"
		balls_per_rent = 25
		rent_price = 100
		ball_is_glass = true
		accent = Color(0.15, 0.35, 0.8)

	func _help_text() -> String:
		return "Space 長押し→離す：玉を打つ\n強さで飛び方が変わる\n右ドラッグ：視点を回す\nホイール：ズーム\n[R] 盤面リセット"


## 盤面の絵（SubViewport でテクスチャにする）
class FieldArt extends Node2D:
	var field_poly: PackedVector2Array
	var art_scale: float = 2.0

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(art_scale, art_scale))
		draw_rect(Rect2(-20, -20, 560, 720), Color(0.98, 0.8, 0.15))
		draw_colored_polygon(field_poly, Color(0.97, 0.93, 0.82))
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		# 水色の模様（スクショの淡い水色の砂浜のような塊）
		for i: int in 16:
			var c := Vector2(rng.randf_range(20, 440), rng.randf_range(40, 600))
			var blob := PackedVector2Array()
			var r0: float = rng.randf_range(45, 95)
			for k: int in 20:
				var a: float = k * TAU / 20.0
				blob.append(c + Vector2.from_angle(a) * r0 * (0.75 + 0.3 * sin(a * 3.0 + i)))
			_fill_clipped(blob, Color(0.62, 0.86, 0.9, 0.55))
		# ヤシの葉
		var teal := Color(0.28, 0.7, 0.68, 0.85)
		for leaf: Array in [[Vector2(95, 250), 0.5], [Vector2(400, 185), 2.9], [Vector2(70, 470), -0.4], [Vector2(420, 470), 3.4], [Vector2(215, 575), 1.0], [Vector2(360, 575), 2.2]]:
			_draw_palm(leaf[0], leaf[1], teal)
		# ハイビスカス
		for fl: Vector2 in [Vector2(40, 560), Vector2(330, 610), Vector2(430, 95), Vector2(35, 150)]:
			for k2: int in 5:
				_fill_clipped(_circle(fl + Vector2.from_angle(k2 * TAU / 5.0) * 14.0, 13.0), Color(1.0, 0.55, 0.45, 0.85))
			_fill_clipped(_circle(fl, 6.0), Color(1.0, 0.85, 0.3))
		# 発射レーン
		draw_rect(Rect2(450, 250, 30, 390), Color(0.12, 0.3, 0.7))
		draw_rect(Rect2(456, 260, 18, 375), Color(0.08, 0.2, 0.5))
		# 外周の縁取り
		var outline: PackedVector2Array = field_poly.duplicate()
		outline.append(field_poly[0])
		draw_polyline(outline, Color(0.7, 0.55, 0.1), 3.0, true)

	func _circle(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k: int in 16:
			pts.append(c + Vector2.from_angle(k * TAU / 16.0) * r)
		return pts

	func _draw_palm(center: Vector2, rot: float, color: Color) -> void:
		for k: int in 6:
			var a: float = rot + (k - 2.5) * 0.42
			var dir: Vector2 = Vector2.from_angle(a)
			var side: Vector2 = dir.orthogonal() * 14.0
			var leaf := PackedVector2Array([center, center + dir * 28.0 + side, center + dir * 62.0, center + dir * 28.0 - side])
			_fill_clipped(leaf, color)

	func _fill_clipped(pts: PackedVector2Array, color: Color) -> void:
		for c: PackedVector2Array in Geometry2D.intersect_polygons(pts, field_poly):
			draw_colored_polygon(c, color)


const S: float = 0.01
const TILT_DEG: float = 11.0
const ARC_C: Vector2 = Vector2(245, 240)
const ARC_R: float = 235.0
const LANE_L: float = 450.0
const LANE_R: float = 480.0
const LANE_BOTTOM: float = 640.0
const DRAIN_Y: float = 598.0
const BALL_R: float = 0.115
const HOLE_R_PX: float = 15.0
## 穴に落ちる条件（中心からの距離・盤面上の速さ）と、くぼみの引き込みの強さ
## 玉の中心が穴の中心から capture_r_px 以内で、盤面上の速さが capture_speed 未満なら落ちる。
## 中心付近（capture_r_px の 35% 以内）を通った玉は速さに関係なく落ちる。
## 穴の開口部（濃い青）は半径約 16px、玉は半径 11.5px
const DEFAULT_CAPTURE_R_PX: float = 7.0
const DEFAULT_CAPTURE_SPEED: float = 1.3
const DEFAULT_PULL: float = 0.6
const LAYOUT_VERSION: int = 2
const DEFAULT_PIN_BOUNCE: float = 0.5
## 台の配置ファイル
## BOARD_LAYOUT_PATH: 台の設計（開発用プロジェクト foreko_smartball で保存し、本体に取り込まれる）
## USER_LAYOUT_PATH : 本体でプレイヤーが調整モードで保存した配置（あれば設計より優先）
const BOARD_LAYOUT_PATH: String = "res://minigames/smartball/board_layout.json"
const USER_LAYOUT_PATH: String = "user://smartball_layout.json"
const BoardEditorScript: GDScript = preload("res://minigames/smartball/smart_ball_editor.gd")
const DEFAULT_HOLES: Array = [
	[Vector2(110, 108), 5], [Vector2(245, 108), 5], [Vector2(380, 108), 5],
	[Vector2(95, 318), 15], [Vector2(245, 330), 15], [Vector2(395, 318), 15],
	[Vector2(105, 492), 5], [Vector2(245, 500), 5], [Vector2(385, 492), 5],
]
const GRAV_SCALE: float = 1.5
const WALL_H: float = 0.26
const LID_Y: float = 0.27
const BALL_COLOR: Color = Color(0.1, 0.35, 1.0)

const LINES: Array = [[3, 4, 5], [1, 4, 7], [0, 4, 8], [2, 4, 6], [0, 1, 2], [6, 7, 8], [0, 3, 6], [2, 5, 8]]
const LINE_BONUS: Array = [15, 15, 15, 15, 5, 5, 5, 5]
const FULL_BONUS: int = 100

var hud: SmartHud
## 調整モード中は玉を打てず、物理も止まる
var editing: bool = false
var capture_r_px: float = DEFAULT_CAPTURE_R_PX
var capture_speed: float = DEFAULT_CAPTURE_SPEED
var pull: float = DEFAULT_PULL
var pin_bounce: float = DEFAULT_PIN_BOUNCE
var board: Node3D
var camera: Camera3D
var balls: Array = []
var holes: Array = []  # {pos, value, filled, marker, ring_mat, ring_col}
var line_lit: Array = [false, false, false, false, false, false, false, false]

var _b: WorldBuilder = WorldBuilder.new()
var _walls: StaticBody3D
var _pins: StaticBody3D
var _pin_positions: Array = []
var _pin_shapes: Array = []
var _pin_mmis: Array = []
var _pin_pmat: PhysicsMaterial
var _editor: Node
var _ball_mat: StandardMaterial3D
var _lamps: Array = []  # {mesh, on, off, label}
var _power: float = 0.0
var _charging: bool = false
var _plunger: Node3D
var _spring_rings: Array = []
var _tray: Node3D
var _tray_shown: int = -1
var _score_label: Label3D
var _count_label: Label3D
var _lamp_flash: float = 0.0
var _anim_t: float = 0.0
var _cam_yaw: float = 0.0
var _cam_pitch: float = -1.0
var _cam_dist: float = 9.2
var _power_bar: ColorRect
var _power_back: Panel
var _out_label: Label
var _reset_pending: bool = false


func _ready() -> void:
	hud = SmartHud.new()
	hud.exit_requested.connect(_on_hud_exit)
	add_child(hud)
	_build_environment()
	board = Node3D.new()
	board.rotation_degrees.x = TILT_DEG
	add_child(board)
	_build_surface()
	_build_walls()
	_build_holes()
	_build_pins_body()
	_pin_positions = _default_pin_positions()
	_load_layout()
	rebuild_pins()
	_build_lamp_panel()
	_build_gate()
	_build_cabinet()
	_build_plunger()
	_build_room()
	_build_camera()
	_build_side_ui()
	_editor = BoardEditorScript.new()
	_editor.set("table", self)
	add_child(_editor)
	_ball_mat = StandardMaterial3D.new()
	_ball_mat.albedo_color = BALL_COLOR
	_ball_mat.metallic = 0.1
	_ball_mat.roughness = 0.04
	_ball_mat.clearcoat_enabled = true
	_ball_mat.rim_enabled = true
	_ball_mat.rim = 0.6
	_ball_mat.emission_enabled = true
	_ball_mat.emission = Color(0.05, 0.2, 0.7)
	_ball_mat.emission_energy_multiplier = 0.4


# ================================================================ 座標変換

func p3(v: Vector2, y: float = 0.0) -> Vector3:
	return Vector3((v.x - 245.0) * S, y, (v.y - 320.0) * S)


func to_px(local: Vector3) -> Vector2:
	return Vector2(local.x / S + 245.0, local.z / S + 320.0)


func _field_polygon() -> PackedVector2Array:
	var pts: PackedVector2Array = BallTable.arc_points(ARC_C, ARC_R, -180.0, 0.0, 48)
	pts.append(Vector2(LANE_R, LANE_BOTTOM))
	pts.append(Vector2(LANE_L, LANE_BOTTOM))
	pts.append(Vector2(LANE_L, 560))
	pts.append(Vector2(290, 612))
	pts.append(Vector2(200, 612))
	pts.append(Vector2(10, 560))
	return pts


# ================================================================ 構築

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.07, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.85, 0.7)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 20.0
	sun.rotation_degrees = Vector3(-62, 25, 0)
	add_child(sun)
	for x: float in [-3.5, 3.5]:
		var l := OmniLight3D.new()
		l.position = Vector3(x, 4.0, 1.0)
		l.light_color = Color(1.0, 0.8, 0.55)
		l.light_energy = 0.7
		l.omni_range = 9.0
		add_child(l)


func _build_surface() -> void:
	# 盤面の絵をテクスチャ化
	var sv := SubViewport.new()
	sv.size = Vector2i(1000, 1320)
	sv.transparent_bg = false
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var art := FieldArt.new()
	art.field_poly = _field_polygon()
	sv.add_child(art)
	add_child(sv)
	var surf_mat := StandardMaterial3D.new()
	surf_mat.albedo_texture = sv.get_texture()
	surf_mat.roughness = 0.6
	surf_mat.clearcoat_enabled = true
	surf_mat.clearcoat = 0.15
	surf_mat.clearcoat_roughness = 0.4
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.0, 6.6)
	plane.mesh = pm
	plane.material_override = surf_mat
	plane.position = p3(Vector2(250, 330))
	board.add_child(plane)
	# 盤面と、玉が飛び出さないためのガラス板（当たり判定のみ）
	var body := StaticBody3D.new()
	var pmat := PhysicsMaterial.new()
	pmat.friction = 0.0
	pmat.bounce = 0.1
	body.physics_material_override = pmat
	board.add_child(body)
	_add_box_shape(body, Vector3(6.0, 0.2, 8.0), p3(Vector2(250, 330), -0.1))
	_add_box_shape(body, Vector3(6.0, 0.1, 8.0), p3(Vector2(250, 330), LID_Y + 0.05))
	# ガラス板の見た目（ごく薄い反射）
	var glass := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(5.0, 6.6)
	glass.mesh = gm
	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(1, 1, 1, 0.04)
	glass_mat.roughness = 0.0
	glass_mat.metallic_specular = 1.0
	glass.material_override = glass_mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.position = p3(Vector2(250, 330), LID_Y + 0.02)
	board.add_child(glass)


func _add_box_shape(body: StaticBody3D, size: Vector3, pos: Vector3, rot_y: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	cs.rotation.y = rot_y
	body.add_child(cs)


func _build_walls() -> void:
	_walls = StaticBody3D.new()
	var pmat := PhysicsMaterial.new()
	pmat.bounce = 0.35
	pmat.friction = 0.1
	_walls.physics_material_override = pmat
	board.add_child(_walls)
	var chrome: StandardMaterial3D = _b.metal_mat(Color(0.85, 0.86, 0.9))
	_wall_chain(BallTable.arc_points(ARC_C, ARC_R + 2.0, 0.0, -180.0, 48), chrome)
	_wall_chain(PackedVector2Array([Vector2(8, 240), Vector2(8, 560), Vector2(200, 614), Vector2(290, 614), Vector2(LANE_L, 560)]), chrome)
	_wall_chain(PackedVector2Array([Vector2(LANE_L, 262), Vector2(LANE_L, LANE_BOTTOM), Vector2(LANE_R + 2.0, LANE_BOTTOM), Vector2(LANE_R + 2.0, 240)]), chrome)


func _wall_chain(points: PackedVector2Array, material: Material) -> void:
	for i: int in points.size() - 1:
		var a: Vector3 = p3(points[i])
		var b: Vector3 = p3(points[i + 1])
		var mid: Vector3 = (a + b) * 0.5
		var d: Vector3 = b - a
		var length: float = d.length() + 0.03
		var rot: float = atan2(-d.z, d.x)
		_add_box_shape(_walls, Vector3(length, WALL_H, 0.04), mid + Vector3(0, WALL_H * 0.5, 0), rot)
		var mi: MeshInstance3D = _b.box(board, Vector3(length, 0.1, 0.045), mid + Vector3(0, 0.05, 0), material)
		mi.rotation.y = rot


func _build_holes() -> void:
	for d: Array in DEFAULT_HOLES:
		holes.append(_create_hole(d[0], d[1]))


func _hole_color(value: int) -> Color:
	return Color(0.3, 0.75, 0.45) if value == 5 else Color(0.97, 0.45, 0.25)


func _create_hole(pos: Vector2, value: int) -> Dictionary:
	var col: Color = _hole_color(value)
	var root := Node3D.new()
	root.position = p3(pos)
	board.add_child(root)
	# 受け皿のふち（ドーナツ）
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.15
	tm.outer_radius = 0.27
	tm.rings = 24
	tm.ring_segments = 12
	ring.mesh = tm
	ring.scale = Vector3(1, 0.45, 1)
	ring.position.y = 0.012
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = col
	ring_mat.roughness = 0.3
	ring_mat.clearcoat_enabled = true
	ring_mat.emission_enabled = true
	ring_mat.emission = col
	ring_mat.emission_energy_multiplier = 0.0
	ring.material_override = ring_mat
	root.add_child(ring)
	# 穴の中（濃い青）
	_b.cyl(root, 0.165, 0.012, Vector3(0, 0.004, 0), _b.mat(Color(0.06, 0.16, 0.45), "", 1.0, 0.4), Vector3.ZERO, -1.0, 24)
	_b.cyl(root, 0.11, 0.014, Vector3(0, 0.006, 0.035), _b.mat(Color(0.02, 0.05, 0.2), "", 1.0, 0.5), Vector3.ZERO, -1.0, 20)
	var num: Label3D = _b.label(root, str(value), Vector3(0, 0.045, -0.21), GameManager.font_pop, 64, Color(0.06, 0.1, 0.2), false, 0.0021, Color(1, 1, 1, 0.9), 8)
	num.rotation_degrees.x = -90.0
	num.shaded = false
	# 入った玉の表示
	var marker: MeshInstance3D = _b.sphere(root, BALL_R, Vector3(0, 0.02, 0.02), _b.mat(BALL_COLOR, "", 1.0, 0.05))
	marker.visible = false
	return {"pos": pos, "value": value, "filled": false, "marker": marker, "ring_mat": ring_mat, "root": root, "label": num}


func _build_pins_body() -> void:
	_pins = StaticBody3D.new()
	_pin_pmat = PhysicsMaterial.new()
	_pin_pmat.bounce = pin_bounce
	_pin_pmat.friction = 0.1
	_pins.physics_material_override = _pin_pmat
	board.add_child(_pins)


## 初期配置の釘（穴を囲む馬てい形・ゲート・ランプ盤脇・散らし釘）
func _default_pin_positions() -> Array:
	var result: Array = []
	for d: Array in DEFAULT_HOLES:
		var hp: Vector2 = d[0]
		for ang: float in [-135.0, -45.0, -168.0, -12.0, 150.0, 30.0]:
			result.append(hp + Vector2.from_angle(deg_to_rad(ang)) * 31.0)
	for x: float in [218.0, 232.0, 258.0, 272.0]:
		result.append(Vector2(x, 272.0 + absf(x - 245.0) * 0.4))
	for x2: float in [96.0, 394.0]:
		result.append(Vector2(x2, 190.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1958
	var row: int = 0
	var y: float = 60.0
	while y < 560.0:
		var off: float = 21.0 if row % 2 == 0 else 0.0
		var x3: float = 30.0 + off
		while x3 < LANE_L - 18.0:
			var p := Vector2(x3 + rng.randf_range(-5, 5), y + rng.randf_range(-5, 5))
			if _pin_allowed(p, result):
				result.append(p)
			x3 += 44.0
		y += 40.0
		row += 1
	return result


## 釘の当たり判定と見た目（MultiMesh）を作り直す
func rebuild_pins() -> void:
	for old_cs: CollisionShape3D in _pin_shapes:
		old_cs.queue_free()
	_pin_shapes.clear()
	for old_mmi: MultiMeshInstance3D in _pin_mmis:
		old_mmi.queue_free()
	_pin_mmis.clear()
	# 当たり判定と見た目（MultiMesh でまとめて描画）
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.018
	shaft.bottom_radius = 0.022
	shaft.height = 0.2
	shaft.radial_segments = 8
	var head := SphereMesh.new()
	head.radius = 0.034
	head.height = 0.05
	head.radial_segments = 10
	head.rings = 5
	var mm_shaft := MultiMesh.new()
	mm_shaft.transform_format = MultiMesh.TRANSFORM_3D
	mm_shaft.mesh = shaft
	mm_shaft.instance_count = _pin_positions.size()
	var mm_head := MultiMesh.new()
	mm_head.transform_format = MultiMesh.TRANSFORM_3D
	mm_head.mesh = head
	mm_head.instance_count = _pin_positions.size()
	for i: int in _pin_positions.size():
		var pos: Vector3 = p3(_pin_positions[i])
		mm_shaft.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.1, 0)))
		mm_head.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.2, 0)))
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.03
		cyl.height = 0.3
		cs.shape = cyl
		cs.position = pos + Vector3(0, 0.15, 0)
		_pins.add_child(cs)
		_pin_shapes.append(cs)
	var metal: StandardMaterial3D = _b.metal_mat(Color(0.82, 0.84, 0.88))
	for mm: MultiMesh in [mm_shaft, mm_head]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = metal
		board.add_child(mmi)
		_pin_mmis.append(mmi)


func _pin_allowed(p: Vector2, existing: Array) -> bool:
	if p.y < ARC_C.y and p.distance_to(ARC_C) > ARC_R - 22.0:
		return false
	if p.x < 26.0 or p.x > LANE_L - 16.0 or p.y > 545.0:
		return false
	if p.y > 158.0 and p.y < 222.0 and p.x > 90.0 and p.x < 400.0:
		return false
	if p.y > 232.0 and p.y < 300.0 and absf(p.x - 245.0) < 55.0:
		return false
	for d: Array in DEFAULT_HOLES:
		if p.distance_to(d[0]) < 50.0:
			return false
	for q: Vector2 in existing:
		if p.distance_to(q) < 30.0:
			return false
	return true


# ================================================================ 調整用 API（SmartBallEditor から使う）

func get_pin_positions() -> Array:
	return _pin_positions


func is_on_field(px: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(px, _field_polygon()) and px.x < LANE_L - 8.0


## 釘 1 本だけ動かす（ドラッグ中は毎フレーム呼ばれるので全体を作り直さない）
func move_pin(i: int, px: Vector2) -> void:
	_pin_positions[i] = px
	var pos: Vector3 = p3(px)
	(_pin_shapes[i] as CollisionShape3D).position = pos + Vector3(0, 0.15, 0)
	(_pin_mmis[0] as MultiMeshInstance3D).multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.1, 0)))
	(_pin_mmis[1] as MultiMeshInstance3D).multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.2, 0)))


func add_pin(px: Vector2) -> int:
	_pin_positions.append(px)
	rebuild_pins()
	return _pin_positions.size() - 1


func remove_pin(i: int) -> void:
	_pin_positions.remove_at(i)
	rebuild_pins()


func set_hole_pos(i: int, px: Vector2) -> void:
	holes[i]["pos"] = px
	(holes[i]["root"] as Node3D).position = p3(px)


func set_hole_value(i: int, value: int) -> void:
	var h: Dictionary = holes[i]
	h["value"] = value
	var col: Color = _hole_color(value)
	var rm: StandardMaterial3D = h["ring_mat"]
	rm.albedo_color = col
	rm.emission = col
	(h["label"] as Label3D).text = str(value)


func set_pin_bounce(v: float) -> void:
	pin_bounce = v
	if _pin_pmat:
		_pin_pmat.bounce = v


func set_editing(on: bool) -> void:
	editing = on
	if on:
		# 盤面の玉は持ち玉に戻す
		hud.held_balls += balls.size()
		for b: RigidBody3D in balls.duplicate():
			_remove_ball(b)
		hud._update_labels()
		_charging = false
		_power = 0.0
		_update_plunger()


func set_camera_view(yaw: float, pitch: float, dist: float) -> void:
	_cam_yaw = yaw
	_cam_pitch = pitch
	_cam_dist = dist
	_update_camera()


func layout_to_dict() -> Dictionary:
	var pins: Array = []
	for p: Vector2 in _pin_positions:
		pins.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	var hs: Array = []
	for h: Dictionary in holes:
		var hp: Vector2 = h["pos"]
		hs.append([snappedf(hp.x, 0.1), snappedf(hp.y, 0.1), int(h["value"])])
	return {
		"version": LAYOUT_VERSION, "pins": pins, "holes": hs,
		"params": {"capture_r_px": capture_r_px, "capture_speed": capture_speed, "pull": pull, "pin_bounce": pin_bounce},
	}


func apply_layout(data: Dictionary) -> void:
	var hs: Array = data.get("holes", [])
	if hs.size() == holes.size():
		for i: int in hs.size():
			var e: Array = hs[i]
			set_hole_pos(i, Vector2(float(e[0]), float(e[1])))
			set_hole_value(i, int(e[2]))
	var pins: Array = data.get("pins", [])
	if not pins.is_empty():
		_pin_positions = []
		for e2: Array in pins:
			_pin_positions.append(Vector2(float(e2[0]), float(e2[1])))
	var prm: Dictionary = data.get("params", {})
	# 旧バージョンの判定値は厳しすぎたので、新しい初期値に置き換える
	if int(data.get("version", 1)) < LAYOUT_VERSION:
		prm.erase("capture_r_px")
		prm.erase("capture_speed")
		prm.erase("pull")
	capture_r_px = float(prm.get("capture_r_px", DEFAULT_CAPTURE_R_PX))
	capture_speed = float(prm.get("capture_speed", DEFAULT_CAPTURE_SPEED))
	pull = float(prm.get("pull", DEFAULT_PULL))
	set_pin_bounce(float(prm.get("pin_bounce", DEFAULT_PIN_BOUNCE)))


## 開発用プロジェクト（foreko_smartball）で動いているか
static func is_dev_project() -> bool:
	return ProjectSettings.has_setting("foreko/minigame_scene")


## 保存先：開発用プロジェクトでは台の設計ファイル、本体ではプレイヤーの配置
func get_save_path() -> String:
	return BOARD_LAYOUT_PATH if is_dev_project() else USER_LAYOUT_PATH


func save_layout() -> void:
	if not GameManager.save_enabled:
		return
	var f := FileAccess.open(get_save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(layout_to_dict(), "\t"))


func _load_layout() -> void:
	if not is_dev_project() and _load_layout_file(USER_LAYOUT_PATH):
		return
	_load_layout_file(BOARD_LAYOUT_PATH)


func _load_layout_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		apply_layout(parsed)
		return true
	return false


## 初期配置に戻す。本体ではプレイヤーの配置を消して台の設計に、開発用では組み込みの初期値に戻す
func reset_layout() -> void:
	for i: int in DEFAULT_HOLES.size():
		set_hole_pos(i, DEFAULT_HOLES[i][0])
		set_hole_value(i, DEFAULT_HOLES[i][1])
	capture_r_px = DEFAULT_CAPTURE_R_PX
	capture_speed = DEFAULT_CAPTURE_SPEED
	pull = DEFAULT_PULL
	set_pin_bounce(DEFAULT_PIN_BOUNCE)
	_pin_positions = _default_pin_positions()
	rebuild_pins()
	if not is_dev_project():
		if FileAccess.file_exists(USER_LAYOUT_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_LAYOUT_PATH))
		if _load_layout_file(BOARD_LAYOUT_PATH):
			rebuild_pins()


func _build_lamp_panel() -> void:
	var center: Vector3 = p3(Vector2(245, 189))
	_b.box(board, Vector3(2.9, 0.05, 0.58), center + Vector3(0, 0.025, 0), _b.metal_mat(Color(0.8, 0.8, 0.83)))
	_b.box(board, Vector3(2.78, 0.06, 0.48), center + Vector3(0, 0.03, 0), _b.mat(Color(0.12, 0.12, 0.16)))
	for li: int in 8:
		var base: Color = Color(0.97, 0.38, 0.28) if LINE_BONUS[li] == 15 else Color(0.62, 0.32, 0.85)
		var x: float = -1.37 + 0.3425 * (float(li) + 0.5) - 0.0
		var on_mat := StandardMaterial3D.new()
		on_mat.albedo_color = base.lightened(0.25)
		on_mat.emission_enabled = true
		on_mat.emission = base
		on_mat.emission_energy_multiplier = 2.5
		var off_mat: StandardMaterial3D = _b.mat(base.darkened(0.25), "", 1.0, 0.35)
		var cell: MeshInstance3D = _b.box(board, Vector3(0.31, 0.05, 0.42), center + Vector3(x, 0.06, 0), off_mat)
		var l: Label3D = _b.label(board, str(LINE_BONUS[li]), center + Vector3(x, 0.09, 0.0), GameManager.font_pop, 64, Color(0.1, 0.08, 0.12), false, 0.0034, Color(1, 1, 1, 0.5), 6)
		l.rotation_degrees.x = -90.0
		_lamps.append({"mesh": cell, "on": on_mat, "off": off_mat, "label": l})


func _build_gate() -> void:
	var c: Vector3 = p3(Vector2(245, 252))
	_b.box(board, Vector3(0.95, 0.06, 0.3), c + Vector3(0, 0.03, 0), _b.metal_mat(Color(0.8, 0.8, 0.83)))
	_b.box(board, Vector3(0.85, 0.07, 0.22), c + Vector3(0, 0.035, 0), _b.mat(Color(0.1, 0.22, 0.5)))
	var tri := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.26, 0.18, 0.02)
	tri.mesh = pm
	tri.material_override = _b.mat(Color(1.0, 0.45, 0.25), "", 1.0, 0.4)
	tri.rotation_degrees.x = -90.0
	tri.position = c + Vector3(0, 0.08, 0)
	board.add_child(tri)


func _build_cabinet() -> void:
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.99, 0.8, 0.12)
	yellow.roughness = 0.3
	yellow.clearcoat_enabled = true
	var blue: StandardMaterial3D = _b.mat(Color(0.12, 0.35, 0.72), "", 1.0, 0.35)
	var h: float = 0.32
	# 左右と下の枠
	_b.box(board, Vector3(0.45, h, 7.9), p3(Vector2(-22, 330), h * 0.5 - 0.02), yellow)
	_b.box(board, Vector3(0.5, h, 7.9), p3(Vector2(508, 330), h * 0.5 - 0.02), yellow)
	# 本体（盤面の下）
	_b.box(board, Vector3(5.95, 0.7, 8.4), p3(Vector2(243, 320), -0.37), yellow)
	# ヘッダー
	var head_c: Vector3 = p3(Vector2(243, -45))
	_b.box(board, Vector3(5.95, h, 1.0), head_c + Vector3(0, h * 0.5 - 0.02, 0), yellow)
	_b.box(board, Vector3(4.0, 0.06, 0.8), head_c + Vector3(0, h + 0.01, 0), blue)
	for s: float in [-1.0, 1.0]:
		for k: int in 3:
			var leaf: MeshInstance3D = _b.box(board, Vector3(0.5, 0.01, 0.1), head_c + Vector3(s * 1.55, h + 0.05, -0.15 + k * 0.15), _b.mat(Color(0.2, 0.5, 0.85)))
			leaf.rotation_degrees.y = s * (25.0 - k * 20.0)
	var title: Label3D = _b.label(board, "SMART BALL", head_c + Vector3(0, h + 0.06, -0.08), GameManager.font_pop, 128, Color(1.0, 0.42, 0.22), false, 0.0055, Color(1, 1, 1), 22)
	title.rotation_degrees.x = -90.0
	var dome: MeshInstance3D = _b.sphere(board, 0.14, head_c + Vector3(0, h + 0.03, 0.28), _b.glow_mat(Color(1.0, 0.25, 0.15), 1.5))
	dome.scale = Vector3(1.4, 0.7, 1.0)
	# スコア表示と持ち玉表示
	var score_c: Vector3 = p3(Vector2(40, -40), h + 0.02)
	_b.box(board, Vector3(1.3, 0.06, 0.6), score_c, _b.mat(Color(0.08, 0.2, 0.45)))
	var sl: Label3D = _b.label(board, "SCORE", score_c + Vector3(0, 0.05, -0.18), GameManager.font_ui, 48, Color(1, 1, 1), false, 0.003)
	sl.rotation_degrees.x = -90.0
	_score_label = _b.label(board, "00000", score_c + Vector3(0, 0.05, 0.08), GameManager.font_pop, 80, Color(1, 1, 1), false, 0.0042, Color(0.02, 0.05, 0.15), 16)
	_score_label.rotation_degrees.x = -90.0
	var cnt_c: Vector3 = p3(Vector2(445, -40), h + 0.02)
	_b.box(board, Vector3(1.2, 0.06, 0.6), cnt_c, _b.mat(Color(0.08, 0.2, 0.45)))
	var cnt_ball: MeshInstance3D = _b.sphere(board, 0.14, cnt_c + Vector3(-0.3, 0.1, 0), _b.mat(BALL_COLOR, "", 1.0, 0.05))
	cnt_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_count_label = _b.label(board, "0", cnt_c + Vector3(0.2, 0.06, 0), GameManager.font_pop, 90, Color(1, 1, 1), false, 0.0042)
	_count_label.rotation_degrees.x = -90.0
	# 下の受け皿
	var tray_c: Vector3 = p3(Vector2(225, 705))
	_b.box(board, Vector3(5.1, h, 1.2), tray_c + Vector3(0, h * 0.5 - 0.02, 0), yellow)
	_b.box(board, Vector3(4.5, 0.05, 0.8), tray_c + Vector3(0, h + 0.0, 0), _b.mat(Color(0.05, 0.12, 0.35)))
	_tray = Node3D.new()
	_tray.position = tray_c + Vector3(0, h + 0.1, 0)
	board.add_child(_tray)
	# 四隅のねじ
	for sp: Vector2 in [Vector2(-30, -85), Vector2(515, -85), Vector2(-30, 750), Vector2(515, 750)]:
		_b.cyl(board, 0.06, 0.02, p3(sp, h + 0.0), _b.metal_mat(Color(0.6, 0.6, 0.62)))


func _build_plunger() -> void:
	_plunger = Node3D.new()
	board.add_child(_plunger)
	var knob: MeshInstance3D = _b.cyl(_plunger, 0.2, 0.16, Vector3.ZERO, _b.mat(Color(0.92, 0.25, 0.18), "", 1.0, 0.25), Vector3(90, 0, 0), -1.0, 24)
	knob.name = "Knob"
	var arrow: Label3D = _b.label(_plunger, "↑", Vector3(0, 0.12, 0), GameManager.font_pop, 110, Color(1, 1, 1), false, 0.0035)
	arrow.rotation_degrees.x = -90.0
	var spring_mat: StandardMaterial3D = _b.metal_mat(Color(0.75, 0.75, 0.78))
	for k: int in 6:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07
		tm.outer_radius = 0.1
		tm.rings = 16
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = spring_mat
		ring.rotation_degrees.x = 90.0
		board.add_child(ring)
		_spring_rings.append(ring)
	_update_plunger()


func _update_plunger() -> void:
	var cx: float = (LANE_L + LANE_R) * 0.5 + 1.0
	var knob_y: float = LANE_BOTTOM + 58.0 + _power * 30.0
	_plunger.position = p3(Vector2(cx, knob_y), 0.12)
	for k: int in _spring_rings.size():
		var t: float = float(k) / float(_spring_rings.size() - 1)
		var ring: MeshInstance3D = _spring_rings[k]
		ring.position = p3(Vector2(cx, lerpf(LANE_BOTTOM + 4.0, knob_y - 10.0, t)), 0.12)


func _build_room() -> void:
	var floor_mat: StandardMaterial3D = _b.mat(Color(0.4, 0.28, 0.2), "planks", 0.8)
	_b.box(self, Vector3(40, 0.2, 40), Vector3(0, -2.4, 0), floor_mat)
	_b.box(self, Vector3(40, 12, 0.3), Vector3(0, 3.0, -9.0), _b.mat(Color(0.5, 0.36, 0.25), "hplanks", 0.6))
	# 台の脚
	for x: float in [-2.6, 2.6]:
		for z: float in [-3.0, 3.0]:
			_b.box(self, Vector3(0.2, 2.2, 0.2), Vector3(x, -1.3, z), _b.mat(Color(0.3, 0.2, 0.12)))
	# 両隣の台（シルエット）
	for x2: float in [-7.5, 7.5]:
		var neighbor: MeshInstance3D = _b.box(self, Vector3(5.8, 0.9, 8.2), Vector3(x2, -0.35, 0), _b.mat(Color(0.95, 0.75, 0.15), "", 1.0, 0.4))
		neighbor.rotation_degrees.x = TILT_DEG
		_b.box(self, Vector3(4.8, 0.05, 6.4), Vector3(x2, 0.12, 0.1), _b.mat(Color(0.93, 0.9, 0.8)), Vector3(TILT_DEG, 0, 0))
	# 壁の品書き
	for i: int in 3:
		var sign_pos := Vector3(-6.0 + i * 6.0, 3.6, -8.8)
		_b.box(self, Vector3(1.6, 0.9, 0.05), sign_pos, _b.mat(Color(0.97, 0.94, 0.85)))
		var texts: Array = ["一回 百円", "景品 いろいろ", "金 星"]
		_b.label(self, texts[i], sign_pos + Vector3(0, 0, 0.04), GameManager.font_sign, 96, Color(0.6, 0.08, 0.05), false, 0.006)
	for x3: float in [-4.0, 4.0]:
		_b.sphere(self, 0.12, Vector3(x3, 4.2, 1.0), _b.glow_mat(Color(1.0, 0.85, 0.6), 6.0))


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.h_offset = -0.25
	camera.current = true
	add_child(camera)
	_update_camera()


func _update_camera() -> void:
	var target := Vector3(0, 0.3, 0.05)
	var rot := Basis(Vector3.UP, _cam_yaw) * Basis(Vector3.RIGHT, _cam_pitch)
	camera.global_position = target + rot * Vector3(0, 0, _cam_dist)
	camera.look_at(target, Vector3.UP)


func _build_side_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.95, 0.9, 0.78, 0.94)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", st)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -230
	panel.offset_right = -14
	panel.offset_top = 14
	layer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var t := Label.new()
	t.text = "遊び方"
	t.add_theme_font_override("font", GameManager.font_sign)
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(0.5, 0.1, 0.05))
	v.add_child(t)
	var rules := Label.new()
	rules.text = "緑の穴 … 5玉\n赤の穴 … 15玉\n縦・横・斜めがそろうと\nランプ点灯でボーナス\n　中心を通る列 +15\n　外側の列 +5\n全部入り … +%d" % FULL_BONUS
	rules.add_theme_font_size_override("font_size", 16)
	rules.add_theme_color_override("font_color", Color(0.2, 0.12, 0.08))
	v.add_child(rules)
	_out_label = Label.new()
	_out_label.add_theme_font_size_override("font_size", 18)
	_out_label.add_theme_color_override("font_color", Color(0.6, 0.1, 0.05))
	v.add_child(_out_label)
	# 打ち出しの強さ
	_power_back = Panel.new()
	_power_back.anchor_left = 1.0
	_power_back.anchor_right = 1.0
	_power_back.anchor_top = 1.0
	_power_back.anchor_bottom = 1.0
	_power_back.offset_left = -60
	_power_back.offset_right = -30
	_power_back.offset_top = -260
	_power_back.offset_bottom = -40
	_power_back.visible = false
	layer.add_child(_power_back)
	_power_bar = ColorRect.new()
	_power_bar.color = Color(1.0, 0.5, 0.2)
	_power_back.add_child(_power_bar)


# ================================================================ 入力

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mm: InputEventMouseMotion = event
		_cam_yaw -= mm.relative.x * 0.005
		_cam_pitch = clampf(_cam_pitch - mm.relative.y * 0.005, -1.45, -0.12)
		_update_camera()
		return
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_dist = maxf(3.0, _cam_dist - 0.4)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_dist = minf(16.0, _cam_dist + 0.4)
			_update_camera()
	if hud._exchanging or editing:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R:
		_reset_board()


func _start_charge() -> void:
	if _lane_ball() == null:
		if not hud.use_ball():
			return
		_spawn_ball(Vector2((LANE_L + LANE_R) * 0.5 + 1.0, LANE_BOTTOM - 12.0))
		Sound.play("clack_low", -10.0)
	_charging = true
	_power = 0.0


func _release_shot() -> void:
	if not _charging:
		return
	_charging = false
	var b: RigidBody3D = _lane_ball()
	if b:
		var v: float = 4.0 + 5.5 * _power
		b.linear_velocity = board.global_basis * Vector3(0, 0, -v)
		Sound.play("launch", -4.0)
		Sound.play("spring", -12.0)
	_power = 0.0
	_update_plunger()


func _lane_ball() -> RigidBody3D:
	for b: RigidBody3D in balls:
		var px: Vector2 = to_px(board.to_local(b.global_position))
		if px.x > LANE_L and px.y > LANE_BOTTOM - 60.0 and b.linear_velocity.length() < 0.6:
			return b
	return null


func _spawn_ball(px: Vector2) -> RigidBody3D:
	var b := RigidBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = BALL_R
	cs.shape = shape
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	mi.mesh = sm
	mi.material_override = _ball_mat
	b.add_child(mi)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.0
	b.physics_material_override = pm
	b.mass = 0.05
	b.gravity_scale = GRAV_SCALE
	b.continuous_cd = true
	b.can_sleep = false
	b.contact_monitor = true
	b.max_contacts_reported = 2
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.linear_damp = 0.12
	b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.angular_damp = 0.0
	b.body_entered.connect(_on_ball_hit.bind(b))
	add_child(b)
	b.global_position = board.to_global(p3(px, BALL_R + 0.01))
	balls.append(b)
	return b


func _on_ball_hit(_body: Node, b: RigidBody3D) -> void:
	var spd: float = b.linear_velocity.length()
	if spd < 0.5:
		return
	Sound.play("clack_low", clampf(-26.0 + spd * 2.5, -26.0, -8.0), randf_range(0.9, 1.1), 30)


func _remove_ball(b: RigidBody3D) -> void:
	balls.erase(b)
	if is_instance_valid(b):
		b.queue_free()


# ================================================================ 更新

func _physics_process(delta: float) -> void:
	var paused: bool = hud._exchanging or editing
	for b: RigidBody3D in balls:
		b.freeze = paused
	if paused:
		return
	if Input.is_action_just_pressed("shoot"):
		_start_charge()
	elif Input.is_action_just_released("shoot"):
		_release_shot()
	if _charging:
		_power = minf(1.0, _power + delta * 0.9)
		_update_plunger()
	for b: RigidBody3D in balls.duplicate():
		if not is_instance_valid(b):
			balls.erase(b)
			continue
		var local: Vector3 = board.to_local(b.global_position)
		var px: Vector2 = to_px(local)
		if (px.y > DRAIN_Y and px.x > 185.0 and px.x < 305.0) or local.y < -1.0 or px.y > 700.0:
			Sound.play("hole", -16.0, 0.7)
			_remove_ball(b)
			continue
		_check_holes(b, px)


func _check_holes(b: RigidBody3D, px: Vector2) -> void:
	var inv: Basis = board.global_basis.inverse()
	var local_vel: Vector3 = inv * b.linear_velocity
	var plane_speed: float = Vector2(local_vel.x, local_vel.z).length()
	for i: int in holes.size():
		var hp: Vector2 = holes[i]["pos"]
		var d: float = px.distance_to(hp)
		if d > HOLE_R_PX + 9.0:
			continue
		if d < capture_r_px * 0.35 or (d < capture_r_px and plane_speed < capture_speed):
			_capture(b, i)
			return
		# 穴のくぼみに少し引き込まれる
		var dir2: Vector2 = (hp - px).normalized()
		var strength: float = pull * (1.0 - d / (HOLE_R_PX + 9.0))
		b.apply_central_force(board.global_basis * Vector3(dir2.x, 0, dir2.y) * strength * b.mass)


func _capture(b: RigidBody3D, hole_idx: int) -> void:
	balls.erase(b)
	b.freeze = true
	b.collision_layer = 0
	b.collision_mask = 0
	var h: Dictionary = holes[hole_idx]
	var target: Vector3 = board.to_global(p3(h["pos"], -0.05))
	var tw: Tween = b.create_tween()
	tw.tween_property(b, "global_position", target, 0.18)
	tw.tween_callback(b.queue_free)
	Sound.play("hole", -4.0)
	hud.payout(int(h["value"]), camera.unproject_position(target))
	if not bool(h["filled"]):
		h["filled"] = true
		(h["marker"] as MeshInstance3D).visible = true
		_check_lines()


func _check_lines() -> void:
	for li: int in LINES.size():
		if line_lit[li]:
			continue
		var ok: bool = true
		for idx: int in LINES[li]:
			if not bool(holes[idx]["filled"]):
				ok = false
		if ok:
			line_lit[li] = true
			_lamp_flash = 1.5
			hud.payout(LINE_BONUS[li], camera.unproject_position(board.to_global(p3(Vector2(245, 189)))), true)
	var all_filled: bool = true
	for h: Dictionary in holes:
		if not bool(h["filled"]):
			all_filled = false
	if all_filled and not _reset_pending:
		_reset_pending = true
		hud.payout(FULL_BONUS, camera.unproject_position(board.to_global(p3(Vector2(245, 330)))), true)
		GameManager.toast_requested.emit("全部入り！ 大当たり +%d玉" % FULL_BONUS)
		get_tree().create_timer(2.0).timeout.connect(_reset_board)


func _reset_board() -> void:
	_reset_pending = false
	for h: Dictionary in holes:
		h["filled"] = false
		(h["marker"] as MeshInstance3D).visible = false
	for i: int in line_lit.size():
		line_lit[i] = false
	Sound.play("pour", -10.0)


func _process(delta: float) -> void:
	_anim_t += delta
	_lamp_flash = maxf(0.0, _lamp_flash - delta)
	for li: int in _lamps.size():
		var lamp: Dictionary = _lamps[li]
		var lit: bool = line_lit[li]
		if lit and _lamp_flash > 0.0 and int(_anim_t * 10.0) % 2 == 0:
			lit = false
		(lamp["mesh"] as MeshInstance3D).material_override = lamp["on"] if lit else lamp["off"]
	for h: Dictionary in holes:
		var rm: StandardMaterial3D = h["ring_mat"]
		rm.emission_energy_multiplier = (0.6 + 0.4 * sin(_anim_t * 6.0)) if bool(h["filled"]) else 0.0
	_score_label.text = "%05d" % mini(hud.total_out * 10, 99999)
	_count_label.text = str(hud.held_balls)
	_out_label.text = "本日の払い出し %d 玉" % hud.total_out
	_power_back.visible = _charging
	if _charging:
		var hgt: float = 216.0 * _power
		_power_bar.position = Vector2(2, 218.0 - hgt)
		_power_bar.size = Vector2(26, hgt)
	_update_tray()


## 受け皿に持ち玉を並べる（最大 40 個）
func _update_tray() -> void:
	var n: int = mini(hud.held_balls, 40)
	if n == _tray_shown:
		return
	_tray_shown = n
	for c: Node in _tray.get_children():
		c.queue_free()
	var mat: StandardMaterial3D = _ball_mat
	for i: int in n:
		var row: int = i / 20
		var col: int = i % 20
		var pos := Vector3(-2.05 + col * 0.215 + row * 0.1, row * 0.08, 0.18 - row * 0.2)
		var s: MeshInstance3D = _b.sphere(_tray, 0.11, pos, mat)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _on_hud_exit() -> void:
	# 盤面に残っている玉は持ち玉に戻す
	hud.held_balls += balls.size()
	for b: RigidBody3D in balls.duplicate():
		_remove_ball(b)
	GameManager.set_stored_balls("smartball", hud.held_balls)
	exit_requested.emit()

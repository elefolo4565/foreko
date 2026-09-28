extends Node3D
## 夕暮れの昭和の商店街。スマートボール店とパチンコ店に入れる。

signal shop_entered(shop_id: String)

const ROAD_HALF: float = 4.0
const FACADE_X: float = 4.6
const STREET_START_Z: float = 12.0
const SHOP_DEPTH: float = 7.0

## 左側（西）の店。z はファサード中心
const LEFT_SHOPS: Array = [
	{"name": "八百屋", "sign": "八百金", "sub": "青果", "w": 7.0, "style": "gable", "wall": Color(0.55, 0.38, 0.24), "goods": "veg", "sode": "やおや"},
	{"name": "米屋", "sign": "米穀 田中商店", "w": 6.0, "style": "kanban", "wall": Color(0.62, 0.66, 0.6), "goods": "rice", "sode": "お米"},
	{"id": "pachinko", "w": 12.0, "style": "pachinko"},
	{"name": "駄菓子屋", "sign": "だがし", "w": 6.0, "style": "gable", "wall": Color(0.5, 0.34, 0.22), "goods": "candy", "noren": "だがしや", "noren_color": Color(0.2, 0.3, 0.55), "flag": "氷"},
	{"name": "電気店", "sign": "三河屋電器", "w": 7.0, "style": "kanban", "wall": Color(0.75, 0.72, 0.62), "goods": "tv", "sode": "テレビ"},
	{"name": "本屋", "sign": "文明堂書店", "w": 6.0, "style": "gable", "wall": Color(0.45, 0.32, 0.22), "goods": "books", "sode": "本"},
]
const RIGHT_SHOPS: Array = [
	{"name": "魚屋", "sign": "魚辰", "sub": "鮮魚", "w": 7.0, "style": "gable", "wall": Color(0.5, 0.36, 0.25), "goods": "fish", "noren": "さかな", "noren_color": Color(0.15, 0.22, 0.45)},
	{"name": "豆腐屋", "sign": "とうふ 松本", "w": 6.0, "style": "gable", "wall": Color(0.58, 0.42, 0.28), "goods": "tofu", "sode": "豆腐"},
	{"id": "smartball", "w": 9.0, "style": "smartball"},
	{"name": "薬局", "sign": "ホシ薬局", "w": 6.0, "style": "kanban", "wall": Color(0.72, 0.8, 0.78), "goods": "medicine", "sode": "くすり"},
	{"name": "洋品店", "sign": "モダン洋品店", "w": 7.0, "style": "kanban", "wall": Color(0.82, 0.7, 0.62), "goods": "clothes", "sode": "洋品"},
	{"name": "食堂", "sign": "大衆食堂 まるや", "w": 7.0, "style": "gable", "wall": Color(0.5, 0.35, 0.24), "goods": "none", "noren": "めし", "noren_color": Color(0.1, 0.12, 0.2)},
]

var _b: WorldBuilder = WorldBuilder.new()
var _player: ForekoPlayer
var _doors: Array = []  # {"id", "pos": Vector3, "exit_pos": Vector3, "yaw": float, "label": String}
var _near_door: Dictionary = {}
var _blink_bulbs: Array = []
var _blink_time: float = 0.0
var _neon_labels: Array = []

var _hud_money: Label
var _hud_prizes: Label
var _prompt: Label
var _prompt_panel: PanelContainer


func _ready() -> void:
	_build_environment()
	_build_ground()
	var left_end: float = _build_row(LEFT_SHOPS, -1)
	var right_end: float = _build_row(RIGHT_SHOPS, 1)
	var street_end_z: float = minf(left_end, right_end) - 1.0
	_build_street_ends(street_end_z)
	_build_poles(street_end_z)
	_build_props()
	_build_tokyo_tower()
	_spawn_player()
	_build_hud()
	GameManager.money_changed.connect(func(_m: int) -> void: _refresh_hud())
	GameManager.prizes_changed.connect(_refresh_hud)


# ================================================================ 環境

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.25, 0.48)
	sky_mat.sky_horizon_color = Color(1.0, 0.56, 0.28)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.2, 0.14, 0.12)
	sky_mat.ground_horizon_color = Color(0.95, 0.55, 0.3)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.95, 0.6, 0.38)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.2
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# 通りの奥（-Z）に沈む夕日
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.66, 0.42)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.rotation_degrees = Vector3(-13.0, 168.0, 0.0)
	add_child(sun)


func _build_ground() -> void:
	# 土の道
	var road: MeshInstance3D = _b.box(self, Vector3(ROAD_HALF * 2.0, 0.2, 140.0), Vector3(0, -0.1, -50.0), _b.mat(Color(0.6, 0.5, 0.4), "dirt", 0.12))
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_b.collider(self, Vector3(80.0, 0.2, 180.0), Vector3(0, -0.1, -50.0))
	# どぶ板（側溝のふた）
	var gutter: StandardMaterial3D = _b.mat(Color(0.55, 0.55, 0.52), "plaster", 0.5)
	for side: int in [-1, 1]:
		_b.box(self, Vector3(0.6, 0.12, 140.0), Vector3(side * (ROAD_HALF + 0.3), 0.0, -50.0), gutter)
		for i: int in 140:
			_b.box(self, Vector3(0.62, 0.01, 0.03), Vector3(side * (ROAD_HALF + 0.3), 0.065, -120.0 + float(i)), _b.mat(Color(0.3, 0.3, 0.3)))
	# 建物の外側の地面
	_b.box(self, Vector3(60.0, 0.1, 160.0), Vector3(0, -0.2, -50.0), _b.mat(Color(0.35, 0.3, 0.26), "dirt", 0.1))


# ================================================================ 店並び

func _build_row(shops: Array, side: int) -> float:
	var z: float = STREET_START_Z - 4.0
	for spec: Dictionary in shops:
		var w: float = spec.get("w", 6.0)
		var zc: float = z - w * 0.5
		var root := Node3D.new()
		# 左側は +X を、右側は -X を向く
		root.position = Vector3(side * FACADE_X, 0.0, zc)
		root.rotation_degrees.y = 90.0 if side < 0 else -90.0
		add_child(root)
		match String(spec.get("style", "gable")):
			"pachinko":
				_build_pachinko_hall(root, w)
				_register_door(root, "pachinko", "パチンコ ミナト会館 に入る")
			"smartball":
				_build_smartball_shop(root, w)
				_register_door(root, "smartball", "スマートボール 金星 に入る")
			_:
				_build_shop(root, spec)
		z -= w + 0.4
	return z


func _register_door(root: Node3D, shop_id: String, text: String) -> void:
	var door_world: Vector3 = root.to_global(Vector3(0, 0, 0.8))
	var exit_world: Vector3 = root.to_global(Vector3(0, 0, 2.2))
	var facing: Vector3 = root.global_transform.basis.z
	_doors.append({
		"id": shop_id, "pos": door_world, "exit_pos": exit_world,
		"yaw": atan2(facing.x, facing.z), "label": text,
	})


## 一般的な商店。ローカル座標：ファサードが z=0、奥が -z
func _build_shop(root: Node3D, spec: Dictionary) -> void:
	var w: float = spec.get("w", 6.0)
	var wall_col: Color = spec.get("wall", Color(0.5, 0.35, 0.22))
	var style: String = spec.get("style", "gable")
	var d: float = SHOP_DEPTH
	var wood: StandardMaterial3D = _b.mat(wall_col, "planks", 0.9)
	var dark_wood: StandardMaterial3D = _b.mat(wall_col.darkened(0.45), "planks", 0.9)

	# 1階：店の奥壁と柱、天井
	_b.box(root, Vector3(w, 3.1, 0.2), Vector3(0, 1.55, -2.2), _b.mat(Color(0.95, 0.85, 0.65), "plaster", 0.6))
	_b.box(root, Vector3(0.25, 3.1, 2.3), Vector3(-w * 0.5 + 0.12, 1.55, -1.1), dark_wood)
	_b.box(root, Vector3(0.25, 3.1, 2.3), Vector3(w * 0.5 - 0.12, 1.55, -1.1), dark_wood)
	_b.box(root, Vector3(w, 0.15, 2.4), Vector3(0, 3.05, -1.1), dark_wood)
	_b.box(root, Vector3(w, 0.08, 2.4), Vector3(0, 0.04, -1.1), _b.mat(Color(0.5, 0.48, 0.44), "plaster", 0.5))
	# 店内の明かり（裸電球）
	var bulb: MeshInstance3D = _b.sphere(root, 0.09, Vector3(0, 2.7, -1.2), _b.glow_mat(Color(1.0, 0.8, 0.5), 5.0))
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.5, -0.9)
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.light_energy = 1.4
	lamp.omni_range = 4.5
	root.add_child(lamp)
	_build_goods(root, w, String(spec.get("goods", "none")))
	# 奥の母屋（当たり判定を含む建物本体）
	_b.box(root, Vector3(w, 6.0, d - 2.3), Vector3(0, 3.0, -2.3 - (d - 2.3) * 0.5), wood)
	_b.collider(root, Vector3(w, 7.0, d), Vector3(0, 3.5, -0.35 - d * 0.5))

	if style == "kanban":
		_build_kanban_front(root, w, wall_col, spec)
	else:
		_build_gable_front(root, w, wall_col, spec)

	if spec.has("noren"):
		_build_noren(root, w, String(spec["noren"]), spec.get("noren_color", Color(0.15, 0.2, 0.4)))
	if spec.has("sode"):
		_build_sode_sign(root, w, String(spec["sode"]), Color(0.95, 0.92, 0.85), Color(0.7, 0.1, 0.08))
	if spec.has("flag"):
		_build_ice_flag(root, Vector3(w * 0.5 - 0.6, 0, 0.9))


## 瓦屋根の木造二階建て
func _build_gable_front(root: Node3D, w: float, wall_col: Color, spec: Dictionary) -> void:
	var d: float = SHOP_DEPTH
	var wood2: StandardMaterial3D = _b.mat(wall_col.lightened(0.05), "hplanks", 0.8)
	var tile: StandardMaterial3D = _b.mat(Color(0.32, 0.34, 0.4), "tiles", 1.4, 0.6)
	# 1階の庇（瓦）
	_b.box(root, Vector3(w + 0.2, 0.1, 1.3), Vector3(0, 3.35, 0.35), tile, Vector3(-18.0, 0, 0))
	# 2階
	_b.box(root, Vector3(w, 2.8, d - 0.4), Vector3(0, 4.6, -0.4 - (d - 0.4) * 0.5 + 0.2), wood2)
	_build_window(root, Vector3(-w * 0.22, 4.6, 0.02), Vector2(w * 0.32, 1.3))
	_build_window(root, Vector3(w * 0.22, 4.6, 0.02), Vector2(w * 0.32, 1.3))
	# 手すり
	_b.box(root, Vector3(w * 0.9, 0.08, 0.1), Vector3(0, 4.05, 0.1), _b.mat(wall_col.darkened(0.5)))
	# 切妻屋根（棟は x 方向）
	var half: float = d * 0.5 + 0.4
	var ang: float = 27.0
	var rise: float = sin(deg_to_rad(ang)) * half * 0.5
	var run: float = cos(deg_to_rad(ang)) * half * 0.5
	var zc: float = -d * 0.5 + 0.2
	_b.box(root, Vector3(w + 0.6, 0.14, half), Vector3(0, 6.0 + rise, zc + run), tile, Vector3(ang, 0, 0))
	_b.box(root, Vector3(w + 0.6, 0.14, half), Vector3(0, 6.0 + rise, zc - run), tile, Vector3(-ang, 0, 0))
	_b.box(root, Vector3(w + 0.7, 0.18, 0.25), Vector3(0, 6.0 + rise * 2.0, zc), _b.mat(Color(0.22, 0.23, 0.27)))
	# 妻壁（三角部分は箱で近似）
	_b.box(root, Vector3(w - 0.1, rise * 1.6, d * 0.6), Vector3(0, 6.0 + rise * 0.6, zc), wood2)
	# 看板（庇の上の横長板）
	_build_sign_board(root, Vector3(0, 3.8, 0.55), Vector2(w * 0.78, 0.6), String(spec.get("sign", "")),
		Color(0.2, 0.12, 0.06), Color(0.97, 0.92, 0.78))


## 看板建築（平らな正面壁の上部に屋号）
func _build_kanban_front(root: Node3D, w: float, wall_col: Color, spec: Dictionary) -> void:
	var d: float = SHOP_DEPTH
	var front: StandardMaterial3D = _b.mat(wall_col, "plaster", 0.7)
	# 2階本体
	_b.box(root, Vector3(w, 3.2, d - 0.2), Vector3(0, 4.7, -d * 0.5), _b.mat(wall_col.darkened(0.2), "plaster", 0.7))
	# 正面の看板壁
	_b.box(root, Vector3(w, 4.0, 0.25), Vector3(0, 5.1, 0.0), front)
	# 上部の飾り縁（銅板風）
	_b.box(root, Vector3(w + 0.1, 0.25, 0.4), Vector3(0, 7.15, 0.0), _b.mat(Color(0.3, 0.5, 0.42), "", 1.0, 0.5))
	_b.box(root, Vector3(w + 0.1, 0.15, 0.35), Vector3(0, 3.2, 0.1), _b.mat(Color(0.3, 0.5, 0.42), "", 1.0, 0.5))
	# 2階の窓
	_build_window(root, Vector3(-w * 0.25, 4.3, 0.14), Vector2(w * 0.28, 1.1))
	_build_window(root, Vector3(w * 0.25, 4.3, 0.14), Vector2(w * 0.28, 1.1))
	# 屋号（壁に直接）
	var l: Label3D = _b.label(root, String(spec.get("sign", "")), Vector3(0, 6.2, 0.14), GameManager.font_mincho, 96,
		Color(0.25, 0.12, 0.08), false, 0.0065)
	_fit_label(l, w * 0.85)
	# 布の日よけ
	_b.box(root, Vector3(w * 0.95, 0.06, 1.2), Vector3(0, 2.95, 0.5), _b.mat(Color(0.75, 0.2, 0.15), "stripes", 0.5), Vector3(-20.0, 0, 0))


func _fit_label(l: Label3D, max_width: float) -> void:
	var font: Font = l.font
	var sz: Vector2 = font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, -1, l.font_size)
	var width: float = sz.x * l.pixel_size
	if width > max_width and width > 0.0:
		l.pixel_size *= max_width / width


func _build_window(root: Node3D, pos: Vector3, size: Vector2) -> void:
	var glow: StandardMaterial3D = _b.glow_mat(Color(1.0, 0.78, 0.5), 0.9)
	var frame: StandardMaterial3D = _b.mat(Color(0.25, 0.16, 0.1))
	_b.box(root, Vector3(size.x, size.y, 0.05), pos, glow)
	# 格子
	var cols: int = 4
	for i: int in cols + 1:
		var x: float = pos.x - size.x * 0.5 + size.x * float(i) / float(cols)
		_b.box(root, Vector3(0.05, size.y + 0.05, 0.08), Vector3(x, pos.y, pos.z + 0.02), frame)
	for j: int in 3:
		var y: float = pos.y - size.y * 0.5 + size.y * float(j) / 2.0
		_b.box(root, Vector3(size.x, 0.05, 0.08), Vector3(pos.x, y, pos.z + 0.02), frame)


func _build_sign_board(root: Node3D, pos: Vector3, size: Vector2, text: String, bg: Color, fg: Color) -> void:
	_b.box(root, Vector3(size.x, size.y, 0.08), pos, _b.mat(bg, "planks", 0.8))
	_b.box(root, Vector3(size.x + 0.1, size.y + 0.1, 0.05), pos + Vector3(0, 0, -0.03), _b.mat(bg.darkened(0.5)))
	var l: Label3D = _b.label(root, text, pos + Vector3(0, 0, 0.05), GameManager.font_sign, 96, fg, false, 0.0045)
	_fit_label(l, size.x * 0.92)


## 袖看板（壁から突き出た縦看板）
func _build_sode_sign(root: Node3D, w: float, text: String, bg: Color, fg: Color) -> void:
	var h: float = 0.45 * text.length() + 0.5
	var pos := Vector3(w * 0.5 - 0.35, 5.0, 0.55)
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = 90.0
	root.add_child(holder)
	_b.box(holder, Vector3(0.7, h, 0.1), Vector3.ZERO, _b.mat(bg, "plaster", 0.5))
	_b.box(holder, Vector3(0.78, h + 0.08, 0.06), Vector3.ZERO, _b.mat(fg.darkened(0.2)))
	for s: int in [-1, 1]:
		var l: Label3D = _b.label(holder, text, Vector3(0, 0, 0.06 * s), GameManager.font_pop, 80, fg, true, 0.005)
		if s < 0:
			l.rotation_degrees.y = 180.0
	_b.rod(root, pos + Vector3(-0.35, h * 0.4, -0.4), pos + Vector3(0, h * 0.4, 0), 0.02, _b.metal_mat(Color(0.3, 0.3, 0.3)))


func _build_noren(root: Node3D, w: float, text: String, color: Color) -> void:
	var n: int = text.length()
	var panel_w: float = 0.55
	var total: float = panel_w * n
	var cloth: StandardMaterial3D = _b.mat(color, "", 1.0, 1.0)
	_b.rod(root, Vector3(-total * 0.5 - 0.1, 2.75, 0.3), Vector3(total * 0.5 + 0.1, 2.75, 0.3), 0.025, _b.mat(Color(0.3, 0.2, 0.1)))
	for i: int in n:
		var x: float = -total * 0.5 + panel_w * (float(i) + 0.5)
		_b.box(root, Vector3(panel_w - 0.04, 0.9, 0.02), Vector3(x, 2.3, 0.3), cloth)
		_b.label(root, text[i], Vector3(x, 2.35, 0.32), GameManager.font_sign, 72, Color(0.97, 0.95, 0.9), false, 0.005)


## 「氷」ののぼり
func _build_ice_flag(root: Node3D, pos: Vector3) -> void:
	_b.cyl(root, 0.025, 2.0, pos + Vector3(0, 1.0, 0), _b.mat(Color(0.6, 0.55, 0.45)))
	_b.box(root, Vector3(0.7, 0.7, 0.01), pos + Vector3(0.36, 1.55, 0), _b.mat(Color(0.97, 0.97, 0.97), "", 1.0, 1.0))
	_b.box(root, Vector3(0.7, 0.14, 0.012), pos + Vector3(0.36, 1.2, 0), _b.mat(Color(0.2, 0.35, 0.8), "", 1.0, 1.0))
	for s: int in [-1, 1]:
		var l: Label3D = _b.label(root, "氷", pos + Vector3(0.36, 1.58, 0.012 * s), GameManager.font_sign, 96, Color(0.85, 0.08, 0.08), false, 0.0045)
		if s < 0:
			l.rotation_degrees.y = 180.0


## 店先の商品
func _build_goods(root: Node3D, w: float, kind: String) -> void:
	if kind == "none":
		return
	var table: StandardMaterial3D = _b.mat(Color(0.45, 0.32, 0.2), "planks", 1.2)
	_b.box(root, Vector3(w * 0.75, 0.7, 0.9), Vector3(0, 0.35, -0.8), table)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	match kind:
		"veg", "fish", "candy":
			var palette: Array = []
			if kind == "veg":
				palette = [Color(0.3, 0.6, 0.2), Color(0.9, 0.45, 0.1), Color(0.8, 0.15, 0.1), Color(0.95, 0.9, 0.7), Color(0.45, 0.2, 0.4)]
			elif kind == "fish":
				palette = [Color(0.6, 0.65, 0.7), Color(0.8, 0.3, 0.25), Color(0.5, 0.55, 0.6)]
			else:
				palette = [Color(1.0, 0.4, 0.6), Color(1.0, 0.85, 0.2), Color(0.3, 0.7, 1.0), Color(0.5, 0.9, 0.4)]
			var n_crate: int = int(w * 0.75 / 0.6)
			for i: int in n_crate:
				var cx: float = -w * 0.375 + 0.3 + 0.6 * float(i)
				_b.box(root, Vector3(0.55, 0.14, 0.7), Vector3(cx, 0.77, -0.8), _b.mat(Color(0.7, 0.55, 0.35), "planks", 2.0))
				var col: Color = palette[i % palette.size()]
				for k: int in 5:
					var p := Vector3(cx + rng.randf_range(-0.18, 0.18), 0.9, -0.8 + rng.randf_range(-0.25, 0.25))
					if kind == "fish":
						_b.box(root, Vector3(0.1, 0.06, 0.35), p, _b.metal_mat(col))
					else:
						_b.sphere(root, 0.08, p, _b.mat(col, "", 1.0, 0.5))
		"rice":
			for i: int in 4:
				_b.cyl(root, 0.3, 0.6, Vector3(-w * 0.3 + float(i) * 0.6, 1.0, -0.8), _b.mat(Color(0.85, 0.8, 0.62), "hplanks", 3.0))
		"tv":
			for i: int in 3:
				var x: float = -1.4 + float(i) * 1.4
				_b.box(root, Vector3(0.8, 0.65, 0.55), Vector3(x, 1.03, -0.8), _b.mat(Color(0.35, 0.22, 0.12), "planks", 2.0))
				_b.box(root, Vector3(0.52, 0.42, 0.02), Vector3(x - 0.08, 1.05, -0.52), _b.glow_mat(Color(0.6, 0.75, 0.8), 1.2))
				_b.cyl(root, 0.05, 0.4, Vector3(x, 1.25, -0.8), _b.metal_mat(Color(0.8, 0.8, 0.8)), Vector3(0, 0, 25))
		"books":
			for i: int in 14:
				var x: float = -w * 0.35 + float(i) * 0.3
				_b.box(root, Vector3(0.22, 0.04 + rng.randf() * 0.05, 0.3), Vector3(x, 0.73, -0.8), _b.mat(Color.from_hsv(rng.randf(), 0.5, 0.8)))
		"tofu":
			_b.box(root, Vector3(1.2, 0.35, 0.7), Vector3(0, 0.88, -0.8), _b.mat(Color(0.3, 0.5, 0.7), "", 1.0, 0.1))
			for i: int in 4:
				_b.box(root, Vector3(0.18, 0.12, 0.18), Vector3(-0.35 + float(i) * 0.23, 1.0, -0.8), _b.mat(Color(0.98, 0.97, 0.9), "", 1.0, 0.4))
		"medicine":
			for i: int in 10:
				var x: float = -w * 0.3 + float(i) * 0.36
				_b.box(root, Vector3(0.25, 0.3, 0.2), Vector3(x, 0.85, -0.8), _b.mat(Color.from_hsv(rng.randf(), 0.4, 0.9)))
		"clothes":
			for i: int in 5:
				var x: float = -w * 0.3 + float(i) * 0.6
				_b.box(root, Vector3(0.45, 0.6, 0.06), Vector3(x, 1.8, -1.9), _b.mat(Color.from_hsv(rng.randf(), 0.45, 0.8), "", 1.0, 1.0))


# ================================================================ パチンコ店

func _build_pachinko_hall(root: Node3D, w: float) -> void:
	var d: float = SHOP_DEPTH + 1.0
	var facade: StandardMaterial3D = _b.mat(Color(0.93, 0.9, 0.82), "plaster", 0.6)
	# 建物本体と当たり判定
	_b.box(root, Vector3(w, 7.5, d - 1.2), Vector3(0, 3.75, -1.2 - (d - 1.2) * 0.5), _b.mat(Color(0.7, 0.66, 0.6), "plaster", 0.6))
	_b.collider(root, Vector3(w, 8.0, d), Vector3(0, 4.0, -0.4 - d * 0.5))
	# 正面の大看板壁
	_b.box(root, Vector3(w, 5.2, 0.3), Vector3(0, 5.4, -0.2), facade)
	_b.box(root, Vector3(w + 0.2, 0.3, 0.5), Vector3(0, 8.1, -0.1), _b.mat(Color(0.75, 0.1, 0.1)))
	# 入口のガラス戸（中が明るい）
	_b.box(root, Vector3(w * 0.7, 2.6, 0.06), Vector3(0, 1.4, -1.0), _b.glow_mat(Color(1.0, 0.85, 0.55), 1.5))
	for i: int in 7:
		var x: float = -w * 0.35 + w * 0.7 * float(i) / 6.0
		_b.box(root, Vector3(0.08, 2.7, 0.12), Vector3(x, 1.4, -0.95), _b.metal_mat(Color(0.75, 0.75, 0.72)))
	_b.box(root, Vector3(w * 0.72, 0.1, 0.14), Vector3(0, 2.75, -0.95), _b.metal_mat(Color(0.75, 0.75, 0.72)))
	# 入口両脇の柱（赤）
	_b.box(root, Vector3(w * 0.15, 2.8, 1.0), Vector3(-w * 0.425, 1.4, -0.7), _b.mat(Color(0.7, 0.1, 0.08)))
	_b.box(root, Vector3(w * 0.15, 2.8, 1.0), Vector3(w * 0.425, 1.4, -0.7), _b.mat(Color(0.7, 0.1, 0.08)))
	var inside := OmniLight3D.new()
	inside.position = Vector3(0, 2.2, 0.8)
	inside.light_color = Color(1.0, 0.8, 0.55)
	inside.light_energy = 2.0
	inside.omni_range = 6.0
	root.add_child(inside)

	# 大看板：「パチンコ」＋屋号。周囲に点滅電球
	var board_pos := Vector3(0, 5.6, 0.0)
	_b.box(root, Vector3(w * 0.9, 2.4, 0.1), board_pos, _b.mat(Color(0.1, 0.25, 0.55)))
	var title: Label3D = _b.label(root, "パチンコ", board_pos + Vector3(0, 0.45, 0.07), GameManager.font_pop, 160,
		Color(4.0, 3.2, 0.8), false, 0.008, Color(0.7, 0.05, 0.05), 24)
	_fit_label(title, w * 0.82)
	_neon_labels.append(title)
	var sub: Label3D = _b.label(root, "ミナト会館", board_pos + Vector3(0, -0.6, 0.07), GameManager.font_sign, 120,
		Color(1.0, 1.0, 1.0), false, 0.006, Color(0.1, 0.1, 0.3), 12)
	_fit_label(sub, w * 0.6)
	_add_bulb_frame(root, board_pos + Vector3(0, 0, 0.08), Vector2(w * 0.9, 2.4), 0.3)
	# 軒の「新装開店」の幕
	_b.box(root, Vector3(w * 0.7, 0.5, 0.04), Vector3(0, 3.35, 0.2), _b.mat(Color(0.95, 0.95, 0.9), "", 1.0, 1.0))
	var banner: Label3D = _b.label(root, "新装開店 玉がよく出る！", Vector3(0, 3.35, 0.23), GameManager.font_pop, 80, Color(0.8, 0.05, 0.05), false, 0.004)
	_fit_label(banner, w * 0.66)
	# 花輪
	_build_hanawa(root, Vector3(-w * 0.5 - 0.1, 0, 1.2), "祝")
	_build_hanawa(root, Vector3(w * 0.5 + 0.1, 0, 1.2), "祝")
	# 袖の縦看板
	_build_sode_sign(root, w, "パチンコ", Color(0.95, 0.85, 0.2), Color(0.75, 0.05, 0.05))
	# 軒先のちょうちん
	for i: int in 5:
		var x: float = -w * 0.4 + w * 0.8 * float(i) / 4.0
		var lan: MeshInstance3D = _b.sphere(root, 0.22, Vector3(x, 3.0, 0.6), _b.glow_mat(Color(1.0, 0.35, 0.2), 1.6))
		lan.scale = Vector3(1, 1.3, 1)


func _add_bulb_frame(root: Node3D, center: Vector3, size: Vector2, spacing: float) -> void:
	var nx: int = int(size.x / spacing)
	var ny: int = int(size.y / spacing)
	var pts: Array = []
	for i: int in nx + 1:
		var x: float = -size.x * 0.5 + size.x * float(i) / float(nx)
		pts.append(Vector3(x, size.y * 0.5, 0))
		pts.append(Vector3(x, -size.y * 0.5, 0))
	for j: int in range(1, ny):
		var y: float = -size.y * 0.5 + size.y * float(j) / float(ny)
		pts.append(Vector3(-size.x * 0.5, y, 0))
		pts.append(Vector3(size.x * 0.5, y, 0))
	var on_mat: StandardMaterial3D = _b.glow_mat(Color(1.0, 0.85, 0.4), 6.0)
	var off_mat: StandardMaterial3D = _b.mat(Color(0.5, 0.42, 0.3))
	for k: int in pts.size():
		var bulb: MeshInstance3D = _b.sphere(root, 0.055, center + (pts[k] as Vector3), on_mat)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_blink_bulbs.append({"mesh": bulb, "on": on_mat, "off": off_mat, "group": k % 3})


func _build_hanawa(root: Node3D, pos: Vector3, text: String) -> void:
	var leg: StandardMaterial3D = _b.mat(Color(0.55, 0.45, 0.3))
	_b.rod(root, pos + Vector3(-0.4, 0, 0), pos + Vector3(0, 2.2, 0), 0.03, leg)
	_b.rod(root, pos + Vector3(0.4, 0, 0), pos + Vector3(0, 2.2, 0), 0.03, leg)
	var ring_colors: Array = [Color(0.95, 0.3, 0.45), Color(1.0, 0.85, 0.2), Color(0.3, 0.6, 0.95), Color(0.95, 0.95, 0.95)]
	for r: int in 4:
		var rad: float = 0.75 - float(r) * 0.17
		var disc: MeshInstance3D = _b.cyl(root, rad, 0.05, pos + Vector3(0, 2.4, 0.03 * float(r)), _b.mat(ring_colors[r], "", 1.0, 0.9), Vector3(90, 0, 0), -1.0, 20)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_b.label(root, text, pos + Vector3(0, 2.4, 0.15), GameManager.font_sign, 110, Color(0.8, 0.05, 0.05), false, 0.004)
	_b.box(root, Vector3(0.3, 1.1, 0.02), pos + Vector3(0, 1.2, 0.02), _b.mat(Color(0.97, 0.97, 0.95)))
	_b.label(root, "新装開店", pos + Vector3(0, 1.2, 0.04), GameManager.font_sign, 60, Color(0.1, 0.1, 0.1), true, 0.0035)


# ================================================================ スマートボール店

func _build_smartball_shop(root: Node3D, w: float) -> void:
	var d: float = SHOP_DEPTH
	var wall: StandardMaterial3D = _b.mat(Color(0.95, 0.88, 0.55), "plaster", 0.6)
	_b.box(root, Vector3(w, 6.5, d - 1.5), Vector3(0, 3.25, -1.5 - (d - 1.5) * 0.5), _b.mat(Color(0.6, 0.5, 0.4), "hplanks", 0.8))
	_b.collider(root, Vector3(w, 7.0, d), Vector3(0, 3.5, -0.35 - d * 0.5))
	# 正面：黄色いモルタル壁と青い縁
	_b.box(root, Vector3(w, 3.6, 0.25), Vector3(0, 5.0, -0.1), wall)
	_b.box(root, Vector3(w + 0.1, 0.25, 0.4), Vector3(0, 6.85, -0.05), _b.mat(Color(0.15, 0.4, 0.75)))
	_b.box(root, Vector3(w + 0.1, 0.2, 0.4), Vector3(0, 3.2, 0.0), _b.mat(Color(0.15, 0.4, 0.75)))
	# 看板：丸いガラス玉ランプの中に一文字ずつ
	var text: String = "スマートボール"
	var n: int = text.length()
	var span: float = w * 0.86
	var ball_mat: StandardMaterial3D = _b.mat(Color(0.25, 0.5, 1.0), "", 1.0, 0.15)
	ball_mat.metallic = 0.3
	for i: int in n:
		var x: float = -span * 0.5 + span * (float(i) + 0.5) / float(n)
		var disc: MeshInstance3D = _b.cyl(root, 0.48, 0.1, Vector3(x, 5.45, 0.08), ball_mat, Vector3(90, 0, 0), -1.0, 24)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_b.sphere(root, 0.12, Vector3(x - 0.18, 5.63, 0.14), _b.glow_mat(Color(0.8, 0.9, 1.0), 1.2))
		var ch: String = "｜" if text[i] == "ー" else text[i]
		var l: Label3D = _b.label(root, ch, Vector3(x, 5.43, 0.15), GameManager.font_pop, 110, Color(1.0, 1.0, 1.0), false, 0.0055, Color(0.05, 0.1, 0.35), 14)
		if text[i] == "ー":
			l.text = "ー"
	var sub: Label3D = _b.label(root, "金 星", Vector3(0, 4.35, 0.03), GameManager.font_sign, 110, Color(0.75, 0.1, 0.05), false, 0.006)
	_fit_label(sub, w * 0.5)
	_add_bulb_frame(root, Vector3(0, 4.95, 0.05), Vector2(w * 0.94, 3.2), 0.35)
	# 赤白ストライプの日よけ
	_b.box(root, Vector3(w * 0.95, 0.06, 1.5), Vector3(0, 2.95, 0.6), _b.mat(Color(0.85, 0.15, 0.12), "stripes", 0.5), Vector3(-22.0, 0, 0))
	# 店内（明るい）とガラス戸
	_b.box(root, Vector3(w, 3.0, 0.2), Vector3(0, 1.5, -1.6), _b.glow_mat(Color(1.0, 0.9, 0.65), 0.9))
	_b.box(root, Vector3(0.3, 3.0, 1.6), Vector3(-w * 0.5 + 0.15, 1.5, -0.8), _b.mat(Color(0.15, 0.4, 0.75)))
	_b.box(root, Vector3(0.3, 3.0, 1.6), Vector3(w * 0.5 - 0.15, 1.5, -0.8), _b.mat(Color(0.15, 0.4, 0.75)))
	# 店内に並ぶ台のシルエット
	for i: int in 4:
		var x: float = -w * 0.35 + w * 0.7 * float(i) / 3.0
		_b.box(root, Vector3(0.9, 1.2, 0.5), Vector3(x, 0.9, -1.25), _b.mat(Color(0.95, 0.8, 0.2)))
		_b.box(root, Vector3(0.7, 0.9, 0.02), Vector3(x, 1.0, -0.99), _b.glow_mat(Color(0.5, 0.8, 0.9), 1.0))
	var inside := OmniLight3D.new()
	inside.position = Vector3(0, 2.2, 0.5)
	inside.light_color = Color(1.0, 0.85, 0.6)
	inside.light_energy = 1.6
	inside.omni_range = 5.5
	root.add_child(inside)
	_build_noren(root, w, "スマートボール", Color(0.12, 0.3, 0.6))
	_build_ice_flag(root, Vector3(-w * 0.5 + 0.4, 0, 1.2))


# ================================================================ 通りの両端・電柱・小物

func _build_street_ends(end_z: float) -> void:
	# 奥：銭湯（煙突つき）
	var sento := Node3D.new()
	sento.position = Vector3(0, 0, end_z - 4.5)
	add_child(sento)
	var w: float = 16.0
	_b.box(sento, Vector3(w, 5.0, 8.0), Vector3(0, 2.5, -4.0), _b.mat(Color(0.55, 0.4, 0.28), "hplanks", 0.8))
	_b.collider(sento, Vector3(w + 6.0, 8.0, 8.0), Vector3(0, 4.0, -4.0))
	var tile: StandardMaterial3D = _b.mat(Color(0.3, 0.32, 0.38), "tiles", 1.4, 0.6)
	# 唐破風っぽい屋根
	_b.box(sento, Vector3(w + 0.8, 0.2, 5.0), Vector3(0, 6.2, -1.8), tile, Vector3(25, 0, 0))
	_b.box(sento, Vector3(w + 0.8, 0.2, 5.0), Vector3(0, 6.2, -6.2), tile, Vector3(-25, 0, 0))
	_b.box(sento, Vector3(w, 2.0, 4.0), Vector3(0, 5.6, -4.0), _b.mat(Color(0.5, 0.36, 0.25), "hplanks", 0.8))
	_b.box(sento, Vector3(5.0, 0.15, 1.8), Vector3(0, 3.6, 0.6), tile, Vector3(-15, 0, 0))
	_b.box(sento, Vector3(3.0, 2.8, 0.1), Vector3(0, 1.4, 0.05), _b.glow_mat(Color(1.0, 0.85, 0.6), 0.8))
	_build_noren(sento, 3.0, "ゆ", Color(0.15, 0.25, 0.6))
	var yu: Label3D = _b.label(sento, "松の湯", Vector3(0, 4.4, 0.1), GameManager.font_sign, 120, Color(0.95, 0.92, 0.8), false, 0.006)
	_b.box(sento, Vector3(3.2, 0.9, 0.08), Vector3(0, 4.4, 0.03), _b.mat(Color(0.25, 0.15, 0.08), "planks", 1.0))
	yu.position.z = 0.1
	# 煙突
	var chimney_mat: StandardMaterial3D = _b.mat(Color(0.55, 0.3, 0.22), "hplanks", 0.5)
	_b.cyl(sento, 0.9, 22.0, Vector3(5.5, 11.0, -6.5), chimney_mat, Vector3.ZERO, 0.6, 16)
	_b.label(sento, "松の湯", Vector3(5.5, 16.0, -5.8), GameManager.font_sign, 90, Color(0.95, 0.95, 0.9), true, 0.012)
	# 奥の家並み
	for side: int in [-1, 1]:
		_b.box(self, Vector3(12.0, 6.0, 8.0), Vector3(side * 14.0, 3.0, end_z - 8.0), _b.mat(Color(0.45, 0.35, 0.27), "hplanks", 0.8))

	# 手前：空き地と土管、板塀
	var lot := Node3D.new()
	lot.position = Vector3(0, 0, STREET_START_Z + 4.0)
	add_child(lot)
	_b.box(lot, Vector3(26.0, 0.05, 12.0), Vector3(0, 0.0, 4.0), _b.mat(Color(0.45, 0.42, 0.25), "dirt", 0.2))
	var pipe: StandardMaterial3D = _b.mat(Color(0.62, 0.62, 0.6), "plaster", 0.5)
	for p: Array in [[-2.0, 0.6, 3.0], [0.0, 0.6, 3.0], [-1.0, 1.75, 3.0]]:
		_b.cyl(lot, 0.6, 2.2, Vector3(p[0], p[1], p[2]), pipe, Vector3(90, 0, 0), -1.0, 16)
	_b.collider(lot, Vector3(3.4, 2.4, 2.4), Vector3(-1.0, 1.2, 3.0))
	var fence: StandardMaterial3D = _b.mat(Color(0.45, 0.33, 0.22), "planks", 1.2)
	_b.box(lot, Vector3(26.0, 1.9, 0.1), Vector3(0, 0.95, 10.0), fence)
	_b.collider(lot, Vector3(26.0, 3.0, 0.4), Vector3(0, 1.5, 10.0))
	for side: int in [-1, 1]:
		_b.box(lot, Vector3(0.1, 1.9, 12.0), Vector3(side * 8.0, 0.95, 4.0), fence)
		_b.collider(lot, Vector3(0.4, 3.0, 12.0), Vector3(side * 8.0, 1.5, 4.0))
	# 空き地の木
	_b.cyl(lot, 0.18, 3.0, Vector3(5.0, 1.5, 7.0), _b.mat(Color(0.35, 0.25, 0.18)))
	_b.sphere(lot, 1.6, Vector3(5.0, 3.8, 7.0), _b.mat(Color(0.25, 0.4, 0.18), "dirt", 0.5))
	# 通りの入口のアーチ「三丁目商店街」
	var arch := Node3D.new()
	arch.position = Vector3(0, 0, STREET_START_Z - 3.0)
	add_child(arch)
	var arch_mat: StandardMaterial3D = _b.metal_mat(Color(0.75, 0.2, 0.15))
	for side: int in [-1, 1]:
		_b.cyl(arch, 0.15, 5.5, Vector3(side * (ROAD_HALF + 0.2), 2.75, 0), arch_mat)
	_b.box(arch, Vector3(ROAD_HALF * 2.0 + 1.0, 1.0, 0.2), Vector3(0, 5.2, 0), _b.mat(Color(0.95, 0.93, 0.85)))
	for s: int in [-1, 1]:
		var al: Label3D = _b.label(arch, "夕日ヶ丘 三丁目商店街", Vector3(0, 5.2, 0.11 * s), GameManager.font_sign, 110, Color(0.7, 0.08, 0.05), false, 0.006)
		_fit_label(al, ROAD_HALF * 2.0)
		if s < 0:
			al.rotation_degrees.y = 180.0
	_add_bulb_frame(arch, Vector3(0, 5.2, 0.12), Vector2(ROAD_HALF * 2.0 + 1.0, 1.0), 0.45)


func _build_poles(end_z: float) -> void:
	var wood: StandardMaterial3D = _b.mat(Color(0.3, 0.24, 0.2), "planks", 2.0)
	var wire: StandardMaterial3D = _b.mat(Color(0.08, 0.08, 0.08))
	var insul: StandardMaterial3D = _b.mat(Color(0.9, 0.9, 0.88), "", 1.0, 0.3)
	var poles: Dictionary = {-1: [], 1: []}
	var z: float = STREET_START_Z - 6.0
	var idx: int = 0
	while z > end_z + 2.0:
		for side: int in [-1, 1]:
			var x: float = side * (ROAD_HALF + 0.25)
			var pz: float = z + (0.0 if side < 0 else -6.0)
			if pz < end_z + 2.0:
				continue
			_b.cyl(self, 0.13, 8.5, Vector3(x, 4.25, pz), wood, Vector3.ZERO, 0.1)
			_b.collider(self, Vector3(0.3, 4.0, 0.3), Vector3(x, 2.0, pz))
			_b.box(self, Vector3(1.4, 0.12, 0.12), Vector3(x, 7.6, pz), wood, Vector3(0, 90, 0))
			for k: int in 3:
				_b.cyl(self, 0.05, 0.14, Vector3(x, 7.72, pz - 0.55 + 0.55 * float(k)), insul)
			(poles[side] as Array).append(Vector3(x, 7.78, pz))
			# 鈴蘭灯
			if idx % 2 == 0:
				var arm_end := Vector3(x - side * 1.0, 5.2, pz)
				_b.rod(self, Vector3(x, 5.5, pz), arm_end, 0.03, _b.metal_mat(Color(0.2, 0.3, 0.25)))
				var shade: MeshInstance3D = _b.cyl(self, 0.28, 0.18, arm_end + Vector3(0, -0.1, 0), _b.metal_mat(Color(0.25, 0.4, 0.3)), Vector3.ZERO, 0.05, 12)
				shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var bulb: MeshInstance3D = _b.sphere(self, 0.13, arm_end + Vector3(0, -0.28, 0), _b.glow_mat(Color(1.0, 0.85, 0.55), 5.0))
				bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var l := OmniLight3D.new()
				l.position = arm_end + Vector3(0, -0.5, 0)
				l.light_color = Color(1.0, 0.78, 0.5)
				l.light_energy = 1.2
				l.omni_range = 7.0
				add_child(l)
				# 電柱の広告
				var ads: Array = ["質", "ミナト会館", "金星", "松の湯"]
				var ad_text: String = ads[(idx / 2) % ads.size()]
				var ad := Node3D.new()
				ad.position = Vector3(x - side * 0.14, 2.4, pz)
				ad.rotation_degrees.y = 90.0 * -side
				add_child(ad)
				_b.box(ad, Vector3(0.3, 1.2, 0.02), Vector3.ZERO, _b.mat(Color(0.95, 0.9, 0.2) if idx % 4 == 0 else Color(0.95, 0.95, 0.92)))
				_b.label(ad, ad_text, Vector3(0, 0, 0.015), GameManager.font_mincho, 60, Color(0.1, 0.1, 0.1), true, 0.003)
		z -= 12.0
		idx += 1
	# 電線（たるみ付き）
	for side: int in [-1, 1]:
		var arr: Array = poles[side]
		for i: int in arr.size() - 1:
			for k: int in 3:
				var off := Vector3(0, 0, -0.55 + 0.55 * float(k))
				_draw_wire((arr[i] as Vector3) + off, (arr[i + 1] as Vector3) + off, 0.5, wire)
	# 通りを横切る電線
	var la: Array = poles[-1]
	var ra: Array = poles[1]
	for i: int in mini(la.size(), ra.size()):
		if i % 2 == 0:
			_draw_wire(la[i], ra[i], 0.4, wire)


func _draw_wire(a: Vector3, b: Vector3, sag: float, material: Material) -> void:
	var seg: int = 6
	var prev: Vector3 = a
	for i: int in range(1, seg + 1):
		var t: float = float(i) / float(seg)
		var p: Vector3 = a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		_b.rod(self, prev, p, 0.012, material)
		prev = p


func _build_props() -> void:
	# 丸ポスト
	var post := Node3D.new()
	post.position = Vector3(-ROAD_HALF + 0.2, 0, -8.0)
	add_child(post)
	var red: StandardMaterial3D = _b.mat(Color(0.8, 0.08, 0.06), "", 1.0, 0.4)
	_b.cyl(post, 0.24, 1.2, Vector3(0, 0.6, 0), red, Vector3.ZERO, -1.0, 20)
	_b.sphere(post, 0.26, Vector3(0, 1.22, 0), red).scale = Vector3(1, 0.45, 1)
	_b.box(post, Vector3(0.25, 0.04, 0.1), Vector3(0.22, 0.95, 0), _b.mat(Color(0.1, 0.1, 0.1)), Vector3(0, 90, 0))
	_b.collider(post, Vector3(0.5, 1.4, 0.5), Vector3(0, 0.7, 0))
	# 木のゴミ箱、植木鉢、自転車の代わりのリヤカー風荷車
	var bin_mat: StandardMaterial3D = _b.mat(Color(0.4, 0.3, 0.2), "planks", 2.0)
	for p: Vector3 in [Vector3(ROAD_HALF + 0.1, 0.4, -3.0), Vector3(-ROAD_HALF - 0.1, 0.4, -40.0), Vector3(ROAD_HALF + 0.1, 0.4, -55.0)]:
		_b.box(self, Vector3(0.6, 0.8, 0.5), p, bin_mat)
		_b.collider(self, Vector3(0.6, 0.8, 0.5), p)
	var pot: StandardMaterial3D = _b.mat(Color(0.55, 0.3, 0.2))
	var leaf: StandardMaterial3D = _b.mat(Color(0.25, 0.45, 0.2), "dirt", 1.0)
	for i: int in 8:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(side * (ROAD_HALF + 0.05), 0.15, -6.0 - float(i) * 7.3)
		_b.cyl(self, 0.18, 0.3, p, pot, Vector3.ZERO, 0.22)
		_b.sphere(self, 0.28, p + Vector3(0, 0.35, 0), leaf)
	# 木箱の山
	var crate: StandardMaterial3D = _b.mat(Color(0.7, 0.55, 0.35), "planks", 2.0)
	for p: Vector3 in [Vector3(ROAD_HALF - 0.2, 0.25, -12.5), Vector3(ROAD_HALF - 0.2, 0.75, -12.4), Vector3(ROAD_HALF - 0.2, 0.25, -13.1)]:
		_b.box(self, Vector3(0.5, 0.5, 0.55), p, crate, Vector3(0, 8, 0))
	_b.collider(self, Vector3(0.6, 1.0, 1.4), Vector3(ROAD_HALF - 0.2, 0.5, -12.8))
	# 通りの両端の見えない壁
	for side: int in [-1, 1]:
		_b.collider(self, Vector3(0.4, 4.0, 160.0), Vector3(side * (FACADE_X + 0.2), 2.0, -50.0))


## 遠くに見える建設中の東京タワー
func _build_tokyo_tower() -> void:
	var tower := Node3D.new()
	tower.position = Vector3(55.0, 0, -260.0)
	add_child(tower)
	var red: StandardMaterial3D = _b.mat(Color(0.85, 0.3, 0.15), "", 1.0, 0.7)
	var white: StandardMaterial3D = _b.mat(Color(0.9, 0.88, 0.85), "", 1.0, 0.7)
	var h: float = 110.0
	var base_half: float = 22.0
	var top_half: float = 3.0
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var a := Vector3(sx * base_half, 0, sz * base_half)
			var b := Vector3(sx * top_half, h, sz * top_half)
			var m: MeshInstance3D = _b.rod(tower, a, b, 1.2, red)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bands: int = 9
	for i: int in bands:
		var t: float = float(i + 1) / float(bands + 1)
		var y: float = h * t
		var hw: float = lerpf(base_half, top_half, t)
		var mat_b: StandardMaterial3D = red if i % 2 == 0 else white
		for pair: Array in [[Vector3(-hw, y, -hw), Vector3(hw, y, -hw)], [Vector3(-hw, y, hw), Vector3(hw, y, hw)],
				[Vector3(-hw, y, -hw), Vector3(-hw, y, hw)], [Vector3(hw, y, -hw), Vector3(hw, y, hw)]]:
			var m2: MeshInstance3D = _b.rod(tower, pair[0], pair[1], 0.6, mat_b)
			m2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 工事中の上部（クレーン）
	var crane: MeshInstance3D = _b.rod(tower, Vector3(0, h, 0), Vector3(0, h + 18.0, 0), 0.5, white)
	crane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_b.rod(tower, Vector3(-10, h + 16.0, 0), Vector3(8, h + 16.0, 0), 0.35, red)


# ================================================================ プレイヤーと入口

func _spawn_player() -> void:
	_player = ForekoPlayer.new()
	add_child(_player)
	var spawn := Vector3(0, 0.1, STREET_START_Z - 1.0)
	var yaw: float = PI
	for door: Dictionary in _doors:
		if door["id"] == GameManager.return_shop:
			spawn = door["exit_pos"]
			spawn.y = 0.1
			yaw = door["yaw"]
	_player.global_position = spawn
	_player.set_facing(yaw)


func _process(delta: float) -> void:
	_blink_time += delta
	var phase: int = int(_blink_time * 4.0) % 3
	for b: Dictionary in _blink_bulbs:
		var mesh: MeshInstance3D = b["mesh"]
		mesh.material_override = b["off"] if int(b["group"]) == phase else b["on"]
	var flick: float = 1.0 if fmod(_blink_time, 3.3) > 0.12 else 0.35
	for l: Label3D in _neon_labels:
		l.modulate = Color(4.0, 3.2, 0.8) * flick
	_update_door_prompt()


func _update_door_prompt() -> void:
	if _player == null:
		return
	var nearest: Dictionary = {}
	var best: float = 2.2
	for door: Dictionary in _doors:
		var dp: Vector3 = door["pos"]
		var dist: float = Vector2(dp.x - _player.global_position.x, dp.z - _player.global_position.z).length()
		if dist < best:
			best = dist
			nearest = door
	_near_door = nearest
	_prompt_panel.visible = not nearest.is_empty()
	if not nearest.is_empty():
		_prompt.text = "[E] %s" % nearest["label"]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not _near_door.is_empty():
		shop_entered.emit(String(_near_door["id"]))


# ================================================================ HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.12, 0.08, 0.78)
	style.border_color = Color(0.95, 0.75, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	_hud_money = Label.new()
	_hud_money.add_theme_font_size_override("font_size", 22)
	_hud_money.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	vbox.add_child(_hud_money)
	_hud_prizes = Label.new()
	_hud_prizes.add_theme_font_size_override("font_size", 15)
	_hud_prizes.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	vbox.add_child(_hud_prizes)

	var help := Label.new()
	help.text = "WASD/矢印：移動　Shift：走る　右ドラッグ・Z/C：カメラ　ホイール：ズーム"
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	help.add_theme_constant_override("outline_size", 6)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(16, -34)
	layer.add_child(help)
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_top = -34
	help.offset_bottom = -10

	_prompt_panel = PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.75, 0.1, 0.08, 0.9)
	ps.border_color = Color(1.0, 0.9, 0.5)
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(10)
	ps.set_content_margin_all(12)
	_prompt_panel.add_theme_stylebox_override("panel", ps)
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -220
	_prompt_panel.offset_right = 220
	_prompt_panel.offset_top = -130
	_prompt_panel.offset_bottom = -80
	_prompt_panel.visible = false
	layer.add_child(_prompt_panel)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_color", Color(1, 1, 0.9))
	_prompt_panel.add_child(_prompt)
	_refresh_hud()


func _refresh_hud() -> void:
	_hud_money.text = "おこづかい  %d 円" % GameManager.money
	var parts: PackedStringArray = []
	for p: Dictionary in GameManager.PRIZES:
		var c: int = int(GameManager.prizes.get(p["id"], 0))
		if c > 0:
			parts.append("%s×%d" % [p["label"], c])
	var balls: String = "貯玉  スマートボール %d ／ パチンコ %d" % [GameManager.get_stored_balls("smartball"), GameManager.get_stored_balls("pachinko")]
	_hud_prizes.text = balls + "\n景品  " + ("なし" if parts.is_empty() else "、".join(parts))

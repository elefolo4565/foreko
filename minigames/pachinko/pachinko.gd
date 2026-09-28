extends BallTable
## 昭和レトロなパチンコ台（正村ゲージ風）。
## ハンドルの強さで玉を打ち上げ、チューリップや入賞口を狙う。
## センター役物の「V」に入ると全チューリップが開く。

const BOARD_POS: Vector2 = Vector2(500, 40)
const C: Vector2 = Vector2(290, 312)
const R_OUT: float = 280.0
const R_IN: float = 262.0
const LANE_START_DEG: float = 100.0
const LANE_END_DEG: float = 208.0
const BALL_R: float = 5.5
const BALL_COLOR: Color = Color(0.86, 0.88, 0.92)
const FIRE_INTERVAL: float = 0.6
const OUT_POS: Vector2 = Vector2(290, 578)

var pockets: Array = []  # {pos, w, value, kind, open, body, name}
var windmills: Array = []  # {body, pos, colors}
var _pin_positions: Array = []
var _power: float = 0.62
var _fire_timer: float = 0.0
var _anim_t: float = 0.0
var _v_flash: float = 0.0
## 役物のクルーン（回転盤）: 中央入賞した玉が回って 4 つの穴のどれかに落ちる。V なら当たり
const KROON_C: Vector2 = Vector2(290, 306)
const KROON_TIME: float = 1.8
const V_CHANCE: float = 0.12
var _kroon_queue: int = 0
var _kroon_t: float = -1.0
var _kroon_win: bool = false
var _kroon_start_angle: float = 0.0
var _hit_counts: Dictionary = {}


func _init() -> void:
	shop_id = "pachinko"
	shop_title = "パチンコ"
	shop_subtitle = "〜 ミナト会館 〜"
	balls_per_rent = 50
	rent_price = 100
	ball_is_glass = false
	accent = Color(0.75, 0.1, 0.08)


func _help_text() -> String:
	return "Space 長押し：玉を打つ\n↑↓・ホイール：ハンドルの強さ\nチューリップ … 7玉\n入ると開き、次で閉じる\n天 … 8玉　袖 … 6玉\n中央入賞 … 4玉＋クルーン抽選\nVに落ちれば +15玉と\nチューリップ全開放！"


func _setup_table() -> void:
	board.position = BOARD_POS
	_build_rails()
	_build_pockets()
	_build_windmills()
	_build_gauge()


# ---------------------------------------------------------------- 盤面の構築

func _build_rails() -> void:
	# 外レール（ほぼ一周）
	add_wall_chain(arc_points(C, R_OUT, LANE_START_DEG - 20.0, LANE_START_DEG + 340.0, 120))
	# 内レール（発射レーンの内側）
	add_wall_chain(arc_points(C, R_IN, LANE_START_DEG, LANE_END_DEG, 40))
	# レーンの底
	var a: float = deg_to_rad(LANE_START_DEG)
	add_wall_chain(PackedVector2Array([C + Vector2.from_angle(a) * (R_IN - 2.0), C + Vector2.from_angle(a) * (R_OUT + 2.0)]))
	# 右上の返しゴム
	var rb: float = deg_to_rad(338.0)
	add_wall_chain(PackedVector2Array([C + Vector2.from_angle(rb) * R_OUT, C + Vector2.from_angle(rb + 0.03) * (R_OUT - 22.0)]))
	# アウト口の左右のガイド
	add_wall_chain(PackedVector2Array([Vector2(200, 560), Vector2(262, 572)]))
	add_wall_chain(PackedVector2Array([Vector2(380, 560), Vector2(318, 572)]))


func _build_pockets() -> void:
	_add_pocket("ten", Vector2(290, 150), 12.0, 8, "天")
	_add_pocket("v", Vector2(290, 252), 12.0, 4, "中")
	_add_pocket("sode_l", Vector2(92, 372), 10.0, 6, "袖")
	_add_pocket("sode_r", Vector2(488, 372), 10.0, 6, "袖")
	_add_pocket("tulip", Vector2(176, 430), 10.0, 7, "L")
	_add_pocket("tulip", Vector2(404, 430), 10.0, 7, "R")
	_add_pocket("tulip", Vector2(290, 486), 10.0, 7, "C")
	# センター役物の本体（当たり判定）
	var body_pts := PackedVector2Array([
		Vector2(222, 262), Vector2(222, 330), Vector2(250, 352), Vector2(330, 352),
		Vector2(358, 330), Vector2(358, 262), Vector2(300, 256), Vector2(280, 256),
	])
	add_wall_chain(body_pts, true)
	# V 入賞口の両側の囲い
	add_wall_chain(PackedVector2Array([Vector2(280, 240), Vector2(282, 258)]))
	add_wall_chain(PackedVector2Array([Vector2(300, 240), Vector2(298, 258)]))


func _add_pocket(kind: String, pos: Vector2, w: float, value: int, pname: String) -> void:
	var p: Dictionary = {"kind": kind, "pos": pos, "w": w, "value": value, "open": false, "name": pname}
	if kind == "tulip":
		var body := StaticBody2D.new()
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.3
		body.physics_material_override = pm
		body.position = pos
		board.add_child(body)
		for s: int in [-1, 1]:
			var cs := CollisionShape2D.new()
			var c := CircleShape2D.new()
			c.radius = 2.5
			cs.shape = c
			body.add_child(cs)
		# 胴体（下半分）
		for s: int in [-1, 1]:
			var cs2 := CollisionShape2D.new()
			var seg := SegmentShape2D.new()
			seg.a = Vector2(s * 9.0, -2.0)
			seg.b = Vector2(s * 6.0, 14.0)
			cs2.shape = seg
			body.add_child(cs2)
		p["body"] = body
		_set_tulip_shape(p, false)
	elif kind != "v":
		# 入賞口の左右の爪
		add_pin(pos + Vector2(-w * 0.5 - 4.0, -2.0), 2.2)
		add_pin(pos + Vector2(w * 0.5 + 4.0, -2.0), 2.2)
		add_wall_chain(PackedVector2Array([pos + Vector2(-w * 0.5 - 4.0, 0), pos + Vector2(-w * 0.5, 12)]))
		add_wall_chain(PackedVector2Array([pos + Vector2(w * 0.5 + 4.0, 0), pos + Vector2(w * 0.5, 12)]))
	pockets.append(p)


## チューリップの羽根：閉じると狭く、開くと大きく広がって玉を拾う
func _set_tulip_shape(p: Dictionary, is_open: bool) -> void:
	p["open"] = is_open
	p["w"] = 19.0 if is_open else 8.0
	var body: StaticBody2D = p["body"]
	var petals: Array = [body.get_child(0), body.get_child(1)]
	var sgn: Array = [-1.0, 1.0]
	for i: int in 2:
		var cs: CollisionShape2D = petals[i]
		cs.position = Vector2(sgn[i] * (14.5 if is_open else 8.0), -12.0 if is_open else -5.0)


func _build_windmills() -> void:
	for pos: Vector2 in [Vector2(140, 260), Vector2(440, 260)]:
		var body := AnimatableBody2D.new()
		body.sync_to_physics = false
		body.position = pos
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.4
		body.physics_material_override = pm
		for k: int in 4:
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(12.0, 3.0)
			cs.shape = rect
			cs.position = Vector2.from_angle(k * PI * 0.5) * 7.0
			cs.rotation = k * PI * 0.5
			body.add_child(cs)
		board.add_child(body)
		windmills.append({"body": body, "pos": pos})
		# 風車の軸を囲む釘
		for ang: float in [-120.0, -60.0]:
			_place_pin(pos + Vector2.from_angle(deg_to_rad(ang)) * 20.0)


func _build_gauge() -> void:
	# 天釘：上部のアーチ状の列
	for i: int in 13:
		var a: float = deg_to_rad(lerpf(215.0, 325.0, float(i) / 12.0))
		_place_pin(C + Vector2.from_angle(a) * 205.0)
	for i: int in 9:
		var a2: float = deg_to_rad(lerpf(228.0, 312.0, float(i) / 8.0))
		_place_pin(C + Vector2.from_angle(a2) * 180.0)
	# 天入賞口の命釘（玉1個ぶんより少し広いだけの隙間）と、真上の釘
	for pp: Vector2 in [Vector2(281, 132), Vector2(299, 132), Vector2(290, 116), Vector2(266, 128), Vector2(314, 128)]:
		_place_pin(pp)
	# V 入賞口：真上をふさぐ釘と、左右へそらす釘
	for pp: Vector2 in [Vector2(290, 232), Vector2(276, 226), Vector2(304, 226), Vector2(262, 210), Vector2(318, 210), Vector2(290, 204)]:
		_place_pin(pp)
	# チューリップのハカマ釘
	for pk: Dictionary in pockets:
		if pk["kind"] == "tulip":
			var tp: Vector2 = pk["pos"]
			for off: Vector2 in [Vector2(0, -27), Vector2(-24, -14), Vector2(24, -14), Vector2(-30, 2), Vector2(30, 2), Vector2(-14, -36), Vector2(14, -36)]:
				_place_pin(tp + off)
		elif pk["kind"] != "v":
			var sp: Vector2 = pk["pos"]
			for off2: Vector2 in [Vector2(-18, -18), Vector2(18, -18)]:
				_place_pin(sp + off2)
	# 役物の両脇の道釘（斜めの列）
	for i: int in 5:
		_place_pin(Vector2(205 - i * 14.0, 360 + i * 9.0))
		_place_pin(Vector2(375 + i * 14.0, 360 + i * 9.0))
	# 風車の下の道釘
	for i: int in 4:
		_place_pin(Vector2(120 + i * 12.0, 300 + i * 12.0))
		_place_pin(Vector2(460 - i * 12.0, 300 + i * 12.0))
	# 残りの場所に散らし釘
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var row: int = 0
	var y: float = 115.0
	while y < 545.0:
		var off3: float = 13.0 if row % 2 == 0 else 0.0
		var x: float = 40.0 + off3
		while x < 545.0:
			var p := Vector2(x + rng.randf_range(-2, 2), y)
			if _gauge_allowed(p):
				_place_pin(p)
			x += 26.0
		y += 22.0
		row += 1


func _gauge_allowed(p: Vector2) -> bool:
	if p.distance_to(C) > R_IN - 16.0:
		return false
	# センター役物
	if p.x > 205.0 and p.x < 375.0 and p.y > 195.0 and p.y < 372.0:
		return false
	# 天入賞口まわり
	if p.distance_to(Vector2(290, 150)) < 44.0:
		return false
	for wm: Dictionary in windmills:
		if p.distance_to(wm["pos"]) < 34.0:
			return false
	for pk: Dictionary in pockets:
		if p.distance_to(pk["pos"]) < 42.0:
			return false
	# アウト口
	if p.distance_to(OUT_POS) < 60.0:
		return false
	for q: Vector2 in _pin_positions:
		if p.distance_to(q) < 20.0:
			return false
	return true


func _place_pin(p: Vector2) -> void:
	add_pin(p, 2.0)
	_pin_positions.append(p)


# ---------------------------------------------------------------- 入力・更新

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if _exchanging:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_power = minf(1.0, _power + 0.02)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_power = maxf(0.0, _power - 0.02)


func _physics_process(delta: float) -> void:
	if _exchanging:
		return
	if Input.is_key_pressed(KEY_UP):
		_power = minf(1.0, _power + delta * 0.3)
	if Input.is_key_pressed(KEY_DOWN):
		_power = maxf(0.0, _power - delta * 0.3)
	for wm: Dictionary in windmills:
		var body: AnimatableBody2D = wm["body"]
		body.rotation += delta * 2.2
	_fire_timer -= delta
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0:
		_fire_timer = FIRE_INTERVAL
		_fire()
	for b: TableBall in balls.duplicate():
		if not is_instance_valid(b):
			balls.erase(b)
			continue
		_update_ball(b)


func _fire() -> void:
	if not use_ball():
		return
	var a: float = deg_to_rad(LANE_START_DEG + 7.0)
	var pos: Vector2 = C + Vector2.from_angle(a) * ((R_IN + R_OUT) * 0.5)
	# 角度が増える向きの接線（左上へ）
	var tangent := Vector2(-sin(a), cos(a))
	# ハンドル最弱でもレーンを抜けやすいよう下限を上げ、打てる範囲を広げている
	var speed: float = lerpf(1000.0, 1450.0, _power) * randf_range(0.97, 1.03)
	spawn_ball(pos, tangent * speed, BALL_R, BALL_COLOR, 0.35, 1.0)
	Sound.play("launch", -10.0, 1.4)


func _update_ball(b: TableBall) -> void:
	var p: Vector2 = b.position
	var rel: Vector2 = p - C
	var r: float = rel.length()
	var deg: float = fposmod(rad_to_deg(rel.angle()), 360.0)
	# ファール：レーン内を逆戻りして下まで落ちた玉は返却
	var in_lane: bool = r > R_IN and deg > LANE_START_DEG - 2.0 and deg < LANE_END_DEG
	var is_foul: bool = false
	if in_lane and deg < LANE_START_DEG + 14.0 and b.age > 0.2:
		var tangent := Vector2(-sin(deg_to_rad(deg)), cos(deg_to_rad(deg)))
		is_foul = b.linear_velocity.dot(tangent) <= 5.0
	# レーン内で玉同士が詰まってレールの外へ弾かれた玉・居座った玉もファール扱い
	if in_lane and (r > R_OUT + 8.0 or b.age > 6.0):
		is_foul = true
	if is_foul:
		held_balls += 1
		_update_labels()
		remove_ball(b)
		return
	# アウト口
	if p.distance_to(OUT_POS) < 22.0 or p.y > 600.0 or r > R_OUT + 20.0:
		remove_ball(b)
		return
	# 入賞口
	for pk: Dictionary in pockets:
		var pp: Vector2 = pk["pos"]
		var half: float = float(pk["w"]) * 0.5
		if absf(p.x - pp.x) < half and p.y > pp.y - 4.0 and p.y < pp.y + 8.0 and b.linear_velocity.y > -20.0:
			_on_pocket(pk)
			remove_ball(b)
			return


func _on_pocket(pk: Dictionary) -> void:
	var kind: String = pk["kind"]
	payout(int(pk["value"]), pk["pos"])
	_hit_counts[kind] = int(_hit_counts.get(kind, 0)) + 1
	match kind:
		"tulip":
			_set_tulip_shape(pk, not bool(pk["open"]))
			Sound.play("spring", -10.0, 1.6)
		"v":
			_kroon_queue += 1


func _start_kroon() -> void:
	_kroon_queue -= 1
	_kroon_t = 0.0
	_kroon_win = randf() < V_CHANCE
	_kroon_start_angle = randf() * TAU


func _finish_kroon() -> void:
	_kroon_t = -1.0
	if _kroon_win:
		_hit_counts["vwin"] = int(_hit_counts.get("vwin", 0)) + 1
		_v_flash = 2.5
		payout(15, KROON_C, true)
		for t: Dictionary in pockets:
			if t["kind"] == "tulip":
				_set_tulip_shape(t, true)
		_flash_info("V入賞！ チューリップ全開放！")
	else:
		Sound.play("hole", -10.0, 0.8)


func _process(delta: float) -> void:
	super._process(delta)
	_anim_t += delta
	_v_flash = maxf(0.0, _v_flash - delta)
	if _kroon_t >= 0.0:
		_kroon_t += delta
		if _kroon_t >= KROON_TIME:
			_finish_kroon()
	elif _kroon_queue > 0:
		_start_kroon()
	queue_redraw()


# ---------------------------------------------------------------- 描画

func _draw() -> void:
	_draw_room()
	draw_set_transform(BOARD_POS)
	_draw_cabinet()
	_draw_field()
	_draw_center()
	for pk: Dictionary in pockets:
		if pk["kind"] == "tulip":
			_draw_tulip(pk)
		elif pk["kind"] != "v":
			_draw_pocket(pk)
	for wm: Dictionary in windmills:
		_draw_windmill(wm)
	for p: Vector2 in _pin_positions:
		_draw_nail(p)
	_draw_rails()
	_draw_glass()
	_draw_tray()
	draw_set_transform(Vector2.ZERO)
	_draw_side_info()


func _draw_room() -> void:
	var vp: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.3, 0.12, 0.1))
	# 並んだ隣の台（シルエット）
	for x: float in [330.0, 1130.0]:
		_draw_round_rect(Rect2(x, 40, 150, 560), 12.0, Color(0.4, 0.2, 0.12))
		draw_circle(Vector2(x + 75, 250), 60.0, Color(0.55, 0.45, 0.3, 0.6))
	draw_rect(Rect2(0, vp.y - 60, vp.x, 60), Color(0.2, 0.1, 0.08))
	for x2: float in [600.0, 900.0]:
		for r: int in 5:
			draw_circle(Vector2(x2, 0), 180.0 - r * 30.0, Color(1.0, 0.85, 0.5, 0.035))


func _draw_cabinet() -> void:
	# 木枠（ニス塗り）と金の縁
	_draw_round_rect(Rect2(-18, -32, 616, 700), 18.0, Color(0.35, 0.16, 0.07))
	_draw_round_rect(Rect2(-10, -24, 600, 684), 14.0, Color(0.52, 0.26, 0.1))
	for i: int in 12:
		var y: float = -20.0 + i * 57.0
		draw_line(Vector2(-6, y), Vector2(586, y + 8), Color(0.45, 0.22, 0.08, 0.5), 2.0)
	draw_circle(C, R_OUT + 12.0, Color(0.85, 0.7, 0.3))
	draw_circle(C, R_OUT + 8.0, Color(0.55, 0.45, 0.2))
	# 下部の名盤
	_draw_round_rect(Rect2(210, 604, 160, 30), 8.0, Color(0.85, 0.7, 0.3))
	_draw_text_c("ミナト号", Vector2(290, 627), GameManager.font_sign, 22, Color(0.45, 0.1, 0.05))


func _draw_field() -> void:
	draw_circle(C, R_OUT + 2.0, Color(0.97, 0.94, 0.8))
	# 放射状の日の出模様（上部）
	for k: int in 16:
		var a0: float = deg_to_rad(180.0 + k * 11.25)
		var a1: float = a0 + deg_to_rad(5.6)
		var tri := PackedVector2Array([C + Vector2(0, -60), C + Vector2.from_angle(a0) * R_OUT, C + Vector2.from_angle(a1) * R_OUT])
		draw_colored_polygon(tri, Color(1.0, 0.75, 0.35, 0.28))
	# 下半分の水色の波
	for i: int in 3:
		var pts := PackedVector2Array()
		var base_y: float = 440.0 + i * 38.0
		for k2: int in 30:
			var x: float = 20.0 + k2 * 19.0
			pts.append(Vector2(x, base_y + sin(x * 0.04 + i) * 8.0))
		pts.append(Vector2(570, 620))
		pts.append(Vector2(10, 620))
		var circle: PackedVector2Array = arc_points(C, R_OUT, 0.0, 360.0, 72)
		for c: PackedVector2Array in Geometry2D.intersect_polygons(pts, circle):
			draw_colored_polygon(c, Color(0.45, 0.72, 0.85, 0.2))
	# 桜の花（昭和の盤面絵）
	for fl: Vector2 in [Vector2(80, 470), Vector2(500, 470), Vector2(120, 170), Vector2(460, 170), Vector2(200, 540), Vector2(380, 540)]:
		for k3: int in 5:
			draw_circle(fl + Vector2.from_angle(k3 * TAU / 5.0 - PI * 0.5) * 9.0, 8.0, Color(1.0, 0.6, 0.7, 0.7))
		draw_circle(fl, 4.0, Color(1.0, 0.9, 0.4))
	# アウト口
	draw_circle(OUT_POS, 20.0, Color(0.55, 0.45, 0.2))
	draw_circle(OUT_POS, 15.0, Color(0.1, 0.06, 0.04))
	_draw_text_c("アウト", OUT_POS + Vector2(0, -24), GameManager.font_ui, 11, Color(0.4, 0.3, 0.2))


func _draw_center() -> void:
	# センター役物：赤い漆塗り風の飾り枠に富士山と日の丸
	var body := PackedVector2Array([
		Vector2(222, 262), Vector2(222, 330), Vector2(250, 352), Vector2(330, 352),
		Vector2(358, 330), Vector2(358, 262), Vector2(300, 256), Vector2(280, 256),
	])
	var shadow := PackedVector2Array()
	for p: Vector2 in body:
		shadow.append(p + Vector2(4, 5))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.25))
	draw_colored_polygon(body, Color(0.8, 0.12, 0.1))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.95, 0.8, 0.3), 3.0, true)
	var inner := Rect2(234, 272, 112, 66)
	draw_rect(inner, Color(0.55, 0.8, 0.95))
	# 背景の富士山と日の丸
	draw_circle(Vector2(256, 288), 9.0, Color(0.95, 0.2, 0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(234, 338), Vector2(268, 300), Vector2(302, 338)]), Color(0.3, 0.4, 0.7))
	draw_colored_polygon(PackedVector2Array([Vector2(260, 309), Vector2(268, 300), Vector2(276, 309), Vector2(271, 307), Vector2(268, 311), Vector2(264, 307)]), Color(1, 1, 1))
	_draw_kroon()
	draw_rect(inner, Color(0.95, 0.8, 0.3), false, 2.0)
	# V 入賞口
	var glow: float = 1.0 if (_v_flash > 0.0 and int(_anim_t * 12.0) % 2 == 0) else 0.0
	draw_colored_polygon(PackedVector2Array([Vector2(276, 238), Vector2(304, 238), Vector2(300, 258), Vector2(280, 258)]), Color(0.95, 0.8, 0.2).lerp(Color(1, 1, 0.9), glow))
	draw_rect(Rect2(283, 246, 14, 10), Color(0.15, 0.08, 0.05))
	_draw_text_c("V", Vector2(290, 252), GameManager.font_pop, 16, Color(0.8, 0.05, 0.05))
	_draw_text_c("千両", Vector2(290, 366), GameManager.font_sign, 16, Color(0.6, 0.1, 0.05))


func _draw_kroon() -> void:
	var c: Vector2 = KROON_C + Vector2(18, 0)
	draw_circle(c, 26.0, Color(0.85, 0.85, 0.9))
	draw_circle(c, 23.0, Color(0.95, 0.95, 1.0))
	var hole_names: Array = ["V", "×", "×", "×"]
	for k: int in 4:
		var hp: Vector2 = c + Vector2.from_angle(k * TAU / 4.0 + PI * 0.5) * 12.0
		var is_v: bool = k == 0
		draw_circle(hp, 5.0, Color(0.9, 0.15, 0.1) if is_v else Color(0.25, 0.25, 0.3))
		_draw_text_c(hole_names[k], hp + Vector2(0, 3.5), GameManager.font_pop, 9, Color(1, 1, 0.8))
	if _kroon_t >= 0.0:
		var u: float = clampf(_kroon_t / KROON_TIME, 0.0, 1.0)
		# 最後に止まる穴：当たりなら V(下), 外れなら他の3つのどれか
		var target_k: int = 0 if _kroon_win else 1 + int(_kroon_start_angle * 10.0) % 3
		var target_a: float = target_k * TAU / 4.0 + PI * 0.5
		var spins: float = 3.0
		var total: float = target_a + TAU * spins - fposmod(_kroon_start_angle, TAU)
		var ease_u: float = 1.0 - pow(1.0 - u, 2.2)
		var a: float = _kroon_start_angle + total * ease_u
		var r: float = lerpf(20.0, 12.0, clampf((u - 0.6) / 0.4, 0.0, 1.0))
		TableBall.draw_ball(self, c + Vector2.from_angle(a) * r, 4.5, BALL_COLOR, false)


func _draw_tulip(pk: Dictionary) -> void:
	var p: Vector2 = pk["pos"]
	var is_open: bool = pk["open"]
	var red := Color(0.95, 0.2, 0.2)
	var yellow := Color(1.0, 0.85, 0.2)
	var col: Color = red if pk["name"] != "C" else yellow
	# 茎と葉
	draw_line(p + Vector2(0, 14), p + Vector2(0, 26), Color(0.2, 0.55, 0.2), 3.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, 22), p + Vector2(-12, 16), p + Vector2(-4, 26)]), Color(0.3, 0.7, 0.3))
	# 胴体
	draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -2), p + Vector2(9, -2), p + Vector2(6, 14), p + Vector2(-6, 14)]), col)
	draw_rect(Rect2(p + Vector2(-5, -1), Vector2(10, 6)), Color(0.15, 0.05, 0.05))
	# 羽根
	for s: float in [-1.0, 1.0]:
		var tip: Vector2 = p + (Vector2(s * 14.5, -12.0) if is_open else Vector2(s * 8.0, -5.0))
		var petal := PackedVector2Array([p + Vector2(s * 8.0, 2.0), tip, tip + Vector2(s * 3.0, 5.0)])
		draw_colored_polygon(petal, col.lightened(0.2))
		draw_circle(tip, 2.5, col.darkened(0.2))
	if is_open:
		draw_circle(p + Vector2(0, -6), 3.0, Color(1, 1, 0.7, 0.5 + 0.5 * sin(_anim_t * 8.0)))


func _draw_pocket(pk: Dictionary) -> void:
	var p: Vector2 = pk["pos"]
	var w: float = pk["w"]
	var cup := PackedVector2Array([p + Vector2(-w * 0.5 - 5, -2), p + Vector2(w * 0.5 + 5, -2), p + Vector2(w * 0.5 + 1, 13), p + Vector2(-w * 0.5 - 1, 13)])
	draw_colored_polygon(cup, Color(0.2, 0.65, 0.4))
	draw_rect(Rect2(p + Vector2(-w * 0.5 + 1, 0), Vector2(w - 2, 7)), Color(0.08, 0.1, 0.08))
	_draw_text_c(pk["name"], p + Vector2(0, 26), GameManager.font_sign, 13, Color(0.2, 0.4, 0.25))
	_draw_text_c(str(pk["value"]), p + Vector2(0, 12), GameManager.font_pop, 9, Color(1, 1, 0.9))


func _draw_windmill(wm: Dictionary) -> void:
	var body: AnimatableBody2D = wm["body"]
	var p: Vector2 = wm["pos"]
	var cols: Array = [Color(0.95, 0.2, 0.2), Color(1.0, 0.85, 0.2), Color(0.2, 0.5, 0.95), Color(0.2, 0.75, 0.35)]
	for k: int in 4:
		var a: float = body.rotation + k * PI * 0.5
		var d: Vector2 = Vector2.from_angle(a)
		var n: Vector2 = d.orthogonal()
		var blade := PackedVector2Array([p, p + d * 13.0 + n * 3.0, p + d * 13.0 - n * 2.0])
		draw_colored_polygon(blade, cols[k])
	draw_circle(p, 3.0, Color(0.9, 0.9, 0.9))


func _draw_nail(p: Vector2) -> void:
	draw_circle(p + Vector2(1.8, 2.4), 2.4, Color(0, 0, 0, 0.3))
	draw_circle(p, 2.4, Color(0.72, 0.6, 0.3))
	draw_circle(p + Vector2(-0.6, -0.6), 1.2, Color(1.0, 0.95, 0.75))


func _draw_rails() -> void:
	draw_polyline(arc_points(C, R_OUT + 2.0, 0.0, 360.0, 120), Color(0.85, 0.87, 0.9), 4.0, true)
	draw_polyline(arc_points(C, R_IN - 1.0, LANE_START_DEG, LANE_END_DEG, 40), Color(0.85, 0.87, 0.9), 3.0, true)
	var rb: float = deg_to_rad(338.0)
	draw_line(C + Vector2.from_angle(rb) * R_OUT, C + Vector2.from_angle(rb + 0.03) * (R_OUT - 22.0), Color(0.2, 0.2, 0.2), 5.0)


func _draw_glass() -> void:
	var band := PackedVector2Array([Vector2(60, 0), Vector2(150, 0), Vector2(-40, 620), Vector2(-130, 620)])
	var circle: PackedVector2Array = arc_points(C, R_OUT, 0.0, 360.0, 72)
	for c: PackedVector2Array in Geometry2D.intersect_polygons(band, circle):
		draw_colored_polygon(c, Color(1, 1, 1, 0.06))


func _draw_tray() -> void:
	# 上皿と玉、右下のハンドル
	var tray := Rect2(40, 640, 440, 36)
	_draw_round_rect(tray.grow(4), 16.0, Color(0.75, 0.75, 0.78))
	_draw_round_rect(tray, 14.0, Color(0.35, 0.36, 0.4))
	var n: int = mini(held_balls, 70)
	for i: int in n:
		var col: int = i % 35
		var row: int = i / 35
		TableBall.draw_ball(self, Vector2(56 + col * 12.0 + row * 6.0, 666 - row * 10.0), 5.5, BALL_COLOR, false)
	var hc := Vector2(540, 660)
	draw_circle(hc, 28.0, Color(0.7, 0.7, 0.72))
	draw_circle(hc, 22.0, Color(0.85, 0.2, 0.15))
	var ang: float = deg_to_rad(-210.0 + 240.0 * _power)
	draw_line(hc, hc + Vector2.from_angle(ang) * 20.0, Color(1, 1, 1), 4.0)
	_draw_text_c("強さ %d" % int(_power * 100.0), hc + Vector2(0, -34), GameManager.font_ui, 13, Color(1, 0.95, 0.8))


func _draw_side_info() -> void:
	var x: float = 1110.0
	var f: Font = GameManager.font_ui
	_draw_round_rect(Rect2(x - 10, 60, 165, 200), 10.0, Color(0.95, 0.9, 0.78, 0.95))
	draw_string(GameManager.font_sign, Vector2(x + 10, 92), "入賞記録", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.5, 0.1, 0.05))
	var y: float = 124.0
	for pair: Array in [["チューリップ", "tulip"], ["中央入賞", "v"], ["V当たり", "vwin"], ["天・袖", "ten"]]:
		var cnt: int = int(_hit_counts.get(pair[1], 0))
		if pair[1] == "ten":
			for k: String in _hit_counts.keys():
				if k.begins_with("sode"):
					cnt += int(_hit_counts[k])
		draw_string(f, Vector2(x, y), "%s  %d" % [pair[0], cnt], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.2, 0.12, 0.08))
		y += 28.0
	draw_string(f, Vector2(x, y + 10), "払い出し %d 玉" % total_out, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.1, 0.05))


func _draw_round_rect(r: Rect2, radius: float, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _draw_text_c(text: String, center_baseline: Vector2, font: Font, size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, center_baseline - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

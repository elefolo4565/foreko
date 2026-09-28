class_name TableBall
extends RigidBody2D
## 遊技台の玉。ガラス玉（スマートボール）と鋼球（パチンコ）の両方に使う。

var radius: float = 6.0
var glass: bool = false
var base_color: Color = Color(0.85, 0.87, 0.9)
var captured: bool = false
## 発射からの経過時間
var age: float = 0.0
var _last_hit_ms: int = 0


func setup(r: float, is_glass: bool, color: Color, bounce: float, grav_scale: float) -> void:
	radius = r
	glass = is_glass
	base_color = color
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = r
	cs.shape = shape
	add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = 0.15
	physics_material_override = pm
	gravity_scale = grav_scale
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 2
	linear_damp = 0.05
	angular_damp = 1.0
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	age += delta


func _on_body_entered(body: Node) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_hit_ms < 60:
		return
	_last_hit_ms = now
	var spd: float = linear_velocity.length()
	if spd < 40.0:
		return
	var vol: float = clampf(-26.0 + spd * 0.02, -26.0, -8.0)
	if glass:
		Sound.play("clack_low", vol, randf_range(0.9, 1.1), 25)
	else:
		Sound.play("clack", vol - 4.0, randf_range(0.9, 1.15), 18)


func _draw() -> void:
	draw_ball(self, Vector2.ZERO, radius, base_color, glass)


## 玉の描画（穴に入った玉の表示にも使う）
static func draw_ball(ci: CanvasItem, center: Vector2, r: float, color: Color, is_glass: bool) -> void:
	ci.draw_circle(center + Vector2(r * 0.15, r * 0.25), r, Color(0, 0, 0, 0.25))
	if is_glass:
		ci.draw_circle(center, r, color.darkened(0.35))
		ci.draw_circle(center + Vector2(r * 0.1, r * 0.12), r * 0.8, color)
		ci.draw_circle(center + Vector2(r * 0.2, r * 0.3), r * 0.45, color.lightened(0.35))
		ci.draw_circle(center + Vector2(-r * 0.35, -r * 0.4), r * 0.28, Color(1, 1, 1, 0.85))
	else:
		ci.draw_circle(center, r, Color(0.45, 0.47, 0.5))
		ci.draw_circle(center + Vector2(-r * 0.1, -r * 0.1), r * 0.8, color)
		ci.draw_circle(center + Vector2(r * 0.25, r * 0.3), r * 0.35, Color(0.55, 0.57, 0.6))
		ci.draw_circle(center + Vector2(-r * 0.35, -r * 0.38), r * 0.3, Color(1, 1, 1, 0.95))

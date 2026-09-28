class_name ForekoPlayer
extends CharacterBody3D
## foreko.glb を操作する三人称キャラクター。
## モデルにアニメーションが無いので、骨を手続き的に回して歩行させる。

const MODEL_PATH: String = "res://assets/models/foreko.glb"
const MODEL_SCALE: float = 1.45
const WALK_SPEED: float = 3.0
const RUN_SPEED: float = 6.0
const TURN_SPEED: float = 10.0
const GRAVITY: float = 20.0
const MOUSE_SENS: float = 0.005

var camera: Camera3D

var _model_root: Node3D
var _skeleton: Skeleton3D
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.22
var _cam_dist: float = 4.2
var _pivot: Node3D
var _spring: SpringArm3D
var _phase: float = 0.0
var _move_blend: float = 0.0
var _idle_time: float = 0.0
var _last_step_sign: float = 0.0
## 骨名 -> {idx, rest_rot(Quaternion), right(Vector3), fwd(Vector3), up(Vector3)}（骨ローカルでの世界軸）
var _bones: Dictionary = {}
## 腕を下ろす補正（骨ローカルの Quaternion）
var _arm_fix: Dictionary = {}
var _sk_inv: Basis = Basis.IDENTITY


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.4
	cs.shape = cap
	cs.position.y = 0.7
	add_child(cs)
	_load_model()
	_build_camera()


func _load_model() -> void:
	_model_root = Node3D.new()
	add_child(_model_root)
	var scene: PackedScene = load(MODEL_PATH)
	var inst: Node3D = scene.instantiate()
	inst.scale = Vector3.ONE * MODEL_SCALE
	_model_root.add_child(inst)
	var found: Array = inst.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	_skeleton = found[0]
	var meshes: Array = inst.find_children("*", "MeshInstance3D", true, false)
	if not meshes.is_empty():
		AutoRig.rebuild(meshes[0], _skeleton)
	_collect_bones()


func _collect_bones() -> void:
	var names: Array = [
		"Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
		"LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "LeftFoot", "RightFoot",
		"LeftShoulder", "LeftArm", "LeftForeArm", "RightShoulder", "RightArm", "RightForeArm",
	]
	# モデル空間（キャラは +Z を向く）の軸を骨格空間へ変換する
	var sk_basis: Basis = (_model_root.global_transform.affine_inverse() * _skeleton.global_transform).basis.orthonormalized()
	_sk_inv = sk_basis.inverse()
	for n: String in names:
		var idx: int = _skeleton.find_bone("mixamorig_" + n)
		if idx < 0:
			idx = _skeleton.find_bone("mixamorig:" + n)
		if idx < 0:
			continue
		var global_rest: Transform3D = _skeleton.get_bone_global_rest(idx)
		var inv: Basis = global_rest.basis.orthonormalized().inverse()
		_bones[n] = {
			"idx": idx,
			"rest_rot": _skeleton.get_bone_rest(idx).basis.get_rotation_quaternion(),
			"right": (inv * (_sk_inv * Vector3.RIGHT)).normalized(),
			"fwd": (inv * (_sk_inv * Vector3.BACK)).normalized(),
			"up": (inv * (_sk_inv * Vector3.UP)).normalized(),
		}
	_compute_arm_fix("Left", "LeftArm", "LeftForeArm", 1.0)
	_compute_arm_fix("Right", "RightArm", "RightForeArm", -1.0)


## T ポーズの腕を体の横に下ろす回転を求める
func _compute_arm_fix(side: String, arm: String, fore: String, sgn: float) -> void:
	if not _bones.has(arm) or not _bones.has(fore):
		return
	var a_idx: int = _bones[arm]["idx"]
	var f_idx: int = _bones[fore]["idx"]
	var a_pos: Vector3 = _skeleton.get_bone_global_rest(a_idx).origin
	var f_pos: Vector3 = _skeleton.get_bone_global_rest(f_idx).origin
	var cur_dir: Vector3 = (f_pos - a_pos).normalized()
	var target: Vector3 = (_sk_inv * Vector3(0.16 * sgn, -1.0, 0.04)).normalized()
	var delta := Quaternion(cur_dir, target)
	var g_rot: Quaternion = _skeleton.get_bone_global_rest(a_idx).basis.orthonormalized().get_rotation_quaternion()
	_arm_fix[side] = g_rot.inverse() * delta * g_rot


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.top_level = true
	add_child(_pivot)
	_spring = SpringArm3D.new()
	_spring.spring_length = _cam_dist
	_spring.margin = 0.2
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.25
	_spring.shape = sphere_shape
	_pivot.add_child(_spring)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.current = true
	_spring.add_child(camera)
	_update_camera_transform(1.0)


func set_facing(yaw: float) -> void:
	_model_root.rotation.y = yaw
	_cam_yaw = yaw + PI
	_update_camera_transform(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mm: InputEventMouseMotion = event
		_cam_yaw -= mm.relative.x * MOUSE_SENS
		_cam_pitch = clampf(_cam_pitch - mm.relative.y * MOUSE_SENS, -1.0, 0.25)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_dist = maxf(1.8, _cam_dist - 0.3)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_dist = minf(8.0, _cam_dist + 0.3)


func _physics_process(delta: float) -> void:
	if Input.is_key_pressed(KEY_Z):
		_cam_yaw += 1.8 * delta
	if Input.is_key_pressed(KEY_C):
		_cam_yaw -= 1.8 * delta
	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := Basis(Vector3.UP, _cam_yaw)
	var dir: Vector3 = cam_basis * Vector3(input_vec.x, 0.0, input_vec.y)
	var speed: float = RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	var target_vel: Vector3 = dir * speed
	velocity.x = move_toward(velocity.x, target_vel.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, 30.0 * delta)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var flat_speed: float = Vector2(velocity.x, velocity.z).length()
	if dir.length() > 0.05:
		var target_yaw: float = atan2(dir.x, dir.z)
		_model_root.rotation.y = lerp_angle(_model_root.rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))
	_animate(delta, flat_speed)
	_update_camera_transform(delta)


func _update_camera_transform(delta: float) -> void:
	if _pivot == null:
		return
	var target_pos: Vector3 = global_position + Vector3(0.0, 1.35, 0.0)
	_pivot.global_position = _pivot.global_position.lerp(target_pos, clampf(delta * 12.0, 0.0, 1.0)) if delta < 1.0 else target_pos
	_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
	_spring.spring_length = lerpf(_spring.spring_length, _cam_dist, clampf(delta * 8.0, 0.0, 1.0))


# ---------------------------------------------------------------- 手続きアニメーション

func _animate(delta: float, flat_speed: float) -> void:
	if _skeleton == null:
		return
	var moving: float = clampf(flat_speed / WALK_SPEED, 0.0, 1.6)
	_move_blend = lerpf(_move_blend, minf(moving, 1.0), clampf(delta * 8.0, 0.0, 1.0))
	var run_amt: float = clampf((flat_speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)
	_phase += delta * (5.5 + 4.5 * run_amt) * maxf(_move_blend, 0.0)
	_idle_time += delta

	var s: float = sin(_phase)
	var b: float = _move_blend
	var leg_amp: float = 0.55 + 0.25 * run_amt
	var arm_amp: float = 0.45 + 0.35 * run_amt
	var breath: float = sin(_idle_time * 2.2) * 0.03 * (1.0 - b)

	# 脚：前後に振る（右軸まわり）
	_rot_bone("LeftUpLeg", ["right", s * leg_amp * b])
	_rot_bone("RightUpLeg", ["right", -s * leg_amp * b])
	# 膝：足先が後ろへ曲がる向き（+X まわり正方向が後ろ）
	_rot_bone("LeftLeg", ["right", maxf(0.0, -cos(_phase)) * 0.9 * b + 0.05 * b])
	_rot_bone("RightLeg", ["right", maxf(0.0, cos(_phase)) * 0.9 * b + 0.05 * b])
	# 体：前傾と左右のひねり
	_rot_bone("Spine", ["right", 0.06 * b + 0.1 * run_amt + breath, "up", s * 0.08 * b])
	_rot_bone("Spine2", ["right", breath * 0.5])
	_rot_bone("Head", ["up", -s * 0.06 * b, "fwd", sin(_idle_time * 0.9) * 0.04 * (1.0 - b)])
	# 腕：下ろしてから振る
	_rot_arm("Left", "LeftArm", -s * arm_amp * b, breath)
	_rot_arm("Right", "RightArm", s * arm_amp * b, breath)
	_rot_bone("LeftForeArm", ["right", 0.0])
	_rot_bone("RightForeArm", ["right", 0.0])

	# 上下のバウンド
	_model_root.position.y = absf(sin(_phase)) * 0.05 * b
	var step_sign: float = signf(s)
	if b > 0.5 and step_sign != _last_step_sign:
		Sound.play("step", -18.0, randf_range(0.9, 1.1))
	_last_step_sign = step_sign


## axis_angles: ["right"/"fwd"/"up", angle, ...] をキャラ空間の軸で回す
func _rot_bone(bone_name: String, axis_angles: Array) -> void:
	if not _bones.has(bone_name):
		return
	var info: Dictionary = _bones[bone_name]
	var q: Quaternion = info["rest_rot"]
	var i: int = 0
	while i < axis_angles.size():
		var axis: Vector3 = info[axis_angles[i]]
		q = q * Quaternion(axis, float(axis_angles[i + 1]))
		i += 2
	_skeleton.set_bone_pose_rotation(int(info["idx"]), q)


func _rot_arm(side: String, bone_name: String, swing: float, breath: float) -> void:
	if not _bones.has(bone_name):
		return
	var info: Dictionary = _bones[bone_name]
	var q: Quaternion = info["rest_rot"]
	if _arm_fix.has(side):
		q = q * (_arm_fix[side] as Quaternion)
	# 下ろした後の腕を前後に振る：キャラ空間の右軸をさらに補正後の骨ローカルへ
	var fix: Quaternion = _arm_fix.get(side, Quaternion.IDENTITY)
	var axis: Vector3 = (fix.inverse() * (info["right"] as Vector3)).normalized()
	q = q * Quaternion(axis, swing + breath)
	_skeleton.set_bone_pose_rotation(int(info["idx"]), q)

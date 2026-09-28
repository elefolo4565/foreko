class_name AutoRig
extends RefCounted
## foreko.glb（Tripo 製）のリグ修復。
## 元データは (1) 骨格がメッシュに対して Y 軸まわりに 90° ずれている、
## (2) 全頂点のウェイトが Hips に 100% という状態で、骨を動かしても体が動かない。
## そこで骨の位置をメッシュに合わせ直し、骨からの距離でウェイトを自動計算してスキンを作り直す。

## ウェイト計算に使う骨: [骨名, 先端の決め方（子の骨名 or オフセット）, 太さ, 左右(-1:右,0:中央,1:左)]
const PARTS: Array = [
	["Hips", "Spine", 0.05, 0],
	["Spine", "Spine1", 0.04, 0],
	["Spine1", "Spine2", 0.04, 0],
	["Spine2", "Neck", 0.04, 0],
	["Neck", "Head", 0.0, 0],
	["Head", Vector3(0, 0.35, 0), 0.0, 0],
	["LeftUpLeg", "LeftLeg", 0.0, 1],
	["LeftLeg", "LeftFoot", 0.0, 1],
	["LeftFoot", Vector3(0, -0.04, 0.07), 0.0, 1],
	["RightUpLeg", "RightLeg", 0.0, -1],
	["RightLeg", "RightFoot", 0.0, -1],
	["RightFoot", Vector3(0, -0.04, 0.07), 0.0, -1],
	["LeftShoulder", "LeftArm", 0.0, 1],
	["LeftArm", "LeftForeArm", 0.0, 1],
	["LeftForeArm", "LeftHand", 0.0, 1],
	["LeftHand", Vector3(0.04, -0.05, 0), 0.0, 1],
	["RightShoulder", "RightArm", 0.0, -1],
	["RightArm", "RightForeArm", 0.0, -1],
	["RightForeArm", "RightHand", 0.0, -1],
	["RightHand", Vector3(-0.04, -0.05, 0), 0.0, -1],
]
const PREFIX: String = "mixamorig_"
## 元の骨格座標 → メッシュ座標（Y 軸まわり -90°）
const ALIGN: Basis = Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))


static func rebuild(mi: MeshInstance3D, skeleton: Skeleton3D) -> bool:
	if mi.skin == null or mi.mesh == null:
		return false
	var skin: Skin = mi.skin.duplicate()
	var bone_count: int = skeleton.get_bone_count()

	# 1) 元のバインドポーズから骨のメッシュ座標上の位置を求める
	var global_pos: Array = []
	global_pos.resize(bone_count)
	var has_pos: Array = []
	has_pos.resize(bone_count)
	has_pos.fill(false)
	var bind_to_bone: Dictionary = {}
	for k: int in skin.get_bind_count():
		var bi: int = skeleton.find_bone(String(skin.get_bind_name(k)))
		if bi < 0:
			continue
		bind_to_bone[k] = bi
		global_pos[bi] = ALIGN * skin.get_bind_pose(k).affine_inverse().origin
		has_pos[bi] = true

	# 2) 回転なし・平行移動だけのレストに作り直す
	for i: int in bone_count:
		var parent: int = skeleton.get_bone_parent(i)
		var parent_pos: Vector3 = Vector3.ZERO if parent < 0 else global_pos[parent]
		if not has_pos[i]:
			global_pos[i] = parent_pos
		var local := Transform3D(Basis.IDENTITY, (global_pos[i] as Vector3) - parent_pos)
		skeleton.set_bone_rest(i, local)
		skeleton.reset_bone_pose(i)
	for k: int in skin.get_bind_count():
		if bind_to_bone.has(k):
			skin.set_bind_pose(k, Transform3D(Basis.IDENTITY, -(global_pos[bind_to_bone[k]] as Vector3)))

	# 3) 骨ごとの線分（カプセル）を作る
	var bone_to_bind: Dictionary = {}
	for k: Variant in bind_to_bone.keys():
		bone_to_bind[bind_to_bone[k]] = k
	var segs: Array = []  # {bind, a, b, radius, side}
	for part: Array in PARTS:
		var bi: int = skeleton.find_bone(PREFIX + String(part[0]))
		if bi < 0 or not bone_to_bind.has(bi):
			continue
		var a: Vector3 = global_pos[bi]
		var b: Vector3
		if part[1] is Vector3:
			b = a + (part[1] as Vector3)
		else:
			var ci: int = skeleton.find_bone(PREFIX + String(part[1]))
			b = global_pos[ci] if ci >= 0 else a
		segs.append({"bind": int(bone_to_bind[bi]), "a": a, "b": b, "radius": float(part[2]), "side": int(part[3]), "name": part[0]})

	var neck_y: float = (global_pos[skeleton.find_bone(PREFIX + "Neck")] as Vector3).y
	var hip_y: float = (global_pos[skeleton.find_bone(PREFIX + "Hips")] as Vector3).y

	# 4) 頂点ごとにウェイトを計算してメッシュを作り直す
	var src: Mesh = mi.mesh
	var new_mesh := ArrayMesh.new()
	for s: int in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(verts.size() * 4)
		weights.resize(verts.size() * 4)
		for vi: int in verts.size():
			var v: Vector3 = verts[vi]
			var cand: Array = []
			for sg: Dictionary in segs:
				var side: int = sg["side"]
				# 左右の取り違えを防ぐ
				if side == 1 and v.x < -0.03:
					continue
				if side == -1 and v.x > 0.03:
					continue
				var nm: String = sg["name"]
				# 首より上は頭、脚は腰より下だけ
				if v.y > neck_y + 0.02 and nm != "Head" and nm != "Neck":
					continue
				if nm.ends_with("UpLeg") or nm.ends_with("Leg") or nm.ends_with("Foot"):
					if v.y > hip_y + 0.03:
						continue
				var d: float = maxf(0.001, _dist_to_segment(v, sg["a"], sg["b"]) - float(sg["radius"]))
				cand.append([d, int(sg["bind"])])
			cand.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
			var total: float = 0.0
			var ws: Array = [0.0, 0.0, 0.0, 0.0]
			var bs: Array = [0, 0, 0, 0]
			for j: int in mini(3, cand.size()):
				var w: float = 1.0 / pow(float(cand[j][0]), 4.0)
				ws[j] = w
				bs[j] = cand[j][1]
				total += w
			for j: int in 4:
				bones[vi * 4 + j] = bs[j]
				weights[vi * 4 + j] = (float(ws[j]) / total) if total > 0.0 else (1.0 if j == 0 else 0.0)
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		new_mesh.surface_set_material(s, src.surface_get_material(s))
	mi.mesh = new_mesh
	mi.skin = skin
	return true


static func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var len2: float = ab.length_squared()
	if len2 < 0.000001:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

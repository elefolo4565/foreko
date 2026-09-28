class_name WorldBuilder
extends RefCounted
## 町を組み立てるためのメッシュ・マテリアル・手続きテクスチャのヘルパー。

static var _tex_cache: Dictionary = {}

var _mat_cache: Dictionary = {}


# ---------------------------------------------------------------- テクスチャ

## グレースケールの手続きテクスチャ（albedo_color で色付けして使う）
static func get_texture(kind: String) -> ImageTexture:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var size: int = 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = kind.hash()
	for y: int in size:
		for x: int in size:
			var v: float = 1.0
			match kind:
				"planks":
					# 縦板張り。板の継ぎ目と木目
					var plank: int = x / 32
					var grain: float = noise.get_noise_2d(float(x) * 6.0 + plank * 50.0, float(y) * 0.25)
					v = 0.78 + 0.18 * grain + 0.05 * sin(float(plank) * 12.9)
					if x % 32 < 2:
						v = 0.4
				"hplanks":
					# 横板張り（下見板）
					var board: int = y / 24
					var g2: float = noise.get_noise_2d(float(x) * 0.25, float(y) * 6.0 + board * 40.0)
					v = 0.8 + 0.16 * g2
					if y % 24 < 3:
						v = 0.45
				"tiles":
					# 瓦屋根。横の段と丸み
					var row: float = float(y % 32) / 32.0
					var col: float = float((x + (y / 32) * 16) % 32) / 32.0
					v = 0.55 + 0.35 * sin(col * PI) * (0.4 + 0.6 * row)
					if y % 32 < 3:
						v = 0.25
				"dirt":
					var n1: float = noise.get_noise_2d(float(x) * 2.0, float(y) * 2.0)
					var n2: float = noise.get_noise_2d(float(x) * 9.0, float(y) * 9.0)
					v = 0.8 + 0.12 * n1 + 0.08 * n2
				"plaster":
					var n3: float = noise.get_noise_2d(float(x) * 3.0, float(y) * 3.0)
					v = 0.9 + 0.08 * n3
				"stripes":
					v = 1.0 if (x / 32) % 2 == 0 else 0.0
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[kind] = tex
	return tex


# ---------------------------------------------------------------- マテリアル

func mat(color: Color, tex_kind: String = "", uv_scale: float = 1.0, roughness: float = 0.85) -> StandardMaterial3D:
	var key: String = "%s|%s|%s|%s" % [color.to_html(), tex_kind, uv_scale, roughness]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if tex_kind != "":
		m.albedo_texture = get_texture(tex_kind)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * uv_scale
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache[key] = m
	return m


func glow_mat(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key: String = "glow|%s|%s" % [color.to_html(), energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mat_cache[key] = m
	return m


func metal_mat(color: Color) -> StandardMaterial3D:
	var key: String = "metal|%s" % color.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.8
	m.roughness = 0.35
	_mat_cache[key] = m
	return m


# ---------------------------------------------------------------- 形状

func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func cyl(parent: Node3D, radius: float, height: float, pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO, top_radius: float = -1.0, segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func sphere(parent: Node3D, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## 2点間を結ぶ細い円柱（電線など）
func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = a.distance_to(b)
	cm.radial_segments = 4
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var mid: Vector3 = (a + b) * 0.5
	var dir: Vector3 = (b - a).normalized()
	var up_ref: Vector3 = Vector3.UP if absf(dir.dot(Vector3.FORWARD)) > 0.9 else Vector3.FORWARD
	var basis_y: Vector3 = dir
	var basis_x: Vector3 = basis_y.cross(up_ref).normalized()
	var basis_z: Vector3 = basis_x.cross(basis_y).normalized()
	mi.transform = Transform3D(Basis(basis_x, basis_y, basis_z), mid)
	return mi


func collider(parent: Node3D, size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	body.rotation_degrees = rot_deg
	parent.add_child(body)
	return body


## 看板の文字。vertical=true で縦書き
func label(parent: Node3D, text: String, pos: Vector3, font: Font, font_size: int, color: Color, vertical: bool = false, pixel: float = 0.004, outline: Color = Color(0, 0, 0, 0), outline_size: int = 0) -> Label3D:
	var l := Label3D.new()
	var t: String = text
	if vertical:
		var chars: PackedStringArray = []
		for c: String in text:
			chars.append("｜" if c == "ー" else c)
		t = "\n".join(chars)
	l.text = t
	l.font = font
	l.font_size = font_size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_modulate = outline
	l.outline_size = outline_size
	l.position = pos
	l.double_sided = false
	l.line_spacing = -font_size * 0.12
	l.shaded = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(l)
	return l

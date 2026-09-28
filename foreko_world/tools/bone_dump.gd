extends SceneTree
func _init() -> void:
	var inst: Node3D = (load("res://assets/models/foreko.glb") as PackedScene).instantiate()
	root.add_child(inst)
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	print("skeleton path=", mi.skeleton, " skin=", mi.skin, " parent=", mi.get_parent().name)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	print("bones=", sk.get_bone_count(), " binds=", mi.skin.get_bind_count() if mi.skin else -1)
	if mi.skin:
		for k in range(0, 6):
			print(k, " bone=", mi.skin.get_bind_bone(k), " name=", mi.skin.get_bind_name(k), " pose=", mi.skin.get_bind_pose(k).origin)
	var arr: Array = mi.mesh.surface_get_arrays(0)
	print("has bones arr=", arr[Mesh.ARRAY_BONES] != null, " fmt=", mi.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES)
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var hist := {}
	for i in range(0, bones.size(), 4):
		var best := 0
		for j in 4:
			if weights[i+j] > weights[i+best]: best = j
		var bb: int = bones[i+best]
		hist[bb] = hist.get(bb, 0) + 1
	print("dominant bone histogram=", hist)
	print(sk.get_modification_stack() if sk.has_method("get_modification_stack") else "", " children=", sk.get_children().map(func(c): return c.get_class()))
	quit()

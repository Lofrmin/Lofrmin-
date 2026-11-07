extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var station: Node3D = load("res://station.gd").new()
	root.add_child(station)
	station.build()
	for layer in station.maps:
		var art: Sprite3D = layer.get_node_or_null("A01_PandaJamMascots")
		check(art != null and art.texture != null, "official mascot display in both phases")
		if art != null:
			check(art.region_enabled and Rect2(Vector2.ZERO, art.texture.get_size()).encloses(art.region_rect), "source image crop stays inside official sheet")
			check(art.position.y > 1.9 and art.position.y < 2.8, "display is above the monitor and below ceiling")
		for name in ["A01_Monitor","A01_Keyboard","A01_File","A01_Stamp"]:
			var prop: Node3D = layer.get_node_or_null(name)
			check(prop != null, "imported desk model exists: " + name)
			if prop == null: continue
			var meshes := prop.find_children("*","MeshInstance3D",true,false)
			check(not meshes.is_empty(), "prop contains visible geometry")
			for mesh in meshes:
				var bounds: AABB = mesh.global_transform * mesh.get_aabb()
				check(absf(bounds.position.y - 1.02) < 0.005, "prop base rests on desk")
				check(not mesh.get_active_material(0) == null, "prop material is loaded")
				check(prop.find_children("*","CollisionObject3D",true,false).is_empty(), "decoration never changes walkable paths")
	station.free()
	await process_frame
	print("A01_ASSETS_TEST: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

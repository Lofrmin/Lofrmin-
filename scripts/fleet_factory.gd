extends RefCounted
## Procedural hard-surface spacecraft. All geometry lives in the project.
static func material(color: Color, emission: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = .3 if emission == 0 else .0
	mat.roughness = .42
	if emission > 0:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = false
	return mat

static func mesh_node(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, pos, mat)

static func sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 48
	mesh.rings = 24
	return mesh_node(parent, mesh, pos, mat)

static func ring(parent: Node3D, radius: float, thickness: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh = TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 64
	mesh.ring_segments = 8
	return mesh_node(parent, mesh, pos, mat)

static func line_mesh(points: PackedVector3Array, color: Color) -> MeshInstance3D:
	var mesh = ArrayMesh.new()
	var data = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = points
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, data)
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color, 1, color.a < 1)
	return node

static func hull(parent: Node3D, heavy: bool, mat: Material) -> void:
	var points = [Vector3(0,.15,-2.4),Vector3(-.8,0,-.5),Vector3(-.65,0,1.5),Vector3(.65,0,1.5),Vector3(.8,0,-.5),Vector3(0,.65,.3),Vector3(0,-.3,.3)]
	var faces = [[0,1,5],[1,2,5],[2,3,5],[3,4,5],[4,0,5],[1,0,6],[2,1,6],[3,2,6],[4,3,6],[0,4,6]]
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for index in face: surface.add_vertex(points[index] * (1.3 if heavy else 1.0))
	surface.generate_normals()
	mesh_node(parent, surface.commit(), Vector3.ZERO, mat)

static func ship(color: Color, kind: int = 0) -> Node3D:
	var root = Node3D.new()
	var hull_mat = material(Color("2a3b50"))
	var armor_mat = material(Color("43566a"))
	var dark = material(Color("0c1726"))
	var glow = material(color, 2)
	hull(root, kind == 2, hull_mat)
	box(root, Vector3(.4,.22,1.2), Vector3(0,.5,.15), dark)
	box(root, Vector3(.16,.04,.6), Vector3(0,.64,-.12), glow)
	for side in [-1, 1]:
		box(root, Vector3(.38,.34,2.3), Vector3(side * .95,0,.5), armor_mat)
		box(root, Vector3(1.15,.11,.8), Vector3(side * 1.05,-.05,.5), hull_mat)
		box(root, Vector3(.4,.2,.12), Vector3(side*.95,0,1.68), glow)
		box(root, Vector3(.065,.06,1.8), Vector3(side*.92,.2,.4), glow)
		var jet = CylinderMesh.new()
		jet.top_radius = .16
		jet.bottom_radius = .025
		jet.height = 1.5
		var flame = mesh_node(root, jet, Vector3(side*.95,0,2.4), material(Color(color,.25),2,true))
		flame.rotation.x = PI/2
		if kind == 2:
			box(root, Vector3(.35,.6,2), Vector3(side*1.3,.25,-.4), dark)
			box(root, Vector3(.12,.12,1.4), Vector3(side*1.3,.55,-1), glow)
	if kind == 1:
		ring(root, 1.2,.045,Vector3(0,.2,.2),glow).rotation.x=PI/2
	root.scale = Vector3.ONE * (.63 if kind == 0 else (.83 if kind == 1 else 1.03))
	return root

static func enemy(capital: bool = false) -> Node3D:
	var root = ship(Color("ff714b"), 2 if capital else 0)
	root.rotation.y = PI
	sphere(root,.21,Vector3(0,.25,-2.25),material(Color("ff8c55"),3))
	if capital:
		root.scale *= 2.0
		for side in [-1, 1]:
			box(root,Vector3(.55,.5,4),Vector3(side*2.0,0,.1),material(Color("3b2529")))
			box(root,Vector3(.1,.13,3),Vector3(side*2.0,.3,.1),material(Color("ff6044"),2))
	return root

static func station() -> Node3D:
	var root = Node3D.new()
	var armor = material(Color("44596c"))
	var dark = material(Color("172739"))
	var light = material(Color("67e8f9"),2)
	box(root,Vector3(1.3,1.3,9),Vector3.ZERO,armor)
	box(root,Vector3(.8,.8,11),Vector3.ZERO,dark)
	for z in [-2.0,2.0]:
		var rotor=Node3D.new()
		rotor.name="Rotor"+str(z)
		root.add_child(rotor)
		rotor.position.z=z
		for r in [3.1,3.5]: ring(rotor,r,.16,Vector3.ZERO,armor).rotation.x=PI/2
		ring(rotor,3.3,.035,Vector3.ZERO,light).rotation.x=PI/2
		for i in range(8):
			var a=i*TAU/8
			var arm=box(rotor,Vector3(3.4,.17,.18),Vector3(cos(a)*1.7,sin(a)*1.7,0),dark)
			arm.rotation.z=a
			box(rotor,Vector3(.7,.7,.7),Vector3(cos(a)*3.3,sin(a)*3.3,0),armor)
	for side in [-1,1]:
		box(root,Vector3(8,.18,.2),Vector3(side*4,0,0),armor)
		for z in [-1.6,1.6]:
			box(root,Vector3(4.5,.07,2.7),Vector3(side*6,0,z),material(Color("163c5a")))
			for j in range(5): box(root,Vector3(.035,.08,2.7),Vector3(side*6-2+j,0,z),light)
	return root

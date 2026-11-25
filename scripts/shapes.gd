extends RefCounted
## Helpers for building low-poly scenery out of primitive meshes.

static var font: Font


static func mat(col: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


static func emissive(col: Color, energy: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


static func glass(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.metallic = 0.2
	return m


static func box(parent: Node, size: Vector3, pos: Vector3, m: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material,
		rot_deg: Vector3 = Vector3.ZERO, segs: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## An invisible box collider. Layer 1 = solid, layer 2 = interactable only.
static func collider(parent: Node, size: Vector3, pos: Vector3, layer: int = 1) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)
	return sb


static func label(parent: Node, text: String, pos: Vector3, size: int = 48,
		col: Color = Color(0.95, 0.9, 0.75), billboard: bool = true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	if font != null:
		l.font = font
	l.pixel_size = 0.005
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	l.position = pos
	parent.add_child(l)
	return l


## Hide a label beyond `dist` metres (fades out over the last 2 m).
static func fade(l: GeometryInstance3D, dist: float) -> void:
	l.visibility_range_end = dist
	l.visibility_range_end_margin = 2.0
	l.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

extends Node3D
## Gives the meshes of an imported model flat colors, by mesh name.
## For models whose texture file is missing (they import pure white).
## Attach to the root of an instanced model and fill `colors`.

## Mesh node name -> color. Meshes not listed keep their imported material.
@export var colors: Dictionary = {}


func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not colors.has(String(mi.name)):
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[String(mi.name)]
		mat.roughness = 0.85
		mi.material_override = mat

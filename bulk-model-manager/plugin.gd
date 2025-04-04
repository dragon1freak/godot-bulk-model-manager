@tool
extends EditorPlugin

enum COLLIDER_PLACEMENT { Sibling, StaticBodyChild }
enum COLLIDER_TYPE { Trimesh, SingleConvex, SimplifiedConvex, MultipleConvex }

const SUPPORTED_TYPES = [".gltf", ".glb", ".fbx"]
const INHERITED_SCENE_TEMPLATE_PATH = "res://addons/bulk-model-manager/inherited_scene_template.txt"
var INHERITED_SCENE_TEMPLATE : String = ""

var bulk_set_material_dock
var materials_to_set : Dictionary = {} 

var current_directory_name : String
var files_to_reimport = []


@onready var mat_name_regex : RegEx = RegEx.new()
@onready var model_name_regex : RegEx = RegEx.new()
@onready var uid_regex : RegEx = RegEx.new()
@onready var subres_regex = RegEx.new()
@onready var node_type_regex = RegEx.new()


func _ready() -> void:
	mat_name_regex.compile("/([^/.]+).(?:tres|res)$")
	model_name_regex.compile("/([^/.]+).(?:gltf|glb|fbx)$")
	uid_regex.compile("uid=\"(.+)\"")
	node_type_regex.compile("(nodes/root_type=\".*\")")
	subres_regex.compile("_subresources=([\\w={}\\n\\s\":/,.]+})")
	var file = FileAccess.open(INHERITED_SCENE_TEMPLATE_PATH, FileAccess.READ_WRITE)
	INHERITED_SCENE_TEMPLATE = file.get_as_text()
	file.close()


func _enter_tree():
	bulk_set_material_dock = preload("bmm_dock.tscn").instantiate()
	bulk_set_material_dock.editor_parent = self
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UR, bulk_set_material_dock)


func _exit_tree():
	remove_control_from_docks(bulk_set_material_dock)
	bulk_set_material_dock = null


func apply(selected_files, options: Dictionary) -> void:
	# Set the override materials the user selected in the dictionary
	materials_to_set = {}
	for mat in options.selected_materials:
		var mat_name = _get_material_name(mat)
		if mat_name:
			materials_to_set[mat_name] = mat
	
	# Extract any materials on the selected models that dont match a selected material
	if options.extract_materials:
		_extract_materials(selected_files, options.material_export_path)
		print("--- Materials Extracted ---")
	# Set all materials selected or extracted to the models use external paths
	if materials_to_set.keys().size() > 0:
		_set_mats(selected_files)
		print("--- External Materials Set ---")
	
	if options.create_inherited_scenes:
		_create_inherited_scenes(selected_files, options.inherited_scene_options)
		print("--- Inherited Scenes Created ---")
	
	if options.extract_meshes:
		_extract_meshes(selected_files, options.extract_mesh_options)
		print("--- Meshes Extracted ---")
		
	EditorInterface.get_resource_filesystem().scan_sources()


#func reimport_selection(selected_files) -> void:
	#files_to_reimport = []
	#for file in selected_files:
		#_handle_dir_or_file(file, func(path): files_to_reimport.push_back(path))
	#EditorInterface.get_resource_filesystem().reimport_files(files_to_reimport)


#region Material Extracting
# Material Extraction ------------------------------------------------
func _extract_materials(selected_files, mat_export_path) -> void:
	for file_path in selected_files:
		_handle_dir_or_file(file_path, _extract_material_from_file, [mat_export_path])


func _extract_material_from_file(file_path, mat_export_path) -> void:
	var scene : PackedScene = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var scene_instance : Node3D = scene.instantiate()
	var mesh_children = scene_instance.find_children("*", "MeshInstance3D", true)
	
	for mesh_instance in mesh_children:
		var mesh : Mesh = mesh_instance.mesh
		var surface_count = mesh.get_surface_count()
		
		for i in surface_count:
			var surface_material : StandardMaterial3D = mesh.surface_get_material(i).duplicate(true)
			if !surface_material:
				continue
			
			var mat_path = mat_export_path + "/" + surface_material.resource_name + ".tres"
			if !materials_to_set.has(surface_material.resource_name):
				if !FileAccess.file_exists(mat_path):
					ResourceSaver.save(surface_material, mat_path)
				materials_to_set[surface_material.resource_name] = mat_path
	
	scene_instance.free()

#endregion

#region Scene Creation
# Scene creation -----------------------------------------------------
func _create_inherited_scenes(selected_files, options) -> void:
	for file_path in selected_files:
		_handle_dir_or_file(file_path, _create_scene, [options])


func _create_scene(file_path, options) -> void:
	var new_scene_uid_int = ResourceUID.create_id()
	var new_scene_uid = ResourceUID.id_to_text(new_scene_uid_int)
	var new_scene_name = _get_model_name(file_path)
	var imported_model_id = ResourceUID.create_id()
	var imported_model_uid = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(file_path))

	var new_scene_template = INHERITED_SCENE_TEMPLATE
	new_scene_template = new_scene_template.replace("new_scene_name", new_scene_name)
	new_scene_template = new_scene_template.replace("imported_model_path", file_path)
	new_scene_template = new_scene_template.replace("imported_model_id", str(imported_model_id))
	new_scene_template = new_scene_template.replace("new_scene_uid", new_scene_uid)
	new_scene_template = new_scene_template.replace("imported_model_uid", imported_model_uid)
	
	var base_path = options.inherited_scene_path
	if options.mirror_directory and current_directory_name:
		DirAccess.make_dir_absolute(base_path + "/" + current_directory_name)
		base_path = base_path + "/" + current_directory_name
	var new_scene_path = base_path + "/" + new_scene_name + ".tscn"
	
	var file = FileAccess.open(new_scene_path, FileAccess.WRITE)
	file.store_string(new_scene_template)
	file.close()
	ResourceUID.add_id(new_scene_uid_int, new_scene_path)
	
	if options.custom_node_type != "" and options.custom_node_type != null:
		_set_custom_type(file_path, options.custom_node_type)
	
	_handle_scene_settings(new_scene_path, options)


func _set_custom_type(file_path, custom_type) -> void:
	var file = FileAccess.open(file_path + ".import", FileAccess.READ_WRITE)
	var content = file.get_as_text()
	var res = node_type_regex.search(content)
	var node_type_string = res.get_string(1)
	
	content = content.replace(node_type_string, "nodes/root_type=\"" + custom_type + "\"")
	
	file.store_string(content)
	file.close()


func _handle_scene_settings(new_scene_path, options) -> void:
	var packed_scene = load(new_scene_path)
	var target_scene : Node3D = packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE if options.scenes_are_inherited else PackedScene.GEN_EDIT_STATE_MAIN)
	
	if options.create_colliders:
		_create_colliders(target_scene, options)
	
	var new_packed_scene = PackedScene.new()
	new_packed_scene.pack(target_scene)
	ResourceSaver.save(new_packed_scene, new_scene_path)


func _create_colliders(target_scene: Node3D, options) -> void:
	var mesh_children = target_scene.find_children("*", "MeshInstance3D", true)
	for mesh_instance: MeshInstance3D in mesh_children:
		var static_body : StaticBody3D
		match options.collider_type:
			COLLIDER_TYPE.Trimesh:
				mesh_instance.create_trimesh_collision()
				static_body = mesh_instance.find_child("*_col")
			COLLIDER_TYPE.SingleConvex:
				mesh_instance.create_convex_collision()
				static_body = mesh_instance.find_child("*_col")
			COLLIDER_TYPE.SimplifiedConvex:
				mesh_instance.create_convex_collision(true, true)
				static_body = mesh_instance.find_child("*_col")
			COLLIDER_TYPE.MultipleConvex:
				mesh_instance.create_multiple_convex_collisions()
				static_body = mesh_instance.find_child("*_col")
		
		var static_body_children = static_body.get_children(true)
		for shape in static_body_children:
			shape.name = mesh_instance.name + "_col_shape"
			if options.collider_placement == COLLIDER_PLACEMENT.Sibling:
				shape.set_owner(null)
				shape.reparent(mesh_instance.get_parent_node_3d(), false)
				shape.set_owner(target_scene)
				static_body.free()

#endregion

#region Material Setting
# Material Setting -------------------------------------------
func _set_mats(selected_files) -> void:
	for file_path in selected_files:
		_handle_dir_or_file(file_path, _set_mats_on_file)


func _set_mats_on_file(file_path) -> void:
	var file = FileAccess.open(file_path + ".import", FileAccess.READ_WRITE)
	var content = file.get_as_text()
	
	var res = subres_regex.search(content)
	var subres_json_string = res.get_string(1)
	var subresources_json = JSON.parse_string(subres_json_string)
	
	_set_materials(subresources_json)
	
	content = content.replace(subres_json_string, JSON.stringify(subresources_json))
	
	file.store_string(content)
	file.close()


func _set_materials(object: Dictionary) -> void:
	for mat_name in materials_to_set.keys():
		if !object.has("materials"):
			object.materials = {}
			
		object.materials[mat_name] = {"use_external/enabled": true, "use_external/path": materials_to_set.get(mat_name)}

#endregion

#region Mesh Extracting
# Mesh Extraction ------------------------------------------------
func _extract_meshes(selected_files, options) -> void:
	for file_path in selected_files:
		_handle_dir_or_file(file_path, _extract_mesh_from_file, [options])


func _extract_mesh_from_file(file_path, options) -> void:
	var scene : PackedScene = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var scene_instance : Node3D = scene.instantiate()
	var mesh_children = scene_instance.find_children("*", "MeshInstance3D", true)
	
	var meshes_to_set = {}
	var base_path = options.mesh_export_path
	if options.mirror_directory and current_directory_name:
		DirAccess.make_dir_absolute(base_path + "/" + current_directory_name)
		base_path = base_path + "/" + current_directory_name
	if options.mesh_file_directory:
		var model_name = _get_model_name(file_path)
		DirAccess.make_dir_absolute(base_path + "/" + model_name)
		base_path = base_path + "/" + model_name
	
	for mesh_instance in mesh_children:
		var mesh : Mesh = mesh_instance.mesh
		meshes_to_set[mesh.resource_name] = base_path + "/" + mesh.resource_name + ".res"
	
	_set_meshes_on_file(file_path, meshes_to_set)
	
	scene_instance.free()


func _set_meshes_on_file(file_path: String, meshes_to_set: Dictionary) -> void:
	var file = FileAccess.open(file_path + ".import", FileAccess.READ_WRITE)
	var content = file.get_as_text()
	
	var res = subres_regex.search(content)
	var subres_json_string = res.get_string(1)
	var subresources_json = JSON.parse_string(subres_json_string)
	
	_set_meshes(subresources_json, meshes_to_set)
	
	content = content.replace(subres_json_string, JSON.stringify(subresources_json))
	
	file.store_string(content)
	file.close()


func _set_meshes(object: Dictionary, meshes_to_set: Dictionary) -> void:
	for mesh_name in meshes_to_set.keys():
		if !object.has("meshes"):
			object.meshes = {}
		
		object.meshes[mesh_name] = {"save_to_file/enabled": true, "save_to_file/path": meshes_to_set.get(mesh_name)}


#endregion

#region Utils
# Utils -----
func _check_file_format(file_path) -> bool:
	for format in SUPPORTED_TYPES:
		if file_path.ends_with(format):
			return true
	return false


func _get_material_name(path : String) -> String:
	var mat_path_res = mat_name_regex.search(path)
	var mat_path_name = ""
	if mat_path_res:
		mat_path_name = mat_path_res.get_string(1)
	return mat_path_name


func _get_model_name(path : String) -> String:
	var model_path_res = model_name_regex.search(path)
	var model_path_name = ""
	if model_path_res:
		model_path_name = model_path_res.get_string(1)
	return model_path_name


func _get_directory_name(path : String) -> String:
	var path_array = path.split("/", false)
	return path_array[path_array.size() - 1]


func _handle_dir_or_file(path, callable : Callable, args = []) -> void:
	current_directory_name = ""
	if FileAccess.file_exists(path):
		if !_check_file_format(path):
			return
		
		var _args = [path]
		_args.append_array(args)
		callable.callv(_args)
	elif DirAccess.dir_exists_absolute(path):
		var dir = DirAccess.open(path)
		if dir:
			current_directory_name = _get_directory_name(path)
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if !dir.current_is_dir():
					var file_path = path + file_name
					if _check_file_format(file_path):
						var _args = [file_path]
						_args.append_array(args)
						callable.callv(_args)
				file_name = dir.get_next()
			dir.list_dir_end()
#endregion

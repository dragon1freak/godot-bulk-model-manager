@tool
extends EditorPlugin


const SUPPORTED_TYPES = [".gltf", ".glb", ".fbx"]


var bulk_set_material_dock
var materials_to_set : Dictionary = {} 
var files_to_reimport : PackedStringArray = []

@onready var mat_name_regex : RegEx = RegEx.new()
@onready var subres_regex = RegEx.new()


func _ready() -> void:
	mat_name_regex.compile("/([^/.]+).(?:tres|res)$")
	subres_regex.compile("_subresources=([\\w={}\\n\\s\":/,.]+})")


func _enter_tree():
	bulk_set_material_dock = preload("bulk_set_mats_dock.tscn").instantiate()
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
	# Set all materials selected or extracted to the models use external paths
	_set_mats(selected_files)
	
	if options.create_inherited_scenes:
		_create_inherited_scenes(selected_files, options)
	
	print("reimport", selected_files)
	
	EditorInterface.get_resource_filesystem().scan_sources()


#region Material Extracting
# Material Extraction ------------------------------------------------
func _extract_materials(selected_files, mat_export_path) -> void:
	for file_path in selected_files:
		_handle_dir_or_file(file_path, _extract_from_file, [mat_export_path])
	print("extract the stuff")


func _extract_from_file(file_path, mat_export_path) -> void:
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
	print("inherit the stuff")
	pass

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
	files_to_reimport.push_back(file_path)
	print("set the stuff", materials_to_set)


func _set_materials(object: Dictionary) -> void:
	for mat_name in materials_to_set.keys():
		if !object.has("materials"):
			object.materials = {}
			
		object.materials[mat_name] = {"use_external/enabled": true, "use_external/path": materials_to_set.get(mat_name)}

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


func _handle_dir_or_file(path, callable : Callable, args = []) -> void:	
	if FileAccess.file_exists(path):
		if !_check_file_format(path):
			print("bad file", path)
			return
		var _args = [path]
		_args.append_array(args)
		callable.callv(_args)
	elif DirAccess.dir_exists_absolute(path):
		var dir = DirAccess.open(path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if !dir.current_is_dir():
					var file_path = path + file_name
					if _check_file_format(file_path):
						var _args = [file_path]
						_args.append_array(args)
						callable.callv(_args)
					else:
						print("bad file in dir", file_path)
				file_name = dir.get_next()
			dir.list_dir_end()


#func _reimport_files(step = 0):
	#if EditorInterface.get_resource_filesystem().is_scanning():
		#await get_tree().create_timer(0.1).timeout
		#return await _reimport_files(step)
	#else:
		#match step:
			#0:
				#EditorInterface.get_resource_filesystem().scan()
			#1:
				#EditorInterface.get_resource_filesystem().scan_sources()
			#2:
				#print(files_to_reimport)
				#EditorInterface.get_resource_filesystem().reimport_files(files_to_reimport)
		#
		#step += 1
		#if step < 2:
			#_reimport_files(step)
#endregion

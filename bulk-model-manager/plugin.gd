@tool
extends EditorPlugin


const SUPPORTED_TYPES = [".gltf", ".glb", ".fbx"]


var bulk_set_material_dock
var set_mats_button

@onready var mat_name_regex : RegEx = RegEx.new()
@onready var subres_regex = RegEx.new()


func _enter_tree():
	bulk_set_material_dock = preload("bulk_set_mats_dock.tscn").instantiate()
	bulk_set_material_dock.editor_parent = self
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UR, bulk_set_material_dock)


func _exit_tree():
	remove_control_from_docks(bulk_set_material_dock)
	bulk_set_material_dock = null


func set_mats(selected_files, target_materials) -> void:
	mat_name_regex.compile("/([^/.]+).(?:tres|res)$")
	subres_regex.compile("_subresources=([\\w={}\\n\\s\":/,.]+})")
	
	for file_path in selected_files:
		if FileAccess.file_exists(file_path):
			_handle_file(file_path, target_materials)
		elif DirAccess.dir_exists_absolute(file_path):
			_handle_directory(file_path, target_materials)
	
	EditorInterface.get_resource_filesystem().scan_sources()


func _handle_directory(dir_path, target_materials) -> void:
	var dir = DirAccess.open(dir_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				_handle_file(dir_path + file_name, target_materials)
			file_name = dir.get_next()
		dir.list_dir_end()


func _handle_file(file_path, target_materials) -> void:
	if !_check_file_format(file_path):
		return
	
	var file = FileAccess.open(file_path + ".import", FileAccess.READ_WRITE)
	var content = file.get_as_text()
	
	var res = subres_regex.search(content)
	var subres_json_string = res.get_string(1)
	var subresources_json = JSON.parse_string(subres_json_string)
	
	_set_materials(subresources_json, target_materials)
	
	content = content.replace(subres_json_string, JSON.stringify(subresources_json))
	
	file.store_string(content)
	file.close()


func _check_file_format(file_path) -> bool:
	for format in SUPPORTED_TYPES:
		if file_path.ends_with(format):
			return true
	return false


func _set_materials(object: Dictionary, target_materials: PackedStringArray) -> void:
	for mat in target_materials:
		var mat_path_res = mat_name_regex.search(target_materials[0])
		var mat_path_name = ""
		if mat_path_res:
			mat_path_name = mat_path_res.get_string(1)
		else:
			continue
		
		if !object.has("materials"):
			object.materials = {}
			
		object.materials[mat_path_name] = {"use_external/enabled": true, "use_external/path": mat}

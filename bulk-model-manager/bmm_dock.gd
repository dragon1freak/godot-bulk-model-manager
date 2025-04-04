@tool
extends Control


const BSM_MATERIAL_LABEL = preload("res://addons/bulk-model-manager/bmm_material_label.tscn")

enum COLLIDER_PLACEMENT { Sibling, StaticBodyChild }
enum COLLIDER_TYPE { Trimesh, SingleConvex, SimplifiedConvex, MultipleConvex }

var file_name_regex : RegEx
var add_material_dialog : EditorFileDialog
var material_export_path_dialog : EditorFileDialog
var inherited_scene_path_dialog : EditorFileDialog
var mesh_export_path_dialog : EditorFileDialog
var material_export_path : String
var inherited_scene_path : String
var mesh_export_path : String
var selected_materials : PackedStringArray = []
var editor_parent : EditorPlugin

@onready var set_mats_button: Button = %SetMatsButton
@onready var selected_file_count: TextEdit = %SelectedFileCount
@onready var scenes_mirror_directory_checkbox: CheckBox = %ScenesMirrorDirectoryCheckbox
@onready var info_dialog_button: Button = %InfoDialogButton
@onready var info_dialog: AcceptDialog = AcceptDialog.new()
@onready var reimport_button: Button = %ReimportButton

@onready var select_materials_button: Button = %SelectMaterialsButton
@onready var material_labels: VBoxContainer = %MaterialLabels
@onready var no_mats_label: Label = %NoMatsLabel

@onready var tab_parent: TabContainer = self.get_parent()

@onready var extract_materials_checkbox: CheckBox = %ExtractMaterialsCheckbox
@onready var extract_material_path_row: VBoxContainer = %ExtractMaterialPathRow
@onready var material_export_path_label: TextEdit = %MaterialExportPath
@onready var set_material_path_button: Button = %SetMaterialPathButton
@onready var clear_materials_path_button: Button = %ClearMaterialsPathButton

@onready var create_scenes_checkbox: CheckBox = %CreateScenesCheckbox
@onready var inherited_scene_row: VBoxContainer = %InheritedSceneRow
@onready var inherited_scene_path_label: TextEdit = %InheritedScenePath
@onready var set_inherited_scene_path: Button = %SetInheritedScenePath
@onready var clear_inherited_scene_path: Button = %ClearInheritedScenePath
@onready var create_colliders_checkbox: CheckBox = %CreateCollidersCheckbox
@onready var create_colliders_row: VBoxContainer = %CreateCollidersRow
@onready var collider_placement_button: OptionButton = %ColliderPlacementButton
@onready var collider_type_button: OptionButton = %ColliderTypeButton
@onready var node_type_button: Button = %NodeTypeButton
@onready var custom_node_type_label: TextEdit = %CustomNodeTypeLabel
@onready var custom_node_type_row: VBoxContainer = %CustomNodeTypeRow
@onready var custom_node_type_checkbox: CheckBox = %CustomNodeTypeCheckbox
@onready var clear_node_type_button: Button = %ClearNodeTypeButton
@onready var scenes_inherited_checkbox: CheckBox = %ScenesInheritedCheckbox

@onready var extract_meshes_checkbox: CheckBox = %ExtractMeshesCheckbox
@onready var extract_meshes_row: VBoxContainer = %ExtractMeshesRow
@onready var mesh_mirror_directory_checkbox: CheckBox = %MeshMirrorDirectoryCheckbox
@onready var mesh_export_path_label: TextEdit = %MeshExportPath
@onready var set_mesh_path_button: Button = %SetMeshPathButton
@onready var clear_mesh_path_button: Button = %ClearMeshPathButton
@onready var mesh_file_directory_checkbox: CheckBox = %MeshFileDirectoryCheckbox



func _ready() -> void:
	# Buttons ----------------------
	info_dialog_button.pressed.connect(func(): info_dialog.popup_centered())
	set_mats_button.pressed.connect(_on_set_mats_pressed)
	select_materials_button.pressed.connect(func(): add_material_dialog.popup_file_dialog())
	reimport_button.pressed.connect(_on_reimport_pressed)
	
	_on_extract_toggled(false)
	extract_materials_checkbox.toggled.connect(_on_extract_toggled)
	set_material_path_button.pressed.connect(func(): material_export_path_dialog.popup_file_dialog())
	clear_materials_path_button.pressed.connect(func(): _mat_export_path_selected(""))
	
	_on_inherited_scene_toggled(false)
	_on_create_colliders_toggled(false)
	_on_custom_type_toggled(false)
	custom_node_type_checkbox.toggled.connect(_on_custom_type_toggled)
	create_scenes_checkbox.toggled.connect(_on_inherited_scene_toggled)
	create_colliders_checkbox.toggled.connect(_on_create_colliders_toggled)
	set_inherited_scene_path.pressed.connect(func(): inherited_scene_path_dialog.popup_file_dialog())
	clear_inherited_scene_path.pressed.connect(func(): _inherited_scene_path_selected(""))
	node_type_button.pressed.connect(func(): EditorInterface.popup_create_dialog(_on_custom_root_type_selected, "Node"))
	clear_node_type_button.pressed.connect(func(): _on_custom_root_type_selected(""))
	_on_list_change()
	
	_on_mesh_export_toggled(false)
	extract_meshes_checkbox.toggled.connect(_on_mesh_export_toggled)
	set_mesh_path_button.pressed.connect(func(): mesh_export_path_dialog.popup_centered())
	clear_mesh_path_button.pressed.connect(func(): _mesh_export_path_selected(""))

	
	file_name_regex = RegEx.new()
	file_name_regex.compile("/([^/.]+.\\w+)$")
	
	# Dialogs -----------------------
	add_material_dialog = EditorFileDialog.new()
	_set_dialog_settings(add_material_dialog)
	add_material_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	add_material_dialog.add_filter("*.tres,*.res", "Resources")
	add_material_dialog.files_selected.connect(_on_material_selected)
	EditorInterface.get_base_control().add_child(add_material_dialog)
	
	material_export_path_dialog = EditorFileDialog.new()
	_set_dialog_settings(material_export_path_dialog)
	material_export_path_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	material_export_path_dialog.dir_selected.connect(_mat_export_path_selected)
	EditorInterface.get_base_control().add_child(material_export_path_dialog)
	
	inherited_scene_path_dialog = EditorFileDialog.new()
	_set_dialog_settings(inherited_scene_path_dialog)
	inherited_scene_path_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	inherited_scene_path_dialog.dir_selected.connect(_inherited_scene_path_selected)
	EditorInterface.get_base_control().add_child(inherited_scene_path_dialog)
	
	mesh_export_path_dialog = EditorFileDialog.new()
	_set_dialog_settings(mesh_export_path_dialog)
	mesh_export_path_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	mesh_export_path_dialog.dir_selected.connect(_mesh_export_path_selected)
	EditorInterface.get_base_control().add_child(mesh_export_path_dialog)
	
	# Info dialog
	info_dialog.title = "Dragon1Freak's BMM Info"
	info_dialog.dialog_text = "Here are some common issues and what to do about them:
								
								FileAccess errors in the console
								\t    - As long as everything worked as expected, just ignore them!
								
								The material extraction and/or inherited scene creation process was successful, but
								my model is showing the incorrect material or the inherited scene doesnt look right
								\t    - In some cases the process may be successful but the resources won't be completely
								\t      reimported as expected, such as processing large amounts of models.  Reloading the 
								\t      project should resolve this issue as it will rescan all of the resources again.
								"
	add_child(info_dialog)


func _set_dialog_settings(dialog: EditorFileDialog) -> void:
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	dialog.size = Vector2(1024, 576)


func _process(delta: float) -> void:
	if file_name_regex == null:
		return
	if tab_parent != null and self != tab_parent.get_current_tab_control():
		return

	var current_paths = EditorInterface.get_selected_paths()
	var current_path_count = current_paths.size()
	if current_path_count == 0:
		selected_file_count.text = "No selected file"
	elif current_path_count == 1 and current_paths[0] != null:
		var mat_path_res = file_name_regex.search(current_paths[0])
		var mat_path_name = ""
		if mat_path_res:
			mat_path_name = mat_path_res.get_string(1)
		selected_file_count.text = mat_path_name if mat_path_name else current_paths[0]
	else:
		selected_file_count.text = str(current_path_count) + " Selected Files"


func _on_set_mats_pressed() -> void:
	var confirim_dialog = ConfirmationDialog.new()
	confirim_dialog.title = "Process Models"
	confirim_dialog.dialog_text = "Are you sure you want to apply the configured actions to the selected models?\n
									It is highly likely you'll need to reload the project after the process is complete, if
									the processed resources aren't behaving as expected, make sure to reload."
	
	confirim_dialog.confirmed.connect(func():
		editor_parent.apply(EditorInterface.get_selected_paths(), {
			"selected_materials": selected_materials,
			"extract_materials": extract_materials_checkbox.button_pressed,
			"material_export_path": material_export_path,
			"create_inherited_scenes": create_scenes_checkbox.button_pressed,
			"extract_meshes": extract_meshes_checkbox.button_pressed,
			"inherited_scene_options": {
				"inherited_scene_path": inherited_scene_path,
				"create_colliders": create_colliders_checkbox.button_pressed,
				"collider_placement": collider_placement_button.selected,
				"collider_type": collider_type_button.selected,
				"mirror_directory": scenes_mirror_directory_checkbox.button_pressed,
				"custom_node_type": custom_node_type_label.text,
				"scenes_are_inherited": scenes_inherited_checkbox.button_pressed
			},
			"extract_mesh_options": {
				"mesh_export_path": mesh_export_path,
				"mirror_directory": mesh_mirror_directory_checkbox.button_pressed,
				"mesh_file_directory": mesh_file_directory_checkbox.button_pressed
			}
		})
	)
	
	add_child(confirim_dialog)
	confirim_dialog.popup_centered()
	confirim_dialog.show()


func _on_reimport_pressed() -> void:
	editor_parent.reimport_selection(EditorInterface.get_selected_paths())


func _check_apply_disabled() -> void:
	var is_disabled : bool = false
	if selected_materials.size() == 0 and !extract_materials_checkbox.button_pressed and !create_scenes_checkbox.button_pressed and !extract_meshes_checkbox.button_pressed:
		set_mats_button.disabled = true
		set_mats_button.tooltip_text = "Select one or more materials"
	elif extract_materials_checkbox.button_pressed and !material_export_path:
		set_mats_button.disabled = true
		set_mats_button.tooltip_text = "Set a material extract path"
	elif create_scenes_checkbox.button_pressed and !inherited_scene_path:
		set_mats_button.disabled = true
		set_mats_button.tooltip_text = "Set a path for inherited scene creation"
	elif extract_meshes_checkbox.button_pressed and !mesh_export_path:
		set_mats_button.disabled = true
		set_mats_button.tooltip_text = "Set a path for the extracted meshes"
	else:
		set_mats_button.disabled = false
		set_mats_button.tooltip_text = ""


#region Material Selection
# Material Selection -----------------------------------
func _on_material_selected(paths):
	var new_materials = Array(paths).filter(func(path): return !selected_materials.has(path))
	selected_materials.append_array(PackedStringArray(new_materials))
	_update_material_labels()


func _remove_material(target_mat) -> void:
	var labels = material_labels.get_children()
	for child in labels:
		if child is HBoxContainer and child.get_node("Label").text == target_mat:
			child.queue_free()
	selected_materials.remove_at(selected_materials.find(target_mat))
	_on_list_change()


func _update_material_labels() -> void:
	_on_list_change()
	
	var labels = material_labels.get_children()
	for child in labels:
		if child is HBoxContainer:
			child.queue_free()
	
	for mat in selected_materials:
		var label_instance = BSM_MATERIAL_LABEL.instantiate()
		label_instance.get_node("Label").text = mat
		label_instance.get_node("Button").pressed.connect(func(): _remove_material(mat))
		material_labels.add_child(label_instance)


func _on_list_change() -> void:
	no_mats_label.visible = selected_materials.size() == 0
	_check_apply_disabled()

#endregion


#region Material Extract
# Material Exctract ------------------------------------
func _on_extract_toggled(value: bool) -> void:
	extract_material_path_row.visible = value
	_check_apply_disabled()


func _mat_export_path_selected(path) -> void:
	material_export_path_label.text = path
	material_export_path = path
	_check_apply_disabled()

#endregion


#region Inherited Scenes
# Inherited Scene --------------------------------------
func _inherited_scene_path_selected(path) -> void:
	inherited_scene_path_label.text = path
	inherited_scene_path = path
	_check_apply_disabled()


func _on_inherited_scene_toggled(value: bool) -> void:
	inherited_scene_row.visible = value
	_check_apply_disabled()


func _on_create_colliders_toggled(value: bool) -> void:
	create_colliders_row.visible = value
	_check_apply_disabled()


func _on_custom_root_type_selected(type) -> void:
	custom_node_type_label.text = type


func _on_custom_type_toggled(value: bool) -> void:
	custom_node_type_row.visible = value

#endregion


func _on_mesh_export_toggled(value: bool) -> void:
	extract_meshes_row.visible = value
	_check_apply_disabled()

func _mesh_export_path_selected(path) -> void:
	mesh_export_path_label.text = path
	mesh_export_path = path
	_check_apply_disabled()

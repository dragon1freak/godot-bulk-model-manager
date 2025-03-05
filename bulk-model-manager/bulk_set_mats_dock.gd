@tool
extends Control


const BSM_MATERIAL_LABEL = preload("res://addons/bulk-model-manager/bsm_material_label.tscn")

var file_name_regex : RegEx
var file_dialog : EditorFileDialog
var material_export_path_dialog : EditorFileDialog
var material_export_path : String
var selected_materials : PackedStringArray = []
var editor_parent : EditorPlugin

@onready var set_mats_button: Button = %SetMatsButton
@onready var selected_file_count: Label = %SelectedFileCount
@onready var select_materials_button: Button = %SelectMaterialsButton
@onready var material_labels: VBoxContainer = %MaterialLabels
@onready var no_mats_label: Label = %NoMatsLabel
@onready var tab_parent: TabContainer = self.get_parent()
@onready var extract_materials_checkbox: CheckBox = %ExtractMaterialsCheckbox
@onready var extract_material_path_row: HBoxContainer = %ExtractMaterialPathRow
@onready var material_export_path_label: Label = %MaterialExportPath
@onready var set_material_path_button: Button = %SetMaterialPathButton


func _ready() -> void:
	set_mats_button.pressed.connect(_on_set_mats_pressed)
	select_materials_button.pressed.connect(func(): file_dialog.show())
	extract_materials_checkbox.toggled.connect(_on_extract_toggled)
	_on_extract_toggled(false)
	set_material_path_button.pressed.connect(func(): material_export_path_dialog.show())
	_on_list_change()
	
	file_name_regex = RegEx.new()
	file_name_regex.compile("/([^/.]+.\\w+)$")
	
	file_dialog = EditorFileDialog.new()
	_set_dialog_settngs(file_dialog)
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	file_dialog.add_filter("*.tres,*.res", "Resources")
	file_dialog.files_selected.connect(_file_selected)
	EditorInterface.get_base_control().add_child(file_dialog)
	
	material_export_path_dialog = EditorFileDialog.new()
	_set_dialog_settngs(material_export_path_dialog)
	material_export_path_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	material_export_path_dialog.dir_selected.connect(_mat_export_path_selected)
	EditorInterface.get_base_control().add_child(material_export_path_dialog)


func _set_dialog_settngs(dialog: EditorFileDialog) -> void:
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	dialog.size = Vector2(1024, 576)

func _process(delta: float) -> void:
	if tab_parent != null and self != tab_parent.get_current_tab_control():
		return

	var current_paths = EditorInterface.get_selected_paths()
	var current_path_count = current_paths.size()
	if current_path_count == 0:
		selected_file_count.text = "No selected file"
	elif current_path_count == 1:
		var mat_path_res = file_name_regex.search(current_paths[0])
		var mat_path_name = ""
		if mat_path_res:
			mat_path_name = mat_path_res.get_string(1)
		selected_file_count.text = mat_path_name if mat_path_name else current_paths[0]
	else:
		selected_file_count.text = str(current_path_count) + " Selected Files"


func _on_set_mats_pressed() -> void:
	editor_parent.set_mats(EditorInterface.get_selected_paths(), selected_materials)


func _file_selected(paths):
	selected_materials = paths
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
	set_mats_button.disabled = selected_materials.size() == 0
	no_mats_label.visible = selected_materials.size() == 0


func _on_extract_toggled(value: bool) -> void:
	extract_material_path_row.visible = value
	set_mats_button.disabled = value and !material_export_path


func _mat_export_path_selected(path) -> void:
	material_export_path_label.text = path
	material_export_path = path

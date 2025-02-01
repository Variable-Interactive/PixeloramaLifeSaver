extends Node

const extension_data_path := "user://LifeSaver/"

var max_folders = 20

var save_timer = Timer
var life_path: String
var file_item_id: int
var help_item_id: int
var api: Node
var open_save_autoload: Node

@onready var small_delay = $SmallDelay

var session_loader: Window

# This script acts as a setup for the extension
func _enter_tree() -> void:
	## NOTE: use get_node_or_null("/root/ExtensionsApi") to access api.
	api = get_node_or_null("/root/ExtensionsApi")
	open_save_autoload = get_node_or_null("/root/OpenSave")
	if open_save_autoload:
		# Check if timer also exists (This is to ensure no crash occur in Godot 4.4 in future)
		if open_save_autoload.autosave_timer:
			save_timer = open_save_autoload.autosave_timer
			save_timer.timeout.connect(func (): small_delay.start())

			session_loader = preload(
				"res://src/Extensions/LifeSaver/WayBack/WayBack.tscn"
			).instantiate()
			api.dialog.get_dialogs_parent_node().add_child(session_loader)

			# also take the time to remove empty sessions.
			for session_folder in DirAccess.get_directories_at(extension_data_path):
				if DirAccess.get_files_at(
					extension_data_path.path_join(session_folder)
				).size() == 0:
					DirAccess.remove_absolute(extension_data_path.path_join(session_folder))

			# Add this session's folder
			life_path = extension_data_path.path_join(get_id())
			DirAccess.make_dir_recursive_absolute(life_path)

			ensure_max_session_limit()

	file_item_id = api.menu.add_menu_item(api.menu.FILE, "Restore a Past Session", session_loader)
	help_item_id = api.menu.add_menu_item(api.menu.HELP, "Browse LifeSaver Backups", self)


func _exit_tree() -> void:
	api.menu.remove_menu_item(api.menu.FILE, file_item_id)
	api.menu.remove_menu_item(api.menu.FILE, help_item_id)


func menu_item_clicked():
	OS.shell_open(ProjectSettings.globalize_path("user://LifeSaver"))


func get_id() -> String:
	var date_time: Dictionary = convert_values_to_string(Time.get_datetime_dict_from_system())

	var id: String = str(
		date_time.year, "_", date_time.month, "_", date_time.day, "_",
		date_time.hour, "_", date_time.minute, "_", date_time.second)
	return id


func convert_values_to_string(dict: Dictionary) -> Dictionary:
	var string_dict = {}
	for key in dict.keys():
		var value = int(dict[key])
		var value_string = str(value)
		if value <= 9:
			value_string = str("0", value_string)
		string_dict[key] = value_string
	return string_dict


func _on_small_delay_timeout() -> void:
	# Hope that the projects are saved
	for project in api.general.get_global().projects:
		var p_backup_path: String = project.backup_path
		var p_name: String = project.file_name

		if p_backup_path:
			print("backup path:", p_name)
			print("life path:", life_path)
			DirAccess.copy_absolute(
				p_backup_path,
				life_path.path_join("(" + p_name + ")_" + p_backup_path.get_file() + ".pxo")
			)


func ensure_max_session_limit():
	var old_folders = DirAccess.get_directories_at(extension_data_path)
	if old_folders.size() > max_folders:
		# Remove oldest folder
		var oldest = extension_data_path.path_join(old_folders[0])
		for file in DirAccess.get_files_at(oldest):
			DirAccess.remove_absolute(oldest.path_join(file))
			DirAccess.remove_absolute(oldest)

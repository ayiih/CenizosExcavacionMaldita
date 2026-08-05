extends Control


func _on_btn_volver_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/ui/main_menu.tscn")

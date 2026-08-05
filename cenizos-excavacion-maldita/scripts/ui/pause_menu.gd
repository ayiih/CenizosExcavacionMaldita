extends CanvasLayer

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func abrir_menu() -> void:
	visible = true
	get_tree().paused = true


func cerrar_menu() -> void:
	visible = false
	get_tree().paused = false


func toggle_menu() -> void:
	if visible:
		cerrar_menu()
	else:
		abrir_menu()


func _on_btn_reanudar_pressed() -> void:
	cerrar_menu()


func _on_btn_guardar_pressed() -> void:
	GuardadoManager.guardar_partida()


func _on_btn_cargar_pressed() -> void:
	GuardadoManager.cargar_partida()
	cerrar_menu()


func _on_btn_ajustes_pressed() -> void:
	# Puedes abrir un subpanel o cargar otra escena de ajustes
	print("Abrir ajustes")


func _on_btn_salir_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://escenas/ui/main_menu.tscn")

extends Control


func _ready() -> void:
	$BotonesMenu/BtnGuardarPartida.disabled = true


func _on_btn_nueva_partida_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/juego/fase01_taller.tscn")


func _on_btn_guardar_pressed() -> void:
	var guardado_correcto := GuardadoManager.guardar_partida()

	if guardado_correcto:
		%MensajeLabel.text = "Partida guardada correctamente."
	else:
		%MensajeLabel.text = "No se pudo guardar la partida."


func _on_btn_cargar_pressed() -> void:
	var carga_correcta := GuardadoManager.cargar_partida()

	if carga_correcta:
		%MensajeLabel.text = "Partida cargada correctamente."
		cerrar_menu()
	else:
		%MensajeLabel.text = "No existe una partida válida."

func _on_btn_ajustes_pressed() -> void:
	get_tree().change_scene_to_file("res://escenas/ui/ajustes_menu.tscn")


func _on_btn_salir_pressed() -> void:
	get_tree().quit()

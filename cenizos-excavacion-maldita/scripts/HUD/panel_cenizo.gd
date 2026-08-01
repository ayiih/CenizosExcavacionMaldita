extends Control
class_name PanelCenizo

@onready var icono_cara: TextureRect = %IconoCara
@onready var nombre_label: Label = %NombreCenizoLabel
@onready var barra_vida: ProgressBar = %BarraVida
@onready var barra_energia: ProgressBar = %BarraEnergia


func configurar_cenizo(
	nombre: String,
	icono: Texture2D,
	vida_actual: int,
	vida_maxima: int,
	energia_actual: int,
	energia_maxima: int
) -> void:
	nombre_label.text = nombre
	icono_cara.texture = icono

	actualizar_vida(vida_actual, vida_maxima)
	actualizar_energia(energia_actual, energia_maxima)


func actualizar_vida(vida_actual: int, vida_maxima: int) -> void:
	vida_maxima = max(vida_maxima, 1)
	vida_actual = clampi(vida_actual, 0, vida_maxima)

	barra_vida.max_value = vida_maxima
	barra_vida.value = vida_actual


func actualizar_energia(
	energia_actual: int,
	energia_maxima: int
) -> void:
	energia_maxima = max(energia_maxima, 1)
	energia_actual = clampi(
		energia_actual,
		0,
		energia_maxima
	)

	barra_energia.max_value = energia_maxima
	barra_energia.value = energia_actual

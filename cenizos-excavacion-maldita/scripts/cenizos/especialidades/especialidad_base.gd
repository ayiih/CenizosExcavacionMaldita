class_name EspecialidadCenizo
extends Resource

## Clase base para las especialidades/trabajos autónomos de un Cenizo.
## Debe mantenerse SIN estado propio mutable por Cenizo: cualquier dato
## que cambie durante la ejecución de una orden vive en OrdenTrabajo,
## para que una misma instancia de especialidad pueda ser reutilizada
## por varios Cenizos trabajando al mismo tiempo.

## Identificador único de la especialidad (ej. &"excavador").
@export var id: StringName = &""

## Nombre para mostrar en la interfaz.
@export var nombre_visible: String = ""


## Determina si esta especialidad puede aceptar la orden recibida.
func puede_realizar_orden(
	_cenizo: CharacterBody2D,
	_orden: OrdenTrabajo
) -> bool:
	return false


## Calcula la posición global a la que el Cenizo debe desplazarse
## antes de comenzar a trabajar.
func calcular_posicion_trabajo(
	cenizo: CharacterBody2D,
	orden: OrdenTrabajo
) -> Vector2:
	return orden.posicion_objetivo if orden != null else cenizo.global_position


## Llamado una vez al entrar al estado EXCAVANDO (o equivalente).
func comenzar_trabajo(
	_cenizo: CharacterBody2D,
	_orden: OrdenTrabajo
) -> void:
	pass


## Llamado en cada _physics_process mientras el Cenizo está trabajando.
func actualizar_trabajo(
	_cenizo: CharacterBody2D,
	_orden: OrdenTrabajo,
	_delta: float
) -> void:
	pass


## Llamado al cancelar o interrumpir la orden antes de completarse.
func cancelar_trabajo(
	_cenizo: CharacterBody2D,
	_orden: OrdenTrabajo
) -> void:
	pass

extends Node

## Mantiene referencias al nivel activo (Cenizo y TerrenoDestructible)
## para que otros Managers puedan acceder sin acoplarse a la escena.

var cenizo: CharacterBody2D
var terreno_destructible: TerrenoDestructible


func registrar_nivel(
	nuevo_cenizo: CharacterBody2D,
	nuevo_terreno: TerrenoDestructible
) -> void:
	cenizo = nuevo_cenizo
	terreno_destructible = nuevo_terreno

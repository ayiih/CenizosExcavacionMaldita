class_name EstadoCenizo
extends RefCounted

## Espacio de nombres para el enum de estados de la máquina de estados
## de Cenizo. No se instancia; solo se usa como EstadoCenizo.Valor.X

enum Valor {
	INACTIVO,
	SELECCIONADO,
	MOVIENDOSE_A_TAREA,
	BUSCANDO_RUTA,
	PREPARANDO_TRABAJO,
	EXCAVANDO,
	ESPERANDO,
	BLOQUEADO,
	CAYENDO,
	ESCALANDO,
	TAREA_COMPLETADA,
	DESTINO_ALCANZADO,
}

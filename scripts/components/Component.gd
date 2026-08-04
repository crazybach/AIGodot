class_name Component
extends Node2D
## Base class for all pluggable entity components.
##
## Components are child nodes of a Creature. The `creature` back-reference
## is set by Creature._add_component() before add_child.
##
## Override _physics_tick for per-frame updates (called by Creature).

var creature: Creature

## Per-physics-frame update, called by Creature._physics_process in
## component add order after the creature's own per-frame logic.
func _physics_tick(_delta: float) -> void:
	pass
